BAM = BAM or {}


function BAM:OnMechanicActionDone(success)
    -- This function is only ever called in multiplayer, but if its called in singleplayer, do nothing-- Safety check: Ensure this is only run on the client side
    if not isClient() then
        --print("Error: OnMechanicActionDone called on server or singleplayer. Ignoring.")
        return
    end

    if not BAM.IsCurrentlyTraining then
        return
    end

    local player = self
    print("-> Mechanic action done! Player: ", player, " ", BAM.LastWorkedPart:getId(), " ", BAM.LastWorkedActionType, " Success: ", success)

    -- If the action was successful, save the XP data and sync to server
    -- TODO: This should be done even without training, but we don't have access to the currently worked on part in that case
    if success then
        BAM.RecordXPAction(player, BAM.Vehicle, BAM.LastWorkedPart, BAM.LastWorkedActionType)
        --print("BAM: XP Cooldown saved for part " .. BAM.LastWorkedPart:getId())
    end

    -- Start a tick countdown, after which 'workOnNextPart' is called to continue the training
    -- This gives the server enough time to update the game state
    BAM.DelayTimer = 20  -- 10 ticks is approx 0.16 seconds
    print("Waiting ", BAM.DelayTimer, " ticks before working on next part...")
end


-- The Tick Handler: Runs every single frame (approx 60 times/sec)
function BAM.OnTick()
    -- Fail fast. If not training, do nothing immediately.
    if not BAM.IsCurrentlyTraining then return end

    -- Only run logic if the timer is active (greater than 0)
    if BAM.DelayTimer > 0 then
        BAM.DelayTimer = BAM.DelayTimer - 1

        -- When the timer hits exactly 0, execute the delayed action
        if BAM.DelayTimer == 0 then
            if BAM.IsCurrentlyTraining then
                --print("Delay finished: executing workOnNextPart...")
                BAM:workOnNextPart(BAM.Player, BAM.Vehicle)
            end
        end
    end
end


-- Only register these events if we are running in multiplayer
if isClient() then
    Events.OnTick.Add(BAM.OnTick)
    Events.OnMechanicActionDone.Add(BAM.OnMechanicActionDone);
end