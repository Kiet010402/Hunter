--// Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Check Game ID
if game.GameId ~= 7671049560 then
    warn("Script only runs on Game ID: 7671049560. Current Game ID: " .. tostring(game.GameId))
    return
end

-- RF mua đồ Proximity (Maria shop)
local ProximityPurchaseRF = ReplicatedStorage
    :WaitForChild("Shared")
    :WaitForChild("Packages")
    :WaitForChild("Knit")
    :WaitForChild("Services")
    :WaitForChild("ProximityService")
    :WaitForChild("RF")
    :WaitForChild("Purchase")

--// Load UI Library (MacLib)
local MacLib = nil
local success, err = pcall(function()
    MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()
end)

if not success or not MacLib then
    warn("Error loading UI Library (MacLib): " .. tostring(err))
    return
end

--// Config System (tương tự UI.lua, rút gọn cho TheForge)
local ConfigSystem = {}
ConfigSystem.FileName = "HTHubTheForgeConfig_" .. Players.LocalPlayer.Name .. ".json"
ConfigSystem.DefaultConfig = {
    SelectedRockType = nil,
    AutoMineEnabled = false,
    SelectedEnemyType = nil,
    SelectedDistance = 6,
    AutoFarmEnemyEnabled = false,
    SelectedMineDistance = 6,
    SelectedPotionName = nil,
    AutoBuyAndUsePotionEnabled = false,
    SelectedItemName = nil,
    AutoSellItemEnabled = false,
    AntiAFKEnabled = true,
}
ConfigSystem.CurrentConfig = {}

ConfigSystem.SaveConfig = function()
    local ok, saveErr = pcall(function()
        writefile(ConfigSystem.FileName, HttpService:JSONEncode(ConfigSystem.CurrentConfig))
    end)
    if not ok then
        warn("Failed to save config:", saveErr)
    end
end

ConfigSystem.LoadConfig = function()
    local ok, content = pcall(function()
        if isfile and isfile(ConfigSystem.FileName) then
            return readfile(ConfigSystem.FileName)
        end
        return nil
    end)

    if ok and content then
        local data = HttpService:JSONDecode(content)
        ConfigSystem.CurrentConfig = data
    else
        ConfigSystem.CurrentConfig = table.clone(ConfigSystem.DefaultConfig)
        ConfigSystem.SaveConfig()
    end
end

ConfigSystem.LoadConfig()

--// UI Window
local playerName = Players.LocalPlayer.Name

local Window = MacLib:Window({
    Title = "HT HUB | The Forge",
    Subtitle = "Hello, " .. playerName,
    Size = UDim2.fromOffset(720, 500),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.LeftAlt,
    AcrylicBlur = true,
})

local function notify(title, desc, duration)
    if Window and Window.Notify then
        Window:Notify({
            Title = title or Window.Settings.Title,
            Description = desc or "",
            Lifetime = duration or 4
        })
    else
        print("[Notify]", tostring(title), tostring(desc))
    end
end

MacLib:SetFolder("HTHubTheForge")

--// Tabs
local tabGroup = Window:TabGroup()
local tabs = {
    Farm = tabGroup:Tab({ Name = "Farm", Image = "rbxassetid://10734923549" }),
    Shop = tabGroup:Tab({ Name = "Shop", Image = "rbxassetid://10734952273" }),
    Teleport = tabGroup:Tab({ Name = "Teleport", Image = "rbxassetid://10747381992" }),
    Settings = tabGroup:Tab({ Name = "Settings", Image = "rbxassetid://10734950309" }),
}

--// Mine state
local autoMineEnabled = ConfigSystem.CurrentConfig.AutoMineEnabled
if type(autoMineEnabled) ~= "boolean" then
    autoMineEnabled = ConfigSystem.DefaultConfig.AutoMineEnabled
end

local selectedRockType = ConfigSystem.CurrentConfig.SelectedRockType
if type(selectedRockType) == "string" then
    selectedRockType = { selectedRockType }
elseif type(selectedRockType) ~= "table" then
    selectedRockType = {}
end

local selectedMineDistance = tonumber(ConfigSystem.CurrentConfig.SelectedMineDistance) or
    ConfigSystem.DefaultConfig.SelectedMineDistance
if selectedMineDistance < 1 or selectedMineDistance > 10 then
    selectedMineDistance = ConfigSystem.DefaultConfig.SelectedMineDistance
end
local rockTypes = {}
local rockTypeDropdown = nil

-- Blacklist để lưu các rock đang bị conflict (có người khác đang đào)
-- Format: { [rockPart] = timestamp }
local conflictedRocks = {}
local CONFLICT_COOLDOWN = 10 -- Thời gian chờ trước khi thử lại rock bị conflict (giây)

-- Trạng thái bay trên trời cho Auto Mine
local isMiningInSky = false           -- Flag để biết đang bay trên trời hay đang đào
local mineSkyPositionConnection = nil -- Connection để giữ Y cố định khi bay trên trời

--// Enemy state
local selectedEnemyType = ConfigSystem.CurrentConfig.SelectedEnemyType
if type(selectedEnemyType) ~= "table" then
    selectedEnemyType = {}
end
local selectedDistance = tonumber(ConfigSystem.CurrentConfig.SelectedDistance) or
    ConfigSystem.DefaultConfig.SelectedDistance
-- Giới hạn khoảng cách trong khoảng 1 - 10
if selectedDistance < 1 or selectedDistance > 10 then
    selectedDistance = ConfigSystem.DefaultConfig.SelectedDistance
end
local autoFarmEnemyEnabled = ConfigSystem.CurrentConfig.AutoFarmEnemyEnabled
if type(autoFarmEnemyEnabled) ~= "boolean" then
    autoFarmEnemyEnabled = ConfigSystem.DefaultConfig.AutoFarmEnemyEnabled
end
local antiAFKEnabled = ConfigSystem.CurrentConfig.AntiAFKEnabled
if type(antiAFKEnabled) ~= "boolean" then
    antiAFKEnabled = ConfigSystem.DefaultConfig.AntiAFKEnabled
end
local enemyTypes = {}
local enemyTypeDropdown = nil

-- Độ cao trên trời để bay (Y coordinate)
local SKY_HEIGHT = 300
local isFlyingInSky = false       -- Flag để biết đang bay trên trời hay đang đánh quái
local skyPositionConnection = nil -- Connection để giữ Y cố định khi bay trên trời

--// Shop Potion state
local potionNames = {}
local potionDropdown = nil
local selectedPotionName = ConfigSystem.CurrentConfig.SelectedPotionName
if selectedPotionName ~= nil and type(selectedPotionName) ~= "string" then
    selectedPotionName = nil
end
local autoBuyAndUsePotionEnabled = ConfigSystem.CurrentConfig.AutoBuyAndUsePotionEnabled
if type(autoBuyAndUsePotionEnabled) ~= "boolean" then
    autoBuyAndUsePotionEnabled = ConfigSystem.DefaultConfig.AutoBuyAndUsePotionEnabled
end
local isAutoBuyAndUseActive = false -- Flag ưu tiên Auto Buy And Use (block Auto Mine & Auto Farm Enemy)

-- Trạng thái bay trên trời cho Auto Buy And Use
local isBuyingInSky = false          -- Flag để biết đang bay trên trời hay đang mua
local buySkyPositionConnection = nil -- Connection để giữ Y cố định khi bay trên trời

--// Sell Item state
local oreNames = {}
local selectedItemName = ConfigSystem.CurrentConfig.SelectedItemName
if type(selectedItemName) == "string" then
    -- Convert string cũ thành array
    selectedItemName = { selectedItemName }
elseif type(selectedItemName) ~= "table" then
    selectedItemName = {}
end
local autoSellItemEnabled = ConfigSystem.CurrentConfig.AutoSellItemEnabled
if type(autoSellItemEnabled) ~= "boolean" then
    autoSellItemEnabled = ConfigSystem.DefaultConfig.AutoSellItemEnabled
end
local greedyCeyModel = nil      -- Lưu reference đến Greedy Cey model
local hasOpenedDialogue = false -- Flag để chỉ mở dialogue 1 lần duy nhất

--// Teleport state
local npcNames = {}
local selectedNPCName = nil
local shopNames = {}
local selectedShopName = nil

--// Sections
local sections = {
    Farm = tabs.Farm:Section({ Side = "Left" }),
    Enemy = tabs.Farm:Section({ Side = "Right" }),
    ShopPotion = tabs.Shop:Section({ Side = "Left" }),
    SellItem = tabs.Shop:Section({ Side = "Right" }),
    TeleportNPC = tabs.Teleport:Section({ Side = "Left" }),
    TeleportShop = tabs.Teleport:Section({ Side = "Right" }),
    SettingsInfo = tabs.Settings:Section({ Side = "Left" }),
    SettingsMisc = tabs.Settings:Section({ Side = "Right" }),
}

--// FARM TAB
sections.Farm:Header({ Name = "Mine" })

local function getDefaultOption(list, target)
    if not list or #list == 0 then
        return nil
    end
    if not target then
        return list[1]
    end
    for _, name in ipairs(list) do
        if name == target then
            return name
        end
    end
    return list[1]
end

local function scanRockTypes()
    rockTypes = {}
    local seen = {}

    -- Chỉ dùng ReplicatedStorage.Assets.Rocks để scan tên, Auto Mine vẫn dùng workspace như cũ
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        return rockTypes
    end

    local rocksRoot = assetsFolder:FindFirstChild("Rocks")
    if not rocksRoot then
        return rockTypes
    end

    for _, inst in ipairs(rocksRoot:GetDescendants()) do
        if inst:IsA("Model") then
            local name = inst.Name
            if typeof(name) == "string" and name ~= "" and not name:match("^%d+$") then
                if not seen[name] then
                    seen[name] = true
                    table.insert(rockTypes, name)
                end
            end
        end
    end

    table.sort(rockTypes)

    return rockTypes
