local keyId = 180653
local commands = {
	"!key",
	"!keys",
}

local function FindKey()
	for bag = 0, BACKPACK_CONTAINER + NUM_BAG_SLOTS + 1 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local item = C_Container.GetContainerItemID(bag, slot)

			if item == keyId then
				local data = { Bag = bag, Slot = slot }
				return data
			end
		end
	end

	return nil
end

function TrimWhitespace(s)
	return s:match("^%s*(.-)%s*$")
end

local function OnEvent(_, event, message)
	if not message or InCombatLockdown() then
		return
	end

	local messageLower = TrimWhitespace(string.lower(message))
	local commandMatch = false

	for _, command in ipairs(commands) do
		if messageLower == command then
			commandMatch = true
			break
		end
	end

	if not commandMatch then
		return
	end

	local key = FindKey()
	local link = key and C_Container.GetContainerItemLink(key.Bag, key.Slot) or "I don't have a key."
	local channel

	if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
		channel = "PARTY"
	elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
		channel = "RAID"
	elseif event == "CHAT_MSG_GUILD" then
		channel = "GUILD"
	end

	if not channel then
		return
	end

	SendChatMessage(link, channel)
end

local frame = CreateFrame("Frame")
frame:HookScript("OnEvent", OnEvent)

local chatEvents = {
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_GUILD",
}

for _, event in ipairs(chatEvents) do
	frame:RegisterEvent(event)
end
