-- vocab.lua
-- Vocabolario inglese suddiviso per lettera (~3000 parole), pronunciate dal
-- TTS (lib/tts.lua). Liste ordinate e deduplicate al caricamento.
-- Per aggiungere parole basta scriverle nella stringa della lettera.

local RAW = {
A = [[a able about above absolute absorb abstract accent accept access accident account ace acid acoustic across act action active actor actual adapt add address admire adult advance adventure advice aerial affair afraid africa after afternoon again against age agent ago agree ahead aid aim air airplane airport alarm album alert alien alive all alley allow almost alone along alpha already also alter always amazing amber ambient america amount amp amplifier analog anchor ancient and android angel anger angle angry animal ankle answer ant antenna any anyone anything apart apartment ape apple april arc arch area arena argue arm armor army around arrive arrow art artist ash ask asleep atom attack attention audio august aunt author auto autumn avenue avoid awake away axis]],
B = [[baby back backbeat bad badge bag bake balance ball balloon banana band bang bank bar bark barrel base basic basket bass bat bath battery battle bay beach beam bean bear beard beast beat beautiful beauty because become bed bee beef beer before begin behind believe bell belly below belt bench bend beneath berry best bet better between beyond bicycle big bike bill bind bird birth biscuit bit bite bitter black blade blame blank blast blaze bleed blend bless blind blink block blood bloom blow blue blues blur board boat body boil bold bolt bomb bond bone bonus book boom boost boot border bored born borrow boss both bottle bottom bounce bow bowl box boy brain brake branch brass brave bread break breath breeze brick bridge brief bright bring broad broken bronze brother brown brush bubble bucket buddy budget bug build bulb bullet bump bunch burn burst bury bus bush business busy but butter button buy buzz bye]],
C = [[cab cabin cable cage cake calculate call calm camera camp can canal cancel candle candy cannon canvas cap capital captain car carbon card care career careful carpet carry cart case cash cast castle cat catch cause cave ceiling cell cello center central century chain chair chalk challenge champion chance change channel chaos chapter charge charm chart chase cheap check cheek cheese chef chemical cherry chess chest chicken chief child chill chip chocolate choice choir choose chop chord chorus church circle circuit city claim clap class classic clean clear clever click cliff climb clip clock close cloth cloud clown club clue coach coal coast coat code coffee coin cold collect color column comb combine come comedy comet comfort comic command common company compare complete computer concert condition connect control cook cool copper copy coral core corn corner correct cosmic cost cotton couch count country couple courage course cousin cover cow crab crack craft crash crazy cream create creature credit crew crime crisp critic crop cross crowd crown crucial cruel crush cry crystal cube culture cup cupboard curious current curtain curve cushion custom cut cute cycle cyber cymbal]],
D = [[dad daily damage damp dance danger dare dark darling dash data date daughter dawn day dead deal dear death debate decade december decide deck decline deep deer defend define degree delay delete deliver demand demo denial dense dentist deny depart depth describe desert design desk detail detect develop device devil diagram dial diamond diary dice dictionary die diet differ digital dignity dim dinner dinosaur direct dirt dirty disco discover disease dish disk display distance distant dive divide dizzy doctor document dog doll dollar dolphin domain donkey door dot double doubt down dozen draft dragon drama draw dream dress drift drill drink drip drive drone drop drum dry duck dull dune during dusk dust duty dwarf dynamic dynamo]],
E = [[each eager eagle ear early earn earth ease east easy eat echo eclipse economy edge edit effect effort egg eight eighteen eighty either elbow elder electric electron electronic element elephant elevator eleven else email embrace emerge emotion empty enable end enemy energy engine enjoy enormous enough enter entire entry envelope equal equalizer equator era erase error escape essay estate eternal even evening event ever every evidence evil exact example excellent except exchange excite excuse exercise exhaust exist exit exotic expand expect expert explain explode explore export express extra extreme eye eyebrow]],
F = [[fabric face fact factory fade fail faint fair fairy faith fake fall false fame family famous fan fancy fantasy far farm fashion fast fat fate father fault favorite fear feast feather february feed feel fellow female fence festival fetch fever few fiber fiction field fierce fifteen fifth fifty fight figure file fill film filter final find fine finger finish fire firm first fish fist fit five fix flag flame flash flat flavor flight float flock flood floor flow flower fluid flute fly foam focus fog fold folk follow food fool foot force forest forever forget fork form fortune forty forward fossil found fountain four fourteen fox fragile frame free freeze frequency fresh friday friend frog from front frost frozen fruit fuel full fun funk funny fur future fuzz]],
G = [[gadget gain galaxy gallery game gamma gang gap garage garden garlic gas gate gather gear gem general gentle genius ghost giant gift giggle ginger giraffe girl give glad glance glass glide glimpse glitch globe gloom glory glove glow glue goal goat gold golden golf gone good goodbye goose gorilla gospel gossip govern grab grace grade grain gram grand grandma grandpa grape graph grass grave gravity gray great green greet grid grief grill grin grip groove ground group grow growl guard guess guest guide guilt guitar gum gun guru gut guy gym]],
H = [[habit hair half hall halt hammer hand handle happen happy harbor hard harm harmony harp harvest hat hate have hawk hazard head health hear heart heat heaven heavy hedge heel height helicopter hello helmet help hen her herb here hero hidden hide high hill hint hip hire history hit hobby hold hole holiday hollow holy home honest honey hook hope horizon horn horror horse hospital host hot hotel hour house hover how huge human humble humor hundred hunger hunt hurry hurt husband hut hybrid hydrogen hymn hyper hypnotic]],
I = [[ice icon idea identify idle ignore ill image imagine impact impulse inch include income increase index indoor industry infant infinite inform inner input insane insect inside inspire install instant instrument intense interest interface internet into invent invisible invite iron island issue item ivory]],
J = [[jacket jaguar jail jam january jar jazz jealous jeans jelly jet jewel job join joke journey joy judge juice july jump jungle june junior junk jupiter just justice]],
K = [[kangaroo keen keep kernel kettle key keyboard kick kid kidney kill kilo kind king kingdom kiss kit kitchen kite kitten knee knife knight knock knot know koala]],
L = [[lab label labor lady lake lamp land lane language laptop large laser last late later laugh launch lava law lawn layer lazy lead leader leaf learn leather leave left leg legal legend lemon lend length lens leopard lesson letter level liar liberty library license lid lie life lift light like limb limit line link lion lip liquid list listen little live lizard load loan lobster local lock logic lonely long loop loose lord lose loss lost loud lounge love lovely low loyal lucky lullaby lunar lunch lung luxury lyrics]],
M = [[machine mad magic magnet maid mail main major make male mammal man manage mango manual many map marble march margin marine mark market marry mars mask mass master match material math matrix matter maximum maybe meadow meal mean measure meat mechanic medal media medicine medium meet melody melt member memory menu mercury mercy merge message metal meteor method metro micro middle midnight milk million mind mineral minimum minor minute miracle mirror misery miss mist mix mixer mobile mode model modern modular module moment monday money monitor monkey monster month mood moon moral more morning mosquito mother motion motor mountain mouse mouth move movie much mud multiply muscle museum mushroom music must mute mutual my mystery myth]],
N = [[nail name narrow nation native nature navy near neck need needle negative neighbor neither neon nerve nest net network neutral never new news next nice night nine nineteen ninety noble nobody noise none noodle normal north nose not note nothing notice novel november now nuclear number nurse nut]],
O = [[oak oasis obey object ocean october octopus odd off offer office often oil okay old olive omega once one onion online only open opera opinion orange orbit orchestra order organ origin orphan oscillator other outer output outside oval oven over own owner oxygen oyster]],
P = [[pace pack package paddle page pain paint pair palace palm pan panda panel panic paper parade parent park parrot part party pass past patch path patient pattern pause pay peace peach peak pear pearl pen pencil penguin people pepper perfect permit person pet phase phone photo phrase piano pick picture piece pig pigeon pill pilot pin pink pioneer pipe pistol pitch pixel pizza place planet plant plastic plate play player please pleasure plenty plot plug plus pocket poem poet point poison polar pole police polite pond pony pool poor pop popular portal position possible post pot potato pottery poverty powder power practice praise predict prefer prepare present pretty prevent price pride primary prince princess print prison private prize problem process produce profit program project promise proof proper protect proud prove public pull pulse pump punch pupil puppet puppy purple purpose push puzzle pyramid]],
Q = [[quality quantum quarter queen query quest question quick quiet quilt quit quite quiz quote]],
R = [[rabbit race rack radar radio rage rail rain rainbow raise rally ramp ranch random range rank rapid rare rat rate raven raw ray razor reach react read ready real reason rebel recall receive recipe record recycle red reduce reflect refuse region regret relax release remain remember remind remote remove render rent repair repeat replace reply report rescue resist resonance rest result retro return reveal reverb review reward rhythm rib ribbon rice rich ride ridge rifle right ring riot ripple rise risk ritual rival river road roast robot rock rocket romance roof room root rope rose rotate rough round route royal rubber rude rug rule run rural rush rust]],
S = [[sad saddle safe sail salad salmon salt same sample sand satellite satisfy saturday sauce save saw say scale scan scare scatter scene scheme school science scissors score scout scream screen script sea search season seat second secret section security seed seek segment select sell send senior sense sentence september sequence series serious serve session set settle seven seventeen seventy shadow shake shallow shape share shark sharp shed sheep shelf shell shield shift shine ship shirt shock shoe shoot shop short shoulder shout show shower shrimp shuffle shy sick side siege sight signal silence silent silk silly silver similar simple since sing siren sister sit six sixteen sixty size skate sketch ski skill skin skirt skull sky slam sleep slice slide slim slogan slot slow small smart smile smoke smooth snack snake snap sneeze snow soap soccer social sock soda soft solar soldier solid solo solution solve some son song sonic soon sorry sort soul sound soup source south space spare spark speak special speed spell spend sphere spice spider spike spin spirit split sponge spoon sport spot spray spread spring spy square squeeze squirrel stable stadium staff stage stairs stamp stand star start state station stay steak steel stem step stereo stick still sting stock stomach stone stool story stove strange strategy straw stream street strike strong struggle student stuff stumble style subject submarine subway success such sudden sugar suit summer sun sunday sunny sunset super supply supreme sure surface surge surprise surround survey suspect swallow swamp swap swarm swear sweet swift swim swing switch sword symbol symptom synth synthesizer syrup system]],
T = [[table tackle tag tail talent talk tank tape target task taste tattoo taxi tea teach team tear technology techno teeth telephone television tell tempo ten tenant tennis tent term test text thank that theme then theory there they thing this thought three thrive throw thumb thunder thursday ticket tide tiger tilt timber time tiny tip tired tissue title toast tobacco today toddler toe together toilet token tomato tomorrow tone tongue tonight tool tooth top topic torch tornado tortoise toss total tourist toward tower town toy track trade traffic tragic train transfer trap trash travel tray treat tree trend trial tribe trick trigger trim trip trophy trouble truck true truly trumpet trust truth try tube tuesday tumble tuna tunnel turbo turkey turn turtle twelve twenty twice twin twist two type typical]],
U = [[ugly umbrella unable uncle under undo unfair unfold unhappy uniform unique unit universe unknown unlock until unusual unveil update upgrade uphold upon upper upset urban urge usage use used useful useless usual utility]],
V = [[vacant vacuum vague valid valley valve van vanish vapor various vast vault vector velvet vendor venture venus verb verify version very vessel veteran viable vibe vibrant vicious victory video view village vintage vinyl violin virtual virus visa visit visual vital vivid vocal vocoder voice void volcano volume vote voyage]],
W = [[wage wagon wait walk wall walnut want warfare warm warrior wash wasp waste water wave way wealth weapon wear weasel weather web wedding wednesday weekend weird welcome west wet whale what wheat wheel when where whip whisper white who whole why wide width wife wild will win window wine wing wink winner winter wire wisdom wise wish witness wolf woman wonder wood wool word work world worry worth wrap wreck wrestle wrist write wrong]],
X = [[xenon xerox xylophone]],
Y = [[yacht yard yawn year yell yellow yes yesterday yet yoga yogurt young youth yummy]],
Z = [[zap zebra zenith zero zigzag zinc zipper zodiac zombie zone zoo zoom]],
}

