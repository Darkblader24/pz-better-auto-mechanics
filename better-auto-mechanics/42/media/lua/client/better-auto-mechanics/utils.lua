-- Ensure we have access to the UI global for the floor container
require "ISUI/ISInventoryPage"

BAM = BAM or {}


function BAM.GetNextUninstallablePart(player, vehicle)
    --print("-> Searching for next uninstallable part...")
    -- Collect all installed car parts into a list for sorting
    local validParts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)

        -- Gather only parts that are currently installed
        if part:getInventoryItem() ~= nil then
            table.insert(validParts, part)
        end
    end

    local sortedParts = BAM.SortParts(validParts)

    -- Check each part for uninstall possibility and XP eligibility
    for _, part in pairs(sortedParts) do
        -- 1. Check if the physical action is possible (tools, location, etc.)
        local canUninstallPart = part:getVehicle():canUninstallPart(player, part)
        local canAccessPart = not BAM.InaccessibleParts[part:getId()]

        -- 2. Check if the player is eligible for XP (Cooldown check)
        -- Key format: PartID + VehicleID + "1" (1 is for Uninstall)
        local canGainUninstallXP = BAM.CanGainXP(player, vehicle, part, 1)

        -- 3. Get part success chance
        local successChance = BAM.GetPartSuccessChance(player, part, "uninstall")

        -- Check for smashed cars, their front windows are inaccessible
        if part:getId():find("WindowFront") or part:getId():find("Seat") then
            local scriptName = vehicle:getScript():getName()
            --print("-> Vehicle script name: " .. scriptName)
            if string.find(scriptName, "Burnt") or string.find(scriptName, "Smashed") then
                --print("-> Vehicle is burnt or smashed, cannot uninstall " .. part:getId())
                canAccessPart = false
            end
        end

        --print(part:getId() .. " - UNINSTALL ACCESS: " .. tostring(canAccessPart))
        --print(part:getId() .. " - UNINSTALL: " .. tostring(canUninstallPart) .. " - UNINSTALL XP: " .. tostring(canGainUninstallXP) .. " - ACCESS: " .. tostring(canAccessPart))

        -- 3. If all checks pass, return the part
        if canUninstallPart and canAccessPart and canGainUninstallXP and successChance >= BAM_Options_MinSuccessChance:getValue() then
            --print("Part " .. part:getId() .. " Success Chance: " .. tostring(successChance) .. "%, Failure Chance: " .. tostring(failureChance) .. "%")
            return part
        end
    end
    return nil
end


function BAM.GetNextInstallablePartAndItem(player, vehicle)
    --print("-> Searching for next installable part...")
    -- Collect all uninstalled car parts into a list for sorting
    local validParts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)

        -- Gather only parts that are currently not installed
        if part:getInventoryItem() == nil then
            table.insert(validParts, part)
        end
    end

    local sortedParts = BAM.SortParts(validParts)

    for _, part in pairs(sortedParts) do
        -- 1. Check if the physical action is possible (tools, location, etc.)
        local canInstallPart = part:getVehicle():canInstallPart(player, part)
        local canAccessPart = not BAM.InaccessibleParts[part:getId()]

        -- 2. Get part success chance
        local successChance = BAM.GetPartSuccessChance(player, part, "install")

        -- 3. Check if the player has the required part in inventory or on ground
        local item = BAM.GetAnyItemOnPlayerThatMatchesThatPart(player, part);

        --print(part:getId() .. " - INSTALL: " .. tostring(canInstallPart))

        if canInstallPart and canAccessPart and item and successChance >= BAM_Options_MinSuccessChance:getValue() then
            return part, item
        end
    end
    return nil, nil
end


