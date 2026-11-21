-- tts.lua
-- Testo inglese -> codici SpeakJet.
--
-- 1) regole lettera->fonema in stile NRL (Elovitz, Johnson, McHugh, Shore,
--    "Automatic Translation of English Text to Phonetics by Means of
--    Letter-to-Sound Rules", Naval Research Laboratory 1976 - pubblico
--    dominio; la stessa famiglia di regole del TTS256 che si abbinava al
--    SpeakJet). Set ridotto e riscritto.
-- 2) i fonemi astratti vengono convertiti negli allofoni SpeakJet scegliendo
--    le varianti in base al contesto (BE/BO/EB/OB, KE/KO/EK/OK, SE/SO, ...),
--    come suggerisce la "Phonetic Usage Table" del manuale.
--
-- Simboli nei contesti delle regole:
--   #  una o piu' vocali         :  zero o piu' consonanti
--   ^  una consonante            .  consonante sonora (B D V G J L M N R W Z)
--   +  vocale anteriore (E I Y)  %  suffisso (ER E ES ED ING ELY)
--   &  sibilante                 @  T S R D L Z N J TH CH SH
--   ' ' confine di parola

local TTS = {}

local RULES_SRC = {
  A = {
    " [A] =AX", " [ARE] =AA R", " [AR]O=AX R", "[AR]#=EH R", " ^[AS]#=EY S",
    "[A]WA=AX", "[AW]=AO", " :[ANY]=EH N IY", "[A]^+#=EY", "#:[ALLY]=AX L IY",
    " [AL]#=AX L", "[AGAIN]=AX G EH N", "#:[AG]E=IH JH", "[A]^+:#=AE",
    " :[A]^+ =EY", "[A]^%=EY", " [ARR]=AX R", "[ARR]=AE R", " :[AR] =AA R",
    "[AR] =ER", "[AR]=AA R", "[AIR]=EH R", "[AI]=EY", "[AY]=EY", "[AU]=AO",
    "#:[AL] =AX L", "#:[ALS] =AX L Z", "[ALK]=AO K", "[AL]^=AO L",
    " :[ABLE]=EY B AX L", "[ABLE]=AX B AX L", "[ANG]+=EY N JH", "[A]=AE",
  },
  B = {" [BE]^#=B IH", "[BEING]=B IY IH NG", " [BOTH] =B OW TH", " [BUS]#=B IH Z",
       "[BUIL]=B IH L", "[BB]=B", "[B]=B"},
  C = {" [CH]^=K", "^E[CH]=K", "[CH]=CH", " S[CI]#=S AY", "[CI]A=SH", "[CI]O=SH",
       "[CI]EN=SH", "[C]+=S", "[CK]=K", "[COM]%=K AH M", "[C]=K"},
  D = {"#:[DED] =D IH D", ".E[D] =D", "#^:E[D] =T", " [DE]^#=D IH", " [DO] =D UW",
       " [DOES]=D AH Z", " [DOING]=D UW IH NG", " [DOW]=D AW", "[DU]A=JH UW", "[DD]=D", "[D]=D"},
  E = {
    "#:[E] =", "'^:[E] =", " :[E] =IY", "#[ED] =D", "#:[E]D =", "[EV]ER=EH V",
    "[E]^%=IY", "[ERI]#=IY R IY", "[ERI]=EH R IH", "#:[ER]#=ER", "[ER]#=EH R",
    "[ER]=ER", " [EVEN]=IY V EH N", "#:[E]W=", "@[EW]=UW", "[EW]=Y UW", "[E]O=IY",
    "#:&[ES] =IH Z", "#:[E]S =", "#:[ELY] =L IY", "#:[EMENT]=M EH N T",
    "[EFUL]=F UH L", "[EE]=IY", "[EARN]=ER N", " [EAR]^=ER", "[EAD]=EH D",
    "#:[EA] =IY AX", "[EA]SU=EH", "[EA]=IY", "[EIGH]=EY", "[EI]=IY", " [EYE]=AY",
    "[EY]=IY", "[EU]=Y UW", "[E]=EH",
  },
  F = {"[FUL]=F UH L", "[FF]=F", "[F]=F"},
  G = {" [GH]=G", "[GIV]=G IH V", " [G]I^=G", "[GE]T=G EH", "SU[GGES]=G JH EH S", "[GG]=G",
       " B#[G]=G", "[G]+=JH", "[GREAT]=G R EY T", "#[GH]=", "[G]=G"},
  H = {" [HAV]=HH AE V", " [HERE]=HH IY R", " [HOUR]=AW ER", "[HOW]=HH AW", "[H]#=HH", "[H]="},
  I = {
    " [IN]=IH N", " [I] =AY", "[IX]=IH K S", " :[I]O=AY", " :[I]A=AY",
    "#^:[IVE] =IH V", "#^:[ICE] =IH S", "#^:[ILE] =AY L", "[INE] =AY N", "[I]^E =AY", "[I]^ES =AY", "[I]^ED =AY", "[IN]D=AY N", "[IER]=IY ER", "#:R[IED] =IY D",
    "[IED] =AY D", "[IEN]=IY EH N", "[IE]T=AY EH", " :[I]%=AY", "[I]%=IY",
    "[IE]=IY", "[I]^+:#=IH", "[IR]#=AY R", "[IZ]%=AY Z", "[IS]%=AY Z", "[I]D%=AY",
    "+^[I]^+=IH", "[I]T%=AY", "#^:[I]^+=IH", "[I]^+=AY", "[IR]=ER", "[IGH]=AY",
    "[ILD]=AY L D", "[IGN] =AY N", "[IGN]^=AY N", "[IGN]%=AY N", "[IQUE]=IY K", "[I]=IH",
  },
  J = {"[J]=JH"},
  K = {" [K]N=", "[K]=K"},
  L = {"^[LE] =AX L", "[LO]C#=L OW", "L[L]=", "#^:[LES] =AX L Z", "#^:[LED] =AX L D", "[LEAD]=L IY D", "[L]=L"},
  M = {"[MOV]=M UW V", "[MM]=M", "[M]=M"},
  N = {"E[NG]+=N JH", "[NG]R=NG G", "[NG]#=NG G", "[NGL]%=NG G AX L", "[NG]=NG",
       "[NK]=NG K", " [NOW] =N AW", "[NN]=N", "[N]=N"},
  O = {
    "[OF] =AX V", "[OROUGH]=ER OW", "#:[OR] =ER", "#:[ORS] =ER Z", "[OR]=AO R",
    " [ONE]=W AH N", "[OWER]=AW ER", "[OWN] =AW N", "[OW]=OW", " [OVER]=OW V ER", "[OV]=AH V", "[O]^%=OW",
    "[O]^EN=OW", "[O]^I#=OW", "[OL]D=OW L", "[OUGHT]=AO T", "[OUGH]=AH F",
    " [OU]=AW", "H[OU]S#=AW", "#:[OUS]=AX S", "[OUR]=AO R", "[OULD]=UH D",
    "^[OU]^L=AH", "[OUP]=UW P", "[OU]=AW", "[OY]=OY", "[OING]=OW IH NG", "[OI]=OY",
    "[OOR]=AO R", "[OOK]=UH K", "[OOD]=UH D", "[OO]=UW", "[O]E=OW", "[O] =OW",
    "[OA]=OW", " [ONLY]=OW N L IY", " [ONCE]=W AH N S", "[ON'T]=OW N T", "C[O]N=AA",
    "[O]NG=AO", " :^[O]N=AH", "I[ON]=AX N", "#:[ON] =AX N", "#^[ON]=AX N",
    "[O]ST =OW", "[OF]^=AO F", "[OTHER]=AH DH ER", "[OSS] =AO S", "#^:[OM]=AH M", "[O]=AA",
  },
  P = {"[PH]=F", "[PP]=P", "[PEOP]=P IY P", "[POW]=P AW", "[PUT] =P UH T", "[P]=P"},
  Q = {"[QUAR]=K W AO R", "[QU]=K W", "[Q]=K"},
  R = {" [RE]^#=R IY", "[RR]=R", "[R]=R"},
  S = {
    "[SH]=SH", "#[SION]=ZH AX N", "[SOME]=S AH M", "#[SUR]#=ZH ER", "[SUR]#=SH ER",
    "#[SU]#=ZH UW", "#[SSU]#=SH UW", "#[SED] =Z D", "#[S]#=Z", "[SAID]=S EH D",
    "^[SION]=SH AX N", "[S]S=", ".[S] =Z", "#:.E[S] =Z", "#^:##[S] =Z", "#^:#[S] =S",
    "U[S] =S", " :#[S] =Z", " [SCH]=S K", "[S]C+=", "#[SM]=Z M", "[S]=S",
  },
  T = {
    " [THE] =DH AX", "[TO] =T UW", "[THAT] =DH AE T", " [THIS] =DH IH S",
    " [THEY]=DH EY", " [THERE]=DH EH R", "[THER]=DH ER", "[THEIR]=DH EH R",
    " [THAN] =DH AE N", " [THEM] =DH EH M", "[THESE] =DH IY Z", " [THEN]=DH EH N",
    "[THROUGH]=TH R UW", "[THOSE]=DH OW Z", "[THOUGH] =DH OW", " [THUS]=DH AH S",
    "[TH]=TH", "[TT]=T", "#:[TED] =T IH D", "S[TI]#N=CH", "[TI]O=SH", "[TI]A=SH",
    "[TIEN]=SH AX N", "[TUR]#=CH ER", "[TU]A=CH UW", " [TWO]=T UW", "[T]=T",
  },
  U = {"[UIT] =UW T", "[UI]CE=UW", 
    " [UN]I=Y UW N", " [UN]=AH N", " [UPON]=AX P AO N", "@[UR]#=UH R", "[UR]#=Y UH R",
    "[UR]^=ER", "[U]^ =AH", "[U]^^=AH", "[UY]=AY", " G[U]#=", "G[U]%=", "G[U]#=W",
    "#N[U]=Y UW", "@[U]=UW", "[U]=Y UW",
  },
  V = {"[VIEW]=V Y UW", "[V]=V"},
  W = {" [WERE]=W ER", "[WA]S=W AA", "[WA]T=W AA", "[WHERE]=WH EH R", "[WHAT]=WH AA T",
       "[WHOL]=HH OW L", "[WHO]=HH UW", "[WH]=WH", "[WAR]=W AO R", "[WOR]^=W ER",
       "[WR]=R", "[W]=W"},
  X = {"[X]=K S"},
  Y = {"[YOUNG]=Y AH NG", " [YOU]=Y UW", " [YES]=Y EH S", " [Y]=Y", "#^:[Y] =IY",
       "#^:[Y]I=IY", " :[Y] =AY", " :[Y]#=AY", " :[Y]^+:#=IH", " :[Y]^#=AY", "[Y]=IH"},
  Z = {"[ZZ]=Z", "[Z]=Z"},
}

