return function()
	local printAst = require(script.Parent.printAst)
	local tokenize = require(script.Parent.tokenize)
	local parse = require(script.Parent.parse)
	
	describe("formatting", function()
		it("should print back loops with types", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("for i: number, j:number in iterator() do end")
			check("for i: number = a, b, c  do end")
		end)
		
		it("should print generic type arguments", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("local a: FooBar<a, b, c>;")
			check("local a: baz< a, b,c> = 6")
		end)
		
		it("should print back typeof types", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("type Foo=typeof(foo + bar)")
			check("local a:typeof(foobar) | {}")
		end)
		
		it("should print back type statements", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("type Foo=number")
			check("type Set<T >= {[T]: boolean}")
			check("type Map<K, V> =Bar")
			check("type Map<K,V>=Bar;;")
		end)
		
		it("should print back table types", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("local a: { }")
			check("local a: {[number]: number}")
			check("local a:{field: value, foo:bar}")
			check("local a:  {field: value, [type]: type}")
		end)

		it("should print complex types", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("local a:(b)->c")
			check("local a:(b,c?)->d? | e")
			check("local a: (b & c) | d? | (e)->(f | g)?")
		end)

		it("should print local statements", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("local a")
			check("local a;")
			check("local a,b,c")
			check("local a:type")
			check("local a, b, c")
			check("local a,b: type = c")
			check("local a, b: type=c")
		end)

		it("should print function arg lists", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("function a() end")
			check("function a(...) end")
			check("function a(a,b, ...) end")
			check("function a(a:type, c,...): t end")
			check("function a(a:c,e:f) end")
		end)

		it("should print function arg lists", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("local function a() end")
			check("local function a(...) end")
			check("local function a(a,b, ...) end")
			check("local function a(a:type, c,...): t end")
			check("local function a(a:c,e:f) end")
		end)

		it("should print anonymous function arg lists", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("a = function(a,b, ...) end")
			check("a = function(a:type, b): t end")
			check("a = function(a, b:type,...) end")
		end)

		it("should differentiate local and global functions", function()
			local function check(str)
				expect(printAst(parse(tokenize(str)))).to.equal(str)
			end
			check("local function blah() end")
			check("function blah() end")
			check("function a.b.c(arg) end")
		end)
	end)
end