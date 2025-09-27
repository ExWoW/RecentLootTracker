-- Add to Blizzard Options -- RecentLootTracker: Shows recently acquired loot in a persistent window
-- Compatible with WoW 3.3.5a (WotLK)

local addonName = "RecentLootTracker"
local RLT = {}

-- Default Configuration
local DEFAULT_SETTINGS = {
    displayTime = 5,        -- seconds
    maxEntries = 10,        -- maximum loot entries to show
    windowWidth = 250,      -- window width
    windowHeight = 200,     -- window height
    positionX = 200,        -- window X position offset
    positionY = 100,        -- window Y position offset
    onlyCurrentSession = false,  -- only show loot from most recent kill
}

-- Current settings (will be loaded from saved variables)
local settings = {}

-- Constants
local ENTRY_HEIGHT = 20
local LOOT_SESSION_TIMEOUT = 3  -- seconds between loot to consider new session

-- Initialize settings with defaults
function RLT:InitializeSettings()
    -- Initialize saved variables if they don't exist
    if not RecentLootTrackerDB then
        RecentLootTrackerDB = {}
    end
    
    -- Copy defaults, but preserve any existing saved settings
    for key, value in pairs(DEFAULT_SETTINGS) do
        if RecentLootTrackerDB[key] == nil then
            RecentLootTrackerDB[key] = value
        end
    end
    
    settings = RecentLootTrackerDB
end

-- Save settings to saved variables
function RLT:SaveSettings()
    if RecentLootTrackerDB then
        for key, value in pairs(settings) do
            RecentLootTrackerDB[key] = value
        end
    end
end
-- Data storage
RLT.recentLoot = {}
RLT.displayTimer = nil
RLT.frame = nil
RLT.lastLootTime = 0  -- timestamp of last loot received
RLT.mouseOver = false  -- track if mouse is over the frame

