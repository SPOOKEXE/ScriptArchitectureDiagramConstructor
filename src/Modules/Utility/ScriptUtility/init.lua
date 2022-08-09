
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

function Module:GetScriptRequireTree( sourceContainer : SourceScript )
	-- parse the script
	-- get an array of scripts that are required by this module
end

function Module:LinkScriptsToTree( ... : SourceScript )
	local sources = { ... }
	-- parse scripts
	-- find connections between scripts
	-- provide a table of which script (FullName?) require other scripts
	return {}
end

return Module

