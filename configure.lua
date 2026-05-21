-- ============================================================
-- GateKeeper OS - CONFIGURATOR MASTER WIZARD (BASALT GUI v4.0)
-- ============================================================

-- Загружаем Basalt и текущий конфиг
local basalt = require("door/basalt")
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

-- Создаём главное окно интерфейса (Базовый контейнер)
local mainFrame = basalt.createFrame()
    :setBackground(colors.black)

-- Заголовок системы (Общий для всех экранов)
mainFrame:addLabel()
    :setPosition(3, 2)
    :setSize(45, 1)
    :setText("GateKeeper OS [CONFIGURATION MATRIX]")
    :setForeground(colors.lime)

mainFrame:addHorizontalBar()
    :setPosition(3, 3)
    :setSize(45, 1)
    :setBackground(colors.gray)

-- Создаём под-фреймы (Страницы мастера настроек)
local step1Frame = mainFrame:addFrame():setPosition(3, 4):setSize(45, 14):setBackground(colors.black)
local step2Frame = mainFrame:addFrame():setPosition(3, 4):setSize(45, 14):setBackground(colors.black):hide()

-- Переменные для хранения промежуточных GUI-данных
local monitorsList = {}

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ ШАГА 1 (Ввод параметров шлюза)
-- ============================================================

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

step1Frame:addLabel()
    :setPosition(12, 6)
    :setText("* 0 = Toggle Lever Mode")
    :setForeground(colors.yellow)

step1Frame:addLabel()
    :setPosition(2, 8)
    :setSize(40, 2)
    :setText("Lever mode leaves the gate open until you\nmanually click [ CLOSE ] on the display.")
    :setForeground(colors.lightGray)

-- Кнопка переключения на Шаг 2
local btnNext = step1Frame:addButton()
    :setPosition(32, 12)
    :setSize(10, 1)
    :setText("NEXT >")
    :setBackground(colors.lime)
    :setForeground(colors.black)

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ ШАГА 2 (Интерактивная таблица мониторов)
-- ============================================================

step2Frame:addLabel():setPosition(2, 1):setText("Select Display Panel Matrix:"):setForeground(colors.cyan)

-- Используем продвинутый виджет списка Basalt с поддержкой встроенных чекбоксов
local listWidget = step2Frame:addList()
    :setPosition(2, 3)
    :setSize(40, 7)
    :setBackground(colors.gray)
    :setForeground(colors.white)

-- Функция динамического сканирования сети
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
            
            -- Форматируем строку под твою таблицу
            local checkMark = isChecked and "[*]" or "[ ]"
            local displayString = string.format("%s %-12s (%s)", checkMark, name, sizeStr)
            
            listWidget:addItem(displayString)
            table.insert(monitorsList, { name = name, checked = isChecked, str = displayString })
        end
    end
end

-- Обработка клика по элементу списка (имитация чекбокса)
listWidget:onClick(function(self, event, button, x, y)
    local itemIdx = listWidget:getItemIndex()
    if itemIdx and monitorsList[itemIdx] then
        local item = monitorsList[itemIdx]
        item.checked = not item.checked
        
        local checkMark = item.checked and "[*]" or "[ ]"
        local sizeStr = item.displayString -- сохраняем структуру
        -- Перерисовываем строку
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

-- ============================================================
-- НАВИГАЦИОННАЯ ЛОГИКА И СОХРАНЕНИЕ
-- ============================================================

btnNext:onClick(function()
    config.roomName = inputRoom:getValue()
    config.openDelay = tonumber(inputDelay:getValue()) or 4
    step1Frame:hide()
    refreshMonitorsList() -- Сканируем периферию прямо перед выводом таблицы
    step2Frame:show()
end)

btnBack:onClick(function()
    step2Frame:hide()
    step1Frame:show()
end)

btnFinish:onClick(function()
    -- Собираем чекнутые мониторы из памяти виджета
    config.selectedMonitors = {}
    for _, mon in ipairs(monitorsList) do
        config.selectedMonitors[mon.name] = mon.checked
    end
    
    -- Сохраняем итоговый файл конфигурации контроллера
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
    
    basalt.stop() -- Корректно завершаем UI поток Basalt
    term.setBackgroundColor(colors.black) term.clear()
    shell.run("door/controller.lua") -- Запускаем рабочее ядро
end)

-- Проверка профиля: если настраиваем ресивер, GUI контроллера нам не нужен
if (config.profile or "CONTROLLER") == "RECEIVER" then
    config.doorSide = config.doorSide or "bottom"
    
    local f = fs.open("door/config.lua", "w")
    f.writeLine("return {")
    f.writeLine("  profile = \"RECEIVER\",")
    f.writeLine("  modemSide = \"" .. config.modemSide .. "\",")
    f.writeLine("  doorSide = \"" .. config.doorSide .. "\",")
    if config.controllerId then f.writeLine("  controllerId = " .. config.controllerId) else f.writeLine("  controllerId = nil") end
    f.writeLine("}")
    f.close()
    
    shell.run("door/receiver.lua")
else
    -- Если это КОНТРОЛЛЕР - запускаем графическую оболочку Basalt на выполнение
    basalt.autoUpdate()
end