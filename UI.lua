-- Spellbook skill line tab UI (visually identical to original) with collapsible headers + search dimming + custom search box styling and placeholder
local ADDON_NAME, wt = ...

local BOOKTYPE_SPELL = BOOKTYPE_SPELL
local MAX_ROWS = 22
local ROW_HEIGHT = 14
local SKILL_LINE_TAB = MAX_SKILLLINE_TABS - 1

-- Build texture paths dynamically from the actual addon folder name
local ADDON_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\"
local HIGHLIGHT_TEXTURE_PATH = ADDON_PATH .. "res\\highlight"
local LEFT_BG_TEXTURE_PATH   = ADDON_PATH .. "res\\left"
local RIGHT_BG_TEXTURE_PATH  = ADDON_PATH .. "res\\right"
local TAB_TEXTURE_PATH       = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Ensure account DB exists and defaults
WT_EpochAccountDB = WT_EpochAccountDB or {}
if WT_EpochAccountDB.useClassTabIcon == nil then WT_EpochAccountDB.useClassTabIcon = false end
if WT_EpochAccountDB.collapsedCats == nil then WT_EpochAccountDB.collapsedCats = {} end

-- Collapse helpers (account-wide persistence)
local function IsHeaderCollapsed(key)
  if not key then return false end
  local m = WT_EpochAccountDB.collapsedCats or {}
  return m[key] == true
end
function wt.IsHeaderCollapsed(key) -- exposed for other modules if needed
  return IsHeaderCollapsed(key)
end
function wt.ToggleHeaderCollapse(key)
  if not key then return end
  WT_EpochAccountDB.collapsedCats = WT_EpochAccountDB.collapsedCats or {}
  WT_EpochAccountDB.collapsedCats[key] = not WT_EpochAccountDB.collapsedCats[key]
  -- Rebuild display list and refresh the current view
  if wt.MainFrame and wt.MainFrame:IsVisible() and type(wt.Update) == "function" then
    wt.Update(wt.MainFrame, true)
  end
end

