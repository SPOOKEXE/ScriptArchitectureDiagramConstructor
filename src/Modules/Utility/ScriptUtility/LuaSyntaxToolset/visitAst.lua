

local formatTable = require(script.Parent.formatTable)
local lookupify = require(script.Parent.lookupify)

function visitAst(ast, visitors)
	local ExprType = lookupify{
		'BinopExpr'; 'UnopExpr'; 
		'NumberLiteral'; 'StringLiteral'; 'NilLiteral'; 'BooleanLiteral'; 'VargLiteral';
		'FieldExpr'; 'IndexExpr';
		'MethodExpr'; 'CallExpr';
		'FunctionLiteral';
		'VariableExpr';
		'ParenExpr';
		'TableLiteral';
	}

	local StatType = lookupify{
		'StatList';
		'BreakStat';
		'ReturnStat';
		'LocalVarStat';
		'LocalFunctionStat';
		'FunctionStat';
		'RepeatStat';
		'GenericForStat';
		'NumericForStat';
		'WhileStat';
		'DoStat';
		'IfStat';
		'CallExprStat';
		'AssignmentStat';
	}

	-- Check for typos in visitor construction
	for visitorSubject, visitor in pairs(visitors) do
		if not StatType[visitorSubject] and not ExprType[visitorSubject] then
			error("Invalid visitor target: `"..visitorSubject.."`")
		end
	end

	-- Helpers to call visitors on a node
	local function preVisit(exprOrStat)
		local visitor = visitors[exprOrStat.Type]
		if type(visitor) == 'function' then
			return visitor(exprOrStat)
		elseif visitor and visitor.Pre then
			return visitor.Pre(exprOrStat)
		end
	end
	local function postVisit(exprOrStat)
		local visitor = visitors[exprOrStat.Type]
		if visitor and type(visitor) == 'table' and visitor.Post then
			return visitor.Post(exprOrStat)
		end
	end

	local visitExpr, visitStat, visitType;

	visitExpr = function(expr)
		if preVisit(expr) then
			-- Handler did custom child iteration or blocked child iteration
			return
		end
		if expr.Type == 'BinopExpr' then
			visitExpr(expr.Lhs)
			visitExpr(expr.Rhs)
		elseif expr.Type == 'UnopExpr' then
			visitExpr(expr.Rhs)
		elseif expr.Type == 'NumberLiteral' or expr.Type == 'StringLiteral' or 
			expr.Type == 'NilLiteral' or expr.Type == 'BooleanLiteral' or 
			expr.Type == 'VargLiteral' 
		then
			-- No children to visit, single token literals
		elseif expr.Type == 'FieldExpr' then
			visitExpr(expr.Base)
		elseif expr.Type == 'IndexExpr' then
			visitExpr(expr.Base)
			visitExpr(expr.Index)
		elseif expr.Type == 'MethodExpr' or expr.Type == 'CallExpr' then
			visitExpr(expr.Base)
			if expr.FunctionArguments.CallType == 'ArgCall' then
				for index, argExpr in pairs(expr.FunctionArguments.ArgList) do
					visitExpr(argExpr)
				end
			elseif expr.FunctionArguments.CallType == 'TableCall' then
				visitExpr(expr.FunctionArguments.TableExpr)
			end
		elseif expr.Type == 'FunctionLiteral' then
			visitStat(expr.Body)
		elseif expr.Type == 'VariableExpr' then
			-- No children to visit
		elseif expr.Type == 'ParenExpr' then
			visitExpr(expr.Expression)
		elseif expr.Type == 'TableLiteral' then
			for index, entry in pairs(expr.EntryList) do
				if entry.EntryType == 'Field' then
					visitExpr(entry.Value)
				elseif entry.EntryType == 'Index' then
					visitExpr(entry.Index)
					visitExpr(entry.Value)
				elseif entry.EntryType == 'Value' then
					visitExpr(entry.Value)
				else
					assert(false, "unreachable")
				end
			end
		else
			assert(false, "unreachable, type: "..expr.Type..":"..formatTable(expr))
		end
		postVisit(expr)
	end
	
	visitType = function(typeExpr)
		if preVisit(typeExpr) then
			-- Handler did custom child iteration or blocked child iteration
			return
		end
		if typeExpr.Type == 'BasicType' then
			if typeExpr.Token_OpenAngle then
				for _, typeArg in pairs(typeExpr.GenericArgumentList) do
					visitType(typeArg)
				end
			end
		elseif typeExpr.Type == 'TypeofType' then
			visitExpr(typeExpr.Expression)
		elseif typeExpr.Type == 'FunctionType' then
			visitType(typeExpr.ArgType)
			visitType(typeExpr.ReturnType)
		elseif typeExpr.Type == 'TupleType' then
			for index, subTypeExpr in pairs(typeExpr.TypeList) do
				visitType(subTypeExpr)
			end
		elseif typeExpr.Type == 'TableType' then
			for index, record in pairs(typeExpr.RecordList) do
				if record.Type == 'Type' then
					visitType(record.KeyType)
					visitType(record.ValueType)
				elseif record.Type == 'Name' then
					visitType(record.ValueType)
				else
					error("Unexpected record in table type: "..formatTable(record))
				end
			end
		elseif typeExpr.Type == 'OptionalType' then
			visitType(typeExpr.BaseType)
		elseif typeExpr.Type == 'UnionType' or typeExpr.Type == 'IntersectionType' then
			for index, subTypeExpr in pairs(typeExpr.TypeList) do
				visitType(subTypeExpr)
			end
		else
			error("Bad typeExpr type in: "..formatTable(typeExpr))
		end
	end

	visitStat = function(stat)
		if preVisit(stat) then
			-- Handler did custom child iteration or blocked child iteration
			return
		end
		if stat.Type == 'StatList' then
			for index, ch in pairs(stat.StatementList) do
				visitStat(ch)
			end
		elseif stat.Type == 'BreakStat' then
			-- No children to visit
		elseif stat.Type == 'ContinueStat' then
			-- No children to visit
		elseif stat.Type == 'ReturnStat' then
			for index, expr in pairs(stat.ExprList) do
				visitExpr(expr)
			end
		elseif stat.Type == 'LocalVarStat' then
			for _, typeExpr in pairs(stat.TypeList) do
				visitType(typeExpr)
			end
			if stat.Token_Equals then
				for index, expr in pairs(stat.ExprList) do
					visitExpr(expr)
				end
			end
		elseif stat.Type == 'LocalFunctionStat' then
			for _, typeExpr in pairs(stat.FunctionStat.ArgTypeList) do
				visitType(typeExpr)
			end
			if stat.FunctionStat.ReturnType then
				visitType(stat.FunctionStat.ReturnType)
			end
			visitStat(stat.FunctionStat.Body)
		elseif stat.Type == 'FunctionStat' then
			for _, typeExpr in pairs(stat.ArgTypeList) do
				visitType(typeExpr)
			end
			if stat.ReturnType then
				visitType(stat.ReturnType)
			end
			visitStat(stat.Body)
		elseif stat.Type == 'RepeatStat' then
			visitStat(stat.Body)
			visitExpr(stat.Condition)
		elseif stat.Type == 'GenericForStat' then
			for _, typeExpr in pairs(stat.VarTypeList) do
				visitType(typeExpr)
			end
			for index, expr in pairs(stat.GeneratorList) do
				visitExpr(expr)
			end
			visitStat(stat.Body)
		elseif stat.Type == 'NumericForStat' then
			for _, typeExpr in pairs(stat.VarTypeList) do
				visitType(typeExpr)
			end
			for index, expr in pairs(stat.RangeList) do
				visitExpr(expr)
			end
			visitStat(stat.Body)
		elseif stat.Type == 'WhileStat' then
			visitExpr(stat.Condition)
			visitStat(stat.Body)
		elseif stat.Type == 'DoStat' then
			visitStat(stat.Body)
		elseif stat.Type == 'IfStat' then
			visitExpr(stat.Condition)
			visitStat(stat.Body)
			for _, clause in pairs(stat.ElseClauseList) do
				if clause.Condition then
					visitExpr(clause.Condition)
				end
				visitStat(clause.Body)
			end
		elseif stat.Type == 'CallExprStat' then
			visitExpr(stat.Expression)
		elseif stat.Type == 'AssignmentStat' then
			for index, ex in pairs(stat.Lhs) do
				visitExpr(ex)
			end
			for index, ex in pairs(stat.Rhs) do
				visitExpr(ex)
			end
		elseif stat.Type == 'TypeStat' then
			visitType(stat.AliasedType)
		else
			assert(false, "unreachable, "..tostring(stat.Type))
		end	
		postVisit(stat)
	end

	if StatType[ast.Type] then
		visitStat(ast)
	else
		visitExpr(ast)
	end
end

return visitAst