---@diagnostic disable: undefined-global
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

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

local mw, mh = monitor.getSize()

-- === STATE ===
local gateOpen = false
local dialing = false
local selectedAddress = nil

local addresses = {
  "Abydos",
  "Chulak",
  "Dakara",
  "Tollana",
  "Atlantis"
}

local origins = {"Andromeda","Aquarius","Aries","Auriga","Bootes","Cancer","Canis Minor","Capricornus","Centaurus","Cetus","Corona Australis","Crater","Equuleus","Eridanus","Gemini","Hydra","Leo","Leo Minor","Libra","Lynx","Microscopium","Monoceros","Norma","Orion","Pegasus","Perseus","Pisces","Piscis Austrinus","Sagittarius","Scorpius","Sculptor","Scutum","Serpens Caput","Sextans","Taurus","Triangulum","Virgo"}

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

local function button(x, y, w, label, active)
  monitor.setCursorPos(x,y)
  if active then
    monitor.setBackgroundColor(colors.gray)
    monitor.setTextColor(colors.black)
  else
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
  end
  monitor.write("[" .. label .. string.rep(" ", w-#label-2) .. "]")
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
end

-- === STARGATE RING ===

local function drawGate(animStep)
  local cx = math.floor(mw/2)
  local cy = math.floor(mh/2)
  monitor.setBackgroundColor(colors.gray)
  for angle=0,360,4 do
    local rad = math.rad(angle)
    local radius = 11
    if dialing then
      radius = 11 + math.sin(math.rad(animStep + angle*3)) * 2
    end
    local x = cx + math.floor(radius * math.sin(rad))
    local y = cy + math.floor(radius * math.cos(rad))
    monitor.setCursorPos(x,y)
    monitor.write(" ")
  end
  monitor.setBackgroundColor(colors.black)
end

-- === MAIN UI DRAW ===
local function drawUI(animStep)
  monitor.clear()

  -- Left box
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

  -- Right box
  box(mw-16,1,18,mh+1,"Origin")
  for i=1,math.min(#origins,mh) do
    monitor.setCursorPos(mw-15,1+i)
    monitor.write(origins[i])
  end

  -- Buttons
  button(23,3,6,"Dial", not gateOpen)
  button(30,3,11,"Add Entry", false)
  button(42,3,12,"Edit Entry", false)

  -- Stargate
  drawGate(0)

  -- Status bar
  box(1,mh-2,mw-17,3)
  monitor.setCursorPos(2,mh-1)
  monitor.write("Energy: "..stargate.getEnergyStored().." FE  Capacitors installed: "..stargate.getCapacitorsInstalled())

  monitor.setCursorPos(mw-28,mh-1)
  if gateOpen then
    monitor.setTextColor(colors.red)
    monitor.write("CLOSE GATE")
  else
    monitor.setTextColor(colors.green)
    monitor.write("Gate Closed")
  end
  monitor.setTextColor(colors.white)
end

-- === DIAL ANIMATION ===
local function dialSequence()
  dialing = true
  for i=1,30 do
    drawUI(i*6)
    sleep(0.05)
  end
  gateOpen = true
  dialing = false
end

-- === TOUCH HANDLING ===
local function handleTouch(x,y)
  -- Address select
  if x >= 3 and x <= 18 and y >= 4 then
    local index = y - 3
    if addresses[index] then
      selectedAddress = index
    end
  end

  -- Dial button
  if x>=23 and x<=32 and y==3 and not gateOpen and selectedAddress then
    dialSequence()
  end

  -- Close gate
  if gateOpen and x>=mw-28 and y==mh-2 then
    gateOpen = false
  end
end

-- === MAIN LOOP ===
drawUI()

--[[while true do
  local e, side, x, y = os.pullEvent()
  if e == "monitor_touch" then
    handleTouch(x,y)
    drawUI()
  end
]]--end
