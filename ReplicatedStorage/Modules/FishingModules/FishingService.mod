local FishingService = {}
local FishingState = {}

-- services
local Players = game:GetService("Players")

-- refs
local RP = game.ReplicatedStorage
local FishingEvents = RP:WaitForChild("Events"):WaitForChild("FishingEvents")

local FishModules = RP:WaitForChild("Modules"):WaitForChild("FishingModules")
local FishData = require(FishModules:WaitForChild("FishData"))
local FishZones = require(FishModules:WaitForChild("FishZones"))
local InventoryService = require(FishModules:WaitForChild("InventoryService"))

local FishingResources = RP:WaitForChild("Resources"):WaitForChild("Fishing")
local HookedBillboardTemplate = FishingResources:WaitForChild("HookedBillboard")

-- cfg
local ASSIST_RANGE = 25
local MAX_ASSIST = 3
local TICK_RATE = 0.1
local BITE_WINDOW = 10

-- chain cfg
local PULL_BACK_OFFSET = 3.5
local PULL_SLOT_SPACING = 2.4
local PULL_SIDE_OFFSET = 0
local PULL_HEIGHT_OFFSET = 0
local PULL_ANIM_OFFSET = Vector3.new(0, 0, 0)

local SessionsByOwner = {}
local SessionByPlayer = {}

-- util
local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function ApplyOverrides(baseFish, overrides)
	if not overrides then
		return table.clone(baseFish)
	end
	local combined = table.clone(baseFish)
	for k, v in pairs(overrides) do
		combined[k] = v
	end
	return combined
end

local function GetRandomSize(sizeRange: NumberRange)
	local t = (math.random() + math.random() + math.random()) / 3
	return sizeRange.Min + (sizeRange.Max - sizeRange.Min) * t
end

local function BroadcastProgress(session)
	FishingEvents.SessionProgress:FireClient(session.Owner, session.OwnerId, session.Progress)
	for plr in pairs(session.Assistants) do
		FishingEvents.SessionProgress:FireClient(plr, session.OwnerId, session.Progress)
	end
end

-- billboard
local function ShowFishOn(owner, st)
	local head = owner.Character and owner.Character:FindFirstChild("Head")
	if not head then return end

	if st.Billboard then
		st.Billboard:Destroy()
		st.Billboard = nil
	end

	local bb = HookedBillboardTemplate:Clone()
	bb.Name = "FishOnBillboard"
	bb.Adornee = head
	bb.Parent = head
	st.Billboard = bb
end

local function ClearFishOn(st)
	if st.Billboard then
		st.Billboard:Destroy()
		st.Billboard = nil
	end
end

-- slots
local function ReindexSlots(slotByPlayer)
	local list = {}
	for plr, idx in pairs(slotByPlayer) do
		if plr and plr.Parent == Players then
			table.insert(list, { P = plr, I = idx })
		end
	end
	table.sort(list, function(a, b) return a.I < b.I end)

	local newMap = {}
	for i, entry in ipairs(list) do
		newMap[entry.P] = i
	end
	return newMap
end

local function SlotCFrame(ownerHrp: BasePart, idx: number)
	local back = PULL_BACK_OFFSET + ((idx - 1) * PULL_SLOT_SPACING)

	local pos =
		ownerHrp.Position
	- (ownerHrp.CFrame.LookVector * back)
		+ (ownerHrp.CFrame.RightVector * PULL_SIDE_OFFSET)
		+ (ownerHrp.CFrame.UpVector * PULL_HEIGHT_OFFSET)
		+ (ownerHrp.CFrame:VectorToWorldSpace(PULL_ANIM_OFFSET))

	return CFrame.new(pos, pos + ownerHrp.CFrame.LookVector)
end

local function TeleportToSlot(owner: Player, helper: Player, idx: number)
	local ownerHrp = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
	local helperHrp = helper.Character and helper.Character:FindFirstChild("HumanoidRootPart")
	if not ownerHrp or not helperHrp then return false end

	helperHrp.CFrame = SlotCFrame(ownerHrp, idx)
	return true
end

