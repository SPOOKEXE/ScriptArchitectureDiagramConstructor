local Module = {}

for _, ModuleScript in ipairs( script:GetChildren() ) do
	if ModuleScript:IsA('ModuleScript') then
		Module[ModuleScript.Name] = require(ModuleScript)
	end
end

return Module