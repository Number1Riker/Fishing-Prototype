local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local RP = game.ReplicatedStorage
local Events = RP:WaitForChild("Events")
local FishingEvents = Events:WaitForChild("FishingEvents")

local FishModules = RP:WaitForChild("Modules"):WaitForChild("FishingModules")
local FishData = require(FishModules:WaitForChild("FishData"))
local BehaviorsFolder = FishModules:WaitForChild("MinigameBehaviors")

local FishingClient = {}

-- util
local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

-- zone anim
local ZONE_EPS = 1e-4
local ZONE_CLOSE_TIME = 0.07 -- how fast old zone closes
local ZONE_OPEN_TIME = 0.07 -- how fast new zone opens
local ZONE_RESIZE_TIME = 0.06 -- how fast zone resizes

-- bar speed
local BAR_RISE_TIME = 0.08 -- how fast bar goes up
local BAR_FALL_TIME = 0.05 -- how fast bar goes down

-- bar flash
local BAR_FLASH_UP_TIME = 0.04 -- how fast it brightens
local BAR_FLASH_DOWN_TIME = 0.08 -- how fast it goes back to normal
local BAR_FLASH_BRIGHTEN = 0.35 -- how bright it gets

-- zone flash
local ZONE_FLASH_UP_TIME = 0.03 -- how fast zone flashes on hit
local ZONE_FLASH_DOWN_TIME = 0.08 -- how fast it fades back
local ZONE_FLASH_BRIGHTEN = 0.45 -- how bright the zone flash is

-- reel sound
local REEL_BASE_SPEED = 0.95 -- normal slow reeling
local REEL_MAX_SPEED = 1.8 -- max speed cap
local REEL_DECAY = 1.5 -- how fast it slows back down
local REEL_RISE_MULT = 0.09 -- how much bar going up speeds it up
local REEL_LERP = 0.25 -- smoothness of speed change

-- hit forgiveness
local HIT_COYOTE = 0.08 -- tiny window for miss hits	

-- ui
local function FindUI()
	local pg = player:WaitForChild("PlayerGui")

	while true do
		local gui = pg:FindFirstChild("FishingMinigameGui", true)
		if gui then
			local frame = gui:WaitForChild("Frame")
			local bar = frame:WaitForChild("Bar")
			local zones = bar:WaitForChild("Zones")
			local zoneTemplate = zones:WaitForChild("ZoneTemplate")
			local cursor = bar:WaitForChild("Cursor")
			local hitSound = frame:FindFirstChild("HitSound")
			local reelSound = frame:FindFirstChild("FishingRodReel")

			local valueBar = frame:FindFirstChild("ValueBar")
			if valueBar then
				local fill = valueBar:WaitForChild("Fill")
				local modeLabel = frame:FindFirstChild("ModeLabel", true)
				return gui, frame, bar, zones, zoneTemplate, cursor, valueBar, fill, modeLabel, hitSound, reelSound
			end
		end
		task.wait(0.1)
	end
end

local uiGui, uiFrame, uiBar, uiZones, uiZoneTemplate, uiCursor, uiValueBar, uiFill, uiModeLabel, uiHitSound, uiReelSound = FindUI()
uiZoneTemplate.Visible = false
uiGui.Enabled = false
uiCursor.AnchorPoint = Vector2.new(0.5, 0.5)

if uiModeLabel then
	uiModeLabel.Visible = false
end

local baseFillColor = uiFill.BackgroundColor3
local fillTween = nil
local flashTween = nil
local flashBackTween = nil
local displayedValue = 0
local lastDisplayedValue = 0
local reelBoost = 0

-- bar
local function BrightenColor(c, amount)
	return Color3.new(
		c.R + (1 - c.R) * amount,
		c.G + (1 - c.G) * amount,
		c.B + (1 - c.B) * amount
	)
end

