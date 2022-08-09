local HttpService = game:GetService('HttpService')

local SampleData = require(script.Parent.Data)

local ScopeConnectionMap = {}
local ScopeRegistries = {}

local SkipTypeList = {'ReturnStat', 'GenericForStat', 'IfStat', 'AssignmentStat 1'}

local ParseHandlers = {
	LocalVarStat = function(scopeRegistry, statementIndex, data, depth)
		table.insert(scopeRegistry.SetVariableNodes, {statementIndex, data.Type, data, depth})
	end,
	FunctionStat = function(scopeRegistry, statementIndex, data, depth)
		table.insert(scopeRegistry.CreateFunctionNodes, {statementIndex, data.Type, data, depth})
	end,
	CallExprStat = function(scopeRegistry, statementIndex, data, depth)
		table.insert(scopeRegistry.CallFunctionNodes, {statementIndex, data.Type, data, depth})
	end,
}

function ParseStatementList(parentRegistryUUID, StatementList, depth)
	print('Step Depth; ', depth or 0)

	local currentRegistryUUID = HttpService:GenerateGUID(false)
	if ScopeConnectionMap[parentRegistryUUID] then
		table.insert(ScopeConnectionMap[parentRegistryUUID], currentRegistryUUID)
	else
		ScopeConnectionMap[parentRegistryUUID] = {currentRegistryUUID}
	end

	local scopeReg = {
		Depth = depth,
		SetVariableNodes = { },
		CreateFunctionNodes = { },
		CallFunctionNodes = { },
	}

	ScopeRegistries[currentRegistryUUID] = scopeReg

	for statementIndex, data in pairs( StatementList ) do
		local parsed = true
		if ParseHandlers[data.Type] then
			print('Parsed ; ', statementIndex, data.Type)
			ParseHandlers[data.Type](scopeReg, statementIndex, data, depth or 0)
		elseif table.find(SkipTypeList, data.Type) then
			print('Skipped ; ', data.Type, statementIndex)
			continue
		else
			parsed = false
		end
		if data.Body and data.Body.StatementList then
			parsed = true
			local _ = ParseStatementList(currentRegistryUUID, data.Body.StatementList, (depth or 0) + 1)
		end
		if not parsed then
			warn('Unsupported Type ; ', data.Type, statementIndex)
		end
	end

	return scopeReg
end

ParseStatementList(false, SampleData.StatementList) -- ModuleScript parse [Type : StatList]

print(ScopeConnectionMap)
local baseRegistryString = 'REGISTRY %s DEPTH %d || CALL FUNCTIONS (%d), CREATE FUNCTIONS (%d), SET VARIABLE (%d)'
for registryUUID, data in pairs( ScopeRegistries ) do
	print( string.format(baseRegistryString, registryUUID, data.Depth or 0, #data.CallFunctionNodes, #data.CreateFunctionNodes, #data.SetVariableNodes) )
end

print(string.rep('\n', 10))

for registryID, registryData in pairs(ScopeRegistries) do
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
