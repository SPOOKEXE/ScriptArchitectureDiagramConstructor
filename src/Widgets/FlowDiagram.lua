local TweenService = game:GetService('TweenService')

local PluginFolder = script.Parent.Parent
local Modules = require(PluginFolder.Modules)

local NodeTreeClassModule = Modules.Classes.NodeTree
local MaidClass = Modules.Classes.Maid

local SystemsContainer = {}

local baseTreeSelectButton = Instance.new('TextButton') do
	baseTreeSelectButton.Name = 'TreeDataSelectButton'
	baseTreeSelectButton.TextColor3 = Color3.new(0.4, 0.4, 0.4)
	baseTreeSelectButton.BackgroundColor3 = Color3.fromRGB(93, 93, 93)
	baseTreeSelectButton.BackgroundTransparency = 0.8
	baseTreeSelectButton.BorderSizePixel = 0
	local uiScaleInstance = Instance.new('UIScale')
	uiScaleInstance.Scale = 1
	uiScaleInstance.Parent = baseTreeSelectButton
end

local baseFlowChartContainerFrame = Instance.new('Frame') do
	baseFlowChartContainerFrame.BackgroundTransparency = 1
	baseFlowChartContainerFrame.Size = UDim2.fromScale(0.975, 0.975)
	baseFlowChartContainerFrame.Position = UDim2.fromScale(0.5, 0.5)
	baseFlowChartContainerFrame.BorderSizePixel = 0
	baseFlowChartContainerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
end

local baseFlowChartNodeFrame = Instance.new('Frame') do
	baseFlowChartNodeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	baseFlowChartNodeFrame.BackgroundTransparency = 0.6
	baseFlowChartNodeFrame.Size = UDim2.fromOffset(40, 40)
	baseFlowChartNodeFrame.BorderSizePixel = 0
	local uiCorner = Instance.new('UICorner')
	uiCorner.CornerRadius = UDim.new(0.5, 0)
	uiCorner.Parent = baseFlowChartNodeFrame
end

local baseLineFrame = Instance.new('Frame')
baseLineFrame.BackgroundTransparency = 0
baseLineFrame.BackgroundColor3 = Color3.new(1, 1, 1)
baseLineFrame.BorderSizePixel = 0
baseLineFrame.ZIndex = -1
local function line(p1, p2)
	local dir = (p2 - p1)
	local length = dir.Magnitude
	local newFrame = baseLineFrame:Clone()
	newFrame.Rotation = math.deg( math.atan2(dir.y, dir.x) )
	newFrame.Size = UDim2.fromOffset(length, 2)
	newFrame.Position = UDim2.fromOffset(p1.x - length, p1.y)
	return newFrame
end

-- https://javascript.info/bezier-curve
local function getCubicBezier(p1, p2, p3, p4, alpha)
	return
		math.pow( 1 - alpha, 3 ) * p1 +
		3 * math.pow(1 - alpha, 2) * alpha * p2 +
		3 * (1 - alpha) * math.pow(alpha, 2) * p3 +
		math.pow(alpha, 3) * p4
end

local bezierResolution = 2 -- frame/pixels
local function bezier(p1, p2, p3, p4)
	local bezierFrames = {}
	local totalSteps = math.floor((p4 - p1).Magnitude / bezierResolution)
	local delta = (1 / totalSteps)
	for step = 1, totalSteps do
		local v = (step * delta)
		local vectorA = getCubicBezier(p1, p2, p3, p4, v - delta)
		local vectorB = getCubicBezier(p1, p2, p3, p4, v + delta)
		table.insert(bezierFrames, line(vectorA, vectorB))
	end
	return bezierFrames
end

