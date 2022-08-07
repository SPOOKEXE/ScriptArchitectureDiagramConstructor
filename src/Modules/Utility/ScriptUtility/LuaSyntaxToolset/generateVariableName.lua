--[[
Turns an index [0..n) into a variable name. 
0 -> '_'
1 -> 'a'
27 -> 'z'
28 -> '_a'
29 -> '_b' 
etc...
]]
local VarDigits = {'_'}
for i = ('a'):byte(), ('z'):byte() do table.insert(VarDigits, string.char(i)) end
for i = ('A'):byte(), ('Z'):byte() do table.insert(VarDigits, string.char(i)) end
for i = ('0'):byte(), ('9'):byte() do table.insert(VarDigits, string.char(i)) end

local VarStartDigits = {'_'}
for i = ('a'):byte(), ('z'):byte() do table.insert(VarStartDigits, string.char(i)) end
for i = ('A'):byte(), ('Z'):byte() do table.insert(VarStartDigits, string.char(i)) end

local function generateVariableName(index)
	local id = ''
	local d = index % #VarStartDigits
	index = (index - d) / #VarStartDigits
	id = id..VarStartDigits[d+1]
	while index > 0 do
		local d = index % #VarDigits
		index = (index - d) / #VarDigits
		id = id..VarDigits[d+1]
	end
	return id
end

return generateVariableName