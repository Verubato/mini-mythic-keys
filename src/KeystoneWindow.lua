local addonName, addon = ...

local window

local ROW_HEIGHT = 28
-- Minimum widths. Name and Dungeon share whatever the window has spare; Level and Weekly hold
-- a "+30"-sized number and never need more.
local COLS = { Name = 150, Dungeon = 200, Level = 55, Weekly = 90 }
local COL_GAP = 8
local ROW_PADDING = 4
-- Width the scrollbar column reserves on the right of the list, whether or not it's shown.
local SCROLLBAR_WIDTH = 14
-- Fraction of the spare width that goes to Name; the rest goes to Dungeon.
local NAME_GROWTH_SHARE = 0.35

local DEFAULT_WIDTH = 600
local DEFAULT_HEIGHT = 480
-- Narrowest window that still fits every column at its minimum: the list's base width plus the
-- scrollbar gutter, plus the standalone window's content padding and borders.
local MIN_WIDTH = 570
local MIN_HEIGHT = 300

local DEFAULTS = {
	Window = {
		Width = DEFAULT_WIDTH,
		Height = DEFAULT_HEIGHT,
	},
}

local function GetClassColor(className)
	if className and className ~= "" then
		local color = C_ClassColor.GetClassColor(className)
		if color then return color:GetRGB() end
	end
	return 1, 1, 1
end

local function GetDungeonName(mapID)
	if not mapID or mapID == 0 then return "" end
	local name = C_ChallengeMode.GetMapUIInfo(mapID)
	return name or "Unknown"
end

