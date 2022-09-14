local HttpService = game:GetService("HttpService")

local function JoinNameChain(nameChainData)
	local nameString = ""
	for _, stringData in ipairs( nameChainData ) do
		if not stringData.Source then
			warn('Invalid Name Chain Data ; ', stringData)
			continue
		end
		nameString = nameString..stringData.Source
	end
	return nameString
end


-- // Class // --
local Class = {}
Class.__index = Class
Class.__tostring = function(self)
	local registryCount = 0
	for _, _ in pairs(self.ScopeRegistries ) do
		registryCount += 1
	end
	return string.format('TokenParser [ ScopeRegistries %s ]', registryCount)
end

function Class.New()
	return setmetatable({
		RootRegistryID = false, -- root scope id
		RootRegistryDict = false, -- root scope

		ScopeConnectionMap = false, -- how scopes interconnect
		ScopeRegistries = false, -- each individual scope
	}, Class)
end

-- // CORE METHODS // --
function Class:Clear()
	self.RootRegistryID = false
	self.RootRegistryDict = false
	self.ScopeConnectionMap = {}
	self.ScopeRegistries = {}
end

local IgnoreTypes = {
	'TableLiteral', 'StringLiteral', 'VargLiteral',
	'NumberLiteral', 'Ident', 'Symbol', 'String', 'Keyword',
	'ContinueStat', 'NilLiteral', 'BooleanLiteral', 'BreakStat',
}

local WhitelistTypes = {
	'ArgCall', 'CallExprStat', 'FunctionStat', 'LocalFunctionStat', 'FunctionLiteral',
	'StatList', 'VariableExpr', 'CallExpr', 'MethodExpr', 'LocalVarStat', 'FieldExpr',
	'BinopExpr', 'AssignmentStat', 'AssignmentStat 1', 'ReturnStat', 'GeneratorList',
	'GenericForStat', 'IfStat', 'UnopExpr', 'IndexExpr', 'ParenExpr', 'NumericForStat',
	'WhileStat', 'RepeatStat'
}

