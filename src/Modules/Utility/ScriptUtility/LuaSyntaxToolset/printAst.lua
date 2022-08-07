
local formatTable = require(script.Parent.formatTable)

-- Prints out an AST to a string
local function printAst(ast)

	local printStat, printExpr, printType;

	local buffer = ''

	local function printt(tk)
		if not tk.LeadingWhite or not tk.Source then
			error("Bad token: "..formatTable(tk))
		end
		buffer = buffer..tk.LeadingWhite..tk.Source
	end

	printExpr = function(expr)
		if expr.Type == 'BinopExpr' then
			printExpr(expr.Lhs)
			printt(expr.Token_Op)
			printExpr(expr.Rhs)
		elseif expr.Type == 'UnopExpr' then
			printt(expr.Token_Op)
			printExpr(expr.Rhs)
		elseif expr.Type == 'NumberLiteral' or expr.Type == 'StringLiteral' or 
			expr.Type == 'NilLiteral' or expr.Type == 'BooleanLiteral' or 
			expr.Type == 'VargLiteral' 
		then
			-- Just print the token
			printt(expr.Token)
		elseif expr.Type == 'FieldExpr' then
			printExpr(expr.Base)
			printt(expr.Token_Dot)
			printt(expr.Field)
		elseif expr.Type == 'IndexExpr' then
			printExpr(expr.Base)
			printt(expr.Token_OpenBracket)
			printExpr(expr.Index)
			printt(expr.Token_CloseBracket)
		elseif expr.Type == 'MethodExpr' or expr.Type == 'CallExpr' then
			printExpr(expr.Base)
			if expr.Type == 'MethodExpr' then
				printt(expr.Token_Colon)
				printt(expr.Method)
			end
			if expr.FunctionArguments.CallType == 'StringCall' then
				printt(expr.FunctionArguments.Token)
			elseif expr.FunctionArguments.CallType == 'ArgCall' then
				printt(expr.FunctionArguments.Token_OpenParen)
				for index, argExpr in pairs(expr.FunctionArguments.ArgList) do
					printExpr(argExpr)
					local sep = expr.FunctionArguments.Token_CommaList[index]
					if sep then
						printt(sep)
					end
				end
				printt(expr.FunctionArguments.Token_CloseParen)
			elseif expr.FunctionArguments.CallType == 'TableCall' then
				printExpr(expr.FunctionArguments.TableExpr)
			end
		elseif expr.Type == 'FunctionLiteral' then
			printt(expr.Token_Function)
			printt(expr.Token_OpenParen)
			for index, arg in pairs(expr.ArgList) do
				printt(arg)
				local colon = expr.Token_ArgColonList[index]
				if colon then
					printt(colon)
					printType(expr.ArgTypeList[index])
				end
				local comma = expr.Token_ArgCommaList[index]
				if comma then
					printt(comma)
				end
			end
			if expr.Token_Varg then
				printt(expr.Token_Varg)
			end
			printt(expr.Token_CloseParen)
			if expr.Token_Colon then
				printt(expr.Token_Colon)
				printType(expr.ReturnType)
			end
			printStat(expr.Body)
			printt(expr.Token_End)
		elseif expr.Type == 'VariableExpr' then
			printt(expr.Token)
		elseif expr.Type == 'ParenExpr' then
			printt(expr.Token_OpenParen)
			printExpr(expr.Expression)
			printt(expr.Token_CloseParen)
		elseif expr.Type == 'TableLiteral' then
			printt(expr.Token_OpenBrace)
			for index, entry in pairs(expr.EntryList) do
				if entry.EntryType == 'Field' then
					printt(entry.Field)
					printt(entry.Token_Equals)
					printExpr(entry.Value)
				elseif entry.EntryType == 'Index' then
					printt(entry.Token_OpenBracket)
					printExpr(entry.Index)
					printt(entry.Token_CloseBracket)
					printt(entry.Token_Equals)
					printExpr(entry.Value)
				elseif entry.EntryType == 'Value' then
					printExpr(entry.Value)
				else
					assert(false, "unreachable")
				end
				local sep = expr.Token_SeparatorList[index]
				if sep then
					printt(sep)
				end
			end
			printt(expr.Token_CloseBrace)
		else
			assert(false, "unreachable, type: "..expr.Type..":"..formatTable(expr))
		end
	end
	
	printType = function(typeExpr)
		if typeExpr.Type == 'BasicType' then
			for i, ident in pairs(typeExpr.IdentList) do
				printt(ident)
				if typeExpr.Token_IdentDotList[i] then
					printt(typeExpr.Token_IdentDotList[i])
				end
			end
			if typeExpr.Token_OpenAngle then
				printt(typeExpr.Token_OpenAngle)
				for index, typeArg in pairs(typeExpr.GenericArgumentList) do
					printType(typeArg)
					if typeExpr.Token_GenericArgumentCommaList[index] then
						printt(typeExpr.Token_GenericArgumentCommaList[index])
					end
				end
				printt(typeExpr.Token_CloseAngle)
			end
		elseif typeExpr.Type == 'NilType' then
			printt(typeExpr.Token_Nil)
		elseif typeExpr.Type == 'TypeofType' then
			printt(typeExpr.Token_Typeof)
			printt(typeExpr.Token_OpenParen)
			printExpr(typeExpr.Expression)
			printt(typeExpr.Token_CloseParen)
		elseif typeExpr.Type == 'FunctionType' then
			printType(typeExpr.ArgType)
			printt(typeExpr.Token_Arrow)
			printType(typeExpr.ReturnType)
		elseif typeExpr.Type == 'TupleType' then	
			printt(typeExpr.Token_OpenParen)
			for index, subTypeExpr in pairs(typeExpr.TypeList) do
				printType(subTypeExpr)
				if typeExpr.Token_CommaList[index] then
					printt(typeExpr.Token_CommaList[index])
				end
			end
			printt(typeExpr.Token_CloseParen)
		elseif typeExpr.Type == 'TableType' then
			printt(typeExpr.Token_OpenBrace)
			for index, record in pairs(typeExpr.RecordList) do
				if record.Type == 'Type' then
					printt(record.Token_OpenBracket)
					printType(record.KeyType)
					printt(record.Token_CloseBracket)
					printt(record.Token_Colon)
					printType(record.ValueType)
				elseif record.Type == 'Name' then
					printt(record.Ident)
					printt(record.Token_Colon)
					printType(record.ValueType)
				else
					error("Unexpected record in table type: "..formatTable(record))
				end
				if typeExpr.Token_CommaList[index] then
					printt(typeExpr.Token_CommaList[index])
				end
			end
			printt(typeExpr.Token_CloseBrace)
		elseif typeExpr.Type == 'OptionalType' then
			printType(typeExpr.BaseType)
			printt(typeExpr.Token_QuestionMark)
		elseif typeExpr.Type == 'UnionType' or typeExpr.Type == 'IntersectionType' then
			for index, subTypeExpr in pairs(typeExpr.TypeList) do
				printType(subTypeExpr)
				if typeExpr.Token_CombinerList[index] then
					printt(typeExpr.Token_CombinerList[index])
				end
			end
		else
			assert(false, "unreachable, type: "..typeExpr.Type..":"..formatTable(typeExpr))
		end
	end

	printStat = function(stat)
		if stat.Type == 'StatList' then
			for index, ch in pairs(stat.StatementList) do
				printStat(ch)
				local semis = stat.SemicolonList[index]
				if semis then
					for _, semi in pairs(semis) do
						printt(semi)
					end
				end
			end
		elseif stat.Type == 'BreakStat' then
			printt(stat.Token_Break)
		elseif stat.Type == 'ContinueStat' then
			printt(stat.Token_Continue)
		elseif stat.Type == 'TypeStat' then
			if stat.Token_Export then
				printt(stat.Token_Export)
			end
			printt(stat.Token_Type)
			printt(stat.Ident)
			if stat.Token_OpenAngle then
				printt(stat.Token_OpenAngle)
				for index, ident in pairs(stat.GenericTypeList) do
					printt(ident)
					if stat.Token_GenericTypeCommaList[index] then
						printt(stat.Token_GenericTypeCommaList[index])
					end
				end
				printt(stat.Token_CloseAngle)
			end
			printt(stat.Token_Equals)
			printType(stat.AliasedType)
		elseif stat.Type == 'ReturnStat' then
			printt(stat.Token_Return)
			for index, expr in pairs(stat.ExprList) do
				printExpr(expr)
				if stat.Token_CommaList[index] then
					printt(stat.Token_CommaList[index])
				end
			end
		elseif stat.Type == 'LocalVarStat' then
			printt(stat.Token_Local)
			for index, var in pairs(stat.VarList) do
				printt(var)
				local colon = stat.Token_VarColonList[index]
				if colon then
					printt(colon)
					printType(stat.TypeList[index])
				end
				local comma = stat.Token_VarCommaList[index]
				if comma then
					printt(comma)
				end
			end
			if stat.Token_Equals then
				printt(stat.Token_Equals)
				for index, expr in pairs(stat.ExprList) do
					printExpr(expr)
					local comma = stat.Token_ExprCommaList[index]
					if comma then
						printt(comma)
					end
				end
			end
		elseif stat.Type == 'LocalFunctionStat' or stat.Type == 'FunctionStat' then
			if stat.Type == 'LocalFunctionStat' then
				printt(stat.Token_Local)
				stat = stat.FunctionStat
				printt(stat.Token_Function)
				printt(stat.NameChain[1])
			else
				printt(stat.Token_Function)
				for index, part in pairs(stat.NameChain) do
					printt(part)
					local sep = stat.Token_NameChainSeparator[index]
					if sep then
						printt(sep)
					end
				end
			end
			printt(stat.Token_OpenParen)
			for index, arg in pairs(stat.ArgList) do
				printt(arg)
				local colon = stat.Token_ArgColonList[index]
				if colon then
					printt(colon)
					printType(stat.ArgTypeList[index])
				end
				local comma = stat.Token_ArgCommaList[index]
				if comma then
					printt(comma)
				end
			end
			if stat.Token_Varg then
				printt(stat.Token_Varg)
			end
			printt(stat.Token_CloseParen)
			if stat.Token_Colon then
				printt(stat.Token_Colon)
				printType(stat.ReturnType)
			end
			printStat(stat.Body)
			printt(stat.Token_End)
		elseif stat.Type == 'RepeatStat' then
			printt(stat.Token_Repeat)
			printStat(stat.Body)
			printt(stat.Token_Until)
			printExpr(stat.Condition)
		elseif stat.Type == 'GenericForStat' then
			printt(stat.Token_For)
			for index, var in pairs(stat.VarList) do
				printt(var)
				local colon = stat.Token_VarColonList[index]
				if colon then
					printt(colon)
					printType(stat.VarTypeList[index])
				end
				local sep = stat.Token_VarCommaList[index]
				if sep then
					printt(sep)
				end
			end
			printt(stat.Token_In)
			for index, expr in pairs(stat.GeneratorList) do
				printExpr(expr)
				local sep = stat.Token_GeneratorCommaList[index]
				if sep then
					printt(sep)
				end
			end
			printt(stat.Token_Do)
			printStat(stat.Body)
			printt(stat.Token_End)
		elseif stat.Type == 'NumericForStat' then
			printt(stat.Token_For)
			for index, var in pairs(stat.VarList) do
				printt(var)
				local colon = stat.Token_VarColonList[index]
				if colon then
					printt(colon)
					printType(stat.VarTypeList[index])
				end
				local sep = stat.Token_VarCommaList[index]
				if sep then
					printt(sep)
				end
			end
			printt(stat.Token_Equals)
			for index, expr in pairs(stat.RangeList) do
				printExpr(expr)
				local sep = stat.Token_RangeCommaList[index]
				if sep then
					printt(sep)
				end
			end
			printt(stat.Token_Do)
			printStat(stat.Body)
			printt(stat.Token_End)
		elseif stat.Type == 'WhileStat' then
			printt(stat.Token_While)
			printExpr(stat.Condition)
			printt(stat.Token_Do)
			printStat(stat.Body)
			printt(stat.Token_End)
		elseif stat.Type == 'DoStat' then
			printt(stat.Token_Do)
			printStat(stat.Body)
			printt(stat.Token_End)
		elseif stat.Type == 'IfStat' then
			printt(stat.Token_If)
			printExpr(stat.Condition)
			printt(stat.Token_Then)
			printStat(stat.Body)
			for _, clause in pairs(stat.ElseClauseList) do
				printt(clause.Token)
				if clause.Condition then
					printExpr(clause.Condition)
					printt(clause.Token_Then)
				end
				printStat(clause.Body)
			end
			printt(stat.Token_End)
		elseif stat.Type == 'CallExprStat' then
			printExpr(stat.Expression)
		elseif stat.Type == 'AssignmentStat' then
			for index, ex in pairs(stat.Lhs) do
				printExpr(ex)
				local sep = stat.Token_LhsSeparatorList[index]
				if sep then
					printt(sep)
				end
			end
			printt(stat.Token_Equals)
			for index, ex in pairs(stat.Rhs) do
				printExpr(ex)
				local sep = stat.Token_RhsSeparatorList[index]
				if sep then
					printt(sep)
				end
			end
		else
			assert(false, "unreachable")
		end	
	end

	printStat(ast)
	
	return buffer
end

return printAst