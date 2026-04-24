local Behavior = {}

-- util
local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function getRange(cfg, zoneWidth)
	local r = cfg and cfg.MoveRange
	local lo = 0.15
	local hi = 0.85

	if type(r) == "table" then
		lo = tonumber(r.Min) or lo
		hi = tonumber(r.Max) or hi
	end

	local half = (zoneWidth or 0.2) * 0.5
	lo = clamp(lo, half, 1 - half)
	hi = clamp(hi, half, 1 - half)

	if hi <= lo then
		lo = half
		hi = 1 - half
	end

	return lo, hi
end

local function zonesIntersect(aCenter, aWidth, bCenter, bWidth, pad)
	local aHalf = aWidth * 0.5
	local bHalf = bWidth * 0.5
	local aL = aCenter - aHalf - pad
	local aR = aCenter + aHalf + pad
	local bL = bCenter - bHalf
	local bR = bCenter + bHalf
	return not (aR <= bL or aL >= bR)
end

local function pickCenter(cfg, zoneWidth, existingZones, pad)
	local lo, hi = getRange(cfg, zoneWidth)
	pad = pad or 0

	for _ = 1, 40 do
		local c = lo + (hi - lo) * math.random()

		local ok = true
		for _, z in ipairs(existingZones) do
			if zonesIntersect(c, zoneWidth, z.Center, z.Width, pad) then
				ok = false
				break
			end
		end

		if ok then
			return c
		end
	end

	return (lo + hi) * 0.5
end

local function buildZones(cfg)
	local count = tonumber(cfg.ZoneCount) or 1
	count = math.max(1, math.floor(count))

	local width = tonumber(cfg.ZoneWidth) or 0.22
	width = clamp(width, 0.02, 0.95)

	local pad = tonumber(cfg.NonIntersectPadding) or 0

	local zones = {}
	for _ = 1, count do
		local c = pickCenter(cfg, width, zones, pad)
		table.insert(zones, { Center = c, Width = width })
	end

	return zones
end

local function hitZoneIndex(state, cursorX)
	for i, z in ipairs(state.Zones) do
		local half = z.Width * 0.5
		if cursorX >= (z.Center - half) and cursorX <= (z.Center + half) then
			return i
		end
	end
	return nil
end

-- init
function Behavior:Init(state)
	local cfg = state.MinigameConfig or {}
	state.Zones = buildZones(cfg)
end

-- click
function Behavior:OnClick(state, cursorX, hitAny)
	if not hitAny then return end

	local cfg = state.MinigameConfig or {}

	if cfg.ReverseOnHit then
		state.CursorDir *= -1
	end

	local mode = cfg.OnHit or "MoveHitZone"
	local pad = tonumber(cfg.NonIntersectPadding) or 0

	if mode == "MoveAllZones" then
		local newZones = {}
		for _, old in ipairs(state.Zones) do
			local c = pickCenter(cfg, old.Width, newZones, pad)
			table.insert(newZones, { Center = c, Width = old.Width })
		end
		state.Zones = newZones
		return
	end

	local idx = hitZoneIndex(state, cursorX)
	if not idx then return end

	local this = state.Zones[idx]
	local others = {}

	for i, z in ipairs(state.Zones) do
		if i ~= idx then
			table.insert(others, z)
		end
	end

	this.Center = pickCenter(cfg, this.Width, others, pad)
end

-- step
function Behavior:Step(state, dt)
end

return Behavior