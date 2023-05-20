local addonName, addonTable = ...

local coinIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"

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
                equipmentSetItemLocationMap[bag][slot] = equipmentSetIDs[i]
            end
        end
    end

    return equipmentSetItemLocationMap
end

local function sellMaster(minIlvl)
    local equipmentMap = buildEquipmentSetItemLocationMap()
    local numBags = 5 -- includes backpack
    for bag = 0, numBags - 1 do
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
                    if not itemLevel or itemLevel >= minIlvl then
                        break
                    end

                    --C_Container.UseContainerItem(bag, slot)
                    print(coinIcon, containerInfo.hyperlink, "ilvl", itemLevel)
                else
                    -- selling gray trash
                    if not itemQuality or itemQuality > 0 then
                        break
                    end
                    --C_Container.UseContainerItem(bag, slot)
                    print(coinIcon, containerInfo.hyperlink)
                end
            until true
        end
    end
end

local function updateEquipmentSetIcons()
    local equipmentMap = buildEquipmentSetItemLocationMap()
    local numBags = 5 -- includes backpack
    -- Update equipment set icons when bags are opened
    for bag = 0, numBags - 1 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            repeat
                local itemButton = _G["ContainerFrame" .. (bag + 1) .. "Item" .. (C_Container.GetContainerNumSlots(bag) - slot + 1)]
                local equipmentSetID = optionalChain(equipmentMap, bag, slot)
                if equipmentSetID ~= nil then
                    if not itemButton.iconOverlay then
                        itemButton.iconOverlay = itemButton:CreateTexture(nil, "OVERLAY")
                        itemButton.iconOverlay:SetSize(12, 12)
                        itemButton.iconOverlay:SetPoint("TOPRIGHT", 2, 2)
                        itemButton.iconOverlay:SetDrawLayer("OVERLAY", 2)
                    end
                    local _, iconFileID = C_EquipmentSet.GetEquipmentSetInfo(equipmentSetID)
                    itemButton.iconOverlay:SetTexture(iconFileID)
                else
                    if itemButton.iconOverlay then
                        itemButton.iconOverlay:SetTexture(nil)
                    end
                end
            until true
        end
    end
end

local function handleEvent(self, event, ...)
    if event == "MERCHANT_SHOW" then
        sellMaster(addonTable.minIlvl)
    elseif event == "BAG_UPDATE" then
        updateEquipmentSetIcons()
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        updateEquipmentSetIcons()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("EQUIPMENT_SETS_CHANGED")
f:SetScript("OnEvent", handleEvent)

addonTable.minIlvl = 395 -- Default. This can be changed via the addon's interface
