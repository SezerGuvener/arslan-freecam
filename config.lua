Config = {}

-- Kameranın hareket edebileceği aralığı tanımlama
Config.CameraRange = 100.0 -- Kameranın hareket edebileceği maksimum mesafeyi ayarlamak için bu değeri ayarlayın

-- Serbest kamera modu için yapılandırma ayarları
Config.ActivationCommand = "freecam" -- Komut ile aktif etme
Config.ActivationKey = 236 -- 'v' Free Kamerayı Etkinleştirir
Config.ActivationHoldTime = 1000 -- Milisaniye cinsinden 1 saniye
Config.HelpToggleKey = 104 -- 'h' Free Kamera için yardım kutusunu açıp kapatır
Config.MoveSpeed = 0.1 -- Varsayılan hız
Config.SpeedMultiplier = 2.0 -- Shift ile artırılmış hız