end

local function getRockPartsByType(typeName)
    local result = {}

    if not typeName or typeName == "" then
        return result
    end

    local rocksRoot = workspace:FindFirstChild("Rocks")
    if not rocksRoot then
        return result
    end

    for _, inst in ipairs(rocksRoot:GetDescendants()) do
        if inst:IsA("BasePart") then
            local model = inst:FindFirstAncestorWhichIsA("Model")
            if model and model.Name == typeName then
                table.insert(result, inst)
            end
        end
    end

    return result
end

local function getClosestRockPartByType(typeName)
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return nil
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return nil
    end

    local parts = getRockPartsByType(typeName)
    local closestPart = nil
    local closestDist = math.huge

    for _, part in ipairs(parts) do
        if part and part.Parent then
            local dist = (hrp.Position - part.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestPart = part
            end
        end
    end

    return closestPart
end

-- Lấy viên đá gần nhất trong danh sách nhiều loại đá được chọn
local function getClosestRockPartByTypes(typeList)
    if not typeList or #typeList == 0 then
        return nil
    end

    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return nil
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return nil
    end

    -- Nếu typeList chứa "All", dùng tất cả rockTypes
    local effectiveTypes = typeList
    local hasAll = false
    for _, typeName in ipairs(typeList) do
        if typeName == "All" then
            hasAll = true
            break
        end
    end
    if hasAll then
        effectiveTypes = rockTypes
    end

    local closestPart = nil
    local closestDist = math.huge
    local currentTime = tick()

    for _, typeName in ipairs(effectiveTypes) do
        local parts = getRockPartsByType(typeName)
        for _, part in ipairs(parts) do
            if part and part.Parent then
                -- Skip rock nếu đang trong blacklist và chưa hết cooldown
                local conflictTime = conflictedRocks[part]
                if conflictTime then
                    if (currentTime - conflictTime) < CONFLICT_COOLDOWN then
                        -- Rock vẫn đang trong cooldown, skip
                        -- Không làm gì, tiếp tục vòng lặp
                    else
                        -- Hết cooldown, xóa khỏi blacklist
                        conflictedRocks[part] = nil
                    end
                end

                -- Chỉ tính rock nếu không trong cooldown
                if not conflictTime or (currentTime - conflictTime) >= CONFLICT_COOLDOWN then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestPart = part
                    end
                end
            end
        end
    end

    return closestPart
end

-- Hàm check notification "Someone else is already mining this rock."
local function checkMiningConflictNotification()
    local player = Players.LocalPlayer
    if not player then
        return false
    end

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then
        return false
    end

    local notifications = playerGui:FindFirstChild("Notifications")
    if not notifications then
        return false
    end

    local screen = notifications:FindFirstChild("Screen")
    if not screen then
        return false
    end

    local notificationsFrame = screen:FindFirstChild("NotificationsFrame")
    if not notificationsFrame then
        return false
    end

    -- Check tất cả TextFrame trong NotificationsFrame
    for _, child in ipairs(notificationsFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name == "TextFrame" then
            -- Tìm TextLabel trong TextFrame (có thể ở cấp con trực tiếp hoặc sâu hơn)
            local textLabel = child:FindFirstChild("TextLabel", true)
            if textLabel and textLabel:IsA("TextLabel") then
                local text = textLabel.Text or ""
                -- Check nếu text chứa thông báo conflict (case-insensitive)
                if text:lower():find("someone else is already mining this rock.", 1, true) then
                    return true
                end
            end
        end
    end

    return false
end

-- Hàm bay lên trời cho Auto Mine
local function flyToSkyForMine()
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return false
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end

    -- Hủy connection cũ nếu có
    if mineSkyPositionConnection then
        mineSkyPositionConnection:Disconnect()
        mineSkyPositionConnection = nil
    end

    -- Tele lên trời ngay lập tức (giữ X và Z, chỉ thay đổi Y)
    local currentPos = hrp.Position
    local skyPos = Vector3.new(currentPos.X, SKY_HEIGHT, currentPos.Z)
    hrp.CFrame = CFrame.new(skyPos)
    isMiningInSky = true

    -- Tạo BodyVelocity để giữ Y cố định
    local bodyVelocity = hrp:FindFirstChild("BodyVelocity")
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Parent = hrp
    end

    -- Giữ Y cố định bằng Heartbeat connection
    local trackedCharacter = character
    mineSkyPositionConnection = RunService.Heartbeat:Connect(function()
        if not autoMineEnabled
            or not isMiningInSky
            or Players.LocalPlayer.Character ~= trackedCharacter
            or not hrp
            or not hrp.Parent then
            if mineSkyPositionConnection then
                mineSkyPositionConnection:Disconnect()
                mineSkyPositionConnection = nil
            end
            return
        end

        -- Giữ Y cố định ở SKY_HEIGHT, chỉ cho phép di chuyển X và Z
        local currentPos = hrp.Position
        local fixedPos = Vector3.new(currentPos.X, SKY_HEIGHT, currentPos.Z)
        hrp.CFrame = CFrame.new(fixedPos, fixedPos + hrp.CFrame.LookVector * Vector3.new(1, 0, 1))
        if bodyVelocity then
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
    end)

    return true
end

-- Hàm di chuyển trên không trung đến rock (giữ Y cao, chỉ di chuyển X và Z)
local function tweenToMineTarget(targetPart)
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return false
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetPart or not targetPart.Parent then
        return false
    end

    -- Vị trí trên không trung phía trên rock (giữ Y = SKY_HEIGHT, chỉ di chuyển X và Z)
    local rockPos = targetPart.Position
    local targetPos = Vector3.new(rockPos.X, SKY_HEIGHT, rockPos.Z)
    local currentPos = hrp.Position
    local distanceToTarget = (Vector3.new(currentPos.X, 0, currentPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z))
    .Magnitude

    -- Tính thời gian tween dựa trên khoảng cách XZ (chậm hơn vì chỉ di chuyển X và Z, không bị anti-tp)
    -- Tốc độ: khoảng 10 studs/s để an toàn
    local time = math.clamp(distanceToTarget / 10, 1, 8)

    -- Hướng về rock (nhưng vẫn ở trên trời)
    local lookAtCFrame = CFrame.new(targetPos, targetPart.Position)

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = lookAtCFrame }
    )

    tween:Play()
    tween.Completed:Wait()

    return true
end

local function swingPickaxeUntilMinedType(targetPart, typeName)
    if not targetPart or not typeName or typeName == "" then
        return
    end

    local model = targetPart:FindFirstAncestorWhichIsA("Model")
    if not model or model.Name ~= typeName then
        return
    end

    local args = { "Pickaxe" }
    local toolRF = game:GetService("ReplicatedStorage")
        :WaitForChild("Shared")
        :WaitForChild("Packages")
        :WaitForChild("Knit")
        :WaitForChild("Services")
        :WaitForChild("ToolService")
        :WaitForChild("RF")
        :WaitForChild("ToolActivated")

    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end

    -- Lưu lại character hiện tại để phát hiện respawn
    local trackedCharacter = character

    -- Hủy connection giữ Y trên trời
    if mineSkyPositionConnection then
        mineSkyPositionConnection:Disconnect()
        mineSkyPositionConnection = nil
    end

    -- Tele xuống dưới rock ngay lập tức (giữ X và Z, chỉ thay đổi Y)
    local downOffset = -(selectedMineDistance or 3)
    local targetPos = targetPart.Position + Vector3.new(0, downOffset, 0)
    local lookAtPos = targetPart.Position + Vector3.new(0, 5, 0) -- Nhìn chếch lên trên rock
    hrp.CFrame = CFrame.new(targetPos, lookAtPos)
    isMiningInSky = false                                        -- Đánh dấu đã xuống đào

    -- Tắt xoay tự do để hạn chế game tự chỉnh hướng nhìn
    local originalAutoRotate = hrp.AssemblyAngularVelocity
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

    -- Giữ nhân vật cố định dưới viên đá (không rơi)
    local bodyVelocity = hrp:FindFirstChild("BodyVelocity")
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = hrp
    end

    -- Khóa vị trí + hướng nhìn (giống Enemy, nhưng ở dưới nhìn lên)
    local keepPositionConnection
    keepPositionConnection = RunService.Heartbeat:Connect(function()
        if not autoMineEnabled
            or not model
            or not model.Parent
            or Players.LocalPlayer.Character ~= trackedCharacter
            or not hrp
            or not hrp.Parent
            or isAutoBuyAndUseActive then
            if keepPositionConnection then
                keepPositionConnection:Disconnect()
            end
            return
        end

        local rockPart = targetPart
        if rockPart and rockPart.Parent then
            local downOffset = -(selectedMineDistance or 3)
            local targetPos = rockPart.Position + Vector3.new(0, downOffset, 0)
            local lookAtPos = rockPart.Position + Vector3.new(0, 5, 0)
            hrp.CFrame = CFrame.new(targetPos, lookAtPos)
            if bodyVelocity then
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end
    end)

    while autoMineEnabled do
        -- Nếu nhân vật respawn, viên đá bị phá hoặc Auto Buy & Use chạy thì dừng
        if Players.LocalPlayer.Character ~= trackedCharacter or not hrp or not hrp.Parent or isAutoBuyAndUseActive then
            break
        end
        if not model or not model.Parent then
            break
        end

        -- Check notification conflict - nếu có người khác đang mine thì chuyển rock khác ngay
        if checkMiningConflictNotification() then
            -- Thêm rock vào blacklist để tránh chọn lại
            if targetPart and targetPart.Parent then
                conflictedRocks[targetPart] = tick()
            end
            break
        end

        pcall(function()
            toolRF:InvokeServer(unpack(args))
        end)
        task.wait(0.15)
    end

    -- Dọn dẹp
    if keepPositionConnection then
        keepPositionConnection:Disconnect()
    end
    if bodyVelocity and bodyVelocity.Parent then
        bodyVelocity:Destroy()
    end
    if hrp and hrp.Parent then
        hrp.AssemblyAngularVelocity = originalAutoRotate
    end

    -- Sau khi mine xong, bay lên trời lại ngay lập tức
    if autoMineEnabled then
        flyToSkyForMine()
    end
