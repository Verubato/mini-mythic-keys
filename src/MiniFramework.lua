local addonName, addon = ...
local L = addon.L or setmetatable({}, { __index = function(_, k) return k end })
local loader = CreateFrame("Frame")
local loaded = false
local onLoadCallbacks = {}

---@class MiniFramework
local M = {
	VerticalSpacing = 16,
	HorizontalSpacing = 20,
	TextMaxWidth = 600,
}
addon.MiniFramework = M


function M:Notify(msg, ...)
	local formatted = string.format(msg, ...)
	print(addonName .. " - " .. formatted)
end

function M:NotifyCombatLockdown()
	M:Notify(L["Can't do that during combat."])
end


function M:CanOpenOptionsDuringCombat()
	if LE_EXPANSION_LEVEL_CURRENT == nil or LE_EXPANSION_MIDNIGHT == nil then
		return true
	end

	return LE_EXPANSION_LEVEL_CURRENT < LE_EXPANSION_MIDNIGHT
end


function M:AddCategory(panel)
	if not panel then
		error("AddCategory - panel must not be nil.")
	end

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(category)

		return category
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)

		return panel
	end

	return nil
end


---@param options TabOptions
---@return TabReturn
function M:CreateTabs(options)
	assert(options and options.Parent, "CreateTabs: options.Parent required")
	assert(options.Tabs and #options.Tabs > 0, "CreateTabs: options.Tabs required")

	local parent = options.Parent
	local tabHeight = options.TabHeight or 22
	local tabMinWidth = options.TabMinWidth or 80
	local tabSpacing = options.TabSpacing or 6
	local stripHeight = options.StripHeight or 28
	local vertical = options.Vertical
	local stripWidth = options.StripWidth or 130
	local horizontalPadding = options.HorizontalPadding or 0

	local insets = options.ContentInsets or {}
	local insetL = insets.Left or 0
	local insetR = insets.Right or 0
	local insetT = insets.Top or 0
	local insetB = insets.Bottom or 10

	local strip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	if vertical then
		strip:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		strip:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
		strip:SetWidth(stripWidth)
	else
		strip:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		strip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
		strip:SetHeight(stripHeight)
	end

	local body = CreateFrame("Frame", nil, parent)
	if vertical then
		body:SetPoint("TOPLEFT", strip, "TOPRIGHT", horizontalPadding + insetL, -insetT)
		body:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -insetR, insetB)
	else
		body:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", insetL, -insetT)
		body:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -insetR, insetB)
	end

	---@type {Key:string, Title:string, Button:table, Content:table}[]
	local tabs = {}
	local keyToIndex = {}
	local selectedKey

	local function GetIndex(keyOrIndex)
		if type(keyOrIndex) == "number" then
			return keyOrIndex
		end
		if type(keyOrIndex) == "string" then
			return keyToIndex[keyOrIndex]
		end
	end

	local function SizeToText(btn)
		local fs = btn.Text
		local w = tabMinWidth
		if fs and fs.GetUnboundedStringWidth then
			w = math.max(tabMinWidth, fs:GetUnboundedStringWidth() + 26)
		elseif fs and fs.GetStringWidth then
			w = math.max(tabMinWidth, fs:GetStringWidth() + 26)
		end
		btn:SetWidth(w)
	end

	local normalR, normalG, normalB = GameFontNormal:GetTextColor()

	-- Horizontal mode: single continuous underline split around the selected tab.
	local lineLeft = strip:CreateTexture(nil, "OVERLAY")
	PixelUtil.SetHeight(lineLeft, 1)
	lineLeft:SetColorTexture(0.35, 0.35, 0.35, 0.8)

	local lineRight = strip:CreateTexture(nil, "OVERLAY")
	PixelUtil.SetHeight(lineRight, 1)
	lineRight:SetColorTexture(0.35, 0.35, 0.35, 0.8)

	-- Vertical mode: static right-edge separator line.
	if vertical then
		local vLine = strip:CreateTexture(nil, "OVERLAY")
		PixelUtil.SetWidth(vLine, 1)
		vLine:SetColorTexture(0.35, 0.35, 0.35, 0.8)
		PixelUtil.SetPoint(vLine, "TOPRIGHT", strip, "TOPRIGHT", 0, 0)
		PixelUtil.SetPoint(vLine, "BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
	end

	-- Assigned after the tab loop; used in horizontal mode to limit the line to the last tab.
	local lastBtn

	local function SetSelected(btn, isSelected)
		if isSelected then
			btn.Text:SetTextColor(1, 1, 1, 1)
			btn.Highlight:SetAlpha(0)

			if vertical then
				btn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
				btn:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.8)
				if btn.Indicator then btn.Indicator:Show() end
			else
				btn:SetBackdropColor(0, 0, 0, 0)
				btn:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
				btn.BottomEdge:Hide()
				btn.BottomLeftCorner:Hide()
				btn.BottomRightCorner:Hide()
				if btn.Accent then btn.Accent:Show() end
				-- Reanchor line segments to leave a gap at this button.
				lineLeft:ClearAllPoints()
				PixelUtil.SetPoint(lineLeft, "TOPLEFT", strip, "BOTTOMLEFT", 0, 2)
				PixelUtil.SetPoint(lineLeft, "BOTTOMRIGHT", btn, "BOTTOMLEFT", 0, 0)
				lineRight:ClearAllPoints()
				if lastBtn and btn ~= lastBtn then
					PixelUtil.SetPoint(lineRight, "TOPLEFT", btn, "BOTTOMRIGHT", 0, 1)
					PixelUtil.SetPoint(lineRight, "BOTTOMRIGHT", lastBtn, "BOTTOMRIGHT", 0, 0)
					lineRight:Show()
				else
					lineRight:Hide()
				end
			end
		else
			btn:SetBackdropColor(0, 0, 0, 0)
			btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.8)
			btn.Text:SetTextColor(normalR, normalG, normalB, 1)
			btn.Highlight:SetAlpha(0.06)

			if vertical then
				if btn.Indicator then btn.Indicator:Hide() end
			else
				if btn.Accent then btn.Accent:Hide() end
				btn.BottomEdge:Hide()
				btn.BottomLeftCorner:Hide()
				btn.BottomRightCorner:Hide()
			end
		end
	end

	local controller = {}

	function controller.GetSelected(_)
		return selectedKey
	end

	function controller.GetContent(_, keyOrIndex)
		local i = GetIndex(keyOrIndex)
		return i and tabs[i] and tabs[i].Content
	end

	function controller.GetTabButton(_, keyOrIndex)
		local i = GetIndex(keyOrIndex)
		return i and tabs[i] and tabs[i].Button
	end

	function controller.Select(_, keyOrIndex)
		local i = GetIndex(keyOrIndex)
		if not i or not tabs[i] then
			return
		end

		selectedKey = tabs[i].Key

		for j = 1, #tabs do
			local isSel = (j == i)
			tabs[j].Container:SetShown(isSel)
			SetSelected(tabs[j].Button, isSel)
		end

		if tabs[i].Container.SetVerticalScroll then
			tabs[i].Container:SetVerticalScroll(0)
		end

		if options.OnTabChanged then
			options.OnTabChanged(selectedKey, i)
		end
	end

	controller.Tabs = tabs

	local prev
	for i, def in ipairs(options.Tabs) do
		assert(def.Key and def.Key ~= "", "CreateTabs: each tab needs Key")
		assert(not keyToIndex[def.Key], "CreateTabs: duplicate Key: " .. def.Key)

		local btn = CreateFrame("Button", nil, strip, "BackdropTemplate")
		btn:SetHeight(tabHeight)
		btn:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		})
		btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		btn.Text:SetPoint("CENTER", btn, "CENTER", 0, 0)
		btn.Text:SetText(def.Title or def.Key)

		btn.Highlight = btn:CreateTexture(nil, "HIGHLIGHT")
		btn.Highlight:SetAllPoints(btn)
		btn.Highlight:SetColorTexture(1, 1, 1, 1)

		if vertical then
			-- Left-edge accent bar for selected state
			btn.Indicator = btn:CreateTexture(nil, "OVERLAY")
			PixelUtil.SetWidth(btn.Indicator, 3)
			btn.Indicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
			btn.Indicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
			btn.Indicator:SetColorTexture(0.4, 0.7, 1.0, 1.0)
			btn.Indicator:Hide()

			if not prev then
				btn:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
				btn:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
			else
				btn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -tabSpacing)
				btn:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -tabSpacing)
			end
		else
			-- Bottom-edge accent bar for selected state
			btn.Accent = btn:CreateTexture(nil, "OVERLAY")
			PixelUtil.SetHeight(btn.Accent, 2)
			btn.Accent:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  0, 0)
			btn.Accent:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
			btn.Accent:SetColorTexture(0.4, 0.7, 1.0, 1.0)
			btn.Accent:Hide()

			SizeToText(btn)

			if not prev then
				btn:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 1)
			else
				btn:SetPoint("LEFT", prev, "RIGHT", tabSpacing, 0)
			end
		end

		prev = btn

		local container, content

		if options.ScrollBody then
			-- Wrapper so scrollFrame + scrollBar hide together when the tab is deselected
			local scrollContainer = CreateFrame("Frame", nil, body)
			scrollContainer:SetAllPoints(body)

			local scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer)
			scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
			scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -14, 0)
			scrollFrame:EnableMouseWheel(true)
			scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
				local step = 40
				local cur = sf:GetVerticalScroll()
				local maxScroll = sf:GetVerticalScrollRange()
				sf:SetVerticalScroll(delta > 0 and math.max(cur - step, 0) or math.min(cur + step, maxScroll))
			end)

			-- Scroll child must have an explicit size (no anchor points).
			-- SetScrollChild takes ownership of the child's position, so anchors conflict.
			local scrollChild = CreateFrame("Frame", nil, scrollFrame)
			local childWidth = options.ScrollContentWidth or 800
			scrollChild:SetSize(childWidth, options.ScrollContentHeight or 100)
			scrollFrame:SetScrollChild(scrollChild)

			-- Scrollbar, visible only when content overflows
			local scrollBar = CreateFrame("Slider", nil, scrollContainer, "BackdropTemplate")
			scrollBar:SetWidth(10)
			scrollBar:SetPoint("TOPRIGHT", scrollContainer, "TOPRIGHT", 0, -2)
			scrollBar:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", 0, 2)
			scrollBar:SetMinMaxValues(0, 1)
			scrollBar:SetValue(0)
			scrollBar:SetObeyStepOnDrag(true)
			scrollBar:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})
			scrollBar:SetBackdropColor(0.10, 0.10, 0.10, 0.6)
			scrollBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)

			local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
			thumb:SetColorTexture(0.55, 0.55, 0.55, 0.85)
			scrollBar:SetThumbTexture(thumb)

			local function UpdateScrollBar()
				local frameH = scrollFrame:GetHeight()
				local childH = scrollChild:GetHeight()
				if frameH == 0 then
					return
				end
				local maxScroll = math.max(0, childH - frameH)
				if maxScroll > 0.5 then
					scrollBar:Show()
					scrollBar:SetMinMaxValues(0, maxScroll)
					scrollBar:SetValue(math.min(scrollFrame:GetVerticalScroll(), maxScroll))
					thumb:SetHeight(math.max(20, scrollBar:GetHeight() * (frameH / childH)))
				else
					scrollBar:Hide()
				end
			end

			scrollBar:SetScript("OnValueChanged", function(_, val)
				scrollFrame:SetVerticalScroll(val)
			end)

			scrollFrame:SetScript("OnScrollRangeChanged", function()
				UpdateScrollBar()
			end)

			scrollFrame:HookScript("OnMouseWheel", function()
				scrollBar:SetValue(scrollFrame:GetVerticalScroll())
			end)

			scrollBar:Hide()

			-- Auto-size scroll child to actual content height on first show.
			-- GetTop/GetBottom require the frame to be on screen, so defer to OnShow.
			-- UpdateScrollBar must be defined before this closure.
			if not options.ScrollContentHeight then
				scrollContainer:SetScript("OnShow", function(scrollSelf)
					scrollSelf:SetScript("OnShow", nil)
					local top = scrollChild:GetTop()
					if not top then
						return
					end
					local minBottom = top
					for _, child in ipairs({ scrollChild:GetChildren() }) do
						local b = child:GetBottom()
						if b and b < minBottom then
							minBottom = b
						end
					end
					local needed = math.ceil(top - minBottom) + 20
					scrollChild:SetHeight(math.max(needed, scrollFrame:GetHeight()))
					UpdateScrollBar()
				end)
			end

			container = scrollContainer
			content = scrollChild
		else
			local contentFrame = CreateFrame("Frame", nil, body)
			contentFrame:SetAllPoints(body)
			container = contentFrame
			content = contentFrame
		end

		container:Hide()

		local tab =
			{ Key = def.Key, Title = def.Title or def.Key, Button = btn, Content = content, Container = container }
		tabs[i] = tab
		keyToIndex[def.Key] = i

		btn:SetScript("OnClick", function()
			controller:Select(i)
		end)

		if type(def.Build) == "function" then
			def.Build(content)
		end
	end

	lastBtn = tabs[#tabs] and tabs[#tabs].Button

	local initialIndex = 1
	if options.InitialKey and keyToIndex[options.InitialKey] then
		initialIndex = keyToIndex[options.InitialKey]
	end

	for i = 1, #tabs do
		local isSel = (i == initialIndex)
		tabs[i].Container:SetShown(isSel)
		SetSelected(tabs[i].Button, isSel)
	end
	selectedKey = tabs[initialIndex].Key

	if options.OnTabChanged then
		options.OnTabChanged(selectedKey, initialIndex)
	end

	if options.TabFitToParent then
		if vertical then
			local function DistributeTabs(h)
				if h == 0 or #tabs == 0 then
					return
				end
				local btnH = math.floor((h - tabSpacing * (#tabs - 1)) / #tabs)
				for _, tab in ipairs(tabs) do
					tab.Button:SetHeight(math.max(16, btnH))
				end
			end
			strip:SetScript("OnSizeChanged", function(_, _, h)
				DistributeTabs(h)
			end)
			local h = strip:GetHeight()
			if h and h > 0 then
				DistributeTabs(h)
			end
		else
			local function DistributeTabs(w)
				if w == 0 or #tabs == 0 then
					return
				end
				local available = w - tabSpacing * (#tabs - 1)
				local btnW = math.floor(available / #tabs)
				local remainder = available - btnW * #tabs
				for i, tab in ipairs(tabs) do
					tab.Button:SetWidth(i == #tabs and btnW + remainder or btnW)
				end
			end
			strip:SetScript("OnSizeChanged", function(s, w)
				DistributeTabs(w)
			end)
			local w = strip:GetWidth()
			if w and w > 0 then
				DistributeTabs(w)
			end
		end
	end

	return controller
end


function M:RegisterSlashCommand(category, panel, commands)
	if not category then
		error("RegisterSlashCommand - category must not be nil.")
	end
	if not panel then
		error("RegisterSlashCommand - panel must not be nil.")
	end

	local upper = string.upper(addonName)

	SlashCmdList[upper] = function()
		M:OpenSettings(category, panel)
	end

	if commands and #commands > 0 then
		local addonUpper = string.upper(addonName)

		for i, command in ipairs(commands) do
			_G["SLASH_" .. addonUpper .. i] = command
		end
	end
end

function M:OpenSettings(category, panel)
	if not category then
		error("OpenSettings - category must not be nil.")
	end

	if not panel then
		error("OpenSettings - panel must not be nil.")
	end

	if Settings and Settings.OpenToCategory then
		if not InCombatLockdown() or M:CanOpenOptionsDuringCombat() then
			Settings.OpenToCategory(category:GetID())
		else
			M:NotifyCombatLockdown()
		end
	elseif InterfaceOptionsFrame_OpenToCategory then
		-- workaround the classic bug where the first call opens the Game interface
		-- and a second call is required
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

function M:WaitForAddonLoad(callback)
	if not callback then
		error("WaitForAddonLoad - callback must not be nil.")
	end

	onLoadCallbacks[#onLoadCallbacks + 1] = callback

	if loaded then
		callback()
	end
end


---Creates a floating, draggable standalone config window.
---@param options table { Name, Title, Subtitle, Width, Height, OnClose }
---@return table window
function M:CreateStandaloneWindow(options)
	local width = options.Width or 860
	local height = options.Height or 680
	local frameName = options.Name or (addonName .. "ConfigFrame")

	local window = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
	window:SetSize(width, height)
	window:SetPoint("CENTER", UIParent, "CENTER")
	window:SetFrameStrata("HIGH")
	window:SetMovable(true)
	window:EnableMouse(true)
	window:SetToplevel(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function(windowSelf)
		windowSelf:StartMoving()
	end)
	window:SetScript("OnDragStop", function(windowSelf)
		windowSelf:StopMovingOrSizing()
		local point, relativeTo, relativePoint, x, y = windowSelf:GetPoint()
		windowSelf:ClearAllPoints()
		windowSelf:SetPoint(point, relativeTo, relativePoint, x, y)
	end)
	window:Hide()

	-- Border only - fill is provided by gradient textures below
	window:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	window:SetBackdropColor(0, 0, 0, 0.75)
	window:SetBackdropBorderColor(0.20, 0.20, 0.24, 1)

	-- Title bar (transparent bg; gradient above provides the fill)
	local titleBar = CreateFrame("Frame", nil, window, "BackdropTemplate")
	titleBar:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -1)
	titleBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1)
	titleBar:SetHeight(40)
	titleBar:SetBackdropColor(0, 0, 0, 0)
	titleBar:SetBackdropBorderColor(0, 0, 0, 0)

	-- Accent line beneath title bar
	local accentLine = window:CreateTexture(nil, "ARTWORK")
	accentLine:SetHeight(1)
	accentLine:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
	accentLine:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
	accentLine:SetColorTexture(1, 1, 1, 0.15)

	-- Title text (warm white)
	local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleText:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
	titleText:SetText(options.Title or "")
	titleText:SetTextColor(0.9, 0.2, 0.2, 1)

	-- Optional subtitle / version beside title
	if options.Subtitle then
		local subtitleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		subtitleText:SetPoint("LEFT", titleText, "RIGHT", 8, -1)
		subtitleText:SetText(options.Subtitle)
		subtitleText:SetTextColor(0.80, 0.80, 0.80, 1)
		window.SubtitleText = subtitleText
	end

	-- Close (×) button
	local closeBtn = CreateFrame("Button", nil, titleBar)
	closeBtn:SetSize(28, 28)
	closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)

	local closeHighlight = closeBtn:CreateTexture(nil, "HIGHLIGHT")
	closeHighlight:SetAllPoints(closeBtn)
	closeHighlight:SetColorTexture(1, 1, 1, 0.07)

	local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	closeLabel:SetAllPoints(closeBtn)
	closeLabel:SetJustifyH("CENTER")
	closeLabel:SetJustifyV("MIDDLE")
	closeLabel:SetText("×")
	closeLabel:SetTextColor(0.5, 0.5, 0.5, 1)

	closeBtn:SetScript("OnEnter", function()
		closeLabel:SetTextColor(1, 0.3, 0.3, 1)
	end)
	closeBtn:SetScript("OnLeave", function()
		closeLabel:SetTextColor(0.5, 0.5, 0.5, 1)
	end)
	closeBtn:SetScript("OnClick", function()
		window:Hide()
		if options.OnClose then
			options.OnClose()
		end
	end)

	-- Content area (inset from window edges for breathing room)
	local pad = options.ContentPadding or 12
	local content = CreateFrame("Frame", nil, window)
	content:SetPoint("TOPLEFT", accentLine, "BOTTOMLEFT", pad, -(pad + 1))
	content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -(pad + 1), pad + 1)

	-- ESC key closes this window (via OnKeyDown, not UISpecialFrames - avoids being
	-- closed when Blizzard's settings panel closes)
	window:SetPropagateKeyboardInput(true)
	window:EnableKeyboard(true)
	window:SetScript("OnKeyDown", function(windowSelf, key)
		if key == "ESCAPE" and windowSelf:IsShown() then
			windowSelf:Hide()
			if options.OnClose then
				options.OnClose()
			end
			if not InCombatLockdown() then
				windowSelf:SetPropagateKeyboardInput(false)
			end
		else
			if not InCombatLockdown() then
				windowSelf:SetPropagateKeyboardInput(true)
			end
		end
	end)

	window.TitleBar = titleBar
	window.TitleText = titleText
	window.Content = content
	window.CloseButton = closeBtn

	function window.Toggle(windowSelf)
		if windowSelf:IsShown() then
			windowSelf:Hide()
		else
			windowSelf:Show()
		end
	end

	return window
end

local function OnAddonLoaded(_, _, name)
	if name ~= addonName then
		return
	end

	loaded = true
	loader:UnregisterEvent("ADDON_LOADED")

	for _, callback in ipairs(onLoadCallbacks) do
		callback()
	end
end

loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", OnAddonLoaded)
