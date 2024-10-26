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

	-- Coin buttons
	self:RegisterEvent("MODIFIER_STATE_CHANGED", "updateCoinButtons")

	-- Equipment set icons
	self:RegisterEvent("BAG_UPDATE_DELAYED", "updateEquipmentSetIcons")
	self:RegisterEvent("USE_COMBINED_BAGS_CHANGED", "updateEquipmentSetIcons")
	self:RegisterEvent("EQUIPMENT_SETS_CHANGED", "updateEquipmentSetIcons")
	local frame = CreateFrame("Frame")

	-- To detect the bag window state
	local function IsBagOpen()
		for i = 1, NUM_CONTAINER_FRAMES do
			local bagFrame = _G["ContainerFrame" .. i]
			if bagFrame and bagFrame:IsShown() then
				return true -- Bag is open
			end
		end
		return false -- Bag is closed
	end

	local wasBagOpen = false

	-- Set up an OnUpdate handler to continuously check for changes in bag state
	frame:SetScript("OnUpdate", function(self, elapsed)
		local isBagOpen = IsBagOpen()

		if isBagOpen and not wasBagOpen then
			SellSage:updateEquipmentSetIcons()
		elseif not isBagOpen and wasBagOpen then
			-- print("Bag closed.")
		end

		wasBagOpen = isBagOpen
	end)
end

function SellSage:updateCoinButtons()
	for bag = 0, NUM_BAG_SLOTS + 1 do
		for _, itemButton in _G["ContainerFrame" .. (bag + 1)]:EnumerateValidItems() do
			if itemButton then
				local item = Item:CreateFromBagAndSlot(itemButton:GetBagID(), itemButton:GetID())
				SellSage:updateCoinButton(itemButton, item)
			end
		end
		for _, itemButton in _G.ContainerFrameCombinedBags:EnumerateValidItems() do
			if itemButton then
				local item = Item:CreateFromBagAndSlot(itemButton:GetBagID(), itemButton:GetID())
				SellSage:updateCoinButton(itemButton, item)
			end
		end
	end
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

function SellSage:coinButtonClick(item)
	local itemID = item:GetItemID()

	if not self.db.profile.itemProperties[itemID] then
		self.db.profile.itemProperties[itemID] = {}
	end

	-- Toggle the autoSell flag for the item
	if self.db.profile.itemProperties[itemID].autoSell then
		-- If the item is currently set to autoSell, remove it
		print("Add item to ignore list: " .. item:GetItemLink())
		self.db.profile.itemProperties[itemID].autoSell = nil
		self.db.profile.itemProperties[itemID].ignore = true
	elseif self.db.profile.itemProperties[itemID].ignore then
		print("Removing item from ignore list: " .. item:GetItemLink())
		self.db.profile.itemProperties[itemID].ignore = nil
		self.db.profile.itemProperties[itemID].autoSell = nil
	else
		print("Add item to auto sell list: " .. item:GetItemLink())
		self.db.profile.itemProperties[itemID].autoSell = true
	end

	SellSage:updateCoinButtons()
end

