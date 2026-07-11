---@diagnostic disable: undefined-global, undefined-field, lowercase-global
-- ===============================
-- STARGATE DIALING COMPUTER
-- CC:Tweaked Monitor Version
-- ===============================
local Version = "1.21"
-- === MONITOR SETUP ===
local monitor = peripheral.find("monitor")
if not monitor then
  error("No Monitor found!")
end

local stargate = peripheral.find("stargate")
if not stargate then
  error("No Stargate found!")
end
local configsf = dofile("selftest.cfg")
local gateEntries = dofile("GateEntries.ff")
local irisCodes = dofile("IrisCodes.ff")
local configsd = dofile("smartdial.cfg")
coloring = dofile("UIColoring.cfg")

local function saveConfig()
  local file = fs.open("selftest.cfg", "w")
  file.write("local config = " .. textutils.serialize(configsf) .. "\nreturn config")
  file.close()
end

local function saveIrisCodes()
  local file = fs.open("IrisCodes.ff", "w")
  file.write("-- Iris Codes Database\n")
  file.write("-- Struktur: name, code, expires (timestamp), used (boolean)\n\n")
  file.write("return " .. textutils.serialize(irisCodes) .. "\n")
  file.close()
end

local function checkForUpdate()
  local success, response = pcall(http.get, "https://raw.githubusercontent.com/TheRedCreations/AGS2/refs/heads/main/0/version.txt")  -- Replace with your pastebin raw URL containing version like "1.12"
  if not success then
    print("Update check failed: No internet/http enabled.")
    return
  end
  local remoteVersion = response.readAll():match("^%s*(%d+%.%d+)")
  response.close()
  if remoteVersion and remoteVersion > Version then
    print("Update available: " .. remoteVersion .. " (local: " .. Version .. ")")
    monitor.setTextColor(colors.yellow)
    monitor.setCursorPos(21,2)
    monitor.write("Update available: " .. remoteVersion .. " (local: " .. Version .. ")")
    monitor.setTextColor(coloring.text)
  else
    print("No update available. You are on latest: " .. Version)
  end
end

if configsf.selftest then
  print("Selftest mode enabled")
  stargate.spinRing()
  stargate.toggleIris()
  for i=0,8 do
    stargate.openChevron(i)
    sleep(0.5)
    stargate.activateChevron(i)
    sleep(0.5)
    stargate.deactivateChevron(i)
    stargate.closeChevron(i)
    sleep(0.5)
  end
  sleep(1)
  stargate.stopRingSpin()
  stargate.toggleIris()
  print("Selftest complete")
  configsf.selftest = false
  saveConfig()
end

local redstonerelay = peripheral.find("redstone_relay")


monitor.setTextScale(0.5)
monitor.setBackgroundColor(coloring.background)
monitor.setTextColor(coloring.text)
monitor.clear()

local mw, mh = monitor.getSize()

-- === Initial Values ===
local gateOpen = false
local dialing = false
local selectedAddress = nil
local changed = {}
local runtime = true
local sendIDC = ""
local IDCAccepted = false
local DHDDial = false
local str = require("cc.strings")
gatesymboltype = stargate.getSymbolType()

-- Erstelle Adressen-Array aus Gate Entries
local addresses = {}
local addresscolor = {}
for i, entry in ipairs(gateEntries) do
  table.insert(addresses, entry.name)
  table.insert(addresscolor, entry.textcolor)
end
-- === Pagination ===
local currentPage = 1
local entriesPerPage = 0

local function calculateEntriesPerPage()
  -- Box height is mh-3, but we reserve bottom row for page navigation
  -- Also reserve space for title, so entriesPerPage = mh - 5
  entriesPerPage = mh - 5
end

