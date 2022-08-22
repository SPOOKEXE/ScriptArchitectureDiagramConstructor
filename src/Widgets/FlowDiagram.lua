local PluginFolder = script.Parent.Parent
local Modules = require(PluginFolder.Modules)

local NodeTreeClassModule = Modules.Classes.NodeTree
local MaidClass = Modules.Classes.Maid

local SystemsContainer = {}

-- // Module // --
local Module = {}

Module.Visible = false
Module.plugin = false

Module.WidgetMaid = MaidClass.New()
Module.DockWidget = false
Module.ChartSelectFrame = false
Module.SeparatorFrame = false
Module.FlowChartFrame = false

Module.ActiveTrees = {}
Module.ActiveNodes = {}

function Module:ParseEnvArraysToNodes(envParserArray)
	-- { {fullScriptPath, tokenDictionary, envParser} }
	local nodeArray = {}
	for _, t in ipairs( envParserArray ) do
		local scriptPath, tokenDictionary, envParser = unpack(t)

		local nodesTable = {}

		table.insert(nodeArray, {scriptPath, nodesTable})
	end
	return nodeArray
end

function Module:ClearActiveTrees()
	-- clear the frames and stuff
	Module.ActiveNodes = {}
	Module.ActiveTrees = {}
end

function Module:LoadNodeArray( nodeArray )
	local IDToNode = {}
	local LayerZToNodeMap = {}
	local NodesArray = {}

	-- return IDToNode, LayerZToNodeMap, NodesArray
	return IDToNode, LayerZToNodeMap, NodesArray
end

function Module:LoadNodeJSON( nodeJSONArray )
	local IDToNode = {}
	local LayerZToNodeMap = {}
	local NodesArray = {}
	for _, nodeData in ipairs( nodeJSONArray ) do
		local layerZTable = LayerZToNodeMap[nodeData.Layer]
		if not layerZTable then
			layerZTable = {}
			LayerZToNodeMap[nodeData.Layer] = layerZTable
		end
		if IDToNode[nodeData.ID] then
			warn('Duplicate Node ; ', nodeData.ID)
			continue
		end
		local newNodeClass = NodeTreeClassModule.BaseNode.New()
		newNodeClass:SetLayer(nodeData.Layer)
		for _, dependID in ipairs( nodeData.Depends ) do
			table.insert(newNodeClass.depends, dependID)
		end
		table.insert(NodesArray, newNodeClass)
		-- table.insert(Module.ActiveNodes, newNodeClass)
		IDToNode[nodeData.ID] = newNodeClass
	end
	return IDToNode, LayerZToNodeMap, NodesArray
end

function Module:UpdateTabs()
	
end

function Module:Show()
	Module.DockWidget.Enabled = true
	-- print(script.Name, 'Show')
	-- self.WidgetMaid:Give()
	-- Module.ChartSelectFrame
	-- Module.SeparatorFrame
	-- Module.FlowChartFrame
end

function Module:Hide()
	Module.DockWidget.Enabled = false
	-- print(script.Name, 'Hide')
	self.WidgetMaid:Cleanup()
end

function Module:Toggle(forcedValue)
	if typeof(forcedValue) == 'boolean' then
		Module.Visible = forcedValue
	else
		Module.Visible = not Module.Visible
	end
	if Module.Visible then
		Module:Show()
	else
		Module:Hide()
	end
end

function Module:Destroy()
	print(script.Name, 'Destroy')
end

function Module:Init(otherSystems, plugin)
	SystemsContainer = otherSystems
	Module.plugin = plugin

	local dockWidgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false, true,
		800, 800, 200, 200
	)

	local dockWidget = plugin:CreateDockWidgetPluginGui(script.Name, dockWidgetInfo) :: DockWidgetPluginGui
	dockWidget.Title = script.Name
	dockWidget.Enabled = false
	Module.DockWidget = dockWidget

	do
		local BackgroundFrame = Instance.new('Frame')
		BackgroundFrame.Name = 'BackgroundFrame'
		BackgroundFrame.BorderSizePixel = 0
		BackgroundFrame.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
		BackgroundFrame.Size = UDim2.fromScale(1, 1)
		BackgroundFrame.ZIndex = 0
		BackgroundFrame.Parent = dockWidget
	end

	local ContainerFrame = Instance.new('Frame')
	ContainerFrame.BackgroundTransparency = 1
	ContainerFrame.Size = UDim2.fromScale(1, 1)
	ContainerFrame.ZIndex = 1
	ContainerFrame.Parent = dockWidget

	local AspectRatio = Instance.new('UIAspectRatioConstraint')
	AspectRatio.AspectRatio = 1
	AspectRatio.AspectType = Enum.AspectType.ScaleWithParentSize
	AspectRatio.Parent = ContainerFrame

	local ChartSelectFrame = Instance.new('Frame')
	ChartSelectFrame.Name = 'ChartSelectFrame'
	ChartSelectFrame.BorderSizePixel = 0
	ChartSelectFrame.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
	ChartSelectFrame.Size = UDim2.fromScale(0.2, 1)
	ChartSelectFrame.ZIndex = 0
	ChartSelectFrame.Parent = ContainerFrame
	self.ChartSelectFrame = ChartSelectFrame

	local SeparatorFrame = Instance.new('Frame')
	SeparatorFrame.Name = 'SeparatorFrame'
	SeparatorFrame.BorderSizePixel = 0
	SeparatorFrame.BackgroundColor3 = Color3.fromRGB(59, 59, 59)
	SeparatorFrame.Size = UDim2.fromScale(0.05, 1)
	SeparatorFrame.Position = UDim2.fromScale(0.2, 0)
	SeparatorFrame.ZIndex = 0
	SeparatorFrame.Parent = ContainerFrame
	self.SeparatorFrame = SeparatorFrame

	local FlowChartFrame = Instance.new('Frame')
	FlowChartFrame.Name = 'FlowChartFrame'
	FlowChartFrame.BorderSizePixel = 0
	FlowChartFrame.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
	FlowChartFrame.Size = UDim2.fromScale(0.795, 1)
	FlowChartFrame.Position = UDim2.fromScale(0.205, 0)
	FlowChartFrame.ZIndex = 0
	FlowChartFrame.Parent = ContainerFrame
	self.FlowChartFrame = FlowChartFrame

	Module:LoadNodeJSON( Modules.Defined.TestDiagram )
end

return Module


