
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

function Class:ParseStatementList( ScopeUUID, StatementList, Depth )
	--[[
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
	]]
end

function Class:ParseTokens(tokenDictionary)
	self:Clear() -- clear current parsed information
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

		self:Reset()
		local rootEnvDictionary = self:ParseStatementList(false, tokenDictionary.StatementList, false)
		self.RootScopeRegistry = rootEnvDictionary
		return rootEnvDictionary
	]]
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

function Class:GetVariableAssignments(restrictScopeUUID)
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