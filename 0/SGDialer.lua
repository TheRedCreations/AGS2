---@diagnostic disable: undefined-global, undefined-field
-- ===============================
-- STARGATE DIALING COMPUTER
-- CC:Tweaked Monitor Version
-- ===============================
local Version = "0.01"
-- === MONITOR SETUP ===
local monitor = peripheral.find("monitor")
if not monitor then
  error("Kein Monitor gefunden!")
end

local stargate = peripheral.find("stargate")
if not stargate then
  error("Kein Stargate gefunden!")
end
local configsf = dofile("selftest.cfg")
local gateEntries = dofile("GateEntries.ff")
local irisCodes = dofile("IrisCodes.ff")

local function saveConfig()
  local file = fs.open("selftest.cfg", "w")
  file.write("local config = " .. textutils.serialize(configsf) .. "\nreturn config")
  file.close()
end

local function saveGateEntries()
  local file = fs.open("GateEntries.ff", "w")
  file.write("-- Gate Entries Database\n")
  file.write("-- Struktur: name, mw (MilkyWay), pg (Pegasus), un (Universe), idc (ID Code)\n\n")
  file.write("return " .. textutils.serialize(gateEntries) .. "\n")
  file.close()
end

local function saveIrisCodes()
  local file = fs.open("IrisCodes.ff", "w")
  file.write("-- Iris Codes Database\n")
  file.write("-- Struktur: name, code, expires (timestamp), used (boolean)\n\n")
  file.write("return " .. textutils.serialize(irisCodes) .. "\n")
  file.close()
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




monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

local mw, mh = monitor.getSize()

-- === Initial Values ===
local gateOpen = false
local dialing = false
local selectedAddress = nil
local changed = {}
local runtime = true
local sendIDC = nil
local IDCAccepted = false
local DHDDial = false

-- Erstelle Adressen-Array aus Gate Entries
local addresses = {}
for i, entry in ipairs(gateEntries) do
  table.insert(addresses, entry.name)
end

local capacitors = stargate.getCapacitorsInstalled()
local symbollistfordial = {}
local numsymbolsselected = 0
local nineSelected = false

local symbolsMW = {"Point of Origin","Andromeda","Aquarius","Aries","Auriga","Bootes","Cancer","Canis Minor","Capricornus","Centaurus","Cetus","Corona Australis","Crater","Equuleus","Eridanus","Gemini","Hydra","Leo","Leo Minor","Libra","Lynx","Microscopium","Monoceros","Norma","Orion","Pegasus","Perseus","Pisces","Piscis Austrinus","Sagittarius","Scorpius","Sculptor","Scutum","Serpens Caput","Sextans","Taurus","Triangulum","Virgo"}
local symbolsPG = {"Subido","Aaxel","Abrin","Acjesis","Aldeni","Alura","Amiwill","Arami","Avoniv","Baselai","Bydo","Ca Po","Danami","Dawnre","Ecrumig","Elenami","Gilltin","Hacemill","Hamlinto","Illume","Laylox","Lenchan","Olavii","Once El","Poco Re","Ramnon","Recktic","Robandus","Roehi","Salma","Sandovi","Setas","Sibbron","Tahnan","Zamilloz","Zeo"}
local symbolsUN = {"17","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32","33","34","35","36"}

if stargate.getGateType() == "MilkyWay" then
  symbols = symbolsMW
elseif stargate.getGateType() == "Pegasus" then
  symbols = symbolsPG
elseif stargate.getGateType() == "Universe" then
  symbols = symbolsUN
else
  error("Unbekannter Gate-Typ: " .. stargate.getGateType())
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
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
end

-- === STARGATE RING ===
local chevrons = {0,0,0,0,0,0,0,0,0}  -- 0=inactive, 1=active
local innerColor = colors.black  -- Farbe des Ring-Inneren
local chevronColors = {
  MilkyWay = colors.orange,
  Pegasus = colors.blue,
  Universe = colors.white
}

local function getChevronColor()
  local gateType = stargate.getGateType()
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

local function deactivateChevron(index)
  if index >= 1 and index <= 9 then
    chevrons[index] = 0
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
  
  monitor.setBackgroundColor(colors.black)
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
  
  monitor.setTextColor(colors.white)
  monitor.setBackgroundColor(colors.black)
  end
end

