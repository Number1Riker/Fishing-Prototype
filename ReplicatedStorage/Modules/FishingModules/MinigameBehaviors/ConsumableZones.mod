local Behavior = {}

-- util
local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function pickCenter(width, zones, pad)
	local half = width * 0.5

	for _ = 1, 50 do
		local c = half + (1 - half * 2) * math.random()

		local ok = true
		for _, z in ipairs(zones) do
			if z.Active then
				local zHalf = z.Width * 0.5
				if math.abs(c - z.Center) < (half + zHalf + pad) then
					ok = false
					break
				end
			end
		end

		if ok then
			return c
		end
	end

	return 0.5
end

local function spawnSet(state)
	local cfg = state.MinigameConfig or {}

	local count = tonumber(cfg.ZoneCount) or 5
	count = math.max(1, math.floor(count))

	local width = tonumber(cfg.ZoneWidth) or (state.ZoneWidth or 0.12)
	width = clamp(width, 0.03, 0.5)

	local pad = tonumber(cfg.NonIntersectPadding) or 0.02

	local zones = {}
	for _ = 1, count do
		table.insert(zones, {
			Center = pickCenter(width, zones, pad),
			Width = width,
			Active = true,
		})
	end

	state.Zones = zones
end

local function getHitIndex(state, cursorX)
	for i, z in ipairs(state.Zones) do
		if z.Active then
			local half = z.Width * 0.5
			if cursorX >= (z.Center - half) and cursorX <= (z.Center + half) then
				return i
			end
		end
	end
	return nil
end

local function allUsed(state)
	for _, z in ipairs(state.Zones) do
		if z.Active then
			return false
		end
	end
	return true
end

-- init
function Behavior:Init(state)
	spawnSet(state)
end

-- click
function Behavior:OnClick(state, cursorX, hitAny)
	if not hitAny then return end

	local idx = getHitIndex(state, cursorX)
	if not idx then return end

	local z = state.Zones[idx]
	z.Active = false
	z.Width = 0.0001

	if allUsed(state) then
		spawnSet(state)
	end
end

-- step
function Behavior:Step(state, dt)
end

return Behavior