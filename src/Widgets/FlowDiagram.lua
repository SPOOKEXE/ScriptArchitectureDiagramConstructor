local PluginFolder = script.Parent.Parent
local Modules = require(PluginFolder.Modules)

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

function Module:LoadTreeData( treeClass )
	--[[
		{
			NodeTreeScript1Name = NodeTreeClass,
			NodeTreeScript2Name = NodeTreeClass,
		}
	]]
	print( treeClass )
end

function Module:AppendTreeData( treeClass )
	print('append ', treeClass)
end

function Module:UpdateTabs()
	
end

function Module:Show()
	Module.DockWidget.Enabled = true
	print(script.Name, 'Show')
	-- self.WidgetMaid:Give()
	-- Module.ChartSelectFrame
	-- Module.SeparatorFrame
	-- Module.FlowChartFrame
end

function Module:Hide()
	Module.DockWidget.Enabled = false
	print(script.Name, 'Hide')
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
end

return Module


