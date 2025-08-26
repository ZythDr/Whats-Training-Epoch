-- Trainer scanner: builds normalized entries from Blizzard trainer API
local _, wt = ...

wt.debug = wt.debug or false

-- Account-wide settings (toggle for tab icon)
WT_EpochAccountDB = WT_EpochAccountDB or {}

local function dprint(...)
  if not wt.debug then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[WT:Epoch]|r " .. table.concat({tostringall(...)}, " "))
end

local tip = CreateFrame("GameTooltip", "WT_EpochTrainerTip", UIParent, "GameTooltipTemplate")
tip:SetOwner(UIParent, "ANCHOR_NONE")

local function StripReq(text)
  if not text or text == "" then return nil end
  if text:match("^Requires") then return nil end
  if text:match("^Cost") then return nil end
  if text:match("^You must") then return nil end
  if text:match("^Already known") then return nil end
  return text
end

local function ReadDescription(index)
  local desc = GetTrainerServiceDescription and GetTrainerServiceDescription(index)
  if desc and desc ~= "" then return desc end
  tip:ClearLines()
  if tip.SetTrainerService then
    tip:SetTrainerService(index)
    local out = {}
    for i = 3, tip:NumLines() do
      local fs = _G["WT_EpochTrainerTipTextLeft" .. i]
      local txt = fs and fs:GetText()
      txt = StripReq(txt)
      if txt then table.insert(out, txt) end
    end
    return table.concat(out, "\n")
  end
  return ""
end

-- More robust spellID resolution:
-- 1) Try tooltip:GetSpell()
-- 2) Fallback: GetSpellLink by name (+ rank) and parse the ID from the link
local function ResolveSpellID(index)
  if tip and tip.SetTrainerService and tip.GetSpell then
    tip:ClearLines()
    tip:SetTrainerService(index)
    local _, _, spellID = tip:GetSpell()
    if spellID and tonumber(spellID) then
      return tonumber(spellID)
    end
  end
  if GetTrainerServiceInfo and GetSpellLink then
    local name, rank = GetTrainerServiceInfo(index)
    if name and name ~= "" then
      local query = name
      if rank and rank ~= "" then
        query = name .. " (" .. rank .. ")"
      end
      local link = GetSpellLink(query)
      if link then
        local id = tonumber(link:match("Hspell:(%d+)"))
        if id then return id end
      end
    end
  end
  return nil
end

local function ResolveIcon(name, rank, index, spellID)
  if spellID and type(GetSpellTexture) == "function" then
    local tex = GetSpellTexture(spellID)
    if tex then return tex end
  end
  if type(GetTrainerServiceIcon) == "function" then
    local tex = GetTrainerServiceIcon(index)
    if tex then return tex end
  end
  if name and name ~= "" then
    local _, _, tex = GetSpellInfo(name)
    if tex then return tex end
    if rank and rank ~= "" then
      local _, _, tex2 = GetSpellInfo(name .. " (" .. rank .. ")")
      if tex2 then return tex2 end
      local _, _, tex3 = GetSpellInfo(name .. "(" .. rank .. ")")
      if tex3 then return tex3 end
    end
  end
  return wt.GetBestIconFor and wt.GetBestIconFor(name, rank) or nil
end

local function toint(v) return (v == 1 or v == true) and 1 or 0 end

local function GetTrainerSelectionIndexCompat()
  if type(GetTrainerSelectionIndex) == "function" then return GetTrainerSelectionIndex() end
  if type(GetTrainerSelection) == "function" then return GetTrainerSelection() end
  return nil
end
local function SetTrainerSelectionCompat(i)
  if type(SetTrainerSelection) == "function" and i then
    pcall(SetTrainerSelection, i)
  end
end
local function GetTrainerScrollFrame()
  return _G.ClassTrainerListScrollFrame or _G.TrainerFrameScrollFrame
end
local function SaveTrainerUIState()
  local sel = GetTrainerSelectionIndexCompat()
  local sf = GetTrainerScrollFrame()
  local off = sf and FauxScrollFrame_GetOffset(sf) or nil
  return sel, off
