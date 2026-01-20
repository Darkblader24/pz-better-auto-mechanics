BAM = BAM or {}


-- Add Train Mechanics button to vehicle part context menu
local original_doPartContextMenu = ISVehicleMechanics.doPartContextMenu
function ISVehicleMechanics:doPartContextMenu(part, x, y, v1, v2, v3, v4)  -- Added a few more variables, in case any mod uses more
    --DebugLog.log("BAM: Adding Better Auto Mechanics button!")
    --DebugLog.log("BAM: ISVehicleMechanics:doPartContextMenu called")
    local success = original_doPartContextMenu(self, part, x, y, v1, v2, v3, v4);
    --DebugLog.log("BAM: ISVehicleMechanics:doPartContextMenu done, returned: ", success)

    self:addMechanicsButtons()
    --DebugLog.log("BAM: Added Better Auto Mechanics button!")
    return success
end

-- Create the Train Mechanics button and its tooltip
function ISVehicleMechanics:addMechanicsButtons()
    -- Add Train Mechanics button
    local trainButton = self.context:addOption(getText("UI_BAM_button.title"), self, BAM.StartMechanicsTraining, self.chr, self.vehicle)
    local trainTooltip = ISToolTip:new()
    trainTooltip:initialise()
    trainTooltip:setVisible(true)
    trainTooltip.description = GenerateDescription(self.chr, self.vehicle)
    trainButton.toolTip = trainTooltip
end


