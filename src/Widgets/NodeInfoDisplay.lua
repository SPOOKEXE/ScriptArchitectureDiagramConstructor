
local PluginFolder = script.Parent.Parent
local PluginModules = require(PluginFolder.Modules)

local SystemsContainer = {}

-- // Module // --
local Module = {}

Module.WidgetMaid = PluginModules.Classes.Maid.New()
Module.Visible = false
Module.DockWidget = false
Module.plugin = false

function Module:DisplayNodeData(nodeClass)
	print(nodeClass)
end

function Module:Show()
	Module.DockWidget.Enabled = true
	print(script.Name, 'Show')
end

function Module:Hide()
	Module.DockWidget.Enabled = false
	print(script.Name, 'Hide')
	self.WidgetMaid:Cleanup()
end

function Module:Toggle(forcedValue)
	print(typeof(forcedValue))
	if typeof(forcedValue) == 'boolean' then
		Module.Visible = forcedValue
	else
		Module.Visible = not Module.Visible
	end
	print(Module.Visible)
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
	end
end

return Module