-- parole aggiunte in una seconda passata (piu' comuni e "da synth")
local EXTRA = [[
able absent acid action airlock alarm alien amp analog anthem apollo arcade arpeggio asteroid astronaut atomic aurora automatic
baby backup bandit barcode baritone bass bassline battery bazooka beacon beam beat beep bingo bionic bleep blip bliss blizzard boogie bounce brother buffer bunker
cadet calibrate capsule cassette catalyst chamber chime chopper chrome cipher clone cobalt cockpit command comet commander compass console contact cosmos countdown crater crystal cyborg
dancer database decoder delta destroy detector dial diode disco distortion doom drone drummer dub dubstep dynamite
earthquake echo eject electro emergency empire encoder energy engage enigma epic exodus explosion
fader falcon feedback fever filter flanger flux frequency funky fusion fuzz
gadget galactic gamma gear genesis glitch glow gong gravity groove guardian
hacker halo hangar harmonica headphone helium hertz hologram horizon hyperspace
ignition infrared ion
jackpot jetpack joystick jukebox
kaleidoscope karaoke kilobyte
laser launch lever lightning liquid loop lunar
machine magnet mainframe matrix mayday megabyte meltdown microphone midi mission modem module monome monolith
nebula neon neutron nitro noise norns nova
octave omega orbit oscillator overdrive
pager panic payload phantom phaser photon pilot pixel plasma plutonium polar portal power pressure prism probe processor proton pulsar pulse
quasar
radar radiation radio ranger reactor receiver relay remix replay resistor retro reverb rewind rhythm riff robot rocket rover
sabotage sampler satellite scanner sector sensor sequencer shuttle signal silicon siren sonar space spaceship spectrum speaker static station stereo strobe sub subwoofer supernova surge synthesizer system
tape target techno telescope tempo terminal theremin thunder titan token tone transistor transmission transmitter treble trigger tuner turbo
ultra ultrasonic unit uplink uranium
vacuum vector velocity vinyl virus visor vocoder voltage vortex
warning warp watt wave waveform wireless
xray
yes
zero zone
afternoon although amazing among animal another answer anything apartment appear around arrive asleep
beautiful became become before began begin behind being believe below beside between birthday blanket body bought brain bread breakfast bring brother brought building
called came cannot careful carry catch caught certain change children chocolate city close clothes coming continue could country course cover
daughter decide different dinner doctor does doing dollar door during
early earth easy either enough evening every everybody everyone everything exactly
family famous father feeling finally finger finish flower follow forget forward friend front
garden gentle getting given going gone great ground grown
happen happy heard heavy hello holiday hour house however hungry husband
idea important inside instead island
journey judge kitchen knew knowledge
language large later laugh learn leave letter listen little lived lonely lovely
making married matter maybe measure middle minute moment money morning mother mountain music myself
nature nearly never nothing number
often once only opened orange other outside
paper parent party people perhaps person picture piece place please pocket police pretty problem promise pull purple
question quickly quiet rather reach really reason remember river round
school second seven several shadow should sister sleep slowly smile someone something sometimes somewhere special square start still story strange street strong student suddenly summer sunshine sure surprise
table taught teacher telephone thing think thirty thought thousand through today together tomorrow tonight toward travel trouble true
uncle under understand until usually
village visit voice wait walk wanted warm watch water weather welcome whatever where whether which while whisper white whole window winter without woman women wonderful word world would write wrong
yellow yesterday young
]]

local EXTRA2 = [[
abandon academy accuse ache acre adjust admit adopt adore affect afford agenda alarm alcohol alley almond aloud alphabet amateur ambition ambush amuse angel annual antique anxiety apology appeal appetite applause approve apron aquarium arcade arctic armchair aroma arrest arrival asset assist athlete atlas attic attract auction audience autograph avocado award awesome awful axe
backpack bacon badly bakery bamboo bandage banjo banner barber bargain barn baron basement bathroom beaver bedroom beetle beggar behave belief beloved benefit biology biscuit bishop blanket blender blossom blouse blueprint bodyguard boiler bonfire boredom boulder bouquet boxer bracelet brainstorm breakfast bribe bride broccoli broom brunch buffalo bulldozer bullet bundle burger burglar butterfly
cactus calendar camel campaign candle cannon canyon capacity caramel caravan cardboard carnival carrot cartoon casino catalog cathedral cattle caution celebrate celery cement cereal champagne charity cheerful chimney chipmunk cinnamon citizen civil clarinet clay clinic closet cocoa coconut coffin collar collapse colony comfortable comma compact compose concrete confess confuse congress consider constant contest cookie corridor cosmetic costume cottage counter coupon cowboy coyote cradle crane crayon creek cricket crisis crocodile cruise crumb crunch cuddle cupcake curry cursor
dairy daisy dandelion dancer deadline debt decent decimal decorate dedicate defeat delicate delight denim deposit deputy desire dessert destiny diesel digest dinosaur diploma disaster discount dismiss distant divorce dizzy dodge dolphin donut dough dragonfly drawer dresser drizzle drowsy drummer dryer dumpling dungeon dynasty
earring easel eastern eccentric eel effort elastic elegant elevate elf embassy empire enchant endless engineer enormous entrance envy episode equip eraser erupt evolve exam excuse exhibit exile expense explain expose extend
fable fabulous facial faculty falcon fantastic farmer fasten fault feeble fern ferry fiddle fiesta fig firework flamingo flannel flashlight flavor flexible flipper florist fluffy foggy foil footprint forehead fork formula fragment freckle freezer frighten fringe frosting frown fudge furnace furniture
gallon gambler gargoyle garlic gazelle generous gentleman geography gesture gingerbread glacier glamour gloomy goblin goggles gondola gorgeous gourmet graceful grammar granite grapefruit grasshopper gravel greedy greenhouse grizzly grocery grumpy guardian guilty gutter
haircut hairdryer halfway hallway hamburger hammock hamster handbag handsome hanger harbor hardware harmless hatch haunted hazelnut headache headline hedgehog hiccup highway hiking hippo hitchhike homework hopeful horrible horseshoe hostage hostile hug hummingbird hurricane hyena
iceberg icicle igloo illegal illness illusion immune impress improve incense independent indigo inferno inhale inherit injury inkwell innocent insult intimate invasion invoice iris irony itch
jackal jaguar jasmine javelin jellyfish jigsaw jockey jogging journal jovial jubilee juggle jumbo
kayak kebab ketchup keyhole kidnap kindness kiosk knapsack knitting knuckle
ladder ladybug lagoon lantern lasagna latitude laundry lavender leash lecture leftover lemonade leopard lettuce lever lifeguard lighthouse lilac limousine linen lipstick litter lobby locker locust lollipop longitude lottery lumber lunatic
macaroni magician magnify mailbox mammoth mansion marathon marmalade marshmallow mascot massive mattress mayor meatball mechanic megaphone melon mermaid microscope microwave milkshake mimic minister minnow mischief moccasin molasses mongoose moose mosaic motel mountain muffin mumble mummy mustard mutant
napkin narrator necklace nectar negotiate nephew nervous newspaper nickel niece nightmare nimble nitrogen nostril nougat nugget nursery nutmeg
oatmeal obelisk observe obstacle octagon odyssey omelet opponent optimist oracle orbit orchid ornament ostrich otter outfit outlaw overcoat owl
paddle padlock pajamas palette pamphlet pancake panther papaya parachute paradise paragraph parsley passenger passport pastry peacock peanut pebble pedal pelican pendulum peppermint perfume periscope pharaoh pheasant pickle picnic pilgrim pineapple pinwheel pirate pistachio plankton platinum platypus playground plumber poodle popcorn porcupine porridge postcard poster pretzel professor propeller pudding pumpkin puppet python
quail quarrel quartz queasy quicksand quiver
raccoon radish raffle railroad raisin rattlesnake recess reindeer reptile rhino riddle robin rodeo rooster rosemary rumble runway
saddle saffron salamander salsa sandal sandwich sardine sausage saxophone scarecrow scarf scorpion scooter seagull seahorse seashell sedan shampoo shamrock shepherd sherbet shipwreck shrub skeleton skyline skyscraper sledge slipper sloth snail snowflake snowman soldier sombrero souvenir spaghetti sparrow spatula spinach sprinkle squid stallion starfish stingray strawberry submarine sunflower swan sweater
tadpole tambourine tangerine tarantula teapot teaspoon telescope temple termite thimble thistle thunderbolt toaster toboggan toothbrush tornado toucan tractor trampoline treasure triangle tricycle trombone trumpet tulip turnip tuxedo twilight
ukulele unicorn unicycle utensil
vampire vanilla vegetable velvet vinegar violet volcano vulture
waffle waiter walrus wardrobe warehouse wasabi watermelon weasel werewolf wheelbarrow whirlpool whistle wigwam windmill wizard woodpecker
yodel yoyo
zeppelin zucchini
]]

local V = {}
V.letters = {}
V.by_letter = {}
V.all = {}

local seen = {}
local function add(w)
  w = w:lower()
  if w == "" or seen[w] then return end
  local l = w:sub(1, 1):upper()
  if not l:match("%a") then return end
  seen[w] = true
  V.by_letter[l] = V.by_letter[l] or {}
  table.insert(V.by_letter[l], w)
end

for _, s in pairs(RAW) do for w in s:gmatch("[%a']+") do add(w) end end
for w in EXTRA:gmatch("[%a']+") do add(w) end
for w in EXTRA2:gmatch("[%a']+") do add(w) end

local MORE = include("lib/vocab_more")
for w in MORE.words:gmatch("[%a']+") do add(w) end
V.themes = {}
for _, th in ipairs(MORE.themes) do
  local list = {}
  for raw in th[2]:gmatch("[%a']+") do
    local w = raw:lower()
    list[#list + 1] = w
    add(w)
  end
  V.themes[#V.themes + 1] = {name = th[1], words = list}
end
V.phrases = MORE.phrases

for c = 65, 90 do
  local l = string.char(c)
  local list = V.by_letter[l] or {}
  table.sort(list)
  V.by_letter[l] = list
  V.letters[#V.letters + 1] = l
  for _, w in ipairs(list) do V.all[#V.all + 1] = {word = w, letter = l} end
end

-- indice della prima parola di ogni lettera dentro V.all
V.first = {}
for i, e in ipairs(V.all) do
  if not V.first[e.letter] then V.first[e.letter] = i end
end

V.count = #V.all

-- parola -> indice in V.all
V.index = {}
for i, e in ipairs(V.all) do V.index[e.word] = i end

return V
