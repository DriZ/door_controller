-- ========================
-- DOOR SYSTEM - CONTROLLER
-- ========================

local term = _G.term
local colors = _G.colors
local keys = _G.keys

local config = dofile("door/config.lua")
if config.modemSide and config.modemSide ~= "" then pcall(function() rednet.open(config.modemSide) end) end

local passModalOpen = false
local enteredPass = ""

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

local function renderSingleMonitor(monSide, active)
    local m = peripheral.wrap(monSide)
    if m then
        m.setBackgroundColor(active and colors.green or colors.black)
        m.setTextColor(active and colors.black or colors.lime)
        m.clear()
        local w, h = m.getSize()
        local txt = "[   OPEN GATE   ]"
        m.setCursorPos(math.floor((w - #txt)/2) + 1, math.floor(h/2) + 1)
        m.write(txt)
    end
end

local function renderAllMonitors(active)
    for monSide, _ in pairs(activeMonitors) do
        renderSingleMonitor(monSide, active)
    end
end

local function initMonitors()
    activeMonitors = {}
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "monitor" then
            activeMonitors[side] = true
            renderSingleMonitor(side, false)
        end
    end
end

local function drawConsoleUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawPanel(2, 2, 48, 16, "ACCESS CONTROL PANEL DEPLOYED", colors.lime)
    term.setCursorPos(4, 4) term.setTextColor(colors.white) term.write("Sector Domain: " .. config.roomName:upper())
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
                local f = fs.open("door/config.lua", "w")
                f.write("local c = dofile('door/config.lua')\nc.targetId = " .. sid .. "\nreturn c")
                f.close()
                break
            end
        end
    end
end

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
    function()
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
    
    function()
        while true do
            local _, char = os.pullEvent("char")
            if passModalOpen then enteredPass = enteredPass .. char; drawConsoleUI() end
        end
    end,
    
    function()
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
                if peripheral.getType(side) == "monitor" then
                    activeMonitors[side] = true
                    renderSingleMonitor(side, false)
                    drawConsoleUI()
                end
                
            elseif event == "peripheral_detach" then
                local side = p1
                if activeMonitors[side] then
                    activeMonitors[side] = nil
                    drawConsoleUI()
                end
            end
        end
    end
)