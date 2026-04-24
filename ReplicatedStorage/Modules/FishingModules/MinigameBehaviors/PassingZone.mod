local Behavior = {}

-- util
local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function SpawnPass(state)
	local zone = state.Zones[1]
	if not zone then return end

	zone.Width = state.PassWidth

	state.PassDir = math.random(0, 1) == 0 and -1 or 1

	if state.PassDir == 1 then
		zone.Center = -zone.Width
	else
		zone.Center = 1 + zone.Width
	end

	state.PassActive = true
end

-- init
function Behavior:Init(state)
	local cfg = state.MinigameConfig or {}

	state.PassWidth = tonumber(cfg.ZoneWidth) or state.ZoneWidth or 0.14
	state.PassWidth = clamp(state.PassWidth, 0.03, 0.6)

	state.PassSpeed = tonumber(cfg.PassSpeed) or 1.1
	state.PassDelay = tonumber(cfg.PassDelay) or 0.25
	state.PassWait = 0
	state.PassActive = false
	state.PassDir = 1

	state.Zones = {
		{
			Center = -state.PassWidth,
			Width = state.PassWidth,
		}
	}

	SpawnPass(state)
end

-- step
function Behavior:Step(state, dt)
	local zone = state.Zones[1]
	if not zone then return end

	if state.PassActive then
		zone.Center += state.PassDir * state.PassSpeed * dt

		if state.PassDir == 1 and zone.Center >= (1 + zone.Width) then
			state.PassActive = false
			state.PassWait = state.PassDelay
		elseif state.PassDir == -1 and zone.Center <= -zone.Width then
			state.PassActive = false
			state.PassWait = state.PassDelay
		end
	else
		state.PassWait -= dt
		if state.PassWait <= 0 then
			SpawnPass(state)
		end
	end
end

-- click
function Behavior:OnClick(state, cursorX, hit)
end

return Behavior