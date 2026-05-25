local VERSION = "3.3.0"
-- ============================================================
-- GATEKEEPER OS - CONFIGURATOR ENGINE (v3.3.0 [GKOS UNIFIED])
-- ============================================================

local config = {
    roomName = "GATE SECTOR A",
    openDelay = 4,
    modemSide = "top",
    usePassword = false,
    correctPassword = "1234",
    selectedMonitors = {}
}

local theme = {
    title = colors.lime,
    bg = colors.black,
    border = colors.gray,
    label = colors.gray,
    value = colors.white,
    telemetry = colors.lightBlue,
    statusOk = colors.lime,
    statusWarn = colors.yellow,
    statusError = colors.red
}

if fs.exists("door/config.lua") then
    local ok, res = pcall(dofile, "door/config.lua")
    if ok and type(res) == "table" then 
        for k, v in pairs(res) do config[k] = v end
    end
end

local function autoDetectModem()
    for _, side in ipairs(peripheral.getNames()) do
        local ok, pType = pcall(peripheral.getType, side)
        if ok and pType == "modem" then return side end
    end
    return "top"
end
config.modemSide = autoDetectModem()

if (config.profile or "CONTROLLER") == "RECEIVER" then
    term.setBackgroundColor(theme.bg)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(theme.title)
    print("==================================================")
    print("   [ GATEKEEPER OS - RECEIVER CONFIGURATION ]     ")
    print("==================================================")
    
    config.doorSide = config.doorSide or "bottom"
    term.setTextColor(theme.statusOk)
    print("\n[+] Bound Modem on side: " .. config.modemSide:upper())
    
    term.setTextColor(theme.label)
    print("\nEnter redstone output side connected to the door")
    write("(top/bottom/left/right/back/front):\n> ")
    local dSide = read()
    config.doorSide = (dSide ~= "") and dSide:lower() or (config.doorSide or "bottom")
    
    local f = fs.open("door/config.lua", "w")
    f.writeLine("return {")
    f.writeLine("  profile = \"RECEIVER\",")
    f.writeLine("  modemSide = \"" .. config.modemSide .. "\",")
    f.writeLine("  doorSide = \"" .. config.doorSide .. "\",")
    if config.controllerId then f.writeLine("  controllerId = " .. config.controllerId) else f.writeLine("  controllerId = nil") end
    f.writeLine("}")
    f.close()
    
    print("\n[+] Receiver registry updated.")
    sleep(1)
    shell.run("door/receiver.lua")
    return
end

-- Unified Basalt loading logic
if not package.path:find(";/%?.lua") then package.path = package.path .. ";/?.lua" end
local ok, basalt = pcall(require, "basalt")
if not ok then error("GKOS Error: Basalt UI framework not found. Please run 'gkos install' first.") end

local mainFrame = basalt.getMainFrame():setBackground(theme.bg)

local topBar = mainFrame:addFrame()
    :setPosition(1, 1)
    :setSize(51, 3)
    :setBackground(theme.border)

topBar:addLabel()
    :setPosition(4, 2)
    :setText("[ GATEKEEPER OS - HARDWARE CONFIGURATION ]")
    :setForeground(theme.title)

mainFrame:addLabel()
    :setPosition(1, 4)
    :setSize(51, 1)
    :setText(string.rep("-", 51))
    :setForeground(theme.border)
    :setBackground(theme.bg)

local contentFrame = mainFrame:addFrame()
    :setPosition(2, 5)
    :setSize(49, 14)
    :setBackground(theme.bg)

local step1Frame = contentFrame:addFrame():setPosition(1, 1):setSize(49, 14):setBackground(theme.bg)
local step2Frame = contentFrame:addFrame():setPosition(1, 1):setSize(49, 14):setBackground(theme.bg):setVisible(false)

local monitorsList = {}

step1Frame:addLabel()
    :setPosition(3, 2)
    :setText("SECTOR DOMAIN IDENTIFIER:")
    :setForeground(theme.label)

local inputRoom = step1Frame:addInput()
    :setPosition(3, 3)
    :setSize(43, 1)
    :setBackground(colors.black)
    :setForeground(theme.telemetry)
    :setValue(config.roomName)

step1Frame:addLabel()
    :setPosition(3, 5)
    :setText("ACTUATOR OPEN DELAY (SEC):")
    :setForeground(theme.label)

local inputDelay = step1Frame:addInput()
    :setPosition(3, 6)
    :setSize(10, 1)
    :setBackground(colors.black)
    :setForeground(theme.statusWarn)
    :setInputType("number")
    :setValue(tostring(config.openDelay))

