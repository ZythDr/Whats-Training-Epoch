-- Spellbook skill line tab UI (visually identical to original)
local _, wt = ...

local BOOKTYPE_SPELL = BOOKTYPE_SPELL
local MAX_ROWS = 22
local ROW_HEIGHT = 14
local SKILL_LINE_TAB = MAX_SKILLLINE_TABS - 1
local HIGHLIGHT_TEXTURE_PATH = "Interface\\AddOns\\WhatsTraining_Epoch\\res\\highlight"
local LEFT_BG_TEXTURE_PATH   = "Interface\\AddOns\\WhatsTraining_Epoch\\res\\left"
local RIGHT_BG_TEXTURE_PATH  = "Interface\\AddOns\\WhatsTraining_Epoch\\res\\right"
local TAB_TEXTURE_PATH       = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Use the global GameTooltip for maximum compatibility on 3.3.5 variants
local tooltip = GameTooltip

local function appendCostLine(spell)
  local cost = tonumber(spell and spell.cost or 0) or 0
  if cost > 0 then
    local coins = (spell and spell.formattedCost) or GetCoinTextureString(cost)
    if GetMoney and GetMoney() < cost then
      coins = RED_FONT_COLOR_CODE .. coins .. FONT_COLOR_CODE_CLOSE
    end
    tooltip:AddLine(" ")
    tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE .. string.format(wt.L.COST_FORMAT, coins) .. FONT_COLOR_CODE_CLOSE)
  end
end

local function setTooltip(spell)
  tooltip:ClearLines()
  if not spell then
    tooltip:Show()
    return
  end

  local id = tonumber(spell.id or 0) or 0
  if id > 0 then
    -- Prime client cache and try to get a full link
    local name = GetSpellInfo(id) or spell.name or "Unknown"
    local link = (GetSpellLink and GetSpellLink(id)) or nil

    -- Build a well-formed hyperlink string if GetSpellLink is unavailable
    if not link then
      link = string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", id, name)
    end

    if type(tooltip.SetHyperlink) == "function" then
      tooltip:SetHyperlink(link)
    elseif type(tooltip.SetSpellByID) == "function" then
      tooltip:SetSpellByID(id)
    else
      -- Last resort: simple text title
      local title = name
      local sub = spell.formattedSubText or ""
      if sub ~= "" then title = title .. " " .. sub end
      tooltip:SetText(title, 1, 1, 1, 1, true)
    end

    appendCostLine(spell)
  else
    -- No spell ID known yet: minimal fallback so users still see something
    local title = (spell.name or "Unknown")
    local sub = spell.formattedSubText or ""
    if sub ~= "" then title = title .. " " .. sub end
    tooltip:SetText(title, 1, 1, 1, 1, true)

    appendCostLine(spell)

    if spell.tooltip and spell.tooltip ~= "" then
      tooltip:AddLine(" ")
      tooltip:AddLine(spell.tooltip, 0.9, 0.9, 0.9, true)
    end
  end

  tooltip:Show()
end

local function setRowSpell(row, spell)
  if not spell then
    row.currentSpell = nil
    row:Hide()
    return
  elseif spell.isHeader then
    row.spell:Hide()
    row.header:Show()
    row.header:SetText(spell.formattedName or "")
    row:SetID(0)
    row.highlight:SetTexture(nil)
  else
    row.header:Hide()
    row.isHeader = false
    row.highlight:SetTexture(HIGHLIGHT_TEXTURE_PATH)
    row.spell:Show()
    row.spell.label:SetText(spell.name or "")
    row.spell.subLabel:SetText(spell.formattedSubText or "")
    if not spell.hideLevel and (spell.formattedLevel and spell.formattedLevel ~= "") then
      row.spell.level:Show()
      row.spell.level:SetText(spell.formattedLevel)
      local c = spell.levelColor or { r = 1, g = 1, b = 1 }
      row.spell.level:SetTextColor(c.r, c.g, c.b)
    else
      row.spell.level:Hide()
    end
    row:SetID(spell.id or 0)
    row.spell.icon:SetTexture(spell.icon or TAB_TEXTURE_PATH)
  end

  row:SetScript("OnClick", nil)
  row.currentSpell = spell
  if tooltip:IsOwned(row) then setTooltip(spell) end
  row:Show()
