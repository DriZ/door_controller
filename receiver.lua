-- ============================================================
-- SCADA DOOR SYSTEM - RECEIVER RELAY NODE (AUTO-RESET v2.2)
-- ============================================================

local term = _G.term
local colors = _G.colors
local keys = _G.keys

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

local function establishLink()
    local controllerFound = false
    config.controllerId = nil
    
    parallel.waitForAny(
        function()
            while not controllerFound do
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
                local sid, msg = rednet.receive(2)
                if msg == ("confirm:" .. myID) then
                    config.controllerId = sid
                    
                    local f = fs.open("door/config.lua", "w")
                    f.write("return {\n")
                    f.write("  profile = \"RECEIVER\",\n")
                    f.write("  modemSide = \"" .. (config.modemSide or "left") .. "\",\n")
                    f.write("  doorSide = \"" .. (config.doorSide or "bottom") .. "\",\n")
                    f.write("  controllerId = " .. sid .. "\n")
                    f.write("}")
                    f.close()
                    
                    controllerFound = true
                    break
                end
                sleep(0.5)
            end
        end
    )
end

if not config.controllerId then
    establishLink()
end

local function mainLifecycle()
    while true do
        term.setBackgroundColor(colors.black) term.clear()
        drawPanel(2, 2, 48, 13, "SCADA NODE INFRASTRUCTURE // ONLINE", colors.green)
        term.setCursorPos(4, 4) term.setTextColor(colors.white) term.write("Authorized Control Unit ID: " .. tostring(config.controllerId))
        term.setCursorPos(4, 5) term.write("Actuator Connection Bus: " .. config.doorSide:upper())
        
        term.setCursorPos(4, 8) term.setTextColor(colors.gray) term.write("[ SYSTEM STATUS ] Idle. Monitoring matrix...")
        term.setCursorPos(4, 11) term.setTextColor(colors.yellow) term.write("[ PRESS SPACEBAR ] To unbind and reset link")
        
        local sid, msg = rednet.receive()
        if sid == config.controllerId and msg == "open" then
            term.setCursorPos(4, 8) term.setTextColor(colors.lime) term.write("[ ENGAGED ] INJECTING ENERGY INTO ACTUATORS  ")
            redstone.setOutput(config.doorSide, true)
            sleep(4)
            redstone.setOutput(config.doorSide, false)
            rednet.send(sid, "done")
        end
    end
end

parallel.waitForAny(
    mainLifecycle,
    function()
        while true do
            local _, key = os.pullEvent("key")
            if key == keys.space or key == keys.enter then
                establishLink()
                break
            end
        end
    end
)