return function()
	local stripAst = require(script.Parent.stripAst)
	local tokenize = require(script.Parent.tokenize)
	local parse = require(script.Parent.parse)
	local printAst = require(script.Parent.printAst)
	
	local function doStrip(str)
		local ast = parse(tokenize(str))
		stripAst(ast)
		return printAst(ast)
	end
	
	describe("special cases", function()
		it("should not join `..` and `.5`", function()
			local str = doStrip[[local a = "a" .. .5]]
			expect(str).to.equal[[local a="a".. .5]]
		end)
		
		it("should not join things into a comment", function()
			local str = doStrip[[local a = 5 - -5]]
			expect(str).to.equal[[local a=5- -5]]
		end)
	end)
end
