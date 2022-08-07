warn('Character visuals - masks / gun skins / perks / etc')
local Players = game:GetService('Players')
local Teams = game:GetService('Teams')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedAssets = ReplicatedStorage:WaitForChild('Assets')
local ReplicatedCore = require(ReplicatedStorage:WaitForChild('Core'))
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))
local ReplicatedData = ReplicatedCore.ReplicatedData
local ItemsModule = ReplicatedModules.Defined.Items
local SystemsContainer = {}
local CharacterCache = {}
local Module = {}

function Module:RenderUpdate()
	local renderData = ReplicatedData:GetData('RenderData')
	-- print(renderData)
	if typeof(renderData) ~= 'table' then
		return
	end

	for playerName, accessoryData in pairs(renderData) do
		local PlayerInstance = Players:FindFirstChild(playerName)
		if (not PlayerInstance) or PlayerInstance.Team == Teams.Props then
			continue
		end

		local CharacterInstance = workspace:FindFirstChild(playerName)
		local HeadInstance = CharacterInstance and CharacterInstance:FindFirstChild('Head')
		if (not CharacterInstance) or (not HeadInstance) then
			continue
		end

		if not CharacterCache[PlayerInstance] then
			CharacterCache[PlayerInstance] = { }
		end

		-- print(CharacterInstance:GetFullName(), accessoryData)

		-- remove all old accessories that are not equipped
		for accessoryID, accessoryInstance in pairs( CharacterCache[PlayerInstance] ) do
			if not table.find(accessoryData, accessoryID) then
				accessoryInstance:Destroy()
				CharacterCache[PlayerInstance][accessoryID] = nil
			end
		end

		-- equip new accessories and skip those that are equipped
		for _, accessoryID in ipairs( accessoryData ) do
			local accessoryConfig = ItemsModule:GetConfigFromID( accessoryID )
			if not accessoryConfig then
				warn('Cannot find the accessory config for ID ', accessoryID)
				continue
			end

			if not accessoryConfig.Model then
				warn('No model set for accessory of ID ', accessoryID)
				continue
			end

			local ModelInstance = ReplicatedAssets.Masks:FindFirstChild(accessoryConfig.Model)
			if not ModelInstance then
				warn('Could not find accessory instance named ', accessoryConfig.Model)
				continue
			end

			-- print(ModelInstance:GetFullName())

			ModelInstance = ModelInstance:Clone()
			ModelInstance:SetPrimaryPartCFrame( HeadInstance.CFrame )
			ReplicatedModules.Utility.Models:WeldConstraint( ModelInstance.PrimaryPart, HeadInstance )
			ModelInstance.Parent = CharacterInstance

			CharacterCache[PlayerInstance][accessoryID] = ModelInstance
		end
	end
end

function Module:Init( otherSystems )
	SystemsContainer = otherSystems

	task.defer(function()
		Module:RenderUpdate()
	end)

	workspace.ChildAdded:Connect(function(childInstance)
		if Players:FindFirstChild(childInstance.Name) then
			task.wait(0.1)
			Module:RenderUpdate()
		end
	end)

	workspace.ChildRemoved:Connect(function(childInstance)
		if Players:FindFirstChild(childInstance.Name) then
			Module:RenderUpdate()
		end
	end)

	ReplicatedData.OnUpdate:Connect(function(Category, _)
		if Category == 'PlayerData' then
			Module:RenderUpdate()
		end
	end)
end

return Module