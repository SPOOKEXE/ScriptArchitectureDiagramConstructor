
local formatTable = require(script.Parent.formatTable)
local WhitespaceCharacters = require(script.Parent.WhitespaceCharacters)
local AllIdentifierCharacters = require(script.Parent.AllIdentifierCharacters)

-- Adds / removes whitespace in an AST to put it into a "standard formatting"
local function formatAst(ast)
	local formatStat
	local formatExpr
	local formatType

	local currentIndent = 0

	local function applyIndent(token)
		local indentString = '\n'..('\t'):rep(currentIndent)
		if token.LeadingWhite == '' or (token.LeadingWhite:sub(-#indentString, -1) ~= indentString) then
			-- Trim existing trailing whitespace on LeadingWhite
			-- Trim trailing tabs and spaces, and up to one newline
			token.LeadingWhite = token.LeadingWhite:gsub("\n?[\t ]*$", "")
			token.LeadingWhite = token.LeadingWhite..indentString
		end
	end

	local function tighten(token)
		token.LeadingWhite = token.LeadingWhite:gsub("[ ]*$", "")
	end

	local function trim(token)
		tighten(token)
		token.LeadingWhite = token.LeadingWhite:gsub("^%s*", "")
	end

	local function indent()
		currentIndent = currentIndent + 1
	end

	local function undent()
		currentIndent = currentIndent - 1
		assert(currentIndent >= 0, "Undented too far")
	end

	local function leadingChar(tk)
		if #tk.LeadingWhite > 0 then
			return tk.LeadingWhite:sub(1,1)
		else
			return tk.Source:sub(1,1)
		end
	end

	local function joint(tokenA, tokenB)
		-- Get the trailing A <-> leading B character pair
		local lastCh = tokenA.Source:sub(-1, -1)
		local firstCh = tokenB.Source:sub(1, 1)

		-- Cases to consider:
		--  Touching minus signs -> comment: `- -42` -> `--42' is invalid
		--  Touching dots: `.. .5` -> `...5` is invalid
		--  Touching words: `a b` -> `ab` is invalid
		--  Touching digits: `2 3`, can't occurr in the Lua syntax as number literals aren't a primary expression
		--  Abiguous syntax: `f(x)\n(x)()` is already disallowed, we can't cause a problem by removing newlines
		--  `>` `=` cannot be merged, because they will become a `>=` token.

		-- Figure out what separation is needed
		if 
			(lastCh == '-' and firstCh == '-') or
			(lastCh == '>' and firstCh == '=') or
			(lastCh == '.' and firstCh == '.') or
			(AllIdentifierCharacters[lastCh] and AllIdentifierCharacters[firstCh]) 
		then
			tokenB.LeadingWhite = ' ' -- Use a separator
		else
			tokenB.LeadingWhite = '' -- Don't use a separator
		end
	end

	local function padToken(tk)
		tighten(tk)
		if not WhitespaceCharacters[leadingChar(tk)] then
			tk.LeadingWhite = ' '..tk.LeadingWhite
		end
	end

	local function padExpr(expr)
		padToken(expr:GetFirstToken())
	end

	local function formatBody(openToken, bodyStat, closeToken)
		indent()
		formatStat(bodyStat)
		undent()
		applyIndent(closeToken)
	end

	formatType = function(typeExpr)
		tighten(typeExpr:GetFirstToken())
		if typeExpr.Type == 'BasicType' then
			for index, ident in pairs(typeExpr.IdentList) do
				tighten(ident)
				if typeExpr.Token_IdentDotList[index] then
					tighten(typeExpr.Token_IdentDotList[index])
				end
			end
			if typeExpr.Token_OpenAngle then
				tighten(typeExpr.Token_OpenAngle)
				for index, typeArg in pairs(typeExpr.GenericArgumentList) do
					formatType(typeArg)
					if index == 1 then
						tighten(typeArg:GetFirstToken())
					else
						padToken(typeArg:GetFirstToken())
					end
					if typeExpr.Token_GenericArgumentCommaList[index] then
						tighten(typeExpr.Token_GenericArgumentCommaList[index])
					end
				end
				tighten(typeExpr.Token_CloseAngle)
			end
		elseif typeExpr.Type == 'NilType' then
			tighten(typeExpr.Token_Nil)
		elseif typeExpr.Type == 'TypeofType' then
			--(typeExpr.Token_Typeof)
			tighten(typeExpr.Token_OpenParen)
			formatExpr(typeExpr.Expression)
			tighten(typeExpr.Token_CloseParen)
		elseif typeExpr.Type == 'FunctionType' then
			formatType(typeExpr.ArgType)
			padToken(typeExpr.Token_Arrow)
			formatType(typeExpr.ReturnType)
			padToken(typeExpr.ReturnType:GetFirstToken())
		elseif typeExpr.Type == 'TupleType' then
			--(typeExpr.Token_OpenParen)
			for index, subTypeExpr in pairs(typeExpr.TypeList) do
				formatType(subTypeExpr)
				if index == 1 then
					tighten(subTypeExpr:GetFirstToken())
				else
					padToken(subTypeExpr:GetFirstToken())
				end
				if typeExpr.Token_CommaList[index] then
					tighten(typeExpr.Token_CommaList[index])
				end
			end
			tighten(typeExpr.Token_CloseParen)
		elseif typeExpr.Type == 'TableType' then
			--(typeExpr.Token_OpenBrace)
			for index, record in pairs(typeExpr.RecordList) do
				if record.Type == 'Type' then
					if index == 1 then
						tighten(record.Token_OpenBracket)
					else
						padToken(record.Token_OpenBracket)
					end
					formatType(record.KeyType)
					tighten(record.Token_CloseBracket)
					tighten(record.Token_Colon)
					formatType(record.ValueType)
					padToken(record.ValueType:GetFirstToken())
				elseif record.Type == 'Name' then
					if index == 1 then
						tighten(record.Ident)
					else
						padToken(record.Ident)
					end
					tighten(record.Token_Colon)
					formatType(record.ValueType)
					padToken(record.ValueType:GetFirstToken())
				else
					error("Unexpected record in table type: "..formatTable(record))
				end
				if typeExpr.Token_CommaList[index] then
					tighten(typeExpr.Token_CommaList[index])
				end
			end
			tighten(typeExpr.Token_CloseBrace)
		elseif typeExpr.Type == 'OptionalType' then
			formatType(typeExpr.BaseType)
			tighten(typeExpr.Token_QuestionMark)
		elseif typeExpr.Type == 'UnionType' or typeExpr.Type == 'IntersectionType' then
			for index, subTypeExpr in pairs(typeExpr.TypeList) do
				formatType(subTypeExpr)
				if index > 1 then
					padToken(subTypeExpr:GetFirstToken())
				end
				if typeExpr.Token_CombinerList[index] then
					padToken(typeExpr.Token_CombinerList[index])
				end
			end
		else
			error("Bad typeExpr type in: "..formatTable(typeExpr))
		end
	end

	formatExpr = function(expr)
		tighten(expr:GetFirstToken())
		if expr.Type == 'BinopExpr' then
			formatExpr(expr.Lhs)
			formatExpr(expr.Rhs)
			if expr.Token_Op.Source == '..' then
				-- Only necessary padding on ..
				joint(expr.Lhs:GetLastToken(), expr.Token_Op)
				joint(expr.Token_Op, expr.Rhs:GetFirstToken())
			else
				padExpr(expr.Rhs)
				padToken(expr.Token_Op)
			end
		elseif expr.Type == 'UnopExpr' then
			formatExpr(expr.Rhs)
			joint(expr.Token_Op, expr.Rhs:GetFirstToken())
			--(expr.Token_Op)
		elseif expr.Type == 'NumberLiteral' or expr.Type == 'StringLiteral' or 
			expr.Type == 'NilLiteral' or expr.Type == 'BooleanLiteral' or 
			expr.Type == 'VargLiteral' 
		then
			-- Nothing to do
			--(expr.Token)
		elseif expr.Type == 'FieldExpr' then
			formatExpr(expr.Base)
			tighten(expr.Token_Dot)
			tighten(expr.Field)
		elseif expr.Type == 'IndexExpr' then
			formatExpr(expr.Base)
			formatExpr(expr.Index)
			--(expr.Token_OpenBracket)
			--(expr.Token_CloseBracket)
		elseif expr.Type == 'MethodExpr' or expr.Type == 'CallExpr' then
			formatExpr(expr.Base)
			if expr.Type == 'MethodExpr' then
				--(expr.Token_Colon)
				--(expr.Method)
			end
			if expr.FunctionArguments.CallType == 'StringCall' then
				--(expr.FunctionArguments.Token)
			elseif expr.FunctionArguments.CallType == 'ArgCall' then
				--(expr.FunctionArguments.Token_OpenParen)
				for index, argExpr in pairs(expr.FunctionArguments.ArgList) do
					formatExpr(argExpr)
					if index > 1 then
						padExpr(argExpr)
					end
					local sep = expr.FunctionArguments.Token_CommaList[index]
					if sep then
						tighten(sep)
					end
				end
				--(expr.FunctionArguments.Token_CloseParen)
			elseif expr.FunctionArguments.CallType == 'TableCall' then
				formatExpr(expr.FunctionArguments.TableExpr)
			end
		elseif expr.Type == 'FunctionLiteral' then
			--(expr.Token_Function)
			tighten(expr.Token_OpenParen)
			for index, arg in pairs(expr.ArgList) do
				if index > 1 then
					padToken(arg)
				end
				local colon = expr.Token_ArgColonList[index]
				if colon then
					tighten(colon)
					formatType(expr.ArgTypeList[index])
				end
				local comma = expr.Token_ArgCommaList[index]
				if comma then
					tighten(comma)
				end
			end
			if #expr.ArgList > 0 and expr.Token_Varg then
				padToken(expr.Token_Varg)
			end
			tighten(expr.Token_CloseParen)
			if expr.Token_Colon then
				tighten(expr.Token_Colon)
				formatType(expr.ReturnType)
				padToken(expr.ReturnType:GetFirstToken())
			end
			formatBody(expr.Token_CloseParen, expr.Body, expr.Token_End)
		elseif expr.Type == 'VariableExpr' then
			--(expr.Token)
		elseif expr.Type == 'ParenExpr' then
			formatExpr(expr.Expression)
			--(expr.Token_OpenParen)
			tighten(expr.Token_CloseParen)
		elseif expr.Type == 'TableLiteral' then
			--(expr.Token_OpenBrace)
			if #expr.EntryList == 0 then
				-- Nothing to do
			else
				indent()
				for index, entry in pairs(expr.EntryList) do
					if entry.EntryType == 'Field' then
						applyIndent(entry.Field)
						padToken(entry.Token_Equals)
						formatExpr(entry.Value)
						padExpr(entry.Value)
					elseif entry.EntryType == 'Index' then
						applyIndent(entry.Token_OpenBracket)
						formatExpr(entry.Index)
						tighten(entry.Token_CloseBracket)
						padToken(entry.Token_Equals)
						formatExpr(entry.Value)
						padExpr(entry.Value)
					elseif entry.EntryType == 'Value' then
						formatExpr(entry.Value)
						applyIndent(entry.Value:GetFirstToken())
					else
						assert(false, "unreachable")
					end
					local sep = expr.Token_SeparatorList[index]
					if sep then
						tighten(sep)
					end
				end
				undent()
				applyIndent(expr.Token_CloseBrace)
			end
			tighten(expr.Token_CloseBrace)
		else
			assert(false, "unreachable, type: "..expr.Type..":"..formatTable(expr))
		end
	end

	formatStat = function(stat)
		if stat.Type == 'StatList' then
			for _, stat in pairs(stat.StatementList) do
				formatStat(stat)
				applyIndent(stat:GetFirstToken())
			end

		elseif stat.Type == 'BreakStat' then
			--(stat.Token_Break)

		elseif stat.Type == 'ContinueStat' then
			--(stat.Token_Continue)

		elseif stat.Type == 'TypeStat' then
			if stat.Token_Export then
				tighten(stat.Token_Export)
				padToken(stat.Token_Type)
			else
				tighten(stat.Token_Type)
			end
				
			padToken(stat.Ident)
			if stat.Token_OpenAngle then
				tighten(stat.Token_OpenAngle)
				for index, ident in pairs(stat.GenericTypeList) do
					if index == 1 then
						tighten(ident)
					else
						padToken(ident)
					end
					if stat.Token_GenericTypeCommaList[index] then
						tighten(stat.Token_GenericTypeCommaList[index])
					end
				end
				tighten(stat.Token_CloseAngle)
			end
			padToken(stat.Token_Equals)
			formatType(stat.AliasedType)
			padToken(stat.AliasedType:GetFirstToken())

		elseif stat.Type == 'ReturnStat' then
			--(stat.Token_Return)
			for index, expr in pairs(stat.ExprList) do
				formatExpr(expr)
				padExpr(expr)
				if stat.Token_CommaList[index] then
					--(stat.Token_CommaList[index])
					tighten(stat.Token_CommaList[index])
				end
			end
		elseif stat.Type == 'LocalVarStat' then
			--(stat.Token_Local)
			for index, var in pairs(stat.VarList) do
				padToken(var)
				local colon = stat.Token_VarColonList[index]
				if colon then
					tighten(colon)
					formatType(stat.TypeList[index])
					padToken(stat.TypeList[index]:GetFirstToken())
				end
				local comma = stat.Token_VarCommaList[index]
				if comma then
					tighten(comma)
				end
			end
			if stat.Token_Equals then
				padToken(stat.Token_Equals)
				for index, expr in pairs(stat.ExprList) do
					formatExpr(expr)
					padExpr(expr)
					local comma = stat.Token_ExprCommaList[index]
					if comma then
						tighten(comma)
					end
				end
			end
		elseif stat.Type == 'LocalFunctionStat' then
			--(stat.Token_Local)
			padToken(stat.FunctionStat.Token_Function)
			padToken(stat.FunctionStat.NameChain[1])
			tighten(stat.FunctionStat.Token_OpenParen)
			for index, arg in pairs(stat.FunctionStat.ArgList) do
				if index > 1 then
					padToken(arg)
				end
				local colon = stat.FunctionStat.Token_ArgColonList[index]
				if colon then
					tighten(colon)
					formatType(stat.FunctionStat.ArgTypeList[index])
					padToken(stat.FunctionStat.ArgTypeList[index]:GetFirstToken())
				end
				local comma = stat.FunctionStat.Token_ArgCommaList[index]
				if comma then
					tighten(comma)
				end
			end
			if #stat.FunctionStat.ArgList > 0 and stat.FunctionStat.Token_Varg then
				padToken(stat.FunctionStat.Token_Varg)
			end
			tighten(stat.FunctionStat.Token_CloseParen)
			if stat.FunctionStat.Token_Colon then
				tighten(stat.FunctionStat.Token_Colon)
				formatType(stat.FunctionStat.ReturnType)
				padToken(stat.FunctionStat.ReturnType:GetFirstToken())
			end
			formatBody(stat.FunctionStat.Token_CloseParen, stat.FunctionStat.Body, stat.FunctionStat.Token_End)
		elseif stat.Type == 'FunctionStat' then
			--(stat.Token_Function)
			for index, part in pairs(stat.NameChain) do
				if index == 1 then
					padToken(part)
				end
				local sep = stat.Token_NameChainSeparator[index]
				if sep then
					tighten(sep)
				end
			end
			tighten(stat.Token_OpenParen)
			for index, arg in pairs(stat.ArgList) do
				if index > 1 then
					padToken(arg)
				end
				local colon = stat.Token_ArgColonList[index]
				if colon then
					tighten(colon)
					formatType(stat.ArgTypeList[index])
					padToken(stat.ArgTypeList[index]:GetFirstToken())
				end
				local comma = stat.Token_ArgCommaList[index]
				if comma then
					tighten(comma)
				end
			end
			if #stat.ArgList > 0 and stat.Token_Varg then
				padToken(stat.Token_Varg)
			end
			tighten(stat.Token_CloseParen)
			if stat.Token_Colon then
				tighten(stat.Token_Colon)
				formatType(stat.ReturnType)
				padToken(stat.ReturnType:GetFirstToken())
			end
			formatBody(stat.Token_CloseParen, stat.Body, stat.Token_End)
		elseif stat.Type == 'RepeatStat' then
			--(stat.Token_Repeat)
			formatBody(stat.Token_Repeat, stat.Body, stat.Token_Until)
			formatExpr(stat.Condition)
			padExpr(stat.Condition)
		elseif stat.Type == 'GenericForStat' then
			--(stat.Token_For)
			for index, var in pairs(stat.VarList) do
				padToken(var)
				local colon = stat.Token_VarColonList[index]
				if colon then
					tighten(colon)
					formatType(stat.VarTypeList[index])
					padToken(stat.VarTypeList[index]:GetFirstToken())
				end
				local sep = stat.Token_VarCommaList[index]
				if sep then
					tighten(sep)
				end
			end
			padToken(stat.Token_In)
			for index, expr in pairs(stat.GeneratorList) do
				formatExpr(expr)
				padExpr(expr)
				local sep = stat.Token_GeneratorCommaList[index]
				if sep then
					tighten(sep)
				end
			end
			padToken(stat.Token_Do)
			formatBody(stat.Token_Do, stat.Body, stat.Token_End)
		elseif stat.Type == 'NumericForStat' then
			--(stat.Token_For)
			for index, var in pairs(stat.VarList) do
				padToken(var)
				local colon = stat.Token_VarColonList[index]
				if colon then
					tighten(colon)
					formatType(stat.VarTypeList[index])
					padToken(stat.VarTypeList[index])
				end
				local sep = stat.Token_VarCommaList[index]
				if sep then
					tighten(sep)
				end
			end
			padToken(stat.Token_Equals)
			for index, expr in pairs(stat.RangeList) do
				formatExpr(expr)
				padExpr(expr)
				local sep = stat.Token_RangeCommaList[index]
				if sep then
					tighten(sep)
				end
			end
			padToken(stat.Token_Do)
			formatBody(stat.Token_Do, stat.Body, stat.Token_End)	
		elseif stat.Type == 'WhileStat' then
			--(stat.Token_While)
			formatExpr(stat.Condition)
			padExpr(stat.Condition)
			padToken(stat.Token_Do)
			formatBody(stat.Token_Do, stat.Body, stat.Token_End)
		elseif stat.Type == 'DoStat' then
			--(stat.Token_Do)
			formatBody(stat.Token_Do, stat.Body, stat.Token_End)
		elseif stat.Type == 'IfStat' then
			--(stat.Token_If)
			formatExpr(stat.Condition)
			padExpr(stat.Condition)
			padToken(stat.Token_Then)
			--
			local lastBodyOpen = stat.Token_Then
			local lastBody = stat.Body
			--
			for _, clause in pairs(stat.ElseClauseList) do
				formatBody(lastBodyOpen, lastBody, clause.Token)
				lastBodyOpen = clause.Token
				--
				if clause.Condition then
					formatExpr(clause.Condition)
					padExpr(clause.Condition)
					padToken(clause.Token_Then)
					lastBodyOpen = clause.Token_Then
				end
				lastBody = clause.Body
			end
			--
			formatBody(lastBodyOpen, lastBody, stat.Token_End)

		elseif stat.Type == 'CallExprStat' then
			formatExpr(stat.Expression)
		elseif stat.Type == 'AssignmentStat' then
			for index, ex in pairs(stat.Lhs) do
				formatExpr(ex)
				if index > 1 then
					padExpr(ex)
				end
				local sep = stat.Token_LhsSeparatorList[index]
				if sep then
					--(sep)
					tighten(sep)
				end
			end
			padToken(stat.Token_Equals)
			for index, ex in pairs(stat.Rhs) do
				formatExpr(ex)
				padExpr(ex)
				local sep = stat.Token_RhsSeparatorList[index]
				if sep then
					--(sep)
					tighten(sep)
				end
			end
		else
			assert(false, "unreachable")
		end	
	end

	formatStat(ast)
	trim(ast:GetFirstToken())
end

return formatAst