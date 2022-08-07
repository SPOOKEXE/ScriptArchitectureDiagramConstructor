
local formatTable = require(script.Parent.formatTable)
local AllIdentifierCharacters = require(script.Parent.AllIdentifierCharacters)

-- Strips as much whitespace off of tokens in an AST as possible without 
local function stripAst(ast)
	local stripStat, stripExpr;

	local function stript(token)
		token.LeadingWhite = ''
	end

	-- Make to adjacent tokens as close as possible
	local function joint(tokenA, tokenB)
		-- Strip the second token's whitespace
		stript(tokenB)

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

	-- Join up a statement body and it's opening / closing tokens
	local function bodyjoint(open, body, close)
		stripStat(body)
		stript(close)
		local bodyFirst = body:GetFirstToken()
		local bodyLast = body:GetLastToken()
		if bodyFirst then
			-- Body is non-empty, join body to open / close
			joint(open, bodyFirst)
			joint(bodyLast, close)
		else
			-- Body is empty, just join open and close token together
			joint(open, close)
		end
	end

	stripExpr = function(expr)
		if expr.Type == 'BinopExpr' then
			stripExpr(expr.Lhs)
			stript(expr.Token_Op)
			stripExpr(expr.Rhs)
			-- Handle the `a - -b` -/-> `a--b` case which would otherwise incorrectly generate a comment
			-- Also handles operators "or" / "and" which definitely need joining logic in a bunch of cases
			joint(expr.Token_Op, expr.Rhs:GetFirstToken())
			joint(expr.Lhs:GetLastToken(), expr.Token_Op)
		elseif expr.Type == 'UnopExpr' then
			stript(expr.Token_Op)
			stripExpr(expr.Rhs)
			-- Handle the `- -b` -/-> `--b` case which would otherwise incorrectly generate a comment
			joint(expr.Token_Op, expr.Rhs:GetFirstToken())
		elseif expr.Type == 'NumberLiteral' or expr.Type == 'StringLiteral' or 
			expr.Type == 'NilLiteral' or expr.Type == 'BooleanLiteral' or 
			expr.Type == 'VargLiteral' 
		then
			-- Just print the token
			stript(expr.Token)
		elseif expr.Type == 'FieldExpr' then
			stripExpr(expr.Base)
			stript(expr.Token_Dot)
			stript(expr.Field)
		elseif expr.Type == 'IndexExpr' then
			stripExpr(expr.Base)
			stript(expr.Token_OpenBracket)
			stripExpr(expr.Index)
			stript(expr.Token_CloseBracket)
		elseif expr.Type == 'MethodExpr' or expr.Type == 'CallExpr' then
			stripExpr(expr.Base)
			if expr.Type == 'MethodExpr' then
				stript(expr.Token_Colon)
				stript(expr.Method)
			end
			if expr.FunctionArguments.CallType == 'StringCall' then
				stript(expr.FunctionArguments.Token)
			elseif expr.FunctionArguments.CallType == 'ArgCall' then
				stript(expr.FunctionArguments.Token_OpenParen)
				for index, argExpr in pairs(expr.FunctionArguments.ArgList) do
					stripExpr(argExpr)
					local sep = expr.FunctionArguments.Token_CommaList[index]
					if sep then
						stript(sep)
					end
				end
				stript(expr.FunctionArguments.Token_CloseParen)
			elseif expr.FunctionArguments.CallType == 'TableCall' then
				stripExpr(expr.FunctionArguments.TableExpr)
			end
		elseif expr.Type == 'FunctionLiteral' then
			stript(expr.Token_Function)
			stript(expr.Token_OpenParen)
			expr.Token_ArgColonList = {}
			expr.ArgTypeList = {}
			expr.Token_Colon = nil
			expr.ReturnType = nil
			for index, arg in pairs(expr.ArgList) do
				stript(arg)
				local comma = expr.Token_ArgCommaList[index]
				if comma then
					stript(comma)
				end
			end
			if expr.Token_Varg then
				stript(expr.Token_Varg)
			end
			stript(expr.Token_CloseParen)
			bodyjoint(expr.Token_CloseParen, expr.Body, expr.Token_End)
		elseif expr.Type == 'VariableExpr' then
			stript(expr.Token)
		elseif expr.Type == 'ParenExpr' then
			stript(expr.Token_OpenParen)
			stripExpr(expr.Expression)
			stript(expr.Token_CloseParen)
		elseif expr.Type == 'TableLiteral' then
			stript(expr.Token_OpenBrace)
			for index, entry in pairs(expr.EntryList) do
				if entry.EntryType == 'Field' then
					stript(entry.Field)
					stript(entry.Token_Equals)
					stripExpr(entry.Value)
				elseif entry.EntryType == 'Index' then
					stript(entry.Token_OpenBracket)
					stripExpr(entry.Index)
					stript(entry.Token_CloseBracket)
					stript(entry.Token_Equals)
					stripExpr(entry.Value)
				elseif entry.EntryType == 'Value' then
					stripExpr(entry.Value)
				else
					assert(false, "unreachable")
				end
				local sep = expr.Token_SeparatorList[index]
				if sep then
					stript(sep)
				end
			end
			-- Trailing separator is never needed, EG: {a = 5; b = 6;} -> {a=5;b=6}
			expr.Token_SeparatorList[#expr.EntryList] = nil
			stript(expr.Token_CloseBrace)
		else
			assert(false, "unreachable, type: "..expr.Type..":"..formatTable(expr))
		end
	end

	stripStat = function(stat)
		if stat.Type == 'StatList' then
			-- Strip all surrounding whitespace on statement lists along with separating whitespace
			local i = 1
			while i <= #stat.StatementList do
				local chStat = stat.StatementList[i]

				-- Strip the statement and it's whitespace
				local deleted = stripStat(chStat)
				if deleted then
					table.remove(stat.StatementList, i)
					table.remove(stat.SemicolonList, i)
					continue
				end
				stript(chStat:GetFirstToken())

				-- Have max one semicolon between statements
				if stat.SemicolonList[i] then
					stat.SemicolonList[i] = {stat.SemicolonList[i][1]}
				end

				-- If there was a last statement, join them appropriately
				local lastChStat = stat.StatementList[i-1]
				if lastChStat then
					-- See if we can remove a semi-colon, the only case where we can't is if
					-- this and the last statement have a `);(` pair, where removing the semi-colon
					-- would introduce ambiguous syntax.
					if stat.SemicolonList[i-1] and 
						(lastChStat:GetLastToken().Source ~= ')' or chStat:GetFirstToken().Source ~= ')')
					then
						stat.SemicolonList[i-1] = nil
					end

					-- If there isn't a semi-colon, we should safely join the two statements
					-- (If there is one, then no whitespace leading chStat is always okay)
					if stat.SemicolonList[i-1] then
						joint(lastChStat:GetLastToken(), chStat:GetFirstToken())
					end
					
					chStat:GetFirstToken().LeadingWhite = " "
				end

				i += 1
			end

			-- A semi-colon is never needed on the last stat in a statlist:
			stat.SemicolonList[#stat.StatementList] = nil

			-- The leading whitespace on the statlist should be stripped
			if #stat.StatementList > 0 then
				stript(stat.StatementList[1]:GetFirstToken())
			end

		elseif stat.Type == 'BreakStat' then
			stript(stat.Token_Break)

		elseif stat.Type == 'ContinueStat' then
			stript(stat.Token_Continue)

		elseif stat.Type == 'ReturnStat' then
			stript(stat.Token_Return)
			for index, expr in pairs(stat.ExprList) do
				stripExpr(expr)
				if stat.Token_CommaList[index] then
					stript(stat.Token_CommaList[index])
				end
			end
			if #stat.ExprList > 0 then
				joint(stat.Token_Return, stat.ExprList[1]:GetFirstToken())
			end
		elseif stat.Type == 'LocalVarStat' then
			stript(stat.Token_Local)
			stat.Token_VarColonList = {}
			stat.TypeList = {}
			for index, var in pairs(stat.VarList) do
				if index == 1 then
					joint(stat.Token_Local, var)
				else
					stript(var)
				end
				local comma = stat.Token_VarCommaList[index]
				if comma then
					stript(comma)
				end
			end
			if stat.Token_Equals then
				stript(stat.Token_Equals)
				for index, expr in pairs(stat.ExprList) do
					stripExpr(expr)
					local comma = stat.Token_ExprCommaList[index]
					if comma then
						stript(comma)
					end
				end
			end
		elseif stat.Type == 'LocalFunctionStat' then
			stript(stat.Token_Local)
			stat.FunctionStat.Token_ArgColonList = {}
			stat.FunctionStat.ArgTypeList = {}
			stat.FunctionStat.Token_Colon = nil
			stat.FunctionStat.ReturnType = nil
			joint(stat.Token_Local, stat.FunctionStat.Token_Function)
			joint(stat.FunctionStat.Token_Function, stat.FunctionStat.NameChain[1])
			joint(stat.FunctionStat.NameChain[1], stat.FunctionStat.Token_OpenParen)
			for index, arg in pairs(stat.FunctionStat.ArgList) do
				stript(arg)
				local comma = stat.FunctionStat.Token_ArgCommaList[index]
				if comma then
					stript(comma)
				end
			end
			if stat.FunctionStat.Token_Varg then
				stript(stat.FunctionStat.Token_Varg)
			end
			stript(stat.FunctionStat.Token_CloseParen)
			bodyjoint(stat.FunctionStat.Token_CloseParen, stat.FunctionStat.Body, stat.FunctionStat.Token_End)
		elseif stat.Type == 'FunctionStat' then
			stript(stat.Token_Function)
			stat.Token_ArgColonList = {}
			stat.ArgTypeList = {}
			stat.Token_Colon = nil
			stat.ReturnType = nil
			for index, part in pairs(stat.NameChain) do
				if index == 1 then
					joint(stat.Token_Function, part)
				else
					stript(part)
				end
				local sep = stat.Token_NameChainSeparator[index]
				if sep then
					stript(sep)
				end
			end
			stript(stat.Token_OpenParen)
			for index, arg in pairs(stat.ArgList) do
				stript(arg)
				local comma = stat.Token_ArgCommaList[index]
				if comma then
					stript(comma)
				end
			end
			if stat.Token_Varg then
				stript(stat.Token_Varg)
			end
			stript(stat.Token_CloseParen)
			bodyjoint(stat.Token_CloseParen, stat.Body, stat.Token_End)
		elseif stat.Type == 'RepeatStat' then
			stript(stat.Token_Repeat)
			bodyjoint(stat.Token_Repeat, stat.Body, stat.Token_Until)
			stripExpr(stat.Condition)
			joint(stat.Token_Until, stat.Condition:GetFirstToken())
		elseif stat.Type == 'GenericForStat' then
			stript(stat.Token_For)
			stat.Token_VarColonList = {}
			stat.VarTypeList = {}
			for index, var in pairs(stat.VarList) do
				if index == 1 then
					joint(stat.Token_For, var)
				else
					stript(var)
				end
				local sep = stat.Token_VarCommaList[index]
				if sep then
					stript(sep)
				end
			end
			joint(stat.VarList[#stat.VarList], stat.Token_In)
			for index, expr in pairs(stat.GeneratorList) do
				stripExpr(expr)
				if index == 1 then
					joint(stat.Token_In, expr:GetFirstToken())
				end
				local sep = stat.Token_GeneratorCommaList[index]
				if sep then
					stript(sep)
				end
			end
			joint(stat.GeneratorList[#stat.GeneratorList]:GetLastToken(), stat.Token_Do)
			bodyjoint(stat.Token_Do, stat.Body, stat.Token_End)
		elseif stat.Type == 'NumericForStat' then
			stript(stat.Token_For)
			stat.Token_VarColonList = {}
			stat.VarTypeList = {}
			for index, var in pairs(stat.VarList) do
				if index == 1 then
					joint(stat.Token_For, var)
				else
					stript(var)
				end
				local sep = stat.Token_VarCommaList[index]
				if sep then
					stript(sep)
				end
			end
			joint(stat.VarList[#stat.VarList], stat.Token_Equals)
			for index, expr in pairs(stat.RangeList) do
				stripExpr(expr)
				if index == 1 then
					joint(stat.Token_Equals, expr:GetFirstToken())
				end
				local sep = stat.Token_RangeCommaList[index]
				if sep then
					stript(sep)
				end
			end
			joint(stat.RangeList[#stat.RangeList]:GetLastToken(), stat.Token_Do)
			bodyjoint(stat.Token_Do, stat.Body, stat.Token_End)	
		elseif stat.Type == 'WhileStat' then
			stript(stat.Token_While)
			stripExpr(stat.Condition)
			stript(stat.Token_Do)
			joint(stat.Token_While, stat.Condition:GetFirstToken())
			joint(stat.Condition:GetLastToken(), stat.Token_Do)
			bodyjoint(stat.Token_Do, stat.Body, stat.Token_End)
		elseif stat.Type == 'DoStat' then
			stript(stat.Token_Do)
			stript(stat.Token_End)
			bodyjoint(stat.Token_Do, stat.Body, stat.Token_End)
		elseif stat.Type == 'IfStat' then
			stript(stat.Token_If)
			stripExpr(stat.Condition)
			joint(stat.Token_If, stat.Condition:GetFirstToken())
			joint(stat.Condition:GetLastToken(), stat.Token_Then)
			--
			local lastBodyOpen = stat.Token_Then
			local lastBody = stat.Body
			--
			for _, clause in pairs(stat.ElseClauseList) do
				bodyjoint(lastBodyOpen, lastBody, clause.Token)
				lastBodyOpen = clause.Token
				--
				if clause.Condition then
					stripExpr(clause.Condition)
					joint(clause.Token, clause.Condition:GetFirstToken())
					joint(clause.Condition:GetLastToken(), clause.Token_Then)
					lastBodyOpen = clause.Token_Then
				end
				stripStat(clause.Body)
				lastBody = clause.Body
			end
			--
			bodyjoint(lastBodyOpen, lastBody, stat.Token_End)

		elseif stat.Type == 'CallExprStat' then
			stripExpr(stat.Expression)
		elseif stat.Type == 'AssignmentStat' then
			for index, ex in pairs(stat.Lhs) do
				stripExpr(ex)
				local sep = stat.Token_LhsSeparatorList[index]
				if sep then
					stript(sep)
				end
			end
			stript(stat.Token_Equals)
			for index, ex in pairs(stat.Rhs) do
				stripExpr(ex)
				local sep = stat.Token_RhsSeparatorList[index]
				if sep then
					stript(sep)
				end
			end
		elseif stat.Type == 'TypeStat' then
			return true
		else
			assert(false, "unreachable")
		end	
	end

	return stripStat(ast)
end

return stripAst