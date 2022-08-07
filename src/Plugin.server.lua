
local pluginToolbar = plugin:CreateToolbar("Script Architecture Diagram")
local pluginToolbarButton = pluginToolbar:CreateButton("Open Widget", "Open The Widget", "Open Button", "Text")

local pluginFolder = script.Parent
local pluginModules = require(pluginFolder:WaitForChild('Modules'))
local pluginWidgetsModule = require(pluginFolder:WaitForChild('Widgets'))

local pluginMaid = pluginModules.Classes.Maid.New()

local activeWidgets = {} do
	for _, widgetClassModule in pairs(pluginWidgetsModule) do
		table.insert(activeWidgets, widgetClassModule)
	end
end

pluginMaid:Give(function()
	pluginToolbarButton:SetActive(false)
	for _, classModule in ipairs( activeWidgets ) do
		classModule:Destroy()
	end
end)

pluginMaid:Give(pluginToolbarButton.Click:Connect(function()
	pluginToolbarButton:SetActive(false)
	pluginWidgetsModule.ParseScript:Toggle()
end))

pluginMaid:Give(plugin.Deactivation:Connect(function()
	pluginMaid:Cleanup()
end))

plugin.Unloading:Connect(function()
	pluginMaid:Cleanup()
end)

pluginToolbarButton:SetActive(false)
pluginWidgetsModule:Init(plugin)
