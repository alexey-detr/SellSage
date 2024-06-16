local AceAddon = LibStub("AceAddon-3.0")
local SellSage = AceAddon:GetAddon("SellSage", "AceEvent-3.0")

function SellSage:coinButtonClick(bag, slot)
	local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
	local itemID = containerInfo.itemID

	if not self.db.profile.itemProperties[itemID] then
		self.db.profile.itemProperties[itemID] = {}
	end

	-- Toggle the autoSell flag for the item
	if self.db.profile.itemProperties[itemID].autoSell then
		-- If the item is currently set to autoSell, remove it
		print("Add item to ignore list: " .. containerInfo.hyperlink)
		self.db.profile.itemProperties[itemID].autoSell = nil
		self.db.profile.itemProperties[itemID].ignore = true
	elseif self.db.profile.itemProperties[itemID].ignore then
		print("Removing item from ignore list: " .. containerInfo.hyperlink)
		self.db.profile.itemProperties[itemID].ignore = nil
		self.db.profile.itemProperties[itemID].autoSell = nil
	else
		print("Add item to auto sell list: " .. containerInfo.hyperlink)
		self.db.profile.itemProperties[itemID].autoSell = true
	end
end

function SellSage:updateCoinButtons()
	local greenTickTexturePath = "interface\\raidframe\\readycheck-ready"
	local redCrossTexturePath = "interface\\raidframe\\readycheck-notready"

	for bag = 0, NUM_BAG_SLOTS + 1 do
		local containerNumSlots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, containerNumSlots do
			repeat
				local itemButton = _G["ContainerFrame" .. (bag + 1) .. "Item" .. (containerNumSlots - slot + 1)]
				if not itemButton then
					break
				end

				if not itemButton.sellSageCoinButton then
					-- Create the coin button
					itemButton.sellSageCoinButton = CreateFrame("Button", nil, itemButton)
					itemButton.sellSageCoinButton:SetFrameStrata("DIALOG")
					itemButton.sellSageCoinButton:SetSize(24, 24)
					itemButton.sellSageCoinButton:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", -3, -4)

					-- Set the coin button texture
					itemButton.sellSageCoinButton:SetNormalTexture("Interface\\Icons\\inv_misc_coin_01")

					-- Create the green tick texture
					itemButton.sellSageCoinButton.greenTickOverlay =
						itemButton.sellSageCoinButton:CreateTexture(nil, "OVERLAY")
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
					itemButton.sellSageCoinButton.redCrossOverlay =
						itemButton.sellSageCoinButton:CreateTexture(nil, "OVERLAY")
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

					-- Set the click handler for the coin button
					itemButton.sellSageCoinButton:SetScript("OnClick", function()
						SellSage:coinButtonClick(bag, slot)
						SellSage:updateCoinButtons()
					end)
				end

				if not IsAltKeyDown() then
					itemButton.sellSageCoinButton:Hide()
					break
				end

				local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
				if not containerInfo then
					itemButton.sellSageCoinButton:Hide()
					break
				end

				local sellPrice = select(11, GetItemInfo(containerInfo.hyperlink))
				if not sellPrice or sellPrice <= 0 then
					itemButton.sellSageCoinButton:Hide()
					break
				end

				itemButton.sellSageCoinButton:Show()

				if SellSage:isItemInAutoSellList(containerInfo.itemID) then
					itemButton.sellSageCoinButton:GetNormalTexture():SetVertexColor(1, 1, 1)
					itemButton.sellSageCoinButton.greenTickOverlay:Show()
					itemButton.sellSageCoinButton.redCrossOverlay:Hide()
				elseif SellSage:isItemInIgnoreList(containerInfo.itemID) then
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
	end
end

function SellSage:isItemInAutoSellList(itemID)
	return self.db.profile.itemProperties[itemID] and self.db.profile.itemProperties[itemID].autoSell
end

function SellSage:isItemInIgnoreList(itemID)
	return self.db.profile.itemProperties[itemID] and self.db.profile.itemProperties[itemID].ignore
end
