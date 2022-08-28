local TweenService = game:GetService('TweenService')

local PluginFolder = script.Parent.Parent
local Modules = require(PluginFolder.Modules)

local DefinedBaseUI = Modules.Defined.BaseUI

local NodeTreeClassModule = Modules.Classes.NodeTree
local MaidClass = Modules.Classes.Maid

local SystemsContainer = {}

local baseTreeSelectButton = Instance.new('TextButton') do
	baseTreeSelectButton.Name = 'TreeDataSelectButton'
	baseTreeSelectButton.TextColor3 = Color3.new(0.4, 0.4, 0.4)
	baseTreeSelectButton.BackgroundColor3 = Color3.fromRGB(93, 93, 93)
	baseTreeSelectButton.BackgroundTransparency = 0.8
	baseTreeSelectButton.BorderSizePixel = 0
	local UIScale = Instance.new('UIScale')
	UIScale.Name = '_UI_SCALE'
	UIScale.Scale = 1
	UIScale.Parent = baseTreeSelectButton
end

local baseFlowChartContainerFrame = Instance.new('ScrollingFrame') do
	baseFlowChartContainerFrame.BackgroundTransparency = 1
	baseFlowChartContainerFrame.Size = UDim2.fromScale(0.975, 0.975)
	baseFlowChartContainerFrame.Position = UDim2.fromScale(0.5, 0.5)
	baseFlowChartContainerFrame.BorderSizePixel = 0
	baseFlowChartContainerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	baseFlowChartContainerFrame.ScrollingEnabled = false
	baseFlowChartContainerFrame.ScrollBarThickness = 0
	baseFlowChartContainerFrame.ScrollBarImageTransparency = 1
	baseFlowChartContainerFrame.CanvasSize = UDim2.fromOffset(1200, 700)
	local gridIcon = Instance.new('ImageLabel')
	gridIcon.Name = 'GridIcon'
	gridIcon.BackgroundTransparency = 1
	gridIcon.Size = UDim2.fromScale(1, 1)
	gridIcon.ZIndex = -2
	gridIcon.Image = 'rbxassetid://9446123374'
	gridIcon.ScaleType = Enum.ScaleType.Tile
	gridIcon.TileSize = UDim2.fromOffset(10, 10)
	gridIcon.Parent = baseFlowChartContainerFrame
end

local baseFlowChartNodeFrame = Instance.new('Frame') do
	baseFlowChartNodeFrame.BackgroundColor3 = Color3.fromRGB(111, 130, 165)
	baseFlowChartNodeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	baseFlowChartNodeFrame.BackgroundTransparency = 0.05
	baseFlowChartNodeFrame.Size = UDim2.fromOffset(40, 40)
	baseFlowChartNodeFrame.BorderSizePixel = 0
	local flowChartNodeIDLabel = Instance.new('TextLabel')
	flowChartNodeIDLabel.Name = 'IDLabel'
	flowChartNodeIDLabel.BackgroundTransparency = 1
	flowChartNodeIDLabel.Size = UDim2.fromScale(1, 0.2)
	flowChartNodeIDLabel.TextScaled = true
	flowChartNodeIDLabel.TextColor3 = Color3.new(1, 1, 1)
	flowChartNodeIDLabel.Position = UDim2.fromScale(0, 1)
	flowChartNodeIDLabel.Text = 'ID_HERE'
	flowChartNodeIDLabel.Parent = baseFlowChartNodeFrame
	DefinedBaseUI.CIRCLE_UI_CORNER:Clone().Parent = baseFlowChartNodeFrame
	DefinedBaseUI.INV_IMAGE_BUTTON:Clone().Parent = baseFlowChartNodeFrame
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
			DefinedBaseUI:Line(p1, p2).Parent = bezierFolderInstance
			--[[
			local lineSegments = DefinedBaseUI:Line(p1, p2)
			for _, segment in ipairs( lineSegments ) do
				segment.Parent = bezierFolderInstance
			end]]
		else
			local dir = (p1 - p2)
			local lineSegments = DefinedBaseUI:CubicBezierLine(p1, Vector2.new(p1.x - (dir.x * 0.375), p1.y), Vector2.new(p2.x + (dir.x * 0.375), p2.y), p2 )
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

function Module:GetNodeFrame(nodeClass, FlowChartFrame)
	local Frame = FlowChartFrame:FindFirstChild(nodeClass.ID)
	if not Frame then
		Frame = baseFlowChartNodeFrame:Clone()
		Frame.Position = UDim2.fromOffset(nodeClass.x, nodeClass.y)
		-- print(Frame.Button:GetFullName())
		Frame.IDLabel.Text = nodeClass.ID
		Frame.Button.Activated:Connect(function()
			-- print(nodeClass.ID)
			SystemsContainer.NodeInfoDisplay:DisplayNodeData(nodeClass)
		end)
		Frame.ZIndex = 2
		Frame.Parent = FlowChartFrame
	end
	return Frame
end

