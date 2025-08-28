-- Announce newly available spells in chat when the player levels up
local _, wt = ...

-- Disable trainer-open testing; use /wte test instead
local TEST_ANNOUNCE_ON_TRAINER = false

-- Show a summary automatically after logging in, after this many seconds.
-- Set to 0 to disable.
local ANNOUNCE_ON_LOGIN_DELAY_SEC = 10

-- Limit how many spells are printed in chat per summary
local MAX_ANNOUNCE_SPELLS = 6

-- Chat header color for "What's Training?"
--   "|cffffd200" -- WoW UI gold
--   "|cffffff00" -- bright yellow
--   "|cff99ff66" -- yellowish green (old default)
local WT_HEADER_COLOR = "|cffffd200"

-- Build a stable key for a spell row (prefer id; otherwise name+rank)
local function SpellKey(s)
  if s and s.id then return "id:" .. tostring(s.id) end
  local name = s and s.name or ""
  local sub = (s and (s.rank or s.formattedSubText)) or ""
  return "nm:" .. name .. "::" .. sub
end

-- Extract the "Available now" rows from wt.data and return:
-- set: { key => true, ... }
-- list: array of row tables (with ._key prefilled for convenience)
local function BuildAvailableSetAndList()
  local set, list = {}, {}
  local data = wt and wt.data or {}
  for _, row in ipairs(data) do
    if row and not row.isHeader and (row.key == "available" or row.trainerState == "available") then
      local key = SpellKey(row)
      row._key = key
      set[key] = true
      table.insert(list, row)
    end
  end
  return set, list
end

-- Make a clickable spell link when we can; otherwise a plain label
-- Appends the rank text (e.g., "(Rank 2)") after the link/name.
local function SpellDisplay(row)
  -- Build "(Rank X)" if available, using formattedSubText first
  local rankText = ""
  if row then
    rankText = row.formattedSubText or ""
    if (not rankText or rankText == "") and row.rank and row.rank ~= "" then
      if string.sub(row.rank, 1, 1) == "(" then
        rankText = row.rank
      else
        rankText = "(" .. row.rank .. ")"
      end
    end
  end
  local suffix = (rankText and rankText ~= "") and (" " .. rankText) or ""

  local id = row and row.id
  if id then
    -- Prime cache to improve GetSpellLink reliability
    local name = GetSpellInfo(id) or row.name or "Unknown"
    if GetSpellLink then
      local link = GetSpellLink(id)
      if link then return link .. suffix end
    end
    -- fallback manual hyperlink if needed
    return string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r%s", id, name, suffix)
  end

  local name = row and row.name or "Unknown"
  return name .. suffix
end

-- Print each line via its own AddMessage to keep chat entries compact
  -- Prefer the GUI’s total so chat matches exactly
