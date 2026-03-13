BAM = BAM or {}

-- ########################
--    Uninstall Buttons
-- ########################


-- Each category maps to an explicit list of part IDs.
-- "Everything" uses nil to match all parts.
-- Translation keys map to vanilla game translation strings where possible
BAM.UninstallCategories = {
    {
        key = "everything",
        label = "UI_BAM_Uninstall_Everything",
        ids = nil,  -- nil means match all parts
    },
    {
        key = "tires",
        label = "IGUI_VehiclePartCattire",
        ids = { "TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight" },
    },
    {
        key = "doors",
        label = "IGUI_VehiclePartCatdoor",
        ids = { "DoorFrontLeft", "DoorFrontRight", "DoorMiddleLeft", "DoorMiddleRight", "DoorRearLeft", "DoorRearRight", "DoorRear" },
    },
    --{
    --    key = "windows",
    --    label = "IGUI_VehiclePartWindow",
    --    ids = { "WindowFrontLeft", "WindowFrontRight", "WindowMiddleLeft", "WindowMiddleRight", "WindowRearLeft", "WindowRearRight", "Windshield", "WindshieldRear" },
    --},
    {
        key = "seats",
        label = "IGUI_VehiclePartCatseat",
        ids = { "SeatFrontLeft", "SeatFrontRight", "SeatMiddleLeft", "SeatMiddleRight", "SeatRearLeft", "SeatRearRight" },
    },
    {
        key = "lights",
        label = "IGUI_VehiclePartCatlights",
        ids = { "HeadlightLeft", "HeadlightRight", "HeadlightRearLeft", "HeadlightRearRight" },
    },
    {
        key = "brakes",
        label = "IGUI_VehiclePartCatbrakes",
        ids = { "BrakeFrontLeft", "BrakeFrontRight", "BrakeRearLeft", "BrakeRearRight" },
    },
    {
        key = "suspension",
        label = "IGUI_VehiclePartCatsuspension",
        ids = { "SuspensionFrontLeft", "SuspensionFrontRight", "SuspensionRearLeft", "SuspensionRearRight" },
    },
}

function BAM.CreateUninstallAllMenu(self, context, player, vehicle)
    if not context then return end

    -- Build a parent option: "Uninstall ..."
    local parentOption = context:addOption(getText("UI_BAM_Uninstall_Title"), nil)
    parentOption.iconTexture = getTexture("Item_Wrench")

    -- Create the submenu
    local subMenu = context:getNew(context)
    context:addSubMenu(parentOption, subMenu)

    local anyEnabled = false

    for _, category in ipairs(BAM.UninstallCategories) do
        -- Build a set-like table from the category ids list (or nil for "everything")
        local categoryIds
        if category.ids then
            categoryIds = {}
            for _, id in ipairs(category.ids) do
                categoryIds[id] = true
            end
        end

        -- Check how many parts can actually be uninstalled in this category
        local parts = BAM.GetUninstallablePartsByCategory(player, vehicle, categoryIds)
        local count = 0
        if category.ids then
            for _, part in ipairs(parts) do
                if categoryIds[part:getId()] then
                    count = count + 1
                end
            end
        end

        -- Build the label: "All Tires (3)" or "Everything (12)"
        local label = getText(category.label or category.key)
        if category.key ~= "everything" then
            label = getText("UI_BAM_Uninstall_All", label)
            label = label .. " (" .. tostring(count) .. ")"
        end

        local option = subMenu:addOption(label, self, BAM.UninstallCategory, player, vehicle, categoryIds)

        if count == 0 and category.ids then
            option.notAvailable = true
        else
            anyEnabled = true
        end
    end

    -- If no category has any uninstallable parts, grey out the parent option too
    if not anyEnabled then
        parentOption.notAvailable = true
    end
end


-- ########################
--      Uninstall Logic
-- ########################


