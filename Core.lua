local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")
local SellSage = AceAddon:NewAddon("SellSage", "AceEvent-3.0")

-- Default settings for AceDB
local defaults = {
	profile = {
		autoSellMinItemLevel = 360,
		itemProperties = {},
	},
}

local function optionalChain(...)
	local value = select(1, ...)
	for i = 2, select("#", ...) do
		local key = select(i, ...)
		if value and value[key] then
			value = value[key]
		else
			return nil
		end
	end
	return value
end

function SellSage:OnInitialize()
	self.db = AceDB:New("SellSageDB", defaults, true)
	self.coinIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
	self.sellItemsCoroutine = nil
	self.ticker = nil
end

function SellSage:OnEnable()
	self:RegisterEvent("MERCHANT_SHOW", "sellMaster")
	self:RegisterEvent("MERCHANT_CLOSED", "stopSelling")
	self:RegisterEvent("BAG_UPDATE", "updateEquipmentSetIcons")
	self:RegisterEvent("EQUIPMENT_SETS_CHANGED", "updateEquipmentSetIcons")
	self:RegisterEvent("MODIFIER_STATE_CHANGED", "updateCoinButtons")
end

function SellSage:stopSelling()
	if self.sellItemsCoroutine then
		self.sellItemsCoroutine = nil
	end
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

function SellSage:updateSellMaster()
	if self.sellItemsCoroutine ~= nil then
		coroutine.resume(self.sellItemsCoroutine)
	end
end

local coinIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"

function SellSage:isTransmoggable(itemID)
	-- Check if the player can collect the appearance source of the item
	local _, canCollectSource = C_TransmogCollection.PlayerCanCollectSource(itemID)
	return canCollectSource
end

function SellSage:buildEquipmentSetItemLocationMap()
	local equipmentSetItemLocationMap = {}
	local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs()

	for i = 1, #equipmentSetIDs do
		local itemLocations = C_EquipmentSet.GetItemLocations(equipmentSetIDs[i])
		for _, itemLocation in pairs(itemLocations) do
			local player, _, bags, _, slot, bag = EquipmentManager_UnpackLocation(itemLocation)
			if player and bags then
				equipmentSetItemLocationMap[bag] = equipmentSetItemLocationMap[bag] or {}
				equipmentSetItemLocationMap[bag][slot] = equipmentSetItemLocationMap[bag][slot] or {}
				table.insert(equipmentSetItemLocationMap[bag][slot], equipmentSetIDs[i])
			end
		end
	end

	return equipmentSetItemLocationMap
end

function SellSage:sellMaster()
	local equipmentMap = self:buildEquipmentSetItemLocationMap()
	self.sellItemsCoroutine = coroutine.create(function()
		for bag = 0, NUM_BAG_SLOTS + 1 do
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				repeat
					local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
					if not containerInfo then
						break
					end

					local itemID = containerInfo.itemID
					if not itemID then
						break
					end

					local itemName, _, itemQuality, itemLevel, _, _, _, _, _, _, sellPrice, classID =
						GetItemInfo(containerInfo.hyperlink)

					if not itemName then
						break
					end

					if sellPrice == 0 then
						break
					end

					-- 2 is for weapons and 4 is for armor
					if classID == 2 or classID == 4 then
						-- Do not sell if item is part of any set
						if optionalChain(equipmentMap, bag, slot) ~= nil then
							break
						end
						-- Do not sell if item is in transmog collection
						if self:isTransmoggable(itemID) and not C_TransmogCollection.PlayerHasTransmog(itemID) then
							break
						end
						-- Do not sell items that are ilvl 1 (cosmetic items) and that are not soulbound
						if not containerInfo.itemLocked and itemLevel == 1 then
							break
						end
						if not itemLevel or itemLevel >= self.db.profile.autoSellMinItemLevel then
							break
						end
						-- Do not sell items with quality higher than epic
						-- https://wowpedia.fandom.com/wiki/Enum.ItemQuality
						if itemQuality and itemQuality >= 5 then
							break
						end

						C_Container.UseContainerItem(bag, slot)
						print(coinIcon, containerInfo.hyperlink, "ilvl", itemLevel)
						coroutine.yield() -- Only yield after using the item
						break
					end

					-- selling gray trash
					if itemQuality and itemQuality == 0 then
						C_Container.UseContainerItem(bag, slot)
						print(coinIcon, containerInfo.hyperlink)
						coroutine.yield() -- Only yield after using the item
						break
					end

					-- selling items in always sell list
					if self:isItemInAutoSellList(itemID) then
						C_Container.UseContainerItem(bag, slot)
						print(coinIcon, containerInfo.hyperlink, "auto sell list")
						coroutine.yield() -- Only yield after using the item
						break
					end
				until true
				-- No yield here, continue processing items
			end
		end

		self.sellItemsCoroutine = nil
		if self.ticker then
			self.ticker:Cancel()
			self.ticker = nil
		end
	end)

	if not self.ticker then
		self.ticker = C_Timer.NewTicker(0.2, function()
			self:updateSellMaster()
		end)
	end
end

function SellSage:updateEquipmentSetIcons()
	local equipmentMap = SellSage:buildEquipmentSetItemLocationMap()
	-- Update equipment set icons when bags are opened
	for bag = 0, NUM_BAG_SLOTS + 1 do
		local containerNumSlots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, containerNumSlots do
			repeat
				local itemButton = _G["ContainerFrame" .. (bag + 1) .. "Item" .. (containerNumSlots - slot + 1)]
				if not itemButton then
					break
				end
				local equipmentSetIDs = optionalChain(equipmentMap, bag, slot)

				for i = 1, 3 do
					local equipmentSetID = optionalChain(equipmentSetIDs, i)
					if equipmentSetID then
						if not itemButton["iconOverlay" .. i] then
							itemButton["iconOverlay" .. i] = itemButton:CreateTexture(nil, "OVERLAY")
							itemButton["iconOverlay" .. i]:SetSize(12, 12)
							itemButton["iconOverlay" .. i]:SetPoint("TOPRIGHT", 2, 2 - 12 * (i - 1))
							itemButton["iconOverlay" .. i]:SetDrawLayer("OVERLAY", 2)
						end
						local _, iconFileID = C_EquipmentSet.GetEquipmentSetInfo(equipmentSetID)
						itemButton["iconOverlay" .. i]:SetTexture(iconFileID)
					else
						if itemButton["iconOverlay" .. i] then
							itemButton["iconOverlay" .. i]:SetTexture(nil)
						end
					end
				end
			until true
		end
	end
end