function Class:_CheckAvailableParses(ScopeRegistry, statementData)
	print(statementData)
	if statementData.FunctionArguments then
		self:_ParseStatementList(ScopeRegistry.ScopeUUID, statementData.FunctionArguments.ArgList, ScopeRegistry.Depth)
	end
	if statementData.FunctionStat then
		self:_ParseStatementList( ScopeRegistry.ScopeUUID, {statementData.FunctionStat.Body}, ScopeRegistry.Depth + 1 )
	end
	if statementData.Body then
		self:_ParseStatementList(ScopeRegistry.ScopeUUID, statementData.Body.StatementList, ScopeRegistry.Depth + 1)
	end
	if statementData.Expression then
		self:_ParseStatementList( ScopeRegistry.ScopeUUID, {statementData.Expression}, ScopeRegistry.Depth)
	end
	if statementData.ExprList then
		self:_ParseStatementList( ScopeRegistry.ScopeUUID, statementData.ExprList, ScopeRegistry.Depth)
	end
	if statementData.ArgList then
		self:_ParseStatementList(ScopeRegistry.ScopeUUID, statementData.ArgList, ScopeRegistry.Depth)
	end
	if statementData.GeneratorList then
		self:_ParseStatementList(ScopeRegistry.ScopeUUID, statementData.GeneratorList, ScopeRegistry.Depth)
	end
	if statementData.Condition then
		self:_ParseStatementList(ScopeRegistry.ScopeUUID, {statementData.Condition}, ScopeRegistry.Depth)
	end
	if statementData.Rhs then
		self:_ParseStatementList(ScopeRegistry.ScopeUUID, #statementData.Rhs > 0 and statementData.Rhs or {statementData.Rhs}, ScopeRegistry.Depth)
	end
	if statementData.Lhs then
		self:_ParseStatementList(ScopeRegistry.ScopeUUID, #statementData.Lhs > 0 and statementData.Lhs or {statementData.Lhs}, ScopeRegistry.Depth)
	end
	if statementData.RangeList then
		self:_ParseStatementList(ScopeRegistry.ScopeUUID, statementData.RangeList, ScopeRegistry.Depth)
	end
end

function Class:_ParseStatementList( parentUUID, StatementList, Depth )
	Depth = Depth or 0
	if Depth > 50 then
		return
	end

	print('Parent ID: ', parentUUID)
	print('Step Depth; ', Depth)

	local newScopeUUID = HttpService:GenerateGUID(false)
	print('New Scope ID: ', newScopeUUID)

	local ScopeRegistry = {
		_CreatedFunctions = {},
		_FunctionCalls = {},
		_CreatedVariables = {},

		Depth = Depth,
		ScopeUUID = newScopeUUID,
		ParentUUID = parentUUID,
		ChildScopeIDs = {},
	}

	local parentRegistry = parentUUID and self.ScopeRegistries[parentUUID]
	if parentRegistry then
		table.insert(parentRegistry.ChildScopeIDs, newScopeUUID)
	end

	if self.ScopeConnectionMap[parentUUID] then
		table.insert(self.ScopeConnectionMap[parentUUID], newScopeUUID)
	else
		self.ScopeConnectionMap[parentUUID] = {newScopeUUID}
	end
	self.ScopeRegistries[newScopeUUID] = ScopeRegistry

	task.wait(0.1)

	for statementIndex, statementData in pairs( StatementList ) do
		if table.find(WhitelistTypes, statementData.Type) then
			warn('PARSING TYPE : ', statementData.Type)
			self:_CheckAvailableParses( ScopeRegistry, statementData )
		elseif not table.find(IgnoreTypes, statementData.Type) then
			warn('UNSUPPORTED TYPE ; ', statementData.Type, ' under scope ', parentUUID)
			print(statementData)
		end
	end

	return ScopeRegistry
end

function Class:ParseTokens(tokenDictionary)
	self:Clear() -- clear current parsed information

	local rootEnvUUID, rootEnvDictionary = self:_ParseStatementList(false, tokenDictionary.StatementList, false)
	self.RootRegistryID = rootEnvUUID
	self.RootRegistryDict = rootEnvDictionary

	--[[
		print(tokenDictionary)
		local hashName = 'OutputToken_'..sha256(HttpService:JSONEncode(tokenDictionary))

		local outputTokenDictionary = workspace:FindFirstChild(hashName)
		if not outputTokenDictionary then
			outputTokenDictionary = Instance.new('StringValue')
			outputTokenDictionary.Name = hashName
			outputTokenDictionary.Parent = workspace
		end
		outputTokenDictionary.Value = HttpService:JSONEncode(tokenDictionary)
	]]

	return rootEnvUUID, rootEnvDictionary
end

function Class:OutputParse()
	print(string.rep('\n', 2))
	local baseRegistryString = 'REGISTRY %s DEPTH %d || CALL FUNCTIONS (%d), CREATE FUNCTIONS (%d), SET VARIABLES (%d)' -- ,CHANGED VARIABLES (%d)
	for registryUUID, scopeData in pairs( self.ScopeRegistries ) do
		local createdFunctions = self:GetCreatedFunctions(registryUUID)
		local functionCalls = self:GetFunctionCalls(registryUUID)
		local createdVariable = self:GetCreatedVariables(registryUUID)
		print(string.format(
			baseRegistryString,
			registryUUID, scopeData.Depth or 0,
			#functionCalls, #createdFunctions,
			#createdVariable
		))
		print('\n')
		for _, createFunctionData in ipairs( createdFunctions ) do
			print('CREATED FUNCTION ; ', createFunctionData)
		end
		for _, functionCallData in ipairs( functionCalls ) do
			print('FUNCTION CALLED ; ', functionCallData)
		end
		for _, createVariableData in ipairs( createdVariable ) do
			print('VARIABLE CREATED ; ', createVariableData)
		end
		print('\n')
	end
end

-- // Wrappers & EzOfUse // --
function Class:__GetScopeArrayData(referenceTableString, restrictScopeUUID)
	if restrictScopeUUID ~= nil then
		return self.ScopeRegistries[restrictScopeUUID] and self.ScopeRegistries[restrictScopeUUID][referenceTableString]
	end
	local array = {}
	for scopeUUID, scopeData in pairs(self.ScopeRegistries) do
		for _, createdFunction in ipairs(scopeData[referenceTableString]) do
			table.insert(array, createdFunction)
		end
	end
	return array
end

function Class:GetCreatedFunctions(restrictScopeUUID)
	return self:__GetScopeArrayData('_CreatedFunctions', restrictScopeUUID)
end

function Class:GetFunctionCalls(restrictScopeUUID)
	return self:__GetScopeArrayData('_FunctionCalls', restrictScopeUUID)
end

function Class:GetCreatedVariables(restrictScopeUUID)
	return self:__GetScopeArrayData('_CreatedVariables', restrictScopeUUID)
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