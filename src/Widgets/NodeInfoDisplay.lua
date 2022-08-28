local HttpService = game:GetService("HttpService")

local PluginFolder = script.Parent.Parent
local PluginModules = require(PluginFolder.Modules)

local SystemsContainer = {}

local baseNodeDataLabel = Instance.new('TextLabel')
baseNodeDataLabel.Name = 'BaseNodeDataLabel'
baseNodeDataLabel.BackgroundTransparency = 1
baseNodeDataLabel.TextScaled = true
baseNodeDataLabel.TextColor3 = Color3.new(1, 1, 1)
baseNodeDataLabel.Text = ''
baseNodeDataLabel.Font = Enum.Font.SourceSansBold

-- // Module // --
local Module = {}

Module.WidgetMaid = PluginModules.Classes.Maid.New()
Module.Visible = false
Module.DockWidget = false
Module.NodeInfoDisplay = false
Module.plugin = false

function Module:ClearLabels()
	for _, Label in ipairs( Module.NodeInfoDisplay:GetChildren() ) do
		if Label:IsA('TextLabel') then
			Label:Destroy()
		end
	end
end

function Module:DisplayNodeData(nodeClass)
	-- print(nodeClass)
	Module:ClearLabels()
	if not Module.Visible then
		return
	end
	for propName, propVal in pairs(nodeClass) do
		local valType = typeof(propVal)
		if valType == 'number' then
			propVal = math.floor(propVal * 10) / 10 -- round to 1 decimal
		elseif valType == 'table' then
			propVal = HttpService:JSONEncode(propVal) -- json encode table as string
			valType = #propVal > 0 and 'array' or 'dict'
		end
		local baseLabel = baseNodeDataLabel:Clone()
		baseLabel.Name = propName
		baseLabel.Text = string.format('%s = %s (%s)', propName, tostring(propVal), valType)
		baseLabel.Parent = Module.NodeInfoDisplay
	end
end

function Module:Show()
	Module.DockWidget.Enabled = true
	-- print(script.Name, 'Show')
end

function Module:Hide()
	Module.DockWidget.Enabled = false
	-- print(script.Name, 'Hide')
	Module:ClearLabels()
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
		250, 250, 250, 250
	)

	local dockWidget = plugin:CreateDockWidgetPluginGui(script.Name, dockWidgetInfo)
	dockWidget.Name = 'NodeInfoDisplay'
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
		Module.NodeInfoDisplay = BackgroundFrame

		local GridLayout = Instance.new('UIGridLayout')
		GridLayout.CellPadding = UDim2.fromScale(0, 0.05)
		GridLayout.CellSize = UDim2.fromScale(1, 0.075)
		GridLayout.Parent = BackgroundFrame
		local UIPadding = Instance.new('UIPadding')
		UIPadding.PaddingBottom = UDim.new(0.04, 0)
		UIPadding.PaddingTop = UDim.new(0.04, 0)
		UIPadding.Parent = BackgroundFrame
	end
end

return Module