-- eccezioni (parole frequenti con pronuncia irregolare), in fonemi astratti
local EXCEPT = {
  ["bear"] = "B EH R",
  ["pear"] = "P EH R",
  ["wear"] = "W EH R",
  ["tear"] = "T EH R",
  ["swear"] = "S W EH R",
  ["maybe"] = "M EY B IY",
  ["food"] = "F UW D",
  ["foot"] = "F UH T",
  ["push"] = "P UH SH",
  ["pull"] = "P UH L",
  ["put"] = "P UH T",
  ["full"] = "F UH L",
  ["read"] = "R IY D",
  ["dozen"] = "D AH Z AX N",
  ["beige"] = "B EY ZH",
  ["maroon"] = "M AX R UW N",
  ["sapphire"] = "S AE F AY R",
  ["giraffe"] = "JH IH R AE F",
  ["dinosaur"] = "D AY N AX S AO R",
  ["magenta"] = "M AX JH EH N T AX",
  ["violet"] = "V AY AX L AX T",
  ["billion"] = "B IH L Y AX N",
  ["second"] = "S EH K AX N D",
  ["autumn"] = "AO T AX M",
  ["tuesday"] = "T UW Z D EY",
  ["wednesday"] = "W EH N Z D EY",
  ["friday"] = "F R AY D EY",
  ["saturday"] = "S AE T ER D EY",
  ["liftoff"] = "L IH F T AO F",
  ["uranus"] = "Y UH R AX N AX S",
  ["supernova"] = "S UW P ER N OW V AX",
  ["cosmos"] = "K AA Z M OW S",
  ["malfunction"] = "M AE L F AH NG K SH AX N",
  ["obey"] = "OW B EY",
  ["anger"] = "AE NG G ER",
  ["afraid"] = "AX F R EY D",
  ["excited"] = "IH K S AY T IH D",
  ["welcome"] = "W EH L K AX M",
  ["hooray"] = "HH UH R EY",
  ["lizard"] = "L IH Z ER D",
  ["wizard"] = "W IH Z ER D",
  ["octopus"] = "AA K T AX P UH S",
  ["kangaroo"] = "K AE NG G ER UW",
  ["butterfly"] = "B AH T ER F L AY",
  ["camel"] = "K AE M AX L",
  ["mountain"] = "M AW N T AX N",
  ["valley"] = "V AE L IY",
  ["desert"] = "D EH Z ER T",
  ["salad"] = "S AE L AX D",
  ["onion"] = "AH N Y AX N",
  ["carrot"] = "K AE R AX T",
  ["coffee"] = "K AO F IY",
  ["museum"] = "M Y UW Z IY AX M",
  ["keyboard"] = "K IY B AO R D",
  ["wireless"] = "W AY R L AX S",
  ["television"] = "T EH L AX V IH ZH AX N",
  ["motor"] = "M OW T ER",
  ["troll"] = "T R OW L",
  ["legend"] = "L EH JH AX N D",
  ["our"] = "AW ER",
  ["chorus"] = "K AO R AX S",
  ["mono"] = "M AA N OW",
  ["hihat"] = "HH AY HH AE T",
  ["envelope"] = "EH N V AX L OW P",
  ["cassette"] = "K AX S EH T",
  ["jealous"] = "JH EH L AX S",
  ["grateful"] = "G R EY T F UH L",
  ["protocol"] = "P R OW T AX K AA L",
  ["binary"] = "B AY N ER IY",
  ["offline"] = "AO F L AY N",
  ["emerald"] = "EH M ER AX L D",
  ["scarlet"] = "S K AA R L AX T",
  ["lavender"] = "L AE V AX N D ER",
  ["lilac"] = "L AY L AE K",
  ["neon"] = "N IY AA N",
  ["eclipse"] = "IH K L IH P S",
  ["rocket"] = "R AA K AX T",
  ["telescope"] = "T EH L AX S K OW P",
  ["martian"] = "M AA R SH AX N",
  ["strawberry"] = "S T R AO B EH R IY",
  ["chicken"] = "CH IH K AX N",
  ["garden"] = "G AA R D AX N",
  ["hotel"] = "HH OW T EH L",
  ["market"] = "M AA R K AX T",
  ["frequency"] = "F R IY K W AX N S IY",
  ["planet"] = "P L AE N AX T",
  ["forest"] = "F AO R AX S T",
  ["silent"] = "S AY L AX N T",
  ["open"] = "OW P AX N",
  ["seven"] = "S EH V AX N",
  ["heaven"] = "HH EH V AX N",
  ["children"] = "CH IH L D R AX N",
  ["garage"] = "G AX R AA ZH",
  ["machine"] = "M AX SH IY N",
  ["ninja"] = "N IH N JH AX",
  ["laser"] = "L EY Z ER",
  ["sugar"] = "SH UH G ER",
  ["bull"] = "B UH L",
  ["wolf"] = "W UH L F",
  ["woman"] = "W UH M AX N",
  ["christmas"] = "K R IH S M AX S",
  ["chrome"] = "K R OW M",
  ["synthesizers"] = "S IH N TH AX S AY Z ER Z",
  ["robots"] = "R OW B AA T S",
  ["beep"] = "B IY P",
  ["boop"] = "B UW P",
  ["yeah"] = "Y EH AX",
  ["hey"] = "HH EY",
  ["hi"] = "HH AY",
  ["bye"] = "B AY",
  ["fa"] = "F AA",
  ["ti"] = "T IY",
  ["mi"] = "M IY",
  ["re"] = "R EY",
  ["la"] = "L AA",
  ["so"] = "S OW",
  ["ha"] = "HH AA",
  ["oh"] = "OW",
  ["uh"] = "AH",
  ["ah"] = "AA",
  ["arrive"] = "AX R AY V", ["alive"] = "AX L AY V", ["survive"] = "S ER V AY V", ["derive"] = "D IH R AY V", ["deprive"] = "D IH P R AY V",
  ["break"] = "B R EY K",
  ["steak"] = "S T EY K",
  ["death"] = "D EH TH",
  ["friend"] = "F R EH N D",
  ["circuit"] = "S ER K IH T",
  ["piano"] = "P IY AE N OW",
  ["finish"] = "F IH N IH SH",
  ["limit"] = "L IH M IH T",
  ["river"] = "R IH V ER",
  ["spirit"] = "S P IH R IH T",
  ["visit"] = "V IH Z IH T",
  ["engine"] = "EH N JH IH N",
  ["imagine"] = "IH M AE JH IH N",
  ["marine"] = "M AX R IY N",
  ["police"] = "P AX L IY S",
  ["advice"] = "AE D V AY S",
  ["device"] = "D IH V AY S",
  ["office"] = "AO F IH S",
  ["bury"] = "B EH R IY",
  ["luxury"] = "L AH K SH ER IY",
  ["build"] = "B IH L D",
  ["built"] = "B IH L T",
  ["guitar"] = "G IH T AA R",
  ["guide"] = "G AY D",
  ["heart"] = "HH AA R T",
  ["heard"] = "HH ER D",
  ["earth"] = "ER TH",
  ["learn"] = "L ER N",
  ["sugar"] = "SH UH G ER",
  ["sure"] = "SH UH R",
  ["laugh"] = "L AE F",
  ["enough"] = "IY N AH F",
  ["tough"] = "T AH F",
  ["rough"] = "R AH F",
  ["though"] = "DH OW",
  ["blood"] = "B L AH D",
  ["flood"] = "F L AH D",
  ["door"] = "D AO R",
  ["floor"] = "F L AO R",
  ["poor"] = "P UH R",
  ["touch"] = "T AH CH",
  ["country"] = "K AH N T R IY",
  ["cousin"] = "K AH Z AX N",
  ["double"] = "D AH B AX L",
  ["trouble"] = "T R AH B AX L",
  ["couple"] = "K AH P AX L",
  ["soul"] = "S OW L",
  ["shoulder"] = "SH OW L D ER",
  ["route"] = "R UW T",
  ["tomato"] = "T AX M EY T OW",
  ["potato"] = "P AX T EY T OW",
  ["idea"] = "AY D IY AX",
  ["area"] = "EH R IY AX",
  ["video"] = "V IH D IY OW",
  ["audio"] = "AO D IY OW",
  ["studio"] = "S T UW D IY OW",
  ["volume"] = "V AA L Y UW M",
  ["menu"] = "M EH N Y UW",
  ["island"] = "AY L AX N D",
  ["listen"] = "L IH S AX N",
  ["castle"] = "K AE S AX L",
  ["answer"] = "AE N S ER",
  ["sword"] = "S AO R D",
  ["wolf"] = "W UH L F",
  ["word"] = "W ER D",
  ["work"] = "W ER K",
  ["orange"] = "AO R IH N JH",
  ["minute"] = "M IH N IH T",
  ["choir"] = "K W AY ER",
  ["echo"] = "EH K OW",
  ["chaos"] = "K EY AA S",
  ["character"] = "K AE R IH K T ER",
  ["stomach"] = "S T AH M AX K",
  ["technology"] = "T EH K N AA L AX JH IY",
  ["synth"] = "S IH N TH",
  ["tempo"] = "T EH M P OW",
  ["vocoder"] = "V OW K OW D ER",
  ["oscillator"] = "AA S IH L EY T ER",
  ["modular"] = "M AA JH AX L ER",
  ["analog"] = "AE N AX L AO G",
  ["digital"] = "D IH JH IH T AX L",
  ["giant"] = "JH AY AX N T",
  ["tiger"] = "T AY G ER",
  ["eager"] = "IY G ER",
  ["finger"] = "F IH NG G ER",
  ["ginger"] = "JH IH N JH ER",
  ["get"] = "G EH T",
  ["gift"] = "G IH F T",
  ["together"] = "T AX G EH DH ER",
  ["target"] = "T AA R G IH T",
  ["forget"] = "F ER G EH T",
  ["tongue"] = "T AH NG",
  ["owl"] = "AW L",
  ["snow"] = "S N OW",
  ["know"] = "N OW",
  ["show"] = "SH OW",
  ["window"] = "W IH N D OW",
  ["yellow"] = "Y EH L OW",
  ["follow"] = "F AA L OW",
  ["tomorrow"] = "T AX M AA R OW",
  ["arrow"] = "AE R OW",
  ["shadow"] = "SH AE D OW",
  ["rainbow"] = "R EY N B OW",
  ["town"] = "T AW N",
  ["clown"] = "K L AW N",
  ["tower"] = "T AW ER",
  ["flow"] = "F L OW",
  ["grow"] = "G R OW",
  ["blow"] = "B L OW",
  ["beautiful"] = "B Y UW T IH F UH L",
  ["beauty"] = "B Y UW T IY",
  ["kilo"] = "K IY L OW",
  ["pizza"] = "P IY T S AX",
  ["taxi"] = "T AE K S IY",
  ["pony"] = "P OW N IY",
  ["ninety"] = "N AY N T IY",
  ["nineteen"] = "N AY N T IY N",
  ["quiet"] = "K W AY AX T",
  ["science"] = "S AY AX N S",
  ["diet"] = "D AY AX T",
  ["tiny"] = "T AY N IY",
  ["pilot"] = "P AY L AX T",
  ["silent"] = "S AY L AX N T",
  ["final"] = "F AY N AX L",
  ["vinyl"] = "V AY N AX L",
  ["liquid"] = "L IH K W IH D",
  ["ocean"] = "OW SH AX N",
  ["business"] = "B IH Z N AX S",
  ["colonel"] = "K ER N AX L",
  ["notice"] = "N OW T IH S",
  ["mobile"] = "M OW B AX L",
  ["fragile"] = "F R AE JH AX L",
  ["juice"] = "JH UW S",
  ["fruit"] = "F R UW T",
  ["suit"] = "S UW T",
  ["house"] = "HH AW S",
  ["mouse"] = "M AW S",
  ["heaven"] = "HH EH V AX N",
  ["heavy"] = "HH EH V IY",
  ["weather"] = "W EH DH ER",
  ["leather"] = "L EH DH ER",
  ["feather"] = "F EH DH ER",
  ["bread"] = "B R EH D",
  ["head"] = "HH EH D",
  ["health"] = "HH EH L TH",
  ["wealth"] = "W EH L TH",
  ["meadow"] = "M EH D OW",
  ["weapon"] = "W EH P AX N",
  ["measure"] = "M EH ZH ER",
  ["treasure"] = "T R EH ZH ER",
  ["pleasure"] = "P L EH ZH ER",
  ["wonder"] = "W AH N D ER",
  ["wonderful"] = "W AH N D ER F UH L",
  ["month"] = "M AH N TH",
  ["monday"] = "M AH N D EY",
  ["money"] = "M AH N IY",
  ["honey"] = "HH AH N IY",
  ["monkey"] = "M AH NG K IY",
  ["mother"] = "M AH DH ER",
  ["brother"] = "B R AH DH ER",
  ["other"] = "AH DH ER",
  ["another"] = "AX N AH DH ER",
  ["nothing"] = "N AH TH IH NG",
  ["something"] = "S AH M TH IH NG",
  ["above"] = "AX B AH V",
  ["glove"] = "G L AH V",
  ["oven"] = "AH V AX N",
  ["cover"] = "K AH V ER",
  ["color"] = "K AH L ER",
  ["front"] = "F R AH N T",
  ["son"] = "S AH N",
  ["none"] = "N AH N",
  ["won"] = "W AH N",
  ["shove"] = "SH AH V",
  ["only"] = "OW N L IY",
  ["both"] = "B OW TH",
  ["gone"] = "G AO N",
  ["lose"] = "L UW Z",
  ["whose"] = "HH UW Z",
  ["prove"] = "P R UW V",
  ["eye"] = "AY",
  ["eyes"] = "AY Z",
  ["buy"] = "B AY",
  ["guy"] = "G AY",
  ["goodbye"] = "G UH D B AY",
  ["bye"] = "B AY",
  ["rhythm"] = "R IH DH AX M",
  ["knowledge"] = "N AA L IH JH",
  ["debris"] = "D AX B R IY",
  ["hour"] = "AW ER",
  ["honest"] = "AA N AX S T",
  ["usual"] = "Y UW ZH UW AX L",
  ["unique"] = "Y UW N IY K",
  ["opera"] = "AA P R AX",
  ["pyramid"] = "P IH R AX M IH D",
  ["system"] = "S IH S T AX M",
  ["crystal"] = "K R IH S T AX L",
  ["symbol"] = "S IH M B AX L",
  ["mystery"] = "M IH S T ER IY",
  ["lyrics"] = "L IH R IH K S",
  ["myth"] = "M IH TH",
  ["gym"] = "JH IH M",
  ["hymn"] = "HH IH M",
  ["cymbal"] = "S IH M B AX L",
  ["cycle"] = "S AY K AX L",
  ["hybrid"] = "HH AY B R IH D",
  ["hyper"] = "HH AY P ER",
  ["xylophone"] = "Z AY L AX F OW N",
  ["xenon"] = "Z IY N AA N",
  ["xerox"] = "Z IH R AA K S",
  ["xray"] = "EH K S R EY",
  ["yacht"] = "Y AA T",
  ["zodiac"] = "Z OW D IY AE K",
  ["radar"] = "R EY D AA R",
  ["sonar"] = "S OW N AA R",
  ["quasar"] = "K W EY Z AA R",
  ["pulsar"] = "P AH L S AA R",
  ["nebula"] = "N EH B Y AX L AX",
  ["galaxy"] = "G AE L AX K S IY",
  ["asteroid"] = "AE S T ER OY D",
  ["satellite"] = "S AE T AX L AY T",
  ["astronaut"] = "AE S T R AX N AO T",
  ["meteor"] = "M IY T IY ER",
  ["comet"] = "K AA M AX T",
  ["mars"] = "M AA R Z",
  ["venus"] = "V IY N AX S",
  ["jupiter"] = "JH UW P IH T ER",
  ["saturn"] = "S AE T ER N",
  ["mercury"] = "M ER K Y ER IY",
  ["laser"] = "L EY Z ER",
  ["robot"] = "R OW B AA T",
  ["alien"] = "EY L IY AX N",
  ["cyborg"] = "S AY B AO R G",
  ["android"] = "AE N D R OY D",
  ["monome"] = "M AX N OW M",
  ["midi"] = "M IH D IY",
  ["disco"] = "D IH S K OW",
  ["techno"] = "T EH K N OW",
  ["electro"] = "IH L EH K T R OW",
  ["electric"] = "IH L EH K T R IH K",
  ["electronic"] = "IH L EH K T R AA N IH K",
  ["electron"] = "IH L EH K T R AA N",
  ["element"] = "EH L AX M AX N T",
  ["elephant"] = "EH L AX F AX N T",
  ["energy"] = "EH N ER JH IY",
  ["enemy"] = "EH N AX M IY",
  ["every"] = "EH V R IY",
  ["everything"] = "EH V R IY TH IH NG",
  ["everybody"] = "EH V R IY B AA D IY",
  ["everyone"] = "EH V R IY W AH N",
  ["family"] = "F AE M AX L IY",
  ["favorite"] = "F EY V R IH T",
  ["february"] = "F EH B R UW EH R IY",
  ["different"] = "D IH F R AX N T",
  ["chocolate"] = "CH AA K L AX T",
  ["camera"] = "K AE M R AX",
  ["america"] = "AX M EH R IH K AX",
  ["africa"] = "AE F R IH K AX",
  ["banana"] = "B AX N AE N AX",
  ["data"] = "D EY T AX",
  ["alpha"] = "AE L F AX",
  ["delta"] = "D EH L T AX",
  ["gamma"] = "G AE M AX",
  ["omega"] = "OW M EY G AX",
  ["koala"] = "K OW AA L AX",
  ["lava"] = "L AA V AX",
  ["panda"] = "P AE N D AX",
  ["tuna"] = "T UW N AX",
  ["umbrella"] = "AH M B R EH L AX",
  ["vodka"] = "V AA D K AX",
  ["yoga"] = "Y OW G AX",
  ["zebra"] = "Z IY B R AX",
  ["harmonica"] = "HH AA R M AA N IH K AX",
  ["sofa"] = "S OW F AX",
  ["pasta"] = "P AA S T AX",
  ["china"] = "CH AY N AX",
  ["drama"] = "D R AA M AX",
  ["cinema"] = "S IH N AX M AX",
  ["antenna"] = "AE N T EH N AX",
  ["arena"] = "AX R IY N AX",
  ["media"] = "M IY D IY AX",
  ["bazooka"] = "B AX Z UW K AX",
  ["karaoke"] = "K EH R IY OW K IY",
  ["atom"] = "AE T AX M",
  ["atomic"] = "AX T AA M IH K",
  ["random"] = "R AE N D AX M",
  ["phantom"] = "F AE N T AX M",
  ["custom"] = "K AH S T AX M",
  ["bottom"] = "B AA T AX M",
  ["kingdom"] = "K IH NG D AX M",
  ["freedom"] = "F R IY D AX M",
  ["wisdom"] = "W IH Z D AX M",
  ["seldom"] = "S EH L D AX M",
  ["melody"] = "M EH L AX D IY",
  ["harmony"] = "HH AA R M AX N IY",
  ["comedy"] = "K AA M AX D IY",
  ["company"] = "K AH M P AX N IY",
  ["economy"] = "IH K AA N AX M IY",
  ["memory"] = "M EH M ER IY",
  ["history"] = "HH IH S T ER IY",
  ["factory"] = "F AE K T ER IY",
  ["victory"] = "V IH K T ER IY",
  ["glory"] = "G L AO R IY",
  ["story"] = "S T AO R IY",
  ["sorry"] = "S AA R IY",
  ["hurry"] = "HH ER IY",
  ["berry"] = "B EH R IY",
  ["cherry"] = "CH EH R IY",
  ["merry"] = "M EH R IY",
  ["very"] = "V EH R IY",
  ["query"] = "K W IH R IY",
  ["series"] = "S IH R IY Z",
  ["diary"] = "D AY ER IY",
  ["library"] = "L AY B R EH R IY",
  ["dictionary"] = "D IH K SH AX N EH R IY",
  ["primary"] = "P R AY M EH R IY",
  ["january"] = "JH AE N Y UW EH R IY",
  ["darling"] = "D AA R L IH NG",
  ["sampler"] = "S AE M P L ER",
  ["identify"] = "AY D EH N T AX F AY",
  ["satisfy"] = "S AE T IH S F AY",
  ["multiply"] = "M AH L T AX P L AY",
  ["reply"] = "R IH P L AY",
  ["deny"] = "D IH N AY",
  ["july"] = "JH UW L AY",
  ["lullaby"] = "L AH L AX B AY",
  ["supply"] = "S AX P L AY",
  ["apply"] = "AX P L AY",
  ["fly"] = "F L AY",
  ["sky"] = "S K AY",
  ["why"] = "WH AY",
  ["try"] = "T R AY",
  ["cry"] = "K R AY",
  ["dry"] = "D R AY",
  ["shy"] = "SH AY",
  ["spy"] = "S P AY",
  ["my"] = "M AY",
  ["by"] = "B AY",
  ["a"] = "AX", ["the"] = "DH AX", ["of"] = "AX V", ["to"] = "T UW",
  ["one"] = "W AH N", ["two"] = "T UW", ["three"] = "TH R IY", ["four"] = "F AO R",
  ["five"] = "F AY V", ["six"] = "S IH K S", ["seven"] = "S EH V AX N",
  ["eight"] = "EY T", ["nine"] = "N AY N", ["ten"] = "T EH N", ["zero"] = "Z IY R OW",
  ["eleven"] = "IH L EH V AX N", ["twelve"] = "T W EH L V", ["hundred"] = "HH AH N D R AX D",
  ["thousand"] = "TH AW Z AX N D", ["million"] = "M IH L Y AX N",
  ["you"] = "Y UW", ["your"] = "Y AO R", ["i"] = "AY", ["i'm"] = "AY M",
  ["are"] = "AA R", ["is"] = "IH Z", ["was"] = "W AA Z", ["have"] = "HH AE V",
  ["hello"] = "HH EH L OW", ["world"] = "W ER L D", ["robot"] = "R OW B AA T",
  ["computer"] = "K AX M P Y UW T ER", ["synthesizer"] = "S IH N TH AX S AY Z ER",
  ["music"] = "M Y UW Z IH K", ["people"] = "P IY P AX L", ["says"] = "S EH Z",
  ["said"] = "S EH D", ["do"] = "D UW", ["does"] = "D AH Z", ["done"] = "D AH N",
  ["love"] = "L AH V", ["move"] = "M UW V", ["give"] = "G IH V", ["live"] = "L IH V",
  ["what"] = "WH AA T", ["who"] = "HH UW", ["why"] = "WH AY", ["where"] = "WH EH R",
  ["there"] = "DH EH R", ["their"] = "DH EH R", ["they"] = "DH EY", ["we"] = "W IY",
  ["he"] = "HH IY", ["she"] = "SH IY", ["me"] = "M IY", ["be"] = "B IY",
  ["norns"] = "N AO R N Z", ["grid"] = "G R IH D", ["monome"] = "M AX N OW M",
  ["voice"] = "V OY S", ["talk"] = "T AO K", ["walk"] = "W AO K",
  ["laser"] = "L EY Z ER", ["radio"] = "R EY D IY OW", ["data"] = "D EY T AX",
  ["error"] = "EH R ER", ["system"] = "S IH S T AX M", ["machine"] = "M AX SH IY N",
  ["water"] = "W AO T ER", ["ocean"] = "OW SH AX N", ["girl"] = "G ER L",
  ["woman"] = "W UH M AX N", ["women"] = "W IH M AX N", ["eyes"] = "AY Z",
  ["okay"] = "OW K EY", ["ok"] = "OW K EY", ["yes"] = "Y EH S", ["no"] = "N OW",
  ["please"] = "P L IY Z", ["thank"] = "TH AE NG K", ["danger"] = "D EY N JH ER",
  ["warning"] = "W AO R N IH NG", ["attention"] = "AX T EH N SH AX N",
  ["galaxy"] = "G AE L AX K S IY", ["universe"] = "Y UW N IH V ER S",
  ["beat"] = "B IY T", ["bass"] = "B EY S", ["techno"] = "T EH K N OW",
  ["sequence"] = "S IY K W AX N S", ["sequencer"] = "S IY K W AX N S ER",
  ["known"] = "N OW N", ["shown"] = "SH OW N", ["grown"] = "G R OW N", ["own"] = "OW N", ["lower"] = "L OW ER",
  ["now"] = "N AW", ["how"] = "HH AW", ["cow"] = "K AW", ["wow"] = "W AW", ["down"] = "D AW N",
  ["phoneme"] = "F OW N IY M", ["speak"] = "S P IY K", ["jet"] = "JH EH T",
}

