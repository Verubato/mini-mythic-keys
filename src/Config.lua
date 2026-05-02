local addonName, addon = ...

local function Init()
	local mini = addon.MiniFramework
	local verticalSpacing = mini.VerticalSpacing
	local horizontalSpacing = mini.HorizontalSpacing

	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = mini:AddCategory(panel)
	if not category then return end

	mini:RegisterSlashCommand(category, panel, {
		"/minimythickeys",
		"/minimk",
		"/mmk",
	})

	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", horizontalSpacing, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local line1 = panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	line1:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -(verticalSpacing / 2))
	line1:SetText("Responds to \"!key\" and \"!keys\" in party, raid, and guild chat with your Mythic+ keystone.")

	local line2 = panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -(verticalSpacing / 2))
	line2:SetText("Use /key or /keys to open a window showing all party and guild keystones.")
end

addon.MiniFramework:WaitForAddonLoad(Init)