local function PulseBar()
	if flashTween then flashTween:Cancel() end
	if flashBackTween then flashBackTween:Cancel() end

	local bright = BrightenColor(baseFillColor, BAR_FLASH_BRIGHTEN)

	flashTween = TweenService:Create(
		uiFill,
		TweenInfo.new(BAR_FLASH_UP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = bright }
	)

	flashBackTween = TweenService:Create(
		uiFill,
		TweenInfo.new(BAR_FLASH_DOWN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = baseFillColor }
	)

	flashTween:Play()
	flashTween.Completed:Connect(function()
		if flashBackTween then
			flashBackTween:Play()
		end
	end)
end

local function SetBarValue(value)
	value = clamp(value, 0, 100)

	if fillTween then
		fillTween:Cancel()
	end

	local goingUp = value > displayedValue
	displayedValue = value

	fillTween = TweenService:Create(
		uiFill,
		TweenInfo.new(
			goingUp and BAR_RISE_TIME or BAR_FALL_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{ Size = UDim2.new(value / 100, 0, 1, 0) }
	)

	fillTween:Play()

	if goingUp then
		PulseBar()
	end
end

-- zone flash
local function GetZoneGuiByIndex(state, idx)
	if not state or not state.ZoneGuis then return nil end
	return state.ZoneGuis[idx]
end

local function FlashZone(zoneGui)
	if not zoneGui then return end

	local baseColor = zoneGui.BackgroundColor3
	local bright = Color3.new(
		baseColor.R + (1 - baseColor.R) * ZONE_FLASH_BRIGHTEN,
		baseColor.G + (1 - baseColor.G) * ZONE_FLASH_BRIGHTEN,
		baseColor.B + (1 - baseColor.B) * ZONE_FLASH_BRIGHTEN
	)

	local up = TweenService:Create(
		zoneGui,
		TweenInfo.new(ZONE_FLASH_UP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = bright }
	)

	local down = TweenService:Create(
		zoneGui,
		TweenInfo.new(ZONE_FLASH_DOWN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = baseColor }
	)

	up:Play()
	up.Completed:Connect(function()
		down:Play()
	end)
end

local function PlayHitSound()
	if not uiHitSound then return end
	uiHitSound:Stop()
	uiHitSound.TimePosition = 0
	uiHitSound:Play()
end

-- reel
local function StartReelSound()
	if not uiReelSound then return end
	uiReelSound.PlaybackSpeed = REEL_BASE_SPEED
	if not uiReelSound.IsPlaying then
		uiReelSound:Play()
	end
end

local function StopReelSound()
	if not uiReelSound then return end
	uiReelSound:Stop()
	uiReelSound.PlaybackSpeed = REEL_BASE_SPEED
	reelBoost = 0
end

local function UpdateReelFromBar(dt)
	if not uiReelSound then return end

	local rise = math.max(displayedValue - lastDisplayedValue, 0)
	lastDisplayedValue = displayedValue

	if rise > 0 then
		reelBoost = math.min(reelBoost + rise * REEL_RISE_MULT, REEL_MAX_SPEED - REEL_BASE_SPEED)
	end

	reelBoost = math.max(reelBoost - REEL_DECAY * dt, 0)

	local targetSpeed = math.clamp(REEL_BASE_SPEED + reelBoost, REEL_BASE_SPEED, REEL_MAX_SPEED)
	uiReelSound.PlaybackSpeed = uiReelSound.PlaybackSpeed + (targetSpeed - uiReelSound.PlaybackSpeed) * REEL_LERP
end

-- behavior
local function LoadBehavior(name)
	local mod = BehaviorsFolder:FindFirstChild(name)
	if not mod then
		mod = BehaviorsFolder:FindFirstChild("StaticCenter")
	end
	return require(mod)
end

-- zones
local function EnsureZoneGuis(state)
	state.ZoneGuis = state.ZoneGuis or {}

	while #state.ZoneGuis > #state.Zones do
		local g = table.remove(state.ZoneGuis)
		if g then g:Destroy() end
	end

	while #state.ZoneGuis < #state.Zones do
		local zone = uiZoneTemplate:Clone()
		zone.Name = "Zone"
		zone.Visible = true
		zone.Parent = uiZones
		table.insert(state.ZoneGuis, zone)
	end
end

local function TweenSize(guiObj, size, t)
	local tween = TweenService:Create(
		guiObj,
		TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = size }
	)
	tween:Play()
	return tween
