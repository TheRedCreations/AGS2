---@diagnostic disable: undefined-global, undefined-field
-- ===============================
-- ADDRESS EDITOR
-- For adding and editing Gate Entries
-- ===============================

local args = {...}
local mode = args[1] or "add"
local editIndex = tonumber(args[2])

local gateEntries = dofile("GateEntries.ff")

local symbolsMW = {"Point of Origin", "Andromeda", "Aquarius", "Aries", "Auriga", "Bootes", "Cancer", "Canis Minor", "Capricornus", "Centaurus", "Cetus", "Corona Australis", "Crater", "Equuleus", "Eridanus", "Gemini", "Hydra", "Leo", "Leo Minor", "Libra", "Lynx", "Microscopium", "Monoceros", "Norma", "Orion", "Pegasus", "Perseus", "Pisces", "Piscis Austrinus", "Sagittarius", "Scorpius", "Sculptor", "Scutum", "Serpens Caput", "Sextans", "Taurus", "Triangulum", "Virgo"}

local symbolsPG = {"Subido", "Aaxel", "Abrin", "Acjesis", "Aldeni", "Alura", "Amiwill", "Arami", "Avoniv", "Baselai", "Bydo", "Ca Po", "Danami", "Dawnre", "Ecrumig", "Elenami", "Gilltin", "Hacemill", "Hamlinto", "Illume", "Laylox", "Lenchan", "Olavii", "Once El", "Poco Re", "Ramnon", "Recktic", "Robandus", "Roehi", "Salma", "Sandovi", "Setas", "Sibbron", "Tahnan", "Zamilloz", "Zeo"}

