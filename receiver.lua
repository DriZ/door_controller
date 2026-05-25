-- ============================================================
-- GATEKEEPER OS - WIRELESS ACTUATOR RELAY (v3.2.0 [GKOS UNIFIED])
-- ============================================================

local term = _G.term
local colors = _G.colors
local keys = _G.keys

local theme = {
    title = colors.lime,
    bg = colors.black,
    border = colors.gray,
    label = colors.gray,
    value = colors.white,
    telemetry = colors.cyan,
    statusOk = colors.lime,
    statusWarn = colors.yellow,
    statusError = colors.red
}

local config = dofile("door/config.lua")

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

local function saveConfig()
    local f = fs.open("door/config.lua", "w")
    f.writeLine("return {")
    f.writeLine("  profile = \"RECEIVER\",")
    f.writeLine("  modemSide = \"" .. (config.modemSide or "left") .. "\",")
    f.writeLine("  doorSide = \"" .. (config.doorSide or "bottom") .. "\",")
    if config.controllerId then
        f.writeLine("  controllerId = " .. config.controllerId)
    else
        f.writeLine("  controllerId = nil")
    end
    f.writeLine("}")
    f.close()
end

local function establishLink()
    term.setBackgroundColor(theme.bg) term.clear()
    drawPanel(2, 2, 48, 10, "[ ESTABLISHING TELEMETRY LINK ]", theme.telemetry)
    term.setCursorPos(4, 4) term.setTextColor(theme.value)
    term.write("BROADCASTING BEACONS VIA " .. config.modemSide:upper() .. "...")
    term.setCursorPos(4, 6) term.setTextColor(theme.label)
    term.write("Awaiting validation packet from Controller...")
    
    local myId = os.getComputerID()
    local token = math.random(1000, 9999)
    
    local timer = os.startTimer(0.5)
    
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "timer" and p1 == timer then
            rednet.broadcast("handshake:" .. token)
            timer = os.startTimer(0.5)
            
        elseif event == "rednet_message" and p2 == "confirm:" .. token then
            config.controllerId = p1
            saveConfig()
            break
        end
    end
end

local function mainLifecycle()
    while true do
        term.setBackgroundColor(theme.bg) term.clear()
        drawPanel(2, 2, 48, 13, "[ NODE INFRASTRUCTURE - ONLINE ]", theme.statusOk)
        term.setCursorPos(4, 4) term.setTextColor(theme.label) term.write("AUTHORIZED CONTROL UNIT ID: ") term.setTextColor(theme.value) term.write(tostring(config.controllerId))
        term.setCursorPos(4, 5) term.setTextColor(theme.label) term.write("ACTUATOR CONNECTION BUS:    ") term.setTextColor(theme.telemetry) term.write(config.doorSide:upper())
        
        local rsStatus = redstone.getOutput(config.doorSide)
        term.setCursorPos(4, 8)
        if rsStatus then
            term.setTextColor(theme.statusOk) term.write("[ METRIC ] OUTPUT BUS ACTIVE (POWER ON)  ")
        else
            term.setTextColor(theme.label) term.write("[ SYSTEM STATUS ] IDLE. MONITORING MATRIX...")
        end
        
        term.setCursorPos(4, 11) term.setTextColor(theme.statusWarn) term.write("[ PRESS SPACEBAR ] TO UNBIND AND RESET LINK")
        
        local abort = parallel.waitForAny(
            function()
                while true do
                    local sid, msg = rednet.receive()
                    if sid == config.controllerId then
                        if msg == "open:toggle" then
                            redstone.setOutput(config.doorSide, true)
                        elseif msg == "close" then
                            redstone.setOutput(config.doorSide, false)
                        elseif string.find(msg, "^open") then
                            local customDelay = msg:match("^open:(%d+)$")
                            local sleepTime = customDelay and tonumber(customDelay) or 4
                            
                            term.setCursorPos(4, 8) term.setTextColor(theme.statusOk) term.write("[ ENGAGED ] INJECTING ENERGY INTO ACTUATORS  ")
                            redstone.setOutput(config.doorSide, true)
                            sleep(sleepTime)
                            redstone.setOutput(config.doorSide, false)
                            rednet.send(sid, "done")
                        end
                    end
                end
            end,
            
            function()
                while true do
                    local _, key = os.pullEvent("key")
                    if key == keys.space then
                        return true 
                    end
                end
            end
        )
        
        if abort then
            redstone.setOutput(config.doorSide, false)
            config.controllerId = nil
            saveConfig()
            break
        end
    end
end

if config.modemSide and config.modemSide ~= "" then 
    pcall(function() rednet.open(config.modemSide) end) 
end

while true do
    if not config.controllerId then
        establishLink()
    end
    mainLifecycle()
end