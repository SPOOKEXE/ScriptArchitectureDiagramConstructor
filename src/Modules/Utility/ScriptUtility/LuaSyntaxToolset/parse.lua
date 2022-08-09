
local lookupify = require(script.Parent.lookupify)

local BlockFollowKeyword = lookupify{'else', 'elseif', 'until', 'end'}

local UnopSet = lookupify{'-', 'not', '#'}

local BinopSet = lookupify{
	'+', '-', '*', '/', '%', '^', '#',
	'..', '.', ':',
	'>', '<', '<=', '>=', '~=', '==',
	'and', 'or'
}

local AssignmentOperators = lookupify{
	'=', -- Lua 5.1 
	'+=', '-=', '*=', '/=', '^=', '%=', -- Luau
}

local BinaryPriority = {
   ['+'] = {6, 6};
   ['-'] = {6, 6};
   ['*'] = {7, 7};
   ['/'] = {7, 7};
   ['%'] = {7, 7};
   ['^'] = {10, 9};
   ['..'] = {5, 4};
   ['=='] = {3, 3};
   ['~='] = {3, 3};
   ['>'] = {3, 3};
   ['<'] = {3, 3};
   ['>='] = {3, 3};
   ['<='] = {3, 3};
   ['and'] = {2, 2};
   ['or'] = {1, 1};
};
local UnaryPriority = 8