local function UIBezierLine(p1, p2, parentFrame)
	local wasCreated = false
	local hashValue = Modules.Utility.Hashlib.sha256(tostring(p1)..tostring(p2))
	local bezierFolderInstance = parentFrame:FindFirstChild(hashValue)
	if not bezierFolderInstance then
		bezierFolderInstance = Instance.new('Folder')
		bezierFolderInstance.Name = hashValue
		bezierFolderInstance.Parent = parentFrame
		if (p1.x == p2.x) or (p1.y == p2.y) then
			line(p1, p2).Parent = bezierFolderInstance
		else
			local dir = (p1 - p2)
			local lineSegments = bezier(p1, Vector2.new(p1.x - (dir.x * 0.375), p1.y), Vector2.new(p2.x + (dir.x * 0.375), p2.y), p2 )
			for _, segment in ipairs( lineSegments ) do
				segment.Parent = bezierFolderInstance
			end
		end
		wasCreated = true
	end
	return bezierFolderInstance, wasCreated
end

-- // Module // --
local Module = {}

Module.Visible = false
Module.plugin = false

Module.WidgetMaid = MaidClass.New()
Module.DockWidget = false
Module.TreeSelectFrame = false
Module.SeparatorFrame = false
Module.FlowChartFrame = false

Module.ActiveTrees = {}
Module.ButtonToTreeFrame = {}

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

function Module:GetNodeFrame(nodeClass, FlowChartFrame)
	local Frame = FlowChartFrame:FindFirstChild(nodeClass.ID)
	if not Frame then
		Frame = baseFlowChartNodeFrame:Clone()
		Frame.Position = UDim2.fromOffset(nodeClass.x, nodeClass.y)
		Frame.Parent = FlowChartFrame
	end
	return Frame
end

function Module:UpdateFramesInFlowChart( baseTreeClass, FlowChartFrame )
	print(FlowChartFrame:GetFullName(), baseTreeClass)

	for _, nodeClass in ipairs( baseTreeClass.nodes ) do
		for _, dependID in ipairs( nodeClass.depends ) do
			local dependantNodeClass = baseTreeClass:GetNodeFromID(dependID)
			UIBezierLine(
				Vector2.new(nodeClass.x, nodeClass.y),
				Vector2.new(dependantNodeClass.x, dependantNodeClass.y),
				FlowChartFrame
			)
		end
	end

	for _, nodeClass in ipairs( baseTreeClass.nodes ) do
		Module:GetNodeFrame(nodeClass, FlowChartFrame)
	end
end

function Module:GetFlowChartFrame(baseTreeClass)
	local targetFrame = Module.FlowChartFrame:FindFirstChild(baseTreeClass.name)
	if not targetFrame then
		targetFrame = baseFlowChartContainerFrame:Clone()
		targetFrame.Name = baseTreeClass.name
		targetFrame.Parent = Module.FlowChartFrame
	end
	return targetFrame
end

function Module:ToggleFrame(targetFrame)
	for ButtonFrame, FlowFrame in pairs(Module.ButtonToTreeFrame) do
		local IsVisible = (FlowFrame == targetFrame) and (not FlowFrame.Visible) or false
		FlowFrame.Visible = IsVisible
		ButtonFrame.TextColor3 = IsVisible and Color3.new(1, 1, 1) or Color3.new(0.4, 0.4, 0.4)
	end
end

function Module:GetCategorySelectButton(baseTreeClass, targetFrame)
	local categoryButton = Module.TreeSelectFrame:FindFirstChild(baseTreeClass.name)
	if not categoryButton then
		categoryButton = baseTreeSelectButton:Clone()
		categoryButton.Name = baseTreeClass.name
		categoryButton.MouseEnter:Connect(function()
			TweenService:Create(categoryButton.UIScale, TweenInfo.new(0.25), {Scale = 1.05}):Play()
		end)
		categoryButton.MouseLeave:Connect(function()
			TweenService:Create(categoryButton.UIScale, TweenInfo.new(0.25), {Scale = 1}):Play()
		end)
		categoryButton.Activated:Connect(function()
			Module:ToggleFrame(targetFrame)
		end)
		categoryButton.Parent = Module.TreeSelectFrame
	end
	categoryButton.LayoutOrder = #baseTreeClass.nodes
	return categoryButton
end

