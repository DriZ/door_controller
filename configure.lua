-- ============================================================
-- DOOR SYSTEM - HARDWARE CONFIGURATOR WIZARD (v2.7)
-- ============================================================

local term = _G.term
local colors = _G.colors

local config = {}
if fs.exists("door/config.lua") then
    local ok, res = pcall(dofile, "door/config.lua")
    if ok and type(res) == "table" then config = res end
end

local function drawUI(title)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.cyan)
    term.clear()
    term.setCursorPos(1, 1)
    print("===============================================")
    print("     DOOR SYSTEM - CONFIGURATION WIZARD        ")
    print("===============================================")
    if title then print(" STEP: " .. title) print("--------------------------------------------------") end
end

drawUI("NODE PROFILE IDENTIFICATION")
local profile = config.profile
if not profile then
    print("Select physical profile for this node:")
    print("1. CONTROLLER (Main Panel & Displays)")
    print("2. RECEIVER (Redstone Output Actuator)")
    write("\nChoose option (1-2): ")
    local pChoice = read()
    profile = (pChoice == "2") and "RECEIVER" or "CONTROLLER"
else
    print("Detected active profile alignment: " .. profile)
    sleep(1)
end

local newConfig = {
    profile = profile,
    targetId = config.targetId
}

if profile == "CONTROLLER" then
    drawUI("SECTOR DOMAIN ASSIGNMENT")
    write("Enter custom sector/room name (e.g. Gate Sector A):\n> ")
    local name = read()
    newConfig.roomName = (name ~= "") and name or (config.roomName or "Gate Sector A")

    drawUI("NETWORK UPLINK BUS")
    write("Enter modem peripheral side (top/bottom/left/right/back):\n> ")
    local side = read()
    newConfig.modemSide = (side ~= "") and side:lower() or (config.modemSide or "top")

    drawUI("ACTUATOR DRIVE MODE")
    print("Choose how the door should operate:")
    print("1. [LEVER MODE]  - Toggle switch. Stays open until closed manually.")
    print("2. [TIMED PULSE] - Automatically closes after a set delay.")
    write("\nSelect operation mode (1-2): ")
    local modeChoice = read()

    if modeChoice == "1" then
        newConfig.openDelay = 0
        print("\n[+] Configured as Permanent Toggle Lever.")
    else
        write("\nEnter door open duration in seconds (e.g. 4):\n> ")
        local delayInput = read()
        local delayNum = tonumber(delayInput)
        -- Защита: если ввели не число или меньше 1, ставим дефолт 4
        if not delayNum or delayNum < 1 then delayNum = 4 end
        newConfig.openDelay = delayNum
        print("\n[+] Pulse timer locked at: " .. delayNum .. " seconds.")
    end
    sleep(1.5)

    drawUI("SECURITY ENCRYPTION LAYER")
    write("Enable cryptographic key protection? (y/n):\n> ")
    local usePass = read():lower()
    if usePass == "y" or usePass == "yes" then
        newConfig.usePassword = true
        write("Set master access password:\n> ")
        local pass = read()
        newConfig.correctPassword = (pass ~= "") and pass or (config.correctPassword or "1234")
    else
        newConfig.usePassword = false
        newConfig.correctPassword = config.correctPassword or "1234"
    end

    local f = fs.open("door/config.lua", "w")
    f.writeLine("return {")
    f.writeLine("  profile = \"" .. newConfig.profile .. "\",")
    f.writeLine("  roomName = \"" .. newConfig.roomName .. "\",")
    f.writeLine("  modemSide = \"" .. newConfig.modemSide .. "\",")
    f.writeLine("  usePassword = " .. tostring(newConfig.usePassword) .. ",")
    f.writeLine("  correctPassword = \"" .. newConfig.correctPassword .. "\",")
    f.writeLine("  openDelay = " .. newConfig.openDelay .. ",")
    if newConfig.targetId then
        f.writeLine("  targetId = " .. newConfig.targetId)
    else
        f.writeLine("  targetId = nil")
    end
    f.writeLine("}")
    f.close()

else
    drawUI("RECEIVER HARDWARE MAPPING")
    write("Enter modem peripheral side (top/bottom/left/right/back):\n> ")
    local mSide = read()
    newConfig.modemSide = (mSide ~= "") and mSide:lower() or (config.modemSide or "left")

    write("Enter redstone output side connected to the door:\n> ")
    local dSide = read()
    newConfig.doorSide = (dSide ~= "") and dSide:lower() or (config.doorSide or "bottom")

    -- Запись конфигурации ресивера
    local f = fs.open("door/config.lua", "w")
    f.writeLine("return {")
    f.writeLine("  profile = \"" .. newConfig.profile .. "\",")
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

drawUI("CONFIGURATION LOCKED")
term.setTextColor(colors.green)
print("[+] Hardware matrix initialized successfully.")
print("[+] System registry update deployed to /door/config.lua")
print("--------------------------------------------------")
write("Press Enter to boot main environment...")
read()

if profile == "CONTROLLER" then
    shell.run("door/controller.lua")
else
    shell.run("door/receiver.lua")
end