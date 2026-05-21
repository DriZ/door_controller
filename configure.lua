-- ===================================
-- DOOR SYSTEM - HARDWARE CONFIGURATOR
-- ===================================

local term = _G.term
local colors = _G.colors
local keys = _G.keys

if not fs.exists("door/config.lua") then
    term.setTextColor(colors.red)
    print("Configurator Error: Missing profile token!")
    return
end
local config = dofile("door/config.lua")

local function getPeripheralSides(pType)
    local results = {}
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == pType then table.insert(results, side) end
    end
    return results
end

-- Автоопределение сетевого и беспроводного оборудования
local modems = getPeripheralSides("modem")
if #modems > 0 then config.modemSide = modems[1] else config.modemSide = "left" end

local monitors = getPeripheralSides("monitor")
local selectedMonitors = {}
local cursorIdx = 1

local function drawHeader(title)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(2, 2)
    term.write("SCADA DESIGNER // " .. config.profile .. " SETUP")
    term.setBackgroundColor(colors.black)
end

local function saveFullConfig()
    local f = fs.open("door/config.lua", "w")
    f.write("return {\n")
    f.write("  profile = \"" .. config.profile .. "\",\n")
    f.write("  modemSide = \"" .. config.modemSide .. "\",\n")
    f.write("  doorSide = \"" .. (config.doorSide or "bottom") .. "\",\n")
    f.write("  roomName = \"" .. (config.roomName or "SECURE BLOCK") .. "\",\n")
    f.write("  usePassword = " .. tostring(config.usePassword or false) .. ",\n")
    f.write("  correctPassword = \"" .. (config.correctPassword or "") .. "\",\n")
    f.write("  monitors = {\n")
    for m, _ in pairs(selectedMonitors) do f.write("    [\"" .. m .. "\"] = true,\n") end
    f.write("  }\n}")
    f.close()
end

-- ФУНКЦИОНАЛ НАСТРОЙКИ РЕСИВЕРА
local function configureReceiver()
    local sides = {"top","bottom","left","right","front","back"}
    while true do
        drawHeader("RELAY INTERFACE")
        term.setTextColor(colors.white)
        term.setCursorPos(3, 5) term.write("Detected Modem Bus: " .. config.modemSide)
        term.setCursorPos(3, 7) term.write("Select Redstone Output Node:")
        
        for i, s in ipairs(sides) do
            if i == cursorIdx then
                term.setTextColor(colors.lime)
                term.setCursorPos(5, 8 + i) term.write("=> [ " .. s:upper() .. " ]")
            else
                term.setTextColor(colors.gray)
                term.setCursorPos(5, 8 + i) term.write("   [ " .. s:upper() .. " ]")
            end
        end
        term.setTextColor(colors.cyan)
        term.setCursorPos(3, 16) term.write("[ENTER] Save Parameters & Open Uplink")
        
        local _, key = os.pullEvent("key")
        if key == keys.up then cursorIdx = math.max(1, cursorIdx - 1)
        elseif key == keys.down then cursorIdx = math.min(#sides, cursorIdx + 1)
        elseif key == keys.enter then
            config.doorSide = sides[cursorIdx]
            saveFullConfig()
            break
        end
    end
end

-- ФУНКЦИОНАЛ НАСТРОЙКИ КОНТРОЛЛЕРА
local function configureController()
    local step = 1
    while step <= 4 do
        drawHeader("NETWORK MATRIX INTERFACE")
        term.setTextColor(colors.white)
        
        if step == 1 then
            term.setCursorPos(3, 5) term.write("Enter Access Sector / Room Name:")
            term.setCursorPos(3, 7) term.setTextColor(colors.lime) term.write(">> ")
            config.roomName = read()
            step = 2
        elseif step == 2 then
            term.setCursorPos(3, 5) term.write("Select Display Outputs (Space to Check, Enter to Confirm):")
            if #monitors == 0 then
                term.setCursorPos(5, 7) term.setTextColor(colors.red) term.write("No external monitors found on the network.")
            end
            for i, m in ipairs(monitors) do
                local chk = selectedMonitors[m] and "[X]" or "[ ]"
                if i == cursorIdx then
                    term.setTextColor(colors.lime)
                    term.setCursorPos(5, 6 + i) term.write("=> " .. chk .. " Peripheral Matrix: " .. m)
                else
                    term.setTextColor(colors.gray)
                    term.setCursorPos(5, 6 + i) term.write("   " .. chk .. " Peripheral Matrix: " .. m)
                end
            end
            local _, key = os.pullEvent("key")
            if key == keys.up then cursorIdx = math.max(1, cursorIdx - 1)
            elseif key == keys.down then cursorIdx = math.min(#monitors, cursorIdx + 1)
            elseif key == keys.space and #monitors > 0 then
                selectedMonitors[monitors[cursorIdx]] = not selectedMonitors[monitors[cursorIdx]]
            elseif key == keys.enter then
                step = 3
                cursorIdx = 1
            end
        elseif step == 3 then
            term.setCursorPos(3, 5) term.write("Enforce Encryption Crypt-Key Password?")
            term.setCursorPos(5, 7) if cursorIdx == 1 then term.setTextColor(colors.lime) term.write("=> [ YES ]") else term.setTextColor(colors.gray) term.write("   [ YES ]") end
            term.setCursorPos(5, 8) if cursorIdx == 2 then term.setTextColor(colors.lime) term.write("=> [ NO ]") else term.setTextColor(colors.gray) term.write("   [ NO ]") end
            
            local _, key = os.pullEvent("key")
            if key == keys.up or key == keys.down then cursorIdx = cursorIdx == 1 and 2 or 1
            elseif key == keys.enter then
                config.usePassword = (cursorIdx == 1)
                if config.usePassword then step = 4 else step = 5 end
            end
        elseif step == 4 then
            term.setCursorPos(3, 5) term.write("Input Terminal Access Password:")
            term.setCursorPos(3, 7) term.setTextColor(colors.lime) term.write(">> ")
            config.correctPassword = read("*")
            step = 5
        end
    end
    saveFullConfig()
end

if config.profile == "CONTROLLER" then configureController() else configureReceiver() end

drawHeader("INITIALIZATION COMPLETION")
term.setTextColor(colors.lime)
term.setCursorPos(3, 6) term.write("[+] Local matrices compiled successfully.")
term.setCursorPos(3, 9) term.setBackgroundColor(colors.green) term.setTextColor(colors.black)
term.write("      [ ENTER ] BOOT MAIN SCADA LIFECYCLE       ")
term.setBackgroundColor(colors.black)

while true do
    local _, key = os.pullEvent("key")
    if key == keys.enter then
        term.clear() term.setCursorPos(1,1)
        if config.profile == "CONTROLLER" then shell.run("door/controller.lua") else shell.run("door/receiver.lua") end
        break
    end
end