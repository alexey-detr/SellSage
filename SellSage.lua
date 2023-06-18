local addonName, SellSage = ...

function SellSage.InitSavedVariables()
    if SellSageMinItemLevelMinItemLevel == nil then
        SellSageMinItemLevelMinItemLevel = 360
    end
    if SellSageAlwaysSellListItemIDs == nil then
        SellSageAlwaysSellListItemIDs = {}
    end
end

local coinIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"

local function sellItemDelayed(bag, slot)
    C_Timer.After(0.1, function()
        C_Container.UseContainerItem(bag, slot)
    end)
end

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

local function isTransmoggable(itemID)
    -- Check if the player can collect the appearance source of the item
    local _, canCollectSource = C_TransmogCollection.PlayerCanCollectSource(itemID)
    return canCollectSource
end

local function buildEquipmentSetItemLocationMap()
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

local function sellMaster()
    local equipmentMap = buildEquipmentSetItemLocationMap()
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

                local _, _, itemQuality, itemLevel, _, _, _, _, _, _, _, classID = GetItemInfo(containerInfo.hyperlink)

                -- 2 is for weapons and 4 is for armor
                if classID == 2 or classID == 4 then
                    -- Do not sell if item is part of any set
                    if optionalChain(equipmentMap, bag, slot) ~= nil then
                        break
                    end
                    -- Do not sell if item is in transmog collection
                    if isTransmoggable(itemID) and not C_TransmogCollection.PlayerHasTransmog(itemID) then
                        break
                    end
                    if not itemLevel or itemLevel >= SellSageMinItemLevelMinItemLevel then
                        break
                    end

                    sellItemDelayed(bag, slot)
                    print(coinIcon, containerInfo.hyperlink, "ilvl", itemLevel)
                    break
                end

                -- selling gray trash
                if itemQuality and itemQuality == 0 then
                    sellItemDelayed(bag, slot)
                    print(coinIcon, containerInfo.hyperlink)
                    break
                end

                -- selling items in always sell list
                if SellSage.IsItemInAlwaysSellList(itemID) then
                    sellItemDelayed(bag, slot)
                    print(coinIcon, containerInfo.hyperlink, "always sell list")
                    break
                end
            until true
        end
    end
end

local function updateEquipmentSetIcons()
    local equipmentMap = buildEquipmentSetItemLocationMap()
    -- Update equipment set icons when bags are opened
    for bag = 0, NUM_BAG_SLOTS + 1 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            repeat
                local itemButton = _G["ContainerFrame" .. (bag + 1) .. "Item" .. (C_Container.GetContainerNumSlots(bag) - slot + 1)]
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

function SellSage_HandleEvent(self, event, ...)
    local arg1 = ...;

    if event == "ADDON_LOADED" and arg1 == addonName then
        SellSage.InitSavedVariables();
        SettingsRegistrar:AddRegistrant(SellSage.RegisterSettingsUI)
    elseif event == "MERCHANT_SHOW" then
        sellMaster()
    elseif event == "BAG_UPDATE" then
        updateEquipmentSetIcons()
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        updateEquipmentSetIcons()
    elseif event == "MODIFIER_STATE_CHANGED" then
        SellSage.UpdateCoinButtons()
        SellSage.UpdateTsmIcons()
    end
end

local f = CreateFrame("Frame")

f:RegisterEvent("ADDON_LOADED");
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("EQUIPMENT_SETS_CHANGED")
f:RegisterEvent("MODIFIER_STATE_CHANGED")

f:SetScript("OnEvent", SellSage_HandleEvent)