end

local function UpdateZoneGuis(state)
	EnsureZoneGuis(state)

	local cfg = state.MinigameConfig or {}
	local moveAnim = cfg.ZoneMoveAnim or "Swap"

	for i, z in ipairs(state.Zones) do
		local oldGui = state.ZoneGuis[i]
		if oldGui then
			oldGui.AnchorPoint = Vector2.new(0.5, 0.5)

			local targetWidth = z.Width or (state.ZoneWidth or 0.2)
			local targetSize = UDim2.new(targetWidth, 0, 1, -10)
			local targetPos = UDim2.new(z.Center, 0, 0.5, 0)

			local lastCenter = oldGui:GetAttribute("LastCenter")
			local lastWidth = oldGui:GetAttribute("LastWidth")
			local token = (oldGui:GetAttribute("AnimToken") or 0)

			if lastCenter == nil then
				oldGui.Position = targetPos
				oldGui.Size = targetSize
				oldGui:SetAttribute("LastCenter", z.Center)
				oldGui:SetAttribute("LastWidth", targetWidth)
				oldGui:SetAttribute("AnimToken", 0)
			else
				local moved = math.abs(lastCenter - z.Center) > ZONE_EPS
				local resized = (lastWidth == nil) or (math.abs(lastWidth - targetWidth) > ZONE_EPS)

				if moved and moveAnim == "Direct" then
					oldGui.Position = targetPos
					oldGui.Size = targetSize
					oldGui:SetAttribute("LastCenter", z.Center)
					oldGui:SetAttribute("LastWidth", targetWidth)
				else
					if moved then
						token += 1
						oldGui:SetAttribute("AnimToken", token)
						oldGui:SetAttribute("LastCenter", z.Center)
						oldGui:SetAttribute("LastWidth", targetWidth)

						local newGui = oldGui:Clone()
						newGui.Parent = oldGui.Parent
						newGui.Visible = true
						newGui.Position = targetPos
						newGui.Size = UDim2.new(0, 0, 1, -10)
						newGui:SetAttribute("LastCenter", z.Center)
						newGui:SetAttribute("LastWidth", targetWidth)
						newGui:SetAttribute("AnimToken", token)

						state.ZoneGuis[i] = newGui

						local shrinkSize = UDim2.new(0, 0, 1, -10)

						local tClose = TweenSize(oldGui, shrinkSize, ZONE_CLOSE_TIME)
						TweenSize(newGui, targetSize, ZONE_OPEN_TIME)

						tClose.Completed:Connect(function()
							if newGui.Parent == nil then return end
							if newGui:GetAttribute("AnimToken") ~= token then return end
							oldGui:Destroy()
						end)
					else
						oldGui.Position = targetPos

						if resized then
							oldGui:SetAttribute("LastWidth", targetWidth)
							TweenSize(oldGui, targetSize, ZONE_RESIZE_TIME)
						else
							oldGui.Size = targetSize
						end
					end
				end
			end
		end
	end
end

local function HitIndex(state, x)
	for i, z in ipairs(state.Zones) do
		local half = (z.Width or 0) * 0.5
		if x >= (z.Center - half) and x <= (z.Center + half) then
			return i
		end
	end
	return nil
end

-- runtime
local active = nil

local function Stop()
	if active then
		if active.RenderConn then active.RenderConn:Disconnect() end
		if active.InputConn then active.InputConn:Disconnect() end

		local s = active.State
		if s.ZoneGuis then
			for _, g in ipairs(s.ZoneGuis) do
				if g then g:Destroy() end
			end
		end
	end

	StopReelSound()

	active = nil
	
	uiGui.Enabled = false

	if uiModeLabel then
		uiModeLabel.Visible = false
	end
end

