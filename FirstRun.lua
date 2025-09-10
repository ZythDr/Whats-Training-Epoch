local _, wt = ...

WT_EpochAccountDB = WT_EpochAccountDB or {}
WT_EpochCharDB = WT_EpochCharDB or {}

local overlayFrame
local doNotShowCheckBox

local function OverlayShouldShow()
    if WT_EpochAccountDB.firstRunOverlayDismissed then return false end
    if WT_EpochCharDB.firstRunOverlayDismissed then return false end
    return true
end

local function HideOverlay()
    if overlayFrame then
        overlayFrame:Hide()
    end
    if doNotShowCheckBox and doNotShowCheckBox:GetChecked() then
        WT_EpochAccountDB.firstRunOverlayDismissed = true
    else
        WT_EpochCharDB.firstRunOverlayDismissed = true
    end
end

local function CreateOverlay()
    if overlayFrame then return overlayFrame end

    local parentFrame = wt.MainFrame and wt.MainFrame.content or wt.MainFrame
    if not parentFrame then return nil end

    overlayFrame = CreateFrame("Frame", "WT_EpochFirstRunOverlay", parentFrame)
    overlayFrame:SetFrameStrata("HIGH")
    overlayFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
    overlayFrame:SetAllPoints(parentFrame)
    overlayFrame:EnableMouse(true)
    overlayFrame:SetMovable(false)

    -- Dark semi-transparent background, 70% opacity
    local bg = overlayFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(overlayFrame)
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    -- Large, yellow, info text with extra newline
    local infoText = overlayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    infoText:SetPoint("TOPLEFT", overlayFrame, "TOPLEFT", 24, -40)
    infoText:SetPoint("TOPRIGHT", overlayFrame, "TOPRIGHT", -24, -40)
    infoText:SetWidth(overlayFrame:GetWidth() - 48)
    infoText:SetJustifyH("CENTER")
    infoText:SetJustifyV("TOP")
    infoText:SetWordWrap(true)
    infoText:SetText("This Addon can only display spells and abilities that have been seen at a class trainer.\n\nFor best results, visit a capital city class trainer.")

    -- "Got it!" button centered horizontally near the bottom
    local gotItBtn = CreateFrame("Button", nil, overlayFrame, "UIPanelButtonTemplate")
    gotItBtn:SetSize(120, 32)
    gotItBtn:SetPoint("BOTTOM", overlayFrame, "BOTTOM", 0, 52)
    gotItBtn:SetText("Got it!")
    gotItBtn:SetScript("OnClick", HideOverlay)

    -- Checkbox left-aligned near the bottom left of the overlay, moved 10px further left
    doNotShowCheckBox = CreateFrame("CheckButton", nil, overlayFrame, "OptionsCheckButtonTemplate")
    doNotShowCheckBox:SetPoint("BOTTOMLEFT", overlayFrame, "BOTTOMLEFT", 14, 16)
    doNotShowCheckBox:SetSize(24, 24)

    -- Checkbox label, left-aligned, spacing reduced to 4px
    local checkLabel = overlayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    checkLabel:SetPoint("LEFT", doNotShowCheckBox, "RIGHT", 4, 0)
    checkLabel:SetPoint("RIGHT", overlayFrame, "RIGHT", -24, 0)
    checkLabel:SetJustifyH("LEFT")
    checkLabel:SetText("Do not show again for any character")

    return overlayFrame
end

local function ShowOverlayIfNeeded()
    if not OverlayShouldShow() then return end
    local parentFrame = wt.MainFrame and wt.MainFrame.content or wt.MainFrame
    if not parentFrame or not parentFrame:IsVisible() then return end
    CreateOverlay()
    if doNotShowCheckBox then doNotShowCheckBox:SetChecked(false) end
    overlayFrame:Show()
end

function wt.ResetFirstRunOverlay()
    WT_EpochAccountDB.firstRunOverlayDismissed = false
    WT_EpochCharDB.firstRunOverlayDismissed = false
    if overlayFrame then overlayFrame:Hide() end
end

if wt.MainFrame then
    local parentFrame = wt.MainFrame.content or wt.MainFrame
    parentFrame:HookScript("OnShow", ShowOverlayIfNeeded)
else
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        if wt.MainFrame then
            local parentFrame = wt.MainFrame.content or wt.MainFrame
            parentFrame:HookScript("OnShow", ShowOverlayIfNeeded)
            self:SetScript("OnUpdate", nil)
        end
    end)
end