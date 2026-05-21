-- ==============================================
-- GATEKEEPER OS - ADVANCED GUI CONFIGURATOR v3.0
-- ==============================================

local term = _G.term
local colors = _G.colors

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

local function autoDetectModem()
    for _, side in ipairs(peripheral.getNames()) do
        local ok, pType = pcall(peripheral.getType, side)
        if ok and pType == "modem" then return side end
    end
    return "top"
end
config.modemSide = autoDetectModem()

local function drawHeader(title)
    term.setBackgroundColor(colors.gray)
    term.clear()
    term.setBackgroundColor(colors.black)
    for i = 2, 18 do
        term.setCursorPos(2, i) term.write(string.rep(" ", 47))
    end
    term.setCursorPos(3, 2) term.setTextColor(colors.lime) term.write("GATEKEEPER OS GLOBAL CONFIGURATION MATRIX")
    term.setCursorPos(3, 3) term.setTextColor(colors.gray) term.write(string.rep("-", 45))
    if title then
        term.setCursorPos(4, 4) term.setTextColor(colors.cyan) term.write(">> " .. title:upper())
    end
end

local function drawButton(x, y, w, text, bgCol, txtCol)
    term.setBackgroundColor(bgCol)
    term.setTextColor(txtCol)
    term.setCursorPos(x, y)
    local pad = math.floor((w - #text) / 2)
    term.write(string.rep(" ", pad) .. text .. string.rep(" ", w - #text - pad))
    term.setBackgroundColor(colors.black)
end

local function drawInputField(x, y, w, text, active)
    term.setBackgroundColor(active and colors.lightGray or colors.gray)
    term.setTextColor(active and colors.black or colors.white)
    term.setCursorPos(x, y)
    local disp = text:sub(1, w - 2)
    term.write(" " .. disp .. string.rep(" ", w - #disp - 1))
    term.setBackgroundColor(colors.black)
end

local function getConnectedMonitors()
    local list = {}
    for _, name in ipairs(peripheral.getNames()) do
        local ok, pType = pcall(peripheral.getType, name)
        if ok and pType == "monitor" then
            local m = peripheral.wrap(name)
            local w, h = m.getSize()
            local blockW = math.ceil(w / 7)
            local blockH = math.ceil(h / 5)
            if blockW < 1 then blockW = 1 end
            if blockH < 1 then blockH = 1 end
            
            local checked = true
            if config.selectedMonitors and next(config.selectedMonitors) then
                checked = config.selectedMonitors[name] or false
            end

            table.insert(list, {
                name = name,
                sizeStr = blockW .. "x" .. blockH,
                checked = checked
            })
        end
    end
    return list
end

local function runStep1()
    local activeField = 0
    local roomNameStr = tostring(config.roomName or "Gate Sector A")
    local delayStr = tostring(config.openDelay or "4")

    while true do
        drawHeader("Step 1: Core Telemetry & Timing")
        
        term.setCursorPos(4, 6) term.setTextColor(colors.white) term.write("Sector / Room Domain Name:")
        drawInputField(4, 7, 30, roomNameStr, activeField == 1)
        
        term.setCursorPos(4, 9) term.setTextColor(colors.white) term.write("Actuator Open Delay (seconds):")
        drawInputField(4, 10, 10, delayStr, activeField == 2)
        
        term.setCursorPos(16, 10) term.setTextColor(colors.yellow) term.write("* 0 = Toggle Lever Mode")
        term.setCursorPos(4, 12) term.setTextColor(colors.gray) 
        term.write("Lever mode leaves the gate open until you")
        term.setCursorPos(4, 13) term.write("manually click [ CLOSE ] on the display.")
        
        drawButton(35, 16, 12, "NEXT >", colors.lime, colors.black)
        
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "mouse_click" and p1 == 1 then
            local mx, my = p2, p3
            
            if mx >= 4 and mx <= 34 and my == 7 then activeField = 1
            elseif mx >= 4 and mx <= 14 and my == 10 then activeField = 2
            elseif mx >= 35 and mx <= 47 and my == 16 then
                config.roomName = roomNameStr ~= "" and roomNameStr or "Gate Sector A"
                config.openDelay = tonumber(delayStr) or 0
                break
            else activeField = 0 end
            
        elseif event == "char" and activeField > 0 then
            if activeField == 1 then roomNameStr = roomNameStr .. p1
            elseif activeField == 2 and p1:match("%d") then delayStr = delayStr .. p1 end
            
        elseif event == "key" and activeField > 0 then
            if p1 == keys.backspace then
                if activeField == 1 then roomNameStr = roomNameStr:sub(1, #roomNameStr - 1)
                elseif activeField == 2 then delayStr = delayStr:sub(1, #delayStr - 1) end
            elseif p1 == keys.enter then activeField = 0 end
        end
    end
end

local function runStep2()
    local monitors = getConnectedMonitors()
    
    while true do
        drawHeader("Step 2: Display Panel Matrix")
        
        term.setCursorPos(4, 6) term.setTextColor(colors.lightBlue)
        term.write("[X] | Monitor ID       | Form Factor")
        term.setCursorPos(4, 7) term.setTextColor(colors.gray)
        term.write(string.rep("-", 42))
        
        if #monitors == 0 then
            term.setCursorPos(4, 9) term.setTextColor(colors.red)
            term.write("NO ACTIVE MONITORS DETECTED IN NET!")
            term.setCursorPos(4, 10) term.setTextColor(colors.gray)
            term.write("Check your Wired Modems / Network cables.")
        else
            for i, mon in ipairs(monitors) do
                if i > 6 then break end
                local y = 7 + i
                term.setCursorPos(4, y)
                term.setTextColor(mon.checked and colors.lime or colors.red)
                term.write(mon.checked and "[*]" or "[ ]")
                
                term.setTextColor(colors.white)
                term.setCursorPos(9, y) term.write("| " .. mon.name .. string.rep(" ", 17 - #mon.name))
                term.setCursorPos(28, y) term.write("| " .. mon.sizeStr)
            end
        end
        
        drawButton(4, 16, 12, "< BACK", colors.red, colors.white)
        drawButton(35, 16, 12, "FINISH", colors.green, colors.white)
        
        local event, btn, mx, my = os.pullEvent("mouse_click")
        if btn == 1 then
            if mx >= 4 and mx <= 15 and my == 16 then return false end
            
            if mx >= 35 and mx <= 47 and my == 16 then
                config.selectedMonitors = {}
                for _, m in ipairs(monitors) do
                    config.selectedMonitors[m.name] = m.checked
                end
                return true
            end
            
            if mx >= 4 and mx <= 7 and my >= 8 and my <= 13 then
                local idx = my - 7
                if monitors[idx] then
                    monitors[idx].checked = not monitors[idx].checked
                end
            end
        end
    end
end

term.clear()

drawHeader("Profile Detection")
term.setCursorPos(4, 6) term.setTextColor(colors.white)
print("Configuring node profile alignment: " .. tostring(config.profile or "CONTROLLER"))
sleep(1)

if (config.profile or "CONTROLLER") == "CONTROLLER" then
    while true do
        runStep1()
        local finished = runStep2()
        if finished then break end
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
else
    drawUI("RECEIVER HARDWARE MAPPING")
    
    if autoModem then
        newConfig.modemSide = autoModem
        print("[+] Automatically mapped modem on side: " .. autoModem:upper())
        sleep(1)
    else
        write("Enter modem peripheral side (top/bottom/left/right/back):\n> ")
        local mSide = read()
        newConfig.modemSide = (mSide ~= "") and mSide:lower() or (config.modemSide or "left")
    end

    print("")

    write("Enter redstone output side connected to the door\n(top/bottom/left/right/back/front):\n> ")
    local dSide = read()
    newConfig.doorSide = (dSide ~= "") and dSide:lower() or (config.doorSide or "bottom")

    local f = fs.open("door/config.lua", "w")
    f.writeLine("return {")
    f.writeLine("  profile = \"RECEIVER\",")
    f.writeLine("  modemSide = \"" .. newConfig.modemSide .. "\",")
    f.writeLine("  doorSide = \"" .. newConfig.doorSide .. "\",")
    if config.controllerId then 
        f.writeLine("  controllerId = " .. config.controllerId) 
    else 
        f.writeLine("  controllerId = nil") 
    end
    f.writeLine("}")
    f.close()
end

drawHeader("Deployment Complete")
term.setBackgroundColor(colors.black) term.clear()
drawPanel = nil

if (config.profile or "CONTROLLER") == "CONTROLLER" then
    shell.run("door/controller.lua")
else
    shell.run("door/receiver.lua")
end