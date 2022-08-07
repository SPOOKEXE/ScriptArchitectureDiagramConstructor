--[[
function lookupify(array)

Turn an array of items into a set where set[item] = true
Useful for declaring static sets of strings.
]]
return function(tb)
	for _, v in pairs(tb) do
		tb[v] = true
	end
	return tb
end