end

rockTypes = scanRockTypes()
-- Thêm "All" vào đầu danh sách
local rockOptions = { "All" }
for _, rockType in ipairs(rockTypes) do
    table.insert(rockOptions, rockType)
end

rockTypeDropdown = sections.Farm:Dropdown({
    Name = "Select Rock",
    Multi = true,
    Required = false,
    Options = rockOptions,
    Default = selectedRockType,
    Callback = function(value)
        if typeof(value) == "table" then
            selectedRockType = {}
            local hasAll = false
            for name, state in pairs(value) do
                if state then
                    if name == "All" then
                        hasAll = true
                    else
                        table.insert(selectedRockType, name)
                    end
                end
            end

            -- Nếu chọn "All", chọn tất cả các loại đá
            if hasAll then
                selectedRockType = {}
                for _, rockType in ipairs(rockTypes) do
                    table.insert(selectedRockType, rockType)
                end
                -- Cập nhật lại dropdown để hiển thị tất cả (bỏ "All")
                if rockTypeDropdown and rockTypeDropdown.UpdateSelection then
                    rockTypeDropdown:UpdateSelection(selectedRockType)
                end
            end
        end

        if not selectedRockType or #selectedRockType == 0 then
            selectedRockType = {}
            ConfigSystem.CurrentConfig.SelectedRockType = {}
        else
            ConfigSystem.CurrentConfig.SelectedRockType = selectedRockType
        end

        ConfigSystem.SaveConfig()
    end,
}, "SelectRockDropdown")

-- Đảm bảo hiển thị lại lựa chọn đã lưu khi mở script
if selectedRockType and rockTypeDropdown and rockTypeDropdown.UpdateSelection then
    rockTypeDropdown:UpdateSelection(selectedRockType)
end

sections.Farm:Button({
    Name = "Refresh Rock List",
    Callback = function()
        rockTypes = scanRockTypes()
        -- Thêm "All" vào đầu danh sách
        local list = { "All" }
        for _, rockType in ipairs(rockTypes) do
            table.insert(list, rockType)
        end
        if rockTypeDropdown then
            if rockTypeDropdown.ClearOptions then
                rockTypeDropdown:ClearOptions()
            end
            if rockTypeDropdown.InsertOptions then
                rockTypeDropdown:InsertOptions(list)
            end
            if selectedRockType and rockTypeDropdown.UpdateSelection then
                rockTypeDropdown:UpdateSelection(selectedRockType)
            end
        end
    end,
}, "RefreshRockListButton")

-- Dropdown chọn khoảng cách Mine (ở dưới viên đá, 1-10)
local mineDistanceDropdown = sections.Farm:Dropdown({
    Name = "Select Distance",
    Multi = false,
    Required = false,
    Options = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" },
    Default = tostring(selectedMineDistance),
    Callback = function(value)
        if typeof(value) == "table" then
            for name, state in pairs(value) do
                if state then
                    value = name
                    break
                end
            end
        end

        local dist = tonumber(value)
        if dist and dist >= 1 and dist <= 10 then
            selectedMineDistance = dist
            ConfigSystem.CurrentConfig.SelectedMineDistance = selectedMineDistance
            ConfigSystem.SaveConfig()
        end
    end,
}, "SelectMineDistanceDropdown")

if selectedMineDistance and mineDistanceDropdown and mineDistanceDropdown.UpdateSelection then
    mineDistanceDropdown:UpdateSelection(tostring(selectedMineDistance))
end

sections.Farm:Toggle({
    Name = "Auto Mine",
    Default = autoMineEnabled,
    Callback = function(value)
        autoMineEnabled = value
        ConfigSystem.CurrentConfig.AutoMineEnabled = value
        ConfigSystem.SaveConfig()

        if value then
            if not selectedRockType or #selectedRockType == 0 then
                notify("Mine", "Please select a rock type!", 4)
            else
                -- Khi bật lên, bay lên trời ngay lập tức
                flyToSkyForMine()
            end
        else
            -- Khi tắt, reset flag và dọn dẹp connection
            isMiningInSky = false
            if mineSkyPositionConnection then
                mineSkyPositionConnection:Disconnect()
                mineSkyPositionConnection = nil
            end
        end
    end,
}, "AutoMineToggle")

task.spawn(function()
    while task.wait(0.3) do
        -- Nếu Auto Buy And Use đang hoạt động, tạm dừng Auto Mine
        if autoMineEnabled and selectedRockType and #selectedRockType > 0 and not isAutoBuyAndUseActive then
            local player = Players.LocalPlayer
            local character = player.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")

            -- Đảm bảo đang bay trên trời (nếu chưa thì bay lên)
            if hrp and not isMiningInSky then
                flyToSkyForMine()
                task.wait(0.2) -- Chờ một chút để đảm bảo đã bay lên
            end

            if character and hrp then
                local closestTarget = nil
                local closestDist = math.huge

                -- Tìm rock gần nhất (tính khoảng cách XZ, bỏ qua Y vì đang bay trên trời)
                for _, typeName in ipairs(selectedRockType) do
                    local parts = getRockPartsByType(typeName)
                    for _, part in ipairs(parts) do
                        if part and part.Parent then
                            -- Skip rock nếu đang trong blacklist và chưa hết cooldown
                            local conflictTime = conflictedRocks[part]
                            local currentTime = tick()
                            if conflictTime and (currentTime - conflictTime) < CONFLICT_COOLDOWN then
                                -- Rock vẫn đang trong cooldown, skip
                            elseif conflictTime then
                                -- Hết cooldown, xóa khỏi blacklist
                                conflictedRocks[part] = nil
                            end

                            -- Chỉ tính rock nếu không trong cooldown
                            if not conflictTime or (currentTime - conflictTime) >= CONFLICT_COOLDOWN then
                                local hrpPos = hrp.Position
                                local rockPos = part.Position
                                -- Tính khoảng cách XZ (bỏ qua Y)
                                local dist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(rockPos.X, 0, rockPos.Z))
                                .Magnitude
                                if dist < closestDist then
                                    closestDist = dist
                                    closestTarget = part
                                end
                            end
                        end
                    end
                end

                if closestTarget then
                    -- Di chuyển trên không trung đến rock (giữ Y cao, chỉ di chuyển X và Z)
                    tweenToMineTarget(closestTarget)
                    -- Truyền loại đá của target vào hàm đào (sẽ tự tele xuống và đào)
                    local model = closestTarget:FindFirstAncestorWhichIsA("Model")
                    local rockName = model and model.Name or nil
                    swingPickaxeUntilMinedType(closestTarget, rockName)
                    -- Sau khi mine xong, swingPickaxeUntilMinedType sẽ tự động bay lên lại
                end
            end
        end
    end
end)

-- Task tự động dọn dẹp blacklist conflicted rocks (mỗi 5 giây)
task.spawn(function()
    while task.wait(5) do
        local currentTime = tick()
        local toRemove = {}
        for rockPart, conflictTime in pairs(conflictedRocks) do
            -- Xóa rock nếu hết cooldown hoặc rock không còn tồn tại
            if (currentTime - conflictTime) >= CONFLICT_COOLDOWN or not rockPart or not rockPart.Parent then
                table.insert(toRemove, rockPart)
            end
        end
        for _, rockPart in ipairs(toRemove) do
            conflictedRocks[rockPart] = nil
        end
    end
end)

--// ENEMY TAB
sections.Enemy:Header({ Name = "Enemy" })

local function extractEnemyTypeName(fullName)
    if not fullName or fullName == "" then
        return nil
    end

    -- Loại bỏ số ở cuối: "Zombie123" -> "Zombie", "EliteZombie234" -> "EliteZombie"
    -- Giữ nguyên khoảng trắng: "Delver Zombie123" -> "Delver Zombie"
    local baseName = fullName:gsub("%d+$", "")
    if baseName == "" then
        return nil
    end

    -- Loại bỏ khoảng trắng thừa ở cuối
    baseName = baseName:gsub("%s+$", "")

    return baseName
end

local function scanEnemyTypes()
    enemyTypes = {}
    local seen = {}

    -- Chỉ dùng ReplicatedStorage.Assets.Mobs để scan tên, Auto Farm Enemy vẫn dùng workspace như cũ
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        return enemyTypes
    end

    local mobsRoot = assetsFolder:FindFirstChild("Mobs")
    if not mobsRoot then
        return enemyTypes
    end

    for _, child in ipairs(mobsRoot:GetDescendants()) do
        if child:IsA("Model") then
            -- Bỏ qua các model tên chung chung như "Model"
            if child.Name ~= "Model" then
                -- Dùng extractEnemyTypeName để loại bỏ số đuôi (nếu có) và khoảng trắng thừa
                local typeName = extractEnemyTypeName(child.Name)
                if typeName and typeName ~= "" and not seen[typeName] then
                    seen[typeName] = true
                    table.insert(enemyTypes, typeName)
                end
            end
        end
    end

    table.sort(enemyTypes)

    return enemyTypes
end