local function parse(tokens)
	-- Pointer into tokens list
	local p = 1

	local function get()
		local tok = tokens[p]
		if p < #tokens then
			p = p + 1
		end
		return tok
	end
	local function peek(n: number | nil)
		n = p + (n or 0)
		return tokens[n] or tokens[#tokens]
	end

	local function getTokenStartPosition(token)
		local line = 1
		local char = 0
		local tkNum = 1
		while true do
			local tk = tokens[tkNum]
			local text;
			if tk == token then
				text = tk.LeadingWhite
			else
				text = tk.LeadingWhite..tk.Source
			end
			for i = 1, #text do
				local c = text:sub(i, i)
				if c == '\n' then
					line = line + 1
					char = 0
				else
					char = char + 1
				end
			end
			if tk == token then
				break
			end
			tkNum = tkNum + 1
		end
		return line..":"..(char+1)
	end
	local function debugMark()
		local tk = peek()
		return "<"..tk.Type.." `"..tk.Source.."`> at: "..getTokenStartPosition(tk)
	end

	local function isBlockFollow()
		local tok = peek()
		return tok.Type == 'Eof' or (tok.Type == 'Keyword' and BlockFollowKeyword[tok.Source])
	end	
	local function isUnop()
		return UnopSet[peek().Source] or false
	end
	local function isBinop()
		return BinopSet[peek().Source] or false
	end
	local function expect(type: string, source: string | nil)
		local tk = peek()
		if tk.Type == type and (source == nil or tk.Source == source) then
			return get()
		else
			for i = -3, 3 do
				print("Tokens["..i.."] = `"..peek(i).Source.."`")
			end
			if source then
				error(getTokenStartPosition(tk)..": `"..source.."` expected.")
			else
				error(getTokenStartPosition(tk)..": "..type.." expected.")
			end
		end
	end

	local function MkNode(node)
		local getf = node.GetFirstToken
		local getl = node.GetLastToken
		function node:GetFirstToken()
			local t = getf(self)
			if not t then
				assert(t, "failed")
			end
			return t
		end
		function node:GetLastToken()
			local t = getl(self)
			assert(t, "failed")
			return t
		end
		return node
	end

	-- Forward decls
	local block;
	local expr;
	local typeexpr;

	-- Expression list
	local function exprlist()
		local exprList = {}
		local commaList = {}
		table.insert(exprList, expr())
		while peek().Source == ',' do
			table.insert(commaList, get())
			table.insert(exprList, expr())
		end
		return exprList, commaList
	end

	local function prefixexpr()
		local tk = peek()
		if tk.Source == '(' then
			local oparenTk = get()
			local inner = expr()
			local cparenTk = expect('Symbol', ')')
			return MkNode{
				Type = 'ParenExpr';
				Expression = inner;
				Token_OpenParen = oparenTk;
				Token_CloseParen = cparenTk;
				GetFirstToken = function(self)
					return self.Token_OpenParen
				end;
				GetLastToken = function(self)
					return self.Token_CloseParen
				end;
			}
		elseif tk.Type == 'Ident' then
			return MkNode{
				Type = 'VariableExpr';
				Token = get();
				GetFirstToken = function(self)
					return self.Token
				end;
				GetLastToken = function(self)
					return self.Token
				end;
			}
		else
			print(debugMark())
			error(getTokenStartPosition(tk)..": Unexpected symbol")
		end
	end

	local function tableexpr()
		local obrace = expect('Symbol', '{')
		local entries: {} = {}
		local separators = {}
		while peek().Source ~= '}' do
			if peek().Source == '[' then
				-- Index
				local obrac = get()
				local index = expr()
				local cbrac = expect('Symbol', ']')
				local eq = expect('Symbol', '=')
				local value = expr()
				table.insert(entries, {
					EntryType = 'Index';
					Index = index;
					Value = value;
					Token_OpenBracket = obrac;
					Token_CloseBracket = cbrac;
					Token_Equals = eq;
				})
			elseif peek().Type == 'Ident' and peek(1).Source == '=' then
				-- Field
				local field = get()
				local eq = get()
				local value = expr()
				table.insert(entries, {
					EntryType = 'Field';
					Field = field;
					Value = value;
					Token_Equals = eq;
				})
			else
				-- Value
				local value = expr()
				table.insert(entries, {
					EntryType = 'Value';
					Value = value;
				})
			end

			-- Comma or Semicolon separator
			if peek().Source == ',' or peek().Source == ';' then
				table.insert(separators, get())
			else
				break
			end
		end
		local cbrace = expect('Symbol', '}')
		return MkNode{
			Type = 'TableLiteral';
			EntryList = entries;
			Token_SeparatorList = separators;
			Token_OpenBrace = obrace;
			Token_CloseBrace = cbrace;
			GetFirstToken = function(self)
				return self.Token_OpenBrace
			end;
			GetLastToken = function(self)
				return self.Token_CloseBrace
			end;
		}
	end

	local function typeExprBasePart()
		if peek().Source == 'typeof' then
			local typeofTk = get()
			local openParen = expect('Symbol', '(')
			local expression = expr()
			local closeParen = expect('Symbol', ')')
			return MkNode{
				Type = 'TypeofType';
				Expression = expression;
				--
				Token_Typeof = typeofTk;
				Token_OpenParen = openParen;
				Token_CloseParen = closeParen;
				GetFirstToken = function(self)
					return self.Token_Typeof
				end;
				GetLastToken = function(self)
					return self.Token_CloseParen
				end;
			}
		elseif peek().Source == '(' then
			-- Tuple type
			local tkOparen = get()
			local types = {}
			local commas = {}
			if peek().Source ~= ')' then
				while true do
					table.insert(types, typeexpr())
					if peek().Source == ',' then
						table.insert(commas, get())
					else
						break
					end
				end
			end
			local tkCparen = expect('Symbol', ')')
			return MkNode{
				Type = 'TupleType';
				TypeList = types;
				--
				Token_OpenParen = tkOparen;
				Token_CommaList = commas;
				Token_CloseParen = tkCparen;
				GetFirstToken = function(self)
					return self.Token_OpenParen
				end;
				GetLastToken = function(self)
					return self.Token_CloseParen
				end;
			}
		elseif peek().Source == '{' then
			-- Table type
			local openBrace = get()
			local records: {} = {}
			local commas = {}
			if peek().Source == '[' or peek().Type == 'Ident' then
				while true do
					if peek().Source == '[' then
						-- Field type record
						local openBracket = get()
						local fieldType = typeexpr()
						local closeBracket = expect('Symbol', ']')
						local colon = expect('Symbol', ':')
						local valueType = typeexpr()
						table.insert(records, {
							Type = 'Type';
							KeyType = fieldType;
							ValueType = valueType;
							--
							Token_OpenBracket = openBracket;
							Token_CloseBracket = closeBracket;
							Token_Colon = colon;
						})
					elseif peek().Type == 'Ident' then
						-- Field name record
						local ident = get()
						local colon = expect('Symbol', ':')
						local valueType = typeexpr()
						table.insert(records, {
							Type = 'Name';
							Ident = ident;
							ValueType = valueType;
							--
							Token_Colon = colon;
						})
					else
						error(getTokenStartPosition(peek())..": Type expected, got `"..peek().Source.."`")
					end
					if peek().Source == ',' then
						table.insert(commas, get())
					else
						break
					end
				end
			end
			local closeBrace = expect('Symbol', '}')
			return MkNode{
				Type = 'TableType';
				RecordList = records;
				--
				Token_OpenBrace = openBrace;
				Token_CloseBrace = closeBrace;
				Token_CommaList = commas;
				GetFirstToken = function(self)
					return self.Token_OpenBrace
				end;
				GetLastToken = function(self)
					return self.Token_CloseBrace
				end;
			}
		elseif peek().Source == 'nil' then
			-- nil type
			local nilKw = get()
			return MkNode{
				Type = 'NilType';
				--
				Token_Nil = nilKw;
				GetFirstToken = function(self)
					return self.Token_Nil
				end;
				GetLastToken = function(self)
					return self.Token_Nil
				end;
			}
		elseif peek().Type == 'Ident' then
			-- Basic type
			local identList = {get()}
			local identDotList = {}
			while peek().Source == '.' do
				table.insert(identDotList, get())
				table.insert(identList, expect('Ident'))
			end
			local tkOpenAngle, tkCloseAngle
			local genericArgumentList = {}
			local genericArgumentCommaList = {}
			if peek().Source == '<' then
				tkOpenAngle = get()
				-- Parameterized generic type
				while true do
					table.insert(genericArgumentList, typeexpr())
					if peek().Source == ',' then
						table.insert(genericArgumentCommaList, get())
					else
						break
					end
				end
				if peek().Source == '>=' then
					-- Special handling for `>=` case
					tkCloseAngle = {
						Type = 'Symbol';
						LeadingWhite = peek().LeadingWhite;
						Source = '>';
					}
					peek().Source = '='
					peek().LeadingWhite = ""
				else
					tkCloseAngle = expect('Symbol', '>')
				end
			end
			return MkNode{
				Type = 'BasicType';
				IdentList = identList;
				GenericArgumentList = genericArgumentList;
				--
				Token_IdentDotList = identDotList;
				Token_OpenAngle = tkOpenAngle;
				Token_CloseAngle = tkCloseAngle;
				Token_GenericArgumentCommaList = genericArgumentCommaList;
				GetFirstToken = function(self)
					return self.IdentList[1]
				end;
				GetLastToken = function(self)
					if self.Token_CloseAngle then
						return self.Token_CloseAngle
					else
						return self.IdentList[#self.IdentList]
					end
				end;
			}
		else
			error(getTokenStartPosition(peek())..": Type expected, got `"..peek().Source.."`")
		end
	end

	local function typeExprPart()
		local baseType = typeExprBasePart()
		if peek().Source == '->' then
			-- Is actually a function type
			local tkArrow = get()
			local returnType = typeexpr()
			return MkNode{
				Type = 'FunctionType';
				ArgType = baseType;
				ReturnType = returnType;
				--
				Token_Arrow = tkArrow;
				GetFirstToken = function(self)
					return self.ArgType:GetFirstToken()
				end;
				GetLastToken = function(self)
					return self.ReturnType:GetLastToken()
				end;
			}
		elseif peek().Source == '?' then
			return MkNode{
				Type = 'OptionalType';
				BaseType = baseType;
				--
				Token_QuestionMark = get();
				GetFirstToken = function(self)
					return self.BaseType:GetFirstToken()
				end;
				GetLastToken = function(self)
					return self.Token_QuestionMark
				end;
			}
		else
			return baseType
		end
	end

	function typeexpr()
		local parts = {typeExprPart()}
		local combiners = {}
		local combinersPresent = {}
		while peek().Source == '&' or peek().Source == '|' do
			local combiner = get()
			combinersPresent[combiner.Source] = true
			table.insert(parts, typeExprPart())
			table.insert(combiners, combiner)
		end
		if combinersPresent['&'] and combinersPresent['|'] then
			error(getTokenStartPosition(peek())..": Mixed union and intersection not allowed, must parenthesize")
		end
		if #parts > 1 then
			return MkNode{
				Type = combinersPresent['&'] and 'IntersectionType' or 'UnionType';
				TypeList = parts;
				--
				Token_CombinerList = combiners;
				GetFirstToken = function(self)
					return self.TypeList[1]:GetFirstToken()
				end;
				GetLastToken = function(self)
					return self.TypeList[#self.TypeList]:GetLastToken()
				end;
			}
		else
			return parts[1]
		end
	end

	-- List of identifiers
	local function varlist(acceptVarg)
		local varList = {}
		local colonList = {}
		local typeList = {}
		local commaList = {}
		if peek().Type == 'Ident' then
			varList[1] = get()
			if peek().Source == ':' then
				colonList[1] = get()
				typeList[1] = typeexpr()
			end
		elseif peek().Source == '...' and acceptVarg then
			return varList, colonList, typeList, commaList, get()
		end
		while peek().Source == ',' do
			table.insert(commaList, get())
			if peek().Source == '...' and acceptVarg then
				return varList, colonList, typeList, commaList, get()
			else
				local id = expect('Ident')
				table.insert(varList, id)
				if peek().Source == ':' then
					colonList[#varList] = get()
					typeList[#varList] = typeexpr()
				end
			end
		end
		return varList, colonList, typeList, commaList
	end

	-- Body
	local function blockbody(terminator)
		local body = block()
		local after = peek()
		if after.Type == 'Keyword' and after.Source == terminator then
			get()
			return body, after
		else
			print(after.Type, after.Source)
			error(getTokenStartPosition(after)..": "..terminator.." expected.")
		end
	end

	-- Function declaration
	local function funcdecl(isAnonymous)
		local functionKw = get()
		--
		local nameChain;
		local nameChainSeparator;
		--
		if not isAnonymous then
			nameChain = {}
			nameChainSeparator = {}
			--
			table.insert(nameChain, expect('Ident'))
			--
			while peek().Source == '.' do
				table.insert(nameChainSeparator, get())
				table.insert(nameChain, expect('Ident'))
			end
			if peek().Source == ':' then
				table.insert(nameChainSeparator, get())
				table.insert(nameChain, expect('Ident'))
			end
		end
		--
		local oparenTk = expect('Symbol', '(')
		local argList, argColonList, argTypeList, argCommaList, vargToken = varlist(true) --true -> allow varg symbol at end of var list
		local cparenTk = expect('Symbol', ')')
		local colonTk;
		local returnType;
		if peek().Source == ':' then
			colonTk = get()
			returnType = typeexpr()
		end
		--
		local fbody, enTk = blockbody('end')
		--
		return MkNode{
			Type = (isAnonymous and 'FunctionLiteral' or 'FunctionStat');
			NameChain = nameChain;
			ArgList = argList;
			ArgTypeList = argTypeList;
			ReturnType = returnType;
			Body = fbody;
			--
			Token_Function = functionKw;
			Token_NameChainSeparator = nameChainSeparator;
			Token_OpenParen = oparenTk;
			Token_Varg = vargToken;
			Token_ArgColonList = argColonList,
			Token_ArgCommaList = argCommaList;
			Token_CloseParen = cparenTk;
			Token_Colon = colonTk;
			Token_End = enTk;
			GetFirstToken = function(self)
				return self.Token_Function
			end;
			GetLastToken = function(self)
				return self.Token_End;
			end;
		}
	end

	-- Argument list passed to a funciton
	local function functionargs()
		local tk = peek()
		if tk.Source == '(' then
			local oparenTk = get()
			local argList = {}
			local argCommaList = {}
			while peek().Source ~= ')' do
				table.insert(argList, expr())
				if peek().Source == ',' then
					table.insert(argCommaList, get())
				else
					break
				end
			end
			local cparenTk = expect('Symbol', ')')
			return MkNode{
				CallType = 'ArgCall';
				ArgList = argList;
				--
				Token_CommaList = argCommaList;
				Token_OpenParen = oparenTk;
				Token_CloseParen = cparenTk;
				GetFirstToken = function(self)
					return self.Token_OpenParen
				end;
				GetLastToken = function(self)
					return self.Token_CloseParen
				end;
			}
		elseif tk.Source == '{' then
			return MkNode{
				CallType = 'TableCall';
				TableExpr = expr();
				GetFirstToken = function(self)
					return self.TableExpr:GetFirstToken()
				end;
				GetLastToken = function(self)
					return self.TableExpr:GetLastToken()
				end;
			}
		elseif tk.Type == 'String' then
			return MkNode{
				CallType = 'StringCall';
				Token = get();
				GetFirstToken = function(self)
					return self.Token
				end;
				GetLastToken = function(self)
					return self.Token
				end;
			}
		else
			error("Function arguments expected.")
		end
	end

	local function primaryexpr()
		local base = prefixexpr()
		assert(base, "nil prefixexpr")
		while true do
			local tk = peek()
			if tk.Source == '.' then
				local dotTk = get()
				local fieldName = expect('Ident')
				base = MkNode{
					Type = 'FieldExpr';
					Base = base;
					Field = fieldName;
					Token_Dot = dotTk;
					GetFirstToken = function(self)
						return self.Base:GetFirstToken()
					end;
					GetLastToken = function(self)
						return self.Field
					end;
				}
			elseif tk.Source == ':' then
				local colonTk = get()
				local methodName = expect('Ident')
				local fargs = functionargs()
				base = MkNode{
					Type = 'MethodExpr';
					Base = base;
					Method = methodName;
					FunctionArguments = fargs;
					Token_Colon = colonTk;
					GetFirstToken = function(self)
						return self.Base:GetFirstToken()
					end;
					GetLastToken = function(self)
						return self.FunctionArguments:GetLastToken()
					end;
				}
			elseif tk.Source == '[' then
				local obrac = get()
				local index = expr()
				local cbrac = expect('Symbol', ']')
				base = MkNode{
					Type = 'IndexExpr';
					Base = base;
					Index = index;
					Token_OpenBracket = obrac;
					Token_CloseBracket = cbrac;
					GetFirstToken = function(self)
						return self.Base:GetFirstToken()
					end;
					GetLastToken = function(self)
						return self.Token_CloseBracket
					end;
				}
			elseif tk.Source == '{' or tk.Source == '(' or tk.Type == 'String' then
				base = MkNode{
					Type = 'CallExpr';
					Base = base;
					FunctionArguments = functionargs();
					GetFirstToken = function(self)
						return self.Base:GetFirstToken()
					end;
					GetLastToken = function(self)
						return self.FunctionArguments:GetLastToken()
					end;
				}
			else
				return base
			end
		end
	end

	local function simpleexpr()
		local tk = peek()
		if tk.Type == 'Number' then
			return MkNode{
				Type = 'NumberLiteral';
				Token = get();
				GetFirstToken = function(self)
					return self.Token
				end;
				GetLastToken = function(self)
					return self.Token
				end;
			}
		elseif tk.Type == 'String' then
			return MkNode{
				Type = 'StringLiteral';
				Token = get();
				GetFirstToken = function(self)
					return self.Token
				end;
				GetLastToken = function(self)
					return self.Token
				end;
			}
		elseif tk.Source == 'nil' then
			return MkNode{
				Type = 'NilLiteral';
				Token = get();
				GetFirstToken = function(self)
					return self.Token
				end;
				GetLastToken = function(self)
					return self.Token
				end;
			}
		elseif tk.Source == 'true' or tk.Source == 'false' then
			return MkNode{
				Type = 'BooleanLiteral';
				Token = get();
				GetFirstToken = function(self)
					return self.Token
				end;
				GetLastToken = function(self)
					return self.Token
				end;
			}
		elseif tk.Source == '...' then
			return MkNode{
				Type = 'VargLiteral';
				Token = get();
				GetFirstToken = function(self)
					return self.Token
				end;
				GetLastToken = function(self)
					return self.Token
				end;
			}
		elseif tk.Source == '{' then
			return tableexpr()
		elseif tk.Source == 'function' then
			return funcdecl(true)
		else
			return primaryexpr()
		end
	end

	local function subexpr(limit)
		local curNode;

		-- Initial Base Expression
		if isUnop() then
			local opTk = get()
			local ex = subexpr(UnaryPriority)
			curNode = MkNode{
				Type = 'UnopExpr';
				Token_Op = opTk;
				Rhs = ex;
				GetFirstToken = function(self)
					return self.Token_Op
				end;
				GetLastToken = function(self)
					return self.Rhs:GetLastToken()
				end;
			}
		else 
			curNode = simpleexpr()
			assert(curNode, "nil simpleexpr")
		end

		-- Apply Precedence Recursion Chain
		while isBinop() and BinaryPriority[peek().Source][1] > limit do
			local opTk = get()
			local rhs = subexpr(BinaryPriority[opTk.Source][2])
			assert(rhs, "RhsNeeded")
			curNode = MkNode{
				Type = 'BinopExpr';
				Lhs = curNode;
				Rhs = rhs;
				Token_Op = opTk;
				GetFirstToken = function(self)
					return self.Lhs:GetFirstToken()
				end;
				GetLastToken = function(self)
					return self.Rhs:GetLastToken()
				end;
			}
		end

		-- Return result
		return curNode
	end

	-- Expression
	expr = function()
		return subexpr(0)
	end

	-- Expression statement
	local function exprstat()
		local ex = primaryexpr()
		if ex.Type == 'MethodExpr' or ex.Type == 'CallExpr' then
			-- all good, calls can be statements
			return MkNode{
				Type = 'CallExprStat';
				Expression = ex;
				GetFirstToken = function(self)
					return self.Expression:GetFirstToken()
				end;
				GetLastToken = function(self)
					return self.Expression:GetLastToken()
				end;
			}
		else
			-- Assignment expr
			local lhs = {ex}
			local lhsSeparator = {}
			while peek().Source == ',' do
				table.insert(lhsSeparator, get())
				local lhsPart = primaryexpr()
				if lhsPart.Type == 'MethodExpr' or lhsPart.Type == 'CallExpr' then
					error("Bad left hand side of assignment")
				end
				table.insert(lhs, lhsPart)
			end
			local eq = get()
			if not AssignmentOperators[eq.Source] then
				error(getTokenStartPosition(eq)..": `=` or compound assigment expected")
			end
			local rhs = {expr()}
			local rhsSeparator = {}
			while peek().Source == ',' do
				table.insert(rhsSeparator, get())
				table.insert(rhs, expr())
			end
			if eq.Source ~= '=' and (#rhs > 1 or #lhs > 1) then
				error(getTokenStartPosition(ex:GetFirstToken())..": Compound assignment statements must operate on single values")
			end
			return MkNode{
				Type = 'AssignmentStat';
				Rhs = rhs;
				Lhs = lhs;
				Token_Equals = eq;
				Token_LhsSeparatorList = lhsSeparator;
				Token_RhsSeparatorList = rhsSeparator;
				GetFirstToken = function(self)
					return self.Lhs[1]:GetFirstToken()
				end;
				GetLastToken = function(self)
					return self.Rhs[#self.Rhs]:GetLastToken()
				end;
			}
		end
	end

	-- If statement
	local function ifstat()
		local ifKw = get()
		local condition = expr()
		local thenKw = expect('Keyword', 'then')
		local ifBody = block()
		local elseClauses = {}
		while peek().Source == 'elseif' or peek().Source == 'else' do
			local elseifKw = get()
			local elseifCondition, elseifThenKw;
			if elseifKw.Source == 'elseif' then
				elseifCondition = expr()
				elseifThenKw = expect('Keyword', 'then')
			end
			local elseifBody = block()
			table.insert(elseClauses, {
				Condition = elseifCondition;
				Body = elseifBody;
				--
				ClauseType = elseifKw.Source;
				Token = elseifKw;
				Token_Then = elseifThenKw;
			})
			if elseifKw.Source == 'else' then
				break
			end
		end
		local enKw = expect('Keyword', 'end')
		return MkNode{
			Type = 'IfStat';
			Condition = condition;
			Body = ifBody;
			ElseClauseList = elseClauses;
			--
			Token_If = ifKw;
			Token_Then = thenKw;
			Token_End = enKw;
			GetFirstToken = function(self)
				return self.Token_If
			end;
			GetLastToken = function(self)
				return self.Token_End
			end;
		}
	end

	-- Do statement
	local function dostat()
		local doKw = get()
		local body, enKw = blockbody('end')
		--
		return MkNode{
			Type = 'DoStat';
			Body = body;
			--
			Token_Do = doKw;
			Token_End = enKw;
			GetFirstToken = function(self)
				return self.Token_Do
			end;
			GetLastToken = function(self)
				return self.Token_End
			end;
		}
	end

	-- While statement
	local function whilestat()
		local whileKw = get()
		local condition = expr()
		local doKw = expect('Keyword', 'do')
		local body, enKw = blockbody('end')
		--
		return MkNode{
			Type = 'WhileStat';
			Condition = condition;
			Body = body;
			--
			Token_While = whileKw;
			Token_Do = doKw;
			Token_End = enKw;
			GetFirstToken = function(self)
				return self.Token_While
			end;
			GetLastToken = function(self)
				return self.Token_End
			end;
		}
	end

	-- For statement
	local function forstat()
		local forKw = get()
		local loopVars, loopVarColons, loopVarTypes, loopVarCommas = varlist()
		if peek().Source == '=' then
			local eqTk = get()
			local exprList, exprCommaList = exprlist()
			if #exprList < 2 or #exprList > 3 then
				error("expected 2 or 3 values for range bounds")
			end
			local doTk = expect('Keyword', 'do')
			local body, enTk = blockbody('end')
			return MkNode{
				Type = 'NumericForStat';
				VarList = loopVars;
				VarTypeList = loopVarTypes;
				RangeList = exprList;
				Body = body;
				--
				Token_For = forKw;
				Token_VarCommaList = loopVarCommas;
				Token_VarColonList = loopVarColons;
				Token_Equals = eqTk;
				Token_RangeCommaList = exprCommaList;
				Token_Do = doTk;
				Token_End = enTk;
				GetFirstToken = function(self)
					return self.Token_For
				end;
				GetLastToken = function(self)
					return self.Token_End
				end;
			}
		elseif peek().Source == 'in' then
			local inTk = get()
			local exprList, exprCommaList = exprlist()
			local doTk = expect('Keyword', 'do')
			local body, enTk = blockbody('end')
			return MkNode{
				Type = 'GenericForStat';
				VarList = loopVars;
				VarTypeList = loopVarTypes;
				GeneratorList = exprList;
				Body = body;
				--
				Token_For = forKw;
				Token_VarCommaList = loopVarCommas;
				Token_VarColonList = loopVarColons;
				Token_In = inTk;
				Token_GeneratorCommaList = exprCommaList;
				Token_Do = doTk;
				Token_End = enTk;
				GetFirstToken = function(self)
					return self.Token_For
				end;
				GetLastToken = function(self)
					return self.Token_End
				end;
			}
		else
			error("`=` or in expected")
		end
	end

	-- Repeat statement
	local function repeatstat()
		local repeatKw = get()
		local body, untilTk = blockbody('until')
		local condition = expr()
		return MkNode{
			Type = 'RepeatStat';
			Body = body;
			Condition = condition;
			--
			Token_Repeat = repeatKw;
			Token_Until = untilTk;
			GetFirstToken = function(self)
				return self.Token_Repeat
			end;
			GetLastToken = function(self)
				return self.Condition:GetLastToken()
			end;
		}
	end

	-- Local var declaration
	local function localdecl()
		local localKw = get()
		if peek().Source == 'function' then
			-- Local function def
			local funcStat = funcdecl(false)
			if #funcStat.NameChain > 1 then
				error(getTokenStartPosition(funcStat.Token_NameChainSeparator[1])..": `(` expected.")
			end
			return MkNode{
				Type = 'LocalFunctionStat';
				FunctionStat = funcStat;
				Token_Local = localKw;
				GetFirstToken = function(self)
					return self.Token_Local
				end;
				GetLastToken = function(self)
					return self.FunctionStat:GetLastToken()
				end;
			}
		elseif peek().Type == 'Ident' then
			-- Local variable declaration
			local varList, varColonList, varTypeList, varCommaList = varlist()
			local exprList, exprCommaList = {}, {}
			local eqToken;
			if peek().Source == '=' then
				eqToken = get()
				exprList, exprCommaList = exprlist()
			end
			return MkNode{
				Type = 'LocalVarStat';
				VarList = varList;
				TypeList = varTypeList;
				ExprList = exprList;
				Token_Local = localKw;
				Token_Equals = eqToken;
				Token_VarCommaList = varCommaList;
				Token_VarColonList = varColonList;
				Token_ExprCommaList = exprCommaList;	
				GetFirstToken = function(self)
					return self.Token_Local
				end;
				GetLastToken = function(self)
					if #self.ExprList > 0 then
						return self.ExprList[#self.ExprList]:GetLastToken()
					else
						return self.VarList[#self.VarList]
					end
				end;
			}
		else
			error("`function` or ident expected")
		end
	end

	-- Return statement
	local function retstat()
		local returnKw = get()
		local exprList;
		local commaList;
		if isBlockFollow() or peek().Source == ';' then
			exprList = {}
			commaList = {}
		else
			exprList, commaList = exprlist()
		end
		return {
			Type = 'ReturnStat';
			ExprList = exprList;
			Token_Return = returnKw;
			Token_CommaList = commaList;
			GetFirstToken = function(self)
				return self.Token_Return
			end;
			GetLastToken = function(self)
				if #self.ExprList > 0 then
					return self.ExprList[#self.ExprList]:GetLastToken()
				else
					return self.Token_Return
				end
			end;
		}
	end

	-- Break statement
	local function breakstat()
		local breakKw = get()
		return {
			Type = 'BreakStat';
			Token_Break = breakKw;
			GetFirstToken = function(self)
				return self.Token_Break
			end;
			GetLastToken = function(self)
				return self.Token_Break
			end;
		}
	end
	
	-- Continue statement
	local function continuestat()
		local continueKw = get()
		return {
			Type = 'ContinueStat';
			Token_Continue = continueKw;
			GetFirstToken = function(self)
				return self.Token_Continue
			end;
			GetLastToken = function(self)
				return self.Token_Continue
			end;
		}
	end
	
	-- Type statement
	local function typestat()
		local exportKw
		if peek().Source == 'export' then
			exportKw = get()
		end
		local typeKw = expect('Ident', 'type')
		local typeName = expect('Ident')
		local genericTypeList = {}
		local genericTypeCommas = {}
		local openAngle, closeAngle
		local addSyntheticEquals = false
		if peek().Source == '<' then
			openAngle = get()
			while true do
				table.insert(genericTypeList, expect('Ident'))
				if peek().Source == ',' then
					table.insert(genericTypeCommas, get())
				else
					break
				end
			end
			-- Special case handling for the `>=` token. In this context treat it
			-- as separate `>` and `=` tokens instead.
			if peek().Source == '>=' then
				closeAngle = get()
				closeAngle.Source = '>'
				addSyntheticEquals = true
			else
				closeAngle = expect('Symbol', '>')
			end
		end
		local equals
		if addSyntheticEquals then
			equals = {
				Type = 'Symbol';
				Source = '=';
				LeadingWhite = "";
			}
		else
			equals = expect('Symbol', '=')
		end
		local mainType = typeexpr()
		return MkNode{
			Type = 'TypeStat';
			Ident = typeName;
			GenericTypeList = genericTypeList;
			AliasedType = mainType;
			--
			Token_Export = exportKw;
			Token_Type = typeKw;
			Token_OpenAngle = openAngle;
			Token_CloseAngle = closeAngle;
			Token_GenericTypeCommaList = genericTypeCommas;
			Token_Equals = equals;
			GetFirstToken = function(self)
				if self.Token_Export then
					return self.Token_Export
				else
					return self.Token_Type
				end
			end;
			GetLastToken = function(self)
				return self.AliasedType:GetLastToken()
			end;
		}
	end

	-- Expression
	local function statement()
		local tok = peek()
		if tok.Source == 'if' then
			return false, ifstat()
		elseif tok.Source == 'while' then
			return false, whilestat()
		elseif tok.Source == 'do' then
			return false, dostat()
		elseif tok.Source == 'for' then
			return false, forstat()
		elseif tok.Source == 'repeat' then
			return false, repeatstat()
		elseif tok.Source == 'function' then
			return false, funcdecl(false)
		elseif tok.Source == 'local' then
			return false, localdecl()
		elseif tok.Source == 'return' then
			return true, retstat()
		elseif tok.Source == 'break' then
			return true, breakstat()
		elseif tok.Source == 'type' or tok.Source == 'export' then
			return false, typestat()
		elseif tok.Source == 'continue' then
			if peek(1).Source == 'end' or peek(1).Source == ';' then
				return true, continuestat()
			else
				return false, exprstat()
			end
		else
			return false, exprstat()
		end
	end

	-- Chunk
	block = function()
		local statements = {}
		local semicolons = {}
		local isLast = false
		while not isLast and not isBlockFollow() do
			-- Parse statement
			local stat;
			isLast, stat = statement()
			table.insert(statements, stat)
			local next = peek()
			if next.Type == 'Symbol' and next.Source == ';' then
				local semiList = {}
				while next.Type == 'Symbol' and next.Source == ';' do
					table.insert(semiList, get())
					next = peek()
				end
				semicolons[#statements] = semiList
			end
		end
		return {
			Type = 'StatList';
			StatementList = statements;
			SemicolonList = semicolons;
			GetFirstToken = function(self)
				if #self.StatementList == 0 then
					return nil
				else
					return self.StatementList[1]:GetFirstToken()
				end
			end;
			GetLastToken = function(self)
				if #self.StatementList == 0 then
					return nil
				elseif self.SemicolonList[#self.StatementList] then
					-- Last token may be one of the semicolon separators
					local semis = self.SemicolonList[#self.StatementList]
					if semis then
						return semis[#semis]
					end
				else
					return self.StatementList[#self.StatementList]:GetLastToken()
				end
			end;
		}
	end

	return block()
end

return parse