---@diagnostic disable: undefined-global, undefined-field
-- ===============================
-- IDC EDITOR
-- For managing Iris Codes in IrisCodes.ff
-- ===============================

local irisCodes = dofile("IrisCodes.ff")

local monitor = peripheral.find("monitor")
if not monitor then
  error("Kein Monitor gefunden!")
end

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

local mw, mh = monitor.getSize()

-- State
local editing = true
local selectedIndex = 1
local mode = "list"  -- "list" or "edit" or "add"
local inputMode = "name"  -- "name" or "code"

-- Edit form fields
local editName = ""
local editCode = ""
local editLimited = false

local function saveIrisCodes()
  local file = fs.open("IrisCodes.ff", "w")
  file.write("-- Iris Codes Database\n")
  file.write("-- Struktur: name, code, expires (timestamp), used (boolean)\n\n")
  file.write("return " .. textutils.serialize(irisCodes) .. "\n")
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

local function drawHeader()
  monitor.setBackgroundColor(colors.black)
  monitor.clear()
  if mode == "list" then
    box(1,1,mw,3,"=== IDC EDITOR ===")
  elseif mode == "add" then
    box(1,1,mw,3,"=== ADD NEW CODE ===")
  elseif mode == "edit" then
    box(1,1,mw,3,"=== EDIT CODE ===")
  end
end

