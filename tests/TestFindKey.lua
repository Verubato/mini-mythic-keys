-- FindKey() is file-local, so every case here is driven through the "!key" chat command it
-- backs, reading the result off of what SendChatMessage was called with.

local fw = require("TestFramework")
local harness = require("AddonHarness")
local WowMock = require("WowMock")

---Overrides one or more globals for the duration of fn, restoring them even if fn raises,
---so one failing assertion can't leave a later test running against a patched global.
---@param overrides table<string, any>
---@param fn fun()
local function WithGlobals(overrides, fn)
	local reals = {}

	for name, value in pairs(overrides) do
		reals[name] = _G[name]
		_G[name] = value
	end

	local ok, err = pcall(fn)

	for name, value in pairs(reals) do
		_G[name] = value
	end

	if not ok then
		error(err, 0)
	end
end

---Overrides one or more C_Container fields for the duration of fn, restoring them even if
---fn raises. FindKey reaches C_Container.GetContainerNumSlots etc. as table fields, not
---globals, so these can't go through WithGlobals.
---@param overrides table<string, any>
---@param fn fun()
local function WithContainerOverrides(overrides, fn)
	local reals = {}

	for name, value in pairs(overrides) do
		reals[name] = C_Container[name]
		C_Container[name] = value
	end

	local ok, err = pcall(fn)

	for name, value in pairs(reals) do
		C_Container[name] = value
	end

	if not ok then
		error(err, 0)
	end
end

---Fires "!key" over CHAT_MSG_PARTY and returns the (message, channel) SendChatMessage was
---called with, or nil if it was never called.
---@param containerOverrides table<string, any>?
---@return string? message
---@return string? channel
local function AskForKey(containerOverrides)
	local message, channel

	WithContainerOverrides(containerOverrides or {}, function()
		WithGlobals({
			SendChatMessage = function(m, c)
				message, channel = m, c
			end,
		}, function()
			WowMock.FireEvent("CHAT_MSG_PARTY", "!key")
		end)
	end)

	return message, channel
end

fw.describe("MiniMythicKeys - FindKey", function()
	local context

	fw.before_each(function()
		context = harness.Load("MiniMythicKeys")

		-- BACKPACK_CONTAINER and NUM_BAG_SLOTS aren't in build/Lua/WowMock.lua at all, so
		-- FindKey's bag loop errors on nil arithmetic the moment "!key" fires. Install() wipes
		-- any global these tests set ahead of Load, so they're set to the real client's values
		-- here instead, after the fresh mock is in place.
		_G.BACKPACK_CONTAINER = 0
		_G.NUM_BAG_SLOTS = 4

		harness.Login(context)
	end)

	fw.it("replies that there is no key when every bag is empty", function()
		local message = AskForKey()

		fw.eq(message, "I don't have a key.", "the missing-key fallback")
	end)

	fw.it("replies that there is no key when bags hold items, but none of them is the keystone", function()
		local message = AskForKey({
			GetContainerNumSlots = function()
				return 2
			end,
			GetContainerItemID = function()
				return 12345
			end,
		})

		fw.eq(message, "I don't have a key.", "no bag slot matched the keystone's item id")
	end)

	fw.it("replies with the keystone's item link once it finds one", function()
		local message = AskForKey({
			GetContainerNumSlots = function(bag)
				return bag == 2 and 3 or 0
			end,
			GetContainerItemID = function(bag, slot)
				if bag == 2 and slot == 3 then
					return 180653
				end
				return nil
			end,
			GetContainerItemLink = function(bag, slot)
				if bag == 2 and slot == 3 then
					return "|Hkeystone:180653|h[Keystone: Test]|h"
				end
				return nil
			end,
		})

		fw.eq(message, "|Hkeystone:180653|h[Keystone: Test]|h", "the found keystone's link")
	end)
end)
