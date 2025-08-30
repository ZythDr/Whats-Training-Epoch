-- Per-character database and accessors
local _, wt = ...

WT_EpochCharDB = WT_EpochCharDB or {
  version = 1,
  spells = {}, -- key: "name::rank" => entry
}

-- Public: replace/merge with latest scanned snapshot (class trainer only)
function wt.DB_StoreScan(entries)
  if type(entries) ~= "table" then return end
  for _, e in ipairs(entries) do
    local key = tostring(e.name or "UNKNOWN") .. "::" .. (e.rank or "")
    WT_EpochCharDB.spells[key] = {
      id = tonumber(e.id),              -- persist spellID for real links
      name = e.name,
      rank = e.rank,
      description = e.description or "",
      requiredLevel = tonumber(e.requiredLevel) or 0,
      cost = tonumber(e.cost) or 0,
      abilityReqs = e.abilityReqs or {}, -- { { ability="X", has=true/false }, ... }
      trainerState = e.trainerState,     -- "available" | "unavailable" | "used"
      icon = e.icon,                     -- persist resolved icon if we found one
      scannedAt = time(),
    }
  end
end

-- Public: get all spells map (may be empty)
function wt.DB_All()
  return WT_EpochCharDB.spells or {}
end

-- Public: reset the per-character DB completely
function wt.DB_Reset()
  WT_EpochCharDB = {
    version = 1,
    spells = {},
  }
end