--- Start batch-uninstalling all parts in a given category, one at a time.
-- Stops any active training first, then works through each matching part sequentially.
-- @param playerOrSelf  When called from the mechanics UI context menu, this is the ISVehicleMechanics 'self'.
-- @param player IsoPlayer
-- @param vehicle BaseVehicle
-- @param categoryIds table|nil  Set of part ID strings, or nil for "Everything"
function BAM.UninstallCategory(playerOrSelf, player, vehicle, categoryIds)
    -- Stop any active training session first
    ISTimedActionQueue.clear(player)
    BAM.StopMechanicsWork(nil)

    local parts = BAM.GetUninstallablePartsByCategory(player, vehicle, categoryIds)
    if #parts == 0 then return end

    DebugLog.log("=================================")
    DebugLog.log("BAM: Starting batch uninstall of " .. #parts .. " parts...")
    BAM.IsCurrentlyBatchUninstalling = true
    BAM.BatchUninstallCategoryIds = categoryIds
    BAM.Vehicle = vehicle
    BAM.InaccessibleParts = {}
    BAM.workOnNextUninstallPart(player, vehicle)
end


--- Pick and uninstall the next part in the current batch category, one at a time.
-- Skips parts marked as inaccessible. Stops when no more parts remain.
function BAM.workOnNextUninstallPart(player, vehicle)
    -- Safety check
    if not player or not vehicle then
        BAM.StopMechanicsWork(nil)
        return
    end

    -- Distance check
    local distanceToCar = player:DistToSquared(vehicle)
    if distanceToCar > 10 and BAM.LastWorkedPart then
        DebugLog.log("BAM: Player is too far from vehicle (" .. tostring(distanceToCar) .. " tiles). Stopping batch uninstall.")
        BAM.StopMechanicsWork(nil)
        return
    end

    -- Get the next part to uninstall in this category
    DebugLog.log("Deciding on next batch uninstall part...")
    local parts = BAM.GetUninstallablePartsByCategory(player, vehicle, BAM.BatchUninstallCategoryIds)

    -- Use the first part that is valid for uninstall
    for _, part in ipairs(parts) do
        if BAM.PartCanBeBatchUninstalled(player, vehicle, part) then
            DebugLog.log("BAM: Next part to batch uninstall: " .. part:getId())
            BAM.UninstallPart(player, part)
            return
        end
    end

     DebugLog.log("BAM: No more accessible parts to batch uninstall.")
     BAM.StopMechanicsWork(nil)
end


-- ########################
--     Uninstall Utils
-- ########################


--- Returns a list of parts on the vehicle that the player can uninstall, filtered by category.
-- Respects BAM.InaccessibleParts to skip parts that have previously failed during batch uninstall.
-- @param player IsoPlayer
-- @param vehicle BaseVehicle
-- @param categoryIds table|nil  A set-like table { ["TireFrontLeft"]=true, ... } or nil for all parts
-- @return table  List of VehiclePart objects
function BAM.GetUninstallablePartsByCategory(player, vehicle, categoryIds)
    -- Collect all installed car parts into a list for sorting
    local validParts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if categoryIds == nil or categoryIds[part:getId()] then
            table.insert(validParts, part)
        end
    end

    local sortedParts = BAM.SortParts(validParts)
    local uninstallableParts = {}

    -- Check each part for uninstall possibility and required uninstalls
    for _, part in ipairs(sortedParts) do
        --DebugLog.log("Checking part" .. part:getId())
        if part:getInventoryItem() then
            local requiredParts = BAM.GetRequiredUninstalledPartsForPart(part)
            for _, p in ipairs(requiredParts) do
                if p:getInventoryItem() then
                    table.insert(uninstallableParts, p)
                end
            end
            table.insert(uninstallableParts, part)
        end
    end
    return uninstallableParts
end


function BAM.PartCanBeBatchUninstalled(player, vehicle, part)
    --DebugLog.log("Checking if part " .. part:getId() .. " can be uninstalled...")
    -- 1. Check if the physical action is possible (tools, location, etc.)
    if not part:getInventoryItem() then
        --DebugLog.log("Part " .. part:getId() .. " has no item installed, cannot uninstall.")
        return false
    end
    if not part:getVehicle():canUninstallPart(player, part) then
        --DebugLog.log("Part " .. part:getId() .. " cannot be uninstalled due to physical constraints.")
        return false
    end
    if BAM.InaccessibleParts[part:getId()] then
        --DebugLog.log("Part " .. part:getId() .. " is marked as inaccessible, cannot uninstall.")
        return false
    end

    -- 2. Get part success chance
    local successChance = BAM.GetPartSuccessChance(player, part, "uninstall")
    if successChance < 1 then
        --DebugLog.log("Part " .. part:getId() .. " has a success chance of " .. tostring(successChance) .. "%, which is below the minimum threshold.")
        return false
    end

    -- 3. Check for smashed cars, their front windows are inaccessible
    if part:getId():find("WindowFront") or part:getId():find("Seat") then
        local scriptName = vehicle:getScript():getName()
        --DebugLog.log("-> Vehicle script name: " .. scriptName)
        if string.find(scriptName, "Burnt") or string.find(scriptName, "Smashed") then
            --DebugLog.log("-> Vehicle is burnt or smashed, cannot uninstall " .. part:getId())
            return false
        end
    end

    return true
end

