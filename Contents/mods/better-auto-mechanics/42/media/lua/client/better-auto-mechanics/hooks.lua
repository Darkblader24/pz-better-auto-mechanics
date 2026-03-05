BAM = BAM or {}

-- #####################
-- Hooking into vanilla functions to add our training logic
-- #####################


-- Once uninstall/install is complete, call workOnNextPart to continue the training on the next part
-- These 'complete' hooks only work in SP, because in MP they never get called
-- In MP we use the OnMechanicActionDone event to continue training after uninstall/install
local original_ISUninstallVehiclePart_complete = ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete(...)
    local success = original_ISUninstallVehiclePart_complete(self, ...)
    if BAM.IsCurrentlyTraining then
        BAM.SaveGameSpeed()
        BAM:workOnNextPart(self.character, self.vehicle)
    end
    return success
end


local original_ISInstallVehiclePart_complete = ISInstallVehiclePart.complete
function ISInstallVehiclePart:complete(...)
    local success = original_ISInstallVehiclePart_complete(self, ...)
    if BAM.IsCurrentlyTraining then
        BAM.SaveGameSpeed()
        BAM:workOnNextPart(self.character, self.vehicle)
    end
    return success
end


-- Stop the training if working on a part is interrupted
-- We can only use these 'stop' hooks in SP, because in MP they get fired after every action during training, unlike in SP
-- In MP we use the initParts hook below to stop training when opening the hood or when the player is too far away from the car
local original_ISUninstallVehiclePart_stop = ISUninstallVehiclePart.stop
function ISUninstallVehiclePart:stop(...)
    local success = original_ISUninstallVehiclePart_stop(self, ...)
    if BAM.IsCurrentlyTraining and not isClient() then
        DebugLog.log("Stopping mechanics training due to uninstall stop...")
        BAM:StopMechanicsTraining(nil)
    end
    return success
end


local original_ISInstallVehiclePart_stop = ISInstallVehiclePart.stop
function ISInstallVehiclePart:stop(...)
    local success = original_ISInstallVehiclePart_stop(self, ...)
    if BAM.IsCurrentlyTraining and not isClient() then
        DebugLog.log("Stopping mechanics training due to install stop...")
        BAM:StopMechanicsTraining(nil)
    end
    return success
end


-- Used to stop the mechanics training. Whenever you open a hood you are no longer training mechanics
local original_ISVehicleMechanics_initParts = ISVehicleMechanics.initParts
function ISVehicleMechanics:initParts(...)
    local success = original_ISVehicleMechanics_initParts(self, ...)
    if BAM.IsCurrentlyTraining then
        DebugLog.log("Stopping mechanics training due to vehicle mechanics init...")
        BAM:StopMechanicsTraining(nil)
    end
    return success
end


local original_ISPathFindAction_start = ISPathFindAction.start
function ISPathFindAction:start(...)
    --DebugLog.log("ISPathFindAction_start 1: GAMESPEED: " .. getGameSpeed() .. " - " .. getGameTime():getMultiplier() .. " - " .. getGameTime():getTrueMultiplier())
    local success = original_ISPathFindAction_start(self, ...)
    --DebugLog.log("ISPathFindAction_start 2: GAMESPEED: " .. getGameSpeed() .. " - " .. getGameTime():getMultiplier() .. " - " .. getGameTime():getTrueMultiplier())

    -- If any pathfinding action fails during mechanics training, mark the part as inaccessible and continue training
    if BAM.IsCurrentlyTraining then
        self:setOnFail(OnPathFailed)
        BAM.CheckGameSpeedInXTicks(10)
    end
    return success
end


function OnPathFailed()
    local part = BAM.LastWorkedPart
    DebugLog.log("Part " .. part:getId() .. " is inaccessible during mechanics training.")

    BAM.InaccessibleParts[part:getId()] = true
    BAM.WorkOnNextPartInXTicks(10) -- Call workOnNextPart after a short delay instead of instantly after pathfinding failed, to avoid pathfinding issues
    BAM.CheckGameSpeedInXTicks(20)
end


-- Only for restoring game speed if it got changed for some reason
local original_ISInstallVehiclePart_start = ISInstallVehiclePart.start
function ISInstallVehiclePart:start(...)
    BAM.CheckGameSpeedInXTicks(10)
    local success = original_ISInstallVehiclePart_start(self, ...)
    return success
end


local original_ISUninstallVehiclePart_start = ISUninstallVehiclePart.start
function ISUninstallVehiclePart:start(...)
    BAM.CheckGameSpeedInXTicks(10)
    local success = original_ISUninstallVehiclePart_start(self, ...)
    return success
end


-- For debugging, display some details about the currently selected vehicle part
local original_ISVehicleMechanics_renderPartDetail = ISVehicleMechanics.renderPartDetail
function ISVehicleMechanics:renderPartDetail(part, ...)
    local success = original_ISVehicleMechanics_renderPartDetail(self, part, ...)
    if getCore():getDebug() then
        self:drawText("DBG: Part ID: " .. part:getId(), 10, 20, 1, 1, 1, 0.5)
        self:drawText("DBG: Can Gain Part XP: " .. tostring(BAM.CanGainXP(getPlayer(), part:getVehicle(), part, 1)), 10, 32, 1, 1, 1, 0.5)
	end
    return success
end