function Module:UpdateFrames()
	for _, baseTreeClass in ipairs( Module.ActiveTrees ) do
		if not baseTreeClass.visible then
			continue
		end
		local TreeFrame = Module:GetFlowChartFrame(baseTreeClass)
		local TreeButton = Module:GetCategorySelectButton(baseTreeClass, TreeFrame)
		if TreeButton then
			Module:UpdateFramesInFlowChart(baseTreeClass, TreeFrame)
			Module.ButtonToTreeFrame[TreeButton] = TreeFrame
		end
	end
end

function Module:LoadNodeArray( nodeArray )
	local baseTreeClass = NodeTreeClassModule.TreeData.New()
	-- baseTreeClass.IDToNode
	-- baseTreeClass.LayerZToNodeMap
	-- baseTreeClass.nodes
	-- return IDToNode, LayerZToNodeMap, NodesArray
	return baseTreeClass
end

function Module:LoadNodeJSON( nodeJSONArray )
	local baseTreeClass = NodeTreeClassModule.TreeData.New()
	baseTreeClass:LoadNodes( nodeJSONArray )
	baseTreeClass.visible = true
	return baseTreeClass
end

function Module:UpdateTabs()
	-- change tab highlights / visibility and stuff
	for TreeButton, TreeFrame in pairs(Module.ButtonToTreeFrame) do
		if not TreeFrame:IsDescendantOf(Module.FlowChartFrame) then
			TreeButton:Destroy()
		end
	end
	-- update the frames
	Module:UpdateFrames()
end

function Module:Show()
	Module.DockWidget.Enabled = true
	-- print(script.Name, 'Show')
	-- self.WidgetMaid:Give()
	-- Module.TreeSelectFrame
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
		600, 400, 600, 400
	)

	local dockWidget = plugin:CreateDockWidgetPluginGui(script.Name, dockWidgetInfo) :: DockWidgetPluginGui
	dockWidget.Title = script.Name
	dockWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
	ContainerFrame.Name = 'ContainerFrame'
	ContainerFrame.BackgroundTransparency = 1
	ContainerFrame.Size = UDim2.fromScale(1, 1)
	ContainerFrame.ZIndex = 1
	ContainerFrame.Parent = dockWidget

	local TreeSelectFrame = Instance.new('Frame')
	TreeSelectFrame.Name = 'TreeSelectFrame'
	TreeSelectFrame.BorderSizePixel = 0
	TreeSelectFrame.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
	TreeSelectFrame.Size = UDim2.fromScale(0.2, 1)
	TreeSelectFrame.ZIndex = 0
	TreeSelectFrame.Parent = ContainerFrame
	self.TreeSelectFrame = TreeSelectFrame

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

	local TreeSelectGridLayout  = Instance.new('UIGridLayout')
	TreeSelectGridLayout.CellPadding = UDim2.fromScale(0, 0.01)
	TreeSelectGridLayout.CellSize = UDim2.fromScale(1, 0.1)
	TreeSelectGridLayout.Parent = TreeSelectFrame
	local TreeSelectAspectRatio = Instance.new('UIAspectRatioConstraint')
	TreeSelectAspectRatio.AspectRatio = 3.5
	TreeSelectAspectRatio.AspectType = Enum.AspectType.ScaleWithParentSize
	TreeSelectAspectRatio.Parent = TreeSelectGridLayout
	local TreeSelectUIPadding = Instance.new('UIPadding')
	TreeSelectUIPadding.PaddingTop = UDim.new(0.01, 0)
	TreeSelectUIPadding.PaddingLeft = UDim.new(0.02, 0)
	TreeSelectUIPadding.PaddingRight = UDim.new(0.02, 0)
	TreeSelectUIPadding.Parent = TreeSelectFrame

	local treeClass = Module:LoadNodeJSON( Modules.Defined.TestDiagram )
	table.insert(Module.ActiveTrees, treeClass)
	Module:UpdateTabs()

	Module:Toggle(true)
end

return Module


