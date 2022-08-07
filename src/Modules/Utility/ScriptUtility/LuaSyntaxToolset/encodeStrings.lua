
function encodeCharacter(normalCharacter)
	return "\\x"..string.format("%X", string.byte(normalCharacter))
end


function encode(str, quot)
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
				table.insert(elements, str:sub(p, p + 3))
				p += 4
			elseif escape == 'u' then
				local q = str:find('}', p)
				table.insert(elements, str:sub(p, q))
				p = q + 1
			else
				-- Normal escape
				table.insert(elements, '\\'..escape)
				p += 2
			end
		else
			-- Normal character
			table.insert(elements, encodeCharacter(c))
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
				token.Source = encode(token.Source, quot)
			end
		end	
	end
end