---- Only for restoring game speed if it got changed for some reason
--local original_ISInstallVehiclePart_start = ISInstallVehiclePart.start
--function ISInstallVehiclePart:start(...)
--    --DebugLog.log("ISInstallVehiclePart_start 1: GAMESPEED: " .. getGameSpeed() .. " - " .. getGameTime():getMultiplier() .. " - " .. getGameTime():getTrueMultiplier())
--    -- If the game speed or time multiplier got reset for some reason during mechanics training, set it back to the previous value
--    if BAM.IsCurrentlyTraining then
--        if getGameSpeed() < BAM.PrevGameSpeed then
--            DebugLog.log("Gamespeed got reset! Restoring to previous game speed: " .. BAM.PrevGameSpeed .. " | " .. BAM.PrevTimeMultiplier)
--            setGameSpeed(BAM.PrevGameSpeed)
--            getGameTime():setMultiplier(BAM.PrevTimeMultiplier)
--            DebugLog.log("New gamespeed: " .. getGameSpeed() .. " | " .. getGameTime():getMultiplier() .. " | " .. getGameTime():getTrueMultiplier())
--        end
--    end
--
--    local success = original_ISInstallVehiclePart_start(self, ...)
--    --DebugLog.log("ISInstallVehiclePart_start 2: GAMESPEED: " .. getGameSpeed() .. " - " .. getGameTime():getMultiplier() .. " - " .. getGameTime():getTrueMultiplier())
--    return success
--end
--
--
--local original_ISPathFindAction_perform = ISPathFindAction.perform
--function ISPathFindAction:perform(...)
--    --DebugLog.log("ISPathFindAction_perform 1: GAMESPEED: " .. getGameSpeed() .. " - " .. getGameTime():getMultiplier() .. " - " .. getGameTime():getTrueMultiplier())
--
--    -- If the game speed or time multiplier got reset for some reason during mechanics training, set it back to the previous value
--    if BAM.IsCurrentlyTraining then
--        if getGameSpeed() < BAM.PrevGameSpeed then
--            DebugLog.log("Gamespeed got reset during perform! Restoring to previous game speed: " .. BAM.PrevGameSpeed .. " | " .. BAM.PrevTimeMultiplier)
--            setGameSpeed(BAM.PrevGameSpeed)
--            getGameTime():setMultiplier(BAM.PrevTimeMultiplier)
--            DebugLog.log("New gamespeed: " .. getGameSpeed() .. " | " .. getGameTime():getMultiplier() .. " | " .. getGameTime():getTrueMultiplier())
--        end
--    end
--
--    -- First call the original perform function
--    --DebugLog.log("ISPathFindAction:perform called")
--    local success = original_ISPathFindAction_perform(self, ...)
--    --DebugLog.log("ISPathFindAction:perform done, returned: " .. success)
--    --DebugLog.log("ISPathFindAction_perform 2: GAMESPEED: " .. getGameSpeed() .. " - " .. getGameTime():getMultiplier() .. " - " .. getGameTime():getTrueMultiplier())
--
--    return success
--end


--local original_ISPathFindAction_stop = ISPathFindAction.stop
--function ISPathFindAction:stop(...)
--    DebugLog.log("ISPathFindAction_stop: GAMESPEED: " .. getGameSpeed() .. " - " .. getGameTime():getMultiplier())
--    -- First call the original stop function
--    --DebugLog.log("ISPathFindAction:stop called")
--    local success = original_ISPathFindAction_stop(self, ...)
--    --DebugLog.log("ISPathFindAction:stop done, returned: " .. success)
--
--    return success
--end


--local original_ISUninstallVehiclePart_perform = ISUninstallVehiclePart.perform
--function ISUninstallVehiclePart:perform(...)
--    -- First call the original perform function
--    DebugLog.log("ISUninstallVehiclePart:perform called")
--    local success = original_ISUninstallVehiclePart_perform(self, ...)
--    DebugLog.log("ISUninstallVehiclePart:perform done, returned: " .. success)
--
--    return success
--end
--
--
--local original_ISUninstallVehiclePart_update = ISUninstallVehiclePart.update
--function ISUninstallVehiclePart:update(...)
--    -- First call the original update function
--    DebugLog.log("ISUninstallVehiclePart:update called")
--    local success = original_ISUninstallVehiclePart_update(self, ...)
--    DebugLog.log("ISUninstallVehiclePart:update done, returned: " .. success)
--
--    return success
--end


--local original_ISUninstallVehiclePart_start = ISUninstallVehiclePart.start
--function ISUninstallVehiclePart:start(...)
--    DebugLog.log("ISUninstallVehiclePart_start: GAMESPEED: " .. getGameSpeed() .. " - " .. getGameTime():getMultiplier())
--    -- First call the original start function
--    --DebugLog.log("ISUninstallVehiclePart:start called")
--    local success = original_ISUninstallVehiclePart_start(self, ...)
--    --DebugLog.log("ISUninstallVehiclePart:start done, returned: " .. success)
--
--    return success
--end
--
--
--local original_ISUninstallVehiclePart_new = ISUninstallVehiclePart.new
--function ISUninstallVehiclePart:new(character, part, time, ...)
--    DebugLog.log("ISUninstallVehiclePart:new called")
--    local obj = original_ISUninstallVehiclePart_new(self, character, part, time, ...)
--    DebugLog.log("ISUninstallVehiclePart:new done, returned: " .. obj)
--    return obj
--end