-- Create settings panel
function RLT:CreateSettingsPanel()
    local panel = CreateFrame("Frame", "RecentLootTrackerOptionsPanel", UIParent)
    panel.name = "Recent Loot Tracker"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Recent Loot Tracker Settings")
    
    -- Display Time Slider
    local displayTimeSlider = CreateFrame("Slider", "RLTDisplayTimeSlider", panel, "OptionsSliderTemplate")
    displayTimeSlider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -40)
    displayTimeSlider:SetMinMaxValues(1, 15)
    displayTimeSlider:SetValueStep(1)
    displayTimeSlider:SetValue(settings.displayTime)
    displayTimeSlider:SetWidth(200)
    getglobal(displayTimeSlider:GetName() .. "Low"):SetText("1")
    getglobal(displayTimeSlider:GetName() .. "High"):SetText("15")
    getglobal(displayTimeSlider:GetName() .. "Text"):SetText("Display Time (seconds): " .. settings.displayTime)
    
    displayTimeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        settings.displayTime = value
        getglobal(self:GetName() .. "Text"):SetText("Display Time (seconds): " .. value)
        RLT:SaveSettings()
    end)
    
    -- Max Entries Slider
    local maxEntriesSlider = CreateFrame("Slider", "RLTMaxEntriesSlider", panel, "OptionsSliderTemplate")
    maxEntriesSlider:SetPoint("TOPLEFT", displayTimeSlider, "BOTTOMLEFT", 0, -40)
    maxEntriesSlider:SetMinMaxValues(5, 20)
    maxEntriesSlider:SetValueStep(1)
    maxEntriesSlider:SetValue(settings.maxEntries)
    maxEntriesSlider:SetWidth(200)
    getglobal(maxEntriesSlider:GetName() .. "Low"):SetText("5")
    getglobal(maxEntriesSlider:GetName() .. "High"):SetText("20")
    getglobal(maxEntriesSlider:GetName() .. "Text"):SetText("Max Entries: " .. settings.maxEntries)
    
    maxEntriesSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        settings.maxEntries = value
        getglobal(self:GetName() .. "Text"):SetText("Max Entries: " .. value)
        RLT:SaveSettings()
    end)
    
    -- Window Width Slider
    local widthSlider = CreateFrame("Slider", "RLTWidthSlider", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", maxEntriesSlider, "BOTTOMLEFT", 0, -40)
    widthSlider:SetMinMaxValues(200, 400)
    widthSlider:SetValueStep(10)
    widthSlider:SetValue(settings.windowWidth)
    widthSlider:SetWidth(200)
    getglobal(widthSlider:GetName() .. "Low"):SetText("200")
    getglobal(widthSlider:GetName() .. "High"):SetText("400")
    getglobal(widthSlider:GetName() .. "Text"):SetText("Window Width: " .. settings.windowWidth)
    
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        settings.windowWidth = value
        getglobal(self:GetName() .. "Text"):SetText("Window Width: " .. value)
        if RLT.frame then
            RLT.frame:SetWidth(value)
        end
        RLT:SaveSettings()
    end)
    
    -- Window Height Slider
    local heightSlider = CreateFrame("Slider", "RLTHeightSlider", panel, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -40)
    heightSlider:SetMinMaxValues(150, 350)
    heightSlider:SetValueStep(10)
    heightSlider:SetValue(settings.windowHeight)
    heightSlider:SetWidth(200)
    getglobal(heightSlider:GetName() .. "Low"):SetText("150")
    getglobal(heightSlider:GetName() .. "High"):SetText("350")
    getglobal(heightSlider:GetName() .. "Text"):SetText("Window Height: " .. settings.windowHeight)
    
    heightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        settings.windowHeight = value
        getglobal(self:GetName() .. "Text"):SetText("Window Height: " .. value)
        if RLT.frame then
            RLT.frame:SetHeight(value)
        end
        RLT:SaveSettings()
    end)
    
    -- Reset Position Button
    local resetButton = CreateFrame("Button", "RLTResetButton", panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", 0, -40)
    resetButton:SetWidth(150)
    resetButton:SetHeight(25)
    resetButton:SetText("Reset Window Position")
    resetButton:SetScript("OnClick", function()
        settings.positionX = DEFAULT_SETTINGS.positionX
        settings.positionY = DEFAULT_SETTINGS.positionY
        if RLT.frame then
            RLT.frame:ClearAllPoints()
            RLT.frame:SetPoint("CENTER", UIParent, "CENTER", settings.positionX, settings.positionY)
        end
        RLT:SaveSettings()
        print("Recent Loot Tracker: Window position reset to center")
    end)
    
    -- Only Current Session Checkbox
    local sessionCheckbox = CreateFrame("CheckButton", "RLTSessionCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    sessionCheckbox:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -20)
    getglobal(sessionCheckbox:GetName() .. "Text"):SetText("Only show loot from most recent kill")
    sessionCheckbox:SetChecked(settings.onlyCurrentSession)
    sessionCheckbox:SetScript("OnClick", function(self)
        settings.onlyCurrentSession = self:GetChecked()
        RLT:SaveSettings()
        print("Recent Loot Tracker: Only current session mode " .. (settings.onlyCurrentSession and "enabled" or "disabled"))
    end)
    
    -- Add tooltip to checkbox
    sessionCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Only show loot from most recent kill", 1, 1, 1, 1, true)
        GameTooltip:AddLine("When enabled: Only items from your most recent kill will be shown. New kills clear previous loot.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("When disabled: Shows the last " .. settings.maxEntries .. " items collected regardless of when/where.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    
    sessionCheckbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    InterfaceOptions_AddCategory(panel)
    
    return panel
end

-- Create the main frame
function RLT:CreateFrame()
    if self.frame then return end
    
    -- Main frame
    local frame = CreateFrame("Frame", "RecentLootTrackerFrame", UIParent)
    frame:SetWidth(settings.windowWidth)
    frame:SetHeight(settings.windowHeight)
    frame:SetPoint("CENTER", UIParent, "CENTER", settings.positionX, settings.positionY)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:Hide()
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() 
        frame:StopMovingOrSizing()
        -- Save new position
        local point, _, _, x, y = frame:GetPoint()
        settings.positionX = x
        settings.positionY = y
        RLT:SaveSettings()
    end)
    
    -- Mouse enter/leave events for auto-hide control
    frame:SetScript("OnEnter", function()
        RLT.mouseOver = true
    end)
    
    frame:SetScript("OnLeave", function()
        RLT.mouseOver = false
        -- Restart the hide timer when mouse leaves
        RLT:StartDisplayTimer()
    end)
    
    -- Title bar
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("Recent Loot")
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    
    -- Scroll frame for loot entries
    local scrollFrame = CreateFrame("ScrollFrame", "RecentLootScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 20)
    
    -- Content frame inside scroll frame
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(settings.windowWidth - 50)
    contentFrame:SetHeight(1) -- Will be adjusted dynamically
    scrollFrame:SetScrollChild(contentFrame)
    
    frame.scrollFrame = scrollFrame
    frame.contentFrame = contentFrame
    frame.lootEntries = {}
    
    self.frame = frame
end

-- Create a single loot entry row
function RLT:CreateLootEntry(parent, index)
    local entry = CreateFrame("Frame", nil, parent)
    entry:SetWidth(settings.windowWidth - 50)
    entry:SetHeight(ENTRY_HEIGHT)
    entry:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ENTRY_HEIGHT)
    
    -- Enable mouse events for tooltip and highlighting
    entry:EnableMouse(true)
    
    -- Create highlight texture (initially hidden)
    local highlight = entry:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints(entry)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.5)
    highlight:Hide()
    
    -- Item icon
    local icon = CreateFrame("Frame", nil, entry)
    icon:SetWidth(16)
    icon:SetHeight(16)
    icon:SetPoint("LEFT", entry, "LEFT", 5, 0)
    
    local iconTexture = icon:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints(icon)
    iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Item name
    local name = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    name:SetPoint("RIGHT", entry, "RIGHT", -5, 0)
    name:SetJustifyH("LEFT")
    name:SetText("Unknown Item")
    
    -- Mouse events for tooltip and highlighting
    entry:SetScript("OnEnter", function(self)
        -- Show highlight
        highlight:Show()
        
        -- Show tooltip if we have item data
        if entry.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(entry.itemLink)
            GameTooltip:Show()
        end
    end)
    
    entry:SetScript("OnLeave", function(self)
        -- Hide highlight
        highlight:Hide()
        
        -- Hide tooltip
        GameTooltip:Hide()
    end)
    
    entry.icon = iconTexture
    entry.name = name
    entry.highlight = highlight
    
    return entry
end

-- Cleanup loot entries by hiding and clearing itemLink
function RLT:CleanupLootEntries(entries)
    for i = 1, #entries do
        entries[i]:Hide()
        entries[i].itemLink = nil
    end
end

-- Update the loot display
function RLT:UpdateDisplay()
    if not self.frame then return end
    
    local contentFrame = self.frame.contentFrame
    local entries = self.frame.lootEntries
    
    -- Clear existing entries
    RLT:CleanupLootEntries(entries)
    
    -- Create/show entries for recent loot
    local numItems = math.min(#self.recentLoot, settings.maxEntries)
    
    for i = 1, numItems do
        if not entries[i] then
            entries[i] = self:CreateLootEntry(contentFrame, i)
        end
        
        local entry = entries[i]
        local lootData = self.recentLoot[i]
        
        -- Set icon
        if lootData.texture then
            entry.icon:SetTexture(lootData.texture)
        else
            entry.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        
        -- Set name with quality color
        local colorCode = ""
        if lootData.quality and lootData.quality >= 0 then
            local r, g, b = GetItemQualityColor(lootData.quality)
            colorCode = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
        end
        
        local displayName = lootData.name or "Unknown Item"
        if lootData.count and lootData.count > 1 then
            displayName = displayName .. " (" .. lootData.count .. ")"
        end
        
        entry.name:SetText(colorCode .. displayName .. "|r")
        
        -- Store item link for tooltip
        entry.itemLink = lootData.link
        
        entry:Show()
    end
    
    -- Adjust content frame height
    contentFrame:SetHeight(math.max(1, numItems * ENTRY_HEIGHT))
    
    -- Show the frame if we have loot to display
    if numItems > 0 then
        self.frame:Show()
    end
end

-- Add a new loot item
function RLT:AddLoot(itemLink, count)
    if not itemLink then return end
    
    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
    
    if not itemName then
        -- Item info not cached yet, try again later
        local retryFrame = CreateFrame("Frame")
        local elapsed = 0
        retryFrame:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.1 then
                retryFrame:SetScript("OnUpdate", nil)
                RLT:AddLoot(itemLink, count)
            end
        end)
        return
    end
    
    local currentTime = time()
    
    -- Check if this is a new loot session (more than LOOT_SESSION_TIMEOUT seconds since last loot)
    local isNewSession = (currentTime - self.lastLootTime) > LOOT_SESSION_TIMEOUT
    
    -- If we're in "only current session" mode and this is a new session, clear previous loot
    if settings.onlyCurrentSession and isNewSession and #self.recentLoot > 0 then
        self.recentLoot = {}
    end
    
    local lootData = {
        name = itemName,
        link = itemLink,
        quality = itemQuality,
        texture = itemTexture,
        count = count or 1,
        timestamp = currentTime
    }
    
    -- Insert at the beginning of the list
    table.insert(self.recentLoot, 1, lootData)
    
    -- Remove old entries (only if not in session mode, or if we have too many from current session)
    local maxEntries = settings.onlyCurrentSession and 20 or settings.maxEntries
    while #self.recentLoot > maxEntries do
        table.remove(self.recentLoot)
    end
    
    -- Update last loot time
    self.lastLootTime = currentTime
    
    self:UpdateDisplay()
    self:StartDisplayTimer()
end

-- Start the display timer
function RLT:StartDisplayTimer()
    if self.displayTimer then
        self.displayTimer:SetScript("OnUpdate", nil)
        self.displayTimer = nil
    end
    
    -- Don't start timer if mouse is over the frame
    if self.mouseOver then
        return
    end
    
    -- Create a timer frame
    local timerFrame = CreateFrame("Frame")
    local elapsed = 0
    timerFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        
        -- Pause timer if mouse is over the frame
        if RLT.mouseOver then
            elapsed = 0
            return
        end
        
        if elapsed >= settings.displayTime then
            self:SetScript("OnUpdate", nil)
            if RLT.frame then
                RLT.frame:Hide()
            end
            RLT.displayTimer = nil
        end
    end)
    
    self.displayTimer = timerFrame
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        RLT:InitializeSettings()
        RLT:CreateFrame()
        RLT:CreateSettingsPanel()
        
    elseif event == "CHAT_MSG_LOOT" then
        local message = ...
        
        -- Parse loot messages for items we received
        -- Pattern for "You receive item: [Item Name]" or "You receive loot: [Item Name]"
        local itemLink = string.match(message, "You receive.-: (|c%x+|Hitem:.-|r)")
        if not itemLink then
            itemLink = string.match(message, "You receive loot: (|c%x+|Hitem:.-|r)")
        end
        
        if itemLink then
            -- Check for quantity in the message (e.g., "x5")
            local count = string.match(message, "x(%d+)")
            RLT:AddLoot(itemLink, tonumber(count))
        end
    end
end)

-- Slash command to toggle the window
SLASH_RECENTLOOT1 = "/recentloot"
SLASH_RECENTLOOT2 = "/rlt"
SlashCmdList["RECENTLOOT"] = function(msg)
    if not RLT.frame then
        RLT:CreateFrame()
    end
    
    if RLT.frame:IsShown() then
        RLT.frame:Hide()
        print("Recent Loot Tracker: Window hidden")
    else
        RLT:UpdateDisplay()
        if #RLT.recentLoot > 0 then
            RLT.frame:Show()
            print("Recent Loot Tracker: Window shown")
        else
            print("Recent Loot Tracker: No recent loot to display")
        end
    end
end

print("|cff00ff00RecentLootTracker loaded! Use /recentloot or /rl to toggle the window.|r")
print("|cff00ff00Configure settings in Interface -> AddOns -> Recent Loot Tracker|r")