local DIGITS = {"zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"}

-- parse delle regole
local RULES = {}
for letter, list in pairs(RULES_SRC) do
  RULES[letter] = {}
  for _, src in ipairs(list) do
    local left, match, right, out = src:match("^(.-)%[(.-)%](.-)=(.*)$")
    if left then
      local ph = {}
      for p in out:gmatch("%S+") do ph[#ph + 1] = p end
      table.insert(RULES[letter], {left = left, match = match, right = right, out = ph})
    end
  end
end

local VOWELS = {A = true, E = true, I = true, O = true, U = true, Y = true}
local VOICED = {B = true, D = true, V = true, G = true, J = true, L = true, M = true,
                N = true, R = true, W = true, Z = true}
local FRONTV = {E = true, I = true, Y = true}

local function is_vowel(ch) return VOWELS[ch] == true end
local function is_cons(ch) return ch ~= nil and ch:match("%a") ~= nil and not is_vowel(ch) end

-- singolo simbolo di contesto (non ripetuto) in posizione pos.
-- restituisce la nuova posizione o nil. dir = +1 (destra) / -1 (sinistra)
local function match_one(p, text, pos, dir)
  local ch = (pos >= 1) and text:sub(pos, pos) or " "
  if ch == "" then ch = " " end
  if p == "^" then return is_cons(ch) and pos + dir or nil
  elseif p == "." then return VOICED[ch] and pos + dir or nil
  elseif p == "+" then return FRONTV[ch] and pos + dir or nil
  elseif p == " " then return (not ch:match("%a")) and pos + dir or nil
  elseif p == "&" then
    local two = (dir < 0) and text:sub(pos - 1, pos) or text:sub(pos, pos + 1)
    if two == "CH" or two == "SH" then return pos + 2 * dir end
    if ("SCGZXJ"):find(ch, 1, true) and ch ~= " " then return pos + dir end
    return nil
  elseif p == "@" then
    local two = (dir < 0) and text:sub(pos - 1, pos) or text:sub(pos, pos + 1)
    if two == "TH" or two == "CH" or two == "SH" then return pos + 2 * dir end
    if ("TSRDLZNJ"):find(ch, 1, true) and ch ~= " " then return pos + dir end
    return nil
  elseif p == "%" then
    if dir < 0 then return nil end
    for _, suf in ipairs({"ING", "ELY", "ER", "ES", "ED", "E"}) do
      if text:sub(pos, pos + #suf - 1) == suf and not text:sub(pos + #suf, pos + #suf):match("%a") then
        return pos + #suf
      end
    end
    return nil
  else
    return (ch == p) and pos + dir or nil
  end
end

-- matcher con backtracking: '#' (1+ vocali) e ':' (0+ consonanti)
local function match_ctx(pat, pi, text, pos, dir)
  if pi < 1 or pi > #pat then return true end
  local p = pat:sub(pi, pi)
  local nexti = pi + dir
  if p == "#" or p == ":" then
    local test = (p == "#") and is_vowel or is_cons
    local n = 0
    local q = pos
    while q >= 1 and q <= #text and test(text:sub(q, q)) do n = n + 1; q = q + dir end
    local minn = (p == "#") and 1 or 0
    for k = n, minn, -1 do
      if match_ctx(pat, nexti, text, pos + k * dir, dir) then return true end
    end
    return false
  end
  local np = match_one(p, text, pos, dir)
  if not np then return false end
  return match_ctx(pat, nexti, text, np, dir)
end

local function match_right(pat, text, pos) return match_ctx(pat, 1, text, pos, 1) end
local function match_left(pat, text, pos) return match_ctx(pat, #pat, text, pos, -1) end

-- parola (maiuscola) -> fonemi astratti
function TTS.word_to_phonemes(word)
  local lw = word:lower()
  if EXCEPT[lw] then
    local ph = {}
    for p in EXCEPT[lw]:gmatch("%S+") do ph[#ph + 1] = p end
    return ph
  end
  local text = " " .. word:upper() .. " "
  local out = {}
  local pos = 2
  while pos <= #text - 1 do
    local ch = text:sub(pos, pos)
    local rules = RULES[ch]
    local matched = false
    if rules then
      for _, r in ipairs(rules) do
        if text:sub(pos, pos + #r.match - 1) == r.match
          and match_left(r.left, text, pos - 1)
          and match_right(r.right, text, pos + #r.match) then
          for _, p in ipairs(r.out) do out[#out + 1] = p end
          pos = pos + #r.match
          matched = true
          break
        end
      end
    end
    if not matched then pos = pos + 1 end
  end
  return out
end

-- fonemi astratti -> allofoni SpeakJet ---------------------------------
local VOW = {IY = true, IH = true, EY = true, EH = true, AE = true, AA = true, AO = true,
             OW = true, UH = true, UW = true, ER = true, AX = true, AH = true, AY = true,
             AW = true, OY = true}
local FRONT = {IY = true, IH = true, EY = true, EH = true, AE = true, AX = true, ER = true, AY = true, Y = true}
local GLIDES = {R = true, L = true, W = true, Y = true}

local VMAP = {IY = 128, IH = 129, EY = 154, EH = 131, AE = 132, AA = 135, AO = 136,
              OW = 164, UH = 138, UW = 139, ER = 151, AX = 133, AH = 134, AY = 155,
              AW = 163, OY = 156}
local RCOLOR = {AA = 152, AO = 153, OW = 153, IH = 149, IY = 149, EH = 150, EY = 150,
                AE = 150, AX = 151, ER = 151}
local SIMPLE = {F = 186, V = 166, TH = 190, DH = 169, Z = 167, SH = 189, ZH = 168,
                M = 140, W = 147, R = 148, CH = 182, JH = 165, WH = 185}

-- prossima vocale (saltando le approssimanti): restituisce fonema o nil
local function next_vowel(ph, i)
  local j = i + 1
  while ph[j] and GLIDES[ph[j]] do j = j + 1 end
  if ph[j] and VOW[ph[j]] then return ph[j] end
  return nil
end

local function prev_vowel(ph, i)
  local j = i - 1
  while ph[j] and not VOW[ph[j]] and ph[j] ~= "|" do j = j - 1 end
  if ph[j] and VOW[ph[j]] then return ph[j] end
  return nil
end

local STOPS = {
  B = {init = {170, 171}, fin = {172, 173}},
  D = {init = {174, 175}, fin = {176, 177}},
  G = {init = {178, 179}, fin = {180, 181}},
  K = {init = {194, 195}, fin = {196, 197}},
  P = {init = {198, 199}, fin = {198, 199}},
}

-- ph: lista di fonemi, con "|" come confine di parola
function TTS.phonemes_to_codes(ph, opts)
  opts = opts or {}
  local out = {}
  local i = 1
  local word_start = true
  while i <= #ph do
    local p = ph[i]
    local nx = ph[i + 1]
    if p == "|" then
      word_start = true
    elseif p == "," then
      out[#out + 1] = 1
    elseif p == "." then
      out[#out + 1] = 2
    elseif VOW[p] then
      if word_start and opts.stress_first then out[#out + 1] = 8 end
      if nx == "R" and RCOLOR[p] then
        out[#out + 1] = RCOLOR[p]
        i = i + 1
      elseif p == "AX" and nx == "L" and (ph[i + 2] == nil or ph[i + 2] == "|") then
        out[#out + 1] = 159 -- EHLL ("little", "saddle")
        i = i + 1
      else
        out[#out + 1] = VMAP[p]
      end
      word_start = false
    elseif p == "Y" then
      if nx == "EH" then out[#out + 1] = 158; i = i + 1
      elseif nx == "UW" then out[#out + 1] = 160; i = i + 1
      else out[#out + 1] = 7; out[#out + 1] = 128 end
    elseif STOPS[p] then
      local nv = next_vowel(ph, i)
      local st = STOPS[p]
      if nv then
        out[#out + 1] = FRONT[nv] and st.init[1] or st.init[2]
      else
        local pv = prev_vowel(ph, i)
        out[#out + 1] = (pv == nil or FRONT[pv]) and st.fin[1] or st.fin[2]
      end
    elseif p == "T" then
      if nx == "S" and (ph[i + 2] == nil or ph[i + 2] == "|") then
        out[#out + 1] = 193; i = i + 1
      elseif next_vowel(ph, i) then
        out[#out + 1] = 192
      else
        out[#out + 1] = 191
      end
    elseif p == "S" then
      local v = next_vowel(ph, i) or prev_vowel(ph, i)
      out[#out + 1] = (v == nil or FRONT[v]) and 187 or 188
    elseif p == "HH" then
      local v = next_vowel(ph, i)
      out[#out + 1] = (v == nil or FRONT[v]) and 183 or 184
    elseif p == "N" then
      local v = (nx and VOW[nx]) and nx or prev_vowel(ph, i)
      out[#out + 1] = (v == nil or FRONT[v]) and 141 or 142
    elseif p == "NG" then
      local v = prev_vowel(ph, i)
      out[#out + 1] = (v == nil or FRONT[v]) and 143 or 144
    elseif p == "L" then
      local v = next_vowel(ph, i)
      out[#out + 1] = (v and FRONT[v]) and 145 or 146
    elseif SIMPLE[p] then
      out[#out + 1] = SIMPLE[p]
    end
    i = i + 1
  end
  return out
end

-- testo completo -> codici
function TTS.text_to_codes(text, opts)
  local ph = {}
  text = text:gsub("(%d)", function(d) return " " .. DIGITS[tonumber(d) + 1] .. " " end)
  for token in text:gmatch("[%a']+[,%.%?!]?") do
    local word, punct = token:match("^([%a']+)([,%.%?!]?)$")
    if #ph > 0 then ph[#ph + 1] = "|" end
    for _, p in ipairs(TTS.word_to_phonemes(word)) do ph[#ph + 1] = p end
    if punct == "," then ph[#ph + 1] = ","
    elseif punct ~= "" then ph[#ph + 1] = "." end
  end
  return TTS.phonemes_to_codes(ph, opts)
end

-- lettere dell'alfabeto (nome della lettera) e cifre --------------------------
TTS.LETTERS = {
  A = {154}, B = {170, 128}, C = {187, 128}, D = {174, 128}, E = {128},
  F = {131, 186}, G = {165, 128}, H = {154, 182}, I = {155}, J = {165, 154},
  K = {194, 154}, L = {131, 159}, M = {131, 140}, N = {131, 141}, O = {164},
  P = {198, 128}, Q = {194, 160}, R = {152}, S = {131, 187}, T = {192, 128},
  U = {160}, V = {166, 128}, W = {175, 134, 171, 159, 160}, X = {131, 196, 187},
  Y = {147, 155}, Z = {167, 128},
}

function TTS.letter_codes(ch)
  ch = ch:upper()
  if TTS.LETTERS[ch] then return TTS.LETTERS[ch] end
  local d = tonumber(ch)
  if d then return TTS.text_to_codes(DIGITS[d + 1]) end
  return {}
end

return TTS