-- === DRAW FUNCTIONS ===
local function drawLeftBox()
  box(1,1,19,mh-3,"Gate Entries")
  for i,v in ipairs(addresses) do
    monitor.setCursorPos(2,1+i)
    if selectedAddress == i then
      monitor.setTextColor(colors.lime)
    else
      monitor.setTextColor(colors.white)
    end
    monitor.write(v)
    monitor.setTextColor(colors.white)
  end
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
      monitor.setBackgroundColor(colors.gray)
    else
      monitor.setTextColor(colors.white)
      monitor.setBackgroundColor(colors.black)
    end
    monitor.write(symbols[i])
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)

    -- Zeige die Reihenfolgenummer außerhalb der Box (nicht für erstes Symbol)
    if i ~= 1 then
      monitor.setCursorPos(mw-17,0+i)
      if isSelected then
        monitor.setTextColor(colors.lime)
        monitor.write(tostring(selectionIndex))
      else
        monitor.write(" ")
      end
      monitor.setTextColor(colors.white)
    end
  end
end

local function drawButtons()
  button(21,3,6,"Dial", colors.white)
  button(28,3,11,"Add Entry", colors.white)
  button(40,3,12,"Edit Entry", colors.white)
  button(21,mh-3,6,"Exit", colors.white)
  if stargate.getIrisState() == "OPENED" or stargate.getIrisState() == "OPENING" then
    button(28,mh-3,10,"Iris opened", colors.green)
    if gateOpen then
      setInnerColor(colors.blue)
    else 
      setInnerColor(colors.black)
    end
  end
  if stargate.getIrisState() == "CLOSED" or stargate.getIrisState() == "CLOSING" then
    button(28,mh-3,12,"Iris closed", colors.red)
    setInnerColor(colors.lightGray)
  end
  button(mw-23,mh-3,6,Version, colors.white)
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
  monitor.write("Energy: "..stargate.getEnergyStored().." FE")
  monitor.setCursorPos(23,mh-1)
  monitor.write("Capacitors installed: ")
  monitor.setCursorPos(45,mh-1)
  monitor.write(capacitors)
  --[[monitor.setCursorPos(mw-29,mh-1)
  if gateOpen then
    monitor.setTextColor(colors.red)
    monitor.write("CLOSE GATE")
  else
    monitor.setTextColor(colors.green)
    monitor.write("Gate Closed")
  end
  monitor.setTextColor(colors.white)]]--
end

-- === MAIN UI DRAW ===
local function drawUI()
  monitor.clear()
  drawLeftBox()
  drawRightBox()
  drawButtons()
  drawStatus()
  drawGate(colors.gray)
end

-- === DIAL ANIMATION ===
local function dialSequence()
  dialing = true
  resetChevrons()
  local addresscheck, err, reqGlyph = stargate.getSymbolsNeeded(symbollistfordial)
  if addresscheck == true then
    if reqGlyph == 7 then
      stargate.dialAddress(symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[9])
    elseif reqGlyph == 8 then
      stargate.dialAddress(symbollistfordial[1],symbollistfordial[2],symbollistfordial[3],symbollistfordial[4],symbollistfordial[5],symbollistfordial[6],symbollistfordial[7],symbollistfordial[9])
    else
      stargate.dialAddress(symbollistfordial)
    end
    dialing = true
  else
    resetChevrons()
    monitor.setCursorPos(21,1)
    monitor.setTextColor(colors.red)
    monitor.write("Invalid address: "..(err or "Unknown error"))
    monitor.setTextColor(colors.white)
    sleep(2)
    monitor.setCursorPos(21,1)
    monitor.write(string.rep(" ", 41))
    drawGate(colors.gray)
  end
end

-- === LOAD ADDRESS SYMBOLS ===
local function loadAddressSymbols(addressIndex)
  symbollistfordial = {}
  numsymbolsselected = 0
  nineSelected = false
  
  if addressIndex and gateEntries[addressIndex] then
    local entry = gateEntries[addressIndex]
    local gateType = stargate.getGateType()
    local symbolSequence = {}
    
    if gateType == "MilkyWay" and entry.mw then
      symbolSequence = entry.mw
    elseif gateType == "Pegasus" and entry.pg then
      symbolSequence = entry.pg
    elseif gateType == "Universe" and entry.un then
      symbolSequence = entry.un
    end
    sendIDC = entry.idc
    for _, sym in ipairs(symbolSequence) do
      table.insert(symbollistfordial, sym)
      numsymbolsselected = numsymbolsselected + 1
    end
  end
end

