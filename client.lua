local cam = nil
local freeCamActive = false
local initialPos = nil
local initialRot = nil
local currentFOV = nil
local rollAngle = 0.0
local helpVisible = false
local activationStartTime = nil
local initialOffset = nil

local function saveHelpVisibility()
    SetResourceKvp("freecam_help_visible", tostring(helpVisible))
end

local function loadHelpVisibility()
    local savedValue = GetResourceKvpString("freecam_help_visible")
    if savedValue ~= nil then
        helpVisible = savedValue == "true"
    else
        helpVisible = false
    end
end

local function calculateCameraPosition()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)

    local headingRad = math.rad(playerHeading)
    local forwardOffset = vector3(-math.sin(headingRad), math.cos(headingRad), 0.5)

    return playerCoords + forwardOffset
end

local function toggleFreeCam()
    local playerPed = PlayerPedId()

    if not freeCamActive then
        freeCamActive = true

        currentFOV = GetGameplayCamFov()

        local playerCoords = GetEntityCoords(playerPed)
        -- Kamera tekrar açıldığında, önceki offset ve rotasyon varsa kullan
        if initialOffset and initialRot then
            local camStartPos = playerCoords + initialOffset
            initialPos = camStartPos
            cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
            SetCamCoord(cam, camStartPos.x, camStartPos.y, camStartPos.z)
            SetCamRot(cam, initialRot.x, initialRot.y, initialRot.z)
            SetCamFov(cam, currentFOV)
        else
            local camStartPos = initialPos or calculateCameraPosition()
            initialPos = camStartPos
            cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
            SetCamCoord(cam, camStartPos.x, camStartPos.y, camStartPos.z)
            SetCamRot(cam, 180.0, 0.0, GetEntityHeading(playerPed))
            SetCamFov(cam, currentFOV)
        end

        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)

        SetEntityVisible(playerPed, true)
        SetEntityAlpha(playerPed, 255, false)

        if helpVisible then
            SendNUIMessage({ action = "show" })
        else
            SendNUIMessage({ action = "hide" })
        end

    else
        freeCamActive = false

        if cam then
            local camPos = GetCamCoord(cam)
            local playerCoords = GetEntityCoords(playerPed)
            initialOffset = camPos - playerCoords
            initialRot = GetCamRot(cam, 2)
            currentFOV = GetCamFov(cam)
            initialPos = camPos
        end

        DestroyCam(cam, false)
        RenderScriptCams(false, false, 0, true, true)
        cam = nil

        SendNUIMessage({ action = "hide" })
    end
end

local function GetCamForwardVector(cam)
    local rot = GetCamRot(cam, 2)
    local x = -math.sin(math.rad(rot.z)) * math.abs(math.cos(math.rad(rot.x)))
    local y = math.cos(math.rad(rot.z)) * math.abs(math.cos(math.rad(rot.x)))
    local z = math.sin(math.rad(rot.x))
    return vector3(x, y, z)
end

local function GetCamRightVector(cam)
    local forwardVector = GetCamForwardVector(cam)
    return vector3(forwardVector.y, -forwardVector.x, 0.0)
end

local function disablePlayerControls()
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 22, true)
    DisableControlAction(0, 23, true)
    DisableControlAction(0, 75, true)
    DisableControlAction(0, 45, true)
    DisableControlAction(0, 44, true)
end

local function notification(msg)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

RegisterCommand(Config.ActivationCommand, function()
    toggleFreeCam()
end, false)

Citizen.CreateThread(function()
    loadHelpVisibility()

    while true do
        Citizen.Wait(0)

        -- V tuşuna basılı tutulduğunda aç/kapat
        if IsControlPressed(0, Config.ActivationKey) then
            if not activationStartTime then
                activationStartTime = GetGameTimer()
            elseif GetGameTimer() - activationStartTime >= Config.ActivationHoldTime then
                toggleFreeCam()
                activationStartTime = nil
            end
        else
            activationStartTime = nil
        end

        -- Yardım kutusunu aç/kapat H tuşu ile
        if freeCamActive and IsControlJustPressed(0, Config.HelpToggleKey) then
            helpVisible = not helpVisible
            saveHelpVisibility()
            SendNUIMessage({ action = helpVisible and "show" or "hide" })
        end

        if freeCamActive then
            if not initialPos then
                initialPos = GetCamCoord(cam)
            end

            disablePlayerControls()

            local camPos = GetCamCoord(cam)
            local camRot = GetCamRot(cam, 2)
            local moveSpeed = Config.MoveSpeed

            if IsControlPressed(0, 21) then -- SHIFT
                moveSpeed = moveSpeed * Config.SpeedMultiplier
            end

            if IsControlPressed(0, 32) then -- W
                camPos = camPos + (GetCamForwardVector(cam) * moveSpeed)
            end
            if IsControlPressed(0, 33) then -- S
                camPos = camPos - (GetCamForwardVector(cam) * moveSpeed)
            end
            if IsControlPressed(0, 34) then -- A
                camPos = camPos - (GetCamRightVector(cam) * moveSpeed)
            end
            if IsControlPressed(0, 35) then -- D
                camPos = camPos + (GetCamRightVector(cam) * moveSpeed)
            end
            if IsControlPressed(0, 52) then -- Q yukarı
                camPos = camPos + vector3(0.0, 0.0, moveSpeed)
            end
            if IsControlPressed(0, 38) then -- E aşağı
                camPos = camPos - vector3(0.0, 0.0, moveSpeed)
            end

            SetCamCoord(cam, camPos)

            local xMagnitude = GetControlNormal(0, 1) * 8.0
            local yMagnitude = GetControlNormal(0, 2) * 8.0

            -- Kamerayı roll ile döndürme, sağ/sol ok
            if IsControlPressed(0, 174) then -- Sol ok
                rollAngle = rollAngle - 1.0
            end
            if IsControlPressed(0, 175) then -- Sağ ok
                rollAngle = rollAngle + 1.0
            end

            camRot = vector3(camRot.x - yMagnitude, camRot.y, camRot.z - xMagnitude)
            SetCamRot(cam, camRot.x, rollAngle, camRot.z, 2)

            -- Scroll zoom (mouse tekerleği)
            local scrollUp = IsDisabledControlJustPressed(0, 15)
            local scrollDown = IsDisabledControlJustPressed(0, 14)
            if scrollUp then
                currentFOV = math.max(30.0, currentFOV - 5.0)
                SetCamFov(cam, currentFOV)
            elseif scrollDown then
                currentFOV = math.min(120.0, currentFOV + 5.0)
                SetCamFov(cam, currentFOV)
            end

            local distance = #(camPos - initialPos)
            if distance > Config.DeactivateDistance then
                toggleFreeCam()
                initialPos = nil
                notification('Freecam belirlenen mesafeden uzaklaşıldığı için ~r~kapatıldı.')
            end
        end
    end
end)
