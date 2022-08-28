
local HttpService = game:GetService('HttpService')
local sha256 = require(script.Parent.Parent.Utility.Hashlib).sha256

local SkipTypeList = {'ReturnStat', 'GenericForStat', 'IfStat', 'AssignmentStat 1'}

local ParseHandlers = {}

ParseHandlers.LocalVarStat = function(_, scopeRegistry, statementIndex, data, depth)
	table.insert(scopeRegistry.SetVariableNodes, {statementIndex, data.Type, data, depth})
end

ParseHandlers.FunctionStat = function(_, scopeRegistry, statementIndex, data, depth)
	table.insert(scopeRegistry.CreateFunctionNodes, {statementIndex, data.Type, data, depth})
end
ParseHandlers.LocalFunctionStat = ParseHandlers.FunctionStat

ParseHandlers.CallExprStat = function(_, scopeRegistry, statementIndex, data, depth)
	table.insert(scopeRegistry.CallFunctionNodes, {statementIndex, data.Type, data, depth})
end

-- // Class // --
local Class = {}
Class.__index = Class

function Class.New()
	return setmetatable({
		LastParse = 0,
		RootScopeRegistry = false,
		ScopeConnectionMap = {},
		ScopeRegistries = {},
	}, Class)
end

function Class:Reset()
	print('Reset Script Parser')
	self.ScopeConnectionMap = {}
	self.ScopeRegistries = {}
	self.LastParse = 0
end

function Class:ParseBodyStatement( parentRegistryUUID, BodyArray, depth )
	
end

function Class:ParseStatementList(parentRegistryUUID, StatementList, depth)
	print('ParentID: ', parentRegistryUUID)
	print('Step Depth; ', depth or 0)

	local currentRegistryUUID = HttpService:GenerateGUID(false)

	local scopeReg = {
		ParentScopeUUID = parentRegistryUUID,
		ScopeID = currentRegistryUUID,
		ChildScopesIDs = {},
		SetVariableNodes = {},
		CreateFunctionNodes = {},
		CallFunctionNodes = {},
		Depth = depth,
	}

	if self.ScopeConnectionMap[parentRegistryUUID] then
		table.insert(self.ScopeConnectionMap[parentRegistryUUID], currentRegistryUUID)
	else
		self.ScopeConnectionMap[parentRegistryUUID] = {currentRegistryUUID}
	end

	self.ScopeRegistries[currentRegistryUUID] = scopeReg

	for statementIndex, data in pairs( StatementList ) do
		local parsed = true
		if ParseHandlers[data.Type] then
			print('Parsed ; ', statementIndex, data.Type)
			ParseHandlers[data.Type](self, scopeReg, statementIndex, data, depth or 0)
		elseif table.find(SkipTypeList, data.Type) then
			print('Skipped ; ', data.Type, statementIndex)
			continue
		else
			parsed = false
		end
		if data.Body then
			parsed = true
			local envRegistryTable = self:ParseStatementList(currentRegistryUUID, data.Body.StatementList, (depth or 0) + 1)
			table.insert(scopeReg.ChildScopesIDs, envRegistryTable.ScopeID)
		end
		if not parsed then
			warn('Unsupported Type ; ', data.Type, statementIndex)
		end
	end

	return scopeReg
end

function Class:OutputParse()
	print(self.ScopeConnectionMap)
	local baseRegistryString = 'REGISTRY %s DEPTH %d || CALL FUNCTIONS (%d), CREATE FUNCTIONS (%d), SET VARIABLE (%d)'
	for registryUUID, data in pairs( self.ScopeRegistries ) do
		print( string.format(baseRegistryString, registryUUID, data.Depth or 0, #data.CallFunctionNodes, #data.CreateFunctionNodes, #data.SetVariableNodes) )
	end
	print(string.rep('\n', 2))
	for registryID, registryData in pairs(self.ScopeRegistries) do
		print('==== ', registryID, ' ====')
		for _, SetVariableNode in ipairs( registryData.SetVariableNodes ) do
			local statementIndex, dataType, data, depth = unpack(SetVariableNode)
			print('SET VARIABLE ; ', statementIndex, dataType, data.VarList[1].Source, depth)
		end
		for _, CreateFunctionNode in ipairs( registryData.CreateFunctionNodes ) do
			local statementIndex, dataType, data, depth = unpack(CreateFunctionNode)
			print('CREATE FUNCTION ; ', statementIndex, dataType, data.NameChain[#data.NameChain].Source, depth)
		end
		for _, functionCallNode in ipairs( registryData.CallFunctionNodes ) do
			local statementIndex, dataType, data, depth = unpack(functionCallNode)
			print('CALL FUNCTION ; ', statementIndex, dataType, depth)
		end
	end
end

function Class:ParseTokens(tokenDictionary)
	print(tokenDictionary)
	local hashName = 'OutputToken_'..sha256(HttpService:JSONEncode(tokenDictionary))

	local outputTokenDictionary = workspace:FindFirstChild(hashName)
	if not outputTokenDictionary then
		outputTokenDictionary = Instance.new('StringValue')
		outputTokenDictionary.Name = hashName
		outputTokenDictionary.Parent = workspace
	end
	outputTokenDictionary.Value = HttpService:JSONEncode(tokenDictionary)

	self:Reset()
	local rootEnvDictionary = self:ParseStatementList(false, tokenDictionary.StatementList, false)
	self.RootScopeRegistry = rootEnvDictionary
	return rootEnvDictionary
end

--[[
	-- Create one node tree that links scripts together in one large diagram
	function Module:ConstructLargeNodeTree(parseResult)
		print('Construct Large Tree ; ', parseResult)
	end

	-- Create node trees for each script separately (no linking between scripts in one large diagram)
	function Module:ConstructPerScriptNodeTrees(parseResult)
		print(parseResult)
		local newNodeTree = NodeTreeContainer.TreeData.New()
		local nodesArray = {}

		--	{
		--		{ ID = 'blah2', Depends = {}, Layer = 1 },
		--		{ ID = 'blah', Depends = {'blah2'}, Layer = 2 },
		--	}

		for _, t in ipairs( parseResult ) do
			local scriptFullName, envParserClass = unpack(t)
			print('==== ', scriptFullName, ' ====')
			envParserClass:OutputParse() -- DEBUG
			break
		end

		newNodeTree:LoadNodes( nodesArray )

		return newNodeTree
	end
]]

return Class