-- Derived display list that respects collapsed headers (UI-only; wt.data remains complete)
function wt.RebuildDisplayData()
  local src = wt.data or {}
  local dst = {}

  local i = 1
  local n = #src
  while i <= n do
    local row = src[i]
    if row and row.isHeader then
      table.insert(dst, row)
      local collapsed = row.key and IsHeaderCollapsed(row.key)
      if collapsed then
        -- Skip the next #row.spells entries (they are contiguous right after this header)
        local toSkip = (row.spells and #row.spells) or 0
        i = i + 1 + toSkip
      else
        i = i + 1
      end
    else
      table.insert(dst, row)
      i = i + 1
    end
  end

  wt._displayData = dst
end

-- Case-insensitive substring check (needleLower must be lowercase)
local function ContainsCI(hay, needleLower)
  if not needleLower or needleLower == "" then return true end
  if not hay or hay == "" then return false end
  return string.find(string.lower(hay), needleLower, 1, true) ~= nil
end

-- Row search match: nil/empty search => match; headers match by header name OR any child that matches
local function RowMatches(spell, needleLower)
  if not needleLower or needleLower == "" then return true end
  if not spell then return false end
  if spell.isHeader then
    if ContainsCI(spell.name, needleLower) then return true end
    local list = spell.spells
    if type(list) == "table" then
      for i = 1, #list do
        local s = list[i]
        if s and (ContainsCI(s.name, needleLower) or ContainsCI(s.formattedSubText, needleLower) or ContainsCI(s.tooltip, needleLower)) then
          return true
        end
      end
    end
    return false
  else
    return ContainsCI(spell.name, needleLower)
        or ContainsCI(spell.formattedSubText, needleLower)
        or ContainsCI(spell.tooltip, needleLower)
  end
end

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

-- Defensive: make sure the level label exists on the row before use
local function EnsureLevelLabel(row)
  if not row or not row.spell then return end
  if row.spell.level then return end

  local lvl = row.spell:CreateFontString("$parentLevelLabel", "OVERLAY", "GameFontWhite")
  lvl:SetPoint("TOPRIGHT", row.spell, -4, 0)
  lvl:SetPoint("BOTTOM", row.spell)
  lvl:SetJustifyH("RIGHT")
  lvl:SetJustifyV("MIDDLE")
  row.spell.level = lvl

  -- Re-anchor sub label relative to the level label
  if row.spell.subLabel then
    row.spell.subLabel:ClearAllPoints()
    row.spell.subLabel:SetPoint("TOPLEFT", row.spell.label, "TOPRIGHT", 2, 0)
    row.spell.subLabel:SetPoint("BOTTOM", row.spell.label)
    row.spell.subLabel:SetPoint("RIGHT", lvl, "LEFT")
    row.spell.subLabel:SetJustifyV("MIDDLE")
  end
end

local function setRowSpell(row, spell)
  if not spell then
    row.currentSpell = nil
    row:Hide()
    return
  elseif spell.isHeader then
    -- Header row: center title, left-aligned +/- indicator, right-aligned count
    row.spell:Hide()
    row.header:Show()
    row.highlight:SetTexture(nil)
    row:SetID(0)

    local title = spell.formattedName or (spell.name or "")
    local count = (spell.spells and #spell.spells) or 0

    row.header:SetText(title)

    if spell.key then
      local collapsed = IsHeaderCollapsed(spell.key)
      local indicator = collapsed and "+" or "-" -- no square brackets

      -- Left icon: light gray
      if row.headerIcon then
        row.headerIcon:SetText(indicator)
        row.headerIcon:SetTextColor(0.75, 0.75, 0.75) -- #bbbbbb
        row.headerIcon:Show()
      end

      -- Right count: darker gray
      if row.headerCount then
        row.headerCount:SetText(string.format("(%d)", count))
        row.headerCount:SetTextColor(0.53, 0.53, 0.53) -- ~#888888
        row.headerCount:Show()
      end

      row:SetScript("OnClick", function()
        wt.ToggleHeaderCollapse(spell.key)
      end)
    else
      -- Non-collapsible informational header (e.g., "No data yet")
      if row.headerIcon then row.headerIcon:Hide() end
      if row.headerCount then row.headerCount:Hide() end
      row:SetScript("OnClick", nil)
    end

  else
    -- Non-header row
    row.header:Hide()
    if row.headerIcon then row.headerIcon:Hide() end
    if row.headerCount then row.headerCount:Hide() end

    row.isHeader = false
    row.highlight:SetTexture(HIGHLIGHT_TEXTURE_PATH)
    row.spell:Show()
    row.spell.label:SetText(spell.name or "")
    row.spell.subLabel:SetText(spell.formattedSubText or "")

    -- Ensure level widget exists before using it
    EnsureLevelLabel(row)

    if row.spell.level then
      if not spell.hideLevel and (spell.formattedLevel and spell.formattedLevel ~= "") then
        row.spell.level:Show()
        row.spell.level:SetText(spell.formattedLevel)
        local c = spell.levelColor or { r = 1, g = 1, b = 1 }
        row.spell.level:SetTextColor(c.r, c.g, c.b)
      else
        row.spell.level:Hide()
      end
    end

    row:SetID(spell.id or 0)
    row.spell.icon:SetTexture(spell.icon or TAB_TEXTURE_PATH)
    row:SetScript("OnClick", nil)
  end

  -- Apply search dimming
  local needle = wt._searchText -- already lowercase or nil
  local match = RowMatches(spell, needle)
  row:SetAlpha(match and 1 or 0.35)

  row.currentSpell = spell
  if tooltip:IsOwned(row) then setTooltip(spell) end
  row:Show()
end

local lastOffset = -1
function wt.Update(frame, forceUpdate)
  -- Build the UI display list from the full data set, respecting collapsed state
  wt.RebuildDisplayData()
  local list = wt._displayData or wt.data or {}

  local scrollBar = frame.scrollBar
  local offset = FauxScrollFrame_GetOffset(scrollBar)
  if (offset == lastOffset and not forceUpdate) then
    if wt.UpdateTotals then wt.UpdateTotals() end
    return
  end

  for i, row in ipairs(frame.rows) do
    local idx = i + offset
    local spell = list[idx]
    setRowSpell(row, spell)
  end

  FauxScrollFrame_Update(frame.scrollBar, #list, MAX_ROWS, ROW_HEIGHT, nil, nil, nil, nil, nil, nil, true)
  lastOffset = offset
  if wt.UpdateTotals then wt.UpdateTotals() end
end

-- Hide/show spellbook spell buttons 1-24
local function WT_SetSpellButtonsVisible(visible)
  for i = 1, 24 do
    local btn = _G["SpellButton"..i]
    if btn then
      if visible then
        btn:Show()
      else
        btn:Hide()
      end
    end
  end
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
  mainFrame:SetFrameStrata("MEDIUM")
  mainFrame:SetFrameLevel(40) -- ensure our frame is above page buttons

  -- Background
  local left = mainFrame:CreateTexture(nil, "ARTWORK")
  left:SetTexture(LEFT_BG_TEXTURE_PATH)
  left:SetWidth(256) left:SetHeight(512)
  left:SetPoint("TOPLEFT", mainFrame)
  left:SetDrawLayer("ARTWORK", 0)

  local right = mainFrame:CreateTexture(nil, "ARTWORK")
  right:SetTexture(RIGHT_BG_TEXTURE_PATH)
  right:SetWidth(128) right:SetHeight(512)
  right:SetPoint("TOPRIGHT", mainFrame)
  right:SetDrawLayer("ARTWORK", 0)
  mainFrame:Hide()

  -- === TOP BAR FRAME (contains EditBox and Total Cost) ===
  local topBarWidth = 260 -- adjust as desired
  local topBarHeight = 24
  local topBarFrame = CreateFrame("Frame", "$parentTopBarFrame", mainFrame)
  topBarFrame:SetHeight(topBarHeight)
  topBarFrame:SetWidth(topBarWidth)
  topBarFrame:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -45, -43)
  topBarFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 1)
  mainFrame.topBarFrame = topBarFrame

  -- EditBox inside TopBarFrame
  local search = CreateFrame("EditBox", "$parentSearchBox", topBarFrame, "InputBoxTemplate")
  mainFrame.searchBox = search
  search:SetHeight(20)
  search:SetAutoFocus(false)
  search:SetMaxLetters(64)
  search:SetFrameLevel(topBarFrame:GetFrameLevel() + 1)
  search:SetPoint("LEFT", topBarFrame, "LEFT", 0, 0)
  search:SetPoint("CENTER", topBarFrame, "CENTER", -topBarWidth/4, 0) -- vertical center alignment

  -- Custom Background for EditBox (inner, not covering corners)
  local bg = search:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", search, "TOPLEFT", -4, -4)
  bg:SetPoint("BOTTOMRIGHT", search, "BOTTOMRIGHT", 0, 4)
  bg:SetTexture(0, 0, 0, 0.5)
  bg:SetDrawLayer("BACKGROUND", 0)
  search.bg = bg

  -- Placeholder Text for EditBox
  local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  placeholder:SetPoint("LEFT", search, "LEFT", 0, -0)
  placeholder:SetPoint("RIGHT", search, "RIGHT", -0, -1)
  placeholder:SetJustifyH("LEFT")
  placeholder:SetText("Search...")
  search.placeholder = placeholder

  local function UpdatePlaceholder()
    if search:HasFocus() or (search:GetText() ~= nil and search:GetText() ~= "") then
      search.placeholder:Hide()
    else
      search.placeholder:Show()
    end
  end
  search:HookScript("OnTextChanged", UpdatePlaceholder)
  search:HookScript("OnEditFocusGained", UpdatePlaceholder)
  search:HookScript("OnEditFocusLost", UpdatePlaceholder)

  search:SetScript("OnTextChanged", function(self)
    local txt = self:GetText() or ""
    txt = txt:match("^%s*(.-)%s*$")
    wt._searchText = (txt ~= "" and string.lower(txt)) or nil
    if wt.MainFrame and wt.MainFrame:IsVisible() and type(wt.Update) == "function" then
      wt.Update(wt.MainFrame, true)
    end
  end)
  search:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
  end)
  search:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)

  -- Global focus catcher for EditBox (unfocuses on any click in game window)
  local globalFocusCatcher = CreateFrame("Frame", "WhatsTrainingGlobalFocusCatcher", UIParent)
  globalFocusCatcher:SetFrameStrata("TOOLTIP")
  globalFocusCatcher:SetFrameLevel(9999)
  globalFocusCatcher:SetAllPoints(UIParent)
  globalFocusCatcher:EnableMouse(true)
  globalFocusCatcher:Hide()
  globalFocusCatcher:SetScript("OnMouseDown", function()
    search:ClearFocus()
    globalFocusCatcher:Hide()
  end)
  search:HookScript("OnEditFocusGained", function()
    globalFocusCatcher:Show()
  end)
  search:HookScript("OnEditFocusLost", function()
    globalFocusCatcher:Hide()
  end)

  -- Total Cost label inside TopBarFrame
  local totalText = topBarFrame:CreateFontString("$parentTotalCost", "OVERLAY", "GameFontNormal")
  totalText:SetJustifyH("RIGHT")
  totalText:SetPoint("RIGHT", topBarFrame, "RIGHT", 0, 0)
  totalText:SetPoint("CENTER", topBarFrame, "CENTER", topBarWidth/4, 0) -- vertical center alignment
  totalText:SetDrawLayer("OVERLAY", 2)
  totalText:Hide()
  mainFrame.totalCostText = totalText

  -- Dynamically resize EditBox based on Total Cost label
  local function UpdateTopBarLayout()
    totalText:Show()
    local costWidth = totalText:GetStringWidth() or 0
    local barWidth = topBarFrame:GetWidth() or topBarWidth
    local pad = 8 -- adjust the gap here
    local editWidth = math.max(50, barWidth - costWidth - pad)
    search:SetWidth(editWidth)
  end

  topBarFrame:SetScript("OnSizeChanged", UpdateTopBarLayout)
  mainFrame.UpdateTopBarLayout = UpdateTopBarLayout

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
    if mainFrame.UpdateTopBarLayout then mainFrame.UpdateTopBarLayout() end
  end

  -- Scrollable content container (visual viewport)
  local content = CreateFrame("Frame", "$parentContent", mainFrame)
  mainFrame.content = content
  content:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 26, -78)
  content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -65, 81)
  content:SetFrameLevel(mainFrame:GetFrameLevel() + 1)

  -- FauxScrollFrame drives which rows are populated (we don't physically move children)
  local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", mainFrame, "FauxScrollFrameTemplate")
  mainFrame.scrollBar = scrollBar
  scrollBar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
  scrollBar:SetFrameLevel(mainFrame:GetFrameLevel() + 2)
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
    row:SetFrameLevel(content:GetFrameLevel() + 1)
    row:SetScript("OnEnter", function(self)
      tooltip:SetOwner(self, "ANCHOR_RIGHT")
      setTooltip(self.currentSpell)
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local highlight = row:CreateTexture("$parentHighlight", "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetDrawLayer("HIGHLIGHT", 1)

    local spell = CreateFrame("Frame", "$parentSpell", row)
    spell:SetPoint("LEFT", row, "LEFT")
    spell:SetPoint("TOP", row, "TOP")
    spell:SetPoint("BOTTOM", row, "BOTTOM")
    spell:SetFrameLevel(row:GetFrameLevel() + 1)

    local spellIcon = spell:CreateTexture(nil, "ARTWORK")
    spellIcon:SetPoint("TOPLEFT", spell)
    spellIcon:SetPoint("BOTTOMLEFT", spell)
    spellIcon:SetWidth(ROW_HEIGHT)
    spellIcon:SetDrawLayer("ARTWORK", 1)

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

    -- Centered header title
    local headerLabel = row:CreateFontString("$parentHeaderLabel", "OVERLAY", "GameFontWhite")
    headerLabel:SetAllPoints()
    headerLabel:SetJustifyV("MIDDLE")
    headerLabel:SetJustifyH("CENTER")

    -- Left-aligned +/- indicator for headers
    local headerIcon = row:CreateFontString("$parentHeaderIcon", "OVERLAY", "GameFontWhite")
    headerIcon:SetPoint("LEFT", row, "LEFT", 2, 0)
    headerIcon:SetJustifyH("LEFT")
    headerIcon:SetJustifyV("MIDDLE")
    headerIcon:Hide()

    -- Right-aligned count for headers
    local headerCount = row:CreateFontString("$parentHeaderCount", "OVERLAY", "GameFontWhite")
    headerCount:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    headerCount:SetJustifyH("RIGHT")
    headerCount:SetJustifyV("MIDDLE")
    headerCount:Hide()

    -- Attach child widgets to the container for easy access
    spell.label = spellLabel
    spell.subLabel = spellSublabel
    spell.icon = spellIcon
    spell.level = spellLevelLabel
    row.highlight = highlight
    row.header = headerLabel
    row.headerIcon = headerIcon
    row.headerCount = headerCount
    row.spell = spell

    if rows[i - 1] == nil then
      row:SetPoint("TOPLEFT", content, 0, 0)
    else
      row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
    end

    rows[i] = row
  end
  mainFrame.rows = rows

  -- Helper: show/hide the native "Show all spell ranks" checkbox while our UI is visible
  local function WT_SetShowAllRanksVisible(visible)
    local cb = _G.ShowAllSpellRanksCheckBox or _G["ShowAllSpellRanksCheckBox"]
    if not cb then return end
    if visible then cb:Show() else cb:Hide() end
  end

  -- Helper: show/hide the spellbook spell buttons 1-24 while our UI is visible
  -- (already defined above as WT_SetSpellButtonsVisible)

  -- Compute and apply visibility for our frame and the checkbox based on SpellBook state
  local function WT_ApplySpellbookVisibility()
    local skillLineTab = _G["SpellBookSkillLineTab" .. SKILL_LINE_TAB]
    if skillLineTab then
      skillLineTab:SetNormalTexture(TAB_TEXTURE_PATH)
      skillLineTab.tooltip = wt.L.TAB_TEXT
      skillLineTab:Show()
    end

    local showWT = (SpellBookFrame.bookType == BOOKTYPE_SPELL) and (SpellBookFrame.selectedSkillLine == SKILL_LINE_TAB)

    if skillLineTab then
      skillLineTab:SetChecked(showWT)
    end

    if showWT then
      mainFrame:Show()
      WT_SetShowAllRanksVisible(false)
      WT_SetSpellButtonsVisible(false)
    else
      mainFrame:Hide()
      WT_SetShowAllRanksVisible(true)
      WT_SetSpellButtonsVisible(true)
    end
  end

  -- Ensure consistency if our frame is shown/hidden by any other means
  mainFrame:HookScript("OnShow", function()
    WT_SetShowAllRanksVisible(false)
    WT_SetSpellButtonsVisible(false)
    if SpellBookPrevPageButton then SpellBookPrevPageButton:Hide() end
    if SpellBookNextPageButton then SpellBookNextPageButton:Hide() end
  end)

  mainFrame:HookScript("OnHide", function()
    WT_SetShowAllRanksVisible(true)
    WT_SetSpellButtonsVisible(true)
    if SpellBookPrevPageButton then SpellBookPrevPageButton:Show() end
    if SpellBookNextPageButton then SpellBookNextPageButton:Show() end
  end)

  -- Hook spellbook tab behavior once
  if not wt._uiHooked then
    hooksecurefunc("SpellBookFrame_Update", function()
      WT_ApplySpellbookVisibility()
    end)
    wt._uiHooked = true
  end

  -- Apply initial visibility state
  if type(SpellBookFrame_Update) == "function" then
    SpellBookFrame_Update()
  else
    WT_ApplySpellbookVisibility()
  end
end

-- ===== Tab icon (What's Training? spellbook tab) =====
local ICON_ZOOM = 1.3

local function SetZoomedTexCoord(tex, left, right, top, bottom, zoom)
  zoom = tonumber(zoom) or 1
  if zoom <= 1 then
    tex:SetTexCoord(left, right, top, bottom)
    return
  end
  local w = right - left
  local h = bottom - top
  local padX = (1 - 1/zoom) * w * 0.5
  local padY = (1 - 1/zoom) * h * 0.5
  tex:SetTexCoord(left + padX, right - padX, top + padY, bottom - padY)
end

local function ApplyWTTabIconInternal()
  local tabIndex = (MAX_SKILLLINE_TABS and (MAX_SKILLLINE_TABS - 1)) or 4
  local tab = _G["SpellBookSkillLineTab" .. tabIndex]
  if not tab then return end

  if not tab:GetNormalTexture() then
    tab:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  end
  local tex = tab:GetNormalTexture()
  if not tex then return end

  local useClass = WT_EpochAccountDB and WT_EpochAccountDB.useClassTabIcon
  if useClass then
    local classToken = select(2, UnitClass("player"))
    if CLASS_ICON_TCOORDS and classToken and CLASS_ICON_TCOORDS[classToken] then
      local c = CLASS_ICON_TCOORDS[classToken]
      tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
      SetZoomedTexCoord(tex, c[1], c[2], c[3], c[4], ICON_ZOOM)
      return
    end
  end

  tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  SetZoomedTexCoord(tex, 0, 1, 0, 1, ICON_ZOOM)
end

local function ApplyWTTabIconNextFrame()
  local fr = CreateFrame("Frame")
  fr:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    ApplyWTTabIconInternal()
  end)
end

-- Public helpers for other modules
function wt.ApplyWTTabIcon()
  ApplyWTTabIconInternal()
  ApplyWTTabIconNextFrame()
end

function wt.ToggleTabIcon()
  WT_EpochAccountDB = WT_EpochAccountDB or {}
  WT_EpochAccountDB.useClassTabIcon = not WT_EpochAccountDB.useClassTabIcon
  wt.ApplyWTTabIcon()
  if type(SpellBookFrame_Update) == "function" then
    SpellBookFrame_Update()
  end
  return WT_EpochAccountDB.useClassTabIcon
end

if type(hooksecurefunc) == "function" and type(SpellBookFrame_Update) == "function" then
  hooksecurefunc("SpellBookFrame_Update", function()
    ApplyWTTabIconInternal()
    ApplyWTTabIconNextFrame()
  end)
end
-- ===== End: Tab icon =====
