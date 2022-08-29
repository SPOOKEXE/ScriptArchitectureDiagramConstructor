
local pluginToolbar = plugin:CreateToolbar("Script Architecture Diagram")

local pluginFolder = script.Parent
local Modules = require(pluginFolder:WaitForChild('Modules'))
local WidgetModule = require(pluginFolder:WaitForChild('Widgets'))

local MaidClass = Modules.Classes.Maid

local ActiveButtonClasses = {}

-- // Class // --
local ButtonClass = {}
ButtonClass.__index = ButtonClass

function ButtonClass.New(widgetClass, buttonId, tooltip, icon_name , text : string?)
	local pluginButton = pluginToolbar:CreateButton(buttonId, tooltip, icon_name, text)

	if widgetClass then
		widgetClass:Toggle(false)
	end
	pluginButton:SetActive(false)

	local self = setmetatable({
		widgetClass = widgetClass,

		pluginButton = pluginButton,
		clickEvent = pluginButton.Click,

		_connections = MaidClass.New(),
	}, ButtonClass)

	self:OnClick(function()
		self:Toggle()
	end)

	table.insert(ActiveButtonClasses, self)

	return self
end

function ButtonClass:Toggle(enabled)
	-- print('toggle ', enabled or (not self.widgetClass.Visible))
	self.pluginButton:SetActive(false)
	if self.widgetClass then
		self.widgetClass:Toggle(enabled)
	end
end

function ButtonClass:OnClick(...)
	local connection = self.clickEvent:Connect(...)
	self._connections:Give(connection)
	return connection
end

function ButtonClass:Destroy()
	-- cleanup click event
	if self.clickEvent then
		self.clickEvent:Disconnect()
		self.clickEvent = nil
	end
	-- plugin button
	if self.pluginButton then
		self.pluginButton:Destroy()
		self.pluginButton = nil
	end
	-- connections cleanup
	if self._connections then
		self._connections:Cleanup()
		self._connections = nil
	end
end

-- // Plugin // --
local pluginMaid = MaidClass.New()

pluginMaid:Give(function()
	-- clear buttons
	for _, buttonClass in ipairs( ActiveButtonClasses ) do
		buttonClass:Destroy()
	end
	ActiveButtonClasses = nil
end)

pluginMaid:Give(plugin.Deactivation:Connect(function()
	pluginMaid:Cleanup()
end))

pluginMaid:Give(plugin.Unloading:Connect(function()
	pluginMaid:Cleanup()
end))

WidgetModule:Init(plugin)
ButtonClass.New(WidgetModule.ParseScript, 'Parse Script', 'This widget is used to parse scripts.', 'rbxassetid://8939587672')
ButtonClass.New(WidgetModule.FlowDiagram, 'Flow Diagram', 'This widget is used to hold diagrams', 'rbxassetid://8939587672')
ButtonClass.New(WidgetModule.NodeInfoDisplay, 'Node Info', 'This widget is used to display node information', 'rbxassetid://8939587672')

ButtonClass.New(false, 'Display Latest Tokens', 'Display the latest parsed script\'s tokens', 'rbxassetid://8939587672'):OnClick(function()
	local LatestTokenParseArray = WidgetModule.ParseScript:GetLatestParse()
	print(LatestTokenParseArray or 'No Latest Parse')
end)
