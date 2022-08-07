return function()
	local tokenize = require(script.Parent.tokenize)
	local parse = require(script.Parent.parse)
	
	local function doParse(code)
		parse(tokenize(code))
	end
	
	describe("basic parsing", function()
		it("should parse a basic script", function()
			doParse[[local a = 5]]
		end)
	end)
	
	describe("export types", function()
		it("should parse an export type", function()
			doParse[[export type foo = bar<string>]]
		end)
	end)
	
	describe("typeof types", function()
		it("should let you define a type via typeof", function()
			doParse[[local a: typeof(foo + bar);]]
		end)
	end)
	
	describe("generic type usage", function()
		it("should handle you using a generic type", function()
			doParse[[local n: Thing<number, string> = 6]]
		end)
		
		it("should handle the `>=` case in a local statement", function()
			doParse[[local n: Thing<number>= 6]]
		end)
	end)
	
	describe("type statement", function()
		it("should let you alias a type", function()
			doParse[[type Foo = number]]
		end)

		it("should let you alias a generic type", function()
			doParse[[type Set<T> = {[T]: boolean}]]
		end)

		it("should let you use multiple generic argument", function()
			doParse[[type Map<K,V> = {[K]: V}]]
		end)

		it("should handle the `>=` token correctly", function()
			doParse[[type Generic<T>=T]]
		end)
	end)
	
	describe("nil type", function()
		it("can be used in a type statement", function()
			doParse[[type Foo = nil]]
			doParse[[type FooTable = {[number]: nil}]]
		end)
		
		it("can be used as a type", function()
			doParse[[local a: nil = nil]]
		end)
	end)

	describe("table types", function()
		it("should parse a basic table type", function()
			doParse[[
			local a: {}
			]]
		end)

		it("should parse name fields", function()
			doParse[[
			local a: {a: number, b:string}
			local b: {b: c?}?
			]]
		end)

		it("should parse type fields", function()
			doParse[[
			local b: {[boolean]: number}
			local c: {[string]: string, [() -> boolean]: number} = 5
			]]
		end)
	end)
	
	describe("function types", function()
		it("should parse a function with return type", function()
			doParse[[
			function a(b:c, d:e): (f, g)
			end
			]]
		end)

		it("should parse a function type", function()
			doParse[[
			local a: () -> number
			local b: ((number) -> number);
			]]
		end)
	end)

	describe("typed local declarations", function()
		it("should parse a local declaration without types", function()
			doParse[[
			local a
			local b = 7
			local c, d
			]]
		end)

		it("should parse a local declaration with basic types", function()
			doParse[[
			local a: number = 7
			local b, c: string = 7, "test"
			]]
		end)
	end)
	
	describe("compound assigment", function()
		it("should parse a compound assignment operator", function()
			doParse[[
			a += 1
			a -= 2
			a /= 3
			a *= 4
			a ^= 5
			a %= 6
			]]
		end)
		
		it("should not parse a compound assignment with multiple parts", function()
			expect(function()
				doParse[[
				a, b += 6, 7
				]]
			end).to.throw()
		end)
	end)
	
	describe("continue", function()
		it("should parse a continue statement", function()
			doParse[[
			while true do
				continue
			end
			]]
		end)
		
		it("should parse a continue statement with semis", function()
			doParse[[
			while true do
				continue;;
			end
			]]
		end)
		
		it("should parse a continue call", function()
			doParse[[
			while true do
				continue()
			end
			]]
		end)
		
		it("should parse a continue call with semis", function()
			doParse[[
			while true do
				continue();;
			end
			]]
		end)
		
		it("should accept continue as a variable", function()
			doParse[[local continue = 5]]
		end)
	end)
end
