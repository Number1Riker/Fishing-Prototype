local Behavior = {}

-- util
local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function chooseDir()
	return math.random(0, 1) == 0 and -1 or 1
end

local function startFullPass(state)
	local zone = state.Zones[1]
	if not zone then return end

	state.Mode = "Pass"
	state.Dir = chooseDir()

	if state.Dir == 1 then
		zone.Center = -zone.Width
	else
		zone.Center = 1 + zone.Width
	end
end

local function startFakeout(state)
	local zone = state.Zones[1]
	if not zone then return end

	state.Mode = "FakeIn"
	state.Dir = chooseDir()

	if state.Dir == 1 then
		zone.Center = -zone.Width
	else
		zone.Center = 1 + zone.Width
	end

	local fakeDepth = state.FakeoutDepth or 0.18
	if state.Dir == 1 then
		state.FakeTarget = fakeDepth
	else
		state.FakeTarget = 1 - fakeDepth
	end
end

-- init
function Behavior:Init(state)
	local cfg = state.MinigameConfig or {}

	local width = tonumber(cfg.ZoneWidth) or state.ZoneWidth or 0.22
	width = clamp(width, 0.05, 0.7)

	state.PassSpeed = tonumber(cfg.PassSpeed) or 0.5
	state.FakeoutSpeed = tonumber(cfg.FakeoutSpeed) or 0.75
	state.PassDelay = tonumber(cfg.PassDelay) or 0.45
	state.FakeoutChance = tonumber(cfg.FakeoutChance) or 0.3
	state.FakeoutDepth = tonumber(cfg.FakeoutDepth) or 0.18

	state.Mode = "Wait"
	state.WaitTimer = 0
	state.Dir = 1
	state.FakeTarget = 0.2

	state.Zones = {
		{
			Center = -width,
			Width = width,
		}
	}

	startFullPass(state)
end

-- step
function Behavior:Step(state, dt)
	local zone = state.Zones[1]
	if not zone then return end

	if state.Mode == "Pass" then
		zone.Center += state.Dir * state.PassSpeed * dt

		if state.Dir == 1 and zone.Center >= (1 + zone.Width) then
			state.Mode = "Wait"
			state.WaitTimer = state.PassDelay
		elseif state.Dir == -1 and zone.Center <= -zone.Width then
			state.Mode = "Wait"
			state.WaitTimer = state.PassDelay
		end

	elseif state.Mode == "FakeIn" then
		zone.Center += state.Dir * state.FakeoutSpeed * dt

		if state.Dir == 1 then
			if zone.Center >= state.FakeTarget then
				state.Mode = "FakeOut"
			end
		else
			if zone.Center <= state.FakeTarget then
				state.Mode = "FakeOut"
			end
		end

	elseif state.Mode == "FakeOut" then
		zone.Center -= state.Dir * state.FakeoutSpeed * dt

		if state.Dir == 1 and zone.Center <= -zone.Width then
			state.Mode = "Wait"
			state.WaitTimer = state.PassDelay
		elseif state.Dir == -1 and zone.Center >= (1 + zone.Width) then
			state.Mode = "Wait"
			state.WaitTimer = state.PassDelay
		end

	elseif state.Mode == "Wait" then
		state.WaitTimer -= dt

		if state.WaitTimer <= 0 then
			if math.random() < state.FakeoutChance then
				startFakeout(state)
			else
				startFullPass(state)
			end
		end
	end
end

-- click
function Behavior:OnClick(state, cursorX, hit)
end

return Behavior