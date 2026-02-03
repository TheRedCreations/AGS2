---@diagnostic disable: undefined-global, undefined-field
-- ===============================
-- STARGATE DIALING COMPUTER
-- CC:Tweaked Monitor Version
-- ===============================

-- === MONITOR SETUP ===
local monitor = peripheral.find("monitor")
if not monitor then
  error("Kein Monitor gefunden!")
end

local stargate = peripheral.find("stargate")
if not stargate then
  error("Kein Stargate gefunden!")
end
local configsf = dofile("selftest.lua")

local function saveConfig()
  local file = fs.open("selftest.lua", "w")
  file.write("local config = " .. textutils.serialize(configsf) .. "\nreturn config")
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

-- === STATE ===
local gateOpen = false
local dialing = false
local selectedAddress = nil
local changed = {}
local runtime = true

local addresses = {
  "Abydos"
}

local symbols = {"Andromeda","Aquarius","Aries","Auriga","Bootes","Cancer","Canis Minor","Capricornus","Centaurus","Cetus","Corona Australis","Crater","Equuleus","Eridanus","Gemini","Hydra","Leo","Leo Minor","Libra","Lynx","Microscopium","Monoceros","Norma","Orion","Pegasus","Perseus","Pisces","Piscis Austrinus","Sagittarius","Scorpius","Sculptor","Scutum","Serpens Caput","Sextans","Taurus","Triangulum","Virgo"}

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

local function drawGate(animStep,gatecolor)
  local cx = math.floor(mw/2)
  local cy = math.floor(mh/2)
  monitor.setBackgroundColor(gatecolor)
  local radius = 11
  if dialing then
    radius = 11 + math.sin(math.rad(animStep)) * 2
  end
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
  monitor.setBackgroundColor(colors.black)
end

-- === DRAW FUNCTIONS ===
local function drawLeftBox()
  box(1,1,20,mh-3,"Gate Entries")
  for i,v in ipairs(addresses) do
    monitor.setCursorPos(2,1+i)
    if selectedAddress == i then
      monitor.setTextColor(colors.lime)
    else
      monitor.setTextColor(colors.white)
    end
    monitor.write(v)
  end
end

local function drawRightBox()
  box(mw-16,1,18,mh+1,"Origin")
  for i=1,math.min(#symbols,mh) do
    monitor.setCursorPos(mw-15,1+i)
    if selectedChevron == i then
      monitor.setTextColor(colors.lime)
    else
      monitor.setTextColor(colors.white)
    end
    monitor.write(symbols[i])
  end
end

local function drawButtons()
  button(23,3,6,"Dial", colors.white)
  button(30,3,11,"Add Entry", colors.white)
  button(42,3,12,"Edit Entry", colors.white)
  button(23,mh-3,6,"Exit", colors.white)
  if stargate.getIrisState() == "OPENED" or stargate.getIrisState() == "OPENING" then
    button(30,mh-3,10," Iris open ", colors.green)
  end
  if stargate.getIrisState() == "CLOSED" or stargate.getIrisState() == "CLOSING" then
    button(30,mh-3,12,"Iris closed", colors.red)
  end
end

local function drawStatus()
  box(1,mh-2,mw-18,3)
  monitor.setCursorPos(2,mh-1)
  monitor.write("Energy: "..stargate.getEnergyStored().." FE  Capacitors installed: "..stargate.getCapacitorsInstalled())

  monitor.setCursorPos(mw-29,mh-1)
  if gateOpen then
    monitor.setTextColor(colors.red)
    monitor.write("CLOSE GATE")
  else
    monitor.setTextColor(colors.green)
    monitor.write("Gate Closed")
  end
  monitor.setTextColor(colors.white)
end

-- === MAIN UI DRAW ===
local function drawUI(animStep)
  if not animStep then
    monitor.clear()
    drawLeftBox()
    drawRightBox()
    drawButtons()
    drawStatus()
  end
  drawGate(0,colors.gray)
end

-- === DIAL ANIMATION ===
local function dialSequence()
  dialing = true
  sleep(1)
  gateOpen = true
  dialing = false
end

-- === TOUCH HANDLING ===
local function handleTouch(x,y)
  -- Address select
  if x >= 2 and x <= 18 and y >= 2 then
    local index = y - 1
    if addresses[index] then
      selectedAddress = index
      changed.left = true
    end
  end

  -- Dial button
  if x>=23 and x<=32 and y==3 and not gateOpen and selectedAddress then
    dialSequence()
    changed.buttons = true
    changed.status = true
  end

  -- Close gate
  if gateOpen and x>=mw-29 and x<mw-19 and y==mh-1 then
    gateOpen = false
    changed.buttons = true
    changed.status = true
  end

  -- Iris button
  if x>=30 and x<=36 and y==mh-3 then
    stargate.toggleIris()
    sleep(0.5)
    changed.buttons = true
  end

  -- Exit button
  if runtime and x>=23 and x<=29 and y==mh-3 then
    runtime = false
    monitor.setCursorPos(23,1)
    monitor.setTextColor(colors.red)
    monitor.write("Shutting down...")
    monitor.setTextColor(colors.white)
    sleep(2)
    drawGate(0,colors.black)
    monitor.clear()
  end
end

-- === MAIN LOOP ===
drawUI()

while runtime do
  local e, side, x, y = os.pullEvent()
  if e == "monitor_touch" then
    handleTouch(x,y)
    if changed.left then drawLeftBox() changed.left = false end
    if changed.right then drawRightBox() changed.right = false end
    if changed.buttons then drawButtons() changed.buttons = false end
    if changed.status then drawStatus() changed.status = false end
    if runtime then
      drawGate(0,colors.gray)
    else
      drawGate(0,colors.black)
    end
  end
end