local function BuildList(parent, getDataFn)
	local rows = {}

	-- Every column at its minimum. Anything the window has beyond this is handed to Name and
	-- Dungeon by Layout below, so widening the window widens the list rather than padding it.
	local BASE_WIDTH = ROW_PADDING
		+ COLS.Name
		+ COL_GAP
		+ COLS.Dungeon
		+ COL_GAP
		+ COLS.Level
		+ COL_GAP
		+ COLS.Weekly
		+ ROW_PADDING

	local contentWidth = BASE_WIDTH
	local nameWidth = COLS.Name
	local dungeonWidth = COLS.Dungeon

	local header = CreateFrame("Frame", nil, parent)
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", -SCROLLBAR_WIDTH, 0)
	header:SetHeight(22)

	local hName = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hName:SetPoint("LEFT", ROW_PADDING, 0)
	hName:SetWidth(COLS.Name)
	hName:SetText("Name")
	hName:SetTextColor(0.7, 0.7, 0.7)

	local hDungeon = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hDungeon:SetPoint("LEFT", hName, "RIGHT", COL_GAP, 0)
	hDungeon:SetWidth(COLS.Dungeon)
	hDungeon:SetText("Dungeon")
	hDungeon:SetTextColor(0.7, 0.7, 0.7)

	local hLevel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hLevel:SetPoint("LEFT", hDungeon, "RIGHT", COL_GAP, 0)
	hLevel:SetWidth(COLS.Level)
	hLevel:SetText("Level")
	hLevel:SetTextColor(0.7, 0.7, 0.7)

	local hWeekly = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hWeekly:SetPoint("LEFT", hLevel, "RIGHT", COL_GAP, 0)
	hWeekly:SetWidth(COLS.Weekly)
	hWeekly:SetText("Weekly Best")
	hWeekly:SetTextColor(0.7, 0.7, 0.7)

	local divider = header:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(1, 1, 1, 0.1)
	PixelUtil.SetHeight(divider, 1)
	divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
	divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

	local sf = CreateFrame("ScrollFrame", nil, parent)
	sf:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
	sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 0)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, delta)
		local step = 40
		self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScroll() - delta * step, self:GetVerticalScrollRange())))
	end)

	local sc = CreateFrame("Frame", nil, sf)
	sc:SetSize(BASE_WIDTH, 1)
	sf:SetScrollChild(sc)

	local sb = CreateFrame("Slider", nil, parent, "BackdropTemplate")
	sb:SetWidth(10)
	sb:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -26)
	sb:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	sb:SetMinMaxValues(0, 1)
	sb:SetValue(0)
	sb:SetObeyStepOnDrag(true)
	sb:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	sb:SetBackdropColor(0.10, 0.10, 0.10, 0.6)
	sb:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)
	local thumb = sb:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(0.55, 0.55, 0.55, 0.85)
	sb:SetThumbTexture(thumb)
	sb:Hide()

	local function UpdateScrollBar()
		local fh = sf:GetHeight()
		local ch = sc:GetHeight()
		if fh == 0 then return end
		local maxScroll = math.max(0, ch - fh)
		if maxScroll > 0.5 then
			sb:Show()
			sb:SetMinMaxValues(0, maxScroll)
			sb:SetValue(math.min(sf:GetVerticalScroll(), maxScroll))
			thumb:SetHeight(math.max(20, sb:GetHeight() * (fh / ch)))
		else
			sb:Hide()
		end
	end

	sb:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
	sf:SetScript("OnScrollRangeChanged", UpdateScrollBar)
	sf:HookScript("OnMouseWheel", function() sb:SetValue(sf:GetVerticalScroll()) end)

	-- Re-splits the list width across the flexible columns. Level and Weekly stay fixed, so the
	-- spare width goes to Name and Dungeon - the two that actually truncate.
	local function Layout(width)
		local available = (width or 0) - SCROLLBAR_WIDTH
		local spare = math.max(0, available - BASE_WIDTH)
		local nameExtra = math.floor(spare * NAME_GROWTH_SHARE)

		nameWidth = COLS.Name + nameExtra
		dungeonWidth = COLS.Dungeon + (spare - nameExtra)
		contentWidth = BASE_WIDTH + spare

		hName:SetWidth(nameWidth)
		hDungeon:SetWidth(dungeonWidth)
		sc:SetWidth(contentWidth)

		for _, row in ipairs(rows) do
			row:SetWidth(contentWidth)
			row.Name:SetWidth(nameWidth)
			row.Dungeon:SetWidth(dungeonWidth)
		end
	end

	parent:HookScript("OnSizeChanged", function(_, width)
		Layout(width)
	end)

	local function CreateRow()
		local row = CreateFrame("Frame", nil, sc)
		row:SetHeight(ROW_HEIGHT)
		row:SetWidth(contentWidth)

		row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.Name:SetPoint("LEFT", row, "LEFT", ROW_PADDING, 0)
		row.Name:SetWidth(nameWidth)
		row.Name:SetJustifyH("LEFT")

		row.Dungeon = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.Dungeon:SetPoint("LEFT", row.Name, "RIGHT", COL_GAP, 0)
		row.Dungeon:SetWidth(dungeonWidth)
		row.Dungeon:SetJustifyH("LEFT")

		row.Level = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.Level:SetPoint("LEFT", row.Dungeon, "RIGHT", COL_GAP, 0)
		row.Level:SetWidth(COLS.Level)
		row.Level:SetJustifyH("LEFT")

		row.Weekly = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.Weekly:SetPoint("LEFT", row.Level, "RIGHT", COL_GAP, 0)
		row.Weekly:SetWidth(COLS.Weekly)
		row.Weekly:SetJustifyH("LEFT")

		return row
	end

	local function Refresh()
		-- Re-split before repopulating: the window may have been resized while this tab was hidden.
		Layout(parent:GetWidth())

		for _, row in ipairs(rows) do
			row:Hide()
		end

		local data = getDataFn()
		local entries = {}
		for _, v in pairs(data) do
			if type(v) == "table" then
				entries[#entries + 1] = v
			end
		end

		table.sort(entries, function(a, b)
			return (a.current_keylevel or 0) > (b.current_keylevel or 0)
		end)

		local y = 0
		for i, entry in ipairs(entries) do
			if not rows[i] then
				rows[i] = CreateRow()
			end
			local row = rows[i]

			local r, g, b = GetClassColor(entry.class)
			row.Name:SetTextColor(r, g, b)
			row.Name:SetText(entry.name or "?")

			local level = entry.current_keylevel or 0
			if level > 0 then
				row.Dungeon:SetText(GetDungeonName(entry.current_key))
				row.Level:SetText("+" .. level)
				row.Level:SetTextColor(0.3, 1, 0.3)
			else
				row.Dungeon:SetText("|cff808080No Key|r")
				row.Level:SetText("")
			end

			local best = entry.weeklybest or 0
			if best > 0 then
				row.Weekly:SetText("+" .. best)
				row.Weekly:SetTextColor(1, 0.82, 0)
			else
				row.Weekly:SetText("")
			end

			row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -y)
			row:SetWidth(contentWidth)
			row:Show()

			y = y + ROW_HEIGHT + 2
		end

		if #entries == 0 then
			if not rows[1] then
				rows[1] = CreateRow()
			end
			rows[1].Name:SetText("|cff808080No data yet...|r")
			rows[1].Name:SetTextColor(1, 1, 1)
			rows[1].Dungeon:SetText("")
			rows[1].Level:SetText("")
			rows[1].Weekly:SetText("")
			rows[1]:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
			rows[1]:SetWidth(contentWidth)
			rows[1]:Show()
			y = ROW_HEIGHT
		end

		sc:SetHeight(math.max(1, y))
		sf:SetVerticalScroll(0)
		UpdateScrollBar()
	end

	Layout(parent:GetWidth())

	return { Refresh = Refresh }
end

