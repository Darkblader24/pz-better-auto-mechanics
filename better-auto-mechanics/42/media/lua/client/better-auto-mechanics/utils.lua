
function getNextUninstallablePart(player, vehicle)
    -- Collect all installed car parts into a list for sorting
    local validParts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)

        -- Gather only parts that are currently installed
        if part:getInventoryItem() ~= nil then
            table.insert(validParts, part)
        end
    end

    local sortedParts = sortParts(validParts)

    -- Check each part for uninstall possibility and XP eligibility
    for _, part in pairs(sortedParts) do
        -- 1. Check if the physical action is possible (tools, location, etc.)
        local canUninstallPart = part:getVehicle():canUninstallPart(player, part)

        -- 2. Check if the player is eligible for XP (Cooldown check)
        -- Key format: PartID + VehicleID + "1" (1 is for Uninstall)
        local canGainUninstallXP = false
        if part:getInventoryItem() then
            local xpKey = part:getInventoryItem():getID() .. vehicle:getMechanicalID() .. "1"
            lastWorkedOn = player:getMechanicsItem(xpKey)
            canGainUninstallXP = lastWorkedOn == nil
        end

        -- 3. Get success chance and failure chance
        local successChance, failureChance = 0, 100
        local keyvalues = part:getTable("install")
    	if keyvalues then
            local perks = keyvalues.skills;
            local perksTable = VehicleUtils.getPerksTableForChr(perks, player)
            successChance, failureChance = VehicleUtils.calculateInstallationSuccess(perks, player, perksTable)
        end

        --print(part:getId() .. " - UNINSTALL: " .. tostring(canUninstallPart) .. " - UNINSTALL XP: " .. tostring(canGainUninstallXP))

        -- 3. If all checks pass, return the part. We require at least 10% success chance to avoid an infinite loop bug.
        if canUninstallPart and canGainUninstallXP and successChance > 10 then
            print("Part " .. part:getId() .. " Success Chance: " .. tostring(successChance) .. "%, Failure Chance: " .. tostring(failureChance) .. "%")
            return part
        end
    end
    return nil
end


function getNextInstallablePartAndItem(player, vehicle)
    -- Collect all uninstalled car parts into a list for sorting
    local validParts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)

        -- Gather only parts that are currently not installed
        if part:getInventoryItem() == nil then
            table.insert(validParts, part)
        end
    end

    local sortedParts = sortParts(validParts)

    for _, part in pairs(sortedParts) do
        -- 1. Check if the physical action is possible (tools, location, etc.)
        local canInstallPart = part:getVehicle():canInstallPart(player, part)

        -- 2. Check if the player has the required part in inventory or on ground
        if canInstallPart then
            local item = getAnyItemOnPlayerThatMatchesThatPart(player, part);
            if item then
                return part, item
            end
        end
    end
    return nil, nil
end


function sortParts(parts)
    -- 1. Define the train order
    local orderList = {
        -- Front
        "Radio",
        "Battery",
        "HeadlightLeft",
        "HeadlightRight",
        "EngineDoor",  -- Hood
        "Windshield",

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
        "Muffler",
        "HeadlightRearLeft",
        "HeadlightRearRight",
        "TrunkDoor", -- Trunk Lid
        "DoorRear",
        "WindshieldRear",

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
        "PassengerCompartment",  -- ???
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



function getAnyItemOnPlayerThatMatchesThatPart(player, part)
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


----------------------------------------------------------
-- Make the functions publicly accessible
local Utils = {
    getAnyItemOnPlayerThatMatchesThatPart = getAnyItemOnPlayerThatMatchesThatPart,
    getNextUninstallablePart = getNextUninstallablePart,
    getNextInstallablePartAndItem = getNextInstallablePartAndItem,
}
return Utils