-- Scan tên potion từ ReplicatedStorage.Assets.Extras.Potion
local function scanPotionModels()
    potionNames = {}

    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        return potionNames
    end

    local extrasFolder = assetsFolder:FindFirstChild("Extras")
    if not extrasFolder then
        return potionNames
    end

    local potionFolder = extrasFolder:FindFirstChild("Potion")
    if not potionFolder then
        return potionNames
    end

    for _, child in ipairs(potionFolder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(potionNames, child.Name)
        end
    end

    table.sort(potionNames)
    return potionNames
end

local function getEnemyModelsByType(typeName)
    local result = {}

    if not typeName or typeName == "" then
        return result
    end

    local livingRoot = workspace:FindFirstChild("Living")
    if not livingRoot then
        return result
    end

    for _, child in ipairs(livingRoot:GetChildren()) do
        if child:IsA("Model") then
            local extractedType = extractEnemyTypeName(child.Name)
            if extractedType == typeName then
                table.insert(result, child)
            end
        end
    end

    return result
end

local function isEnemyDead(enemyModel)
    if not enemyModel or not enemyModel.Parent then
        return true
    end

    local statusFolder = enemyModel:FindFirstChild("Status")
    if statusFolder and statusFolder:FindFirstChild("Dead") then
        return true
    end

    return false
end

local function getClosestEnemyByType(typeName)
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return nil
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return nil
    end

    local enemies = getEnemyModelsByType(typeName)
    local closestEnemy = nil
    local closestDist = math.huge

    for _, enemy in ipairs(enemies) do
        -- Bỏ qua enemy chết
        if not isEnemyDead(enemy) and enemy and enemy.Parent then
            local rootPart = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart or
                enemy:FindFirstChildWhichIsA("BasePart", true)
            if rootPart then
                local dist = (hrp.Position - rootPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestEnemy = enemy
                end
            end
        end
    end

    return closestEnemy
end

local function isEnemyDead(enemyModel)
    if not enemyModel or not enemyModel.Parent then
        return true
    end

    local statusFolder = enemyModel:FindFirstChild("Status")
    if statusFolder and statusFolder:FindFirstChild("Dead") then
        return true
    end

    return false
end

local currentTween = nil

-- Hàm bay lên trời ngay lập tức và giữ Y cố định
local function flyToSky()
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return false
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end

    -- Hủy connection cũ nếu có
    if skyPositionConnection then
        skyPositionConnection:Disconnect()
        skyPositionConnection = nil
    end

    -- Tele lên trời ngay lập tức (giữ X và Z, chỉ thay đổi Y)
    local currentPos = hrp.Position
    local skyPos = Vector3.new(currentPos.X, SKY_HEIGHT, currentPos.Z)
    hrp.CFrame = CFrame.new(skyPos)
    isFlyingInSky = true

    -- Tạo BodyVelocity để giữ Y cố định
    local bodyVelocity = hrp:FindFirstChild("BodyVelocity")
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Parent = hrp
    end

    -- Giữ Y cố định bằng Heartbeat connection
    local trackedCharacter = character
    skyPositionConnection = RunService.Heartbeat:Connect(function()
        if not autoFarmEnemyEnabled
            or not isFlyingInSky
            or Players.LocalPlayer.Character ~= trackedCharacter
            or not hrp
            or not hrp.Parent then
            if skyPositionConnection then
                skyPositionConnection:Disconnect()
                skyPositionConnection = nil
            end
            return
        end

        -- Giữ Y cố định ở SKY_HEIGHT, chỉ cho phép di chuyển X và Z
        local currentPos = hrp.Position
        local fixedPos = Vector3.new(currentPos.X, SKY_HEIGHT, currentPos.Z)
        hrp.CFrame = CFrame.new(fixedPos, fixedPos + hrp.CFrame.LookVector * Vector3.new(1, 0, 1))
        if bodyVelocity then
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
    end)

    return true
end

-- Hàm di chuyển trên không trung đến vị trí enemy (giữ Y cao, chỉ di chuyển X và Z)
local function tweenToEnemyInSky(enemyModel)
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return false
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not enemyModel or not enemyModel.Parent then
        return false
    end

    local enemyRootPart = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart or
        enemyModel:FindFirstChildWhichIsA("BasePart", true)
    if not enemyRootPart then
        return false
    end

    -- Hủy tween cũ nếu còn chạy
    if currentTween then
        pcall(function() currentTween:Cancel() end)
    end

    -- Vị trí trên không trung phía trên enemy (giữ Y = SKY_HEIGHT, chỉ di chuyển X và Z)
    local enemyPos = enemyRootPart.Position
    local targetPos = Vector3.new(enemyPos.X, SKY_HEIGHT, enemyPos.Z)
    local currentPos = hrp.Position
    local distanceToTarget = (Vector3.new(currentPos.X, 0, currentPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z))
        .Magnitude

    -- Tính thời gian tween dựa trên khoảng cách XZ (chậm hơn vì chỉ di chuyển X và Z, không bị anti-tp)
    -- Tốc độ: khoảng 8 studs/s để an toàn
    local time = math.clamp(distanceToTarget / 10, 1, 8)

    -- Hướng về enemy (nhưng vẫn ở trên trời)
    local lookAtCFrame = CFrame.new(targetPos, enemyRootPart.Position)

    currentTween = TweenService:Create(
        hrp,
        TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = lookAtCFrame }
    )

    currentTween:Play()
    return true
end

local function swingWeaponUntilEnemyDead(enemyModel, typeName)
    if not enemyModel or not typeName or typeName == "" then
        return
    end

    -- Kiểm tra enemy còn sống không
    if not enemyModel or not enemyModel.Parent then
        return
    end

    local args = { "Weapon" }
    local toolRF = game:GetService("ReplicatedStorage")
        :WaitForChild("Shared")
        :WaitForChild("Packages")
        :WaitForChild("Knit")
        :WaitForChild("Services")
        :WaitForChild("ToolService")
        :WaitForChild("RF")
        :WaitForChild("ToolActivated")

    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end

    -- Lưu lại character hiện tại, nếu người chơi chết & respawn (character đổi) thì dừng vòng while để chạy lại logic tween
    local trackedCharacter = character

    -- Chờ tween trên không trung hoàn tất trước khi tele xuống
    if currentTween then
        pcall(function() currentTween.Completed:Wait() end)
    end

    -- Hủy connection giữ Y trên trời
    if skyPositionConnection then
        skyPositionConnection:Disconnect()
        skyPositionConnection = nil
    end

    -- Tele xuống enemy ngay lập tức (giữ X và Z, chỉ thay đổi Y)
    local enemyRootPart = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart or
        enemyModel:FindFirstChildWhichIsA("BasePart", true)
    if not enemyRootPart then
        return
    end

    -- Tele xuống dưới enemy (selectedDistance dưới enemy) và nằm ngửa nhìn lên (giống auto mine)
    local targetPos = enemyRootPart.Position + Vector3.new(0, -selectedDistance, 0)
    local lookAtPos = enemyRootPart.Position + Vector3.new(0, 5, 0) -- Nhìn chếch lên trên enemy
    hrp.CFrame = CFrame.new(targetPos, lookAtPos)
    isFlyingInSky = false                                           -- Đánh dấu đã xuống đánh quái

    -- Tắt AutoRotate để tránh game tự động xoay nhân vật
    local originalAutoRotate = hrp.AssemblyAngularVelocity
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

    -- Tắt gravity để giữ độ cao
    local bodyVelocity = hrp:FindFirstChild("BodyVelocity")
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = hrp
    end

    -- Bắt đầu giữ vị trí
    local keepPositionConnection
    keepPositionConnection = RunService.Heartbeat:Connect(function()
        -- Nếu AutoFarm tắt, enemy mất, enemy chết, nhân vật đổi (respawn) hoặc Auto Buy & Use đang chạy thì dừng
        if not autoFarmEnemyEnabled
            or not enemyModel
            or not enemyModel.Parent
            or isEnemyDead(enemyModel)
            or Players.LocalPlayer.Character ~= trackedCharacter
            or not hrp
            or not hrp.Parent
            or isAutoBuyAndUseActive then
            if keepPositionConnection then
                keepPositionConnection:Disconnect()
            end
            return
        end

        if enemyRootPart and hrp and hrp.Parent then
            -- Đứng dưới enemy và nằm ngửa nhìn lên (giống auto mine)
            local targetPos = enemyRootPart.Position + Vector3.new(0, -selectedDistance, 0)
            local lookAtPos = enemyRootPart.Position + Vector3.new(0, 5, 0) -- Nhìn chếch lên trên enemy
            hrp.CFrame = CFrame.new(targetPos, lookAtPos)
            -- Giữ vận tốc = 0 để không rơi
            if bodyVelocity then
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end
    end)

    while autoFarmEnemyEnabled do
        -- Nếu người chơi đã respawn (character đổi), HRP mất hoặc Auto Buy & Use đang chạy thì thoát vòng lặp
        if Players.LocalPlayer.Character ~= trackedCharacter or not hrp or not hrp.Parent or isAutoBuyAndUseActive then
            break
        end

        -- Kiểm tra enemy còn sống hay không (status.Dead)
        if isEnemyDead(enemyModel) then
            break
        end

        if not enemyModel or not enemyModel.Parent then
            break
        end

        -- Invoke weapon attack
        pcall(function()
            toolRF:InvokeServer(unpack(args))
        end)

        task.wait(0.15)
    end

    -- Dọn dẹp khi dừng - hủy tween nếu còn chạy
    if currentTween then
        pcall(function() currentTween:Cancel() end)
        currentTween = nil
    end

    if keepPositionConnection then
        keepPositionConnection:Disconnect()
    end
    if bodyVelocity and bodyVelocity.Parent then
        bodyVelocity:Destroy()
    end
    -- Khôi phục AutoRotate
    if hrp and hrp.Parent then
        hrp.AssemblyAngularVelocity = originalAutoRotate
    end

    -- Sau khi enemy chết, bay lên trời lại ngay lập tức
    if autoFarmEnemyEnabled then
        flyToSky()
    end
end

enemyTypes = scanEnemyTypes()
-- Thêm "All" vào đầu danh sách
local enemyOptions = { "All" }
for _, enemyType in ipairs(enemyTypes) do
    table.insert(enemyOptions, enemyType)
end

enemyTypeDropdown = sections.Enemy:Dropdown({
    Name = "Select Enemy",
    Multi = true,
    Required = false,
    Options = enemyOptions,
    Default = selectedEnemyType,
    Callback = function(value)
        if typeof(value) == "table" then
            selectedEnemyType = {}
            local hasAll = false
            for name, state in pairs(value) do
                if state then
                    if name == "All" then
                        hasAll = true
                    else
                        table.insert(selectedEnemyType, name)
                    end
                end
            end

            -- Nếu chọn "All", chọn tất cả các loại enemy
            if hasAll then
                selectedEnemyType = {}
                for _, enemyType in ipairs(enemyTypes) do
                    table.insert(selectedEnemyType, enemyType)
                end
                -- Cập nhật lại dropdown để hiển thị tất cả (bỏ "All")
                if enemyTypeDropdown and enemyTypeDropdown.UpdateSelection then
                    enemyTypeDropdown:UpdateSelection(selectedEnemyType)
                end
            end
        end

        if not selectedEnemyType or #selectedEnemyType == 0 then
            selectedEnemyType = {}
            ConfigSystem.CurrentConfig.SelectedEnemyType = {}
        else
            ConfigSystem.CurrentConfig.SelectedEnemyType = selectedEnemyType
        end

        ConfigSystem.SaveConfig()
    end,
}, "SelectEnemyDropdown")

-- Đảm bảo hiển thị lại lựa chọn đã lưu khi mở script
if selectedEnemyType and enemyTypeDropdown and enemyTypeDropdown.UpdateSelection then
    for _, name in ipairs(enemyTypes) do
        if name == selectedEnemyType then
            enemyTypeDropdown:UpdateSelection(selectedEnemyType)
            break
        end
    end
end

sections.Enemy:Button({
    Name = "Refresh Enemy List",
    Callback = function()
        enemyTypes = scanEnemyTypes()
        -- Thêm "All" vào đầu danh sách
        local list = { "All" }
        for _, enemyType in ipairs(enemyTypes) do
            table.insert(list, enemyType)
        end
        if enemyTypeDropdown then
            if enemyTypeDropdown.ClearOptions then
                enemyTypeDropdown:ClearOptions()
            end
            if enemyTypeDropdown.InsertOptions then
                enemyTypeDropdown:InsertOptions(list)
            end
            if selectedEnemyType and enemyTypeDropdown.UpdateSelection then
                enemyTypeDropdown:UpdateSelection(selectedEnemyType)
            end
        end
    end,
}, "RefreshEnemyListButton")

local distanceDropdown = sections.Enemy:Dropdown({
    Name = "Select Distance",
    Multi = false,
    Required = false,
    Options = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" },
    Default = tostring(selectedDistance),
    Callback = function(value)
        if typeof(value) == "table" then
            for name, state in pairs(value) do
                if state then
                    value = name
                    break
                end
            end
        end

        local dist = tonumber(value)
        if dist and dist >= 1 and dist <= 10 then
            selectedDistance = dist
            ConfigSystem.CurrentConfig.SelectedDistance = selectedDistance
            ConfigSystem.SaveConfig()
        end
    end,
}, "SelectDistanceDropdown")

-- Đảm bảo hiển thị lại lựa chọn đã lưu khi mở script
if selectedDistance and distanceDropdown and distanceDropdown.UpdateSelection then
    distanceDropdown:UpdateSelection(tostring(selectedDistance))
end

sections.Enemy:Toggle({
    Name = "Auto Farm Enemy",
    Default = autoFarmEnemyEnabled,
    Callback = function(value)
        autoFarmEnemyEnabled = value
        ConfigSystem.CurrentConfig.AutoFarmEnemyEnabled = value
        ConfigSystem.SaveConfig()

        if value then
            if not selectedEnemyType then
                notify("Enemy", "Please select an enemy type!", 4)
            else
                -- Khi bật lên, bay lên trời ngay lập tức
                flyToSky()
            end
        else
            -- Khi tắt, reset flag và dọn dẹp connection
            isFlyingInSky = false
            if skyPositionConnection then
                skyPositionConnection:Disconnect()
                skyPositionConnection = nil
            end
        end
    end,
}, "AutoFarmEnemyToggle")

task.spawn(function()
    while true do
        -- Nếu Auto Buy And Use đang hoạt động, tạm dừng Auto Farm Enemy
        if autoFarmEnemyEnabled and selectedEnemyType and #selectedEnemyType > 0 and not isAutoBuyAndUseActive then
            local player = Players.LocalPlayer
            local character = player.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")

            -- Đảm bảo đang bay trên trời (nếu chưa thì bay lên)
            if hrp and not isFlyingInSky then
                flyToSky()
                task.wait(0.2) -- Chờ một chút để đảm bảo đã bay lên
            end

            if character and hrp then
                local closestTarget = nil
                local closestDist = math.huge

                -- Tìm enemy gần nhất từ tất cả loại được chọn
                -- Nếu selectedEnemyType chứa "All", dùng tất cả enemyTypes
                local effectiveEnemyTypes = selectedEnemyType
                local hasAll = false
                for _, typeName in ipairs(selectedEnemyType) do
                    if typeName == "All" then
                        hasAll = true
                        break
                    end
                end
                if hasAll then
                    effectiveEnemyTypes = enemyTypes
                end

                for _, enemyTypeName in ipairs(effectiveEnemyTypes) do
                    local target = getClosestEnemyByType(enemyTypeName)
                    if target and hrp then
                        local rootPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart or
                            target:FindFirstChildWhichIsA("BasePart", true)
                        if rootPart then
                            -- Tính khoảng cách XZ (bỏ qua Y) vì đang bay trên trời
                            local hrpPos = hrp.Position
                            local enemyPos = rootPart.Position
                            local dist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(enemyPos.X, 0, enemyPos.Z))
                                .Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closestTarget = target
                            end
                        end
                    end
                end

                if closestTarget then
                    -- Kiểm tra lại enemy không dead trước khi bắt đầu
                    if not isEnemyDead(closestTarget) then
                        -- Di chuyển trên không trung đến enemy (giữ Y cao, chỉ di chuyển X và Z)
                        tweenToEnemyInSky(closestTarget)
                        -- Chuyển sang đánh (sẽ tự tele xuống và đánh)
                        swingWeaponUntilEnemyDead(closestTarget, extractEnemyTypeName(closestTarget.Name))
                        -- Sau khi enemy chết, swingWeaponUntilEnemyDead sẽ tự động bay lên lại
                    else
                        task.wait(0.1) -- Nếu enemy dead, chờ ngắn rồi tìm lại
                    end
                else
                    task.wait(0.1) -- Nếu không tìm thấy, chờ rồi tìm lại
                end
            end
        else
            task.wait(0.3) -- Nếu disabled, chờ lâu hơn
        end
    end
end)