local function getTotalPages()
  if entriesPerPage == 0 then return 1 end
  return math.max(1, math.ceil(#addresses / entriesPerPage))
end

local function getPageStart()
  return (currentPage - 1) * entriesPerPage + 1
end

local function getPageEnd()
  return math.min(currentPage * entriesPerPage, #addresses)
end

-- Calculate entries per page after addresses array is created
calculateEntriesPerPage()

local capacitors = stargate.getCapacitorsInstalled()
local symbollistfordial = {}
local numsymbolsselected = 0
local nineSelected = false

local symbolsMW = {"Point of Origin","Andromeda","Aquarius","Aries","Auriga","Bootes","Cancer","Canis Minor","Capricornus","Centaurus","Cetus","Corona Australis","Crater","Equuleus","Eridanus","Gemini","Hydra","Leo","Leo Minor","Libra","Lynx","Microscopium","Monoceros","Norma","Orion","Pegasus","Perseus","Pisces","Piscis Austrinus","Sagittarius","Scorpius","Sculptor","Scutum","Serpens Caput","Sextans","Taurus","Triangulum","Virgo"}
local symbolsPG = {"Subido","Aaxel","Abrin","Acjesis","Aldeni","Alura","Amiwill","Arami","Avoniv","Baselai","Bydo","Ca Po","Danami","Dawnre","Ecrumig","Elenami","Gilltin","Hacemill","Hamlinto","Illume","Laylox","Lenchan","Olavii","Once El","Poco Re","Ramnon","Recktic","Robandus","Roehi","Salma","Sandovi","Setas","Sibbron","Tahnan","Zamilloz","Zeo"}
local symbolsUN = {"17","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32","33","34","35","36"}

if gatesymboltype == "jsg:milkyway" or gatesymboltype== "milkyway" then
  symbols = symbolsMW
elseif gatesymboltype == "jsg:pegasus" or gatesymboltype== "pegasus" then
  symbols = symbolsPG
elseif gatesymboltype == "jsg:universe" or gatesymboltype== "universe" then
  symbols = symbolsUN
else
  error("Unknown gate type: " .. gatesymboltype)
end

-- === DRAW HELPERS ===
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
  monitor.setBackgroundColor(coloring.background)
  monitor.setTextColor(coloring.text)
end

-- === STARGATE RING ===
local chevrons = {0,0,0,0,0,0,0,0,0}  -- 0=inactive, 1=active
local innerColor = coloring.background  -- Farbe des Ring-Inneren
local chevronColors = {
  milkyway = coloring.chevronMW,
  pegasus = coloring.chevronPG,
  universe = coloring.chevronUN
}

local function getChevronColor()
  if gatesymboltype == "jsg:milkyway" or gatesymboltype== "milkyway" then
  gateType = "milkyway"
elseif gatesymboltype == "jsg:pegasus" or gatesymboltype== "pegasus" then
  gateType = "pegasus"
elseif gatesymboltype == "jsg:universe" or gatesymboltype== "universe" then
  gateType = "universe"
end
  return chevronColors[gateType]
end

local function setInnerColor(color)
  innerColor = color
end

local function activateChevron(index)
  if index >= 1 and index <= 9 then
    chevrons[index] = 1
  end
end

local function resetChevrons()
  for i = 1, 9 do
    chevrons[i] = 0
  end
end

local function drawGate(gatecolor)
  local cx = math.floor(mw/2)
  local cy = math.floor(mh/2)
  monitor.setBackgroundColor(gatecolor)
  local radius = 15
  local inner_radius = radius - 4
  for dx = -math.floor(radius), math.floor(radius) do
    for dy = -math.floor(radius), math.floor(radius) do
      local dist = dx*dx + dy*dy
      if dist <= (radius - 0.5)^2 and dist >= (inner_radius + 0.5)^2 then
        local x = cx + dx
        local y = cy + dy
        monitor.setCursorPos(x, y)
        monitor.write(" ")
      end
    end
  end
  
  -- Färbe das Innere des Rings
  monitor.setBackgroundColor(innerColor)
  local innergateradius = radius - 3
  for dx = -math.floor(innergateradius), math.floor(innergateradius) do
    for dy = -math.floor(innergateradius), math.floor(innergateradius) do
      local dist = dx*dx + dy*dy
      if dist <= (innergateradius - 0.5)^2 then
        local x = cx + dx
        local y = cy + dy
        monitor.setCursorPos(x, y)
        monitor.write(" ")
      end
    end
  end
  
  monitor.setBackgroundColor(coloring.background)
  if runtime then

  -- Draw chevrons on the ring (9 chevrons at 40° intervals)
  local chevronColor = getChevronColor()
  for i = 1, 9 do
    local angle = (i - 1) * 40 - 90  -- Start at top, 40° intervals
    local rad = math.rad(angle)
    local chevx = cx + math.cos(rad) * (radius - 1)
    local chevy = cy + math.sin(rad) * (radius - 1)
    
    chevx = math.floor(chevx + 0.5)
    chevy = math.floor(chevy + 0.5)
    
    monitor.setCursorPos(chevx, chevy)
    
    if chevrons[i] == 0 then
      monitor.setBackgroundColor(colors.lightGray)
    else
      monitor.setBackgroundColor(chevronColor)
    end
    
  
    monitor.write(" ")
  end
  
  monitor.setTextColor(coloring.text)
  monitor.setBackgroundColor(coloring.background)
  end
end

-- === DRAW FUNCTIONS ===
local function drawLeftBox()
  box(1,1,19,mh-3,"Gate Entries")
  local pageStart = getPageStart()
  local pageEnd = getPageEnd()
  
if #addresses == 0 then
    monitor.setCursorPos(21,1)
    monitor.setTextColor(colors.red)
    monitor.write("No Address in Database!")
    monitor.setTextColor(coloring.text)
end
  for i = pageStart, pageEnd do
    local v = addresses[i]
    if v then
      local displayIndex = i - pageStart + 2
      monitor.setCursorPos(2, displayIndex)
      if selectedAddress == i then
        monitor.setTextColor(colors.lime)
      else
        monitor.setTextColor(addresscolor[i] or coloring.text)
      end
      monitor.write(str.ensure_width(v,17))
      monitor.setTextColor(coloring.text)
    end
  end
  
  -- Draw page navigation at bottom of left box
  local totalPages = getTotalPages()
  local pageNavY = mh - 3
  
  -- Previous page button (<)
  if currentPage > 1 then
    monitor.setCursorPos(2, pageNavY)
    monitor.setTextColor(colors.cyan)
    monitor.write("<")
  else
    monitor.setCursorPos(2, pageNavY)
    monitor.setTextColor(colors.gray)
    monitor.write("-")
  end
  
  -- Page indicator
  monitor.setCursorPos(5, pageNavY)
  monitor.setTextColor(coloring.text)
  monitor.write(currentPage .. "/" .. totalPages)
  
  -- Next page button (>)
  if currentPage < totalPages then
    monitor.setCursorPos(10, pageNavY)
    monitor.setTextColor(colors.cyan)
    monitor.write(">")
  else
    monitor.setCursorPos(10, pageNavY)
    monitor.setTextColor(colors.gray)
    monitor.write("-")
  end
  
  monitor.setTextColor(coloring.text)
end

local function drawRightBox()
  box(mw-16,0,18,mh+2,"Symbols ("..numsymbolsselected.."/8)")
  for i=1,math.min(#symbols,mh) do
    monitor.setCursorPos(mw-15,0+i)
    local isSelected = false
    local selectionIndex = 0

    -- Sonderfall: erstes Symbol kann als Slot 9 benutzt werden
    if i == 1 and nineSelected then
      isSelected = true
      selectionIndex = 9
    else
      for idx, sym in ipairs(symbollistfordial) do
        if sym == symbols[i] then
          isSelected = true
          selectionIndex = idx
          break
        end
      end
    end

    if isSelected then
      monitor.setTextColor(colors.lime)
    else
      monitor.setTextColor(coloring.text)
    end
    if gatesymboltype == "universe" or gatesymboltype == "jsg:universe" then
      monitor.write("Glyph " .. symbols[i])
      monitor.setTextColor(coloring.text)
    else
      monitor.write(symbols[i])
      monitor.setTextColor(coloring.text)
    end
    

    -- Zeige die Reihenfolgenummer außerhalb der Box (nicht für erstes Symbol)
    if i ~= 1 then
      monitor.setCursorPos(mw-17,0+i)
      if isSelected then
        monitor.setTextColor(colors.lime)
        monitor.write(tostring(selectionIndex))
      else
        monitor.write(" ")
      end
      monitor.setTextColor(coloring.text)
    end
  end
end

local function drawButtons()
  button(21,3,6,"Dial", coloring.dialButton)
  button(28,3,11,"Add Entry", coloring.addButton)
  button(40,3,12,"Edit Entry", coloring.editButton)
  button(21,mh-3,6,"Exit", coloring.exitButton)
  if stargate.getIrisState() == "OPENED" or stargate.getIrisState() == "OPENING" then
    button(28,mh-3,10,"Iris opened", colors.green)
    if gateOpen then
      setInnerColor(coloring.eventhorizont)
    else 
      setInnerColor(coloring.background)
    end
  end
  if stargate.getIrisState() == "CLOSED" or stargate.getIrisState() == "CLOSING" then
    button(28,mh-3,12,"Iris closed", colors.red)
    setInnerColor(coloring.iris)
  end
  button(mw-23,mh-3,6,"IDCs", colors.white)
  if gateOpen and not dialing then
    button(mw-37,mh-3,10,"Close Gate ", colors.red)
  elseif dialing and not gateOpen then
    button(mw-37,mh-3,10,"Abort Dial ", colors.yellow)
  else
    button(mw-37,mh-3,10,"Gate Closed", colors.green)
  end
  button(55,3,5,"Clear", colors.orange)
end

local function drawStatus()
  box(1,mh-2,mw-18,3)
  monitor.setCursorPos(2,mh-1)
  monitor.write("Energy: ")
  energy = stargate.getEnergyStored()
  if energy > 30000000000 then
    monitor.write("Infinite FE")
  else
    monitor.write(energy.." FE")
  end
  monitor.setCursorPos(26,mh-1)
  monitor.write("Capacitors installed: ")
  monitor.setCursorPos(48,mh-1)
  monitor.write(capacitors)
  monitor.setCursorPos(mw-22,mh-1)
  monitor.write(Version)
end

-- === MAIN UI DRAW ===
local function drawUI()
  monitor.clear()
  drawLeftBox()
  drawRightBox()
  drawButtons()
  drawStatus()
  drawGate(coloring.gatering)
end

-- === DIAL ANIMATION ===
local function dialSequence()
  resetChevrons()
  if symbollistfordial[6] == "" or symbollistfordial[6] == nil then
    addresscheck = false
    err = "Address too short"
  elseif symbollistfordial[7] == "" then
    if not configsd.smartdial then
      addresscheck = true
      reqGlyph = 7
    else
      addresscheck, err, reqGlyph = stargate.getSymbolsNeeded({symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[9]})
    end
  elseif symbollistfordial[8] == "" then
    if not configsd.smartdial then
      addresscheck = true
      reqGlyph = 8
    else
      addresscheck, err, reqGlyph = stargate.getSymbolsNeeded({symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[7],symbollistfordial[9]})
    end
  else
    if not configsd.smartdial then
      addresscheck = true
      reqGlyph = 9
    else
      addresscheck, err, reqGlyph = stargate.getSymbolsNeeded(symbollistfordial)
    end
  end
  if addresscheck == true then
    monitor.setCursorPos(21,1)
    monitor.write("Dialing: "..str.ensure_width(entryName or "Unknown",31))
    if reqGlyph == 7 then
      if stargate.customDialAddress then
        if configsd.fastdial then
          stargate.customDialAddress(symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[9],"FAST")
        else
          stargate.dialAddress(symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[9])
        end
      else
        stargate.dialAddress(symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[9])
      end
    elseif reqGlyph == 8 then
      if stargate.customDialAddress then
        if configsd.fastdial then
          stargate.customDialAddress(symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[7],symbollistfordial[9],"FAST")
        else
          stargate.dialAddress(symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[7],symbollistfordial[9])
        end
      else
        stargate.dialAddress(symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[7],symbollistfordial[9])
      end
    else
      if stargate.customDialAddress then
        if configsd.fastdial then
          stargate.customDialAddress(symbollistfordial,"FAST")
        else
          stargate.dialAddress(symbollistfordial)
        end
      else
        stargate.dialAddress(symbollistfordial)
      end
    end
    dialing = true
    if redstonerelay then
      redstonerelay.setOutput("back", true)
    end
  else
    resetChevrons()
    monitor.setCursorPos(21,1)
    monitor.setTextColor(colors.red)
    monitor.write("Invalid address: "..(err or "Unknown error"))
    monitor.setTextColor(coloring.text)
    sleep(2)
    monitor.setCursorPos(21,1)
    monitor.write(string.rep(" ", 41))
    drawGate(coloring.gatering)
  end
end

-- === LOAD ADDRESS SYMBOLS ===
local function loadAddressSymbols(addressIndex)
  symbollistfordial = {}
  numsymbolsselected = 0
  nineSelected = false
  
  if addressIndex and gateEntries[addressIndex] then
    local entry = gateEntries[addressIndex]
    local symbolSequence = {}
    
    if gatesymboltype == "jsg:milkyway" or gatesymboltype == "milkyway" and entry.mw then
      symbolSequence = entry.mw
    elseif gatesymboltype == "jsg:pegasus" or gatesymboltype == "pegasus" and entry.pg then
      symbolSequence = entry.pg
    elseif gatesymboltype == "jsg:universe" or gatesymboltype == "universe" and entry.un then
      symbolSequence = entry.un
    end
    sendIDC = entry.idc
    entryName = entry.name
    for _, sym in ipairs(symbolSequence) do
      table.insert(symbollistfordial, sym)
      numsymbolsselected = numsymbolsselected + 1
    end
  end
end

-- === IRIS CODE RECEIVED HANDLER ===
local function drawIDCOverlay(code, entryName, accepted)
  local boxW = math.min(25, mw - 6)
  local boxH = 11
  local x0 = math.floor((mw - boxW) / 2) 
  local y0 = math.floor((mh - boxH) / 2) + 1

  -- Draw boxed area like the other UI boxes
  monitor.setBackgroundColor(coloring.background)
  monitor.setTextColor(coloring.text)
  box(x0, y0, boxW, boxH, "")

  -- Clear inner area
  for yy = y0 + 1, y0 + boxH - 2 do
    monitor.setCursorPos(x0 + 1, yy)
    monitor.write(string.rep(" ", boxW - 2))
  end

  -- obere "Wave"-Anzeige (vereinfachte Grafik)
  for ry = 0, 2 do
    monitor.setCursorPos(x0 + 2, y0 + 1 + ry)
    for cx = 1, boxW - 4 do
      if (cx + ry) % 7 == 0 then
        monitor.setTextColor(colors.green)
        monitor.write("/")
      else
        monitor.setTextColor(colors.red)
        monitor.write("\\")
      end
    end
  end

  -- Trennlinie
  monitor.setTextColor(colors.gray)
  monitor.setCursorPos(x0 + 2, y0 + 4)
  monitor.write(string.rep("-", boxW - 4))

  -- Code-Zeilen (zentriert innerhalb der Box)
  local codeLine1 = "SIGNAL DECRYPTED"
  local codeLine2 = "CODE: " .. tostring(code)
  local cx1 = x0 + 1 + math.floor((boxW - 2 - #codeLine1) / 2)
  monitor.setCursorPos(cx1, y0 + 5)
  monitor.setTextColor(colors.lightGray)
  monitor.write(codeLine1)
  local cx2 = x0 + 1 + math.floor((boxW - 2 - #codeLine2) / 2)
  monitor.setCursorPos(cx2, y0 + 6)
  monitor.write(codeLine2)

  -- Große Erkennungszeile
  local recog1 = "RECOGNIZED:"
  local recog2 = (entryName or "UNKNOWN")
  local recogColor = accepted and colors.lime or colors.red
  local rcx1 = x0 + 1 + math.floor((boxW - 2 - #recog1) / 2)
  monitor.setCursorPos(rcx1, y0 + 7)
  monitor.setTextColor(recogColor)
  monitor.write(recog1)
  local rcx2 = x0 + 1 + math.floor((boxW - 2 - #recog2) / 2)
  monitor.setCursorPos(rcx2, y0 + 8)
  monitor.write(recog2)

  -- Hinweiszeile / optionaler Status
  monitor.setTextColor(colors.gray)
  local info = accepted and "IDC accepted" or "IDC rejected"
  local icx = x0 + 1 + math.floor((boxW - 2 - #info) / 2)
  monitor.setCursorPos(icx, y0 + 9)
  monitor.write(info)

  -- Reset Farben
  monitor.setTextColor(coloring.text)
  monitor.setBackgroundColor(coloring.background)
end

local function irisCodeRecived(IDC)
  -- Suche Eintrag
  for i, entry in ipairs(irisCodes) do
    if entry.code == IDC and not entry.used then
      if entry.limited then
        entry.used = true
        saveIrisCodes()
      end


      -- Iris öffnen und Nachrichten senden
      if stargate.getIrisState() == "CLOSED" or stargate.getIrisState() == "CLOSING" then
        setInnerColor(coloring.eventhorizont)
        drawGate(coloring.gatering)
        stargate.toggleIris()
        changed.buttons = true
        drawButtons()
      end
      if stargate.sendMessageToIncoming then
      stargate.sendMessageToIncoming("IDC Accepted")
    else
      stargate.sendMessageToIncomingTraveller("IDC Accepted")
    end
      IDCAccepted = true
      -- Zeige Overlay accepted
      drawIDCOverlay(IDC, entry.name, true)

      sleep(5)
      -- Overlay entfernen und UI neu zeichnen
      setInnerColor(coloring.eventhorizont)
      drawGate(coloring.gatering)
      return
    end
  end

  -- Kein gültiger Code -> Overlay rejected
  drawIDCOverlay(IDC, "UNKNOWN", false)
  if stargate.sendMessageToIncoming then
    stargate.sendMessageToIncoming("IDC Rejected")
  else
    stargate.sendMessageToIncomingTraveller("IDC Rejected")
  end
  sleep(5)
  drawGate(coloring.gatering)
end

-- === TOUCH HANDLING ===
local function handleTouch(x,y)
  if not dialing then
  -- Page navigation (< button at position 2, y = mh-3)
  if y == mh - 3 and x >= 2 and x <= 2 then
    if currentPage > 1 then
      currentPage = currentPage - 1
      changed.left = true
    end
    return
  end
  
  -- Page navigation (> button at position 10, y = mh-3)
  if y == mh - 3 and x >= 10 and x <= 10 then
    if currentPage < getTotalPages() then
      currentPage = currentPage + 1
      changed.left = true
    end
    return
  end
  
  -- Address select (within the list area, not the page navigation area)
  local pageNavY = mh - 3
  if x >= 2 and x <= 18 and y >= 2 and y <= pageNavY - 1 then
    local pageStart = getPageStart()
    local index = pageStart + (y - 2)
    if addresses[index] then
      selectedAddress = index
      loadAddressSymbols(index)
      changed.left = true
      changed.right = true
    end
    return
  end

  -- Symbols select (Mehrfach-Auswahl)
  if x >= mw-16 and x <= mw and y >= 1 and y <= mh then
    local index = y
    if symbols[index] then
      -- Sonderfall: erstes Symbol toggelt exklusiv Slot 9
      if index == 1 then
        nineSelected = not nineSelected
        table.insert(symbollistfordial,9,symbols[index])
        changed.right = true
      else
        local found = false
        for i, sym in ipairs(symbollistfordial) do
          if sym == symbols[index] then
            table.remove(symbollistfordial, i)
            found = true
            break
          end
        end
        if not found and numsymbolsselected < 8 then
          table.insert(symbollistfordial, symbols[index])
          numsymbolsselected = numsymbolsselected + 1
        end
        if found then
          numsymbolsselected = numsymbolsselected - 1
        end
        changed.right = true
      end
    end
  end

  -- Add Entry button
  if x>=28 and x<=38 and y==3 then
    shell.run("AddressEditor.lua add")
    -- Reload data after returning
    gateEntries = dofile("GateEntries.ff")
    addresses = {}
    addresscolor = {}
    for i, entry in ipairs(gateEntries) do
      table.insert(addresses, entry.name)
      table.insert(addresscolor, entry.textcolor)
    end
    currentPage = 1
    selectedAddress = nil
    changed.left = true
    changed.right = true
    changed.buttons = true
    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(coloring.background)
    monitor.setTextColor(coloring.text)
    drawUI()
  end

  -- Edit Entry button
  if x>=40 and x<=51 and y==3 then
    if selectedAddress ~= nil then
      shell.run("AddressEditor.lua edit " .. selectedAddress)
      -- Reload data after returning
      gateEntries = dofile("GateEntries.ff")
      addresses = {}
      addresscolor = {}
      for i, entry in ipairs(gateEntries) do
        table.insert(addresses, entry.name)
        table.insert(addresscolor, entry.textcolor)
      end
      if selectedAddress > #addresses then
        selectedAddress = #addresses
      end
      if selectedAddress then
        loadAddressSymbols(selectedAddress)
      end
      changed.left = true
      changed.right = true
      changed.buttons = true
      changed.status = true
      monitor.setTextScale(0.5)
      monitor.setBackgroundColor(coloring.background)
      monitor.setTextColor(coloring.text)
      drawUI()
    end
  end

  -- Edit IDC button
  if x>=mw-23 and x<=mw-18 and y==mh-3 then
    shell.run("IDCEditor.lua")
    -- Reload iris codes after returning mw-23,mh-3
    irisCodes = dofile("IrisCodes.ff")
    changed.buttons = true
    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(coloring.background)
    monitor.setTextColor(coloring.text)
    drawUI()
  end

  -- Dial button
  if x>=21 and x<=26 and y==3 and not gateOpen then
    dialSequence()
    changed.buttons = true
  end
  end

  -- Close gate
  if gateOpen and x>=mw-37 and x<=mw-25 and y==mh-3 then
    gateOpen = false
    changed.buttons = true
    stargate.disengageGate()
  end

  --Abort Dial
  if dialing and x>=mw-37 and x<=mw-25 and y==mh-3 then
    gateOpen = false
    dialing = false
    changed.buttons = true
    stargate.abortDialing()
    if redstonerelay then
      redstonerelay.setOutput("back", false)
    end
  end

  -- Iris button
  if x>=28 and x<=40 and y==mh-3 then
    stargate.toggleIris()
    sleep(0.1)
    changed.buttons = true
  end

  -- Clear button
  if x>=55 and x<=60 and y==3 then
    if not dialing then
    symbollistfordial = {}
    numsymbolsselected = 0
    selectedAddress = nil
    sendIDC = ""
    entryName = ""
    nineSelected = false
    changed.right = true
    changed.left = true
    changed.buttons = true
    end
  end

  -- Exit button
  if runtime and x>=21 and x<=26 and y==mh-3 then
    runtime = false
    monitor.setCursorPos(21,1)
    monitor.setTextColor(colors.red)
    monitor.write("Shutting down...")
    monitor.setTextColor(colors.white)
    sleep(2)
    setInnerColor(colors.black)
    drawGate(colors.black)
    monitor.clear()
  end
end

-- === MAIN LOOP ===
drawUI()

checkForUpdate()

while runtime do
  local e, side, x, y, z,za = os.pullEvent()
  if e == "monitor_touch" then
    handleTouch(x,y)
    if changed.left then drawLeftBox() changed.left = false end
    if changed.right then drawRightBox() changed.right = false end
    if changed.buttons then drawButtons() changed.buttons = false end
    if changed.status then drawStatus() changed.status = false end
    if runtime then
      drawGate(coloring.gatering)
    else
      drawGate(colors.black)
    end
  end
  if e == "stargate_ping" then
    if not dialing then
      capacitors = stargate.getCapacitorsInstalled()
      --sleep(0.1)
      drawStatus()
    end
  end
  if e == "stargate_wormhole_open_unstable" then
    activateChevron(1)--9
    drawGate(coloring.gatering)
    gateOpen = true
    dialing = false
    drawButtons()
    if stargate.getIrisState() == "OPENED" or stargate.getIrisState() == "OPENING" then
      setInnerColor(coloring.eventhorizont)
      drawGate(coloring.gatering)
    end
    monitor.setCursorPos(21,1)
    monitor.write(string.rep(" ", 41))
  end
  if e == "stargate_wormhole_open_fully" then
    local _,_, openState = stargate.getGateStatus()
    if openState then
        if sendIDC ~= "" then
          stargate.sendIrisCode(sendIDC)
          monitor.setCursorPos(21,1)
          monitor.write("Sending IDC. Iris could be closed!")
        end
    end
  end
  if e == "stargate_wormhole_incoming" then
    IDCAccepted = false
    if redstonerelay then
      redstonerelay.setOutput("back", true)
    end
    monitor.setCursorPos(21,1)
    monitor.setTextColor(colors.red)
    monitor.write("Incoming wormhole detected! ")
    monitor.setTextColor(coloring.text)
    if stargate.getIrisState() == "OPENED" or stargate.getIrisState() == "OPENING" then
      stargate.toggleIris()
      if stargate.getIrisState() == "CLOSING" or stargate.getIrisState() == "CLOSED" then
        setInnerColor(coloring.iris)
        drawGate(coloring.gatering)
      end
    end
    gateOpen = false
    dialing = false
    --[[if x == 7 then
      chevrons = {1,1,1,1,0,0,1,1,1}
    elseif x == 8 then
      chevrons = {1,1,1,1,1,0,1,1,1}
    elseif x == 9 then
      chevrons = {1,1,1,1,1,1,1,1,1}
    end--]]
    drawGate(coloring.gatering)
    drawButtons()
  end
  if e == "stargate_wormhole_close_fully" then
    if stargate.getIrisState() == "CLOSED" or stargate.getIrisState() == "CLOSING" then
      stargate.toggleIris()
    end
    if redstonerelay then
      redstonerelay.setOutput("back", false)
    end
    monitor.setCursorPos(21,1)
    monitor.write(string.rep(" ", 41))
    symbollistfordial = {}
    numsymbolsselected = 0
    selectedAddress = 0
    sendIDC = ""
    entryName = ""
    setInnerColor(coloring.background)
    resetChevrons()
    drawLeftBox()
    drawRightBox()
    drawStatus()
    drawGate(coloring.gatering)
    drawButtons()
  end
  if e == "stargate_wormhole_close_unstable" then
    gateOpen = false
    dialing = false
    DHDDial = false
  end
  if e == "stargate_iris_code_received" then
    --monitor.setCursorPos(21,1)
    --monitor.write(x)
    irisCodeRecived(x)
  end
  if e == "stargate_chevron_engaged" then
    if x == "DHD" then
      DHDDial = true
    end
      if z == 0 then
      --activateChevron(2)--1
      chevrons = {0,1,0,0,0,0,0,0,0}
    elseif z == 1 then
      --activateChevron(3)--2
      chevrons = {0,1,1,0,0,0,0,0,0}
    elseif z == 2 then
      --activateChevron(4)--3
      chevrons = {0,1,1,1,0,0,0,0,0}
    elseif z == 3 then
      --activateChevron(7)--4
      chevrons = {0,1,1,1,0,0,1,0,0}
    elseif z == 4 then
      --activateChevron(8)--5
      chevrons = {0,1,1,1,0,0,1,1,0}
    elseif z == 5 then
      --activateChevron(9)--6
      chevrons = {0,1,1,1,0,0,1,1,1}
    elseif z == 6 then
      activateChevron(5)--7
    elseif z == 7 then
      activateChevron(6)--8
    elseif z == 8 then
      activateChevron(1)--9
    end
    drawGate(coloring.gatering)

  end
  if e == "stargate_chevron_lit" then
      if x == 0 then
        --activateChevron(2)--1
        chevrons = {0,1,0,0,0,0,0,0,0}
      elseif x == 1 then
        --activateChevron(3)--2
        chevrons = {0,1,1,0,0,0,0,0,0}
      elseif x == 2 then
        --activateChevron(4)--3
        chevrons = {0,1,1,1,0,0,0,0,0}
      elseif x == 3 then
        --activateChevron(7)--4
        chevrons = {0,1,1,1,0,0,1,0,0}
      elseif x == 4 then
        --activateChevron(8)--5
        chevrons = {0,1,1,1,0,0,1,1,0}
      elseif x == 5 then
        --activateChevron(9)--6
        chevrons = {0,1,1,1,0,0,1,1,1}
      elseif x == 6 then
        activateChevron(5)--7
      elseif x == 7 then
        activateChevron(6)--8
      elseif x == 8 then
        activateChevron(1)--9
      end
      drawGate(coloring.gatering)

  end
  if e == "stargate_chevron_dim" then
    if x == 8 then
      chevrons[1] = 0
      drawGate(coloring.gatering)
    end
  end
  if e == "stargate_iris_toggled" then
    if not IDCAccepted then
      if stargate.getIrisState() == "OPENED" or stargate.getIrisState() == "OPENING" then
        stargate.toggleIris()
      end
    end
  end
end
