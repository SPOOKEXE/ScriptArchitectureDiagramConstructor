
local PluginFolder = script.Parent.Parent
local PluginModules = require(PluginFolder.Modules)

local SystemsContainer = {}

-- // Module // --
local Module = {}

Module.WidgetMaid = PluginModules.Classes.Maid.New()
Module.Visible = false
Module.DockWidget = false
Module.plugin = false

function Module:Show()
	if Module.Visible then
		return
	end
	Module.Visible = true
	Module.DockWidget.Enabled = true
	print(script.Name, 'Show')
end

function Module:Hide()
	if not Module.Visible then
		return
	end
	Module.Visible = false
	Module.DockWidget.Enabled = false
	print(script.Name, 'Hide')
	self.WidgetMaid:Cleanup()
end

function Module:Toggle()
	if Module.Visible then
		Module:Hide()
	else
		Module:Show()
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
		250, 150, 50, 30
	)

	local dockWidget = plugin:CreateDockWidgetPluginGui(script.Name, dockWidgetInfo)
	dockWidget.Title = script.Name
	dockWidget.Enabled = false
	Module.DockWidget = dockWidget
end

return Module