local function StartSession(ownerId, mode, ownerName, fishName, fishSize, zoneName)
	Stop()

	local fishInfo = FishData.Fish[fishName]
	if not fishInfo then return end

	local mg = fishInfo.Minigame or {}
	local Behavior = LoadBehavior(mg.Behavior or "StaticCenter")

	local state = {
		Mode = mode,
		OwnerId = ownerId,
		OwnerName = ownerName,

		FishName = fishName,
		FishSize = fishSize,
		ZoneName = zoneName or "Unknown",

		MinigameConfig = mg,

		CursorX = 0.5,
		CursorDir = 1,

		CursorSpeed = mg.CursorSpeed or 1.0,
		ZoneWidth = mg.ZoneWidth or 0.25,

		Value = mg.ValueStart or 45,

		TimeNow = 0,
		LastHitIndex = nil,
		LastHitTime = -999,

		Zones = {},
		ZoneGuis = {},
	}

	if Behavior.Init then
		Behavior:Init(state)
	end

	UpdateZoneGuis(state)
	uiCursor.Position = UDim2.new(state.CursorX, 0, 0.5, 0)

	displayedValue = state.Value
	lastDisplayedValue = state.Value
	reelBoost = 0

	uiFill.Size = UDim2.new(state.Value / 100, 0, 1, 0)
	uiFill.BackgroundColor3 = baseFillColor

	uiGui.Enabled = true
	active = { State = state, Behavior = Behavior }
	
	lastDisplayedValue = state.Value
	reelBoost = 0
	StartReelSound()

	if uiModeLabel then
		if mode == "Assist" then
			uiModeLabel.Text = "Helping " .. tostring(ownerName)
			uiModeLabel.Visible = true
		else
			uiModeLabel.Visible = false
		end
	end

	active.InputConn = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if not active then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

		local s = active.State

		local idx = HitIndex(s, s.CursorX)
		local hit = (idx ~= nil)
		local usedCoyote = false

		if not hit then
			if (s.TimeNow - s.LastHitTime) <= HIT_COYOTE and s.LastHitIndex then
				hit = true
				usedCoyote = true
				idx = s.LastHitIndex
			end
		end

		if hit and idx then
			local zoneGui = GetZoneGuiByIndex(s, idx)
			FlashZone(zoneGui)
			PlayHitSound()
		end

		if active.Behavior.OnClick then
			local cursorForBehavior = s.CursorX
			if usedCoyote and idx and s.Zones[idx] then
				cursorForBehavior = s.Zones[idx].Center
			end
			active.Behavior:OnClick(s, cursorForBehavior, hit)
		end

		UpdateZoneGuis(s)

		FishingEvents.AssistAction:FireServer("Click", hit)
	end)

	active.RenderConn = RunService.RenderStepped:Connect(function(dt)
		if not active then return end
		local s = active.State

		s.TimeNow += dt

		s.CursorX += (s.CursorSpeed * dt * s.CursorDir)
		if s.CursorX >= 1 then s.CursorX = 1; s.CursorDir = -1 end
		if s.CursorX <= 0 then s.CursorX = 0; s.CursorDir = 1 end

		if active.Behavior.Step then
			active.Behavior:Step(s, dt)
		end

		local idx = HitIndex(s, s.CursorX)
		if idx then
			s.LastHitTime = s.TimeNow
			s.LastHitIndex = idx
		end

		uiCursor.Position = UDim2.new(s.CursorX, 0, 0.5, 0)
		UpdateZoneGuis(s)
		
		UpdateReelFromBar(dt)
	end)
end

function FishingClient:Init()
	FishingEvents.StartMinigame.OnClientEvent:Connect(function(fishName, fishSize, zoneName)
		StartSession(player.UserId, "Owner", player.Name, fishName, fishSize, zoneName)
	end)

	FishingEvents.StartAssistMinigame.OnClientEvent:Connect(function(ownerId, ownerName, fishName, fishSize, zoneName)
		StartSession(ownerId, "Assist", ownerName, fishName, fishSize, zoneName)
	end)

	FishingEvents.SessionProgress.OnClientEvent:Connect(function(ownerId, value)
		if not active then return end
		local s = active.State
		if s.OwnerId ~= ownerId then return end

		s.Value = value or 0
		SetBarValue(s.Value)
	end)

	FishingEvents.EndMinigame.OnClientEvent:Connect(function(ownerId, didWin, fishName)
		if not active then return end
		local s = active.State
		if s.OwnerId ~= ownerId then return end
		Stop()
	end)
end

return FishingClient