-- ============================================================
-- GateKeeper OS - CONFIGURATOR MASTER WIZARD (BASALT GUI v4.2)
-- ============================================================

-- 1. СРАЗУ ЗАГРУЖАЕМ ТЕКУЩИЙ КОНФИГ
local config = {
    roomName = "Gate Sector A",
    openDelay = 4,
    modemSide = "top",
    usePassword = false,
    correctPassword = "1234",
    selectedMonitors = {}
}

if fs.exists("door/config.lua") then
    local ok, res = pcall(dofile, "door/config.lua")
    if ok and type(res) == "table" then 
        for k, v in pairs(res) do config[k] = v end
    end
end

-- Автоопределение беспроводного модема
local function autoDetectModem()
    for _, side in ipairs(peripheral.getNames()) do
        local ok, pType = pcall(peripheral.getType, side)
        if ok and pType == "modem" then return side end
    end
    return "top"
end
config.modemSide = autoDetectModem()

-- ============================================================
-- ИЗОЛИРОВАННЫЙ БЛОК ДЛЯ РЕСИВЕРА (БЕЗ GUI)
-- ============================================================
if (config.profile or "CONTROLLER") == "RECEIVER" then
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    print("==================================================")
    print("      GateKeeper OS [RECEIVER CONFIGURATION]      ")
    print("==================================================")
    
    config.doorSide = config.doorSide or "bottom"
    print("\n[+] Bound Modem on side: " .. config.modemSide:upper())
    
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
    return -- Полностью завершаем работу конфигуратора для ресивера
end

-- ============================================================
-- БЛОК ДЛЯ КОНТРОЛЛЕРА (ЗАПУСКАЕТСЯ ТОЛЬКО НА КОНТРОЛЛЕРЕ)
-- ============================================================
local basalt
if fs.exists("door/basalt.lua") then
    if not string.find(package.path, ";/?%.lua") then
        package.path = package.path .. ";/?.lua;/door/?.lua"
    end
    local ok, res = pcall(require, "basalt")
    if ok then basalt = res else basalt = dofile("door/basalt.lua") end
else
    error("Basalt UI framework component is missing! Reinstall via installer.lua")
end

-- Создаём главное окно интерфейса
local mainFrame = basalt.createFrame():setBackground(colors.darkGray)

-- Заголовок системы
mainFrame:addLabel()
    :setPosition(3, 2)
    :setSize(45, 1)
    :setText("GateKeeper OS [CONFIGURATION MATRIX]")
    :setForeground(colors.lime)

-- ФИКС: Заменяем addHorizontalBar на обычную тонкую панель-линию
mainFrame:addLabel()
    :setPosition(3, 3)
    :setSize(45, 1)
    :setBackground(colors.gray)

-- Под-фреймы страниц
local step1Frame = mainFrame:addFrame():setPosition(3, 4):setSize(45, 14):setBackground(colors.black)
local step2Frame = mainFrame:addFrame():setPosition(3, 4):setSize(45, 14):setBackground(colors.black):hide()

local monitorsList = {}

-- ИНИЦИАЛИЗАЦИЯ ШАГА 1
step1Frame:addLabel():setPosition(2, 2):setText("Sector / Room Domain Name:"):setForeground(colors.white)
local inputRoom = step1Frame:addInput()
    :setPosition(2, 3)
    :setSize(30, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)
    :setValue(config.roomName)

step1Frame:addLabel():setPosition(2, 5):setText("Actuator Open Delay (seconds):"):setForeground(colors.white)
local inputDelay = step1Frame:addInput()
    :setPosition(2, 6)
    :setSize(8, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)
    :setInputType("number")
    :setValue(tostring(config.openDelay))

step1Frame:addLabel():setPosition(12, 6):setText("* 0 = Toggle Lever Mode"):setForeground(colors.yellow)

step1Frame:addLabel()
    :setPosition(2, 8)
    :setSize(40, 2)
    :setText("Lever mode leaves the gate open until you\nmanually click [ CLOSE ] on the display.")
    :setForeground(colors.lightGray)

local btnNext = step1Frame:addButton()
    :setPosition(32, 12)
    :setSize(10, 1)
    :setText("NEXT >")
    :setBackground(colors.lime)
    :setForeground(colors.black)

-- ИНИЦИАЛИЗАЦИЯ ШАГА 2
step2Frame:addLabel():setPosition(2, 1):setText("Select Display Panel Matrix:"):setForeground(colors.cyan)

local listWidget = step2Frame:addList()
    :setPosition(2, 3)
    :setSize(40, 7)
    :setBackground(colors.gray)
    :setForeground(colors.white)

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
            
            local checkMark = isChecked and "[*]" or "[ ]"
            local displayString = string.format("%s %-12s (%s)", checkMark, name, sizeStr)
            
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
        
        local checkMark = item.checked and "[*]" or "[ ]"
        local m = peripheral.wrap(item.name)
        local w, h = m.getSize()
        local sStr = math.ceil(w / 7) .. "x" .. math.ceil(h / 5)
        item.str = string.format("%s %-12s (%s)", checkMark, item.name, sStr)
        
        listWidget:editItem(itemIdx, item.str)
    end
end)

local btnBack = step2Frame:addButton()
    :setPosition(2, 12)
    :setSize(10, 1)
    :setText("< BACK")
    :setBackground(colors.red)
    :setForeground(colors.white)

local btnFinish = step2Frame:addButton()
    :setPosition(32, 12)
    :setSize(10, 1)
    :setText("FINISH")
    :setBackground(colors.green)
    :setForeground(colors.white)

-- НАВИГАЦИЯ И СОХРАНЕНИЕ
btnNext:onClick(function()
    config.roomName = inputRoom:getValue()
    config.openDelay = tonumber(inputDelay:getValue()) or 4
    step1Frame:hide()
    refreshMonitorsList()
    step2Frame:show()
end)

btnBack:onClick(function()
    step2Frame:hide()
    step1Frame:show()
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

basalt.autoUpdate()