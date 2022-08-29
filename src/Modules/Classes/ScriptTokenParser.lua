local HttpService = game:GetService("HttpService")

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

function Class:_ParseFunctionArguments( scopeRegistry, argumentList )
	print('Parse Function Arguments - List Length: ', #argumentList)
	-- print(scopeRegistry, argumentList)
	self:_ParseStatementList(scopeRegistry.ScopeUUID, argumentList, scopeRegistry.Depth + 1)
end

local IgnoreTypes = {'ReturnStat', 'GenericForStat', 'IfStat', 'AssignmentStat 1', 'StringLiteral', 'VargLiteral'}
function Class:_ParseStatementList( parentUUID, StatementList, Depth )
	Depth = Depth or 0
	print('Parent ID: ', parentUUID)
	print('Step Depth; ', Depth)

	local newScopeUUID = HttpService:GenerateGUID(false)
	print('New Scope ID: ', newScopeUUID)

	local ScopeRegistry = {
		_CreatedFunctions = {},
		_CreatedVariables = {},
		_FunctionCalls = {},

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

	for statementIndex, statementData in pairs( StatementList ) do
		print('Parsing ; ', statementIndex, statementData.Type, Depth)
		if statementData.Type == 'CallExprStat' then
			-- print(statementData)
			self:_ParseFunctionArguments( ScopeRegistry, statementData.Expression.FunctionArguments.ArgList )
		elseif statementData.Type == 'FunctionStat' or statementData.Type == 'LocalFunctionStat' then
			if statementData.FunctionStat then
				warn('(Local)FunctionStat has a FunctionStat table!')
				self:_ParseStatementList( newScopeUUID, statementData.FunctionStat.Body.StatementList, Depth + 1 )
			end
			if statementData.Body then
				warn('(Local)FunctionStat has a Body table!')
				self:_ParseStatementList( newScopeUUID, statementData.Body.StatementList, Depth + 1 )
			end
		elseif statementData.Type == 'StatList' then
			self:_ParseStatementList( newScopeUUID, statementData.StatementList, Depth + 1 )
		elseif statementData.Type == 'VariableExpr' then
			warn('Got VariableExpr || ', statementIndex)--, statementData)
		elseif statementData.Type == 'LocalVarStat' then
			warn('Got LocalVarStat || ', statementIndex)--, statementData)
		elseif not table.find(IgnoreTypes, statementData.Type) then
			warn('Unsupported Type ; ', statementData.Type, ' under scope ', parentUUID)
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
	local baseRegistryString = 'REGISTRY %s DEPTH %d || CALL FUNCTIONS (%d), CREATE FUNCTIONS (%d), SET VARIABLES (%d), CHANGED VARIABLES (%d)'
	for registryUUID, scopeData in pairs( self.ScopeRegistries ) do
		local createdFunctions = self:GetCreatedFunctions(registryUUID)
		local functionCalls = self:GetFunctionCalls(registryUUID)
		local createdVariable = self:GetCreatedVariables(registryUUID)
		local variableAssignments = self:GetVariableAssignments(registryUUID)
		print(string.format(
			baseRegistryString,
			registryUUID, scopeData.Depth or 0,
			#functionCalls, #createdFunctions,
			#createdVariable, #variableAssignments
		))
		print(string.rep('\n', 2))
		for _, createFunctionData in ipairs( createdFunctions ) do
			print('CREATED FUNCTION ; ', unpack(createFunctionData))
		end
		for _, functionCallData in ipairs( functionCalls ) do
			print('FUNCTION CALLED ; ', unpack(functionCallData))
		end
		for _, createVariableData in ipairs( createdVariable ) do
			print('VARIABLE CREATED ; ', unpack(createVariableData))
		end
		print(string.rep('\n', 2))
	end
end

-- // Wrappers & EzOfUse // --
function Class:GetCreatedFunctions(restrictScopeUUID)
	error('Not Implemented')
end

function Class:GetFunctionCalls(restrictScopeUUID)
	error('Not Implemented')
end

function Class:GetCreatedVariables(restrictScopeUUID)
	error('Not Implemented')
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