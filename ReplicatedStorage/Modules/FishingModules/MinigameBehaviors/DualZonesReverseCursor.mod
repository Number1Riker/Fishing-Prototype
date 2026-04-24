local Behavior = {}

-- util
local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function pickCenter(width, zones, pad)
	local half = width * 0.5
	pad = pad or 0

	for _ = 1, 50 do
		local c = half + (1 - half * 2) * math.random()

		local ok = true
		for _, z in ipairs(zones) do
			local zHalf = z.Width * 0.5
			if math.abs(c - z.Center) < (half + zHalf + pad) then
				ok = false
				break
			end
		end

		if ok then
			return c
		end
	end

	return 0.5
end

local function buildZones(state)
	local cfg = state.MinigameConfig or {}
	local width = tonumber(cfg.ZoneWidth) or state.ZoneWidth or 0.14
	width = clamp(width, 0.03, 0.6)

	local pad = tonumber(cfg.NonIntersectPadding) or 0.02

	local zones = {}
	table.insert(zones, { Center = pickCenter(width, zones, pad), Width = width })
	table.insert(zones, { Center = pickCenter(width, zones, pad), Width = width })
	return zones
end

local function hitIndex(state, cursorX)
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
	state.Zones = buildZones(state)
end

-- click
function Behavior:OnClick(state, cursorX, hitAny)
	if not hitAny then return end

	state.CursorDir *= -1

	local cfg = state.MinigameConfig or {}
	local width = tonumber(cfg.ZoneWidth) or state.ZoneWidth or 0.14
	local pad = tonumber(cfg.NonIntersectPadding) or 0.02

	local idx = hitIndex(state, cursorX)
	if not idx then return end

	local zones = state.Zones

	local keep = {}
	for i, z in ipairs(zones) do
		if i ~= idx then
			table.insert(keep, z)
		end
	end

	zones[idx].Width = width
	zones[idx].Center = pickCenter(width, keep, pad)
end

-- step
function Behavior:Step(state, dt)
end

return Behavior