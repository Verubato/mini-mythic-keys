local ADDON, Addon = ...

-- print("Plugin:AngryKeystones loaded")

local AngryKeystoneStorage = {}


local function OnEvent(self, event, addOnName, message, channel, character)
    if (addOnName == "AngryKeystones") then
        -- print("AngryKeystones received")
        if (string.find(message, "Schedule|")) then
            -- print(message)
            local _, key = strsplit("|", message)
            local keyname, keylevel = strsplit(":", key)
            local charName = strsplit("-", character)
            if keyname and keylevel then
                AngryKeystoneStorage[charName] = AngryKeystoneStorage[charName] or {}
                AngryKeystoneStorage[charName]["current_key"] = keyname
                AngryKeystoneStorage[charName]["current_keylevel"] = keylevel
            end
        end
    end

    for charName in pairs(AngryKeystoneStorage) do
        Addon.PartyKeys[charName] = Addon.PartyKeys[charName] or {}
        Addon.PartyKeys[charName]["current_key"] = AngryKeystoneStorage[charName]["current_key"]
        Addon.PartyKeys[charName]["current_keylevel"] = AngryKeystoneStorage[charName]["current_keylevel"]
    end
end

C_ChatInfo.RegisterAddonMessagePrefix("AngryKeystones")

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", OnEvent)
