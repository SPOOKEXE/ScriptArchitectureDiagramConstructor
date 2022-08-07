return function()
	local formatAst = require(script.Parent.formatAst)
	local tokenize = require(script.Parent.tokenize)
	local parse = require(script.Parent.parse)
	local printAst = require(script.Parent.printAst)
	
	local function doFormat(str)
		local ast = parse(tokenize(str))
		formatAst(ast)
		return printAst(ast)
	end
	
	describe("formatting statements", function()
		it("should format an export type statement", function()
			local str = doFormat[[export  type   foo<T > =blah]]
			expect(str).to.equal[[export type foo<T> = blah]]
		end)
		
		it("should format nil type usage", function()
			local str = doFormat[[local a:nil=nil]]
			expect(str).to.equal[[local a: nil = nil]]
		end)
		
		it("should format a qualified type", function()
			local str = doFormat[[local a:b.c =d.e.  f()]]
			expect(str).to.equal[[local a: b.c = d.e.f()]]
		end)
	end)
	
	describe("formatting locals", function()
		it("should format a local declaration", function()
			doFormat[[
			local a,b,c
			]]
		end)

		it("should format generic type arguments", function()
			local str = doFormat[[local a:foo<bar,baz>]]
			expect(str).to.equal[[local a: foo<bar, baz>]]
			local str2 = doFormat[[local  a  :  Set<T>=value]]
			expect(str2).to.equal[[local a: Set<T> = value]]
		end)

		it("should format a local declaration with types", function()
			local str = doFormat[[local a:number,b:string=7]]
			expect(str).to.equal[[local a: number, b: string = 7]]
			local str2 = doFormat[[local  a   : number,   b :  string  =  7]]
			expect(str2).to.equal[[local a: number, b: string = 7]]
		end)

		it("should format a typed function", function()
			local str = doFormat[[local function  foo(arg:t):number bar()end]]
			expect(str).to.equal"local function foo(arg: t): number\n\tbar()\nend"
		end)

		it("should format a continue statement", function()
			local str = doFormat[[while true do continue end]]
			expect(str).to.equal"while true do\n\tcontinue\nend"
		end)

		it("should format compound assignments", function()
			local str = doFormat[[a+=b b/=c e%=f]]
			expect(str).to.equal"a += b\nb /= c\ne %= f"
		end)

		it("should format a type statement", function()
			local str = doFormat[[type FooBar<T,U>=number]]
			expect(str).to.equal"type FooBar<T, U> = number"
			local str2 = doFormat[[type   FooBar   <T  ,  U  >  =  number]]
			expect(str2).to.equal"type FooBar<T, U> = number"
		end)
	end)
end