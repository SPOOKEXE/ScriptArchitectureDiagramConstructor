
local lookupify = require(script.lookupify)
local formatTable = require(script.formatTable)

local tokenize = require(script.tokenize)
local parse = require(script.parse)

local printAst = require(script.printAst)
local stripAst = require(script.stripAst)
local formatAst = require(script.formatAst)

local addVariableInfo = require(script.addVariableInfo)
local beautifyVariables = require(script.beautifyVariables)
local minifyVariables = require(script.minifyVariablesAdvanced)

local decodeStrings = require(script.decodeStrings)
local encodeStrings = require(script.encodeStrings)

local Keywords = require(script.Keywords)
local WhitespaceCharacters = require(script.WhitespaceCharacters)
local AllIdentifierCharacters = require(script.AllIdentifierCharacters)

local LuaSyntaxToolset = {}

function LuaSyntaxToolset.minify(source: string, renameGlobals: boolean, doEncodeStrings: boolean)
	local tokens = tokenize(source)
	local ast = parse(tokens)
	local glb, root = addVariableInfo(ast)
	minifyVariables(glb, root, renameGlobals)
	if doEncodeStrings then
		encodeStrings(tokens)
	end
	stripAst(ast)
	return printAst(ast)
end

--[[
string source: The source code to beautify
bool renameVars: Should the local variables be renamed into easily find-replacable naming for reverse engineering?
bool renameGlobals: Should the same be done for globals? (unsafe if get/setfenv were used)
]]
function LuaSyntaxToolset.beautify(source: string, renameVars: boolean, renameGlobals: boolean, doDecodeStrings: boolean)
	local tokens = tokenize(source)
	local ast = parse(tokens)
	local glb, root = addVariableInfo(ast)
	if renameVars then
		beautifyVariables(glb, root, renameGlobals)
	end
	if doDecodeStrings then
		decodeStrings(tokens)
	end
	formatAst(ast)
	return printAst(ast)
end

return LuaSyntaxToolset
