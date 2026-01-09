BAM = BAM or {}
BAM.IsCurrentlyTraining = false
BAM.Player = nil
BAM.Vehicle = nil
BAM.DelayTimer = 0
BAM.LastWorkedPart = nil
BAM.LastWorkedActionType = nil -- 1 = uninstall, 2 = install
BAM.InaccessibleParts = {}


function BAM:StartMechanicsTraining(player, vehicle)
    print("=================================")
    print("Starting mechanics training!")
    BAM.IsCurrentlyTraining = true
    BAM.Player = player
    BAM.Vehicle = vehicle
    BAM.InaccessibleParts = {}
    BAM:workOnNextPart(player, vehicle)
end


function BAM:StopMechanicsTraining(player, msgOverride, r, g, b)
    BAM.IsCurrentlyTraining = false
    BAM.Vehicle = nil
    BAM.DelayTimer = 0
    BAM.LastWorkedPart = nil
    BAM.LastWorkedActionType = nil
    BAM.InaccessibleParts = {}
    setGameSpeed(1)
    getGameTime():setMultiplier(1)

    local msg = msgOverride or getText("UI_BAM_message.car_completed")
    r = r or 0
    g = g or 255
    b = b or 0

    -- Display a ingame notification to inform the player that training has finished
    if player then
        HaloTextHelper.addText(player, msg, "[br/]", r, g, b)
    end

    print("Finished mechanics training!")
    print("=================================")
end


function BAM:workOnNextPart(player, vehicle)
    -- First check if we are too far away from the vehicle
    local distanceToCar = player:DistToSquared(vehicle)
    --print("Player distance to vehicle squared: " .. distanceToCar)
    if distanceToCar > 10 then
        print("Player is too far from vehicle (" .. tostring(distanceToCar) .. " tiles). Stopping training.")
        BAM:StopMechanicsTraining(nil)
        return
    end

    -- Gather info about next parts to install/uninstall
    print("Deciding on next part...")
    local partUninstall = BAM.GetNextUninstallablePart(player, vehicle)
    local partInstall, itemInstall = BAM.GetNextInstallablePartAndItem(player, vehicle)
    print("Next part to uninstall: " .. (partUninstall and partUninstall:getId() or "None"))
    print("Next part to install: " .. (partInstall and partInstall:getId() or "None"))

    -- If no parts to install or uninstall, stop training
    if partUninstall == nil and partInstall == nil then
        print("No more parts to work on.")
        BAM:StopMechanicsTraining(player)
        return
    end

    -- First check for parts that require other parts to be uninstalled first
    if partInstall and partUninstall then
        -- If we can install a tire, first check if we can uninstall brake/suspension
        if string.find(partInstall:getId(), "Tire") then
            if string.find(partUninstall:getId(), "Brake") or string.find(partUninstall:getId(), "Suspension") then
                BAM:UninstallPart(player, partUninstall)
                return
            end
        end

        -- If we can install a window or the rear windshield, first check if we can uninstall door
        if string.find(partInstall:getId(), "Window") or string.find(partInstall:getId(), "WindshieldRear") then
            if string.find(partUninstall:getId(), "Door") then
                BAM:UninstallPart(player, partUninstall)
                return
            end
        end
    end

    -- If we can install any part, do it. We always prioritize installation over uninstallation (except for brakes/suspension above)
    if partInstall and itemInstall then
        BAM:InstallPart(player, partInstall, itemInstall)
        return
    end

    -- Otherwise, uninstall the next part
    if partUninstall then
        BAM:UninstallPart(player, partUninstall)
        return
    end

    -- If we reach here, something went wrong. Probably because we have a part to install but no item for it.
    print("Error: Unable to determine next part to work on.")
    BAM:StopMechanicsTraining(player)
end


function BAM:InstallPart(player, part, item)
    print("-> Installing item " .. item:getName() .. " into part: " .. part:getId())
    BAM.LastWorkedPart = part
    BAM.LastWorkedActionType = 2
    BAM.DropBrokenItems(player)  -- Drop broken items before installing
    ISVehiclePartMenu.onInstallPart(player, part, item)  -- Start timed task
end


function BAM:UninstallPart(player, part)
    print("-> Uninstalling part: " .. part:getId())
    BAM.LastWorkedPart = part
    BAM.LastWorkedActionType = 1
    BAM.DropBrokenItems(player)  -- Drop broken items before uninstalling
    ISVehiclePartMenu.onUninstallPart(player, part)  -- Start timed task
end