end
local function RestoreTrainerUIState(sel, off)
  SetTrainerSelectionCompat(sel)
  local sf = GetTrainerScrollFrame()
  if sf and off then
    FauxScrollFrame_SetOffset(sf, off)
    if type(ClassTrainerFrame_Update) == "function" then
      ClassTrainerFrame_Update()
    elseif type(TrainerFrame_Update) == "function" then
      TrainerFrame_Update()
    end
  end
end

local function withAllFilters(fn)
  if not GetTrainerServiceTypeFilter or not SetTrainerServiceTypeFilter then
    return fn()
  end
  local avail = toint(GetTrainerServiceTypeFilter("available"))
  local unavl = toint(GetTrainerServiceTypeFilter("unavailable"))
  local used  = toint(GetTrainerServiceTypeFilter("used"))

  local needFlip = not (avail == 1 and unavl == 1 and used == 1)

  local sel, off
  if needFlip then
    sel, off = SaveTrainerUIState()
    SetTrainerServiceTypeFilter("available",   1)
    SetTrainerServiceTypeFilter("unavailable", 1)
    SetTrainerServiceTypeFilter("used",        1)
  end

  local ok, res = pcall(fn)

  if needFlip then
    SetTrainerServiceTypeFilter("available",   avail)
    SetTrainerServiceTypeFilter("unavailable", unavl)
    SetTrainerServiceTypeFilter("used",        used)
    RestoreTrainerUIState(sel, off)
  end

  if not ok then error(res) end
  return res
end

local function IsProfessionTrainer()
  if not IsTradeskillTrainer then return false end
  local ok = IsTradeskillTrainer()
  return ok == true or ok == 1
end

