require "Vehicles/ISUI/ISVehicleMechanics"
require "Vehicles/TimedActions/ISUninstallVehiclePart"
require "Vehicles/TimedActions/ISInstallVehiclePart"


-- Add Train Mechanics button to vehicle part context menu
local original_doPartContextMenu = ISVehicleMechanics.doPartContextMenu
function ISVehicleMechanics:doPartContextMenu(part, x, y)
    original_doPartContextMenu(self, part, x, y);
    self:addMechanicsButtons()
end

-- Create the Train Mechanics button and its tooltip
function ISVehicleMechanics:addMechanicsButtons()
    -- Add Train Mechanics button
    local trainButton = self.context:addOption("Train Mechanics", self, ISVehicleMechanics.StartMechanicsTraining, self.chr, self.vehicle)
    local trainTooltip = ISToolTip:new()
    trainTooltip:initialise()
    trainTooltip:setVisible(true)
    trainTooltip.description = generateDescription(self.chr, self.vehicle)
    trainButton.toolTip = trainTooltip
end


function generateDescription(player, vehicle)
    local msg = "Training needs: <LINE>"

    -- Item requirements
    local hasScrewdriver = player:getInventory():getFirstTagRecurse(ItemTag.SCREWDRIVER)
    local hasWrench = player:getInventory():getFirstTagRecurse(ItemTag.WRENCH)
    local hasLugWrench = player:getInventory():getFirstTagRecurse(ItemTag.LUG_WRENCH)
    local hasJack = player:getInventory():getFirstTypeRecurse("Jack")

    local nameScrewdriver = getScriptManager():getItem("Base.Screwdriver"):getDisplayName()
    local nameMultitool = getScriptManager():getItem("Base.Multitool"):getDisplayName()
    local nameHandiknife = getScriptManager():getItem("Base.Handiknife"):getDisplayName()
    local nameWrench = getScriptManager():getItem("Base.Wrench"):getDisplayName()
    local nameRatchetWrench = getScriptManager():getItem("Base.Ratchet"):getDisplayName()
    local nameLugWrench = getScriptManager():getItem("Base.LugWrench"):getDisplayName()
    local nameTireIron = getScriptManager():getItem("Base.TireIron"):getDisplayName()
    local nameJack = getScriptManager():getItem("Base.Jack"):getDisplayName()

    if hasScrewdriver then
        msg = msg .. " <GREEN> - "
    else
        msg = msg .. " <RED> - "
    end
    msg = msg .. nameScrewdriver .. " / " .. nameMultitool .." / " .. nameHandiknife .. " <LINE>"

    if hasWrench then
        msg = msg .. " <GREEN> - "
    else
        msg = msg .. " <RED> - "
    end
    msg = msg .. nameWrench .. " / " .. nameRatchetWrench .. " <LINE>"

    if hasLugWrench then
        msg = msg .. " <GREEN> - "
    else
        msg = msg .. " <RED> - "
    end
    msg = msg .. nameLugWrench .. " / " .. nameTireIron .. " <LINE>"

    if hasJack then
        msg = msg .. " <GREEN> - "
    else
        msg = msg .. " <RED> - "
    end
    msg = msg .. nameJack  .. " <LINE>"

    -- Skill requirements
    local skillLevel = player:getPerkLevel(Perks.Mechanics)
    msg = msg .. "<RGB:1,1,1><LINE>Current Mechanics Level: " .. tostring(skillLevel) .. " <LINE>"
    if skillLevel < 2 then
        msg = msg .. " <RED> -> Parts will likely break! <LINE>"
        msg = msg .. " <RED> -> Use disposable vehicles! <LINE>"
        msg = msg .. " <RED> -> (Parts with success chance <10% will be skipped) <LINE>"
    elseif skillLevel < 7 then
        msg = msg .. " <ORANGE> -> Some parts might break <LINE>"
        msg = msg .. " <ORANGE> -> Use disposable vehicles <LINE>"
    else
        msg = msg .. " <GREEN> -> No parts will be damaged <LINE>"
        msg = msg .. " <GREEN> -> Safe on any vehicle <LINE>"
    end

    -- Recipe requirements
    local readRecipe = false
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local keyvalues = part:getTable("uninstall")
        if keyvalues and keyvalues.recipes and keyvalues.recipes ~= "" then
            for _, recipe in ipairs(keyvalues.recipes:split(";")) do
                if not player:isRecipeKnown(recipe) then
                    msg = msg .. "<RGB:1,1,1><LINE>Read this recipe to work on all parts: <LINE>"
                    msg = msg .. " <RED> - " .. getText("Tooltip_vehicle_requireRecipe", getRecipeDisplayName(recipe)) .. " <LINE>"
                else
                    msg = msg .. "<RGB:1,1,1><LINE>You can work on all parts because you know this recipe: <LINE>"
                    msg = msg .. " <GREEN> - " .. getText("Tooltip_vehicle_requireRecipe", getRecipeDisplayName(recipe)) .. " <LINE>"
                end
                readRecipe = true
            end
        end
        if readRecipe then break end -- Only show the first recipe found
    end

    -- Notes
    msg = msg .. "<RGB:1,1,1><LINE>Make sure all car seats are empty."


    return msg
end


