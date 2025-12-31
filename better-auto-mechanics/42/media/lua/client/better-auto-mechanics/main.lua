require "Vehicles/ISUI/ISVehicleMechanics"
require "Vehicles/TimedActions/ISUninstallVehiclePart"
require "Vehicles/TimedActions/ISInstallVehiclePart"
local Utils = require("better-auto-mechanics/utils")

local IsCurrentlyTraining = false


function ISVehicleMechanics:StartMechanicsTraining(player, vehicle)
    print("=================================")
    print("Starting mechanics training!")
    IsCurrentlyTraining = true
    ISVehicleMechanics:workOnNextPart(player, vehicle)
end


function StopMechanicsTraining(player)
    IsCurrentlyTraining = false
    setGameSpeed(1)
    getGameTime():setMultiplier(1)

    -- Display a ingame notification to inform the player that training has finished
    if player then
        HaloTextHelper.addText(player, "This car is !", "[br/]", 0, 255, 0)
    end

    print("Finished mechanics training!")
    print("=================================")
end

function ISVehicleMechanics:workOnNextPart(player, vehicle)
    -- Gather info about next parts to install/uninstall
    local partUninstall = Utils.getNextUninstallablePart(player, vehicle)
    local partInstall, itemInstall = Utils.getNextInstallablePartAndItem(player, vehicle)

    -- If no parts to install or uninstall, stop training
    if partUninstall == nil and partInstall == nil then
        StopMechanicsTraining(player)
        return
    end

    if partInstall and partUninstall then
        -- If we can install a tire, first check if we can uninstall brake/suspension first
        if string.find(partInstall:getId(), "Tire") then
            if string.find(partUninstall:getId(), "Brake") or string.find(partUninstall:getId(), "Suspension") then
                UninstallPart(player, partUninstall)
                return
            end
        end

        -- If we can install a window or windshield, first check if we can uninstall door first
        if string.find(partInstall:getId(), "Window") or string.find(partInstall:getId(), "Windshield") then
            if string.find(partUninstall:getId(), "Door") then
                UninstallPart(player, partUninstall)
                return
            end
        end
    end

    -- If we can install any part, do it. We always prioritize installation over uninstallation (except for brakes/suspension above)
    if partInstall and itemInstall then
        InstallPart(player, partInstall, itemInstall)
        return
    end

    -- Otherwise, uninstall the next part
    if partUninstall then
        UninstallPart(player, partUninstall)
        return
    end

    -- If we reach here, something went wrong. Probably because we have a part to install but no item for it.
    print("Error: Unable to determine next part to work on.")
    StopMechanicsTraining(player)
end


function InstallPart(player, part, item)
    print("Installing item " .. item:getName() .. " into part: " .. part:getId())
    ISVehiclePartMenu.onInstallPart(player, part, item)  -- Start timed task
end


function UninstallPart(player, part)
    print("Uninstalling part: " .. part:getId())
    ISVehiclePartMenu.onUninstallPart(player, part) -- Start timed task
end


-- #####################
-- Hooking into vanilla functions to add our training logic
-- #####################

local original_ISUninstallVehiclePart_complete = ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete()
    -- First call the original complete function
    local success = original_ISUninstallVehiclePart_complete(self);

    -- Then call workOnNextPart to continue the training on the next part
    if IsCurrentlyTraining then
        ISVehicleMechanics:workOnNextPart(self.character, self.vehicle)
    end

    return success
end


local original_ISInstallVehiclePart_complete = ISInstallVehiclePart.complete
function ISInstallVehiclePart:complete()
    -- First call the original complete function
    local success = original_ISInstallVehiclePart_complete(self);

    -- Then call workOnNextPart to continue the training on the next part
    if IsCurrentlyTraining then
        ISVehicleMechanics:workOnNextPart(self.character, self.vehicle)
    end

    return success
end


local original_ISUninstallVehiclePart_stop = ISUninstallVehiclePart.stop
function ISUninstallVehiclePart:stop()
    -- First call the original stop function
    local success = original_ISUninstallVehiclePart_stop(self);

    -- Then stop the training
    if IsCurrentlyTraining then
        StopMechanicsTraining(nil)
    end

    return success
end


local original_ISInstallVehiclePart_stop = ISInstallVehiclePart.stop
function ISInstallVehiclePart:stop()
    -- First call the original stop function
    local success = original_ISInstallVehiclePart_stop(self);

    -- Then stop the training
    if IsCurrentlyTraining then
        StopMechanicsTraining(nil)
    end

    return success
end

