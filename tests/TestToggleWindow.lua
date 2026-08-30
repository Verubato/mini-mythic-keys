-- Checks that addon.ToggleWindow, the entry point the settings panel button calls, actually
-- shows and hides the keystone window. A single load, since the smoke test's reload pass
-- would otherwise replace the named global this test reads.

local fw = require("TestFramework")
local harness = require("AddonHarness")

fw.describe("MiniMythicKeys - ToggleWindow", function()
	fw.it("shows and hides the keystone window", function()
		local context = harness.Load("MiniMythicKeys")
		harness.Login(context)

		local window = _G["MiniMythicKeysKeystoneWindow"]
		fw.not_nil(window, "keystone window frame exists")
		fw.eq(window:IsShown(), false, "keystone window starts hidden")

		context.Addon.ToggleWindow()
		fw.eq(window:IsShown(), true, "ToggleWindow shows the window")

		context.Addon.ToggleWindow()
		fw.eq(window:IsShown(), false, "ToggleWindow hides it again")
	end)
end)
