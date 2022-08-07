local Module = {}

for _, ModuleScript in ipairs( script:GetChildren() ) do
	if ModuleScript:IsA('ModuleScript') then
		Module[ModuleScript.Name] = require(ModuleScript)
	end
end

function Module:Init(pluginObject)
	for mName, mTable in pairs(Module) do
		if typeof(mTable) ~= 'table' or (not mTable.Init) then
			continue
		end
		local System = {}
		for otherName, otherTable in pairs(mTable) do
			if mName == otherName then
				continue
			end
			System[otherName] = otherTable
		end
		mTable:Init(System, pluginObject)
	end
end

return Module