// Engine_JetVox
// Emulazione del "5-Channel Synthesizer" del chip SpeakJet (Magnevation),
// ricostruito dal manuale (Figura 3 / Tabella B):
//
//   Osc 1-3  : oscillatori "formanti" (0..3999 Hz sul chip) -> Mixer 1
//   Osc 4-5  : oscillatori con controllo "distortion" (banda di rumore
//              centrata sulla frequenza dell'oscillatore) -> Mixer 2
//   Envelope : sesto oscillatore (saw / sine / tri / square) che inviluppa
//              Mixer 1 (switch S1) e per meta' Mixer 2 (switch S2)
//   Mixer 5  : somma + master volume -> PWM (qui: sample&hold + bitcrush)
//
// Estensioni JetVox:
//   - "sync": il glottide resetta la fase degli oscillatori formanti
//     (spettro armonico, voce piu' intelligibile e intonabile)
//   - insert per voce: ring modulator, comb "robot" accordato al pitch
//   - mandate per voce verso delay e riverbero
//   - bus master: delay ping-pong a nastro, riverbero FDN "ambient" con
//     shimmer, chorus, saturazione/wavefolder, bitcrusher, limiter
//
// Due voci indipendenti ("chip A" e "chip B"), come nel Flame Talking Synth.

Engine_JetVox : CroneEngine {
	var <voices, <fx, <drybus, <dlybus, <revbus;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		var s = context.server;

		SynthDef(\jetvox_chip, {
			arg out=0, dbus=0, rbus=0, dsend=0, rsend=0.15,
			pan=0, amp=0.7, mvol=0.75, trem=1,
			hz=110, hzlag=0.03, envhz=60, envmode=0, shape=0, sync=1,
			vibrate=5.5, vibdepth=0,
			f1=500, f2=1500, f3=2500, f4=3000, f5=4000,
			a1=0, a2=0, a3=0, a4=0, a5=0, dist=0, env1=1, env2=0,
			lag=0.03, alag=0.01, fscale=1, nscale=1,
			srate=16384, bits=8, lofi=0.5, tone=7500, drive=0,
			ringhz=180, ringmix=0, combmix=0, combratio=1, combfb=0.7;

			var p0, ph, wrap, env, freqs, amps, oscs, m1, m2, d, nbw;
			var sig, lf, q, nyq, comb, st;

			nyq = SampleRate.ir * 0.45;

			// --- envelope generator (glottide) ---
			p0 = Lag.kr(hz, hzlag) * (1 + (SinOsc.kr(vibrate) * vibdepth));
			p0 = Select.kr(envmode, [p0, Lag.kr(envhz, hzlag)]);
			ph = Phasor.ar(0, p0 * SampleDur.ir, 0, 1);
			wrap = (ph - Delay1.ar(ph)) < 0;
			env = Select.ar(shape, [
				1 - ph,                                // 00 saw (decadente)
				0.5 + (0.5 * sin(ph * 2pi)),           // 01 sine
				1 - (((ph * 2) - 1).abs),              // 10 triangle
				ph < 0.5                               // 11 square
			]);

			// --- oscillatori 1..3 (formanti) ---
			freqs = [f1, f2, f3].collect { |f| (Lag.kr(f, lag) * Lag.kr(fscale, 0.05)).clip(0, nyq) };
			amps = [a1, a2, a3, a4, a5].collect { |a| Lag.kr(a, alag) };
			oscs = freqs.collect { |f|
				var synced = sin(Phasor.ar(wrap, f * SampleDur.ir, 0, 1) * 2pi);
				var free = SinOsc.ar(f);
				(synced * sync) + (free * (1 - sync))
			};
			m1 = (oscs[0] * amps[0]) + (oscs[1] * amps[1]) + (oscs[2] * amps[2]);
			m1 = m1 * ((env * env1) + (1 - env1));            // switch S1

			// --- oscillatori 4..5 con "distortion" ---
			d = Lag.kr(dist, alag).clip(0, 1);
			nbw = 30 + (d.squared * 3500);
			m2 = [f4, f5].collect { |f|
				var c = SinOsc.ar((Lag.kr(f, lag) * nscale).clip(0, nyq));
				var n = LFDNoise3.ar(nbw);
				c * ((1 - d) + (d * n * 1.6))
			};
			m2 = (m2[0] * amps[3]) + (m2[1] * amps[4]);
			m2 = m2 * (1 - (env2 * 0.5 * (1 - env)));       // switch S2 (1/2 env)

			// --- mixer 5 + master ---
			sig = (m1 * 0.42) + (m2 * 0.55);
			sig = (sig * (1 + (drive * 6))).tanh / (1 + (drive * 1.5));

			// --- insert: ring modulator + comb "robot" ---
			sig = (sig * (1 - ringmix)) + (sig * SinOsc.ar(Lag.kr(ringhz, 0.05)) * ringmix);
			comb = CombC.ar(sig, 0.1, (1 / (p0 * combratio).clip(20, 4000)), combfb.linexp(0, 1, 0.01, 1.5));
			sig = (sig * (1 - (combmix * 0.5))) + (comb * combmix * 0.35);

			sig = sig * Lag.kr(mvol, 0.05) * Lag.kr(trem, 0.004);

			// --- "PWM out": sample & hold + bit reduction ---
			lf = Latch.ar(sig.clip(-1, 1), Impulse.ar(srate));
			q = 2 ** (bits - 1);
			lf = (lf * q).round(1) / q;
			sig = XFade2.ar(sig, lf, (lofi * 2) - 1);
			sig = LPF.ar(sig, tone.clip(200, 18000));
			sig = LeakDC.ar(sig);

			st = Pan2.ar(sig * amp, pan);
			Out.ar(out, st);
			Out.ar(dbus, st * Lag.kr(dsend, 0.03));
			Out.ar(rbus, st * Lag.kr(rsend, 0.03));
		}).add;

		SynthDef(\jetvox_fx, {
			arg out=0, inbus=0, dbus=0, rbus=0,
			dtime=0.375, dfb=0.45, dtone=4500, dwow=0.2, dpp=1, dret=0.8, d2r=0.2,
			rsize=1, rdecay=3.5, rdamp=6000, rpre=0.02, rmod=0.5, rshim=0, rret=0.8,
			chmix=0, chrate=0.3, chdepth=0.5,
			mdrive=0, mfold=0, mbits=16, mrate=48000, mcrush=0, mtone=18000, mlevel=1,
			stut=0, stutlen=0.125;

			var dry, din, rin, fb, src, dl, wob, dt;
			var pre, x, lfb, times, mod, lines, h, g, sh, rev, sig;
			var ch, lf, q, drv, fold, lin;
			var sbuf, sframes, wph, sA, strig, sstart, slen, rel, rph, srd, swin, sgate;

			dry = In.ar(inbus, 2);
			din = In.ar(dbus, 2);
			rin = In.ar(rbus, 2);

			// --- delay ping-pong "a nastro" ---
			lin = LocalIn.ar(6);            // un solo LocalIn: [delay L R, fdn 1..4]
			fb = [lin[0], lin[1]];
			dt = Lag.kr(dtime, 0.3);
			wob = 1 + (SinOsc.kr([0.53, 0.61], [0, 0.5pi]) * dwow * 0.006)
			          + (LFDNoise3.kr(1.3) * dwow * 0.002);
			src = (din * (1 - dpp)) + ([Mix(din) * 0.7, DC.ar(0)] * dpp);
			dl = DelayC.ar(src + (((fb * (1 - dpp)) + (fb.reverse * dpp)) * dfb.clip(0, 1.05)), 2.5, (dt * wob).clip(0.005, 2.4));
			dl = LPF.ar(HPF.ar(dl, 90), dtone.clip(300, 16000));
			dl = (dl * 1.3).tanh / 1.3;

			// --- riverbero FDN 4 linee + shimmer ---
			pre = DelayN.ar(rin + (dl * d2r), 0.3, rpre.clip(0, 0.29));
			x = pre;
			[[0.0047, 0.0061], [0.0071, 0.0083], [0.0113, 0.0127]].do { |t|
				x = AllpassC.ar(x, 0.05, t, 0.09);
			};
			lfb = [lin[2], lin[3], lin[4], lin[5]];
			times = [0.0353, 0.0441, 0.0527, 0.0613] * rsize.clip(0.2, 3);
			mod = SinOsc.kr([0.11, 0.13, 0.17, 0.19], [0, 1, 2, 3]) * rmod * 0.0012;
			lines = DelayC.ar([x[0], x[1], x[0].neg, x[1].neg] + lfb, 0.25, (times + mod).clip(0.001, 0.24));
			lines = LPF.ar(lines, rdamp.clip(500, 18000));
			h = [
				lines[0] + lines[1] + lines[2] + lines[3],
				lines[0] - lines[1] + lines[2] - lines[3],
				lines[0] + lines[1] - lines[2] - lines[3],
				lines[0] - lines[1] - lines[2] + lines[3]
			] * 0.5;
			g = 0.001 ** (times / rdecay.clip(0.1, 60));
			sh = PitchShift.ar(Mix(lines) * 0.25, 0.2, 2, 0.002, 0.01) * rshim.clip(0, 1) * 0.6;
			LocalOut.ar(dl ++ ((h * g) + [sh, sh.neg, sh, sh.neg]).tanh);
			rev = [lines[0] + lines[2], lines[1] + lines[3]] * 0.6;

			sig = dry + (dl * dret) + (rev * rret);

			// --- stutter / beat repeat: congela e ripete l'ultimo frammento ---
			sframes = 96000;
			sbuf = LocalBuf(sframes, 2).clear;
			sA = K2A.ar(stut > 0.5);
			wph = Phasor.ar(0, 1 - sA, 0, sframes);
			BufWr.ar(sig, sbuf, wph);
			strig = sA > Delay1.ar(sA);
			slen = (stutlen.clip(0.01, 1.9) * SampleRate.ir);
			sstart = Latch.ar(wph, strig) - slen;
			rel = Phasor.ar(strig, 1, 0, slen);
			rph = (sstart + rel).wrap(0, sframes);
			srd = BufRd.ar(2, sbuf, rph, 1, 2);
			swin = min(1, min(rel, slen - rel) / 96);
			sgate = Lag.ar(sA, 0.004);
			sig = (sig * (1 - sgate)) + (srd * swin * sgate);

			// --- chorus ---
			ch = DelayC.ar(sig, 0.05, (0.012 + (SinOsc.kr(chrate, [0, 0.5pi]) * chdepth * 0.006)).clip(0.001, 0.049));
			sig = (sig * (1 - (chmix * 0.5))) + (ch * chmix * 0.7);

			// --- saturazione / wavefolder ---
			drv = sig * (1 + (mdrive * 12));
			fold = (drv * (1 + (mfold * 3))).fold2(1);
			drv = drv.tanh;
			sig = XFade2.ar(sig, XFade2.ar(drv, fold, (mfold * 2) - 1) / (1 + (mdrive * 0.8)), ((mdrive.max(mfold) * 2) - 1).clip(-1, 1));

			// --- bitcrusher master ---
			lf = Latch.ar(sig, Impulse.ar(mrate.clip(500, 48000)));
			q = 2 ** (mbits.clip(1, 16) - 1);
			lf = (lf * q).round(1) / q;
			sig = XFade2.ar(sig, lf, (mcrush * 2) - 1);

			sig = LPF.ar(sig, mtone.clip(300, 20000));
			sig = Limiter.ar(LeakDC.ar(sig) * mlevel, 0.95, 0.01);
			Out.ar(out, sig);
		}).add;

		s.sync;

		drybus = Bus.audio(s, 2);
		dlybus = Bus.audio(s, 2);
		revbus = Bus.audio(s, 2);

		voices = [-0.35, 0.35].collect { |p|
			Synth.new(\jetvox_chip, [\out, drybus, \dbus, dlybus, \rbus, revbus, \pan, p], context.xg);
		};
		fx = Synth.new(\jetvox_fx, [\out, context.out_b, \inbus, drybus, \dbus, dlybus, \rbus, revbus],
			context.xg, \addToTail);

		// frame(voce, f1..f5, a1..a5, dist, env1, env2, lag, alag)
		this.addCommand(\frame, "ifffffffffffffff", { arg msg;
			var v = voices[(msg[1] - 1).clip(0, 1)];
			v.set(
				\f1, msg[2], \f2, msg[3], \f3, msg[4], \f4, msg[5], \f5, msg[6],
				\a1, msg[7], \a2, msg[8], \a3, msg[9], \a4, msg[10], \a5, msg[11],
				\dist, msg[12], \env1, msg[13], \env2, msg[14], \lag, msg[15], \alag, msg[16]
			);
		});

		// pitch(voce, hz, glide)
		this.addCommand(\pitch, "iff", { arg msg;
			voices[(msg[1] - 1).clip(0, 1)].set(\hz, msg[2], \hzlag, msg[3]);
		});

		// envosc(voce, mode, hz, shape)  mode 0 = segue pitch, 1 = frequenza fissa
		this.addCommand(\envosc, "iifi", { arg msg;
			voices[(msg[1] - 1).clip(0, 1)].set(\envmode, msg[2], \envhz, msg[3], \shape, msg[4]);
		});

		// param(voce, nome, valore) - accesso generico ai controlli della voce
		this.addCommand(\param, "isf", { arg msg;
			voices[(msg[1] - 1).clip(0, 1)].set(msg[2].asSymbol, msg[3]);
		});

		// fx(nome, valore) - controlli del bus effetti master
		this.addCommand(\fx, "sf", { arg msg;
			fx.set(msg[1].asSymbol, msg[2]);
		});
	}

	free {
		voices.do(_.free);
		fx.free;
		drybus.free;
		dlybus.free;
		revbus.free;
	}
}
