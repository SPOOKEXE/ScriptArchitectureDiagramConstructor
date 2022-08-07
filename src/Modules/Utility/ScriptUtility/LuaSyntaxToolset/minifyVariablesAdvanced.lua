local Keywords = require(script.Parent.Keywords)

local generateVariableName = require(script.Parent.generateVariableName)

local function minifyVariables(globalScope, rootScope, renameGlobals)
	-- Variable names and other names that are fixed, that we cannot use
	-- Either these are Lua keywords, or globals that are not assigned to,
	-- that is environmental globals that are assigned elsewhere beyond our 
	-- control.
	local globalUsedNames = {}
	for kw, _ in pairs(Keywords) do
		globalUsedNames[kw] = true
	end

	-- Gather a list of all of the variables that we will rename
	local allVariables = {}
	local allLocalVariables = {}
	do
		-- Add applicable globals
		for _, var in pairs(globalScope) do
			if var.AssignedTo and renameGlobals then
				-- We can try to rename this global since it was assigned to
				-- (and thus presumably initialized) in the script we are 
				-- minifying.
				table.insert(allVariables, var)
			else
				-- We can't rename this global, mark it as an unusable name
				-- and don't add it to the nename list
				globalUsedNames[var.Name] = true
			end
		end

		-- Recursively add locals, we can rename all of those
		local function addFrom(scope)
			for _, var in pairs(scope.VariableList) do
				table.insert(allVariables, var)
				table.insert(allLocalVariables, var)
			end
			for _, childScope in pairs(scope.ChildScopeList) do
				addFrom(childScope)
			end
		end
		addFrom(rootScope)
	end

	-- Add used name arrays to variables
	for _, var in pairs(allVariables) do
		var.UsedNameArray = {}
	end

	-- Sort the least used variables first
	table.sort(allVariables, function(a, b)
		return #a.RenameList < #b.RenameList
	end)

	-- Lazy generator for valid names to rename to
	local nextValidNameIndex = 0
	local varNamesLazy = {}
	local function varIndexToValidVarName(i)
		local name = varNamesLazy[i] 
		if not name then
			repeat
				name = generateVariableName(nextValidNameIndex)
				nextValidNameIndex = nextValidNameIndex + 1
			until not globalUsedNames[name]
			varNamesLazy[i] = name
		end
		return name
	end

	-- For each variable, go to rename it
	for _, var in pairs(allVariables) do
		-- Lazy... todo: Make theis pair a proper for-each-pair-like set of loops 
		-- rather than using a renamed flag.
		var.Renamed = true

		-- Find the first unused name
		local i = 1
		while var.UsedNameArray[i] do
			i = i + 1
		end

		-- Rename the variable to that name
		var:Rename(varIndexToValidVarName(i))

		if var.Scope then
			-- Now we need to mark the name as unusable by any variables:
			--  1) At the same depth that overlap lifetime with this one
			--  2) At a deeper level, which have a reference to this variable in their lifetimes
			--  3) At a shallower level, which are referenced during this variable's lifetime
			for _, otherVar in pairs(allVariables) do
				if not otherVar.Renamed then
					if not otherVar.Scope or otherVar.Scope.Depth < var.Scope.Depth then
						-- Check Global variable (Which is always at a shallower level)
						--  or
						-- Check case 3
						-- The other var is at a shallower depth, is there a reference to it
						-- durring this variable's lifetime?
						for _, refAt in pairs(otherVar.ReferenceLocationList) do
							if refAt >= var.BeginLocation and refAt <= var.ScopeEndLocation then
								-- Collide
								otherVar.UsedNameArray[i] = true
								break
							end
						end

					elseif otherVar.Scope.Depth > var.Scope.Depth then
						-- Check Case 2
						-- The other var is at a greater depth, see if any of the references
						-- to this variable are in the other var's lifetime.
						for _, refAt in pairs(var.ReferenceLocationList) do
							if refAt >= otherVar.BeginLocation and refAt <= otherVar.ScopeEndLocation then
								-- Collide
								otherVar.UsedNameArray[i] = true
								break
							end
						end

					else --otherVar.Scope.Depth must be equal to var.Scope.Depth
						-- Check case 1
						-- The two locals are in the same scope
						-- Just check if the usage lifetimes overlap within that scope. That is, we
						-- can shadow a local variable within the same scope as long as the usages
						-- of the two locals do not overlap.
						if var.BeginLocation < otherVar.EndLocation and
							var.EndLocation > otherVar.BeginLocation
						then
							otherVar.UsedNameArray[i] = true
						end
					end
				end
			end
		else
			-- This is a global var, all other globals can't collide with it, and
			-- any local variable with a reference to this global in it's lifetime
			-- can't collide with it.
			for _, otherVar in pairs(allVariables) do
				if not otherVar.Renamed then
					if otherVar.Type == 'Global' then
						otherVar.UsedNameArray[i] = true
					elseif otherVar.Type == 'Local' then
						-- Other var is a local, see if there is a reference to this global within
						-- that local's lifetime.
						for _, refAt in pairs(var.ReferenceLocationList) do
							if refAt >= otherVar.BeginLocation and refAt <= otherVar.ScopeEndLocation then
								-- Collide
								otherVar.UsedNameArray[i] = true
								break
							end
						end
					else
						assert(false, "unreachable")
					end
				end
			end
		end
	end


	-- -- 
	-- print("Total Variables: "..#allVariables)
	-- print("Total Range: "..rootScope.BeginLocation.."-"..rootScope.EndLocation)
	-- print("")
	-- for _, var in pairs(allVariables) do
	-- 	io.write("`"..var.Name.."':\n\t#symbols: "..#var.RenameList..
	-- 		"\n\tassigned to: "..tostring(var.AssignedTo))
	-- 	if var.Type == 'Local' then
	-- 		io.write("\n\trange: "..var.BeginLocation.."-"..var.EndLocation)
	-- 		io.write("\n\tlocal type: "..var.Info.Type)
	-- 	end
	-- 	io.write("\n\n")
	-- end

	-- -- First we want to rename all of the variables to unique temoraries, so that we can
	-- -- easily use the scope::GetVar function to check whether renames are valid.
	-- local temporaryIndex = 0
	-- for _, var in pairs(allVariables) do
	-- 	var:Rename('_TMP_'..temporaryIndex..'_')
	-- 	temporaryIndex = temporaryIndex + 1
	-- end

	-- For each variable, we need to build a list of names that collide with it

	--
	--error()
end

return minifyVariables