end

local lastOffset = -1
function wt.Update(frame, forceUpdate)
  local scrollBar = frame.scrollBar
  local offset = FauxScrollFrame_GetOffset(scrollBar)
  if (offset == lastOffset and not forceUpdate) then
    if wt.UpdateTotals then wt.UpdateTotals() end
    return
  end

  for i, row in ipairs(frame.rows) do
    local idx = i + offset
    local spell = wt.data[idx]
    setRowSpell(row, spell)
  end

  FauxScrollFrame_Update(frame.scrollBar, #wt.data, MAX_ROWS, ROW_HEIGHT, nil, nil, nil, nil, nil, nil, true)
  lastOffset = offset
  if wt.UpdateTotals then wt.UpdateTotals() end
end

local hasFrameShown = false
function wt.CreateFrame()
  -- Idempotent: do not create twice (prevents duplicated “ghost” rows)
  if wt.MainFrame and wt.MainFrame._initialized then return end

  local mainFrame = wt.MainFrame
  if not mainFrame then
    mainFrame = CreateFrame("Frame", "WhatsTrainingFrame", SpellBookFrame)
    wt.MainFrame = mainFrame
  end
  mainFrame._initialized = true
  mainFrame:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 0, 0)
  mainFrame:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", 0, 0)
  mainFrame:SetFrameStrata("HIGH")

  -- Background
  local left = mainFrame:CreateTexture(nil, "ARTWORK")
  left:SetTexture(LEFT_BG_TEXTURE_PATH)
  left:SetWidth(256) left:SetHeight(512)
  left:SetPoint("TOPLEFT", mainFrame)

  local right = mainFrame:CreateTexture(nil, "ARTWORK")
  right:SetTexture(RIGHT_BG_TEXTURE_PATH)
  right:SetWidth(128) right:SetHeight(512)
  right:SetPoint("TOPRIGHT", mainFrame)
  mainFrame:Hide()

  -- Scrollable content container (visual viewport)
  local content = CreateFrame("Frame", "$parentContent", mainFrame)
  mainFrame.content = content
  content:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 26, -78)
  content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -65, 81)

  -- Total cost label (top-right above scroll area)
  local totalText = mainFrame:CreateFontString("$parentTotalCost", "OVERLAY", "GameFontNormal")
  totalText:SetJustifyH("RIGHT")
  totalText:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -72, -62)
  totalText:Hide()
  mainFrame.totalCostText = totalText

  function wt.UpdateTotals()
    if not wt.MainFrame or not wt.MainFrame.totalCostText then return end
    local t = wt.totals or {}
    if t.hasData and (t.availableCost or 0) >= 0 then
      local txt = string.format(wt.L.TOTALCOST_FORMAT, GetCoinTextureString(t.availableCost or 0))
      wt.MainFrame.totalCostText:SetText(txt)
      wt.MainFrame.totalCostText:Show()
    else
      wt.MainFrame.totalCostText:SetText("")
      wt.MainFrame.totalCostText:Hide()
    end
  end

  -- FauxScrollFrame drives which rows are populated (we don't physically move children)
  local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", mainFrame, "FauxScrollFrameTemplate")
  mainFrame.scrollBar = scrollBar
  scrollBar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
  scrollBar:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() wt.Update(mainFrame) end)
  end)
  scrollBar:SetScript("OnShow", function()
    if not hasFrameShown then
      wt.RebuildData()
      hasFrameShown = true
    end
    wt.Update(mainFrame, true)
  end)

  -- Build rows under the content container (not under the scroll frame itself)
  local rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", "$parentRow" .. i, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("RIGHT", content)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function(self)
      tooltip:SetOwner(self, "ANCHOR_RIGHT")
      setTooltip(self.currentSpell)
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local highlight = row:CreateTexture("$parentHighlight", "HIGHLIGHT")
    highlight:SetAllPoints()

    local spell = CreateFrame("Frame", "$parentSpell", row)
    spell:SetPoint("LEFT", row, "LEFT")
    spell:SetPoint("TOP", row, "TOP")
    spell:SetPoint("BOTTOM", row, "BOTTOM")

    local spellIcon = spell:CreateTexture(nil, "ARTWORK")
    spellIcon:SetPoint("TOPLEFT", spell)
    spellIcon:SetPoint("BOTTOMLEFT", spell)
    spellIcon:SetWidth(ROW_HEIGHT)

    local spellLabel = spell:CreateFontString("$parentLabel", "OVERLAY", "GameFontNormal")
    spellLabel:SetPoint("TOPLEFT", spell, "TOPLEFT", ROW_HEIGHT + 4, 0)
    spellLabel:SetPoint("BOTTOM", spell)
    spellLabel:SetJustifyV("MIDDLE")
    spellLabel:SetJustifyH("LEFT")

    local spellSublabel = spell:CreateFontString("$parentSubLabel", "OVERLAY", "SpellFont_Small")
    spellSublabel:SetTextColor(255/255, 255/255, 153/255)
    spellSublabel:SetJustifyH("LEFT")
    spellSublabel:SetPoint("TOPLEFT", spellLabel, "TOPRIGHT", 2, 0)
    spellSublabel:SetPoint("BOTTOM", spellLabel)

    local spellLevelLabel = spell:CreateFontString("$parentLevelLabel", "OVERLAY", "GameFontWhite")
    spellLevelLabel:SetPoint("TOPRIGHT", spell, -4, 0)
    spellLevelLabel:SetPoint("BOTTOM", spell)
    spellLevelLabel:SetJustifyH("RIGHT")
    spellLevelLabel:SetJustifyV("MIDDLE")
    spellSublabel:SetPoint("RIGHT", spellLevelLabel, "LEFT")
    spellSublabel:SetJustifyV("MIDDLE")

    local headerLabel = row:CreateFontString("$parentHeaderLabel", "OVERLAY", "GameFontWhite")
    headerLabel:SetAllPoints()
    headerLabel:SetJustifyV("MIDDLE")
    headerLabel:SetJustifyH("CENTER")

    spell.label = spellLabel
    spell.subLabel = spellSublabel
    spell.icon = spellIcon
    spell.level = spellLevelLabel
    row.highlight = highlight
    row.header = headerLabel
    row.spell = spell

    if rows[i - 1] == nil then
      row:SetPoint("TOPLEFT", content, 0, 0)
    else
      row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
    end

    rows[i] = row
  end
  mainFrame.rows = rows

  -- Hook spellbook tab behavior once
  if not wt._uiHooked then
    local skillLineTab = _G["SpellBookSkillLineTab" .. SKILL_LINE_TAB]
    hooksecurefunc("SpellBookFrame_Update", function()
      skillLineTab:SetNormalTexture(TAB_TEXTURE_PATH)
      skillLineTab.tooltip = wt.L.TAB_TEXT
      skillLineTab:Show()
      if (SpellBookFrame.selectedSkillLine == SKILL_LINE_TAB) then
        skillLineTab:SetChecked(true)
        mainFrame:Show()
      else
        skillLineTab:SetChecked(false)
        mainFrame:Hide()
      end
    end)
    hooksecurefunc("SpellBookFrame_Update", function()
      if (SpellBookFrame.bookType ~= BOOKTYPE_SPELL) then
        mainFrame:Hide()
      elseif (SpellBookFrame.selectedSkillLine == SKILL_LINE_TAB) then
        mainFrame:Show()
      end
    end)
    wt._uiHooked = true
  end
end