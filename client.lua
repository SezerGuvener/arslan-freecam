local currentFilterIndex = 1
local cam = nil
local freeCamActive = false
local initialPos = nil
local currentFOV = 90.0 -- Varsayılan FOV
local rollAngle = 0.0 -- İlk dönürme açısı
local activationStartTime = nil -- V tuşuna basma süresi
local helpVisible = true -- Yardım kutusu görünürlüğü
local deactivateDistance = 15.0 -- Freecam'in kapanacağı mesafe

-- Yardım kutusu görünürlüğünü kaydetme
local function saveHelpVisibility()
    SetResourceKvp("freecam_help_visible", tostring(helpVisible))
end

local function loadHelpVisibility()
    local savedValue = GetResourceKvpString("freecam_help_visible")
    if savedValue ~= nil then
        helpVisible = savedValue == "true"
    end
end

-- Serbest kamera modunu değiştirme fonksiyonu
local function toggleFreeCam()
    if not freeCamActive then
        -- Freecam'i Etkinleştir
        freeCamActive = true
        local playerPed = PlayerPedId()
        initialPos = GetEntityCoords(playerPed)

        -- Yeni bir kamera oluştur
        cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)

        -- Kamera özelliklerini ayarla
        SetCamCoord(cam, initialPos.x, initialPos.y, initialPos.z + 1.0)
        SetCamRot(cam, 0.0, 0.0, 0.0)
        SetCamFov(cam, currentFOV)

        -- Kamerayı etkin olarak ayarla
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)

        -- Görünürse yardım kutusunu göster
        if helpVisible then
            SendNUIMessage({ action = "show" })
        end
    else
        -- Free Cam'i devre dışı bırak
        freeCamActive = false

        -- Kamerayı yok et
        DestroyCam(cam, false)
        RenderScriptCams(false, false, 0, true, true)
        cam = nil

        -- Yardım kutusunu gizle
        SendNUIMessage({ action = "hide" })
    end
end

-- Kameranın dönüşünden ileri vektörü hesaplayan fonksiyon
local function GetCamForwardVector(cam)
    local rot = GetCamRot(cam, 2)
    local x = -math.sin(math.rad(rot.z)) * math.abs(math.cos(math.rad(rot.x)))
    local y = math.cos(math.rad(rot.z)) * math.abs(math.cos(math.rad(rot.x)))
    local z = math.sin(math.rad(rot.x))
    return vector3(x, y, z)
end

-- Kameranın dönüşünden sağ vektörü hesaplayan fonksiyon
local function GetCamRightVector(cam)
    local forwardVector = GetCamForwardVector(cam)
    return vector3(-forwardVector.y, forwardVector.x, 0.0)
end

-- Belirli oyuncu kontrollerini devre dışı bırakma fonksiyonu
local function disablePlayerControls()
    DisableControlAction(0, 30, true) -- D (Hareket)
    DisableControlAction(0, 31, true) -- S (Hareket)
    DisableControlAction(0, 140, true) -- R (Yumruk)
    DisableControlAction(0, 141, true) -- Q (Tekme)
    DisableControlAction(0, 142, true) -- Mouse Sol Tık (Yumruk)
    DisableControlAction(0, 24, true) -- Mouse Sol Tık (Yumruk/Ateş)
    DisableControlAction(0, 25, true) -- Mouse Sağ Tık (Nişan Alma)
    DisableControlAction(0, 22, true) -- Space (Zıplama)
    DisableControlAction(0, 23, true) -- F (Araç Bin)
    DisableControlAction(0, 75, true) -- F (Araç İn)
    DisableControlAction(0, 45, true) -- R (Reload)
    DisableControlAction(0, 44, true) -- Q (Cover)
end

-- Etkinleştirme komutunu
RegisterCommand(Config.ActivationCommand, function()
    toggleFreeCam()
end, false)

