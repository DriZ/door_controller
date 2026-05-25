local VERSION = "3.3.3"
-- ==========================================
-- MATRIX MONITOR V3.3.3 [GKOS UNIFIED]
-- ==========================================

if term.setPaletteColor then 
    term.setPaletteColor(colors.black, 0x333333)
    term.setPaletteColor(colors.white, 0xBFBFBF)
end

if periphemu then
    if peripheral.getType("top") == "monitor" then
        periphemu.remove("top")
    end
    
    local success = periphemu.create("top", "monitor", 23, 17)
    
    if success then
        print("virtual monitor 3x3 (23x17) created successfully on top side.")
    else
        print("Failed to create virtual monitor.")
    end
else
    print("API periphemu not found. Is code running not on CraftOS-PC?")
end

if peripheral.getType("top") == "monitor" then
    local monitor = peripheral.wrap("top")
    monitor.setTextScale(1) 
    if monitor and monitor.setPaletteColor then 
        monitor.setPaletteColor(colors.black, 0x333333)
        monitor.setPaletteColor(colors.white, 0xBFBFBF)
    end
    monitor.clear()
end

-- Basalt is now managed by the GKOS installer and is expected to be in /basalt.lua
if not package.path:find(";/%?.lua") then package.path = package.path .. ";/?.lua" end
local basalt = require("basalt")

local CONFIG_FILE = "config.lua"
local config = {}
local activeMonitors = {}
local currentEditingMonitor = nil

local screenW, screenH = term.getSize()

local theme = {
    title = colors.yellow,
    bg = colors.gray,
    cardBg = colors.black,
    cardBorder = colors.lightGray,
    btnBg = colors.lightGray,
    btnText = colors.black,
    btnDelBg = colors.red,
    btnDelText = colors.white,
    gridColor = colors.gray,
    monOffline = colors.red,
    monOnlineNew = colors.lime,
    monOnlineConfigured = colors.lightBlue
}

local colorPaletteGrid = {
    {colors.white, colors.orange, colors.magenta, colors.lightBlue},
    {colors.yellow, colors.lime, colors.pink, colors.gray},
    {colors.lightGray, colors.cyan, colors.purple, colors.blue},
    {colors.brown, colors.green, colors.red, colors.black}
}

local function getContrastColor(colorVal)
    if colorVal == colors.white or colorVal == colors.yellow or colorVal == colors.lime or colorVal == colors.lightGray or colorVal == colors.pink then
        return colors.black
    end
    return colors.white
end

local scrollOffset = 0
local maxRowsPerPage = math.floor((screenH - 3) / 3)

local function loadConfig()
    if fs.exists(CONFIG_FILE) then
        local file = fs.open(CONFIG_FILE, "r")
        local data = textutils.unserialize(file.readAll())
        file.close()
        if data then config = data end
    end
end

local function saveConfig()
    local file = fs.open(CONFIG_FILE, "w")
    file.write(textutils.serialize(config))
    file.close()
end

local function getMonitorBlockSize(monName)
    local mon = peripheral.wrap(monName)
    if not mon then return "N/A" end
    
    if mon.setPaletteColor then
        mon.setPaletteColor(colors.black, 0x333333)
        mon.setPaletteColor(colors.white, 0xBFBFBF)
    end

    local w, h = mon.getSize()
    local scale = mon.getTextScale()
    
    -- width 7->1, 18->2, 29->3, 39->4
    -- height 5->1, 12->2, 19->3, 26->4
    local blocksX = math.floor((w * scale + 4) / 10.5)
    local blocksY = math.floor((h * scale + 2) / 7)
    
    return blocksX .. "x" .. blocksY
end