function SellSage:updateCoinButton(itemButton, item)
	local greenTickTexturePath = "interface\\raidframe\\readycheck-ready"
	local redCrossTexturePath = "interface\\raidframe\\readycheck-notready"

	repeat
		if not itemButton.sellSageCoinButton then
			-- Create the coin button
			itemButton.sellSageCoinButton = CreateFrame("Button", nil, itemButton)
			itemButton.sellSageCoinButton:SetFrameStrata("DIALOG")
			itemButton.sellSageCoinButton:SetSize(24, 24)
			itemButton.sellSageCoinButton:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", -3, -4)

			-- Set the coin button texture
			itemButton.sellSageCoinButton:SetNormalTexture("Interface\\Icons\\inv_misc_coin_01")

			-- Create the green tick texture
			itemButton.sellSageCoinButton.greenTickOverlay = itemButton.sellSageCoinButton:CreateTexture(nil, "OVERLAY")
			itemButton.sellSageCoinButton.greenTickOverlay:SetTexture(greenTickTexturePath)
			itemButton.sellSageCoinButton.greenTickOverlay:SetSize(20, 20) -- Adjust size as needed
			itemButton.sellSageCoinButton.greenTickOverlay:SetPoint(
				"CENTER",
				itemButton.sellSageCoinButton,
				"CENTER",
				0,
				0
			)
			itemButton.sellSageCoinButton.greenTickOverlay:Hide() -- Initially hidden

			-- Create the red cross texture
			itemButton.sellSageCoinButton.redCrossOverlay = itemButton.sellSageCoinButton:CreateTexture(nil, "OVERLAY")
			itemButton.sellSageCoinButton.redCrossOverlay:SetTexture(redCrossTexturePath)
			itemButton.sellSageCoinButton.redCrossOverlay:SetSize(20, 20) -- Adjust size as needed
			itemButton.sellSageCoinButton.redCrossOverlay:SetPoint(
				"CENTER",
				itemButton.sellSageCoinButton,
				"CENTER",
				0,
				0
			)
			itemButton.sellSageCoinButton.redCrossOverlay:Hide() -- Initially hidden

			itemButton.sellSageCoinButton:SetScript("OnMouseDown", function(self)
				self:SetSize(20, 20) -- Slightly smaller to give a pressed effect
				self:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", -1, -2) -- Adjust position if needed
			end)
			itemButton.sellSageCoinButton:SetScript("OnMouseUp", function(self)
				self:SetSize(24, 24) -- Revert to original size
				self:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", -3, -4) -- Revert to original position
			end)
		end

		-- Set the click handler for the coin button
		itemButton.sellSageCoinButton:SetScript("OnClick", function()
			SellSage:coinButtonClick(item)
		end)

		if not IsAltKeyDown() then
			itemButton.sellSageCoinButton:Hide()
			break
		end

		if not item or not item:GetItemID() then
			itemButton.sellSageCoinButton:Hide()
			break
		end

		local sellPrice = select(11, GetItemInfo(item:GetItemID()))
		if not sellPrice or sellPrice <= 0 then
			itemButton.sellSageCoinButton:Hide()
			break
		end

		itemButton.sellSageCoinButton:Show()

		if SellSage:isItemInAutoSellList(item:GetItemID()) then
			itemButton.sellSageCoinButton:GetNormalTexture():SetVertexColor(1, 1, 1)
			itemButton.sellSageCoinButton.greenTickOverlay:Show()
			itemButton.sellSageCoinButton.redCrossOverlay:Hide()
		elseif SellSage:isItemInIgnoreList(item:GetItemID()) then
			itemButton.sellSageCoinButton:GetNormalTexture():SetVertexColor(1, 1, 1)
			itemButton.sellSageCoinButton.greenTickOverlay:Hide()
			itemButton.sellSageCoinButton.redCrossOverlay:Show()
		else
			itemButton.sellSageCoinButton:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
			itemButton.sellSageCoinButton.greenTickOverlay:Hide()
			itemButton.sellSageCoinButton.redCrossOverlay:Hide()
		end
	until true
end

function SellSage:isItemInAutoSellList(itemID)
	return self.db.profile.itemProperties[itemID] and self.db.profile.itemProperties[itemID].autoSell
end

function SellSage:isItemInIgnoreList(itemID)
	return self.db.profile.itemProperties[itemID] and self.db.profile.itemProperties[itemID].ignore
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

function SellSage:updateEquipmentSetIcons()
	local equipmentMap = SellSage:buildEquipmentSetItemLocationMap()
	for bag = 0, NUM_BAG_SLOTS + 1 do
		for _, itemButton in _G["ContainerFrame" .. (bag + 1)]:EnumerateValidItems() do
			if itemButton then
				local itemLocation = ItemLocation:CreateFromBagAndSlot(itemButton:GetBagID(), itemButton:GetID())
				SellSage:updateEquipmentSetIcon(itemButton, itemLocation, equipmentMap)
			end
		end
		for _, itemButton in _G.ContainerFrameCombinedBags:EnumerateValidItems() do
			if itemButton then
				local itemLocation = ItemLocation:CreateFromBagAndSlot(itemButton:GetBagID(), itemButton:GetID())
				SellSage:updateEquipmentSetIcon(itemButton, itemLocation, equipmentMap)
			end
		end
	end
end

function SellSage:updateEquipmentSetIcon(itemButton, itemLocation, equipmentMap)
	local bag, slot = itemLocation:GetBagAndSlot()
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
end
