-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")

smoke.Run("MiniMythicKeys", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")

		-- The settings panel button calls this to reach the window from another file.
		-- tests/TestToggleWindow.lua covers what it actually does to the window.
		fw.eq(type(context.Addon.ToggleWindow), "function", "ToggleWindow exposed")
	end,
})
