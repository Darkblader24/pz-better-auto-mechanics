BAM = BAM or {}

-- #####################
-- Hooking into vanilla functions to add our training logic
-- #####################

local original_ISUninstallVehiclePart_complete = ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete()
    -- First call the original complete function
    print("ISUninstallVehiclePart:complete called")
    local success = original_ISUninstallVehiclePart_complete(self);
    print("ISUninstallVehiclePart:complete done, returned: ", success)
    print("Uninstall complete called, success: ", success)

    -- Then call workOnNextPart to continue the training on the next part
    -- We can only use this check in SP, because in MP the "complete" function never gets called
    -- In MP we use the OnMechanicActionDone event to continue training after uninstall/install
    if BAM.IsCurrentlyTraining and not isClient() then
        print("Continuing mechanics training after uninstall...")
        BAM:workOnNextPart(self.character, self.vehicle)
    end

    return success
end


local original_ISInstallVehiclePart_complete = ISInstallVehiclePart.complete
function ISInstallVehiclePart:complete()
    -- First call the original complete function
    print("ISInstallVehiclePart:complete called")
    local success = original_ISInstallVehiclePart_complete(self);
    print("ISInstallVehiclePart:complete done, returned: ", success)
    print("Uninstall complete called, success: ", success)

    -- Then call workOnNextPart to continue the training on the next part
    -- We can only use this check in SP, because in MP the "complete" function never gets called
    -- In MP we use the OnMechanicActionDone event to continue training after uninstall/install
    if BAM.IsCurrentlyTraining and not isClient() then
        print("Continuing mechanics training after install...")
        BAM:workOnNextPart(self.character, self.vehicle)
    end

    return success
end


local original_ISUninstallVehiclePart_stop = ISUninstallVehiclePart.stop
function ISUninstallVehiclePart:stop()
    -- First call the original stop function
    print("ISUninstallVehiclePart:stop called")
    local success = original_ISUninstallVehiclePart_stop(self);
    print("ISUninstallVehiclePart:stop done, returned: ", success)

    -- Then stop the training
    -- We can only use this check in SP, because in MP this gets fired after every action during training, unlike in SP
    -- In MP we use the initParts hook below to stop training when opening the hood
    if BAM.IsCurrentlyTraining and not isClient() then
        print("Stopping mechanics training due to uninstall stop...")
        BAM:StopMechanicsTraining(nil)
    end

    return success
end


local original_ISInstallVehiclePart_stop = ISInstallVehiclePart.stop
function ISInstallVehiclePart:stop()
    -- First call the original stop function
    print("ISInstallVehiclePart:stop called")
    local success = original_ISInstallVehiclePart_stop(self);
    print("ISInstallVehiclePart:stop done, returned: ", success)

    -- Then stop the training
    -- We can only use this check in SP, because in MP this gets fired after every action during training, unlike in SP
    -- In MP we use the initParts hook below to stop training when opening the hood
    if BAM.IsCurrentlyTraining and not isClient() then
        print("Stopping mechanics training due to install stop...")
        BAM:StopMechanicsTraining(nil)
    end

    return success
end


-- Used to stop the mechanics training. Whenever you open a hood you are no longer training mechanics
local original_ISVehicleMechanics_initParts = ISVehicleMechanics.initParts
function ISVehicleMechanics:initParts()
    print("ISVehicleMechanics:initParts called")
    local success = original_ISVehicleMechanics_initParts(self);
    print("ISVehicleMechanics:initParts done, returned: ", success)

    -- Then stop the training
    if BAM.IsCurrentlyTraining then
        print("Stopping mechanics training due to vehicle mechanics init...")
        BAM:StopMechanicsTraining(nil)
    end

    return success
end


--local original_ISUninstallVehiclePart_perform = ISUninstallVehiclePart.perform
--function ISUninstallVehiclePart:perform()
--    -- First call the original perform function
--    print("ISUninstallVehiclePart:perform called")
--    local success = original_ISUninstallVehiclePart_perform(self);
--    print("ISUninstallVehiclePart:perform done, returned: ", success)
--
--    return success
--end
--
--
--local original_ISUninstallVehiclePart_update = ISUninstallVehiclePart.update
--function ISUninstallVehiclePart:update()
--    -- First call the original update function
--    print("ISUninstallVehiclePart:update called")
--    local success = original_ISUninstallVehiclePart_update(self);
--    print("ISUninstallVehiclePart:update done, returned: ", success)
--
--    return success
--end


--local original_ISUninstallVehiclePart_start = ISUninstallVehiclePart.start
--function ISUninstallVehiclePart:start()
--    -- First call the original start function
--    print("ISUninstallVehiclePart:start called")
--    local success = original_ISUninstallVehiclePart_start(self);
--    print("ISUninstallVehiclePart:start done, returned: ", success)
--
--    return success
--end
--
--
--local original_ISUninstallVehiclePart_new = ISUninstallVehiclePart.new
--function ISUninstallVehiclePart:new(character, part, time)
--    print("ISUninstallVehiclePart:new called")
--    local obj = original_ISUninstallVehiclePart_new(self, character, part, time);
--    print("ISUninstallVehiclePart:new done, returned: ", obj)
--    return obj
--end

