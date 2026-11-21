-- syll.lua
-- Tastiera di sillabe: consonante iniziale + vocale + consonante finale.
-- Le varianti SpeakJet (BE/BO, KE/KO, EB/OB, SE/SO, ...) vengono scelte
-- automaticamente in base alla vocale, come suggerisce il manuale.

local A = include("lib/allophones")

local Y = {}

-- consonanti iniziali: {nome, codice anteriore, codice posteriore}
Y.ONSETS = {
  {"B", 170, 171}, {"D", 174, 175}, {"G", 178, 179}, {"K", 194, 195},
  {"P", 198, 199}, {"T", 192, 192}, {"CH", 182, 182}, {"J", 165, 165},
  {"F", 186, 186}, {"V", 166, 166}, {"TH", 190, 190}, {"DH", 169, 169},
  {"S", 187, 188}, {"Z", 167, 167}, {"SH", 189, 189}, {"ZH", 168, 168},
  {"H", 183, 184}, {"M", 140, 140}, {"N", 141, 142}, {"L", 145, 146},
  {"R", 148, 148}, {"W", 147, 147}, {"WH", 185, 185}, {"Y", 128, 128},
}

-- vocali / dittonghi (32 tasti)
Y.NUCLEI = {
  {"IY", 128}, {"IH", 129}, {"EY", 130}, {"EH", 131}, {"AE", 132}, {"AX", 133},
  {"UX", 134}, {"OH", 135}, {"AW", 136}, {"OW", 137}, {"UH", 138}, {"UW", 139},
  {"EYIY", 154}, {"OHIY", 155}, {"OWIY", 156}, {"OHIH", 157},
  {"IYEH", 158}, {"IYUW", 160}, {"AXUW", 161}, {"IHWW", 162}, {"AYWW", 163}, {"OWWW", 164},
  {"IYRR", 149}, {"EYRR", 150}, {"AXRR", 151}, {"AWRR", 152}, {"OWRR", 153}, {"EHLL", 159},
  {"MM", 140}, {"NE", 141}, {"LE", 145}, {"RR", 148},
}

-- consonanti finali: {nome, codice dopo vocale anteriore, dopo posteriore}
Y.CODAS = {
  {"B", 172, 173}, {"D", 176, 177}, {"G", 180, 181}, {"K", 196, 197},
  {"P", 198, 199}, {"T", 191, 191}, {"TS", 193, 193}, {"CH", 182, 182},
  {"F", 186, 186}, {"S", 187, 188}, {"Z", 167, 167}, {"SH", 189, 189},
  {"M", 140, 140}, {"N", 141, 142}, {"NG", 143, 144}, {"L", 159, 146},
}

local function front(code)
  return A.FRONT[code] == true
end

-- onset / coda possono essere nil
function Y.build(onset, nucleus, coda)
  local codes = {}
  local nc = nucleus and Y.NUCLEI[nucleus][2]
  local f = true
  if nc then f = front(nc) end
  local label = ""
  if onset then
    local o = Y.ONSETS[onset]
    if o[1] == "Y" then
      codes[#codes + 1] = 7
      codes[#codes + 1] = 128
    else
      codes[#codes + 1] = f and o[2] or o[3]
    end
    label = label .. o[1]
  end
  if nc then
    codes[#codes + 1] = nc
    label = label .. Y.NUCLEI[nucleus][1]
  end
  if coda then
    local c = Y.CODAS[coda]
    codes[#codes + 1] = f and c[2] or c[3]
    label = label .. "-" .. c[1]
  end
  return codes, label:lower()
end

return Y