-- V tuşu etkinleştirme mantığını ve serbest kamera hareketini işlemek
Citizen.CreateThread(function()
    loadHelpVisibility()

    while true do
        Citizen.Wait(0)

        -- Bekleme süresi ile V tuşu aktivasyonunu
        if IsControlPressed(1, Config.ActivationKey) then
            if not activationStartTime then
                activationStartTime = GetGameTimer()
            elseif GetGameTimer() - activationStartTime >= Config.ActivationHoldTime then
                toggleFreeCam()
                activationStartTime = nil
            end
        else
            activationStartTime = nil
        end

        -- Yardım kutusunun görünürlüğünü değiştirmek için H tuşunu kullanın
        if freeCamActive and IsControlJustPressed(1, Config.HelpToggleKey) then
            helpVisible = not helpVisible
            saveHelpVisibility()
            SendNUIMessage({ action = helpVisible and "show" or "hide" })
        end

        if freeCamActive then
            -- Freecam etkinleştirildiğinde başlangıç pozisyonunu kaydet
            if not initialPos then
                initialPos = GetCamCoord(cam)
            end
        
            -- Oyuncu kontrollerini devre dışı bırak
            disablePlayerControls()
        
            -- Kameranın geçerli konumunu ve dönüşünü alır
            local camPos = GetCamCoord(cam)
            local camRot = GetCamRot(cam, 2)
            local moveSpeed = Config.MoveSpeed
        
            -- Hız çarpanı kontrolü (Shift tuşu)
            if IsControlPressed(1, 21) then -- Shift tuşu
                moveSpeed = moveSpeed * Config.SpeedMultiplier
            end
        
            -- Kamera hareket kontrolleri
            if IsControlPressed(1, 32) then -- W (ileri hareket)
                camPos = camPos + (GetCamForwardVector(cam) * moveSpeed)
            end
            if IsControlPressed(1, 33) then -- S (geri hareket)
                camPos = camPos - (GetCamForwardVector(cam) * moveSpeed)
            end
            if IsControlPressed(1, 34) then -- A (sola hareket)
                camPos = camPos + (GetCamRightVector(cam) * moveSpeed)
            end
            if IsControlPressed(1, 35) then -- D (sağa hareket)
                camPos = camPos - (GetCamRightVector(cam) * moveSpeed)
            end
            if IsControlPressed(1, 52) then -- Q (yukarı hareket)
                camPos = camPos + vector3(0.0, 0.0, moveSpeed)
            end
            if IsControlPressed(1, 38) then -- E (aşağı hareket)
                camPos = camPos - vector3(0.0, 0.0, moveSpeed)
            end
        
            -- Kamera konumunu ayarla
            SetCamCoord(cam, camPos)
        
            -- Kamera döndürme kontrolleri (fare kontrolleri)
            local xMagnitude = GetControlNormal(0, 1) * 8.0 -- Mouse X
            local yMagnitude = GetControlNormal(0, 2) * 8.0 -- Mouse Y

            if IsControlPressed(1, 174) then
                rollAngle = rollAngle - 1.0
            end
            if IsControlPressed(1, 175) then
                rollAngle = rollAngle + 1.0
            end

            camRot = vector3(camRot.x - yMagnitude, camRot.y, camRot.z - xMagnitude)
            SetCamRot(cam, camRot.x, rollAngle, camRot.z, 2)

            -- Yakınlaştırma kontrolleri (FOV ayarı)
            if IsControlPressed(1, 15) then -- Yakınlaştırmak için yukarı kaydırma veya Page Up tuşu
                currentFOV = math.max(30.0, currentFOV - 1.0) -- Minimum 30 FOV
                SetCamFov(cam, currentFOV)
            end
            if IsControlPressed(1, 14) then -- Uzaklaştırmak için aşağı kaydırma veya Page Down tuşu
                currentFOV = math.min(120.0, currentFOV + 1.0) -- Maksimum 120 FOV
                SetCamFov(cam, currentFOV)
            end
            
            -- Kamera başlangıç pozisyonundan uzaklık kontrolü
            local distance = #(camPos - initialPos)
            if distance > deactivateDistance then
                toggleFreeCam() -- Freecam'i kapat
                initialPos = nil -- Başlangıç pozisyonunu sıfırla
                print("Freecam, belirlenen mesafeden uzaklaşıldığı için kapatıldı.")
            end
        end
    end
end)