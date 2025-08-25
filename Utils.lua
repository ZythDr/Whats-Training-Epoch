-- Small helpers and constants (compatible with 3.3.5 variants)
local _, wt = ...

wt.currentClass = select(2, UnitClass("player"))

local BOOKTYPE_SPELL_CONST = _G.BOOKTYPE_SPELL or "spell"

-- Build a set of talent names for current class (used to detect "missing talents")
function wt.GetTalentNameSet()
  local names = {}
  if not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo then return names end
  local tabs = GetNumTalentTabs() or 0
  for t = 1, tabs do
    local num = GetNumTalents(t) or 0
    for i = 1, num do
      local name = GetTalentInfo(t, i)
      if name then names[name] = true end
    end
  end
  return names
end

-- Compatibility: some 3.3.5 forks use GetSpellName instead of GetSpellBookItemName
local function SpellBookNameRank(index)
  if type(GetSpellBookItemName) == "function" then
    return GetSpellBookItemName(index, BOOKTYPE_SPELL_CONST)
  elseif type(GetSpellName) == "function" then
    return GetSpellName(index, BOOKTYPE_SPELL_CONST)
  else
    return nil, nil
  end
end

local function SpellBookItemType(index)
  if type(GetSpellBookItemInfo) == "function" then
    return GetSpellBookItemInfo(index, BOOKTYPE_SPELL_CONST)
  else
    -- No type info available; assume a SPELL if we got a name
    return "SPELL"
  end
end

local function SpellBookItemTexture(index)
  if type(GetSpellBookItemTexture) == "function" then
    return GetSpellBookItemTexture(index, BOOKTYPE_SPELL_CONST)
  elseif type(GetSpellTexture) == "function" then
    return GetSpellTexture(index)
  end
  return nil
end

-- Build a runtime icon cache from the player's spellbook
local function ensureIconCache()
  if wt._iconCache then return wt._iconCache end
  local byKey, byName = {}, {}

  -- Prefer tab-based counting (stable on 3.3.5)
  local total = 0
  if type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" then
    local tabs = GetNumSpellTabs() or 0
    for t = 1, tabs do
      local _, _, offset, numSpells = GetSpellTabInfo(t)
      if offset and numSpells then
        local last = offset + numSpells
        if last > total then total = last end
      end
    end
  end
  if total <= 0 then total = 500 end

  for i = 1, total do
    local name, rank = SpellBookNameRank(i)
    if name then
      local typ = SpellBookItemType(i)
      if typ == "SPELL" or typ == nil then
        local tex = SpellBookItemTexture(i)
        if tex then
          local key = tostring(name) .. "::" .. (rank or "")
          byKey[key] = tex
          if not byName[name] then byName[name] = tex end
        end
      end
    end
  end

  wt._iconCache = { byKey = byKey, byName = byName }
  return wt._iconCache
end

local function tryGetIconByNameRank(name, rank)
  if not name or name == "" then return nil end
  local _, _, tex = GetSpellInfo(name)
  if tex then return tex end
  if rank and rank ~= "" then
    local _, _, t2 = GetSpellInfo(name .. " (" .. rank .. ")")
    if t2 then return t2 end
    local _, _, t3 = GetSpellInfo(name .. "(" .. rank .. ")")
    if t3 then return t3 end
  end
  return nil
end

-- Public: best-effort icon resolution with cache and fallbacks
function wt.GetBestIconFor(name, rank, preIcon)
  if preIcon and preIcon ~= "" then return preIcon end
  local tex = tryGetIconByNameRank(name, rank)
  if tex then return tex end

  local cache = ensureIconCache()
  local key = tostring(name or "") .. "::" .. (rank or "")
  if cache.byKey[key] then return cache.byKey[key] end
  if cache.byName[name] then return cache.byName[name] end

  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Scan the player's spellbook to a set of "name::rank" strings for known spells
function wt.GetKnownNameRankSet()
  local known = {}

  -- Prefer tab-based counting (stable on 3.3.5)
  local total = 0
  if type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" then
    local tabs = GetNumSpellTabs() or 0
    for t = 1, tabs do
      local _, _, offset, numSpells = GetSpellTabInfo(t)
      if offset and numSpells then
        local last = offset + numSpells
        if last > total then total = last end
      end
    end
  end
  if total <= 0 then total = 500 end

  for i = 1, total do
    local name, rank = SpellBookNameRank(i)
    if name then
      local typ = SpellBookItemType(i)
      if typ == "SPELL" or typ == nil then
        local key = tostring(name) .. "::" .. (rank or "")
        known[key] = true
      end
    end
  end

  return known
end