
local MIN_PRINTABLE = 32
local MAX_PRINTABLE = 126
local ESCAPES = {
	[string.byte('\a')] = 'a',
	[string.byte('\b')] = 'b',
	[string.byte('\f')] = 'f',
	[string.byte('\n')] = 'n',
	[string.byte('\t')] = 't',
	[string.byte('\r')] = 'r',
	[string.byte('\v')] = 'v',
}

function decodeCharacter(chars)
	local code = tonumber(chars, 16)
	local char = string.char(code)
	if code >= MIN_PRINTABLE and code <= MAX_PRINTABLE then
		return string.char(code)
	elseif code >= 0 and code <= 0xFF and ESCAPES[char] then
		return "\\"..ESCAPES[char]
	elseif code <= 0xFF then
		return string.format("\\x%X", code)	
	else
		return string.format("\\u{%X}", code)
	end
end

function decode(str, quot)
	local elements = {quot}
	local p = 2
	local len = #str
	while p < len do
		local c = str:sub(p, p)
		if c == '\\' then
			-- Some kind of escape
			local escape = str:sub(p + 1, p + 1):lower()
			if escape == 'x' then
				-- Hexidecimal escape
				table.insert(elements, decodeCharacter(str:sub(p + 2, p + 3)))
				p += 4
			elseif escape == 'u' then
				local q = str:find('}', p)
				table.insert(elements, decodeCharacter(str:sub(p + 3, q - 1)))
				p = q + 1
			else
				-- Normal escape
				table.insert(elements, '\\'..escape)
				p += 2
			end
		else
			-- Normal character
			table.insert(elements, c)
			p += 1
		end
	end
	table.insert(elements, quot)
	return table.concat(elements)
end

return function(tokens)
	for _, token in pairs(tokens) do
		if token.Type == 'String' then
			-- Don't modify long string constants
			local quot = token.Source:sub(1, 1)
			if quot == '"' or quot == "'" then
				token.Source = decode(token.Source, quot)
			end
		end	
	end
end