-- === IRIS CODE RECEIVED HANDLER ===
local function irisCodeRecived(IDC)
  for i, entry in ipairs(irisCodes) do
    if entry.code == IDC and not entry.used then
      if entry.limited then
        entry.used = true
        saveIrisCodes()
      end
        -- Gültiger Code: Iris öffnen
        if stargate.getIrisState() == "CLOSED" or stargate.getIrisState() == "CLOSING" then
          setInnerColor(colors.blue)
          drawGate(colors.gray)
          stargate.toggleIris()
          changed.buttons = true
          drawButtons()
        end
        monitor.setCursorPos(21,1)
        monitor.setTextColor(colors.green)
        monitor.write("Iris code '" .. entry.name .. "' accepted.")
        stargate.sendMessageToIncoming("IDC Accepted")
        IDCAccepted = true
        monitor.setTextColor(colors.white)
        sleep(5)
        monitor.setCursorPos(21,1)
        monitor.write(string.rep(" ", 41))
        return
    end
  end
  -- Kein gültiger Code
  monitor.setCursorPos(21,1)
  monitor.setTextColor(colors.red)
  monitor.write("Invalid iris code received.")
  stargate.sendMessageToIncoming("IDC Rejected")
  monitor.setTextColor(colors.white)
  sleep(5)
  monitor.setCursorPos(21,1)
  monitor.write(string.rep(" ", 41))
end

-- === TOUCH HANDLING ===
local function handleTouch(x,y)
  -- Address select
  if x >= 2 and x <= 18 and y >= 2 then
    local index = y - 1
    if addresses[index] then
      selectedAddress = index
      loadAddressSymbols(index)
      changed.left = true
      changed.right = true
    end
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

  -- Dial button
  if x>=21 and x<=26 and y==3 and not gateOpen then
    dialSequence()
    changed.buttons = true
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
  end

  -- Iris button
  if x>=28 and x<=40 and y==mh-3 then
    stargate.toggleIris()
    sleep(0.5)
    changed.buttons = true
  end

  -- Clear button
  if x>=55 and x<=60 and y==3 then
    symbollistfordial = {}
    numsymbolsselected = 0
    nineSelected = false
    changed.right = true
    changed.buttons = true
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

while runtime do
  local e, side, x, y, z,za = os.pullEvent()
  if e == "monitor_touch" then
    handleTouch(x,y)
    if changed.left then drawLeftBox() changed.left = false end
    if changed.right then drawRightBox() changed.right = false end
    if changed.buttons then drawButtons() changed.buttons = false end
    if changed.status then drawStatus() changed.status = false end
    if runtime then
      drawGate(colors.gray)
    else
      drawGate(colors.black)
    end
  end
  if e == "stargate_ping" then
    capacitors = stargate.getCapacitorsInstalled()
    sleep(0.1)
    drawStatus()
  end
  if e == "stargate_wormhole_open_unstable" then
    gateOpen = true
    dialing = false
    drawButtons()
    if stargate.getIrisState() == "OPENED" or stargate.getIrisState() == "OPENING" then
      setInnerColor(colors.blue)
      drawGate(colors.gray)
    end
    monitor.setCursorPos(21,1)
    monitor.write(string.rep(" ", 41))
  end
  if e == "stargate_wormhole_open_fully" then
    local _,_, openState = stargate.getGateStatus()
    if openState then
      if not DHDDial then
        monitor.setCursorPos(21,1)
        monitor.write("Code: "..sendIDC)
        stargate.sendIrisCode(sendIDC)
      end
      
    end
  end
  if e == "stargate_wormhole_incoming" then
    IDCAccepted = false
    monitor.setCursorPos(21,1)
    monitor.setTextColor(colors.red)
    monitor.write("Incoming wormhole detected! ")
    monitor.setTextColor(colors.white)
    if stargate.getIrisState() == "OPENED" or stargate.getIrisState() == "OPENING" then
      stargate.toggleIris()
      if stargate.getIrisState() == "CLOSING" or stargate.getIrisState() == "CLOSED" then
        setInnerColor(colors.lightGray)
        drawGate(colors.gray)
      end
    end
    gateOpen = false
    dialing = false
    if x == 7 then
      chevrons = {1,1,1,1,0,0,1,1,1}
    elseif x == 8 then
      chevrons = {1,1,1,1,1,0,1,1,1}
    elseif x == 9 then
      chevrons = {1,1,1,1,1,1,1,1,1}
    end
    drawGate(colors.gray)
    drawButtons()
  end
  if e == "stargate_wormhole_close_fully" then
    if stargate.getIrisState() == "CLOSED" or stargate.getIrisState() == "CLOSING" then
      stargate.toggleIris()
    end
    monitor.setCursorPos(21,1)
    monitor.write(string.rep(" ", 41))
    setInnerColor(colors.black)
    resetChevrons()
    drawGate(colors.gray)
    drawButtons()
  end
  if e == "stargate_wormhole_close_unstable" then
    gateOpen = false
    dialing = false
    DHDDial = false
  end
  if e == "stargate_iris_code_received" then
    monitor.setCursorPos(21,1)
    monitor.write(x)
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
    drawGate(colors.gray)
  end
  if e == "stargate_iris_toggled" then
    if not IDCAccepted then
      if stargate.getIrisState() == "OPENED" or stargate.getIrisState() == "OPENING" then
        stargate.toggleIris()
      end
    end
  end
end