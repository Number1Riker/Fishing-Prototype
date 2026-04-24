local Behavior = {}

-- util
local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function easeIn(style, t)
	if style == "Sine" then
		return 1 - math.cos((t * math.pi) / 2)
	elseif style == "Quad" then
		return t * t
	elseif style == "Cubic" then
		return t * t * t
	elseif style == "Quart" then
		return t * t * t * t
	elseif style == "Quint" then
		return t * t * t * t * t
	elseif style == "Expo" then
		if t == 0 then return 0 end
		return 2 ^ (10 * (t - 1))
	elseif style == "Back" then
		local c1 = 1.70158
		local c3 = c1 + 1
		return c3 * t * t * t - c1 * t * t
	end
	return t
end

local function easeOut(style, t)
	if style == "Sine" then
		return math.sin((t * math.pi) / 2)
	elseif style == "Quad" then
		return 1 - (1 - t) * (1 - t)
	elseif style == "Cubic" then
		local a = 1 - t
		return 1 - a * a * a
	elseif style == "Quart" then
		local a = 1 - t
		return 1 - a * a * a * a
	elseif style == "Quint" then
		local a = 1 - t
		return 1 - a * a * a * a * a
	elseif style == "Expo" then
		if t == 1 then return 1 end
		return 1 - (2 ^ (-10 * t))
	elseif style == "Back" then
		local c1 = 1.70158
		local c3 = c1 + 1
		local a = t - 1
		return 1 + c3 * a * a * a + c1 * a * a
	end
	return t
end

local function ease(style, dir, t)
	t = clamp(t, 0, 1)

	if dir == "In" then
		return easeIn(style, t)
	elseif dir == "Out" then
		return easeOut(style, t)
	end

	if t < 0.5 then
		return easeIn(style, t * 2) * 0.5
	else
		return 0.5 + easeOut(style, (t - 0.5) * 2) * 0.5
	end
end

local function pingpong01(x)
	-- x grows forever, returns 0->1->0
	local u = x % 2
	if u <= 1 then
		return u
	else
		return 2 - u
	end
end

-- init
function Behavior:Init(state)
	local cfg = state.MinigameConfig or {}

	state.ZoneT = math.random()
	state.ZonePeriod = tonumber(cfg.ZonePeriod) or 2.2
	state.ZoneEaseStyle = tostring(cfg.ZoneEaseStyle or "Sine")
	state.ZoneEaseDirection = tostring(cfg.ZoneEaseDirection or "InOut")

	state.Zones = {
		{ Center = 0.5, Width = state.ZoneWidth }
	}
end

-- step
function Behavior:Step(state, dt)
	local cfg = state.MinigameConfig or {}
	local width = tonumber(cfg.ZoneWidth) or state.ZoneWidth or 0.18
	local half = width * 0.5

	local period = tonumber(cfg.ZonePeriod) or state.ZonePeriod or 2.2
	period = math.max(0.35, period)

	state.ZoneT += dt / (period * 0.5)

	local raw = pingpong01(state.ZoneT)
	local style = tostring(cfg.ZoneEaseStyle or state.ZoneEaseStyle or "Sine")
	local dir = tostring(cfg.ZoneEaseDirection or state.ZoneEaseDirection or "InOut")
	local e = ease(style, dir, raw)

	local minX = half
	local maxX = 1 - half
	local x = minX + (maxX - minX) * e

	state.Zones[1].Center = x
	state.Zones[1].Width = width
end

-- click
function Behavior:OnClick(state, cursorX, hitAny)
end

return Behavior