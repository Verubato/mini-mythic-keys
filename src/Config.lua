local addonName, addon = ...

local function Init()
	local mini = addon.Framework
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

	mini:PanelHeader({
		Parent = panel,
		Lines = {
			"Responds to \"!key\" and \"!keys\" in party, raid, and guild chat with your Mythic+ keystone.",
			"Use /key or /keys to open a window showing all party and guild keystones.",
			"Use /allkeys to post all party keystones to group chat.",
		},
		Gap = verticalSpacing / 2,
	})
end

addon.Framework:WaitForAddonLoad(Init)