local symbolsUN = {"17", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36"}

local entryName = ""
local slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8, slot9 = "", "", "", "", "", "", "", "", ""
local entryIDC = ""
local stargate = peripheral.find("stargate")
local currentGateType = "MilkyWay"
local inputMode = "name"
local editing = true

-- Speichere alle Adresstypen
local savedMW = {}
local savedPG = {}
local savedUN = {}

local monitor = peripheral.find("monitor")
if not monitor then
  error("Kein Monitor gefunden!")
end

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

local mw, mh = monitor.getSize()

local function getFirstSymbol(gateType)
  if gateType == "MilkyWay" then return "Point of Origin"
  elseif gateType == "Pegasus" then return "Subido"
  elseif gateType == "Universe" then return "17"
  end
  return "Point of Origin"
end

local function saveGateEntries()
  local file = fs.open("GateEntries.ff", "w")
  file.write("-- Gate Entries Database\n")
  file.write("-- Struktur: name, mw (MilkyWay), pg (Pegasus), un (Universe), idc (ID Code)\n\n")
  
  local addressArray = {slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8, slot9}
  
  local newEntry = {
    name = entryName,
    mw = {},
    pg = {},
    un = {},
    idc = entryIDC
  }
  
  local gt = string.lower(currentGateType)
  if gt == "milkyway" then
    newEntry.mw = addressArray
    newEntry.pg = savedPG
    newEntry.un = savedUN
  elseif gt == "pegasus" then
    newEntry.pg = addressArray
    newEntry.mw = savedMW
    newEntry.un = savedUN
  elseif gt == "universe" then
    newEntry.un = addressArray
    newEntry.mw = savedMW
    newEntry.pg = savedPG
  else
    newEntry.mw = savedMW
    newEntry.pg = savedPG
    newEntry.un = savedUN
  end
  
  if mode == "add" then
    table.insert(gateEntries, newEntry)
  elseif mode == "edit" and editIndex then
    gateEntries[editIndex] = newEntry
  end
  
  file.write("return " .. textutils.serialize(gateEntries) .. "\n")
  file.close()
end

local function box(x, y, w, h, title)
  monitor.setCursorPos(x, y)
  monitor.write("+" .. string.rep("-", w-2) .. "+")
  for i=1,h-2 do
    monitor.setCursorPos(x, y+i)
    monitor.write("|" .. string.rep(" ", w-2) .. "|")
  end
  monitor.setCursorPos(x, y+h-1)
  monitor.write("+" .. string.rep("-", w-2) .. "+")
  if title then
    monitor.setCursorPos(x+1, y)
    monitor.write(title)
  end
end

local function button(x, y, w, label, textc)
  monitor.setTextColor(textc)
  monitor.setCursorPos(x,y)
  monitor.write("[" .. label .. string.rep(" ", w-#label-2) .. "]")
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
end

local function getSymbolsForType(gateType)
  if gateType == "MilkyWay" then return symbolsMW
  elseif gateType == "Pegasus" then return symbolsPG
  elseif gateType == "Universe" then return symbolsUN
  end
  return symbolsMW
end

local function drawHeader()
  monitor.setBackgroundColor(colors.black)
  monitor.clear()
  box(1,1,mw,3, mode == "add" and "=== ADD NEW ENTRY ===" or "=== EDIT ENTRY ===")
end

local function drawNameInput()
  box(1,4,mw,3,"Name:")
  monitor.setCursorPos(2,5)
  monitor.setTextColor(inputMode == "name" and colors.lime or colors.white)
  monitor.write(entryName .. "_")
  monitor.setTextColor(colors.white)
end

local function drawIDCInput()
  box(1,7,mw,3,"ID Code:")
  monitor.setCursorPos(2,8)
  monitor.setTextColor(inputMode == "idc" and colors.lime or colors.white)
  monitor.write(entryIDC .. "_")
  monitor.setTextColor(colors.white)
end

local function drawGateTypeSelector()
  box(1,10,mw,3,"Gate Type:")
  local x = 2
  local types = {"MilkyWay", "Pegasus", "Universe"}
  for i, gtype in ipairs(types) do
    monitor.setCursorPos(x, 11)
    if currentGateType == gtype then
      monitor.setTextColor(colors.lime)
    else
      local hasOther = false
      if gtype == "MilkyWay" and #savedMW > 0 then hasOther = true
      elseif gtype == "Pegasus" and #savedPG > 0 then hasOther = true
      elseif gtype == "Universe" and #savedUN > 0 then hasOther = true
      end
      monitor.setTextColor(hasOther and colors.yellow or colors.white)
    end
    monitor.write("[" .. gtype .. "] ")
    x = x + #gtype + 3
  end
  monitor.setTextColor(colors.white)
end

local function drawSlots()
  box(1,12,mw,5,"Address Slots (1-9):")
  
  local slots = {slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8, slot9}
  local colorslots = {colors.cyan, colors.cyan, colors.cyan, colors.cyan, colors.cyan, colors.cyan, colors.yellow, colors.yellow, colors.lime}
  
  for i=1,6 do
    monitor.setCursorPos(2 + (i-1)*12, 13)
    monitor.setTextColor(slots[i] ~= "" and colorslots[i] or colors.gray)
    monitor.write("["..i.."]"..(slots[i] ~= "" and string.sub(slots[i],1,8) or "----"))
  end
  for i=7,8 do
    monitor.setCursorPos(2 + (i-7)*12, 14)
    monitor.setTextColor(slots[i] ~= "" and colorslots[i] or colors.gray)
    monitor.write("["..i.."]"..(slots[i] ~= "" and string.sub(slots[i],1,8) or "----"))
  end
  monitor.setCursorPos(2, 15)
  monitor.setTextColor(colors.lime)
  monitor.write("[9]"..string.sub(slot9,1,15))
  monitor.setTextColor(colors.white)
end

local function drawSymbols()
  local yStart = 17
  local h = 14
  box(1, yStart, mw, h, "Select Symbol:")
  
  local symbols = getSymbolsForType(currentGateType)
  local cols = 3
  local colWidth = math.floor((mw - 4) / cols)
  
  for i, sym in ipairs(symbols) do
    local col = (i - 1) % cols
    local row = yStart + math.floor((i - 1) / cols) + 1
    
    if row < yStart + h - 1 then
      local xPos = 2 + col * colWidth
      monitor.setCursorPos(xPos, row)
      
      local used = (slot1 == sym or slot2 == sym or slot3 == sym or slot4 == sym or slot5 == sym or slot6 == sym or slot7 == sym or slot8 == sym or slot9 == sym)
      
      monitor.setTextColor(used and colors.green or colors.white)
      monitor.write(used and "[X]" or "[ ]")
      monitor.write(" " .. string.sub(sym, 1, colWidth - 5))
    end
  end
  monitor.setTextColor(colors.white)
end

local function drawButtons()
  local btnY = mh - 1
  button(2, btnY, 6, "Save", colors.green)
  button(9, btnY, 6, "Clear", colors.orange)
  button(17, btnY, 16, "Import from Gate", colors.blue)
  if mode == "edit" then
    button(36, btnY, 8, "Delete", colors.red)
    button(45, btnY, 6, "Cancel", colors.white)
  else
    button(36, btnY, 6, "Cancel", colors.white)
  end
end

local function drawUI()
  drawHeader()
  drawNameInput()
  drawIDCInput()
  drawGateTypeSelector()
  drawSlots()
  drawSymbols()
  drawButtons()
end

local function importFromGate()
  if not stargate then
    monitor.setCursorPos(21, 2)
    monitor.setTextColor(colors.red)
    monitor.write("No Stargate!")
    monitor.setTextColor(colors.white)
    sleep(1.5)
    monitor.setCursorPos(21, 2)
    monitor.write(string.rep(" ", 20))
    return
  end
  
  local address = stargate.getDialedAddress()
  if not address or #address == 0 then
    monitor.setCursorPos(21, 2)
    monitor.setTextColor(colors.red)
    monitor.write("No address!")
    monitor.setTextColor(colors.white)
    sleep(1.5)
    monitor.setCursorPos(21, 2)
    monitor.write(string.rep(" ", 20))
    return
  end
  
  local detectedType = stargate.getSymbolType()
  local addressSymbols = {}
  
  for i, symbol in ipairs(address) do
    table.insert(addressSymbols, tostring(symbol))
  end
  
  currentGateType = detectedType
  slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8 = "", "", "", "", "", "", "", ""
  
  for i = 1, math.min(#addressSymbols, 9) do
    if i == 1 then slot1 = addressSymbols[i]
    elseif i == 2 then slot2 = addressSymbols[i]
    elseif i == 3 then slot3 = addressSymbols[i]
    elseif i == 4 then slot4 = addressSymbols[i]
    elseif i == 5 then slot5 = addressSymbols[i]
    elseif i == 6 then slot6 = addressSymbols[i]
    elseif i == 7 then slot7 = addressSymbols[i]
    elseif i == 8 then slot8 = addressSymbols[i]
    elseif i == 9 then slot9 = addressSymbols[i]
    end
  end
  
  if detectedType == "MilkyWay" and slot9 == "" then
    slot9 = getFirstSymbol(detectedType)
  end
  
  drawGateTypeSelector()
  drawSlots()
  drawSymbols()
  
  monitor.setCursorPos(21, 2)
  monitor.setTextColor(colors.green)
  monitor.write("Imported!")
  monitor.setTextColor(colors.white)
  sleep(1)
  monitor.setCursorPos(21, 2)
  monitor.write(string.rep(" ", 20))
end

if mode == "edit" and editIndex and gateEntries[editIndex] then
  local entry = gateEntries[editIndex]
  entryName = entry.name or ""
  entryIDC = entry.idc or ""
  
  savedMW = entry.mw or {}
  savedPG = entry.pg or {}
  savedUN = entry.un or {}
  
  local addr = {}
  if entry.mw and #entry.mw > 0 then
    currentGateType = "MilkyWay"
    addr = entry.mw
  elseif entry.pg and #entry.pg > 0 then
    currentGateType = "Pegasus"
    addr = entry.pg
  elseif entry.un and #entry.un > 0 then
    currentGateType = "Universe"
    addr = entry.un
  end
  
  slot9 = addr[#addr] or getFirstSymbol(currentGateType)
  for i=1,math.min(#addr-1,8) do
    if i==1 then slot1=addr[i] elseif i==2 then slot2=addr[i] elseif i==3 then slot3=addr[i] elseif i==4 then slot4=addr[i] elseif i==5 then slot5=addr[i] elseif i==6 then slot6=addr[i] elseif i==7 then slot7=addr[i] elseif i==8 then slot8=addr[i] end
  end
else
  slot9 = getFirstSymbol(currentGateType)
end

-- Speichere die aktuelle Adresse in das richtige Array
local function saveCurrentToTemp()
  local addressArray = {slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8, slot9}
  local gt = string.lower(currentGateType)
  if gt == "milkyway" then
    savedMW = addressArray
  elseif gt == "pegasus" then
    savedPG = addressArray
  elseif gt == "universe" then
    savedUN = addressArray
  end
end

local function handleTouch(x, y)
  local btnY = mh - 1
  
  if y >= 4 and y <= 5 and x >= 2 and x <= mw - 2 then
    inputMode = "name"
    drawNameInput()
    return
  end
  
  if y >= 7 and y <= 8 and x >= 2 and x <= mw - 2 then
    inputMode = "idc"
    drawIDCInput()
    return
  end
  
  -- Gate Type Selector - speichere ALT bevor du neu lädst
  if y == 11 then
    local xPos = 2
    local newType = nil
    if x >= xPos and x <= xPos + #"MilkyWay" + 1 then
      newType = "MilkyWay"
    elseif x >= xPos + #"MilkyWay" + 3 and x <= xPos + #"MilkyWay" + 3 + #"Pegasus" + 1 then
      newType = "Pegasus"
    elseif x >= xPos + #"MilkyWay" + #"Pegasus" + 6 and x <= xPos + #"MilkyWay" + #"Pegasus" + 6 + #"Universe" + 1 then
      newType = "Universe"
    end
    
    if newType and newType ~= currentGateType then
      -- Speichere die aktuelle Adresse VOR dem Wechsel
      saveCurrentToTemp()
      
      -- Lade die neue Adresse
      currentGateType = newType
      local gt = string.lower(currentGateType)
      local addr = {}
      if gt == "milkyway" then
        addr = savedMW
      elseif gt == "pegasus" then
        addr = savedPG
      elseif gt == "universe" then
        addr = savedUN
      end
      
      slot9 = addr[#addr] or getFirstSymbol(currentGateType)
      slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8 = "", "", "", "", "", "", "", ""
      for i=1,math.min(#addr-1,8) do
        if i==1 then slot1=addr[i] elseif i==2 then slot2=addr[i] elseif i==3 then slot3=addr[i] elseif i==4 then slot4=addr[i] elseif i==5 then slot5=addr[i] elseif i==6 then slot6=addr[i] elseif i==7 then slot7=addr[i] elseif i==8 then slot8=addr[i] end
      end
      
      if slot9 == "" then
        slot9 = getFirstSymbol(currentGateType)
      end
    end
    drawGateTypeSelector()
    drawSlots()
    drawSymbols()
    return
  end
  
  --[[if y >= 13 and y <= 15 then
    local selectedSlot = nil
    for i=1,6 do
      local sx = 2 + (i-1)*12
      if x >= sx and x <= sx+10 then selectedSlot = i break end
    end
    if not selectedSlot and y == 14 then
      for i=7,8 do
        local sx = 2 + (i-7)*12
        if x >= sx and x <= sx+10 then selectedSlot = i break end
      end
    end
    if not selectedSlot and y == 15 and x >= 2 and x <= 10 then
      selectedSlot = 9
    end
    
    if selectedSlot then
      if selectedSlot == 9 then
        slot9 = getFirstSymbol(currentGateType)
      else
        if selectedSlot == 1 then slot1 = ""
        elseif selectedSlot == 2 then slot2 = ""
        elseif selectedSlot == 3 then slot3 = ""
        elseif selectedSlot == 4 then slot4 = ""
        elseif selectedSlot == 5 then slot5 = ""
        elseif selectedSlot == 6 then slot6 = ""
        elseif selectedSlot == 7 then slot7 = ""
        elseif selectedSlot == 8 then slot8 = ""
        end
      end
      drawSlots()
      drawSymbols()
    end
    return
  end]]--
  
  local yStart = 17
  local cols = 3
  local colWidth = math.floor((mw - 4) / cols)
  if y >= yStart + 1 and y <= yStart + 12 then
    local symbols = getSymbolsForType(currentGateType)
    local clickedCol = math.floor((x - 2) / colWidth)
    local clickedRow = y - yStart - 1
    
  if clickedCol >= 0 and clickedCol < cols and clickedRow >= 0 then
      local idx = clickedRow * cols + clickedCol + 1
      -- Erster Symbol (Point of Origin/Subido/17) ist nicht anklickbar
      if idx == 1 then
        return
      end
      if idx >= 2 and idx <= #symbols then
        local sym = symbols[idx]
        
        if slot1 == sym then slot1 = ""
        elseif slot2 == sym then slot2 = ""
        elseif slot3 == sym then slot3 = ""
        elseif slot4 == sym then slot4 = ""
        elseif slot5 == sym then slot5 = ""
        elseif slot6 == sym then slot6 = ""
        elseif slot7 == sym then slot7 = ""
        elseif slot8 == sym then slot8 = ""
        elseif slot9 == sym then slot9 = ""
        else
          local placed = false
          if slot1 == "" then slot1 = sym placed = true
          elseif slot2 == "" then slot2 = sym placed = true
          elseif slot3 == "" then slot3 = sym placed = true
          elseif slot4 == "" then slot4 = sym placed = true
          elseif slot5 == "" then slot5 = sym placed = true
          elseif slot6 == "" then slot6 = sym placed = true
          elseif slot7 == "" then slot7 = sym placed = true
          elseif slot8 == "" then slot8 = sym placed = true
          end
          
          if placed then
            drawSlots()
            drawSymbols()
            return
          end
        end
        
        drawSlots()
        drawSymbols()
      end
    end
    return
  end
  
  if y == btnY and x >= 2 and x <= 7 then
    if entryName == "" then
      monitor.setCursorPos(21, 2)
      monitor.setTextColor(colors.red)
      monitor.write("Name required!")
      monitor.setTextColor(colors.white)
      sleep(1.5)
      monitor.setCursorPos(21, 2)
      monitor.write(string.rep(" ", 20))
      return
    end
    saveCurrentToTemp()
    saveGateEntries()
    editing = false
    return
  end
  
  if y == btnY and x >= 9 and x <= 14 then
    slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8 = "", "", "", "", "", "", "", ""
    slot9 = getFirstSymbol(currentGateType)
    drawSlots()
    drawSymbols()
    return
  end
  
  if y == btnY and x >= 17 and x <= 32 then
    importFromGate()
    return
  end
  
  if mode == "edit" and y == btnY and x >= 36 and x <= 44 then
    if editIndex and editIndex > 0 then
      local tempEntries = dofile("GateEntries.ff")
      if editIndex > 0 and editIndex <= #tempEntries then
        table.remove(tempEntries, editIndex)
        local file = fs.open("GateEntries.ff", "w")
        file.write("-- Gate Entries Database\n")
        file.write("-- Struktur: name, mw (MilkyWay), pg (Pegasus), un (Universe), idc (ID Code)\n\n")
        file.write("return " .. textutils.serialize(tempEntries) .. "\n")
        file.close()
      end
      editing = false
      return
    end
  end
  
  if mode == "edit" then
    if y == btnY and x >= 45 and x <= 51 then
      editing = false
      return
    end
  else
    if y == btnY and x >= 36 and x <= 43 then
      editing = false
      return
    end
  end
end

local function handleChar(char)
  if inputMode == "name" then
    if char == "backspace" then
      if #entryName > 0 then entryName = string.sub(entryName, 1, -2) end
    elseif char == "enter" then
      inputMode = "idc"
    else
      entryName = entryName .. char
    end
    drawNameInput()
  elseif inputMode == "idc" then
    if char == "backspace" then
      if #entryIDC > 0 then entryIDC = string.sub(entryIDC, 1, -2) end
    elseif char == "enter" then
      inputMode = "name"
    else
      entryIDC = entryIDC .. char
    end
    drawIDCInput()
  end
end

drawUI()

while editing do
  local e, side, x, y, z, za = os.pullEvent()
  if e == "monitor_touch" then
    handleTouch(x, y)
  elseif e == "char" then
    handleChar(side)
  elseif e == "key" then
    if side == keys.backspace then handleChar("backspace")
    elseif side == keys.enter then handleChar("enter") end
  end
end

monitor.clear()