--// SHOP TAB - Shop Potion
sections.ShopPotion:Header({ Name = "Shop Potion" })

-- Tween tới vị trí cố định mua potion (tùy theo PlaceId)
local currentMariaTween = nil

-- Hàm bay lên trời cho Auto Buy And Use
local function flyToSkyForBuy()
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return false
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end

    -- Hủy connection cũ nếu có
    if buySkyPositionConnection then
        buySkyPositionConnection:Disconnect()
        buySkyPositionConnection = nil
    end

    -- Tele lên trời ngay lập tức (giữ X và Z, chỉ thay đổi Y)
    local currentPos = hrp.Position
    local skyPos = Vector3.new(currentPos.X, SKY_HEIGHT, currentPos.Z)
    hrp.CFrame = CFrame.new(skyPos)
    isBuyingInSky = true

    -- Tạo BodyVelocity để giữ Y cố định
    local bodyVelocity = hrp:FindFirstChild("BodyVelocity")
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Parent = hrp
    end

    -- Giữ Y cố định bằng Heartbeat connection
    local trackedCharacter = character
    buySkyPositionConnection = RunService.Heartbeat:Connect(function()
        if not autoBuyAndUsePotionEnabled
            or not isBuyingInSky
            or Players.LocalPlayer.Character ~= trackedCharacter
            or not hrp
            or not hrp.Parent then
            if buySkyPositionConnection then
                buySkyPositionConnection:Disconnect()
                buySkyPositionConnection = nil
            end
            return
        end

        -- Giữ Y cố định ở SKY_HEIGHT, chỉ cho phép di chuyển X và Z
        local currentPos = hrp.Position
        local fixedPos = Vector3.new(currentPos.X, SKY_HEIGHT, currentPos.Z)
        hrp.CFrame = CFrame.new(fixedPos, fixedPos + hrp.CFrame.LookVector * Vector3.new(1, 0, 1))
        if bodyVelocity then
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
    end)

    return true
end

-- Hàm di chuyển trên không trung đến vị trí mua potion (giữ Y cao, chỉ di chuyển X và Z)
local function tweenToMaria()
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        return false
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end

    -- Chọn tọa độ theo PlaceId
    local placeId = game.PlaceId
    local targetPos

    if placeId == 76558904092080 then
        -- Place cũ
        targetPos = Vector3.new(-153.73959721191406, SKY_HEIGHT, 116.34660339355469)
    elseif placeId == 129009554587176 then
        -- Place mới
        targetPos = Vector3.new(-96.84030151367188, SKY_HEIGHT, -43.52947235107422)
    else
        -- Fallback: dùng tọa độ cũ
        targetPos = Vector3.new(-153.73959721191406, SKY_HEIGHT, 116.34660339355469)
    end

    local currentPos = hrp.Position
    local distanceToTarget = (Vector3.new(currentPos.X, 0, currentPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z))
    .Magnitude
    -- Tốc độ: khoảng 10 studs/s để an toàn (chỉ di chuyển X và Z, không bị anti-tp)
    local time = math.clamp(distanceToTarget / 10, 1, 8)

    -- Hướng nhìn giữ nguyên hướng hiện tại theo trục Y
    local lookAtCFrame = CFrame.new(targetPos, targetPos + (hrp.CFrame.LookVector * Vector3.new(1, 0, 1)))

    -- Hủy tween cũ nếu còn chạy
    if currentMariaTween then
        pcall(function()
            currentMariaTween:Cancel()
        end)
        currentMariaTween = nil
    end

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = lookAtCFrame }
    )

    currentMariaTween = tween
    tween:Play()

    local finished = false
    tween.Completed:Connect(function()
        finished = true
        -- Hủy connection giữ Y trên trời ngay khi tween xong để có thể tele xuống
        if buySkyPositionConnection then
            buySkyPositionConnection:Disconnect()
            buySkyPositionConnection = nil
        end
        isBuyingInSky = false
    end)

    -- Chờ tween xong hoặc bị hủy do tắt toggle
    while not finished do
        if not autoBuyAndUsePotionEnabled then
            pcall(function()
                tween:Cancel()
            end)
            currentMariaTween = nil
            -- Hủy connection nếu bị hủy
            if buySkyPositionConnection then
                buySkyPositionConnection:Disconnect()
                buySkyPositionConnection = nil
            end
            isBuyingInSky = false
            return false
        end
        task.wait(0.05)
    end

    currentMariaTween = nil
    return true
