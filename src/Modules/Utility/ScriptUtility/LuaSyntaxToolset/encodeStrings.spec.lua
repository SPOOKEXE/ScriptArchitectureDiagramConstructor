return function()
	local encodeStrings = require(script.Parent.encodeStrings)
	local tokenize = require(script.Parent.tokenize)

	describe("encoding string constants", function()
		it("should encode an empty string token", function()
			expect(function()
				encodeStrings(tokenize[[""]])
			end).never.to.throw()
		end)

		it("should encode a test string", function()
			local tokens = tokenize[["Testing"]]
			encodeStrings(tokens)
			expect(tokens[1].Source).to.equal([["\x54\x65\x73\x74\x69\x6E\x67"]])
		end)

		it("should hex encode unicode text", function()
			local tokens = tokenize[["😜"]]
			encodeStrings(tokens)
			expect(tokens[1].Source).to.equal([["\xF0\x9F\x98\x9C"]])
		end)
	end)
end