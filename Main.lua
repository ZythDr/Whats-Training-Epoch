-- Data builder: creates wt.data with headers and rows for the UI
local _, wt = ...

-- Category keys
local AVAILABLE_KEY      = "available"
local MISSINGREQS_KEY    = "missingReqs"
local NEXTLEVEL_KEY      = "nextLevel"
local NOTLEVEL_KEY       = "notLevel"
local MISSINGTALENT_KEY  = "missingTalent"
local KNOWN_KEY          = "known"

-- Headers (same text/colors as original)
local COMINGSOON_COLOR = "|cff82c5ff"
local headers = {
  { name = wt.L.AVAILABLE_HEADER,      color = GREEN_FONT_COLOR_CODE,  hideLevel = true, key = AVAILABLE_KEY },
  { name = wt.L.MISSINGREQS_HEADER,    color = ORANGE_FONT_COLOR_CODE, hideLevel = true, key = MISSINGREQS_KEY },
  { name = wt.L.NEXTLEVEL_HEADER,      color = COMINGSOON_COLOR,       hideLevel = false, key = NEXTLEVEL_KEY },
  { name = wt.L.NOTLEVEL_HEADER,       color = RED_FONT_COLOR_CODE,    hideLevel = false, key = NOTLEVEL_KEY },
  { name = wt.L.MISSINGTALENT_HEADER,  color = "|cffffffff",           hideLevel = true, key = MISSINGTALENT_KEY, nameSort = true },
  { name = wt.L.KNOWN_HEADER,          color = GRAY_FONT_COLOR_CODE,   hideLevel = true, key = KNOWN_KEY, nameSort = true },
}

local categories = {
  _byKey = {},
  Insert = function(self, key, spellInfo) table.insert(self._byKey[key], spellInfo) end,
  Initialize = function(self)
    for _, cat in ipairs(headers) do
      cat.spells = {}
      self._byKey[cat.key] = cat.spells
      cat.formattedName = cat.color .. cat.name .. FONT_COLOR_CODE_CLOSE
      cat.isHeader = true
      table.insert(self, cat)
    end
  end,
  ClearSpells = function(self)
    for _, cat in ipairs(self) do
      cat.cost = 0
      wipe(cat.spells)
    end
  end
}
categories:Initialize()

wt.data = {}
wt.totals = { hasData = false, availableCost = 0, availableCount = 0 }

local function toSpellRow(key, entry)
  local name = entry.name or "Unknown"
  local rank = entry.rank or ""
  local formattedSubText = (rank ~= "" and format(PARENS_TEMPLATE, rank)) or ""
  local level = tonumber(entry.requiredLevel or 0) or 0

  local icon = wt.GetBestIconFor(name, rank, entry.icon)

  return {
    id = tonumber(entry.id) or nil, -- pass through spellID so links/tooltips work
    name = name,
    formattedSubText = formattedSubText,
    icon = icon,
    cost = tonumber(entry.cost or 0) or 0,
    formattedCost = GetCoinTextureString(tonumber(entry.cost or 0) or 0),
    level = level,
    formattedLevel = format(wt.L.LEVEL_FORMAT, level),
    key = key,
    tooltip = entry.description or "",
  }
end

local function chooseCategory(entry, playerLevel, knownSet, talentSet)
  local key = tostring(entry.name or "Unknown") .. "::" .. (entry.rank or "")
  local isKnown = knownSet[key] or entry.trainerState == "used"

  if isKnown then return KNOWN_KEY end

  -- Check ability requirements
  local hasAll = true
  local missingTalent = false
  for _, req in ipairs(entry.abilityReqs or {}) do
    if not req.has then
      hasAll = false
      if req.ability and talentSet[req.ability] then
        missingTalent = true
      end
    end
  end

  local lvl = tonumber(entry.requiredLevel or 0) or 0
  if lvl > playerLevel then
    return (lvl <= playerLevel + 2) and NEXTLEVEL_KEY or NOTLEVEL_KEY
  end

  if not hasAll then
    return missingTalent and MISSINGTALENT_KEY or MISSINGREQS_KEY
  end

  return AVAILABLE_KEY
end

local function byLevelThenName(a, b)
  if a.level == b.level then return a.name < b.name end
  return a.level < b.level
end
local function byNameThenLevel(a, b)
  if a.name == b.name then return a.level < b.level end
  return a.name < b.name
end

function wt.RebuildData()
  categories:ClearSpells()
  wipe(wt.data)

  -- reset totals
  wt.totals.hasData = false
  wt.totals.availableCost = 0
  wt.totals.availableCount = 0

  local all = wt.DB_All()
  local hasAny = false
  for _ in pairs(all) do hasAny = true; break end

  if not hasAny then
    -- Show a friendly message inside the tab when no data yet
    wt.data = {
      { isHeader = true, formattedName = HIGHLIGHT_FONT_COLOR_CODE .. wt.L.NO_DATA_TITLE .. FONT_COLOR_CODE_CLOSE },
      { name = wt.L.NO_DATA_BODY, formattedSubText = "", icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        cost = 0, formattedCost = "", level = 0, formattedLevel = "", isHeader = false, click = nil, levelColor = { r=1,g=1,b=1 } },
    }
    if type(wt.UpdateTotals) == "function" then wt.UpdateTotals() end
    return
  end

  local playerLevel = UnitLevel("player") or 1
  local knownSet = wt.GetKnownNameRankSet()
  local talentSet = wt.GetTalentNameSet()

  for _, entry in pairs(all) do
    local catKey = chooseCategory(entry, playerLevel, knownSet, talentSet)
    local row = toSpellRow(catKey, entry)
    categories:Insert(catKey, row)
  end

  local availableCost = 0
  local availableCount = 0

  -- Emit headers and rows with totals
  for _, cat in ipairs(categories) do
    if #cat.spells > 0 then
      table.insert(wt.data, cat)
      local sorter = cat.nameSort and byNameThenLevel or byLevelThenName
      table.sort(cat.spells, sorter)
      local total = 0
      for _, s in ipairs(cat.spells) do
        s.levelColor = GetQuestDifficultyColor(s.level)
        s.hideLevel = cat.hideLevel
        total = total + (s.cost or 0)
        table.insert(wt.data, s)
      end
      cat.cost = total
      if cat.key == AVAILABLE_KEY then
        availableCost = total
        availableCount = #cat.spells
      end
    end
  end

  wt.totals.hasData = true
  wt.totals.availableCost = availableCost
  wt.totals.availableCount = availableCount

  if type(wt.UpdateTotals) == "function" then wt.UpdateTotals() end
end

-- Events to keep view updated
local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_LEVEL_UP")
ef:RegisterEvent("LEARNED_SPELL_IN_TAB")
ef:RegisterEvent("QUEST_TURNED_IN") -- optional: catch level-ups from turn-ins
ef:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    wt.RebuildData()
    if type(wt.CreateFrame) == "function" then wt.CreateFrame() end
  elseif event == "PLAYER_LEVEL_UP" or event == "LEARNED_SPELL_IN_TAB" or event == "QUEST_TURNED_IN" then
    wt.RebuildData()
    if wt.MainFrame and wt.MainFrame:IsVisible() and type(wt.Update) == "function" then
      wt.Update(wt.MainFrame, true)
    end
  end
end)