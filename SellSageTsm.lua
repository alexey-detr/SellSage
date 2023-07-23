local addonName, SellSage = ...

function SellSage.UpdateTsmIcons()
    if not TSM_API then
        return
    end

    for bag = 0, NUM_BAG_SLOTS + 1 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            repeat
                local itemButton = _G["ContainerFrame" .. (bag + 1) .. "Item" .. (C_Container.GetContainerNumSlots(bag) - slot + 1)]

                if not itemButton.sellSageTsmMarker then
                    -- Create the coin button
                    itemButton.sellSageTsmMarker = CreateFrame("Frame", nil, itemButton)
                    itemButton.sellSageTsmMarker:SetFrameStrata("DIALOG")
                    itemButton.sellSageTsmMarker:SetSize(16, 16)
                    itemButton.sellSageTsmMarker:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", 2, -2)

                    -- Set the coin button texture
                    local texture = itemButton.sellSageTsmMarker:CreateTexture(nil, "BACKGROUND")
                    texture:SetAllPoints()
                    texture:SetTexture("Interface\\AddOns\\TradeSkillMaster\\Media\\TSM_Icon2.blp")
                end

                if not IsAltKeyDown() then
                    itemButton.sellSageTsmMarker:Hide()
                    break
                end

                local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
                if not containerInfo then
                    itemButton.sellSageTsmMarker:Hide()
                    break
                end

                local tsmItemLink = TSM_API.ToItemString(containerInfo.hyperlink)
                if not tsmItemLink then
                    itemButton.sellSageTsmMarker:Hide()
                    break
                end

                local sellPrice = select(11, GetItemInfo(containerInfo.hyperlink))
                local tsmPrice = TSM_API.GetCustomPriceValue("DBMarket", tsmItemLink)
                local tsmSaleRate = TSM_API.GetCustomPriceValue("DBRegionSaleRate * 1000", tsmItemLink)
                if not tsmPrice or not sellPrice or not tsmSaleRate then
                    itemButton.sellSageTsmMarker:Hide()
                    break
                end

                local rate = tsmSaleRate / 1000
                if (tsmPrice - sellPrice) / sellPrice >= 1 and rate > 0.1 then
                    itemButton.sellSageTsmMarker:Hide()
                    break
                end

                itemButton.sellSageTsmMarker:Show()
            until true
        end
    end
end