step1Frame:addLabel()
    :setPosition(15, 6)
    :setText("[ 0 = LEVER TOGGLE MODE ]")
    :setForeground(theme.statusWarn)

local infoBox = step1Frame:addFrame()
    :setPosition(3, 8)
    :setSize(43, 3)
    :setBackground(theme.border)

infoBox:addLabel()
    :setPosition(2, 1)
    :setSize(41, 2)
    :setText("Notice: Lever mode maintains active output state\nuntil manually cycled via control matrix.")
    :setForeground(theme.bg)

local btnNext = step1Frame:addButton()
    :setPosition(34, 12)
    :setSize(12, 1)
    :setText("[ NEXT STEP ]")
    :setBackground(theme.statusOk)
    :setForeground(theme.bg)

step2Frame:addLabel()
    :setPosition(3, 1)
    :setText("PERIPHERAL MONITOR GRID MATRIX:")
    :setForeground(theme.telemetry)

local listWidget = step2Frame:addList()
    :setPosition(3, 3)
    :setSize(43, 8)
    :setBackground(colors.black)
    :setForeground(theme.value)

local function refreshMonitorsList()
    listWidget:clear()
    monitorsList = {}
    for _, name in ipairs(peripheral.getNames()) do
        local ok, pType = pcall(peripheral.getType, name)
        if ok and pType == "monitor" then
            local m = peripheral.wrap(name)
            local w, h = m.getSize()
            local sizeStr = math.ceil(w / 7) .. "x" .. math.ceil(h / 5)
            
            local isChecked = true
            if config.selectedMonitors and config.selectedMonitors[name] ~= nil then
                isChecked = config.selectedMonitors[name]
            end
            
            local checkMark = isChecked and "[X]" or "[ ]"
            local displayString = string.format(" %s  %-14s Node Size: %s", checkMark, name:upper(), sizeStr)
            
            listWidget:addItem(displayString)
            table.insert(monitorsList, { name = name, checked = isChecked, str = displayString })
        end
    end
end

listWidget:onClick(function(self, event, button, x, y)
    local itemIdx = listWidget:getItemIndex()
    if itemIdx and monitorsList[itemIdx] then
        local item = monitorsList[itemIdx]
        item.checked = not item.checked
        
        local checkMark = item.checked and "[X]" or "[ ]"
        local m = peripheral.wrap(item.name)
        local w, h = m.getSize()
        local sStr = math.ceil(w / 7) .. "x" .. math.ceil(h / 5)
        item.str = string.format(" %s  %-14s Node Size: %s", checkMark, item.name:upper(), sStr)
        
        listWidget:editItem(itemIdx, item.str)
    end
end)

local btnBack = step2Frame:addButton()
    :setPosition(3, 12)
    :setSize(12, 1)
    :setText("[ RETURN ]")
    :setBackground(theme.statusError)
    :setForeground(colors.white)

local btnFinish = step2Frame:addButton()
    :setPosition(34, 12)
    :setSize(12, 1)
    :setText("[ COMMIT ]")
    :setBackground(theme.statusOk)
    :setForeground(theme.bg)

btnNext:onClick(function()
    config.roomName = inputRoom:getValue()
    config.openDelay = tonumber(inputDelay:getValue()) or 4
    step1Frame:setVisible(false)
    refreshMonitorsList()
    step2Frame:setVisible(true)
end)

btnBack:onClick(function()
    step2Frame:setVisible(false)
    step1Frame:setVisible(true)
end)

btnFinish:onClick(function()
    config.selectedMonitors = {}
    for _, mon in ipairs(monitorsList) do
        config.selectedMonitors[mon.name] = mon.checked
    end
    
    local f = fs.open("door/config.lua", "w")
    f.writeLine("return {")
    f.writeLine("  profile = \"CONTROLLER\",")
    f.writeLine("  roomName = \"" .. config.roomName .. "\",")
    f.writeLine("  modemSide = \"" .. config.modemSide .. "\",")
    f.writeLine("  usePassword = " .. tostring(config.usePassword) .. ",")
    f.writeLine("  correctPassword = \"" .. config.correctPassword .. "\",")
    f.writeLine("  openDelay = " .. config.openDelay .. ",")
    f.writeLine("  selectedMonitors = {")
    for name, state in pairs(config.selectedMonitors) do
        f.writeLine("    [\"" .. name .. "\"] = " .. tostring(state) .. ",")
    end
    f.writeLine("  },")
    if config.targetId then f.writeLine("  targetId = " .. config.targetId) else f.writeLine("  targetId = nil") end
    f.writeLine("}")
    f.close()
    
    basalt.stop()
    term.setBackgroundColor(colors.black) term.clear()
    shell.run("door/controller.lua")
end)

basalt.run()