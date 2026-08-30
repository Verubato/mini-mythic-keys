-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")

-- RegisterSlashCommand hands each alias to the client as its own SLASH_<name><n> global, so
-- there is no table listing them to compare against; this is a search over _G instead.
local function hasSlashAlias(command)
	for key, value in pairs(_G) do
		if type(key) == "string" and key:sub(1, 6) == "SLASH_" and value == command then
			return true
		end
	end

	return false
end

smoke.Run("MiniMythicKeys", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")

		-- The settings panel button calls this to reach the window from another file.
		-- tests/TestToggleWindow.lua covers what it actually does to the window.
		fw.eq(type(context.Addon.ToggleWindow), "function", "ToggleWindow exposed")

		fw.truthy(hasSlashAlias("/minikeys"), "/minikeys registered")
		fw.truthy(hasSlashAlias("/mkeys"), "/mkeys registered")
	end,
})