end

-- Dropdown chọn Potion (scan từ ReplicatedStorage.Assets.Extras.Potion)
potionNames = scanPotionModels()

potionDropdown = sections.ShopPotion:Dropdown({
    Name = "Select Potion",
    Multi = false,
    Required = false,
    Options = potionNames,
    Default = selectedPotionName,
    Callback = function(value)
        if typeof(value) == "table" then
            for name, state in pairs(value) do
                if state then
                    value = name
                    break
                end
            end
        end

        if not value or value == "" then
            selectedPotionName = nil
            ConfigSystem.CurrentConfig.SelectedPotionName = nil
        else
            selectedPotionName = value
            ConfigSystem.CurrentConfig.SelectedPotionName = value
        end

        ConfigSystem.SaveConfig()
    end,
}, "SelectPotionDropdown")

-- Đảm bảo hiển thị lại lựa chọn potion đã lưu khi mở script
if selectedPotionName and potionDropdown and potionDropdown.UpdateSelection then
    potionDropdown:UpdateSelection(selectedPotionName)
end

-- Nút refresh danh sách potion
sections.ShopPotion:Button({
    Name = "Refresh Potion List",
    Callback = function()
        local list = scanPotionModels()
        if potionDropdown then
            if potionDropdown.ClearOptions then
                potionDropdown:ClearOptions()
            end
            if potionDropdown.InsertOptions then
                potionDropdown:InsertOptions(list)
            end
            if selectedPotionName and potionDropdown.UpdateSelection then
                potionDropdown:UpdateSelection(selectedPotionName)
            end
        end
        notify("Shop Potion", "Đã cập nhật danh sách potion.", 3)
    end,
}, "RefreshPotionListButton")

-- Toggle Auto Buy And Use Potion
sections.ShopPotion:Toggle({
    Name = "Auto Buy And Use",
    Default = autoBuyAndUsePotionEnabled,
    Callback = function(value)
        autoBuyAndUsePotionEnabled = value
        ConfigSystem.CurrentConfig.AutoBuyAndUsePotionEnabled = value
        ConfigSystem.SaveConfig()
        if value then
            if not selectedPotionName then
                notify("Shop Potion", "Chưa chọn potion!", 3)
            else
                -- Khi bật lên, bay lên trời ngay lập tức
                flyToSkyForBuy()
            end
        else
            -- Khi tắt, reset flag và dọn dẹp connection
            isBuyingInSky = false
            if buySkyPositionConnection then
                buySkyPositionConnection:Disconnect()
                buySkyPositionConnection = nil
            end
        end
    end,
}, "AutoBuyAndUsePotionToggle")

-- Hàm map tên potion sang tên trong Perks (ví dụ: MovementSpeedPotion1 -> SpeedPotion1, LuckyPotion1 -> LuckPotion1)
local function getPotionPerkName(potionName)
    if not potionName or potionName == "" then
        return nil
    end

    -- Các pattern mapping phổ biến
    local mappings = {
        ["MovementSpeedPotion1"] = "SpeedPotion1",
        ["LuckyPotion1"] = "LuckPotion1",
        -- Có thể thêm mapping khác nếu cần
    }

    -- Nếu có mapping thì dùng, không thì thử tìm trong Perks với tên gốc hoặc các biến thể
    return mappings[potionName] or potionName
end

-- Hàm check potion có trong Perks không
local function hasPotionInPerks(potionName)
    local player = Players.LocalPlayer
    if not player then
        return false
    end

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then
        return false
    end

    local hotbar = playerGui:FindFirstChild("Hotbar")
    if not hotbar then
        return false
    end

    local perks = hotbar:FindFirstChild("Perks")
    if not perks then
        return false
    end

    -- Thử tìm với tên đã map và tên gốc
    local perkName = getPotionPerkName(potionName)
    if perks:FindFirstChild(perkName) then
        return true
    end

    -- Thử tìm với tên gốc
    if perks:FindFirstChild(potionName) then
        return true
    end

    return false
end

-- Vòng lặp Auto Buy And Use Potion
task.spawn(function()
    local toolRF = ReplicatedStorage
        :WaitForChild("Shared")
        :WaitForChild("Packages")
        :WaitForChild("Knit")
        :WaitForChild("Services")
        :WaitForChild("ToolService")
        :WaitForChild("RF")
        :WaitForChild("ToolActivated")

    while true do
        task.wait(0.5)

        -- Nếu toggle tắt hoặc chưa chọn potion thì đảm bảo flag cũng tắt và bỏ qua
        if not autoBuyAndUsePotionEnabled or not selectedPotionName then
            isAutoBuyAndUseActive = false
        else
            -- Bắt đầu 1 chu kỳ Auto Buy & Use: set flag để block Auto Mine / Auto Farm Enemy
            isAutoBuyAndUseActive = true

            local player = Players.LocalPlayer
            local character = player and player.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")

            -- Đảm bảo đang bay trên trời (nếu chưa thì bay lên)
            if hrp and not isBuyingInSky then
                flyToSkyForBuy()
                task.wait(0.2) -- Chờ một chút để đảm bảo đã bay lên
            end

            local backpack = player and player:FindFirstChild("Backpack")
            local canAfford = false

            -- Check Gold trong PlayerGui.Main.Screen.Hud.Gold
            local playerGui = player and player:FindFirstChild("PlayerGui")
            if playerGui then
                local mainGui = playerGui:FindFirstChild("Main")
                local screen = mainGui and mainGui:FindFirstChild("Screen")
                local hud = screen and screen:FindFirstChild("Hud")
                local goldLabel = hud and hud:FindFirstChild("Gold")
                if goldLabel and goldLabel:IsA("TextLabel") then
                    local text = goldLabel.Text or ""
                    -- Ví dụ: "$464.45" -> "464.45"
                    local numeric = text:gsub("[^%d%.]", "")
                    local amount = tonumber(numeric) or 0
                    if amount >= 600 then
                        canAfford = true
                    end
                end
            end

            if autoBuyAndUsePotionEnabled and canAfford then
                local hasPotion = backpack and backpack:FindFirstChild(selectedPotionName)
                if hasPotion then
                    -- Nếu toggle đã tắt giữa chừng thì dừng ngay
                    if autoBuyAndUsePotionEnabled then
                        pcall(function()
                            local args = { selectedPotionName }
                            toolRF:InvokeServer(unpack(args))
                        end)
                    end
                else
                    -- Bước 2: Nếu không có potion trong Backpack, check Perks xem có effect không
                    local hasPotionEffect = hasPotionInPerks(selectedPotionName)
                    if not hasPotionEffect and autoBuyAndUsePotionEnabled then
                        -- Không có effect => đã hết potion => đi mua
                        -- Di chuyển trên không trung đến vị trí mua
                        local ok = tweenToMaria()
                        if ok and autoBuyAndUsePotionEnabled and hrp then
                            -- Đảm bảo connection đã được hủy (đã được hủy trong tweenToMaria, nhưng kiểm tra lại để an toàn)
                            if buySkyPositionConnection then
                                buySkyPositionConnection:Disconnect()
                                buySkyPositionConnection = nil
                            end

                            -- Tele xuống vị trí mua potion ngay lập tức
                            local placeId = game.PlaceId
                            local targetPos
                            if placeId == 76558904092080 then
                                targetPos = Vector3.new(-153.73959721191406, 27.377073287963867, 116.34660339355469)
                            elseif placeId == 129009554587176 then
                                targetPos = Vector3.new(-96.84030151367188, 20.6254825592041, -43.52947235107422)
                            else
                                targetPos = Vector3.new(-153.73959721191406, 27.377073287963867, 116.34660339355469)
                            end

                            -- Chờ một chút để đảm bảo connection đã được hủy hoàn toàn
                            task.wait(0.1)
                            hrp.CFrame = CFrame.new(targetPos)
                            isBuyingInSky = false

                            -- Mua potion
                            pcall(function()
                                local args = { selectedPotionName, 3 }
                                ProximityPurchaseRF:InvokeServer(unpack(args))
                            end)

                            -- Chờ một chút rồi bay lên trời lại
                            task.wait(0.5)
                            if autoBuyAndUsePotionEnabled then
                                flyToSkyForBuy()
                            end
                        end
                    end
                end
            end

            -- Kết thúc 1 chu kỳ Auto Buy & Use
            isAutoBuyAndUseActive = false
        end
    end
end)

--// SELL ITEM SECTION
sections.SellItem:Header({ Name = "Sell Item" })

