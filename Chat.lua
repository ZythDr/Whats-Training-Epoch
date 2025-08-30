-- Chat/Announcements: slash commands and automatic summaries
local _, wt = ...

-- Disable trainer-open testing; use /wte test instead
local TEST_ANNOUNCE_ON_TRAINER = false

-- Show a summary automatically after logging in, after this many seconds.
-- Set to 0 to disable the delayed login summary (still gated by account toggles)
local ANNOUNCE_ON_LOGIN_DELAY_SEC = 10

-- Limit how many spells are printed in chat per summary
local MAX_ANNOUNCE_SPELLS = 6

-- Chat header color for "What's Training?"
local WT_HEADER_COLOR = "|cffffd200"

-- Ensure account settings container exists and defaults for per-event toggles.
WT_EpochAccountDB = WT_EpochAccountDB or {}
if WT_EpochAccountDB.summaryOnLogin == nil then WT_EpochAccountDB.summaryOnLogin = true end
if WT_EpochAccountDB.summaryOnLevel == nil then WT_EpochAccountDB.summaryOnLevel = true end

-- Backward compatibility: migrate legacy summaryMode => two toggles
local function MigrateLegacySummaryModeIfNeeded()
  local mode = WT_EpochAccountDB and WT_EpochAccountDB.summaryMode or nil
  if not mode then return end
  if WT_EpochAccountDB._migratedSummaryMode then return end

  local loginOn, levelOn = true, true
  if mode == "all" then
    loginOn, levelOn = true, true
  elseif mode == "none" then
    loginOn, levelOn = false, false
  elseif mode == "ding" then
    loginOn, levelOn = false, true
  elseif mode == "login" then
    loginOn, levelOn = true, false
  end
  WT_EpochAccountDB.summaryOnLogin = loginOn
  WT_EpochAccountDB.summaryOnLevel = levelOn

  -- Mark migrated; keep the key around in case user downgrades
  WT_EpochAccountDB._migratedSummaryMode = true
end

local function SummaryAllowsLogin()
  return WT_EpochAccountDB and WT_EpochAccountDB.summaryOnLogin == true
end
local function SummaryAllowsLevel()
  return WT_EpochAccountDB and WT_EpochAccountDB.summaryOnLevel == true
end

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

-- Make a clickable spell link when we can; otherwise a plain label.
-- Appends the rank text (e.g., "(Rank 2)") after the link/name.
local function SpellDisplay(row)
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
    local name = GetSpellInfo(id) or row.name or "Unknown"
    if GetSpellLink then
      local link = GetSpellLink(id)
      if link then return link .. suffix end
    end
    return string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r%s", id, name, suffix)
  end

  local name = row and row.name or "Unknown"
  return name .. suffix
end

-- Print each line via its own AddMessage to keep chat entries compact
local function AnnounceNewlyAvailable(rows, cf)
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

-- Events for announcements
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LEVEL_UP")
if TEST_ANNOUNCE_ON_TRAINER then
  f:RegisterEvent("TRAINER_SHOW") -- TEMP for formatting tests (disabled by default)
end

f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    MigrateLegacySummaryModeIfNeeded()
    TryWrapRebuild()

    -- Initialize baseline from current data (if any); this prevents the
    -- first level-up from dumping all currently-available spells as "new".
    if type(wt.RebuildData) == "function" then
      wt.RebuildData()
    else
      wt.SyncAvailableSet()
    end

    -- Schedule a delayed summary on login if the toggle allows it and delay > 0
    if SummaryAllowsLogin() and (ANNOUNCE_ON_LOGIN_DELAY_SEC or 0) > 0 then
      ScheduleOnce(ANNOUNCE_ON_LOGIN_DELAY_SEC, function()
        if type(wt.AnnounceOnLogin) == "function" then
          wt.AnnounceOnLogin()
        end
      end)
    end

  elseif event == "PLAYER_LEVEL_UP" then
    -- Rebuild and compute currently available spells
    if type(wt.RebuildData) == "function" then
      wt.RebuildData()
    end
    local newMap, newList = BuildAvailableSetAndList()
    -- Always update baseline
    wt._availableSet = newMap

    -- Only announce on level-up if toggle allows and there are available spells
    if SummaryAllowsLevel() and newList and #newList > 0 then
      ScheduleOnce(0.5, function()
        AnnounceNewlyAvailable(newList)
      end)
    end

  elseif event == "TRAINER_SHOW" and TEST_ANNOUNCE_ON_TRAINER then
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

