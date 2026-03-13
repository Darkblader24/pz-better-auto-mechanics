BAM = BAM or {}

-- #####################
-- Hooking into vanilla functions to add our training logic
-- #####################


-- Once uninstall/install is complete, call the appropriate continuation function
-- These 'complete' hooks only work in SP, because in MP they never get called
-- In MP we use the OnMechanicActionDone event to continue after uninstall/install
local original_ISUninstallVehiclePart_complete = ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete(...)
    local success = original_ISUninstallVehiclePart_complete(self, ...)
    if BAM.IsCurrentlyWorking() then
        BAM.SaveGameSpeed()
        BAM.ContinueWork(self.character, self.vehicle)
    end
    return success
end


local original_ISInstallVehiclePart_complete = ISInstallVehiclePart.complete
function ISInstallVehiclePart:complete(...)
    local success = original_ISInstallVehiclePart_complete(self, ...)
    if BAM.IsCurrentlyWorking() then
        BAM.SaveGameSpeed()
        BAM.ContinueWork(self.character, self.vehicle)
    end
    return success
end


-- Stop the training or skip the part during batch uninstall if working on a part is interrupted
-- We can only use these 'stop' hooks in SP, because in MP they get fired after every action during training, unlike in SP
-- In MP we use the initParts hook below to stop training when opening the hood or when the player is too far away from the car
local original_ISUninstallVehiclePart_stop = ISUninstallVehiclePart.stop
function ISUninstallVehiclePart:stop(...)
    local success = original_ISUninstallVehiclePart_stop(self, ...)
    if BAM.IsCurrentlyWorking() and not isClient() then
        DebugLog.log("Stopping mechanics work due to uninstall stop...")
        BAM.StopMechanicsWork(nil)
    end
    return success
end


local original_ISInstallVehiclePart_stop = ISInstallVehiclePart.stop
function ISInstallVehiclePart:stop(...)
    local success = original_ISInstallVehiclePart_stop(self, ...)
    if BAM.IsCurrentlyWorking() and not isClient() then
        DebugLog.log("Stopping mechanics work due to install stop...")
        BAM.StopMechanicsWork(nil)
    end
    return success
end


-- Used to stop any active BAM work. Whenever you open a hood you are no longer training/uninstalling
local original_ISVehicleMechanics_initParts = ISVehicleMechanics.initParts
function ISVehicleMechanics:initParts(...)
    local success = original_ISVehicleMechanics_initParts(self, ...)
    if BAM.IsCurrentlyWorking() then
        DebugLog.log("Stopping mechanics work due to vehicle mechanics init...")
        BAM.StopMechanicsWork(nil)
    end
    return success
end


local original_ISPathFindAction_start = ISPathFindAction.start
function ISPathFindAction:start(...)
    local success = original_ISPathFindAction_start(self, ...)

    -- If any pathfinding action fails during mechanics work, mark the part as inaccessible and continue
    if BAM.IsCurrentlyWorking() then
        self:setOnFail(BAM.OnPathFailed)
        BAM.CheckGameSpeedInXTicks(10)
    end
    return success
end


function BAM.OnPathFailed()
    if not BAM.IsCurrentlyWorking() or not BAM.LastWorkedPart then return end

    local part = BAM.LastWorkedPart
    DebugLog.log("Part " .. part:getId() .. " is inaccessible during mechanics work.")

    BAM.InaccessibleParts[part:getId()] = true
    BAM.WorkOnNextPartInXTicks(10) -- Call continuation after a short delay instead of instantly after pathfinding failed, to avoid pathfinding issues
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


local original_ISPathFindAction_start = ISPathFindAction.start
function ISPathFindAction:start(...)
    local success = original_ISPathFindAction_start(self, ...)

    -- During mechanics work, make the player sneak-run after a couple of ticks of pathfinding
    if BAM.IsCurrentlyWorking() then
        local endurance = 1
        if BAM.GameVersionNewerThanOrEqual(42, 13, 0) then
            endurance = self.character:getStats():get(CharacterStat.ENDURANCE)
        else
            endurance = self.character:getStats():getEndurance()
        end

        --DebugLog.log("Endurance:" .. tostring(endurance))
        if endurance > 0.5 then  -- Only run if the endurance is above 50%
            self.BAM_ForceRun = 150
            -- If the game runs very fast, the character often runs too far and needs to adjust again, resulting in a time loss.
            if getGameSpeed() >= 3 then
                 self.BAM_ForceRun = 1000
            end
        end
        self.character:setSneaking(false)
    end
    return success
end


local original_ISPathFindAction_update = ISPathFindAction.update
function ISPathFindAction:update(...)
    local success = original_ISPathFindAction_update(self, ...)
    -- During mechanics work, make the player sneak-run after a couple of ticks spend pathfinding
    if BAM.IsCurrentlyWorking() then
        if self.BAM_ForceRun > 0 then
            --DebugLog.log("Forcerun =" .. tostring(self.BAM_ForceRun))
            self.BAM_ForceRun = self.BAM_ForceRun - 3 * getGameTime():getMultiplier()
            if self.BAM_ForceRun <= 0 then
                DebugLog.log("Starting to run!")
            end
        else
            self.character:setSneaking(true)
            self.character:setRunning(true)
        end
    end
    return success
end


local original_ISTimedActionQueue_resetQueue = ISTimedActionQueue.resetQueue
function ISTimedActionQueue:resetQueue(...)
    local success = original_ISTimedActionQueue_resetQueue(self, ...)

    if BAM.IsCurrentlyWorking() and BAM.LastWorkedPart then
        local part = BAM.LastWorkedPart
        DebugLog.log("Part " .. part:getId() .. " is bugged during mechanics work. Skipping it.")

        BAM.InaccessibleParts[part:getId()] = true
        BAM.WorkOnNextPartInXTicks(10)
        BAM.CheckGameSpeedInXTicks(20)
    end

    return success
end

