-- ============================================================
-- SCADA DOOR SYSTEM - CONTROLLER MAIN ENGINE (CONFIG SHIELD v2.4)
-- ============================================================

local term = _G.term
local colors = _G.colors
local keys = _G.keys

local config = dofile("door/config.lua")
if config.modemSide and config.modemSide ~= "" then pcall(function() rednet.open(config.modemSide) end) end

local passModalOpen = false
local enteredPass = ""

-- Оперативная матрица активных мониторов
local activeMonitors = {}

local function drawPanel(x, y, w, h, title, borderCol)
    term.setTextColor(borderCol or colors.gray)
    for i = 0, h-1 do
        term.setCursorPos(x, y+i)
        if i == 0 or i == h-1 then term.write("+" .. string.rep("-", w-2) .. "+")
        else term.write("|" .. string.rep(" ", w-2) .. "|") end
    end
    if title then
        term.setCursorPos(x+2, y) term.setTextColor(colors.white) term.write(" " .. title .. " ")
    end
end

-- Безопасная и адаптивная отрисовка кнопки на мониторах
local function renderSingleMonitor(monSide, active)
    if not monSide or not string.find(monSide:lower(), "monitor") then return end
    
    local ok, m = pcall(peripheral.wrap, monSide)
    if ok and m then
        local w, h = m.getSize()
        pcall(function()
            if w > 30 or h > 15 then m.setTextScale(2) else m.setTextScale(1) end
        end)
        
        w, h = m.getSize()
        m.setBackgroundColor(active and colors.green or colors.black)
        m.setTextColor(active and colors.black or colors.lime)
        m.clear()
        
        local txt = "[   OPEN GATE   ]"
        if w < #txt then
            txt = "[ OPEN ]"
            if w < #txt then txt = "OPEN" end
        end
        
        local posX = math.floor((w - #txt) / 2) + 1
        local posY = math.floor(h / 2) + 1
        if posX < 1 then posX = 1 end
        if posY < 1 then posY = 1 end
        
        m.setCursorPos(posX, posY)
        m.write(txt)
    end
end

local function renderAllMonitors(active)
    for monSide, _ in pairs(activeMonitors) do
        renderSingleMonitor(monSide, active)
    end
end

-- Безопасная проверка типа
local function isMonitor(side)
    if not side then return false end
    if string.find(side:lower(), "monitor") then return true end
    local ok, pType = pcall(peripheral.getType, side)
    return ok and pType == "monitor"
end

-- Сканирование сети при старте
local function initMonitors()
    activeMonitors = {}
    local ok, pList = pcall(peripheral.getNames)
    if not ok or not pList then return end
    
    for _, side in ipairs(pList) do
        if isMonitor(side) then
            activeMonitors[side] = true
            renderSingleMonitor(side, false)
        end
    end
end

local function drawConsoleUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawPanel(2, 2, 48, 16, "ACCESS CONTROL PANEL DEPLOYED", colors.lime)
    term.setCursorPos(4, 4) term.setTextColor(colors.white) term.write("Sector Domain: " .. (config.roomName or "UNNAMED SECTOR"):upper())
    term.setCursorPos(4, 5) term.write("Uplink Address Node: " .. (config.targetId or "RESOLVING MATRIX..."))
    
    local monCount = 0
    for _ in pairs(activeMonitors) do monCount = monCount + 1 end
    term.setCursorPos(4, 6) term.setTextColor(colors.lightBlue) term.write("Active Display Panels: " .. monCount)
    
    term.setCursorPos(4, 9)
    term.setBackgroundColor(colors.gray) term.setTextColor(colors.lime)
    term.write("    [ PRESS SPACEBAR TO ACTUATE MATRIX ]   ")
    term.setBackgroundColor(colors.black)
    
    if passModalOpen then
        drawPanel(5, 11, 42, 5, "SECURITY ENCRYPTION OVERRIDE", colors.red)
        term.setCursorPos(7, 13) term.setTextColor(colors.white)
        term.write("CRYPT-KEY: " .. string.rep("*", #enteredPass))
    end
end

-- ============================================================
-- ИСПРАВЛЕННЫЙ БЛОК СИНХРОНИЗАЦИИ (БЕЗ РЕКУРСИИ ДОФАЙЛА)
-- ============================================================
if not config.targetId then
    term.clear()
    drawPanel(2, 2, 48, 8, "ESTABLISHING TELEMETRY LINK", colors.lightBlue)
    term.setCursorPos(4, 4) term.setTextColor(colors.white) term.write("Awaiting handshakes from relay sub-nodes...")
    while true do
        local sid, msg = rednet.receive(4)
        if type(msg) == "string" then
            local rid = msg:match("^handshake:(%d+)$")
            if rid then
                rednet.send(sid, "confirm:" .. rid)
                config.targetId = sid
                
                -- Полная перезапись структуры таблицы в виде чистого текста
                local f = fs.open("door/config.lua", "w")
                f.writeLine("return {")
                f.writeLine("  profile = \"" .. (config.profile or "CONTROLLER") .. "\",")
                f.writeLine("  roomName = \"" .. (config.roomName or "Gate Sector") .. "\",")
                f.writeLine("  modemSide = \"" .. (config.modemSide or "top") .. "\",")
                f.writeLine("  usePassword = " .. tostring(config.usePassword or false) .. ",")
                f.writeLine("  correctPassword = \"" .. (config.correctPassword or "1234") .. "\",")
                f.writeLine("  targetId = " .. sid)
                f.writeLine("}")
                f.close()
                break
            end
        end
    end
end
-- ============================================================

initMonitors()
drawConsoleUI()

local function triggerDoorOpening()
    renderAllMonitors(true)
    rednet.send(config.targetId, "open")
    term.setCursorPos(4, 15) term.setTextColor(colors.green) term.write("[TRANSMITTING] VECTOR ACTION ACTIVE.      ")
    
    local timer = os.startTimer(6)
    while true do
        local _, id, msg = os.pullEvent()
        if id == timer then break end
        if id == "rednet_message" and msg == "done" then
            term.setCursorPos(4, 15) term.setTextColor(colors.lime) term.write("[CONFIRMED] TARGET SECTOR CYCLED.       ")
            break
        end
    end
    renderAllMonitors(false)
    drawConsoleUI()
end

parallel.waitForAny(
    function() -- Клавиатура терминала
        while true do
            local _, key = os.pullEvent("key")
            if key == keys.space and not passModalOpen then
                if config.usePassword then
                    passModalOpen = true; enteredPass = ""; drawConsoleUI()
                else triggerDoorOpening() end
            elseif passModalOpen then
                if key == keys.enter then
                    if enteredPass == config.correctPassword then
                        passModalOpen = false; drawConsoleUI(); triggerDoorOpening()
                    else
                        term.setCursorPos(7, 15) term.setTextColor(colors.red) term.write("ACCESS DENIED: CRYPTOKEY INVALID")
                        sleep(1.5); passModalOpen = false; drawConsoleUI()
                    end
                elseif key == keys.backspace then
                    enteredPass = enteredPass:sub(1, #enteredPass - 1)
                    drawConsoleUI()
                end
            end
        end
    end,
    
    function() -- Текстовый буфер пароля
        while true do
            local _, char = os.pullEvent("char")
            if passModalOpen then enteredPass = enteredPass .. char; drawConsoleUI() end
        end
    end,
    
    function() -- Менеджер ивентов сети
        while true do
            local event, p1, p2, p3 = os.pullEvent()
            
            if event == "monitor_touch" then
                local side = p1
                if activeMonitors[side] and not passModalOpen then
                    if config.usePassword then
                        passModalOpen = true; enteredPass = ""; drawConsoleUI()
                    else triggerDoorOpening() end
                end
                
            elseif event == "peripheral" then
                local side = p1
                if isMonitor(side) then
                    activeMonitors[side] = true
                    renderSingleMonitor(side, false)
                    drawConsoleUI()
                end
                
            elseif event == "peripheral_detach" then
                local side = p1
                if side and activeMonitors[side] then
                    activeMonitors[side] = nil
                    drawConsoleUI()
                end
            end
        end
    end
)