local function renderMonitor(monName, cfgOverride)
    local mon = peripheral.wrap(monName)
    if not mon then return end

    if mon.setPaletteColor then 
        mon.setPaletteColor(colors.black, 0x333333)
        mon.setPaletteColor(colors.white, 0xBFBFBF)
    end

    local cfg = cfgOverride or config[monName]
    if not cfg then
        mon.setBackgroundColor(colors.black)
        mon.clear()
        return
    end

    local cols = cfg.columns or 1
    local rows = cfg.rows or 1
    -- Removed global centering
    local isGridX = (cfg.showGridX == true)
    local isGridY = (cfg.showGridY == true)

    local bestScale = 0.5
    for s = 5, 0.5, -0.5 do
        mon.setTextScale(s)
        local w, h = mon.getSize()
        
        local usableW = w - (isGridX and (cols - 1) or 0)
        local usableH = h - (isGridY and (rows - 1) or 0)
        local colW = math.floor(usableW / cols)
        local rowH = math.floor(usableH / rows)
        
        if colW >= 1 and rowH >= 1 then
            local allFit = true
            for i = 1, rows * cols do
                local part = cfg.parts[i]
                if part and part.text and part.text ~= "" then
                    local linesNeeded = math.ceil(#part.text / colW)
                    if linesNeeded > rowH then allFit = false break end
                end
            end
            if allFit then
                bestScale = s
                break
            end
        end
    end

    mon.setTextScale(bestScale)
    mon.setBackgroundColor(colors.black)
    mon.clear()

    local w, h = mon.getSize()
    
    local usableW = w - (isGridX and (cols - 1) or 0)
    local usableH = h - (isGridY and (rows - 1) or 0)

    for r = 1, rows do
        for c = 1, cols do
            local idx = (r - 1) * cols + c
            local part = cfg.parts[idx] or {}
            part.text = part.text or ""
            part.fg = part.fg or colors.white
            part.bg = part.bg or colors.black
            
            mon.setBackgroundColor(part.bg)
            mon.setTextColor(part.fg)
            
            local startX = math.floor((c - 1) * usableW / cols) + 1 + (isGridX and (c - 1) or 0)
            local endX = math.floor(c * usableW / cols) + (isGridX and (c - 1) or 0)
            local drawW = endX - startX + 1

            local startY = math.floor((r - 1) * usableH / rows) + 1 + (isGridY and (r - 1) or 0)
            local endY = math.floor(r * usableH / rows) + (isGridY and (r - 1) or 0)
            local drawH = endY - startY + 1

            for y = startY, endY do
                mon.setCursorPos(startX, y)
                mon.write(string.rep(" ", drawW))
            end

            local text = part.text or ""
            if text ~= "" then
                local lines = {}
                for i = 1, #text, drawW do
                    table.insert(lines, text:sub(i, i + drawW - 1))
                end
                
                local totalLines = #lines
                local startLineY = startY + math.floor((drawH - totalLines) / 2)
                
                local alignment = part.alignment or "left" -- Default to left
                for lineIdx, lineText in ipairs(lines) do
                    local currentY = startLineY + lineIdx - 1
                    if currentY >= startY and currentY <= endY then
                        local textX = startX
                        if alignment == "center" then
                            textX = startX + math.floor((drawW - #lineText) / 2)
                        elseif alignment == "right" then
                            textX = startX + drawW - #lineText
                        end
                        mon.setCursorPos(math.max(1, textX), currentY)
                        mon.write(lineText)
                    end
                end
            end
        end
    end

    -- DRAW THIN GRID LINES
    mon.setTextColor(theme.gridColor)
    mon.setBackgroundColor(colors.black)
    
    local xGaps = {}
    if isGridX and cols > 1 then
        for c = 1, cols - 1 do
            local gapX = math.floor(c * usableW / cols) + c
            xGaps[gapX] = true
            for y = 1, h do
                mon.setCursorPos(gapX, y)
                mon.write("\149") -- Vertical thin line
            end
        end
    end

    if isGridY and rows > 1 then
        for r = 1, rows - 1 do
            local gapY = math.floor(r * usableH / rows) + r
            mon.setCursorPos(1, gapY)
            for x = 1, w do
                if xGaps[x] then
                    mon.write("\151") -- Intersection (Top + Left)
                else
                    mon.write("\131") -- Horizontal thin line
                end
            end
        end
    end
end

local function identifyMonitor(monName)
    local mon = peripheral.wrap(monName)
    if not mon then return end
    local oldData = config[monName]

    basalt.schedule(function()
        for i = 1, 10 do
            mon.setBackgroundColor(colors.white)
            mon.clear()
            os.sleep(0.2)
            mon.setBackgroundColor(colors.black)
            mon.clear()
            os.sleep(0.2)
        end
        if oldData then renderMonitor(monName) end
    end)
end

local function refreshAllMonitors()
    activeMonitors = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "monitor" then
            activeMonitors[name] = true
            if config[name] then renderMonitor(name) end
        end
    end
end


local main = basalt.getMainFrame()
main:setBackground(theme.bg)

local menuFrame = main:addFrame({x = 1, y = 1, width = screenW, height = screenH, background = theme.bg})
local editFrame = main:addFrame({x = 1, y = 1, width = screenW, height = screenH, background = theme.bg})
editFrame:setVisible(false)

local title = "GATEKEEPER OS - MONITOR MATRIX"
menuFrame:addLabel({x = math.floor((screenW - #title) / 2) + 1, y = 1})
    :setText(title)
    :setForeground(theme.title)

local versionLabel = menuFrame:addLabel({x = screenW - #VERSION, y = 1})
    :setText("V" .. VERSION)
    :setForeground(colors.lightGray)

local function checkForUpdates()
    if not http then return end
    basalt.schedule(function()
        -- Запрашиваем актуальный gui.lua напрямую
        local res = http.get("https://raw.githubusercontent.com/DriZ/GateKeeperOS/main/matrix.lua")
        if res then
            local content = res.readAll()
            res.close()
            local remoteVer = content:match('local VERSION%s*=%s*"([^"]+)"')
            if remoteVer and remoteVer ~= VERSION then
                versionLabel:setForeground(colors.yellow)
            end
        end
    end)
end

local listContainer
local scrollBarMain

local buildMainMenu, buildEditMenu

-- ==========================================
-- MAIN MENU
-- ==========================================
buildMainMenu = function()
    if listContainer then menuFrame:removeChild(listContainer) end
    if scrollBarMain then menuFrame:removeChild(scrollBarMain) end
    local listWidth = screenW - 2
    listContainer = menuFrame:addFrame({x = 2, y = 3, width = listWidth, height = screenH - 2, background = theme.bg})
    
    local allMons = {}
    for k in pairs(config) do table.insert(allMons, {name=k, cfg=true}) end
    for k in pairs(activeMonitors) do 
        local found = false
        for _, m in ipairs(allMons) do if m.name == k then found = true break end end
        if not found then table.insert(allMons, {name=k, cfg=false}) end
    end
    table.sort(allMons, function(a, b) return a.name < b.name end)

    listContainer:onScroll(function(self, dir)
        if dir > 0 then
            if scrollOffset < (#allMons - maxRowsPerPage) then
                scrollOffset = scrollOffset + 1
                buildMainMenu()
            end
        elseif dir < 0 then
            if scrollOffset > 0 then
                scrollOffset = scrollOffset - 1
                buildMainMenu()
            end
        end
    end)

    if scrollOffset > (#allMons - maxRowsPerPage) then
        scrollOffset = math.max(0, #allMons - maxRowsPerPage)
    end

    -- Отрисовка полоски скролла
    if #allMons > maxRowsPerPage then
        local trackHeight = listContainer:getHeight()
        scrollBarMain = menuFrame:addFrame({x = screenW, y = 3, width = 1, height = trackHeight, background = colors.black})
        
        local thumbHeight = math.max(1, math.floor((maxRowsPerPage / #allMons) * trackHeight))
        local maxScroll = #allMons - maxRowsPerPage
        local thumbY = math.floor((scrollOffset / maxScroll) * (trackHeight - thumbHeight))
        
        scrollBarMain:addFrame({
            x = 1, y = thumbY + 1,
            width = 1, height = thumbHeight,
            background = colors.lightGray
        })
    end

    local yPos = 1
    local shownCount = 0

    for i = scrollOffset + 1, #allMons do
        if shownCount >= maxRowsPerPage then break end
        shownCount = shownCount + 1
        local item = allMons[i]
        local monName = item.name
        local isOnline = activeMonitors[monName] ~= nil
        local isConfigured = config[monName] ~= nil

        local monColor = theme.monOffline
        local statusText = "[OFFLINE]"
        if isOnline and isConfigured then 
            monColor = theme.monOnlineConfigured
            statusText = "[ READY ]"
        elseif isOnline and not isConfigured then 
            monColor = theme.monOnlineNew
            statusText = "[  NEW  ]"
        end

        local row = listContainer:addFrame({
            x = 1,
            y = yPos,
            width = listContainer:getWidth(),
            height = 2,
            background = theme.cardBg
        })
        
        row:addLabel({x = 2, y = 1}):setText(monName):setForeground(colors.lightGray)
        row:addLabel({x = 2, y = 2}):setText(statusText):setForeground(monColor)
        
        local sizeText = isOnline and getMonitorBlockSize(monName) or "---"
        row:addLabel({x = 20, y = 1}):setText("Size:"):setForeground(colors.lightGray)
        row:addLabel({x = 20, y = 2}):setText(sizeText):setForeground(colors.white)

        row:addButton({x = listWidth - 15, y = 1, width = 6, height = 1})
            :setText("ID")
            :setBackground(colors.blue)
            :setForeground(colors.white)
            :onClick(function() identifyMonitor(monName) end)

        local btnEdit = row:addButton({x = listWidth - 8, y = 1, width = 7, height = 1})
            :setText("EDIT")
            :setBackground(theme.btnBg)
            :setForeground(theme.btnText)
        
        local btnDel = row:addButton({x = listWidth - 8, y = 2, width = 7, height = 1})
            :setText("DEL ")
        
        if isConfigured then
            btnDel:setBackground(theme.btnDelBg):setForeground(theme.btnDelText)
            btnDel:onClick(function(self)
                if self:getText() == "DEL " then
                    self:setText("SURE?")
                    basalt.schedule(function() os.sleep(2) if self.setText then self:setText("DEL ") end end)
                else
                    config[monName] = nil
                    saveConfig()
                    local mon = peripheral.wrap(monName)
                    if mon then mon.setBackgroundColor(colors.black) mon.clear() end
                    buildMainMenu()
                end
            end)
        else
            btnDel:setBackground(colors.gray):setForeground(colors.lightGray)
        end

        btnEdit:onClick(function()
            currentEditingMonitor = monName
            buildEditMenu(monName)
            menuFrame:setVisible(false)
            editFrame:setVisible(true)
        end)

        yPos = yPos + 3
    end
end

-- ==========================================
-- EDIT MENU
-- ==========================================
buildEditMenu = function(monName)
    local children = editFrame:getChildren()
    if children then
        for _, child in pairs(children) do
            editFrame:removeChild(child)
        end
    end
    
    local bX, bY = 1, 1
    local mon = peripheral.wrap(monName)
    if mon then
        local w, h = mon.getSize()
        local scale = mon.getTextScale()

        bX = math.floor((w * scale + 4) / 10.5)
        bY = math.floor((h * scale + 2) / 7)
    end
    local maxColsLimit = math.max(1, bX)
    local maxRowsLimit = math.max(1, bY * 3)

    local cfg = config[monName] or {columns = 1, rows = 1, centered = false, showGridX = false, showGridY = false, parts = {}}
    
    local currentCfg = {
        columns = math.min(cfg.columns or 1, maxColsLimit),
        rows = math.min(cfg.rows or 1, maxRowsLimit),
        showGridX = (cfg.showGridX == true),
        showGridY = (cfg.showGridY == true),
        parts = {}
    }
    
    local function applyPreview()
        if activeMonitors[monName] then
            renderMonitor(monName, currentCfg)
        end
    end

    for i = 1, (maxColsLimit * maxRowsLimit) do
        local sourcePart = (cfg.parts and cfg.parts[i]) or {text = "", fg = colors.white, bg = colors.black, alignment = "left"}
        currentCfg.parts[i] = {text = sourcePart.text, fg = sourcePart.fg, bg = sourcePart.bg, alignment = sourcePart.alignment or "left"}
    end

    local editScrollOffset = 0
    local maxCellsPerPage = math.floor((screenH - 10) / 8)
    if maxCellsPerPage < 1 then maxCellsPerPage = 1 end

    local drawPartsInputs

    editFrame:addLabel({x = 3, y = 1}):setText("CONFIG: " .. monName):setForeground(colors.yellow)
    
    editFrame:addButton({x = 2, y = screenH, width = 10, height = 1})
        :setText("[ CANCEL ]")
        :setBackground(colors.red)
        :setForeground(theme.btnText)
        :onClick(function()
            currentEditingMonitor = nil
            editFrame:setVisible(false)
            menuFrame:setVisible(true)
            if activeMonitors[monName] then renderMonitor(monName) end
            buildMainMenu()
        end)

    local settingsPanel = editFrame:addFrame({x = 2, y = 3, width = screenW - 2, height = 5, background = colors.black}) -- Height adjusted to 5

    settingsPanel:addLabel({x = 2, y = 2}):setText("Grid X:"):setForeground(colors.white) -- Shifted up
    local btnGridX = settingsPanel:addButton({x = 10, y = 2, width = 3, height = 1}) -- Shifted up
    local function updateGridXUI()
        local isAvailable = currentCfg.columns > 1
        btnGridX:setText(currentCfg.showGridX and "[X]" or "[ ]")
        if isAvailable then
            btnGridX:setBackground(currentCfg.showGridX and colors.lime or colors.gray)
            btnGridX:setForeground(currentCfg.showGridX and colors.black or colors.white)
        else
            btnGridX:setBackground(colors.black)
            btnGridX:setForeground(colors.gray)
        end
    end
    updateGridXUI()
    btnGridX:onClick(function()
        if currentCfg.columns > 1 then
            currentCfg.showGridX = not currentCfg.showGridX
            updateGridXUI()
            applyPreview()
        end
    end)

    settingsPanel:addLabel({x = 14, y = 2}):setText("Grid Y:"):setForeground(colors.white) -- Shifted up
    local btnGridY = settingsPanel:addButton({x = 22, y = 2, width = 3, height = 1}) -- Shifted up
    local function updateGridYUI()
        local isAvailable = currentCfg.rows > 1
        btnGridY:setText(currentCfg.showGridY and "[X]" or "[ ]")
        if isAvailable then
            btnGridY:setBackground(currentCfg.showGridY and colors.lime or colors.gray)
            btnGridY:setForeground(currentCfg.showGridY and colors.black or colors.white)
        else
            btnGridY:setBackground(colors.black)
            btnGridY:setForeground(colors.gray)
        end
    end
    updateGridYUI()
    btnGridY:onClick(function()
        if currentCfg.rows > 1 then
            currentCfg.showGridY = not currentCfg.showGridY
            updateGridYUI()
            applyPreview()
        end
    end)

    settingsPanel:addLabel({x = 2, y = 4}):setText("Col:"):setForeground(colors.white) -- Shifted down
    local btnColDec = settingsPanel:addButton({x = 6, y = 4, width = 1, height = 1}) -- Shifted down
        :setText("-"):setBackground(colors.lightGray):setForeground(colors.black)
    local lblColVal = settingsPanel:addLabel({x = 8, y = 4, width = 2, height = 1}) -- Shifted down
        :setText(tostring(currentCfg.columns)):setForeground(colors.white)
    local btnColInc = settingsPanel:addButton({x = 10, y = 4, width = 1, height = 1}) -- Shifted down
        :setText("+"):setBackground(colors.lightGray):setForeground(colors.black)

    settingsPanel:addLabel({x = 13, y = 4}):setText("Row:"):setForeground(colors.white) -- Shifted down
    local btnRowDec = settingsPanel:addButton({x = 17, y = 4, width = 1, height = 1}) -- Shifted down
        :setText("-"):setBackground(colors.lightGray):setForeground(colors.black)
    local lblRowVal = settingsPanel:addLabel({x = 19, y = 4, width = 2, height = 1}) -- Shifted down
        :setText(tostring(currentCfg.rows)):setForeground(colors.white)
    local btnRowInc = settingsPanel:addButton({x = 21, y = 4, width = 1, height = 1}) -- Shifted down
        :setText("+"):setBackground(colors.lightGray):setForeground(colors.black)

    local function updateGridSettings()
        lblColVal:setText(tostring(currentCfg.columns))
        lblRowVal:setText(tostring(currentCfg.rows))
        updateGridXUI()
        updateGridYUI()
        editScrollOffset = 0
        drawPartsInputs()
        applyPreview()
    end

    btnColDec:onClick(function() 
        if currentCfg.columns > 1 then 
            currentCfg.columns = currentCfg.columns - 1 
            if currentCfg.columns == 1 then currentCfg.showGridX = false end
            updateGridSettings() 
        end 
    end)
    btnColInc:onClick(function() if currentCfg.columns < maxColsLimit then currentCfg.columns = currentCfg.columns + 1 updateGridSettings() end end)
    btnRowDec:onClick(function() 
        if currentCfg.rows > 1 then 
            currentCfg.rows = currentCfg.rows - 1 
            if currentCfg.rows == 1 then currentCfg.showGridY = false end
            updateGridSettings() 
        end 
    end)
    btnRowInc:onClick(function() if currentCfg.rows < maxRowsLimit then currentCfg.rows = currentCfg.rows + 1 updateGridSettings() end end)
    
    local partsContainer
    local scrollBarEdit

    drawPartsInputs = function()
        if partsContainer then editFrame:removeChild(partsContainer) end -- Remove existing partsContainer
        if scrollBarEdit then editFrame:removeChild(scrollBarEdit) end
        local pWidth = screenW - 1
        partsContainer = editFrame:addFrame({x = 2, y = 9, width = pWidth, height = screenH - 9, background = theme.bg})
        
        partsContainer:onScroll(function(self, dir)
            local totalParts = currentCfg.columns * currentCfg.rows
            if dir > 0 then 
                if editScrollOffset < (totalParts - maxCellsPerPage) then
                    editScrollOffset = editScrollOffset + 1
                    drawPartsInputs()
                end
            elseif dir < 0 then
                if editScrollOffset > 0 then
                    editScrollOffset = editScrollOffset - 1
                    drawPartsInputs()
                end
            end
        end)

        local cols = currentCfg.columns
        local rows = currentCfg.rows
        local totalParts = cols * rows

        -- Отрисовка полоски скролла для редактора
        if totalParts > maxCellsPerPage then
            local trackHeight = partsContainer:getHeight()
            scrollBarEdit = editFrame:addFrame({x = screenW, y = 9, width = 1, height = trackHeight, background = colors.black})
            
            local thumbHeight = math.max(1, math.floor((maxCellsPerPage / totalParts) * trackHeight))
            local maxScroll = totalParts - maxCellsPerPage
            local thumbY = math.floor((editScrollOffset / maxScroll) * (trackHeight - thumbHeight))
            
            scrollBarEdit:addFrame({
                x = 1, y = thumbY + 1,
                width = 1, height = thumbHeight,
                background = colors.lightGray
            })
        end

        local pY = 1
        local itemsRendered = 0

        -- Перед перерисовкой, явно снимаем фокус с любого элемента,
        -- чтобы избежать "фантомного" ввода в старые поля.
        local currentlyFocused = basalt.getFocused and basalt.getFocused()
        if currentlyFocused and currentlyFocused.blur then
            currentlyFocused:blur()
        end

        for i = editScrollOffset + 1, totalParts do
            if itemsRendered >= maxCellsPerPage then break end
            itemsRendered = itemsRendered + 1

            local part = currentCfg.parts[i]
            local cellR = math.ceil(i / cols)
            local cellC = (i - 1) % cols + 1

            local colCard = partsContainer:addFrame({
                x = 1,
                y = pY,
                width = pWidth - 1,
                height = 8,
                background = colors.black
            })

            colCard:addLabel({x = 2, y = 2}):setText("R" .. cellR .. "C" .. cellC .. " Text:"):setForeground(colors.white)
            
            local txtInput = colCard:addInput({
                x = 12, 
                y = 2, 
                width = pWidth - 14,
                height = 1,
                background = colors.lightGray,
                foreground = colors.black,
                placeholder = "Enter text..."
            }):setText(part.text or "")

            -- Alignment radio buttons
            colCard:addLabel({x = 2, y = 4}):setText("Align:"):setForeground(colors.white)
            local btnAlignLeft = colCard:addButton({x = 8, y = 4, width = 3, height = 1}):setText("L")
            local btnAlignCenter = colCard:addButton({x = 12, y = 4, width = 3, height = 1}):setText("C")
            local btnAlignRight = colCard:addButton({x = 16, y = 4, width = 3, height = 1}):setText("R")

            local function updateAlignmentButtons()
                btnAlignLeft:setBackground(part.alignment == "left" and colors.lime or colors.gray)
                btnAlignLeft:setForeground(part.alignment == "left" and colors.black or colors.white)
                btnAlignCenter:setBackground(part.alignment == "center" and colors.lime or colors.gray)
                btnAlignCenter:setForeground(part.alignment == "center" and colors.black or colors.white)
                btnAlignRight:setBackground(part.alignment == "right" and colors.lime or colors.gray)
                btnAlignRight:setForeground(part.alignment == "right" and colors.black or colors.white)
            end
            updateAlignmentButtons()

            btnAlignLeft:onClick(function()
                part.alignment = "left"
                updateAlignmentButtons()
                applyPreview()
            end)
            btnAlignCenter:onClick(function()
                part.alignment = "center"
                updateAlignmentButtons()
                applyPreview()
            end)
            btnAlignRight:onClick(function()
                part.alignment = "right"
                updateAlignmentButtons()
                applyPreview()
            end)

            txtInput:onChange("text", function(self, text)
                part.text = text
                applyPreview()
            end)
            
            colCard:addLabel({x = 2, y = 6}):setText("FG:"):setForeground(colors.white) -- Shifted down by 2
            local fgContainer = colCard:addFrame({x = 6, y = 6, width = 8, height = 2, background = colors.black}) -- Shifted down by 2
            
            colCard:addLabel({x = 16, y = 6}):setText("BG:"):setForeground(colors.white) -- Shifted down by 2
            local bgContainer = colCard:addFrame({x = 20, y = 6, width = 8, height = 2, background = colors.black}) -- Shifted down by 2

            local function buildGrid(container, isFg)
                local children = container:getChildren()
                if children then
                    for _, child in pairs(children) do
                        container:removeChild(child)
                    end
                end
                local flatColors = {}
                for _, rowColors in ipairs(colorPaletteGrid) do
                    for _, c in ipairs(rowColors) do table.insert(flatColors, c) end
                end

                for idx, colorVal in ipairs(flatColors) do
                    local r = math.ceil(idx / 8)
                    local c = (idx - 1) % 8 + 1
                    local activeColor = isFg and part.fg or part.bg
                    local isSelected = (activeColor == colorVal)
                    local symbol = isSelected and "X" or " "
                    
                    container:addButton({x = c, y = r, width = 1, height = 1})
                        :setText(symbol)
                        :setBackground(colorVal)
                        :setForeground(getContrastColor(colorVal))
                        :onClick(function()
                            if isFg then part.fg = colorVal else part.bg = colorVal end
                            buildGrid(fgContainer, true)
                            buildGrid(bgContainer, false)
                            applyPreview()
                        end)
                end
            end

            buildGrid(fgContainer, true)
            buildGrid(bgContainer, false)

            pY = pY + 8 -- Increased card height
        end
    end

    drawPartsInputs()

    editFrame:addButton({x = 13, y = screenH, width = 15, height = 1}):setText("[ SAVE CONFIG ]")
        :setBackground(colors.green)
        :setForeground(theme.btnText)
        :onClick(function()
            config[monName] = {
                columns = currentCfg.columns,
                rows = currentCfg.rows,
                showGridX = currentCfg.showGridX,
                showGridY = currentCfg.showGridY,
                parts = {}
            }
            
            local totalParts = currentCfg.columns * currentCfg.rows
            for i = 1, totalParts do
                config[monName].parts[i] = {
                    text = currentCfg.parts[i].text,
                    fg = currentCfg.parts[i].fg,
                    bg = currentCfg.parts[i].bg,
                    alignment = currentCfg.parts[i].alignment
                }
            end
            
            saveConfig()
            currentEditingMonitor = nil
            if activeMonitors[monName] then renderMonitor(monName) end
            
            editFrame:setVisible(false)
            menuFrame:setVisible(true)
            buildMainMenu()
        end)
end


local isHandlingPeripheralUpdate = false
local function handlePeripheralUpdate()
    if not menuFrame or not editFrame or isHandlingPeripheralUpdate then return end
    isHandlingPeripheralUpdate = true
    
    refreshAllMonitors()

    local isEditing = false
    if editFrame and editFrame.getVisible then
        isEditing = editFrame:getVisible()
    elseif editFrame and editFrame.isVisible then
        isEditing = editFrame:isVisible()
    end

    if not isEditing then
        buildMainMenu()
    elseif currentEditingMonitor and not activeMonitors[currentEditingMonitor] then
        currentEditingMonitor = nil
        editFrame:setVisible(false)
        menuFrame:setVisible(true)
        buildMainMenu()
    end
    isHandlingPeripheralUpdate = false
end

basalt.onEvent("peripheral", function()
    basalt.schedule(function() handlePeripheralUpdate() end)
end)

basalt.onEvent("peripheral_detach", function()
    basalt.schedule(function() handlePeripheralUpdate() end)
end)

loadConfig()
refreshAllMonitors()
buildMainMenu()
checkForUpdates()

basalt.run()