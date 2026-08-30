-- OnEvent, TrimWhitespace and the command match are all file-local, so every case here is
-- driven by firing the chat events the addon actually registers and reading SendChatMessage's
-- arguments back.
--
-- The mock's issecretvalue always answers false (see build/Lua/WowMock.lua), so the secret
-- branch below swaps it out for one that recognises a sentinel string as the only secret
-- value, exactly where a real secret chat message would arrive.

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

---Fires message over event and returns the (message, channel) SendChatMessage was called
---with, or nil, nil if it was never called.
---@param event string
---@param message string
---@param overrides table<string, any>?
---@return string? sentMessage
---@return string? channel
local function Send(event, message, overrides)
	local sentMessage, channel

	WithGlobals(overrides or {}, function()
		WithGlobals({
			SendChatMessage = function(m, c)
				sentMessage, channel = m, c
			end,
		}, function()
			WowMock.FireEvent(event, message)
		end)
	end)

	return sentMessage, channel
end

fw.describe("MiniMythicKeys - chat command routing", function()
	local context

	fw.before_each(function()
		context = harness.Load("MiniMythicKeys")

		-- BACKPACK_CONTAINER and NUM_BAG_SLOTS aren't in build/Lua/WowMock.lua at all, so
		-- FindKey's bag loop errors on nil arithmetic the moment a command matches. Install()
		-- wipes any global these tests set ahead of Load, so they're set to the real client's
		-- values here instead, after the fresh mock is in place.
		_G.BACKPACK_CONTAINER = 0
		_G.NUM_BAG_SLOTS = 4

		harness.Login(context)
	end)

	fw.it("replies on PARTY for CHAT_MSG_PARTY", function()
		local _, channel = Send("CHAT_MSG_PARTY", "!key")

		fw.eq(channel, "PARTY", "party channel")
	end)

	fw.it("replies on PARTY for CHAT_MSG_PARTY_LEADER too", function()
		local _, channel = Send("CHAT_MSG_PARTY_LEADER", "!key")

		fw.eq(channel, "PARTY", "party leader routes to the same party channel")
	end)

	fw.it("replies on RAID for CHAT_MSG_RAID", function()
		local _, channel = Send("CHAT_MSG_RAID", "!key")

		fw.eq(channel, "RAID", "raid channel")
	end)

	fw.it("replies on RAID for CHAT_MSG_RAID_LEADER too", function()
		local _, channel = Send("CHAT_MSG_RAID_LEADER", "!key")

		fw.eq(channel, "RAID", "raid leader routes to the same raid channel")
	end)

	fw.it("replies on GUILD for CHAT_MSG_GUILD", function()
		local _, channel = Send("CHAT_MSG_GUILD", "!key")

		fw.eq(channel, "GUILD", "guild channel")
	end)

	fw.it("also matches the !keys alias", function()
		local _, channel = Send("CHAT_MSG_PARTY", "!keys")

		fw.eq(channel, "PARTY", "the plural alias matches too")
	end)

	fw.it("matches through TrimWhitespace's leading and trailing spaces and mixed case", function()
		local _, channel = Send("CHAT_MSG_PARTY", "  !KeY  ")

		fw.eq(channel, "PARTY", "trimmed and lower-cased before comparing")
	end)

	fw.it("says nothing when the message doesn't match a command", function()
		local sentMessage = Send("CHAT_MSG_PARTY", "hello there")

		fw.is_nil(sentMessage, "no reply for ordinary chat")
	end)

	fw.it("says nothing for a partial match, since the comparison is exact", function()
		local sentMessage = Send("CHAT_MSG_PARTY", "!key please")

		fw.is_nil(sentMessage, "trailing text after the command is not a match")
	end)

	fw.it("says nothing while in combat, even for a matching command", function()
		WowMock.State.InCombat = true

		local sentMessage = Send("CHAT_MSG_PARTY", "!key")

		fw.is_nil(sentMessage, "InCombatLockdown short-circuits the whole handler")
	end)
end)

fw.describe("MiniMythicKeys - the secret chat message guard", function()
	fw.it("ignores a secret chat message instead of pattern matching it", function()
		-- The addon captures issecretvalue into a module-local the moment its file loads, so
		-- the override has to survive past WowMock.Install, which always resets the global
		-- back to its default before a normal harness.Load gets to run the addon's files.
		-- Installing here first, then loading with install = false, keeps the override alive
		-- for the addon's own load. The sentinel is the command text itself: without the
		-- guard this would match and reply, so a nil reply can only mean the guard fired.
		local sentinel = "!key"
		local sentMessage

		WowMock.Install()

		WithGlobals({
			issecretvalue = function(v)
				return v == sentinel
			end,
		}, function()
			local context = harness.Load("MiniMythicKeys", { install = false })
			_G.BACKPACK_CONTAINER = 0
			_G.NUM_BAG_SLOTS = 4
			harness.Login(context)

			WithGlobals({
				SendChatMessage = function(m)
					sentMessage = m
				end,
			}, function()
				WowMock.FireEvent("CHAT_MSG_PARTY", sentinel)
			end)
		end)

		fw.is_nil(sentMessage, "a secret message is dropped before it's ever compared")
	end)
end)
