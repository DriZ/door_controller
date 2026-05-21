-- =================================
-- DOOR SYSTEM - RECEIVER RELAY NODE
-- =================================

local term = _G.term
local colors = _G.colors

local config = dofile("door/config.lua")
local myID = os.getComputerID()

if config.modemSide and config.modemSide ~= "" then pcall(function() rednet.open(config.modemSide) end) end

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

-- АВТОМАТИЧЕСКИЙ РАДИО-ХЕНДШЕЙК ПРИ ОТСУТСТВИИ СВЯЗИ
if not config.controllerId then
    local running = true
    parallel.waitForAny(
        function()
            while running do
                term.setBackgroundColor(colors.black) term.clear()
                drawPanel(2, 2, 48, 10, "AWAITING CORE NETWORK SYNC", colors.lightBlue)
                term.setCursorPos(4, 5) term.setTextColor(colors.white) term.write("Local Address: Node ID " .. myID)
                term.setCursorPos(4, 7) term.write("Broadcasting cryptographic beacons... ")
                local frames = {"-", "\\", "|", "/"}
                for _, frame in ipairs(frames) do
                    term.setCursorPos(42, 7) term.write(frame) sleep(0.1)
                end
            end
        end,
        function()
            while true do
                rednet.broadcast("handshake:" .. myID)
                local sid, msg = rednet.receive(3)
                if msg == ("confirm:" .. myID) then
                    config.controllerId = sid
                    local f = fs.open("door/config.lua", "w")
                    f.write("local c = dofile('door/config.lua')\nc.controllerId = " .. sid .. "\nreturn c")
                    f.close()
                    running = false
                    break
                end
                sleep(1)
            end
        end
    )
end

-- ОСНОВНОЙ ПРОМЫШЛЕННЫЙ ТАКТ РЕЛЕ
term.setBackgroundColor(colors.black) term.clear()
drawPanel(2, 2, 48, 12, "SCADA NODE INFRASTRUCTURE // ONLINE", colors.green)
term.setCursorPos(4, 4) term.setTextColor(colors.white) term.write("Authorized Control Unit ID: " .. config.controllerId)
term.setCursorPos(4, 5) term.write("Actuator Connection Bus: " .. config.doorSide:upper())

while true do
    term.setCursorPos(4, 8) term.setTextColor(colors.gray) term.write("[ SYSTEM STATUS ] Idle. Awaiting matrix pulses...")
    local sid, msg = rednet.receive()
    if sid == config.controllerId and msg == "open" then
        term.setCursorPos(4, 8) term.setTextColor(colors.lime) term.write("[ ENGAGED ] INJECTING ENERGY INTO ACTUATORS  ")
        redstone.setOutput(config.doorSide, true)
        sleep(4)
        redstone.setOutput(config.doorSide, false)
        rednet.send(sid, "done")
    end
end