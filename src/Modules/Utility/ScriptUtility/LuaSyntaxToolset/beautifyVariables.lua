local function beautifyVariables(globalScope, rootScope, renameGlobals)
	local externalGlobals = {}
	for _, var in pairs(globalScope) do
		if not var.AssignedTo or not renameGlobals then
			externalGlobals[var.Name] = true
		end
	end

	local localNumber = 1
	local globalNumber = 1

	local function setVarName(var, name)
		var.Name = name
		for _, setter in pairs(var.RenameList) do
			setter(name)
		end
	end

	if renameGlobals then
		for _, var in pairs(globalScope) do
			if var.AssignedTo then
				setVarName(var, 'G_'..globalNumber..'_')
				globalNumber = globalNumber + 1
			end
		end
	end

	local function modify(scope)
		for _, var in pairs(scope.VariableList) do
			local name = 'L_'..localNumber..'_'
			if var.Info.Type == 'Argument' then
				name = name..'arg'..var.Info.Index
			elseif var.Info.Type == 'LocalFunction' then
				name = name..'func'
			elseif var.Info.Type == 'ForRange' then
				name = name..'forvar'..var.Info.Index
			end
			setVarName(var, name)
			localNumber = localNumber + 1
		end
		for _, scope in pairs(scope.ChildScopeList) do
			modify(scope)
		end
	end
	modify(rootScope)
end

return beautifyVariables