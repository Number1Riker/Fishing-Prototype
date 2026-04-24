local Players = game:GetService("Players")

local RP = game.ReplicatedStorage
local Events = RP:WaitForChild("Events")
local InventoryEvents = Events:WaitForChild("InventoryEvents")

local GetInventory = InventoryEvents:WaitForChild("GetInventory")
local InventoryChanged = InventoryEvents:WaitForChild("InventoryChanged")

local InventoryService = {}
local InventoryState = {} -- [player] = profile

-- CONFIG
local MAX_INSTANCES_PER_FISH = 200
-- END CONFIG

local function NewProfile()
	return {
		Fish = {}, -- [fishName] = { Instances = { {Size, Zone, Time}, ... } }
	}
end

function InventoryService:GetProfile(player: Player)
	InventoryState[player] = InventoryState[player] or NewProfile()
	return InventoryState[player]
end

function InventoryService:AddFish(player: Player, fishName: string, size: number, zoneName: string?, meta)
	local profile = self:GetProfile(player)

	profile.Fish[fishName] = profile.Fish[fishName] or {Instances = {}}
	local bucket = profile.Fish[fishName]

	table.insert(bucket.Instances, 1, {
		Size = size,
		Zone = zoneName or "Unknown",
		Time = os.time(),
	})

	while #bucket.Instances > MAX_INSTANCES_PER_FISH do
		table.remove(bucket.Instances)
	end

	InventoryChanged:FireClient(player, profile)
end

function InventoryService:Init()
	print("Inventory Service is Loaded!")

	Players.PlayerAdded:Connect(function(player)
		InventoryState[player] = NewProfile()
	end)

	Players.PlayerRemoving:Connect(function(player)
		InventoryState[player] = nil
	end)

	GetInventory.OnServerInvoke = function(player)
		return self:GetProfile(player)
	end
end

return InventoryService