function Module:UpdateFramesInFlowChart( baseTreeClass, FlowChartFrame )
	print(FlowChartFrame:GetFullName(), #baseTreeClass.nodes)

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

function Module:SetupChartInputMechanics( targetFrame : ScrollingFrame )
	assert(typeof(targetFrame) == 'Instance' and targetFrame:IsA('ScrollingFrame'), 'Passed targetFrame is not a ScrollingFrame!')

	local Holding, LastXY = false, Vector2.new(0, 0)
	local MaidInstance = MaidClass.New()

	local UIScaleInstance = Instance.new('UIScale')
	UIScaleInstance.Parent = targetFrame

	MaidInstance:Give(targetFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Holding = true
		end
	end))

	MaidInstance:Give(targetFrame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local newXY = Vector2.new(input.Position.X, input.Position.Y)
			if Holding then
				local delta = (newXY-LastXY)
				targetFrame.CanvasPosition += delta
			end
			LastXY = newXY
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			local nextScale = UIScaleInstance.Scale + (input.Position.Z * 0.05)
			UIScaleInstance.Scale = math.clamp(nextScale, 0.1, 2)
		end
	end))

	MaidInstance:Give(targetFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Holding = false
		end
	end))

	MaidInstance:Give(targetFrame.Destroying:Connect(function()
		MaidInstance:Cleanup()
	end))

	MaidInstance:Give(UIScaleInstance)
end

function Module:GetFlowChartFrame(baseTreeClass)
	local targetFrame = Module.FlowChartFrame:FindFirstChild(baseTreeClass.name)
	if not targetFrame then
		targetFrame = baseFlowChartContainerFrame:Clone()
		targetFrame.Name = baseTreeClass.name
		targetFrame.Visible = false
		Module:SetupChartInputMechanics( targetFrame )
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
			TweenService:Create(categoryButton._UI_SCALE, TweenInfo.new(0.25), {Scale = 1.05}):Play()
		end)
		categoryButton.MouseLeave:Connect(function()
			TweenService:Create(categoryButton._UI_SCALE, TweenInfo.new(0.25), {Scale = 1}):Play()
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

	local nameCache = {}
	for _, baseTreeClass in ipairs( Module.ActiveTrees ) do
		table.insert(nameCache, baseTreeClass.name)
		local TreeFrame = Module:GetFlowChartFrame(baseTreeClass)
		local TreeButton = Module:GetCategorySelectButton(baseTreeClass, TreeFrame)
		if TreeButton then
			Module:UpdateFramesInFlowChart(baseTreeClass, TreeFrame)
			Module.ButtonToTreeFrame[TreeButton] = TreeFrame
		end
	end

	for Button, Frame in pairs( Module.ButtonToTreeFrame ) do
		if not table.find(nameCache, Frame.Name) then
			Module.ButtonToTreeFrame[Button] = nil
			Button:Destroy()
			Frame:Destroy()
		end
	end

	if not Module.FirstRun and #Module.ActiveTrees > 0 then
		Module.FirstRun = true
		Module:ToggleFrame(Module.FlowChartFrame:FindFirstChildWhichIsA('Frame'))
	end
end

function Module:LoadNodeJSON( Name, nodeJSONArray )
	local baseTreeClass = NodeTreeClassModule.TreeData.New()
	baseTreeClass.name = Name
	baseTreeClass:LoadNodes( nodeJSONArray )
	table.insert(Module.ActiveTrees, baseTreeClass)
	return baseTreeClass
end

function Module:ClearActiveTrees()
	Modules.ActiveTrees = {}
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
		true, true,
		600, 400, 600, 400
	)

	local dockWidget = plugin:CreateDockWidgetPluginGui(script.Name, dockWidgetInfo) :: DockWidgetPluginGui
	dockWidget.Name = 'FlowDiagram'
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

	-- Select Tree Frame
	local TreeSelectFrame = Instance.new('Frame')
	TreeSelectFrame.Name = 'TreeSelectFrame'
	TreeSelectFrame.BorderSizePixel = 0
	TreeSelectFrame.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
	TreeSelectFrame.Size = UDim2.fromScale(0.2, 1)
	TreeSelectFrame.ZIndex = 0
	TreeSelectFrame.Parent = ContainerFrame
	self.TreeSelectFrame = TreeSelectFrame
	local TreeSelectGridLayout  = Instance.new('UIGridLayout')
	TreeSelectGridLayout.CellPadding = UDim2.fromScale(0, 0.01)
	TreeSelectGridLayout.CellSize = UDim2.fromScale(1, 0.1)
	TreeSelectGridLayout.Parent = TreeSelectFrame
	local TreeSelectAspectRatio = Instance.new('UIAspectRatioConstraint')
	TreeSelectAspectRatio.AspectType = Enum.AspectType.ScaleWithParentSize
	TreeSelectAspectRatio.AspectRatio = 3.5
	TreeSelectAspectRatio.Parent = TreeSelectGridLayout
	local TreeSelectUIPadding = Instance.new('UIPadding')
	TreeSelectUIPadding.PaddingTop = UDim.new(0.01, 0)
	TreeSelectUIPadding.PaddingLeft = UDim.new(0.02, 0)
	TreeSelectUIPadding.PaddingRight = UDim.new(0.02, 0)
	TreeSelectUIPadding.Parent = TreeSelectFrame

	local _ = Module:LoadNodeJSON( "TestDiagram", Modules.Defined.TestDiagram )
	Module:UpdateFrames()
	Module:Toggle(true)
end

return Module


