local addonName, SellSage = ...

local function coinButtonClick(bag, slot)
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)

    for index, itemID in ipairs(SellSageAlwaysSellListItemIDs) do
        if itemID == containerInfo.itemID then
            -- Item already exists in the list, remove it
            print("Removing item from always sell list: " .. containerInfo.hyperlink)
            table.remove(SellSageAlwaysSellListItemIDs, index)
            return
        end
    end

    -- Item not found in the list, add it
    print("Adding item to always sell list: " .. containerInfo.hyperlink)
    table.insert(SellSageAlwaysSellListItemIDs, containerInfo.itemID)
end

function SellSage.UpdateCoinButtons()
    for bag = 0, NUM_BAG_SLOTS + 1 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            repeat
                local itemButton = _G["ContainerFrame" .. (bag + 1) .. "Item" .. (C_Container.GetContainerNumSlots(bag) - slot + 1)]

                if not itemButton.coinButton then
                    -- Create the coin button
                    itemButton.coinButton = CreateFrame("Button", nil, itemButton)
                    itemButton.coinButton:SetFrameStrata("DIALOG")
                    itemButton.coinButton:SetSize(20, 20)
                    itemButton.coinButton:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", -3, -4)

                    -- Set the coin button texture
                    itemButton.coinButton:SetNormalTexture("Interface\\Icons\\inv_misc_coin_01")

                    -- Set the click handler for the coin button
                    itemButton.coinButton:SetScript("OnClick", function()
                        coinButtonClick(bag, slot)
                        SellSage.UpdateCoinButtons()
                    end)
                end

                if not IsAltKeyDown() then
                    itemButton.coinButton:Hide()
                    break
                end

                local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
                if not containerInfo then
                    itemButton.coinButton:Hide()
                    break
                end

                local sellPrice = select(11, GetItemInfo(containerInfo.hyperlink))
                if not sellPrice or sellPrice <= 0 then
                    itemButton.coinButton:Hide()
                    break
                end

                itemButton.coinButton:Show()

                if SellSage.IsItemInAlwaysSellList(containerInfo.itemID) then
                    _G.ActionButton_ShowOverlayGlow(itemButton.coinButton)
                else
                    _G.ActionButton_HideOverlayGlow(itemButton.coinButton)
                end
            until true
        end
    end
end

function SellSage.IsItemInAlwaysSellList(itemID)
    for _, currentItemID in ipairs(SellSageAlwaysSellListItemIDs) do
        if currentItemID == itemID then
            return true
        end
    end
    return false
end