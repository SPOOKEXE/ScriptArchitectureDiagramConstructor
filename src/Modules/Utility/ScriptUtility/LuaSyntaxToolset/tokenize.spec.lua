return function()
	local tokenize = require(script.Parent.tokenize)
	
	describe("tokenize", function()
		it("should succeed with no input", function()
			local output = tokenize("")
		end)
		
		it("should parse a basic input", function()
			local output = tokenize("local a = 5")
			expect(#output).to.equal(5) -- local, a, =, 5, EOF
		end)
	end)
	
	describe("new type related operators", function()
		it("should accept the optional type operator as a token", function()
			local output = tokenize("??")
			expect(#output).to.equal(3) -- ?, ?, EOF
		end)
		
		it("should accept the union operator as a token", function()
			local output = tokenize("||")
			expect(#output).to.equal(3) -- ?, ?, EOF
		end)
		
		it("should accept the intersection operator as a token", function()
			local output = tokenize("&&")
			expect(#output).to.equal(3) -- ?, ?, EOF
		end)
	end)
	
	describe("type arrow operator", function()
		it("should parse an arrow as a single token", function()
			local output = tokenize("->->")
			expect(#output).to.equal(3) -- ->, ->, EOF
		end)
	end)
	
	describe("compound operators", function()
		it("should accept Luau compound operators", function()
			local output = tokenize[[+=,-=,%=]]
			expect(#output).to.equal(6)
			local output2 = tokenize[[/=,..=]]
			expect(#output2).to.equal(4)
		end)
	end)
	
	describe("number literals", function()
		it("should accept hexidecimal literals", function()
			tokenize[[0xABC, 0xabc, 0Xabc]]
		end)
		
		it("should accept underscores in number literals", function()
			local output = tokenize[[0xDEAD_BEEF, 100_000, 0x__42__, 0b__0_1_]]
			expect(#output).to.equal(8)
		end)
		
		it("should accept underscores in floating point literals", function()
			local output = tokenize[[.5, 0._7, 12.3_4E_78]]
			expect(#output).to.equal(6)
		end)
	end)
	
	describe("string literals", function()
		it("should parse hex constants", function()
			local output = tokenize[[local a = "\x5A"]]
			expect(#output).to.equal(5)
		end)
		
		it("should fail to parse a bad hex constant", function()
			expect(function()
				local output = tokenize[[local a = "\x5G"]]
			end).to.throw()
		end)
		
		it("should parse unicode constants", function()
			local output = tokenize[[local a = "\u{5Ab}"]]
			expect(#output).to.equal(5)
		end)
		
		it("should fail a unicode constant out of range", function()
			expect(function()
				tokenize[[local a = "\u{6456464}"]]
			end).to.throw()
		end)
		
		it("should fail an empty unicode constant", function()
			expect(function()
				tokenize[[local a = "\u{}"]]
			end).to.throw()
		end)
		
		it("should should fail an unfinished unicode constant", function()
			expect(function()
				tokenize[[local a = "\u{AB"]]
			end).to.throw()
		end)
		
		it("should accept the whitespace trimming escape", function()
			tokenize[[local a = "\z"]]
		end)
		
		it("should accept a bad escape sequence anyways", function()
			-- Lua 5.2+ does not accept the follow, but Lua 5.1 / Luau do
			expect(function()
				tokenize[[local a = "\LOL"]]
			end).never.to.throw()
		end)
	end)
end