
--[[
function tokenize(text)

Turn a string containing Lua code into an array of tokens.
]]

local lookupify = require(script.Parent.lookupify)

-- Whitespace characters
local WhitespaceCharacters = require(script.Parent.WhitespaceCharacters)

local CharacterForEscape = {['r'] = '\r', ['n'] = '\n', ['t'] = '\t', ['"'] = '"', ["'"] = "'", ['\\'] = '\\'}

local AllIdentStartChars = lookupify{'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 
                                     'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 
                                     's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
                                     'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 
                                     'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 
                                     'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '_'}

local AllIdentifierCharacters = require(script.Parent.AllIdentifierCharacters)

local Keywords = require(script.Parent.Keywords)

local BinaryDigits = lookupify{'0', '1'}
local Digits = lookupify{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}
local DigitsPlusSeparator = lookupify{'_', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}
local HexDigits = lookupify{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 
	                            'A', 'a', 'B', 'b', 'C', 'c', 'D', 'd', 'E', 'e', 'F', 'f'}

local Symbols = lookupify{'+', '-', '*', '/', '^', '%', ',', '{', '}', '[', ']', '(', ')', ';', '#', '.', ':', '?', '|', '&'}

local EqualSymbols = lookupify{
	'~', '=', '>', '<', -- Lua 5.1
	'+', '-', '*', '/', '^', '%', -- Luau
}


local function tokenize(text)
	-- Tracking for the current position in the buffer, and
	-- the current line / character we are on.
	local p = 1
	local length = #text

	-- Output buffer for tokens
	local tokenBuffer = {}

	-- Get a character, or '' if at eof
	local function look(n)
		n = n or 0
		if p <= length then
			return text:sub(p + n, p + n)
		else
			return ''
		end
	end
	local function get()
		if p <= length then
			local c = text:sub(p, p)
			p = p + 1
			return c
		else
			return ''
		end
	end

	-- Error
	local olderr = error
	local function error(str)
		local q = 1
		local line = 1
		local char = 1
		while q <= p do
			if text:sub(q, q) == '\n' then
				line = line + 1
				char = 1
			else
				char = char + 1
			end
			q = q + 1
		end
		-- Toggle for debugging		
		--for _, token in pairs(tokenBuffer) do
		--	print(token.Type.."<"..token.Source..">")
		--end
		olderr("file<"..line..":"..char..">: "..str)
	end

	local function warn(str)
		-- TODO: Maybe record for lints or something?
	end

	-- Consume a long data with equals count of `eqcount'
	local function longdata(eqcount)
		while true do
			local c = get()
			if c == '' then
				error("Unfinished long string.")
			elseif c == ']' then
				local done = true -- Until contested
				for i = 1, eqcount do
					if look() == '=' then
						p = p + 1
					else
						done = false
						break
					end
				end
				if done and get() == ']' then
					return
				end
			end
		end
	end

	-- Get the opening part for a long data `[` `=`* `[`
	-- Precondition: The first `[` has been consumed
	-- Return: nil or the equals count
	local function getopen()
		local startp = p
		while look() == '=' do
			p = p + 1
		end
		if look() == '[' then
			p = p + 1
			return p - startp - 1
		else
			p = startp
			return nil
		end
	end

	-- Add token
	local whiteStart = 1
	local tokenStart = 1
	local function token(type)
		local tk = {
			Type = type;
			LeadingWhite = text:sub(whiteStart, tokenStart-1);
			Source = text:sub(tokenStart, p-1);
		}
		table.insert(tokenBuffer, tk)
		whiteStart = p
		tokenStart = p
		return tk
	end

	-- Parse tokens loop
	while true do
		-- Mark the whitespace start
		whiteStart = p

		-- Get the leading whitespace + comments
		while true do
			local c = look()
			if c == '' then
				break
			elseif c == '-' then
				if look(1) == '-' then
					p = p + 2
					-- Consume comment body
					if look() == '[' then
						p = p + 1
						local eqcount = getopen()
						if eqcount then
							-- Long comment body
							longdata(eqcount)
						else
							-- Normal comment body
							while true do
								local c2 = get()
								if c2 == '' or c2 == '\n' then
									break
								end
							end
						end
					else
						-- Normal comment body
						while true do
							local c2 = get()
							if c2 == '' or c2 == '\n' then
								break
							end
						end
					end
				else
					break
				end
			elseif WhitespaceCharacters[c] then
				p = p + 1
			else
				break
			end
		end
		local leadingWhite = text:sub(whiteStart, p-1)

		-- Mark the token start
		tokenStart = p

		-- Switch on token type
		local c1 = get()
		if c1 == '' then
			-- End of file
			token('Eof')
			break
		elseif c1 == '\'' or c1 == '\"' then
			-- String constant
			while true do
				local c2 = get()
				if c2 == '\\' then
					local c3 = get()
					if c3 == 'x' then
						-- Hexidecimal character
						local c4 = get()
						local c5 = get()
						if not HexDigits[c4] or not HexDigits[c5] then
							error("Invalid Hexidecimal Escape Sequence `\\x"..c4..c5.."`")
						end
					elseif c3 == 'u' then
						-- Unicode character
						local c4 = get()
						if c4 ~= '{' then
							error("Invalid Unicode Escape Sequence `\\u"..c4.."`")
						end
						local codePoint = ""
						while true do
							local cbody = get()
							if cbody == '' then
								error("Unfinished Unicode Escape Sequence at End of File")
							elseif cbody == '}' then
								break
							elseif HexDigits[cbody] then
								codePoint = codePoint..cbody
							else
								error("Invalid Unicode Escape Sequence `\\u{"..codePoint..cbody.."`")
							end
						end
						if codePoint == "" then
							error("Empty Unicode Escape Sequence")
						elseif tonumber(codePoint, 16) >= 0x10FFFF then
							error("Unicode Escape Sequence Out of Range")
						end
					elseif c3 == 'z' then
						-- Whitespace trimmer
						-- Nothing to do					
					else						
						local esc = CharacterForEscape[c3]
						if not esc then
							warn("Invalid Escape Sequence `\\"..c3.."`.")
						end
					end
				elseif c2 == c1 then
					break
				end
			end
			token('String')
		elseif AllIdentStartChars[c1] then
			-- Ident or Keyword
			while AllIdentifierCharacters[look()] do
				p = p + 1
			end
			if Keywords[text:sub(tokenStart, p-1)] then
				token('Keyword')
			else
				token('Ident')
			end
		elseif Digits[c1] or (c1 == '.' and Digits[look()]) then
			-- Note: The character directly after the .
			-- Number
			if c1 == '0' and look():lower() == 'x' then
				p = p + 1
				-- Hex number
				while HexDigits[look()] or look() == '_' do
					p = p + 1
				end
			elseif c1 == '0' and look():lower() == 'b' then
				p = p + 1
				-- Binary number
				while BinaryDigits[look()] or look() == '_' do
					p = p + 1
				end
			else
				-- Normal Number
				while DigitsPlusSeparator[look()] do
					p = p + 1
				end
				if look() == '.' then
					-- With decimal point
					p = p + 1
					while DigitsPlusSeparator[look()] do
						p = p + 1
					end
				end
				if look() == 'e' or look() == 'E' then
					-- With exponent
					p = p + 1
					if look() == '-' then
						p = p + 1
					end
					while DigitsPlusSeparator[look()] do
						p = p + 1
					end
				end
			end
			token('Number')
		elseif c1 == '[' then
			-- '[' Symbol or Long String
			local eqCount = getopen()
			if eqCount then
				-- Long string
				longdata(eqCount)
				token('String')
			else
				-- Symbol
				token('Symbol')
			end
		elseif c1 == '.' then
			-- Greedily consume up to 3 `.` for . / .. / ... tokens
			-- Also consume "..=" compound concatenation operator in this case
			if look() == '.' then
				get()
				if look() == '.' or look() == '=' then
					get()
				end
			end
			token('Symbol')
		elseif c1 == '-' and look() == '>' then
			-- Special handling for `->`
			get()
			token('Symbol')
		elseif EqualSymbols[c1] then
			if look() == '=' then
				get()
			end
			token('Symbol')
		elseif Symbols[c1] then
			token('Symbol')
		else
			error("Bad symbol `"..c1.."` in source.")
		end
	end
	return tokenBuffer
end

return tokenize