-- Hàm scan Ores từ ReplicatedStorage.Assets.Ores
local function scanOres()
    oreNames = {}
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        return oreNames
    end

    local oresFolder = assetsFolder:FindFirstChild("Ores")
    if not oresFolder then
        return oreNames
    end

    for _, child in ipairs(oresFolder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(oreNames, child.Name)
        end
    end

    table.sort(oreNames)
    return oreNames
end

-- Hàm lấy số lượng item từ PlayerGui
local function getItemQuantity(itemName)
    local player = Players.LocalPlayer
    if not player then
        return 0
    end

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then
        return 0
    end

    local menu = playerGui:FindFirstChild("Menu")
    if not menu then
        return 0
    end

    local frame = menu:FindFirstChild("Frame")
    if not frame then
        return 0
    end

    local frame2 = frame:FindFirstChild("Frame")
    if not frame2 then
        return 0
    end

    local menus = frame2:FindFirstChild("Menus")
    if not menus then
        return 0
    end

    local stash = menus:FindFirstChild("Stash")
    if not stash then
        return 0
    end

    local background = stash:FindFirstChild("Background")
    if not background then
        return 0
    end

    local itemFrame = background:FindFirstChild(itemName)
    if not itemFrame then
        return 0
    end

    local main = itemFrame:FindFirstChild("Main")
    if not main then
        return 0
    end

    local quantity = main:FindFirstChild("Quantity")
    if not quantity or not quantity:IsA("TextLabel") then
        return 0
    end

    -- Parse text "x13" -> 13
    local text = quantity.Text or ""
    local digits = text:gsub("[^%d]", "")
    local amount = tonumber(digits) or 0

    return amount
end

-- Hàm format options với số lượng
local function getOreOptionsWithQuantity()
    local options = {}
    for _, oreName in ipairs(oreNames) do
        local quantity = getItemQuantity(oreName)
        if quantity > 0 then
            table.insert(options, oreName .. " (" .. tostring(quantity) .. ")")
        else
            table.insert(options, oreName)
        end
    end
    return options
end

-- Scan và tạo dropdown
oreNames = scanOres()

-- Format selectedItemName để hiển thị trong dropdown (thêm số lượng nếu có)
local function getSelectedItemNamesForDropdown()
    local result = {}
    for _, itemName in ipairs(selectedItemName or {}) do
        local quantity = getItemQuantity(itemName)
        if quantity > 0 then
            table.insert(result, itemName .. " (" .. tostring(quantity) .. ")")
        else
            table.insert(result, itemName)
        end
    end
    return result
end

local itemDropdown = sections.SellItem:Dropdown({
    Name = "Select Item",
    Multi = true,
    Required = false,
    Options = getOreOptionsWithQuantity(),
    Default = getSelectedItemNamesForDropdown(),
    Callback = function(value)
        if typeof(value) == "table" then
            selectedItemName = {}
            for name, state in pairs(value) do
                if state then
                    -- Extract tên item từ format "Iron (13)" -> "Iron"
                    local itemName = name:gsub("%s*%(%d+%)", "") -- Loại bỏ " (13)"
                    table.insert(selectedItemName, itemName)
                end
            end
        else
            selectedItemName = {}
        end

        ConfigSystem.CurrentConfig.SelectedItemName = selectedItemName
        ConfigSystem.SaveConfig()
    end,
}, "SelectItemDropdown")

-- Đảm bảo hiển thị lại lựa chọn đã lưu khi mở script
if selectedItemName and #selectedItemName > 0 and itemDropdown and itemDropdown.UpdateSelection then
    local selectedOptions = getSelectedItemNamesForDropdown()
    if #selectedOptions > 0 then
        itemDropdown:UpdateSelection(selectedOptions)
    end
end

sections.SellItem:Button({
    Name = "Refresh Item List",
    Callback = function()
        local list = scanOres()
        oreNames = list
        if itemDropdown then
            local options = getOreOptionsWithQuantity()
            if itemDropdown.ClearOptions then
                itemDropdown:ClearOptions()
            end
            if itemDropdown.InsertOptions then
                itemDropdown:InsertOptions(options)
            end
            if selectedItemName and #selectedItemName > 0 then
                -- Tìm và update selection với số lượng mới cho tất cả item đã chọn
                local selectedOptions = {}
                for _, itemName in ipairs(selectedItemName) do
                    for _, opt in ipairs(options) do
                        local optItemName = opt:gsub("%s*%(%d+%)", "")
                        if optItemName == itemName then
                            table.insert(selectedOptions, opt)
                            break
                        end
                    end
                end
                if #selectedOptions > 0 and itemDropdown.UpdateSelection then
                    itemDropdown:UpdateSelection(selectedOptions)
                end
            end
        end
    end,
}, "RefreshItemListButton")

sections.SellItem:Toggle({
    Name = "Auto Sell Item",
    Default = autoSellItemEnabled,
    Callback = function(value)
        autoSellItemEnabled = value
        ConfigSystem.CurrentConfig.AutoSellItemEnabled = value
        ConfigSystem.SaveConfig()
        if value then
            if not selectedItemName or #selectedItemName == 0 then
                notify("Sell Item", "Please select an item!", 3)
            else
                -- Reset model và flag khi bật lại để tìm lại Greedy Cey và mở dialogue lại
                greedyCeyModel = nil
                hasOpenedDialogue = false
            end
        else
            -- Reset model và flag khi tắt
            greedyCeyModel = nil
            hasOpenedDialogue = false
        end
    end,
}, "AutoSellItemToggle")

-- Vòng lặp Auto Sell Item
task.spawn(function()
    local sellRF = ReplicatedStorage
        :WaitForChild("Shared")
        :WaitForChild("Packages")
        :WaitForChild("Knit")
        :WaitForChild("Services")
        :WaitForChild("DialogueService")
        :WaitForChild("RF")
        :WaitForChild("RunCommand")

    local forceDialogueRF = ReplicatedStorage
        :WaitForChild("Shared")
        :WaitForChild("Packages")
        :WaitForChild("Knit")
        :WaitForChild("Services")
        :WaitForChild("ProximityService")
        :WaitForChild("RF")
        :WaitForChild("ForceDialogue")

    while true do
        task.wait(1) -- Check mỗi 1 giây
        if autoSellItemEnabled and selectedItemName and #selectedItemName > 0 then
            -- Bước 1: Chờ Greedy Cey xuất hiện (chỉ 1 lần duy nhất)
            if not greedyCeyModel then
                local prox = workspace:FindFirstChild("Proximity")
                if prox then
                    local greedyCey = prox:FindFirstChild("Greedy Cey")
                    if greedyCey then
                        greedyCeyModel = greedyCey
                    end
                end
            end

            -- Bước 2: Mở dialogue với Greedy Cey (chỉ 1 lần duy nhất khi đã tìm thấy Greedy Cey)
            if greedyCeyModel and not hasOpenedDialogue then
                pcall(function()
                    -- Args phải bao gồm model Greedy Cey làm tham số đầu tiên
                    local dialogueArgs = {
                        greedyCeyModel,
                        "SellConfirmMisc"
                    }
                    forceDialogueRF:InvokeServer(unpack(dialogueArgs))
                end)
                hasOpenedDialogue = true -- Đánh dấu đã mở dialogue
                -- Chờ một chút để dialogue mở xong
                task.wait(0.5)
            end

            -- Bước 3: Bán tất cả item đã chọn (chỉ khi đã tìm thấy Greedy Cey và đã mở dialogue)
            if greedyCeyModel and hasOpenedDialogue then
                local basket = {}
                local hasItems = false

                -- Lấy số lượng của tất cả item đã chọn
                for _, itemName in ipairs(selectedItemName) do
                    local quantity = getItemQuantity(itemName)
                    if quantity > 0 then
                        basket[itemName] = quantity
                        hasItems = true
                    end
                end

                -- Bán tất cả item cùng lúc nếu có
                if hasItems then
                    pcall(function()
                        local args = {
                            "SellConfirm",
                            {
                                Basket = basket
                            }
                        }
                        sellRF:InvokeServer(unpack(args))
                    end)
                end
            end
        end
    end
end)

-- Tự động cập nhật số lượng trong dropdown mỗi 3 giây
task.spawn(function()
    while true do
        task.wait(3)
        if itemDropdown then
            local options = getOreOptionsWithQuantity()
            if itemDropdown.ClearOptions then
                itemDropdown:ClearOptions()
            end
            if itemDropdown.InsertOptions then
                itemDropdown:InsertOptions(options)
            end
            if selectedItemName and #selectedItemName > 0 then
                -- Tìm và update selection với số lượng mới cho tất cả item đã chọn
                local selectedOptions = {}
                for _, itemName in ipairs(selectedItemName) do
                    for _, opt in ipairs(options) do
                        local optItemName = opt:gsub("%s*%(%d+%)", "")
                        if optItemName == itemName then
                            table.insert(selectedOptions, opt)
                            break
                        end
                    end
                end
                if #selectedOptions > 0 and itemDropdown.UpdateSelection then
                    itemDropdown:UpdateSelection(selectedOptions)
                end
            end
        end
    end
end)

--// TELEPORT TAB
sections.TeleportNPC:Header({ Name = "Tween To NPC" })

-- Hàm scan NPC từ workspace.Proximity (loại bỏ tất cả Potion)
local function scanNPCs()
    npcNames = {}
    local proxFolder = workspace:FindFirstChild("Proximity")
    if not proxFolder then
        return npcNames
    end

    for _, child in ipairs(proxFolder:GetChildren()) do
        if child:IsA("Model") then
            local nameLower = child.Name:lower()
            -- Loại bỏ tất cả model có tên chứa "potion" (case-insensitive)
            if not nameLower:find("potion") then
                table.insert(npcNames, child.Name)
            end
        end
    end

    table.sort(npcNames)
    return npcNames
end

-- Hàm scan Shop từ workspace.Shops
local function scanShops()
    shopNames = {}
    local shopsFolder = workspace:FindFirstChild("Shops")
    if not shopsFolder then
        return shopNames
    end

    for _, child in ipairs(shopsFolder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(shopNames, child.Name)
        end
    end

    table.sort(shopNames)
    return shopNames
end

-- Hàm tween tới NPC/Shop với tốc độ chậm
local function tweenToTarget(targetName, isNPC)
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        notify("Teleport", "Character not found!", 3)
        return false
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        notify("Teleport", "HumanoidRootPart not found!", 3)
        return false
    end

    local folder = isNPC and workspace:FindFirstChild("Proximity") or workspace:FindFirstChild("Shops")
    if not folder then
        notify("Teleport", "Không tìm thấy folder!", 3)
        return false
    end

    local targetModel = folder:FindFirstChild(targetName)
    if not targetModel then
        notify("Teleport", "Không tìm thấy " .. targetName .. "!", 3)
        return false
    end

    local targetPart = targetModel:FindFirstChild("HumanoidRootPart") or targetModel.PrimaryPart or
        targetModel:FindFirstChildWhichIsA("BasePart", true)
    if not targetPart then
        notify("Teleport", "Không tìm thấy phần tử của " .. targetName .. "!", 3)
        return false
    end

    local targetPos = targetPart.Position + Vector3.new(0, 3, 0)
    local distance = (hrp.Position - targetPos).Magnitude
    -- Tween chậm: tốc độ 10 studs/s, tối thiểu 1.5s, tối đa 8s
    local time = math.clamp(distance / 10, 1.5, 8)

    local lookAtCFrame = CFrame.new(targetPos, targetPart.Position)

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = lookAtCFrame }
    )

    tween:Play()
    tween.Completed:Wait()

    notify("Teleport", "Tweened to " .. targetName, 3)
    return true
