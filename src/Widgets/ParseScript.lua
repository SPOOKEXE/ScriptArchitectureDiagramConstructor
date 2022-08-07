
local Selection = game:GetService('Selection')

local PluginFolder = script.Parent.Parent
local PluginModules = require(PluginFolder.Modules)

local ScriptUtility = PluginModules.Utility.ScriptUtility

local SystemsContainer = {}

-- // Module // --
local Module = {}

Module.WidgetMaid = PluginModules.Classes.Maid.New()
Module.Visible = false
Module.DockWidget = false
Module.plugin = false

function Module:ParseSelection()
	local whitelistClassName = {'LocalScript', 'Script', 'ModuleScript'}
	local parsedInfoArray = {}
	local ScriptInstances = Selection:Get()
	for _, scriptInstance in ipairs( ScriptInstances ) do
		if table.find(whitelistClassName, scriptInstance.ClassName) then
			table.insert(parsedInfoArray, {	scriptInstance:GetFullName(), ScriptUtility:RawTokenParse( scriptInstance ) })
		end
	end
	return parsedInfoArray
end

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

	local TriggerButton = Instance.new('TextButton')
	TriggerButton.Name = 'TriggerAction'
	TriggerButton.BackgroundTransparency = 1
	TriggerButton.Size = UDim2.fromScale(1, 1)
	TriggerButton.Position = UDim2.fromScale(0.5, 0.5)
	TriggerButton.AnchorPoint = Vector2.new(0.5, 0.5)
	TriggerButton.ZIndex = 5
	TriggerButton.Text = 'Parse Script Tokens'
	TriggerButton.TextScaled = true
	TriggerButton.Activated:Connect(function()
		print("parse selections")
		local results = Module:ParseSelection()
		print(results[1])
	end)

	local PadUDim = UDim.new(0.05, 0)
	local Padding = Instance.new('UIPadding')
	Padding.PaddingTop = PadUDim
	Padding.PaddingBottom = PadUDim
	Padding.PaddingLeft = PadUDim
	Padding.PaddingLeft = PadUDim
	Padding.Parent = TriggerButton

	TriggerButton.Parent = dockWidget
	Module.DockWidget = dockWidget
end

return Module
