local AceAddon = LibStub("AceAddon-3.0")
local SellSage = AceAddon:GetAddon("SellSage", "AceEvent-3.0")
local SettingsUI = SellSage:NewModule("SettingsUI", "AceEvent-3.0")

local options = {
	type = "group",
	args = {
		autoSellMinItemLevel = {
			type = "range",
			name = "Auto Sell Minimum Item Level",
			desc = "The minimum item level for items to be automatically sold.",
			min = 0,
			max = 500,
			step = 5,
			width = "full",
			get = function()
				return SellSage.db.profile.AutoSellMinItemLevel
			end,
			set = function(_, value)
				SellSage.db.profile.AutoSellMinItemLevel = value
			end,
			order = 1,
		},
		ignoredItems = {
			type = "input",
			name = "Ignored items",
			desc = "Items that will not be automatically sold.",
			set = function(info, val)
				for itemLink in val:gmatch("|c%x+|Hitem:[-%d:]+|h%[.+%]|h|r") do
					local itemID = tonumber(itemLink:match("|Hitem:(%d+):"))
					if itemID then
						SellSage.db.profile.itemProperties[itemID] = SellSage.db.profile.itemProperties[itemID] or {}
						SellSage.db.profile.itemProperties[itemID].ignore = true
					end
				end
			end,
			get = function()
				local itemString = ""
				for itemID, properties in pairs(SellSage.db.profile.itemProperties) do
					if properties.ignore then
						local itemLink = select(2, GetItemInfo(itemID))
						if itemLink then
							itemString = itemString .. itemLink .. "\n"
						end
					end
				end
				return itemString
			end,
			multiline = 10,
			width = "full",
			order = 3,
		},
	},
}

function SellSage_OnAddonCompartmentClick(addonName, buttonName, menuButtonFrame)
	InterfaceOptionsFrame_OpenToCategory(SettingsUI.optionsFrame)
end

function SettingsUI:OnInitialize()
	LibStub("AceConfig-3.0"):RegisterOptionsTable("SellSage", options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SellSage", "SellSage")

	SLASH_SELLSAGE1 = "/sellsage"
	SlashCmdList["SELLSAGE"] = function()
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
	end
end

function SettingsUI:SetupOptions() end

function SettingsUI:OnEnable() end

function SettingsUI:OnDisable() end
