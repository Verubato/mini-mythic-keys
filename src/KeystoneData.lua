local _, addon = ...
local weekEpoch = { 1500390000, 1500447600, 1500505200 } -- US/EU/TW reset anchors
local lksPartyKeys = {}

local function GetDB()
	MiniMythicKeysDB = MiniMythicKeysDB or {}
	MiniMythicKeysDB.GuildKeys = MiniMythicKeysDB.GuildKeys or {}
	return MiniMythicKeysDB
end

local function GetWeek()
	local region = GetCurrentRegion()
	local epoch = weekEpoch[region] or weekEpoch[1]
	return math.floor((GetServerTime() - epoch) / 604800)
end

local function ShortName(name)
	return name and (name:match("^([^%-]+)") or name) or name
end

local function OnKeystoneReceived(keyLevel, keyChallengeMapID, playerRating, playerName, channel)
	if keyLevel < 0 then return end -- guild-hidden

	if channel == "PARTY" then
		lksPartyKeys[ShortName(playerName)] = {
			name = playerName,
			current_key = keyChallengeMapID,
			current_keylevel = keyLevel,
		}
	elseif channel == "GUILD" then
		local db = GetDB()
		db.GuildKeys[ShortName(playerName)] = {
			name = playerName,
			current_key = keyChallengeMapID,
			current_keylevel = keyLevel,
			week = GetWeek(),
		}
	end
end

function addon.GetMergedPartyKeys()
	local lmk = LibStub("LibMythicKeystone-1.0")
	local result = {}

	for name, entry in pairs(lmk.getPartyKeystone()) do
		result[ShortName(name)] = entry
	end

	for name, entry in pairs(lksPartyKeys) do
		local existing = result[ShortName(name)]
		local key = ShortName(name)
		if not existing then
			result[key] = entry
		elseif (entry.current_keylevel or 0) > (existing.current_keylevel or 0) then
			result[key] = {
				name = existing.name,
				class = existing.class,
				realm = existing.realm,
				current_key = entry.current_key,
				current_keylevel = entry.current_keylevel,
			}
		end
	end

	local playerName = UnitName("player")
	if playerName and result[playerName] then
		local rewards = C_WeeklyRewards.GetActivities(1)
		if rewards and rewards[1] then
			result[playerName].weeklybest = rewards[1].level or 0
			result[playerName].weeklycount = rewards[1].progress or 0
		end
	end

	return result
end

function addon.GetMergedGuildKeys()
	local lmk = LibStub("LibMythicKeystone-1.0")
	local db = GetDB()
	local result = {}

	for name, entry in pairs(lmk.getGuildKeystone()) do
		result[ShortName(name)] = entry
	end

	for name, entry in pairs(db.GuildKeys) do
		local key = ShortName(name)
		local existing = result[key]
		if not existing then
			result[key] = entry
		elseif (entry.current_keylevel or 0) > (existing.current_keylevel or 0) then
			result[key] = {
				name = existing.name or name,
				class = existing.class,
				current_key = entry.current_key,
				current_keylevel = entry.current_keylevel,
				week = entry.week,
			}
		end
	end

	return result
end

function addon.RequestKeystones()
	if addon.getKeystone then addon.getKeystone() end
	if addon.sendKeystone then addon.sendKeystone() end
	if addon.requestPartyKeystone then addon.requestPartyKeystone() end
	if addon.requestGuildKeystone then addon.requestGuildKeystone() end

	local lks = LibStub("LibKeystone", true)
	if lks then
		lks.Request("PARTY")
		lks.Request("GUILD")
	end
end

local function Init()
	local db = GetDB()
	local week = GetWeek()

	for name in pairs(db.GuildKeys) do
		if db.GuildKeys[name].week ~= week then
			db.GuildKeys[name] = nil
		end
	end

	local lks = LibStub("LibKeystone", true)
	if lks then
		lks.Register(addon, OnKeystoneReceived)
		C_Timer.After(10, function()
			lks.Request("PARTY")
			lks.Request("GUILD")
		end)
	end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	Init()
end)
