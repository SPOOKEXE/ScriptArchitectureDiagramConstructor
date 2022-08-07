
local visitAst = require(script.Parent.visitAst)

function addVariableInfo(ast)
	local globalVars = {}
	local currentScope = nil

	-- Numbering generator for variable lifetimes
	local locationGenerator = 0
	local function markLocation()
		locationGenerator = locationGenerator + 1
		return locationGenerator
	end

	-- Scope management
	local function pushScope()
		currentScope = {
			ParentScope = currentScope;
			ChildScopeList = {};
			VariableList = {};
			BeginLocation = markLocation();
		}
		if currentScope.ParentScope then
			currentScope.Depth = currentScope.ParentScope.Depth + 1
			table.insert(currentScope.ParentScope.ChildScopeList, currentScope)
		else
			currentScope.Depth = 1
		end
		function currentScope:GetVar(varName)
			for _, var in pairs(self.VariableList) do
				if var.Name == varName then
					return var
				end
			end
			if self.ParentScope then
				return self.ParentScope:GetVar(varName)
			else
				for _, var in pairs(globalVars) do
					if var.Name == varName then
						return var
					end
				end
			end
		end
	end
	local function popScope()
		local scope = currentScope

		-- Mark where this scope ends
		scope.EndLocation = markLocation()

		-- Mark all of the variables in the scope as ending there
		for _, var in pairs(scope.VariableList) do
			var.ScopeEndLocation = scope.EndLocation
		end

		-- Move to the parent scope
		currentScope = scope.ParentScope

		return scope
	end
	pushScope() -- push initial scope

	-- Add / reference variables
	local function addLocalVar(name, setNameFunc, localInfo)
		assert(localInfo, "Misisng localInfo")
		assert(name, "Missing local var name")
		local var = {
			Type = 'Local';
			Name = name;
			RenameList = {setNameFunc};
			AssignedTo = false;
			Info = localInfo;
			UseCount = 0;
			Scope = currentScope;
			BeginLocation = markLocation();
			EndLocation = markLocation();
			ReferenceLocationList = {markLocation()};
		}
		function var:Rename(newName)
			self.Name = newName
			for _, renameFunc in pairs(self.RenameList) do
				renameFunc(newName)
			end
		end
		function var:Reference()
			self.UseCount = self.UseCount + 1
		end
		table.insert(currentScope.VariableList, var)
		return var
	end
	local function getGlobalVar(name)
		for _, var in pairs(globalVars) do
			if var.Name == name then
				return var
			end
		end
		local var = {
			Type = 'Global';
			Name = name;
			RenameList = {};
			AssignedTo = false;
			UseCount = 0;
			Scope = nil; -- Globals have no scope
			BeginLocation = markLocation();
			EndLocation = markLocation();
			ReferenceLocationList = {};
		}
		function var:Rename(newName)
			self.Name = newName
			for _, renameFunc in pairs(self.RenameList) do
				renameFunc(newName)
			end
		end
		function var:Reference()
			self.UseCount = self.UseCount + 1
		end
		table.insert(globalVars, var)
		return var
	end
	local function addGlobalReference(name, setNameFunc)
		assert(name, "Missing var name")
		local var = getGlobalVar(name)
		table.insert(var.RenameList, setNameFunc)
		return var
	end
	local function getLocalVar(scope, name)
		-- First search this scope
		-- Note: Reverse iterate here because Lua does allow shadowing a local
		--       within the same scope, and the later defined variable should
		--       be the one referenced.
		for i = #scope.VariableList, 1, -1 do
			if scope.VariableList[i].Name == name then
				return scope.VariableList[i]
			end
		end

		-- Then search parent scope
		if scope.ParentScope then
			local var = getLocalVar(scope.ParentScope, name)
			if var then
				return var
			end
		end

		-- Then 
		return nil
	end
	local function referenceVariable(name, setNameFunc)
		assert(name, "Missing var name")
		local var = getLocalVar(currentScope, name)
		if var then
			table.insert(var.RenameList, setNameFunc)
		else
			var = addGlobalReference(name, setNameFunc)
		end
		-- Update the end location of where this variable is used, and
		-- add this location to the list of references to this variable.
		local curLocation = markLocation()
		var.EndLocation = curLocation
		table.insert(var.ReferenceLocationList, var.EndLocation)
		return var
	end

	local visitor = {}
	visitor.FunctionLiteral = {
		-- Function literal adds a new scope and adds the function literal arguments
		-- as local variables in the scope.
		Pre = function(expr)
			pushScope()
			for index, ident in pairs(expr.ArgList) do
				local var = addLocalVar(ident.Source, function(name)
					ident.Source = name
				end, {
					Type = 'Argument';
					Index = index;
				})
			end
		end;
		Post = function(expr)
			popScope()
		end;
	}
	visitor.VariableExpr = function(expr)
		-- Variable expression references from existing local varibales
		-- in the current scope, annotating the variable usage with variable
		-- information.
		expr.Variable = referenceVariable(expr.Token.Source, function(newName)
			expr.Token.Source = newName
		end)
	end
	visitor.StatList = {
		-- StatList adds a new scope
		Pre = function(stat)
			pushScope()
		end;
		Post = function(stat)
			-- Ugly hack for repeat until statements. They use a statlist in their body,
			-- but we have to wait to pop that stat list until the until conditional
			-- expression has been visited rather than popping where the textual contents 
			-- of the statlist actually end. (As is the case for all the other places a 
			-- stat list can appear)
			if not stat.SkipPop then
				popScope()
			end
		end;
	}
	visitor.LocalVarStat = {
		Post = function(stat)
			-- Local var stat adds the local variables to the current scope as locals
			-- We need to visit the subexpressions first, because these new locals
			-- will not be in scope for the initialization value expressions. That is:
			--  `local bar = bar + 1`
			-- Is valid code
			for varNum, ident in pairs(stat.VarList) do
				addLocalVar(ident.Source, function(name)
					stat.VarList[varNum].Source = name
				end, {
					Type = 'Local';
				})
			end		
		end;
	}
	visitor.LocalFunctionStat = {
		Pre = function(stat)
			-- Local function stat adds the function itself to the current scope as
			-- a local variable, and creates a new scope with the function arguments
			-- as local variables.
			addLocalVar(stat.FunctionStat.NameChain[1].Source, function(name)
				stat.FunctionStat.NameChain[1].Source = name
			end, {
				Type = 'LocalFunction';
			})
			pushScope()
			for index, ident in pairs(stat.FunctionStat.ArgList) do
				addLocalVar(ident.Source, function(name)
					ident.Source = name
				end, {
					Type = 'Argument';
					Index = index;
				})
			end
		end;
		Post = function()
			popScope()
		end;
	}
	visitor.FunctionStat = {
		Pre = function(stat) 			
			-- Function stat adds a new scope containing the function arguments
			-- as local variables.
			-- A function stat may also assign to a global variable if it is in
			-- the form `function foo()` with no additional dots/colons in the 
			-- name chain.
			-- **BUGFIX**: If `function foo()` is done when there is already a local
			-- variable `foo` in scope, it will assign to the local variable instead
			-- of a global one! I did not know this when writing it initially.
			local nameChain = stat.NameChain
			local var;
			if #nameChain == 1 then
				-- If there is only one item in the name chain, then the first item
				-- is a reference to a variable
				if getLocalVar(currentScope, nameChain[1].Source) then
					-- If there is a local of that name, then it's a reference to that local
					var = referenceVariable(nameChain[1].Source, function(name)
						nameChain[1].Source = name
					end)
				else
					-- Otherwise, it's a reference to a global
					var = addGlobalReference(nameChain[1].Source, function(name)
						nameChain[1].Source = name
					end)
				end
			else
				var = referenceVariable(nameChain[1].Source, function(name)
					nameChain[1].Source = name
				end)
			end
			var.AssignedTo = true
			pushScope()
			for index, ident in pairs(stat.ArgList) do
				addLocalVar(ident.Source, function(name)
					ident.Source = name
				end, {
					Type = 'Argument';
					Index = index;
				})
			end
		end;
		Post = function()
			popScope()
		end;
	}
	visitor.GenericForStat = {
		Pre = function(stat)
			-- Generic fors need an extra scope holding the range variables
			-- Need a custom visitor so that the generator expressions can be
			-- visited before we push a scope, but the body can be visited
			-- after we push a scope.
			for _, ex in pairs(stat.GeneratorList) do
				visitAst(ex, visitor)
			end
			pushScope()
			for index, ident in pairs(stat.VarList) do
				addLocalVar(ident.Source, function(name)
					ident.Source = name
				end, {
					Type = 'ForRange';
					Index = index;
				})
			end
			visitAst(stat.Body, visitor)
			popScope()
			return true -- Custom visit
		end;
	}
	visitor.NumericForStat = {
		Pre = function(stat)
			-- Numeric fors need an extra scope holding the range variables
			-- Need a custom visitor so that the generator expressions can be
			-- visited before we push a scope, but the body can be visited
			-- after we push a scope.
			for _, ex in pairs(stat.RangeList) do
				visitAst(ex, visitor)
			end
			pushScope()
			for index, ident in pairs(stat.VarList) do
				addLocalVar(ident.Source, function(name)
					ident.Source = name
				end, {
					Type = 'ForRange';
					Index = index;
				})
			end
			visitAst(stat.Body, visitor)
			popScope()
			return true	-- Custom visit
		end;
	}
	visitor.RepeatStat = {
		Pre = function(stat)
			-- Extend the scope of the body statement up to the current point, that is
			-- up to the point *after* the until condition, since the body variables are
			-- still in scope through that condition.
			-- The SkipPop flag is used by visitor.StatList to accomplish this.
			stat.Body.SkipPop = true
		end;
		Post = function(stat)
			-- Now that the conditional exprssion has been visited, it's safe to pop the
			-- body scope
			popScope()
		end;
	}
	visitor.AssignmentStat = {
		Post = function(stat)
			-- For an assignment statement we need to mark the
			-- "assigned to" flag on variables.
			for _, ex in pairs(stat.Lhs) do
				if ex.Variable then
					ex.Variable.AssignedTo = true
				end
			end
		end;
	}

	visitAst(ast, visitor)

	return globalVars, popScope()
end

return addVariableInfo