local function AnnounceNewlyAvailable(rows, cf)
  local totalAll = (wt.totals and wt.totals.availableCost) or 0
  if not totalAll or totalAll <= 0 then
    -- Fallback: sum the rows (e.g., if totals aren’t available yet)
    for _, r in ipairs(rows) do
      totalAll = totalAll + (tonumber(r.cost) or 0)
    end
  end
  local costLine = "Total cost: " .. GetCoinTextureString(totalAll)

  -- Sum total cost across all available rows (not just shown ones)
  local total = 0
  for _, r in ipairs(rows) do
    total = total + (tonumber(r.cost) or 0)
  end

  local header1 = WT_HEADER_COLOR .. "What's Training?" .. FONT_COLOR_CODE_CLOSE
  local header2 = "Now available at class trainer:"
  local costLine = "Total cost: " .. GetCoinTextureString(total)

  local shown = math.min(MAX_ANNOUNCE_SPELLS or 6, #rows)
  local function out(s)
    if cf and cf.AddMessage then cf:AddMessage(s) else print(s) end
  end

  out(header1)
  out(header2)
  for i = 1, shown do
    out(SpellDisplay(rows[i]))
  end
  if #rows > shown then
    out(string.format("And %d more. Open What's Training? to see the full list.", #rows - shown))
  end
  out(costLine)
end

-- Update the baseline set to reflect current data (call after any RebuildData)
function wt.SyncAvailableSet()
  local set = BuildAvailableSetAndList()
  wt._availableSet = set -- only need the map; list not stored
end

-- Public: on-demand test summary (/wte test)
function wt.TestAnnounce()
  -- If there is no cached trainer data, tell the user and exit.
  local all = wt.DB_All and wt.DB_All() or {}
  local hasAny = false
  for _ in pairs(all) do hasAny = true; break end
  if not hasAny then
    print(WT_HEADER_COLOR .. "What's Training?" .. FONT_COLOR_CODE_CLOSE .. " This command only works if you have cached spells available at your class trainer.")
    return
  end

  if type(wt.RebuildData) == "function" then
    wt.RebuildData()
  end
  local newMap, newList = BuildAvailableSetAndList()
  if not newList or #newList == 0 then
    print(WT_HEADER_COLOR .. "What's Training?" .. FONT_COLOR_CODE_CLOSE .. " No 'Available now' spells found in your cache.")
    return
  end

  AnnounceNewlyAvailable(newList)
  -- Keep baseline in sync to avoid flooding on next level-up if desired
  wt._availableSet = newMap
end

-- Silent login announce: only shows a summary if cache exists and there are "Available now" rows.
function wt.AnnounceOnLogin()
  local all = wt.DB_All and wt.DB_All() or {}
  local hasAny = false
  for _ in pairs(all) do hasAny = true; break end
  if not hasAny then return end

  if type(wt.RebuildData) == "function" then
    wt.RebuildData()
  end
  local newMap, newList = BuildAvailableSetAndList()
  if newList and #newList > 0 then
    AnnounceNewlyAvailable(newList)
    wt._availableSet = newMap
  end
end

-- Wrap wt.RebuildData so any time your data changes we keep the baseline in sync
local function TryWrapRebuild()
  if wt._rebuildWrapped then return end
  if type(wt.RebuildData) == "function" then
    local orig = wt.RebuildData
    wt.RebuildData = function(...)
      local r = orig(...)
      wt.SyncAvailableSet()
      return r
    end
    wt._rebuildWrapped = true
  end
end

-- Simple one-shot scheduler (3.3.5 compatible)
local function ScheduleOnce(sec, fn)
  local fr = CreateFrame("Frame")
  local t = sec or 0.3
  fr:SetScript("OnUpdate", function(self, e)
    t = t - e
    if t <= 0 then
      self:SetScript("OnUpdate", nil)
      fn()
    end
  end)
end

-- Events
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LEVEL_UP")
if TEST_ANNOUNCE_ON_TRAINER then
  f:RegisterEvent("TRAINER_SHOW") -- TEMP for formatting tests (disabled by default)
end

f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    TryWrapRebuild()
    -- Initialize baseline from current data (if any); this prevents the
    -- first level-up from dumping all currently-available spells as "new".
    if type(wt.RebuildData) == "function" then
      wt.RebuildData()
    else
      wt.SyncAvailableSet()
    end

    -- Schedule a delayed summary on login (silent if no cache or nothing available)
    if (ANNOUNCE_ON_LOGIN_DELAY_SEC or 0) > 0 then
      ScheduleOnce(ANNOUNCE_ON_LOGIN_DELAY_SEC, function()
        if type(wt.AnnounceOnLogin) == "function" then
          wt.AnnounceOnLogin()
        end
      end)
    end

  elseif event == "PLAYER_LEVEL_UP" then
    -- Compute diff: what became available that wasn't available before
    local old = wt._availableSet or {}
    if type(wt.RebuildData) == "function" then
      wt.RebuildData()
    end
    local newMap, newList = BuildAvailableSetAndList()
    wt._availableSet = newMap

    -- If there are any available spells, print summary; otherwise, print nothing
    ScheduleOnce(1.0, function()
      if newList and #newList > 0 then
        AnnounceNewlyAvailable(newList)
      end
    end)

  elseif event == "TRAINER_SHOW" and TEST_ANNOUNCE_ON_TRAINER then
    -- TEMP: Announce everything currently available a short moment after opening the trainer
    ScheduleOnce(0.45, function()
      if type(wt.RebuildData) == "function" then
        wt.RebuildData()
      end
      local newMap, newList = BuildAvailableSetAndList()
      AnnounceNewlyAvailable(newList)
      wt._availableSet = newMap
    end)
  end
end)

-- In case this file loads before RebuildData is defined, do a short-lived poll to wrap it.
local poll = CreateFrame("Frame")
local timeout, elapsed = 5, 0
poll:SetScript("OnUpdate", function(self, e)
  elapsed = elapsed + e
  TryWrapRebuild()
  if wt._rebuildWrapped or elapsed > timeout then
    self:SetScript("OnUpdate", nil)
  end
end)
