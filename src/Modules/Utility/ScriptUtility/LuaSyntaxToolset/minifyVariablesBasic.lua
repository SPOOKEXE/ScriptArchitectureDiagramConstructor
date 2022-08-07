local Keywords = require(script.Parent.Keywords)

local generateVariableName = require(script.Parent.generateVariableName)

local function minifyVariables(globalScope, rootScope)
	-- externalGlobals is a set of global variables that have not been assigned to, that is
	-- global variables defined "externally to the script". We are not going to be renaming 
	-- those, and we have to make sure that we don't collide with them when renaming 
	-- things so we keep track of them in this set.
	local externalGlobals = {}

	-- First we want to rename all of the variables to unique temoraries, so that we can
	-- easily use the scope::GetVar function to check whether renames are valid.
	local temporaryIndex = 0
	for _, var in pairs(globalScope) do
		if var.AssignedTo then
			var:Rename('_TMP_'..temporaryIndex..'_')
			temporaryIndex = temporaryIndex + 1
		else
			-- Not assigned to, external global
			externalGlobals[var.Name] = true
		end
	end
	local function temporaryRename(scope)
		for _, var in pairs(scope.VariableList) do
			var:Rename('_TMP_'..temporaryIndex..'_')
			temporaryIndex = temporaryIndex + 1
		end
		for _, childScope in pairs(scope.ChildScopeList) do
			temporaryRename(childScope)
		end
	end

	-- Now we go through renaming, first do globals, we probably want them
	-- to have shorter names in general.
	-- TODO: Rename all vars based on frequency patterns, giving variables
	--       used more shorter names.
	local nextFreeNameIndex = 0
	for _, var in pairs(globalScope) do
		if var.AssignedTo then
			local varName = ''
			repeat
				varName = generateVariableName(nextFreeNameIndex)
				nextFreeNameIndex = nextFreeNameIndex + 1
			until not Keywords[varName] and not externalGlobals[varName]
			var:Rename(varName)
		end
	end

	-- Now rename all local vars
	rootScope.FirstFreeName = nextFreeNameIndex
	local function doRenameScope(scope)
		for _, var in pairs(scope.VariableList) do
			local varName = ''
			repeat
				varName = generateVariableName(scope.FirstFreeName)
				scope.FirstFreeName = scope.FirstFreeName + 1
			until not Keywords[varName] and not externalGlobals[varName]
			var:Rename(varName)
		end
		for _, childScope in pairs(scope.ChildScopeList) do
			childScope.FirstFreeName = scope.FirstFreeName
			doRenameScope(childScope)
		end
	end
	doRenameScope(rootScope)
end

return minifyVariables