-- zones
function FishingService:GetZoneForPlayer(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return "None" end

	local zones = workspace:FindFirstChild("FishingZones")
	if not zones then return "Default" end

	local pos = hrp.Position

	for _, zonePart in ipairs(zones:GetDescendants()) do
		if zonePart:IsA("BasePart") then
			local localPos = zonePart.CFrame:PointToObjectSpace(pos)
			local half = zonePart.Size * 0.5

			if math.abs(localPos.X) <= half.X
				and math.abs(localPos.Y) <= half.Y
				and math.abs(localPos.Z) <= half.Z then
				return zonePart.Parent.Name
			end
		end
	end

	return "None"
end

function FishingService:SelectFishFromZone(zoneConfig)
	local fishPool = zoneConfig.Fish
	local total = 0

	for fishName, weight in pairs(fishPool) do
		local w = weight
		if w == true then
			local entry = FishData.Fish[fishName]
			w = entry and entry.BaseRarity or 0
		end
		total += w
	end

	if total <= 0 then
		return next(fishPool)
	end

	local roll = math.random(1, total)
	local cumulative = 0

	for fishName, weight in pairs(fishPool) do
		local w = weight
		if w == true then
			local entry = FishData.Fish[fishName]
			w = entry and entry.BaseRarity or 0
		end
		cumulative += w
		if roll <= cumulative then
			return fishName
		end
	end

	return next(fishPool)
end

-- end
local function EndSession(owner, didWin)
	local session = SessionsByOwner[owner]
	if not session or session.Ended then return end
	session.Ended = true

	print("[Fishing] EndSession", owner.Name, didWin, session.FishName)

	SessionsByOwner[owner] = nil
	SessionByPlayer[owner] = nil

	for plr in pairs(session.Assistants) do
		SessionByPlayer[plr] = nil
	end

	if didWin then
		InventoryService:AddFish(owner, session.FishName, session.FishSize or 0, session.ZoneName or "Unknown", nil)

		for plr in pairs(session.Assistants) do
			InventoryService:AddFish(plr, session.FishName, session.FishSize or 0, session.ZoneName or "Unknown", {
				CoOp = true,
				Owner = owner.Name,
			})
		end
	end

	FishingEvents.EndMinigame:FireClient(owner, session.OwnerId, didWin, session.FishName)
	for plr in pairs(session.Assistants) do
		FishingEvents.EndMinigame:FireClient(plr, session.OwnerId, didWin, session.FishName)
	end

	local st = FishingState[owner]
	if st then
		ClearFishOn(st)
		FishingState[owner] = nil
	end
end

local function SessionLoop(owner)
	while true do
		local session = SessionsByOwner[owner]
		if not session or session.Ended then return end

		session.Progress = clamp(session.Progress - (session.ValueDecay * TICK_RATE), 0, 100)
		BroadcastProgress(session)

		if session.Progress >= 100 then
			EndSession(owner, true)
			return
		end

		if session.Progress <= 0 then
			EndSession(owner, false)
			return
		end

		task.wait(TICK_RATE)
	end
end

-- cancel
function FishingService:CancelBite(owner)
	local st = FishingState[owner]
	if not st or not st.HasBite then return end

	print("[Fishing] CancelBite", owner.Name)

	st.IsCasting = false
	st.HasBite = false
	st.BiteExpires = 0

	st.PendingAssistants = {}
	st.SlotByPlayer = {}

	st.CurrentFish = nil
	st.CurrentFishInfo = nil
	st.CurrentFishSize = nil
	st.CurrentZone = nil

	ClearFishOn(st)
	FishingEvents.CancelBite:FireClient(owner)
end

-- cast
function FishingService:StartFishing(owner)
	FishingState[owner] = FishingState[owner] or {}
	local st = FishingState[owner]

	if SessionByPlayer[owner] then return end
	if st.IsCasting then return end
	if st.HasBite then return end

	print("[Fishing] Cast", owner.Name)

	st.IsCasting = true
	st.HasBite = false
	st.BiteExpires = 0

	st.PendingAssistants = {}
	st.SlotByPlayer = {}

	local zoneName = self:GetZoneForPlayer(owner)
	local zoneConfig = FishZones.List[zoneName]
	if not zoneConfig then
		st.IsCasting = false
		return
	end

	local chosen = self:SelectFishFromZone(zoneConfig)
	local base = FishData.Fish[chosen]
	if not base then
		st.IsCasting = false
		return
	end

	local overrides = zoneConfig.Overrides and zoneConfig.Overrides[chosen]
	local fishInfo = ApplyOverrides(base, overrides)
	local rolledSize = GetRandomSize(fishInfo.SizeRange)

	st.CurrentFish = chosen
	st.CurrentFishInfo = fishInfo
	st.CurrentFishSize = rolledSize
	st.CurrentZone = zoneName

	local biteRange = zoneConfig.BiteTime
	task.wait(math.random(biteRange.Min, biteRange.Max))

	if FishingState[owner] ~= st or not st.IsCasting then return end

	st.IsCasting = false
	st.HasBite = true
	st.BiteExpires = os.clock() + BITE_WINDOW

	print("[Fishing] Bite", owner.Name, chosen)

	ShowFishOn(owner, st)
	FishingEvents.FishBite:FireClient(owner, chosen)

	task.spawn(function()
		task.wait(BITE_WINDOW)
		if FishingState[owner] ~= st then return end
		if st.HasBite and os.clock() >= (st.BiteExpires or 0) and not SessionByPlayer[owner] then
			self:CancelBite(owner)
		end
	end)
end

function FishingService:StartDebugFish(owner, fishName)
	local fishInfo = FishData.Fish[fishName]
	if not fishInfo then return end
	if SessionByPlayer[owner] then return end

	FishingState[owner] = FishingState[owner] or {}
	local st = FishingState[owner]

	if st.HasBite then
		self:CancelBite(owner)
	end

	local rolledSize = GetRandomSize(fishInfo.SizeRange)
	local zoneName = self:GetZoneForPlayer(owner)

	local mg = fishInfo.Minigame or {}

	local session = {
		Owner = owner,
		OwnerId = owner.UserId,

		FishName = fishName,
		FishSize = rolledSize,
		ZoneName = zoneName or "Debug",

		Progress = mg.ValueStart or 45,
		ValueDecay = mg.ValueDecay or 10,

		HitGain = mg.HitGain or 15,
		MissPenalty = mg.MissPenalty or 8,

		AssistHitMult = mg.AssistHitMult or 0.6,
		AssistMissMult = mg.AssistMissMult or 0.4,

		Assistants = {},
		Ended = false,
	}

	SessionsByOwner[owner] = session
	SessionByPlayer[owner] = session

	st.PendingAssistants = {}
	st.SlotByPlayer = {}
	st.CurrentFish = nil
	st.CurrentFishInfo = nil
	st.CurrentFishSize = nil
	st.CurrentZone = nil
	st.HasBite = false
	st.BiteExpires = 0

	FishingEvents.StartMinigame:FireClient(owner, fishName, rolledSize, zoneName)
	BroadcastProgress(session)

	task.spawn(SessionLoop, owner)
end

-- start
function FishingService:StartMinigame(owner)
	local st = FishingState[owner]
	if not st then return end
	if SessionByPlayer[owner] then return end
	if not st.HasBite then return end

	if os.clock() > (st.BiteExpires or 0) then
		self:CancelBite(owner)
		return
	end

	local fishName = st.CurrentFish
	local fishInfo = st.CurrentFishInfo
	if not fishName or not fishInfo then
		self:CancelBite(owner)
		return
	end

	print("[Fishing] StartMinigame", owner.Name, fishName)

	st.HasBite = false
	st.BiteExpires = 0

	FishingEvents.CancelBite:FireClient(owner)

	local mg = fishInfo.Minigame or {}

	local session = {
		Owner = owner,
		OwnerId = owner.UserId,

		FishName = fishName,
		FishSize = st.CurrentFishSize or 0,
		ZoneName = st.CurrentZone or "Unknown",

		Progress = mg.ValueStart or 45,
		ValueDecay = mg.ValueDecay or 10,

		HitGain = mg.HitGain or 15,
		MissPenalty = mg.MissPenalty or 8,

		AssistHitMult = mg.AssistHitMult or 0.6,
		AssistMissMult = mg.AssistMissMult or 0.4,

		Assistants = {},
		Ended = false,
	}

	SessionsByOwner[owner] = session
	SessionByPlayer[owner] = session

	-- keep indicator for mid-join
	ShowFishOn(owner, st)

	-- bring queued
	for helper in pairs(st.PendingAssistants or {}) do
		if helper and helper.Parent == Players and helper ~= owner and not SessionByPlayer[helper] then
			session.Assistants[helper] = true
			SessionByPlayer[helper] = session

			local idx = st.SlotByPlayer[helper] or 1
			TeleportToSlot(owner, helper, idx)

			FishingEvents.StartAssistMinigame:FireClient(helper, session.OwnerId, owner.Name, session.FishName, session.FishSize, session.ZoneName)
			FishingEvents.SessionProgress:FireClient(helper, session.OwnerId, session.Progress)
		end
	end

	st.PendingAssistants = {}

	FishingEvents.StartMinigame:FireClient(owner, fishName, session.FishSize, session.ZoneName)
	BroadcastProgress(session)

	task.spawn(SessionLoop, owner)

	st.CurrentFish = nil
	st.CurrentFishInfo = nil
	st.CurrentFishSize = nil
	st.CurrentZone = nil
end

-- assist
function FishingService:RequestAssist(helper, ownerId)
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner then return end
	if helper == owner then return end
	if SessionByPlayer[helper] then return end

	local ownerHrp = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
	local helperHrp = helper.Character and helper.Character:FindFirstChild("HumanoidRootPart")
	if not ownerHrp or not helperHrp then return end
	if (ownerHrp.Position - helperHrp.Position).Magnitude > ASSIST_RANGE then return end

	local st = FishingState[owner]
	if not st then return end

	-- mid-minigame join
	local session = SessionsByOwner[owner]
	if session and not session.Ended then
		local count = 0
		for _ in pairs(session.Assistants) do count += 1 end
		if count >= MAX_ASSIST then return end
		if session.Assistants[helper] then return end

		st.SlotByPlayer = st.SlotByPlayer or {}

		local maxIdx = 0
		for _, idx in pairs(st.SlotByPlayer) do
			if idx > maxIdx then maxIdx = idx end
		end

		st.SlotByPlayer[helper] = maxIdx + 1
		st.SlotByPlayer = ReindexSlots(st.SlotByPlayer)

		local slotIndex = st.SlotByPlayer[helper]

		session.Assistants[helper] = true
		SessionByPlayer[helper] = session

		print("[Fishing] AssistJoinSession", helper.Name, "->", owner.Name, "slot", slotIndex)

		FishingEvents.AssistQueued:FireClient(helper, ownerId, true)

		TeleportToSlot(owner, helper, slotIndex)

		FishingEvents.StartAssistMinigame:FireClient(helper, session.OwnerId, owner.Name, session.FishName, session.FishSize, session.ZoneName)
		FishingEvents.SessionProgress:FireClient(helper, session.OwnerId, session.Progress)
		return
	end

	-- bite window queue
	if not st.HasBite then return end
	if os.clock() > (st.BiteExpires or 0) then return end

	st.PendingAssistants = st.PendingAssistants or {}
	st.SlotByPlayer = st.SlotByPlayer or {}

	if st.PendingAssistants[helper] then return end

	local count = 0
	for _ in pairs(st.PendingAssistants) do count += 1 end
	if count >= MAX_ASSIST then return end

	local maxIdx = 0
	for _, idx in pairs(st.SlotByPlayer) do
		if idx > maxIdx then maxIdx = idx end
	end

	st.PendingAssistants[helper] = true
	st.SlotByPlayer[helper] = maxIdx + 1
	st.SlotByPlayer = ReindexSlots(st.SlotByPlayer)

	local slotIndex = st.SlotByPlayer[helper]

	print("[Fishing] AssistQueued", helper.Name, "->", owner.Name, "slot", slotIndex)

	FishingEvents.AssistQueued:FireClient(helper, ownerId, true)

	TeleportToSlot(owner, helper, slotIndex)
end

-- clicks
function FishingService:AssistAction(player, action, hit)
	local session = SessionByPlayer[player]
	if not session or session.Ended then return end
	if action ~= "Click" then return end

	local isOwner = (player == session.Owner)

	local helperCount = 0
	for _ in pairs(session.Assistants) do
		helperCount += 1
	end

	local delta = 0

	if isOwner then
		if hit then
			delta = session.HitGain
		else
			delta = -session.MissPenalty
		end
	else
		if hit then
			local baseMult = session.AssistHitMult or 0.6
			local diminish = 1 / (1 + (helperCount - 1) * 0.35)
			delta = session.HitGain * baseMult * diminish
		else
			delta = 0
		end
	end

	session.Progress = clamp(session.Progress + delta, 0, 100)
	BroadcastProgress(session)

	if session.Progress >= 100 then
		EndSession(session.Owner, true)
	elseif session.Progress <= 0 then
		EndSession(session.Owner, false)
	end
end

-- init
function FishingService:Init()
	print("Fishing Service is Loaded!")

	FishingEvents.StartFishing.OnServerEvent:Connect(function(player)
		self:StartFishing(player)
	end)

	FishingEvents.StartMinigameRequest.OnServerEvent:Connect(function(player)
		print("[Fishing] StartMinigameRequest", player.Name)
		self:StartMinigame(player)
	end)

	FishingEvents.RequestAssist.OnServerEvent:Connect(function(player, ownerId)
		self:RequestAssist(player, ownerId)
	end)

	FishingEvents.AssistAction.OnServerEvent:Connect(function(player, action, hit)
		self:AssistAction(player, action, hit)
	end)
	
	FishingEvents.DebugStartFish.OnServerEvent:Connect(function(player, fishName)
		self:StartDebugFish(player, fishName)
	end)
	
	FishingEvents.DebugStartFish.OnServerEvent:Connect(function(player, fishName)
		self:StartDebugFish(player, fishName)
	end)

	Players.PlayerRemoving:Connect(function(plr)
		local session = SessionByPlayer[plr]
		if session and session.Owner and session.Assistants and session.Assistants[plr] then
			session.Assistants[plr] = nil
			SessionByPlayer[plr] = nil
		end
	end)
end

return FishingService