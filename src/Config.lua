local addonName, addon = ...

local function Init()
	local mini = addon.Framework

	-- A styled button clashes with the stock Blizzard art around it in the settings screen.
	mini:SetCustomStyling(true, { Button = false })

	local verticalSpacing = mini.VerticalSpacing

	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = mini:AddCategory(panel)
	if not category then return end

	mini:RegisterSlashCommand(category, panel, {
		"/minimythickeys",
		"/minimk",
		"/mmk",
	})

	local header = mini:PanelHeader({
		Parent = panel,
		Lines = {
			"Responds to \"!key\" and \"!keys\" in party, raid, and guild chat with your Mythic+ keystone.",
			"Use /key or /keys to open a window showing all party and guild keystones.",
			"Use /allkeys to post all party keystones to group chat.",
		},
		Gap = verticalSpacing / 2,
	})

	-- Some players' /keys is taken over by another addon, so this is the only way in for them.
	local openWindow = mini:Button({
		Parent = panel,
		Text = "Open Window",
		Width = 140,
		OnClick = function()
			addon.ToggleWindow()
		end,
	})
	openWindow:SetPoint("TOPLEFT", header.Anchor, "BOTTOMLEFT", 0, -verticalSpacing)
end

addon.Framework:WaitForAddonLoad(Init)
