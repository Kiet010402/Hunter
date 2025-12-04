--// Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    warn("Lỗi khi tải UI Library (MacLib): " .. tostring(err))
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
}
ConfigSystem.CurrentConfig = {}

ConfigSystem.SaveConfig = function()
    local ok, saveErr = pcall(function()
        writefile(ConfigSystem.FileName, HttpService:JSONEncode(ConfigSystem.CurrentConfig))
    end)
    if not ok then
        warn("Lưu cấu hình thất bại:", saveErr)
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
    Subtitle = "Xin chào, " .. playerName,
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
    antiAFKEnabled = false
end
local enemyTypes = {}
local enemyTypeDropdown = nil

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

--// Sections
local sections = {
    Farm = tabs.Farm:Section({ Side = "Left" }),
    Enemy = tabs.Farm:Section({ Side = "Right" }),
    ShopPotion = tabs.Shop:Section({ Side = "Left" }),
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

    local closestPart = nil
    local closestDist = math.huge

    for _, typeName in ipairs(typeList) do
        local parts = getRockPartsByType(typeName)
        for _, part in ipairs(parts) do
            if part and part.Parent then
                local dist = (hrp.Position - part.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPart = part
                end
            end
        end
    end

    return closestPart
end

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

    -- Đứng dưới viên đá một khoảng (theo Dropdown Distance) và ngửa mặt lên
    local downOffset = -(selectedMineDistance or 3)
    local targetPos = targetPart.Position + Vector3.new(0, downOffset, 0)
    local distance = (hrp.Position - targetPos).Magnitude

    -- Nếu ở gần rock thì tween nhanh nhưng mượt, xa thì tween chậm giống Enemy
    local time
    if distance <= 100 then
        -- Gần: vẫn nhanh nhưng không quá giật
        time = math.clamp(distance / 20, 0.4, 4)
    else
        -- Xa: an toàn, chậm hơn
        time = math.clamp(distance / 8, 0.8, 7)
    end

    local lookAtPos = targetPart.Position + Vector3.new(0, 5, 0) -- nhìn chếch lên trên viên đá
    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = CFrame.new(targetPos, lookAtPos) }
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
end

rockTypes = scanRockTypes()

rockTypeDropdown = sections.Farm:Dropdown({
    Name = "Select Rock",
    Multi = true,
    Required = false,
    Options = rockTypes,
    Default = selectedRockType,
    Callback = function(value)
        if typeof(value) == "table" then
            selectedRockType = {}
            for name, state in pairs(value) do
                if state then
                    table.insert(selectedRockType, name)
                end
            end
        end

        if not selectedRockType or #selectedRockType == 0 then
            selectedRockType = {}
            ConfigSystem.CurrentConfig.SelectedRockType = {}
            notify("Mine", "Đã bỏ chọn loại đá.", 3)
        else
            ConfigSystem.CurrentConfig.SelectedRockType = selectedRockType
            notify("Mine", "Đã chọn: " .. table.concat(selectedRockType, ", "), 3)
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
        local list = scanRockTypes()
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
        notify("Mine", "Đã cập nhật danh sách đá.", 3)
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
            notify("Mine", "Khoảng cách Mine: " .. tostring(selectedMineDistance), 3)
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
                notify("Mine", "Chưa chọn loại đá! Hãy chọn ở dropdown.", 4)
            else
                notify("Mine", "Đã bật Auto Mine cho: " .. table.concat(selectedRockType, ", "), 3)
            end
        else
            notify("Mine", "Đã tắt Auto Mine", 3)
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
            if character and hrp then
                -- Chỉ chạy Auto Mine khi nhân vật đã respawn đầy đủ
                local target = getClosestRockPartByTypes(selectedRockType)
                if target then
                    tweenToMineTarget(target)
                    -- Truyền loại đá của target vào hàm đào
                    local model = target:FindFirstAncestorWhichIsA("Model")
                    local rockName = model and model.Name or nil
                    swingPickaxeUntilMinedType(target, rockName)
                end
            end
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

local function tweenAboveEnemy(enemyModel, distance)
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

    -- Tween lên trên đầu enemy với khoảng cách đã chọn, luôn hướng về enemy
    local targetPos = enemyRootPart.Position + Vector3.new(0, distance, 0)
    local distanceToTarget = (hrp.Position - targetPos).Magnitude

    -- Nếu ở gần enemy thì tween nhanh nhưng mượt hơn (chậm lại một chút), xa thì tween chậm để tránh anti-tp
    local time
    if distanceToTarget <= 100 then
        -- Gần: vẫn nhanh nhưng không quá giật
        time = math.clamp(distanceToTarget / 20, 0.4, 4)
    else
        -- Xa: an toàn, chậm hơn
        time = math.clamp(distanceToTarget / 8, 0.8, 7)
    end

    -- Luôn hướng về enemy
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

    -- Chờ tween hoàn tất trước khi bắt đầu set CFrame
    local tweenCompleted = false
    if currentTween then
        task.spawn(function()
            pcall(function() currentTween.Completed:Wait() end)
            tweenCompleted = true
        end)
    else
        tweenCompleted = true
    end

    -- Bắt đầu giữ vị trí sau khi tween xong
    local keepPositionConnection
    keepPositionConnection = RunService.Heartbeat:Connect(function()
        if not tweenCompleted then
            return -- Chưa tween xong thì không set CFrame
        end

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

        local enemyRootPart = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart or
            enemyModel:FindFirstChildWhichIsA("BasePart", true)
        if enemyRootPart and hrp and hrp.Parent then
            local targetPos = enemyRootPart.Position + Vector3.new(0, selectedDistance, 0)
            -- Giữ vị trí và hướng về enemy
            hrp.CFrame = CFrame.new(targetPos, enemyRootPart.Position)
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
end

enemyTypes = scanEnemyTypes()

enemyTypeDropdown = sections.Enemy:Dropdown({
    Name = "Select Enemy",
    Multi = true,
    Required = false,
    Options = enemyTypes,
    Default = selectedEnemyType,
    Callback = function(value)
        if typeof(value) == "table" then
            selectedEnemyType = {}
            for name, state in pairs(value) do
                if state then
                    table.insert(selectedEnemyType, name)
                end
            end
        end

        if not selectedEnemyType or #selectedEnemyType == 0 then
            selectedEnemyType = {}
            ConfigSystem.CurrentConfig.SelectedEnemyType = {}
            notify("Enemy", "Đã bỏ chọn loại enemy", 3)
        else
            ConfigSystem.CurrentConfig.SelectedEnemyType = selectedEnemyType
            notify("Enemy", "Đã chọn: " .. table.concat(selectedEnemyType, ", "), 3)
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
        local list = scanEnemyTypes()
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
        notify("Enemy", "Đã cập nhật danh sách enemy.", 3)
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
            notify("Enemy", "Khoảng cách: " .. tostring(selectedDistance), 3)
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
                notify("Enemy", "Chưa chọn loại enemy! Hãy chọn ở dropdown.", 4)
            else
                notify("Enemy", "Đã bật Auto Farm Enemy cho: " .. tostring(selectedEnemyType), 3)
            end
        else
            notify("Enemy", "Đã tắt Auto Farm Enemy", 3)
        end
    end,
}, "AutoFarmEnemyToggle")

task.spawn(function()
    while true do
        -- Nếu Auto Buy And Use đang hoạt động, tạm dừng Auto Farm Enemy
        if autoFarmEnemyEnabled and selectedEnemyType and #selectedEnemyType > 0 and not isAutoBuyAndUseActive then
            local closestTarget = nil
            local closestDist = math.huge
            local hrp = Players.LocalPlayer.Character and
                Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

            -- Tìm enemy gần nhất từ tất cả loại được chọn
            for _, enemyTypeName in ipairs(selectedEnemyType) do
                local target = getClosestEnemyByType(enemyTypeName)
                if target and hrp then
                    local rootPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart or
                        target:FindFirstChildWhichIsA("BasePart", true)
                    if rootPart then
                        local dist = (hrp.Position - rootPart.Position).Magnitude
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
                    -- Bắt đầu tween (không chờ)
                    tweenAboveEnemy(closestTarget, selectedDistance)
                    -- Chuyển sang đánh ngay lập tức, không chờ tween xong
                    swingWeaponUntilEnemyDead(closestTarget, extractEnemyTypeName(closestTarget.Name))
                    -- Sau khi enemy chết/break ra, quay lại ngay lập tức
                else
                    task.wait(0.1) -- Nếu enemy dead, chờ ngắn rồi tìm lại
                end
            else
                task.wait(0.1) -- Nếu không tìm thấy, chờ rồi tìm lại
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
        targetPos = Vector3.new(-153.73959721191406, 27.377073287963867, 116.34660339355469)
    elseif placeId == 129009554587176 then
        -- Place mới
        targetPos = Vector3.new(-96.84030151367188, 20.6254825592041, -43.52947235107422)
    else
        -- Fallback: dùng tọa độ cũ
        targetPos = Vector3.new(-153.73959721191406, 27.377073287963867, 116.34660339355469)
    end
    local distance = (hrp.Position - targetPos).Magnitude
    -- Tween chậm hơn để hạn chế dịch chuyển gấp
    local time = math.clamp(distance / 8, 1.2, 12)

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
    end)

    -- Chờ tween xong hoặc bị hủy do tắt toggle
    while not finished do
        if not autoBuyAndUsePotionEnabled then
            pcall(function()
                tween:Cancel()
            end)
            currentMariaTween = nil
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
            notify("Shop Potion", "Đã bỏ chọn potion.", 3)
        else
            selectedPotionName = value
            ConfigSystem.CurrentConfig.SelectedPotionName = value
            notify("Shop Potion", "Đã chọn: " .. tostring(value), 3)
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
                notify("Shop Potion", "Đã bật Auto Buy And Use: " .. selectedPotionName, 3)
            end
        else
            notify("Shop Potion", "Đã tắt Auto Buy And Use", 3)
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
                        local ok = tweenToMaria()
                        if ok and autoBuyAndUsePotionEnabled then
                            pcall(function()
                                local args = { selectedPotionName, 3 }
                                ProximityPurchaseRF:InvokeServer(unpack(args))
                            end)
                        end
                    end
                end
            end

            -- Kết thúc 1 chu kỳ Auto Buy & Use
            isAutoBuyAndUseActive = false
        end
    end
end)

-- Tab Settings: thông tin cơ bản
sections.SettingsInfo:Header({ Name = "Thông tin Script" })
sections.SettingsInfo:Label({
    Text = "The Forge Script\nNgười chơi: " .. playerName
})

sections.SettingsInfo:Button({
    Name = "Copy Player Name",
    Callback = function()
        if setclipboard then
            setclipboard(playerName)
            notify("Thông báo", "Đã sao chép tên người chơi.", 3)
        else
            notify("Thông báo", playerName, 3)
        end
    end,
}, "CopyPlayerNameButton")

sections.SettingsInfo:SubLabel({
    Text = "Phím tắt: Left Alt (hoặc icon mobile) để ẩn/hiện UI"
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
        notify("Anti AFK", (value and "Bật" or "Tắt") .. " Anti AFK", 3)
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
    notify("HT HUB | The Forge", "UI đã được đóng.", 3)
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
                print("Anti-AFK chạy lúc:", os.time())
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
        warn("Lỗi khi tạo nút Mobile UI (HT HUB | The Forge): " .. tostring(errorMsg))
    end
end)

notify("HT HUB | The Forge", "Script đã tải thành công!\nNhấn Left Alt hoặc icon để ẩn/hiện UI", 5)
print("HTHubTheForge.lua đã tải thành công!")