-- ===== Slash commands (/wte) =====
local function sanitizeMsg(msg)
  msg = tostring(msg or "")
  msg = string.lower(msg)
  msg = msg:match("^%s*(.-)%s*$") or msg
  return msg
end

SLASH_WTE1 = "/wte"
SlashCmdList["WTE"] = function(msg)
  msg = sanitizeMsg(msg)

  if msg == "debug" then
    wt.debug = not wt.debug
    print("|cff66ccff[WT:Epoch]|r debug =", wt.debug and "ON" or "OFF")

  elseif msg == "scan" then
    if type(wt.ScanTrainerOnceNow) == "function" then
      local ok, err = pcall(function() wt.ScanTrainerOnceNow() end)
      if not ok then print("|cff66ccff[WT:Epoch]|r scan error:", tostring(err)) end
    else
      print("|cff66ccff[WT:Epoch]|r scan unavailable in this build.")
    end

  elseif msg == "reset" then
    if type(wt.DB_Reset) == "function" then wt.DB_Reset() end
    wt._iconCache = nil
    if type(wt.RebuildData) == "function" then wt.RebuildData() end
    if wt.MainFrame and wt.MainFrame:IsVisible() and type(wt.Update) == "function" then
      wt.Update(wt.MainFrame, true)
    end
    print("|cff66ccff[WT:Epoch]|r cache cleared. Visit a class trainer to repopulate.")

  elseif msg == "test" then
    if type(wt.TestAnnounce) == "function" then
      wt.TestAnnounce()
    else
      print("|cff66ccff[WT:Epoch]|r This command only works if you have cached spells available at your class trainer.")
    end

  elseif msg == "icon" then
    local on = wt.ToggleTabIcon and wt.ToggleTabIcon() or false
    print("|cff66ccff[WT:Epoch]|r Tab icon (account-wide):", on and "Class icon" or "Question mark")

  elseif msg:match("^summary") then
    WT_EpochAccountDB = WT_EpochAccountDB or {}
    local arg = msg:match("^summary%s*(.*)$") or ""
    arg = arg:match("%S+") or ""

    if arg == "" then
      print("|cff66ccff[WT:Epoch]|r Summary on login:", (WT_EpochAccountDB.summaryOnLogin and "ON" or "OFF"),
            "level-up:", (WT_EpochAccountDB.summaryOnLevel and "ON" or "OFF"))
    elseif arg == "all" then
      WT_EpochAccountDB.summaryOnLogin = true
      WT_EpochAccountDB.summaryOnLevel = true
      print("|cff66ccff[WT:Epoch]|r Summary enabled for login and level-up.")
    elseif arg == "none" then
      WT_EpochAccountDB.summaryOnLogin = false
      WT_EpochAccountDB.summaryOnLevel = false
      print("|cff66ccff[WT:Epoch]|r Summary disabled for login and level-up.")
    elseif arg == "login" then
      WT_EpochAccountDB.summaryOnLogin = not WT_EpochAccountDB.summaryOnLogin
      print("|cff66ccff[WT:Epoch]|r Summary on login:", WT_EpochAccountDB.summaryOnLogin and "ON" or "OFF")
    elseif arg == "level" then
      WT_EpochAccountDB.summaryOnLevel = not WT_EpochAccountDB.summaryOnLevel
      print("|cff66ccff[WT:Epoch]|r Summary on level-up:", WT_EpochAccountDB.summaryOnLevel and "ON" or "OFF")
    else
      print("|cff66ccff[WT:Epoch]|r summary usage: /wte summary [all|none|level|login]")
    end

  else
    print("|cff66ccff[WT:Epoch]|r commands: debug | scan | reset | test | icon | summary")
  end
end