end

-- Scan và tạo dropdown NPC
npcNames = scanNPCs()

local npcDropdown = sections.TeleportNPC:Dropdown({
    Name = "Select NPC",
    Multi = false,
    Required = false,
    Options = npcNames,
    Default = selectedNPCName,
    Callback = function(value)
        if typeof(value) == "table" then
            for name, state in pairs(value) do
                if state then
                    value = name
                    break
                end
            end
        end

        if not value or value == "" then
            selectedNPCName = nil
        else
            selectedNPCName = value
        end
    end,
}, "SelectNPCDropdown")

sections.TeleportNPC:Button({
    Name = "Refresh NPC List",
    Callback = function()
        local list = scanNPCs()
        npcNames = list
        if npcDropdown then
            if npcDropdown.ClearOptions then
                npcDropdown:ClearOptions()
            end
            if npcDropdown.InsertOptions then
                npcDropdown:InsertOptions(list)
            end
            if selectedNPCName and npcDropdown.UpdateSelection then
                npcDropdown:UpdateSelection(selectedNPCName)
            end
        end
        notify("Teleport", "Updated NPC list.", 3)
    end,
}, "RefreshNPCListButton")

sections.TeleportNPC:Button({
    Name = "Tween To NPC",
    Callback = function()
        if not selectedNPCName then
            notify("Teleport", "Please select an NPC!", 3)
        else
            tweenToTarget(selectedNPCName, true)
        end
    end,
}, "TweenToNPCButton")

-- Tween To Shop section
sections.TeleportShop:Header({ Name = "Tween To Shop" })

-- Scan và tạo dropdown Shop
shopNames = scanShops()

local shopDropdown = sections.TeleportShop:Dropdown({
    Name = "Select Shop",
    Multi = false,
    Required = false,
    Options = shopNames,
    Default = selectedShopName,
    Callback = function(value)
        if typeof(value) == "table" then
            for name, state in pairs(value) do
                if state then
                    value = name
                    break
                end
            end
        end

        if not value or value == "" then
            selectedShopName = nil
        else
            selectedShopName = value
        end
    end,
}, "SelectShopDropdown")

sections.TeleportShop:Button({
    Name = "Refresh Shop List",
    Callback = function()
        local list = scanShops()
        shopNames = list
        if shopDropdown then
            if shopDropdown.ClearOptions then
                shopDropdown:ClearOptions()
            end
            if shopDropdown.InsertOptions then
                shopDropdown:InsertOptions(list)
            end
            if selectedShopName and shopDropdown.UpdateSelection then
                shopDropdown:UpdateSelection(selectedShopName)
            end
        end
        notify("Teleport", "Updated shop list.", 3)
    end,
}, "RefreshShopListButton")

sections.TeleportShop:Button({
    Name = "Tween To Shop",
    Callback = function()
        if not selectedShopName then
            notify("Teleport", "Please select a shop!", 3)
        else
            tweenToTarget(selectedShopName, false)
        end
    end,
}, "TweenToShopButton")

-- Tab Settings: thông tin cơ bản
sections.SettingsInfo:Header({ Name = "Script Information" })
sections.SettingsInfo:Label({
    Text = "The Forge Script\nPlayer: " .. playerName
})

sections.SettingsInfo:Button({
    Name = "Copy Player Name",
    Callback = function()
        if setclipboard then
            setclipboard(playerName)
            notify("Notification", "Copied player name.", 3)
        else
            notify("Notification", playerName, 3)
        end
    end,
}, "CopyPlayerNameButton")

sections.SettingsInfo:SubLabel({
    Text = "Shortcut: Left Alt (or mobile icon) to hide/show UI"
})

--// SETTINGS MISC TAB
sections.SettingsMisc:Header({ Name = "Misc" })

sections.SettingsMisc:Toggle({
    Name = "Anti AFK",
    Default = antiAFKEnabled,
    Callback = function(value)
        antiAFKEnabled = value
        ConfigSystem.CurrentConfig.AntiAFKEnabled = value
        ConfigSystem.SaveConfig()
        notify("Anti AFK", (value and "Enabled" or "Disabled") .. " Anti AFK", 3)
    end,
}, "AntiAFKToggle")

-- Global settings giống style UI.lua
local globalSettings = {
    UIBlurToggle = Window:GlobalSetting({
        Name = "UI Blur",
        Default = Window:GetAcrylicBlurState(),
        Callback = function(bool)
            Window:SetAcrylicBlurState(bool)
            notify(Window.Settings.Title, (bool and "Enabled" or "Disabled") .. " UI Blur", 4)
        end,
    }),
    NotificationToggle = Window:GlobalSetting({
        Name = "Notifications",
        Default = Window:GetNotificationsState(),
        Callback = function(bool)
            Window:SetNotificationsState(bool)
            notify(Window.Settings.Title, (bool and "Enabled" or "Disabled") .. " Notifications", 4)
        end,
    }),
    UserInfoToggle = Window:GlobalSetting({
        Name = "Show User Info",
        Default = Window:GetUserInfoState(),
        Callback = function(bool)
            Window:SetUserInfoState(bool)
            notify(Window.Settings.Title, (bool and "Showing" or "Redacted") .. " User Info", 4)
        end,
    })
}

tabs.Farm:Select()

Window.onUnloaded(function()
    notify("HT HUB | The Forge", "UI has been closed.", 3)
end)

MacLib:LoadAutoLoadConfig()

-- Auto save config đơn giản (5s/lần)
task.spawn(function()
    while task.wait(5) do
        pcall(ConfigSystem.SaveConfig)
    end
end)

-- Anti AFK - dùng VirtualUser giả lập click chuột
task.spawn(function()
    local vu = game:GetService("VirtualUser")
    local player = Players.LocalPlayer

    while true do
        task.wait(120) -- 120 giây

        if antiAFKEnabled then
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam then
                    vu:Button2Down(Vector2.new(0, 0), cam.CFrame)
                    task.wait(1)
                    vu:Button2Up(Vector2.new(0, 0), cam.CFrame)
                end
                print("Anti-AFK running at:", os.time())
            end)
        end
    end
end)

-- Tạo icon floating để giả lập nút Left Alt cho mobile
task.spawn(function()
    local ok, errorMsg = pcall(function()
        if not getgenv().LoadedTheForgeMobileUI == true then
            getgenv().LoadedTheForgeMobileUI = true
            local OpenUI = Instance.new("ScreenGui")
            local ImageButton = Instance.new("ImageButton")
            local UICorner = Instance.new("UICorner")

            if syn and syn.protect_gui then
                syn.protect_gui(OpenUI)
                OpenUI.Parent = game:GetService("CoreGui")
            elseif gethui then
                OpenUI.Parent = gethui()
            else
                OpenUI.Parent = game:GetService("CoreGui")
            end

            OpenUI.Name = "TheForge_MobileUIButton"
            OpenUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            OpenUI.ResetOnSpawn = false

            ImageButton.Parent = OpenUI
            ImageButton.BackgroundColor3 = Color3.fromRGB(105, 105, 105)
            ImageButton.BackgroundTransparency = 0.8
            ImageButton.Position = UDim2.new(0.9, 0, 0.1, 0)
            ImageButton.Size = UDim2.new(0, 50, 0, 50)
            ImageButton.Image = "rbxassetid://90319448802378"
            ImageButton.Draggable = true
            ImageButton.Transparency = 0.2

            UICorner.CornerRadius = UDim.new(0, 200)
            UICorner.Parent = ImageButton

            ImageButton.MouseEnter:Connect(function()
                game:GetService("TweenService"):Create(ImageButton, TweenInfo.new(0.2), {
                    BackgroundTransparency = 0.5,
                    Transparency = 0
                }):Play()
            end)

            ImageButton.MouseLeave:Connect(function()
                game:GetService("TweenService"):Create(ImageButton, TweenInfo.new(0.2), {
                    BackgroundTransparency = 0.8,
                    Transparency = 0.2
                }):Play()
            end)

            ImageButton.MouseButton1Click:Connect(function()
                game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.LeftAlt, false, game)
                task.wait(0.1)
                game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.LeftAlt, false, game)
            end)
        end
    end)

    if not ok then
        warn("Error creating mobile UI button (HT HUB | The Forge): " .. tostring(errorMsg))
    end
end)

notify("HT HUB | The Forge", "Script loaded successfully!\nPress Left Alt or mobile icon to hide/show UI", 5)
print("HTHubTheForge.lua loaded successfully!")
