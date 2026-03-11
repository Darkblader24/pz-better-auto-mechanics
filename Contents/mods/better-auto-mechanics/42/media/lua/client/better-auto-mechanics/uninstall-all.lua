BAM = BAM or {}

-- ########################
--    Uninstall Buttons
-- ########################

-- Create the Uninstall All menu with category sub-options
-- Translation keys map to vanilla game translation strings where possible
local uninstallCategoryLabels = {
    everything  = "UI_BAM_Uninstall_Everything",
    tires       = "IGUI_VehiclePartCattire",
    doors       = "IGUI_VehiclePartCatdoor",
    windows     = "IGUI_VehiclePartWindow",  -- todo
    seats       = "IGUI_VehiclePartCatseat",
    lights      = "IGUI_VehiclePartCatlights",
    brakes      = "IGUI_VehiclePartCatbrakes",
    suspension  = "IGUI_VehiclePartCatsuspension",
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
        local count = #parts

        -- Build the label: "All Tires (3)" or "Everything (12)"
        local label = getText(uninstallCategoryLabels[category.key] or category.key)
        if category.key ~= "everything" then
            label = getText("UI_BAM_Uninstall_All", label)
        end
        label = label .. " (" .. tostring(count) .. ")"

        local option = subMenu:addOption(label, self, BAM.UninstallCategory, player, vehicle, categoryIds)

        if count == 0 then
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


--- Batch-uninstall all parts in a given category.
-- Stops any active training first, then queues vanilla uninstall actions for each matching part.
-- @param playerOrSelf  When called from the mechanics UI context menu, this is the ISVehicleMechanics 'self'.
-- @param player IsoPlayer
-- @param vehicle BaseVehicle
-- @param categoryIds table|nil  Set of part ID strings, or nil for "Everything"
function BAM.UninstallCategory(playerOrSelf, player, vehicle, categoryIds)
    -- Stop any active training session first
    if BAM.IsCurrentlyTraining then
        ISTimedActionQueue.clear(player)
        BAM.StopMechanicsTraining(nil)
    end

    local parts = BAM.GetUninstallablePartsByCategory(player, vehicle, categoryIds)
    if #parts == 0 then return end

    -- Sort parts using the same order as training for consistency
    --parts = BAM.SortParts(parts)

    DebugLog.log("BAM: Batch uninstalling " .. #parts .. " parts...")
    for _, part in ipairs(parts) do
        if part:getInventoryItem() then
            DebugLog.log("  -> Queuing uninstall: " .. part:getId())
            ISVehiclePartMenu.onUninstallPart(player, part)
        end
    end
end


-- ########################
--     Uninstall Utils
-- ########################


-- Each category maps to an explicit list of part IDs.
-- "Everything" uses nil to match all parts.
BAM.UninstallCategories = {
    {
        key = "everything",
        ids = nil,  -- nil means match all parts
    },
    {
        key = "tires",
        ids = { "TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight" },
    },
    {
        key = "doors",
        ids = { "DoorFrontLeft", "DoorFrontRight", "DoorMiddleLeft", "DoorMiddleRight", "DoorRearLeft", "DoorRearRight", "DoorRear", "TrunkDoor" },
    },
    {
        key = "windows",
        ids = { "WindowFrontLeft", "WindowFrontRight", "WindowMiddleLeft", "WindowMiddleRight", "WindowRearLeft", "WindowRearRight", "Windshield", "WindshieldRear" },
    },
    {
        key = "seats",
        ids = { "SeatFrontLeft", "SeatFrontRight", "SeatMiddleLeft", "SeatMiddleRight", "SeatRearLeft", "SeatRearRight" },
    },
    {
        key = "lights",
        ids = { "HeadlightLeft", "HeadlightRight", "HeadlightRearLeft", "HeadlightRearRight" },
    },
    {
        key = "brakes",
        ids = { "BrakeFrontLeft", "BrakeFrontRight", "BrakeRearLeft", "BrakeRearRight" },
    },
    {
        key = "suspension",
        ids = { "SuspensionFrontLeft", "SuspensionFrontRight", "SuspensionRearLeft", "SuspensionRearRight" },
    },
}


--- Returns a list of parts on the vehicle that the player can uninstall, filtered by category.
-- @param player IsoPlayer
-- @param vehicle BaseVehicle
-- @param categoryIds table|nil  A set-like table { ["TireFrontLeft"]=true, ... } or nil for all parts
-- @return table  List of VehiclePart objects
function BAM.GetUninstallablePartsByCategory(player, vehicle, categoryIds)
    local parts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local id = part:getId()

        -- Filter: if categoryIds is provided, only include matching parts
        if categoryIds == nil or categoryIds[id] then
            if part:getInventoryItem() then
                -- Check if any part needs to be uninstalled first for this part
                local requiredParts = BAM.GetRequiredUninstalledPartsForPart(part)
                for _, requiredPart in ipairs(requiredParts) do
                    table.insert(parts, requiredPart)
                end
                table.insert(parts, part)
            end
        end
    end
    return parts
end


