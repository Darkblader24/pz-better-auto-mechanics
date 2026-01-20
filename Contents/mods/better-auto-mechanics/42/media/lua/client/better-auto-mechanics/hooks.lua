BAM = BAM or {}

-- #####################
-- Hooking into vanilla functions to add our training logic
-- #####################

local original_ISUninstallVehiclePart_complete = ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete()
    -- First call the original complete function
    --DebugLog.log("ISUninstallVehiclePart:complete called")
    local success = original_ISUninstallVehiclePart_complete(self);
    --DebugLog.log("ISUninstallVehiclePart:complete done, returned: ", success)

    -- Then call workOnNextPart to continue the training on the next part
    -- We can only use this check in SP, because in MP the "complete" function never gets called
    -- In MP we use the OnMechanicActionDone event to continue training after uninstall/install
    if BAM.IsCurrentlyTraining and not isClient() then
        DebugLog.log("Continuing mechanics training after uninstall...")
        BAM:workOnNextPart(self.character, self.vehicle)
    end

    return success
end


local original_ISInstallVehiclePart_complete = ISInstallVehiclePart.complete
function ISInstallVehiclePart:complete()
    -- First call the original complete function
    --DebugLog.log("ISInstallVehiclePart:complete called")
    local success = original_ISInstallVehiclePart_complete(self);
    --DebugLog.log("ISInstallVehiclePart:complete done, returned: ", success)

    -- Then call workOnNextPart to continue the training on the next part
    -- We can only use this check in SP, because in MP the "complete" function never gets called
    -- In MP we use the OnMechanicActionDone event to continue training after uninstall/install
    if BAM.IsCurrentlyTraining and not isClient() then
        DebugLog.log("Continuing mechanics training after install...")
        BAM:workOnNextPart(self.character, self.vehicle)
    end

    return success
end


local original_ISUninstallVehiclePart_stop = ISUninstallVehiclePart.stop
function ISUninstallVehiclePart:stop()
    -- First call the original stop function
    --DebugLog.log("ISUninstallVehiclePart:stop called")
    local success = original_ISUninstallVehiclePart_stop(self);
    --DebugLog.log("ISUninstallVehiclePart:stop done, returned: ", success)

    -- Then stop the training
    -- We can only use this check in SP, because in MP this gets fired after every action during training, unlike in SP
    -- In MP we use the initParts hook below to stop training when opening the hood
    if BAM.IsCurrentlyTraining and not isClient() then
        DebugLog.log("Stopping mechanics training due to uninstall stop...")
        BAM:StopMechanicsTraining(nil)
    end

    return success
end


local original_ISInstallVehiclePart_stop = ISInstallVehiclePart.stop
function ISInstallVehiclePart:stop()
    -- First call the original stop function
    --DebugLog.log("ISInstallVehiclePart:stop called")
    local success = original_ISInstallVehiclePart_stop(self);
    --DebugLog.log("ISInstallVehiclePart:stop done, returned: ", success)

    -- Then stop the training
    -- We can only use this check in SP, because in MP this gets fired after every action during training, unlike in SP
    -- In MP we use the initParts hook below to stop training when opening the hood
    if BAM.IsCurrentlyTraining and not isClient() then
        DebugLog.log("Stopping mechanics training due to install stop...")
        BAM:StopMechanicsTraining(nil)
    end

    return success
end


-- Used to stop the mechanics training. Whenever you open a hood you are no longer training mechanics
local original_ISVehicleMechanics_initParts = ISVehicleMechanics.initParts
function ISVehicleMechanics:initParts()
    --DebugLog.log("ISVehicleMechanics:initParts called")
    local success = original_ISVehicleMechanics_initParts(self);
    --DebugLog.log("ISVehicleMechanics:initParts done, returned: ", success)

    -- We we open another vehicle hood, then there should be no mechanics training going on
    if BAM.IsCurrentlyTraining then
        DebugLog.log("Stopping mechanics training due to vehicle mechanics init...")
        BAM:StopMechanicsTraining(nil)
    end

    return success
end


local original_ISPathFindAction_start = ISPathFindAction.start
function ISPathFindAction:start()
    -- First call the original start function
    --DebugLog.log("ISPathFindAction:start called")
    local success = original_ISPathFindAction_start(self);
    --DebugLog.log("ISPathFindAction:start done, returned: ", success)

    -- If any pathfinding action fails during mechanics training, mark the part as inaccessible and continue training
    if BAM.IsCurrentlyTraining then
        self:setOnFail(OnPathFailed)
    end

    return success
end


function OnPathFailed()
    local part = BAM.LastWorkedPart
    DebugLog.log("Part ", part:getId(), " is inaccessible during mechanics training.")

    BAM.InaccessibleParts[part:getId()] = true
    BAM.WorkDelayTimer = 10  -- Call workOnNextPart after a short delay instead of instantly after pathfinding failed, to avoid pathfinding issues
end


--local original_ISUninstallVehiclePart_perform = ISUninstallVehiclePart.perform
--function ISUninstallVehiclePart:perform()
--    -- First call the original perform function
--    DebugLog.log("ISUninstallVehiclePart:perform called")
--    local success = original_ISUninstallVehiclePart_perform(self);
--    DebugLog.log("ISUninstallVehiclePart:perform done, returned: ", success)
--
--    return success
--end
--
--
--local original_ISUninstallVehiclePart_update = ISUninstallVehiclePart.update
--function ISUninstallVehiclePart:update()
--    -- First call the original update function
--    DebugLog.log("ISUninstallVehiclePart:update called")
--    local success = original_ISUninstallVehiclePart_update(self);
--    DebugLog.log("ISUninstallVehiclePart:update done, returned: ", success)
--
--    return success
--end


--local original_ISUninstallVehiclePart_start = ISUninstallVehiclePart.start
--function ISUninstallVehiclePart:start()
--    -- First call the original start function
--    DebugLog.log("ISUninstallVehiclePart:start called")
--    local success = original_ISUninstallVehiclePart_start(self);
--    DebugLog.log("ISUninstallVehiclePart:start done, returned: ", success)
--
--    return success
--end
--
--
--local original_ISUninstallVehiclePart_new = ISUninstallVehiclePart.new
--function ISUninstallVehiclePart:new(character, part, time)
--    DebugLog.log("ISUninstallVehiclePart:new called")
--    local obj = original_ISUninstallVehiclePart_new(self, character, part, time);
--    DebugLog.log("ISUninstallVehiclePart:new done, returned: ", obj)
--    return obj
--end