function BAM.SortParts(parts)
    -- 1. Define the train order
    -- Grouped by location on vehicle, and then by required tool to minimize tool switching
    local orderList = {
        -- Front
        "Radio",
        "Battery",
        "HeadlightLeft",
        "HeadlightRight",
        "Windshield",
        "EngineDoor",  -- Hood

        -- Front Left
        "SuspensionFrontLeft",
        "BrakeFrontLeft",
        "TireFrontLeft",

        -- Doors Left
        "SeatFrontLeft",
        "DoorFrontLeft",
        "WindowFrontLeft",
        "SeatMiddleLeft",
        "DoorMiddleLeft",
        "WindowMiddleLeft",
        "SeatRearLeft",
        "DoorRearLeft",
        "WindowRearLeft",

        -- Rear Left
        "SuspensionRearLeft",
        "BrakeRearLeft",
        "TireRearLeft",

        -- Rear
        "GasTank",
        "WindshieldRear",
        "HeadlightRearLeft",
        "HeadlightRearRight",
        "Muffler",
        "TrunkDoor", -- Trunk Lid
        "DoorRear",

        -- Rear Right
        "SuspensionRearRight",
        "BrakeRearRight",
        "TireRearRight",

        -- Doors Right
        "SeatRearRight",
        "DoorRearRight",
        "WindowRearRight",
        "SeatMiddleRight",
        "DoorMiddleRight",
        "WindowMiddleRight",
        "SeatFrontRight",
        "DoorFrontRight",
        "WindowFrontRight",

        -- Front Right
        "SuspensionFrontRight",
        "BrakeFrontRight",
        "TireFrontRight",

        -- Impossible ones:
        "GloveBox",
        "Heater",
        "Engine",
        "TruckBed",  -- Trunk
        "TruckBedOpen",  -- Trunk that's always open
        "PassengerCompartment", -- ???
        "TrailerAnimalFood",
        "TrailerAnimalEggs",
    }

    -- 2. Create a "Rank Map" for fast lookup
    -- This turns the list into: { ["Radio"] = 1, ["Battery"] = 2, ... }
    local rankLookup = {}
    for index, id in ipairs(orderList) do
        rankLookup[id] = index
    end

    -- 3. Sort the actual 'parts' table using the Rank Map
    table.sort(parts, function(a, b)
        local idA = a:getId()
        local idB = b:getId()

        -- Get the rank from our table.
        -- If an ID isn't in your list, we give it rank 999 (puts it at the very bottom)
        local rankA = rankLookup[idA] or 999
        local rankB = rankLookup[idB] or 999

        return rankA < rankB
    end)

    --print("Sorted parts order:")
    --for i, part in ipairs(parts) do
    --    print(i .. " - " .. part:getId())
    --end

    return parts
end


function BAM.GetAnyItemOnPlayerThatMatchesThatPart(player, part)
    if not part:getItemType() then
        return nil
    end
    local typeToItem = VehicleUtils.getItems(player:getPlayerNum())
    -- among all possible items that can be installed on that part
    for i = 0, part:getItemType():size() - 1 do
        local name = part:getItemType():get(i);
        local item = instanceItem(name);
        if item then name = item:getName(); end
        --if any type is owned by the player
        if typeToItem[part:getItemType():get(i)] then
            for j, v in ipairs(typeToItem[part:getItemType():get(i)]) do
                return v; --return first valid item met
            end
        end
    end
    return nil
end


function BAM.DropBrokenItems(player)
    local inventory = player:getInventory()
    local items = inventory:getItems()
    local itemsToDrop = {}

    -- 1. Identify items to drop
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:isBroken() and not item:isFavorite() and not item:isEquipped() then
            table.insert(itemsToDrop, item)
        end
    end

    if #itemsToDrop == 0 then
        return
    end

    -- 2. Get the "Floor" Container
    -- In Zomboid, the floor is a virtual container managed by ISInventoryPage
    local playerNum = player:getPlayerNum()
    local floorContainer = ISInventoryPage.floorContainer[playerNum + 1]

    if not floorContainer then
        --print("Error: Could not find floor container!")
        return
    end

    --print("BAM: Dropping " .. #itemsToDrop .. " items to floor...")

    -- 3. Queue the Transfer Actions
    for _, item in ipairs(itemsToDrop) do
        -- ISInventoryTransferAction:new(character, item, srcContainer, destContainer, time)
        local action = ISInventoryTransferAction:new(
            player,
            item,
            item:getContainer(),
            floorContainer,
            10 -- Time in ticks (10 is very fast)
        )
        ISTimedActionQueue.add(action)
    end
end


function BAM.GetPartSuccessChance(player, part, actionType)
    local successChance = 0
    local keyvalues = part:getTable(actionType)
    if keyvalues then
        local perks = keyvalues.skills;
        local perksTable = VehicleUtils.getPerksTableForChr(perks, player)
        successChance, _ = VehicleUtils.calculateInstallationSuccess(perks, player, perksTable)
    end
    return successChance
end