local function ScanTrainerOnce()
  if IsProfessionTrainer() then
    dprint("Skipping profession trainer scan (profession trainer detected).")
    return {}
  end
  return withAllFilters(function()
    local results = {}
    local n = (GetNumTrainerServices and GetNumTrainerServices()) or 0
    dprint("Scanning trainer (one-time), services:", n)
    for i = 1, n do
      local name, rank, serviceType = GetTrainerServiceInfo(i)
      if name and name ~= "" and serviceType ~= "header" then
        local id = ResolveSpellID(i)
        local description = ReadDescription(i)
        local reqLevel = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
        local moneyCost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0

        local abilityReqs = {}
        local numReqs = GetTrainerServiceNumAbilityReq and (GetTrainerServiceNumAbilityReq(i) or 0) or 0
        for r = 1, numReqs do
          if GetTrainerServiceAbilityReq then
            local ability, has = GetTrainerServiceAbilityReq(i, r)
            abilityReqs[#abilityReqs + 1] = { ability = ability, has = has and true or false }
          end
        end

        results[#results + 1] = {
          id = id,
          name = name,
          rank = rank,
          description = description,
          requiredLevel = reqLevel,
          cost = moneyCost,
          abilityReqs = abilityReqs,
          trainerState = serviceType,
          icon = (ResolveIcon and ResolveIcon(name, rank, i, id)) or nil,
        }
      end
    end
    dprint("Scan complete, rows:", #results)
    return results
  end)
end

-- ===== Tab icon (What's Training? spellbook tab) =====

local ICON_ZOOM = 1.25

-- Helper: apply a zoom to a texcoord rectangle (left/right/top/bottom in [0,1])
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

-- Set the WT tab icon to either "?" or the player's class icon (atlas + texcoords), with a fixed 1.3x crop
local function ApplyWTTabIcon()
  -- WT uses MAX_SKILLLINE_TABS - 1 for its custom tab (as defined in UI.lua)
  local tabIndex = (MAX_SKILLLINE_TABS and (MAX_SKILLLINE_TABS - 1)) or 4
  local tab = _G["SpellBookSkillLineTab" .. tabIndex]
  if not tab then return end

  -- Ensure a normal texture exists
  if not tab:GetNormalTexture() then
    tab:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  end
  local tex = tab:GetNormalTexture()
  if not tex then return end

  local useClass = WT_EpochAccountDB and WT_EpochAccountDB.useClassTabIcon
  if useClass then
    local classToken = select(2, UnitClass("player"))
    if CLASS_ICON_TCOORDS and classToken and CLASS_ICON_TCOORDS[classToken] then
      local c = CLASS_ICON_TCOORDS[classToken] -- {left, right, top, bottom}
      tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
      SetZoomedTexCoord(tex, c[1], c[2], c[3], c[4], ICON_ZOOM)
      return
    end
  end

  -- Fallback: question mark
  tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  SetZoomedTexCoord(tex, 0, 1, 0, 1, ICON_ZOOM)
end

-- Re-apply next frame to win against other hooks that may set the icon
local function ApplyWTTabIconNextFrame()
  local fr = CreateFrame("Frame")
  fr:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    ApplyWTTabIcon()
  end)
end

-- Keep the icon correct whenever the spellbook updates
if type(hooksecurefunc) == "function" and type(SpellBookFrame_Update) == "function" then
  hooksecurefunc("SpellBookFrame_Update", function()
    ApplyWTTabIcon()
    ApplyWTTabIconNextFrame()
  end)
end

-- ===== End: Tab icon =====

-- Debounced timer
local throttle = CreateFrame("Frame", "WT_EpochTrainerScanOnceThrottle")
throttle:Hide()
local delay, cb = 0, nil
throttle:SetScript("OnUpdate", function(self, elapsed)
  delay = delay - elapsed
  if delay <= 0 then
    self:Hide()
    local f = cb; cb = nil
    if f then f() end
  end
end)
local function ScheduleOnce(sec, fn)
  if throttle:IsShown() then return end
  delay, cb = sec or 0.3, fn
  throttle:Show()
end

-- Session state: only scan once per open trainer
wt._trainerOpen = wt._trainerOpen or false
wt._trainerScannedThisSession = wt._trainerScannedThisSession or false

local function DoInitialScan()
  if wt._trainerScannedThisSession then
    dprint("Already scanned this trainer session; skipping.")
    return
  end
  local entries = ScanTrainerOnce()
  if wt.DB_StoreScan then wt.DB_StoreScan(entries) end
  wt._trainerScannedThisSession = true
  if type(wt.RebuildData) == "function" then
    wt.RebuildData()
    if wt.MainFrame and wt.MainFrame:IsVisible() and type(wt.Update) == "function" then
      wt.Update(wt.MainFrame, true)
    end
  end
end

-- Events
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TRAINER_SHOW")
f:RegisterEvent("TRAINER_UPDATE")
f:RegisterEvent("TRAINER_CLOSED")
f:SetScript("OnEvent", function(_, event)
  dprint("Event:", event)
  if event == "PLAYER_LOGIN" then
    -- nothing required
  elseif event == "TRAINER_SHOW" then
    wt._trainerOpen = true
    wt._trainerScannedThisSession = false
    ScheduleOnce(0.35, DoInitialScan)
  elseif event == "TRAINER_UPDATE" then
    if wt._trainerOpen and not wt._trainerScannedThisSession then
      ScheduleOnce(0.25, DoInitialScan)
    end
  elseif event == "TRAINER_CLOSED" then
    wt._trainerOpen = false
    wt._trainerScannedThisSession = false
  end
end)

-- Slash helpers: /wte debug | /wte scan | /wte reset | /wte test | /wte icon
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
    local ok, err = pcall(function()
      DoInitialScan()
    end)
    if not ok then
      print("|cff66ccff[WT:Epoch]|r scan error:", tostring(err))
    end

  elseif msg == "reset" then
    if type(wt.DB_Reset) == "function" then
      wt.DB_Reset()
    else
      WT_EpochCharDB = { version = 1, spells = {} }
    end
    wt._iconCache = nil
    wt._trainerScannedThisSession = false
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
    -- Account-wide toggle for tab icon
    WT_EpochAccountDB = WT_EpochAccountDB or {}
    WT_EpochAccountDB.useClassTabIcon = not WT_EpochAccountDB.useClassTabIcon
    print("|cff66ccff[WT:Epoch]|r Tab icon (account-wide):", WT_EpochAccountDB.useClassTabIcon and "Class icon" or "Question mark")

    -- Apply immediately and refresh spellbook once; also re-apply next frame
    ApplyWTTabIcon()
    ApplyWTTabIconNextFrame()
    if type(SpellBookFrame_Update) == "function" then
      SpellBookFrame_Update()
    end

  else
    print("|cff66ccff[WT:Epoch]|r commands: debug | scan | reset | test | icon")
  end
end
