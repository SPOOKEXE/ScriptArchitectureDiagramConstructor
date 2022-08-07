
type SourceScript = BaseScript & { Source : string }

local LuaSyntaxToolsetInstance = script.LuaSyntaxToolset
local LuaSyntaxToolset = require(LuaSyntaxToolsetInstance)
local tokenModule = require(LuaSyntaxToolsetInstance.tokenize)
local parseModule = require(LuaSyntaxToolsetInstance.parse)

-- // Module // --
local Module = {}

function Module:RawTokenParse( ScriptInstance : SourceScript ) : table
	return parseModule(tokenModule(ScriptInstance.Source))
end

function Module:GetRequireTree( sourceContainer : SourceScript )
	
end

function Module:GetFunctionTree( sourceContainer : SourceScript )
	
end

function Module:GetVariableTree( sourceContainer : SourceScript )
	
end

function Module:LinkFunctionTree( ... : SourceScript )

	local sources = { ... }

end

return Module