local function drawList()
  box(1,4,mw,mh-6,"Iris Codes:")
  
  local startY = 5
  local maxVisible = mh - 10
  
  for i = 1, math.min(#irisCodes, maxVisible) do
    local entry = irisCodes[i]
    local y = startY + i - 1
    
    -- Highlight selected
    if i == selectedIndex and mode == "list" then
      monitor.setTextColor(colors.lime)
      monitor.setBackgroundColor(colors.gray)
    else
      monitor.setTextColor(colors.white)
      monitor.setBackgroundColor(colors.black)
    end
    
    monitor.setCursorPos(2, y)
    local status = ""
    if entry.limited then
      status = entry.used and "[USED] " or "[LIM] "
    else
      status = "[PERM] "
    end
    local display = string.sub(entry.name .. "           ", 1, 15) .. " " .. status .. entry.code
    monitor.write(display)
  end
  
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
end

local function drawEditForm()
  box(1,4,mw,3,"Name:")
  monitor.setCursorPos(2,5)
  monitor.setTextColor(inputMode == "name" and colors.lime or colors.white)
  monitor.write(editName .. "_")
  
  box(1,7,mw,3,"Code:")
  monitor.setCursorPos(2,8)
  monitor.setTextColor(inputMode == "code" and colors.lime or colors.white)
  monitor.write(editCode .. "_")
  
  box(1,10,mw,3,"Limited (one-time):")
  monitor.setCursorPos(2,11)
  if editLimited then
    monitor.setTextColor(colors.lime)
    monitor.write("[X] Yes")
  else
    monitor.setTextColor(colors.white)
    monitor.write("[ ] Yes")
  end
  
  monitor.setTextColor(colors.white)
end

local function drawButtons()
  local btnY = mh - 1
  
  if mode == "list" then
    button(2, btnY, 6, "Add", colors.green)
    button(9, btnY, 6, "Edit", colors.blue)
    button(16, btnY, 8, "Delete", colors.red)
    button(25, btnY, 6, "Toggle", colors.yellow)
    button(33, btnY, 6, "Clear", colors.orange)
    button(41, btnY, 6, "Exit", colors.white)
  elseif mode == "add" or mode == "edit" then
    button(2, btnY, 6, "Save", colors.green)
    button(9, btnY, 6, "Cancel", colors.white)
  end
end

local function drawUI()
  drawHeader()
  if mode == "list" then
    drawList()
  else
    drawEditForm()
  end
  drawButtons()
end

local function startAdd()
  mode = "add"
  editName = ""
  editCode = ""
  editLimited = false
  inputMode = "name"
  drawUI()
end

local function startEdit()
  if selectedIndex > 0 and selectedIndex <= #irisCodes then
    mode = "edit"
    local entry = irisCodes[selectedIndex]
    editName = entry.name or ""
    editCode = entry.code or ""
    editLimited = entry.limited or false
    inputMode = "name"
    drawUI()
  end
end

local function saveEntry()
  if editName == "" or editCode == "" then
    monitor.setCursorPos(2, mh-3)
    monitor.setTextColor(colors.red)
    monitor.write("Name and Code required!")
    monitor.setTextColor(colors.white)
    sleep(1.5)
    monitor.setCursorPos(2, mh-3)
    monitor.write(string.rep(" ", 30))
    return
  end
  
  if mode == "add" then
    table.insert(irisCodes, {
      name = editName,
      code = editCode,
      limited = editLimited,
      used = false
    })
  elseif mode == "edit" and selectedIndex > 0 and selectedIndex <= #irisCodes then
    irisCodes[selectedIndex].name = editName
    irisCodes[selectedIndex].code = editCode
    irisCodes[selectedIndex].limited = editLimited
  end
  
  saveIrisCodes()
  mode = "list"
  drawUI()
end

local function deleteEntry()
  if selectedIndex > 0 and selectedIndex <= #irisCodes then
    table.remove(irisCodes, selectedIndex)
    saveIrisCodes()
    if selectedIndex > #irisCodes then
      selectedIndex = math.max(1, #irisCodes)
    end
    drawUI()
  end
end

local function toggleLimited()
  if selectedIndex > 0 and selectedIndex <= #irisCodes then
    irisCodes[selectedIndex].limited = not irisCodes[selectedIndex].limited
    irisCodes[selectedIndex].used = false  -- Reset used status when toggling
    saveIrisCodes()
    drawUI()
  end
end

local function clearUsed()
  for i, entry in ipairs(irisCodes) do
    if entry.limited then
      entry.used = false
    end
  end
  saveIrisCodes()
  drawUI()
end

local function handleTouch(x, y)
  local btnY = mh - 1
  
  if mode == "list" then
    -- List item selection
    local startY = 5
    local maxVisible = mh - 10
    if y >= startY and y <= startY + math.min(#irisCodes, maxVisible) - 1 then
      selectedIndex = y - startY + 1
      drawList()
      return
    end
    
    -- Buttons
    if y == btnY and x >= 2 and x <= 7 then
      startAdd()
      return
    end
    
    if y == btnY and x >= 9 and x <= 14 then
      startEdit()
      return
    end
    
    if y == btnY and x >= 16 and x <= 23 then
      deleteEntry()
      return
    end
    
    if y == btnY and x >= 25 and x <= 30 then
      toggleLimited()
      return
    end
    
    if y == btnY and x >= 33 and x <= 38 then
      clearUsed()
      return
    end
    
    if y == btnY and x >= 41 and x <= 46 then
      editing = false
      return
    end
    
  elseif mode == "add" or mode == "edit" then
    -- Input field selection
    if y >= 4 and y <= 5 then
      inputMode = "name"
      drawEditForm()
      return
    end
    
    if y >= 7 and y <= 8 then
      inputMode = "code"
      drawEditForm()
      return
    end
    
    -- Toggle limited
    if y >= 10 and y <= 11 then
      editLimited = not editLimited
      drawEditForm()
      return
    end
    
    -- Buttons
    if y == btnY and x >= 2 and x <= 7 then
      saveEntry()
      return
    end
    
    if y == btnY and x >= 9 and x <= 16 then
      mode = "list"
      drawUI()
      return
    end
  end
end

local function handleChar(char)
  if mode == "add" or mode == "edit" then
    if inputMode == "name" then
      if char == "backspace" then
        if #editName > 0 then editName = string.sub(editName, 1, -2) end
      elseif char == "enter" then
        inputMode = "code"
      else
        editName = editName .. char
      end
    elseif inputMode == "code" then
      if char == "backspace" then
        if #editCode > 0 then editCode = string.sub(editCode, 1, -2) end
      elseif char == "enter" then
        inputMode = "name"
      else
        editCode = editCode .. char
      end
    end
    drawEditForm()
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