local function BuildWindow()
	local mini = addon.Framework
	local db = mini:GetSavedVars(DEFAULTS)

	-- The saved size is clamped on the way back in: the screen may have shrunk, the UI scale may
	-- have changed, or the minimums may have moved since it was written.
	local savedWidth = mini:ClampInt(db.Window.Width, MIN_WIDTH, UIParent:GetWidth(), DEFAULT_WIDTH)
	local savedHeight = mini:ClampInt(db.Window.Height, MIN_HEIGHT, UIParent:GetHeight(), DEFAULT_HEIGHT)

	local win = mini:CreateStandaloneWindow({
		Name = addonName .. "KeystoneWindow",
		Title = "Mythic Keys",
		Width = savedWidth,
		Height = savedHeight,
		Resizable = true,
		MinWidth = MIN_WIDTH,
		MinHeight = MIN_HEIGHT,
		OnResizeStop = function(width, height)
			db.Window.Width = math.floor(width + 0.5)
			db.Window.Height = math.floor(height + 0.5)
		end,
	})

	local partyList, guildList

	local refreshBtn = CreateFrame("Button", nil, win.TitleBar)
	refreshBtn:SetSize(60, 22)
	refreshBtn:SetPoint("RIGHT", win.CloseButton, "LEFT", -10, 0)

	local refreshHighlight = refreshBtn:CreateTexture(nil, "HIGHLIGHT")
	refreshHighlight:SetAllPoints(refreshBtn)
	refreshHighlight:SetColorTexture(1, 1, 1, 0.07)

	local refreshText = refreshBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	refreshText:SetAllPoints(refreshBtn)
	refreshText:SetJustifyH("CENTER")
	refreshText:SetJustifyV("MIDDLE")
	refreshText:SetText("Refresh")
	refreshText:SetTextColor(0.5, 0.5, 0.5)

	local refreshBusy = false
	refreshBtn:SetScript("OnEnter", function()
		if not refreshBusy then refreshText:SetTextColor(0.9, 0.9, 0.9) end
	end)
	refreshBtn:SetScript("OnLeave", function()
		if not refreshBusy then refreshText:SetTextColor(0.5, 0.5, 0.5) end
	end)
	refreshBtn:SetScript("OnClick", function()
		if refreshBusy then return end
		refreshBusy = true
		refreshText:SetText("...")
		refreshText:SetTextColor(1, 0.82, 0)
		addon.RequestKeystones()
		C_Timer.After(2, function()
			if partyList then partyList.Refresh() end
			if guildList then guildList.Refresh() end
			refreshBusy = false
			refreshText:SetText("Refresh")
			local isOver = refreshBtn:IsMouseOver()
			refreshText:SetTextColor(isOver and 0.9 or 0.5, isOver and 0.9 or 0.5, isOver and 0.9 or 0.5)
		end)
	end)

	local tabs = mini:CreateTabs({
		Parent = win.Content,
		Tabs = {
			{
				Key = "party",
				Title = "Party",
				Build = function(content)
					partyList = BuildList(content, function()
						return addon.GetMergedPartyKeys()
					end)
				end,
			},
			{
				Key = "guild",
				Title = "Guild",
				Build = function(content)
					guildList = BuildList(content, function()
						return addon.GetMergedGuildKeys()
					end)
				end,
			},
		},
		InitialKey = "party",
		OnTabChanged = function(key)
			if key == "party" and partyList then
				partyList.Refresh()
			elseif key == "guild" and guildList then
				guildList.Refresh()
			end
		end,
	})

	win:HookScript("OnShow", function()
		local key = tabs:GetSelected()
		if key == "party" and partyList then
			partyList.Refresh()
		elseif key == "guild" and guildList then
			guildList.Refresh()
		end
	end)

	return win
end

local initFrame = CreateFrame("Frame") -- luaconv: its handler is a function defined above
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	window = BuildWindow()

	SLASH_MINIMYTHICKEYSWINDOW1 = "/key"
	SLASH_MINIMYTHICKEYSWINDOW2 = "/keys"
	SlashCmdList["MINIMYTHICKEYSWINDOW"] = function()
		window:Toggle()
	end

	SLASH_MINIMYTHICKEYSALLKEYS1 = "/allkeys"
	SlashCmdList["MINIMYTHICKEYSALLKEYS"] = function()
		local channel
		if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
			channel = "INSTANCE_CHAT"
		elseif IsInGroup() then
			channel = "PARTY"
		else
			print("You are not in a group.")
			return
		end

		local data = addon.GetMergedPartyKeys()
		local entries = {}
		for _, v in pairs(data) do
			if type(v) == "table" then
				entries[#entries + 1] = v
			end
		end
		table.sort(entries, function(a, b)
			return (a.current_keylevel or 0) > (b.current_keylevel or 0)
		end)

		for _, entry in ipairs(entries) do
			local level = entry.current_keylevel or 0
			if level > 0 then
				local dungeon = GetDungeonName(entry.current_key)
				SendChatMessage((entry.name or "?") .. ": +" .. level .. " " .. dungeon, channel)
			end
		end
	end
end)