function GenerateDescription(player, vehicle)
    local newline = " <LINE>"
    local msg = getText("UI_BAM_button_desc.needs") .. ":"

    -- Tool check
    local hasScrewdriver = false
    local hasWrench = false
    local hasLugWrench = false
    if BAM.GameVersionNewerThanOrEqual(42, 13, 0) then
        hasScrewdriver = player:getInventory():getFirstTagRecurse(ItemTag.SCREWDRIVER)
        hasWrench = player:getInventory():getFirstTagRecurse(ItemTag.WRENCH)
        hasLugWrench = player:getInventory():getFirstTagRecurse(ItemTag.LUG_WRENCH)
    else
        hasScrewdriver = player:getInventory():getFirstTagRecurse("Screwdriver")
        hasWrench = player:getInventory():getFirstTagRecurse("Wrench")
        hasLugWrench = player:getInventory():getFirstTagRecurse("LugWrench")
    end
    local hasJack = player:getInventory():getFirstTypeRecurse("Jack")

    local nameScrewdriver = getScriptManager():getItem("Base.Screwdriver"):getDisplayName()
    local nameMultitool = getScriptManager():getItem("Base.Multitool"):getDisplayName()
    local nameHandiknife = getScriptManager():getItem("Base.Handiknife"):getDisplayName()
    local nameWrench = getScriptManager():getItem("Base.Wrench"):getDisplayName()
    local nameRatchetWrench = getScriptManager():getItem("Base.Ratchet"):getDisplayName()
    local nameLugWrench = getScriptManager():getItem("Base.LugWrench"):getDisplayName()
    local nameTireIron = getScriptManager():getItem("Base.TireIron"):getDisplayName()
    local nameJack = getScriptManager():getItem("Base.Jack"):getDisplayName()

    local color = hasScrewdriver and "<GREEN>" or "<RED>"
    msg = msg .. newline .. color .. " - " .. nameScrewdriver .. " / " .. nameMultitool .. " / " .. nameHandiknife

    color = hasWrench and "<GREEN>" or "<RED>"
    msg = msg .. newline .. color .. " - " .. nameWrench .. " / " .. nameRatchetWrench

    color = hasLugWrench and "<GREEN>" or "<RED>"
    msg = msg .. newline .. color .. " - " .. nameLugWrench .. " / " .. nameTireIron

    color = hasJack and "<GREEN>" or "<RED>"
    msg = msg .. newline .. color .. " - " .. nameJack

    -- Skill check
    local skillLevel = player:getPerkLevel(Perks.Mechanics)
    local minSuccessChance = BAM.GetOptionMinPartSuccessChance()
    msg = msg .. newline
    msg = msg ..
    newline .. "<RGB:1,1,1>" .. getText("UI_BAM_button_desc.mechanics_level") .. ": " .. tostring(skillLevel)
    if minSuccessChance == 30 then  -- This is the default value, so show more detailed info
        if skillLevel < 2 then
            msg = msg .. newline .. "<RED> - " .. getText("UI_BAM_button_desc.parts_will_break") .. "!"
            msg = msg .. newline .. "<RED> - " .. getText("UI_BAM_button_desc.use_disposable_vehicles") .. "!"
            msg = msg ..
            newline .. "<RED> - " .. "(" .. getText("UI_BAM_button_desc.success_chance", minSuccessChance) .. ")"
        elseif skillLevel < 7 then
            msg = msg .. newline .. "<ORANGE> - " .. getText("UI_BAM_button_desc.parts_might_break")
            msg = msg .. newline .. "<ORANGE> - " .. getText("UI_BAM_button_desc.use_disposable_vehicles")
        else
            msg = msg .. newline .. "<GREEN> - " .. getText("UI_BAM_button_desc.parts_safe")
            msg = msg .. newline .. "<GREEN> - " .. getText("UI_BAM_button_desc.vehicle_safe")
        end
    else  -- Otherwise just show the minimum success chance and some edge case details
        msg = msg .. newline .. "<RGB:1,1,1> - " .. getText("UI_BAM_button_desc.success_chance", minSuccessChance)
        if minSuccessChance == 100 then
            msg = msg .. newline .. "<GREEN> - " .. getText("UI_BAM_button_desc.parts_safe")
            msg = msg .. newline .. "<GREEN> - " .. getText("UI_BAM_button_desc.vehicle_safe")
        end
    end

    -- Recipe check
    local recipe, knowsRecipe = PlayerKnowsRecipe(player, vehicle)
    if recipe then
        local recipeDisplayName = getText("Tooltip_vehicle_requireRecipe", getRecipeDisplayName(recipe))
        if knowsRecipe then
            msg = msg .. newline
            msg = msg .. newline .. "<RGB:1,1,1>" .. getText("UI_BAM_button_desc.recipe_known") .. ":"
            msg = msg .. newline .. "<GREEN> - " .. recipeDisplayName
        else
            msg = msg .. newline
            msg = msg .. newline .. "<RGB:1,1,1>" .. getText("UI_BAM_button_desc.recipe_unknown") .. ":"
            msg = msg .. newline .. "<RED> - " .. recipeDisplayName
        end
    end

    ---- Car Key check
    if not PlayerHasCarAccess(player, vehicle) then
        msg = msg .. newline
        msg = msg .. newline .. "<RGB:1,1,1>" .. getText("UI_BAM_button_desc.no_car_access")
        msg = msg .. newline .. "<ORANGE> - " .. getText("UI_BAM_button_desc.parts_inaccessible")
    end


    -- Notes
    msg = msg .. newline
    msg = msg .. newline .. "<RGB:1,1,1>" .. getText("UI_BAM_button_desc.empty_seats")

    if BAM.IsServerOverwritingOptionMinPartSuccessChance() then
        msg = msg .. newline
        msg = msg .. newline .. "<RGB:0.5,0.5,0.5>" .. getText("UI_BAM_button_desc.server_enforce")
        msg = msg .. newline .. "<RGB:0.5,0.5,0.5>" .. "  - " .. getText("UI_BAM_options_title.min_success_chance") .. ": " .. BAM.GetOptionMinPartSuccessChance() .. "%"
    end


    return msg
end


function PlayerKnowsRecipe(player, vehicle)
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local keyvalues = part:getTable("uninstall")
        if keyvalues and keyvalues.recipes and keyvalues.recipes ~= "" then
            for _, recipe in ipairs(keyvalues.recipes:split(";")) do
                return recipe, player:isRecipeKnown(recipe)  -- Only return the first recipe found
            end
        end
    end
    return nil, false
end


function PlayerHasCarAccess(player, vehicle)
    local needsKey = false
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if VehicleUtils.RequiredKeyNotFound(part, player) then
            needsKey = true
            break
        end
    end
    return not needsKey
end


