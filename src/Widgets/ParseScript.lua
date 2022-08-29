
local Selection = game:GetService('Selection')

local PluginFolder = script.Parent.Parent
local PluginModules = require(PluginFolder.Modules)

local NodeTreeContainer = PluginModules.Classes.NodeTree
--local ScriptENVParser = PluginModules.Classes.ScriptENVParser
local ScriptENVParser = PluginModules.Classes.ScriptTokenParser

local ScriptUtility = PluginModules.Utility.ScriptUtility
local HashLibUtility = PluginModules.Utility.Hashlib
local sha256 = HashLibUtility.sha256 :: (string) -> string

local SystemsContainer = {}

local LastTokenParse = false

-- // Module // --
local Module = {}

Module.WidgetMaid = PluginModules.Classes.Maid.New()
Module.Visible = false
Module.DockWidget = false
Module.plugin = false

function Module:TokenParseSelections()
	local whitelistClassName = {'LocalScript', 'Script', 'ModuleScript'}
	local parsedInfoArray = {}
	local ScriptInstances = Selection:Get()
	for _, scriptInstance in ipairs( ScriptInstances ) do
		if table.find(whitelistClassName, scriptInstance.ClassName) then
			table.insert(parsedInfoArray, {
				scriptInstance:GetFullName(),
				ScriptUtility:RawTokenParse( scriptInstance )
			})
		end
	end
	return parsedInfoArray
end

function Module:AddEnvParserToParseInfo(parsedInfoArray, debugPrint)
	for _, t in ipairs( parsedInfoArray ) do
		local scriptPath, tokenDictionary = unpack(t)
		local envParser = ScriptENVParser.New()
		local _, _ = envParser:ParseTokens(tokenDictionary)
		if debugPrint then
			print(scriptPath)
			envParser:OutputParse() -- DEBUG
			print('\n\n\n')
		end
		table.insert(t, envParser)
	end
	return parsedInfoArray
end

function Module:ParseEnvArraysToNodeJSONs(envParserArray)
	-- 0 = root stack (global script environment)
	-- 1 = local scope, depth 1
	-- 2 = local scope, depth 2

	-- This one creates a flow diagram of all scripts accessing each other (call functions)
	local GlobalDepthNodeJSONArray = {}

	-- This one creates diagram of invidivual script data
	local ScriptDepthNodeJSONArray = {}

	for _, t in ipairs( envParserArray ) do
		local scriptPath, _, envParserClass = unpack(t)

		local scriptNodeDepthMap = {}

		-- for all call functions
		print('=============')
		print(scriptPath, envParserClass)
		for index, callFunctionNode in ipairs( envParserClass.CallFunctionNodes ) do
			local statementIndex, dataType, data, depth = unpack(callFunctionNode)
			print(statementIndex, dataType, data, depth)

			local nodeHashValue = sha256(scriptPath..depth)
			print(nodeHashValue)

			local nodeData = { ID = nodeHashValue, Layer = depth }

			local localNodeDepthMap = scriptNodeDepthMap[depth]
			if not localNodeDepthMap then
				localNodeDepthMap = {}
				scriptNodeDepthMap[depth] = localNodeDepthMap
			end
			table.insert(localNodeDepthMap, nodeData)

			local globalNodeDepthMap = GlobalDepthNodeJSONArray[depth]
			if not globalNodeDepthMap then
				globalNodeDepthMap = {}
				GlobalDepthNodeJSONArray[depth] = globalNodeDepthMap
			end
			table.insert(globalNodeDepthMap, nodeData)

			if index > 2 then
				break
			end
		end
		print('=============')

		-- match node depth with globalDepthMap
		ScriptDepthNodeJSONArray[scriptPath] = scriptNodeDepthMap
	end

	-- put the nodes in the correct layer
	local IndividualNodeJSONArray = {}
	local GlobalNodeJSONArray = {}
	for layerZ, nodeData in pairs( IndividualNodeJSONArray ) do
		nodeData.Layer = layerZ
	end
	for layerZ, nodeData in pairs( GlobalNodeJSONArray ) do
		nodeData.Layer = layerZ
	end
	-- return node array { ID = 'string', Depends = {'string', 'string'}, Layer = # }
	return GlobalNodeJSONArray, IndividualNodeJSONArray
end

function Module:GetLatestParse()
	return LastTokenParse
end

function Module:Show()
	Module.DockWidget.Enabled = true
	-- print(script.Name, 'Show')
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
		250, 150, 50, 30
	)

	local dockWidget = plugin:CreateDockWidgetPluginGui(script.Name, dockWidgetInfo)
	dockWidget.Name = 'ParseScript'
	dockWidget.Title = script.Name
	dockWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
		local tokenScriptArray = Module:TokenParseSelections()
		LastTokenParse = tokenScriptArray
		Module:AddEnvParserToParseInfo(tokenScriptArray, false)
		local GlobalNodeJSONArray, IndividualNodeJSONArrays = Module:ParseEnvArraysToNodeJSONs(tokenScriptArray)
		print(GlobalNodeJSONArray, IndividualNodeJSONArrays)
		SystemsContainer.FlowDiagramodule:LoadNodeJSON("Global", GlobalNodeJSONArray)
		for ScriptPath, NodeArray in ipairs( IndividualNodeJSONArrays ) do
			SystemsContainer.FlowDiagramodule:LoadNodeJSON(ScriptPath, NodeArray)
		end
		SystemsContainer.FlowDiagramodule:UpdateFrames()
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

