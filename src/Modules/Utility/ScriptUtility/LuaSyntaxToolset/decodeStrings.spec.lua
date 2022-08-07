return function()
	local decodeStrings = require(script.Parent.decodeStrings)
	local tokenize = require(script.Parent.tokenize)
	
	describe("decoding string constants", function()
		it("should decode some ascii text as hex escapes", function()
			local tokens = tokenize[["\x54\x65\x73\x74\x69\x6e\x67\x20\n\x20\u{FFF}\x31\x32\x33"]]
			decodeStrings(tokens)
			expect(tokens[1].Source).to.equal([["Testing \n \u{FFF}123"]])
		end)
		
		it("should not decode a non-ascii character", function()
			local tokens = tokenize[["\x54\x65\x73\x74\x69\x6e\x67\xAB"]]
			decodeStrings(tokens)
			expect(tokens[1].Source).to.equal([["Testing\xAB"]])
		end)

		it("should uppercase hex and unicode escapes", function()
			local tokens = tokenize[["\x54\x65\x73\x74\x69\x6e\x67\xab\u{fff}"]]
			decodeStrings(tokens)
			expect(tokens[1].Source).to.equal([["Testing\xAB\u{FFF}"]])
		end)
	end)
end
