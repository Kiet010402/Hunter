--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

--// Load UI Library với error handling (MacLib)
local MacLib = nil
local success, err = pcall(function()
    MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()
end)

if not success or not MacLib then
    warn("Lỗi khi tải UI Library: " .. tostring(err))
    return
end

-- Hệ thống lưu trữ cấu hình
local function sanitizeFileName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("[^%w_%-]", "_")
    if name == "" then
        return nil
    end
    return name
end

local function getFileNameFromPath(path)
    return path:match("([^/\\]+)$")
end

local function serializeCFrameData(cf)
    local rx, ry, rz = cf:ToOrientation()
    local pos = cf.Position
    return {
        Pos = { pos.X, pos.Y, pos.Z },
        Ori = { rx, ry, rz }
    }
end

local function upgradeSavedPosition(data)
    if not data then
        return nil
    end

    if data.Pos and data.Ori then
        return {
            Pos = {
                tonumber(data.Pos[1]) or 0,
                tonumber(data.Pos[2]) or 0,
                tonumber(data.Pos[3]) or 0
            },
            Ori = {
                tonumber(data.Ori[1]) or 0,
                tonumber(data.Ori[2]) or 0,
                tonumber(data.Ori[3]) or 0
            }
        }
    elseif data.X and data.Y and data.Z then
        return {
            Pos = { tonumber(data.X) or 0, tonumber(data.Y) or 0, tonumber(data.Z) or 0 },
            Ori = { 0, 0, 0 }
        }
    end

    return nil
end

local function getCFrameFromSaved(data)
    local upgraded = upgradeSavedPosition(data)
    if not upgraded then
        return nil, nil
    end

    local pos = upgraded.Pos
    local ori = upgraded.Ori
    local cf = CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(ori[1], ori[2], ori[3])
    return upgraded, cf
end

local ConfigSystem = {}
ConfigSystem.FileName = "ScriptConfig_" .. Players.LocalPlayer.Name .. ".json"
ConfigSystem.DefaultConfig = {
    SavedPosition = nil, -- Lưu tọa độ {X, Y, Z}
    AutoFishEnabled = false,
    SelectedPositionFile = nil,
    AutoSellEnabled = false,
    AutoSellRarity = "Legend",
    AutoSellDelay = 10
}
ConfigSystem.CurrentConfig = {}

-- Hàm để lưu cấu hình
ConfigSystem.SaveConfig = function()
    local ok, saveErr = pcall(function()
        writefile(ConfigSystem.FileName, HttpService:JSONEncode(ConfigSystem.CurrentConfig))
    end)
    if ok then
        print("Đã lưu cấu hình thành công!")
    else
        warn("Lưu cấu hình thất bại:", saveErr)
    end
end

-- Hàm để tải cấu hình
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
        return true
    else
        ConfigSystem.CurrentConfig = table.clone(ConfigSystem.DefaultConfig)
        ConfigSystem.SaveConfig()
        return false
    end
end

-- Tải cấu hình khi khởi động
ConfigSystem.LoadConfig()

-- Lấy tên người chơi
local playerName = Players.LocalPlayer.Name

-- Biến lưu trạng thái Auto Fish
local autoFishEnabled = ConfigSystem.CurrentConfig.AutoFishEnabled or false
local originalSaved = ConfigSystem.CurrentConfig.SavedPosition
local savedPosition = upgradeSavedPosition(originalSaved)
if savedPosition and originalSaved ~= savedPosition then
    ConfigSystem.CurrentConfig.SavedPosition = savedPosition
    ConfigSystem.SaveConfig()
else
    ConfigSystem.CurrentConfig.SavedPosition = savedPosition
end
local selectedPositionFile = ConfigSystem.CurrentConfig.SelectedPositionFile
local autoSellEnabled = ConfigSystem.CurrentConfig.AutoSellEnabled or false
local autoSellRarity = ConfigSystem.CurrentConfig.AutoSellRarity or "Legend"
local autoSellDelayMinutes = ConfigSystem.CurrentConfig.AutoSellDelay or 10
local lastAutoSell = 0

-- Thư mục lưu vị trí
local PositionsFolder = "ScriptHub_Positions"
pcall(function()
    if makefolder and isfolder and not isfolder(PositionsFolder) then
        makefolder(PositionsFolder)
        end
    end)
    
local positionNameInput = ""
local positionDropdown = nil
local positionOptions = {}

local teleportDropdown = nil
local islandOptions = {}
local islandParts = {}
local selectedIsland = nil

local function findFirstBasePart(obj)
    if not obj then
        return nil
    end

    if obj:IsA("BasePart") then
        return obj
    end

    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end

    if obj:IsA("Folder") then
        return obj:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function getPositionFiles()
    local files = {}

    if not listfiles then
        return files
    end

    local ok, list = pcall(function()
        return listfiles(PositionsFolder)
    end)

    if ok and list then
        for _, path in ipairs(list) do
            if path:sub(-4):lower() == ".txt" then
                table.insert(files, getFileNameFromPath(path))
            end
        end
        table.sort(files)
    end

    return files
end

local function readPositionFromFile(fileName)
    if not fileName then
        return nil
    end
    local path = PositionsFolder .. "/" .. fileName
    if not isfile or not readfile or not isfile(path) then
        return nil
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if ok and data then
        return upgradeSavedPosition(data)
    end

    return nil
end

local function savePositionToFile(fileName, position)
    if not fileName or not position then
        return false
    end

    if not writefile then
        return false
    end

    return pcall(function()
        writefile(PositionsFolder .. "/" .. fileName, HttpService:JSONEncode(position))
    end)
        end
        
local function deletePositionFile(fileName)
    if not fileName or not delfile then
        return false
    end

    local path = PositionsFolder .. "/" .. fileName
    if isfile and not isfile(path) then
        return false
    end

    local ok = pcall(function()
        delfile(path)
    end)

    return ok
end

local function refreshDropdownOptions()
    positionOptions = getPositionFiles()

    if positionDropdown then
        if positionDropdown.ClearOptions then
            positionDropdown:ClearOptions()
        end
        if positionDropdown.InsertOptions then
            positionDropdown:InsertOptions(positionOptions)
        end
        if selectedPositionFile and positionDropdown.UpdateSelection then
            positionDropdown:UpdateSelection(selectedPositionFile)
                end
    end

    return positionOptions
end

local function scanIslands()
    table.clear(islandParts)
    islandOptions = {}

    local folder = workspace:FindFirstChild("!!!! ISLAND LOCATIONS !!!!")
    if not folder then
        return islandOptions
    end

    for _, child in ipairs(folder:GetChildren()) do
        local basePart = findFirstBasePart(child)
        if basePart then
            table.insert(islandOptions, child.Name)
            islandParts[child.Name] = basePart
        end
    end

    table.sort(islandOptions)
    return islandOptions
end

local function refreshIslandDropdown()
    local list = scanIslands()

    if teleportDropdown then
        if teleportDropdown.ClearOptions then
            teleportDropdown:ClearOptions()
        end

        if teleportDropdown.InsertOptions then
            teleportDropdown:InsertOptions(list)
        end

        if selectedIsland and teleportDropdown.UpdateSelection then
            teleportDropdown:UpdateSelection(selectedIsland)
                end
            end
            
    return list
end

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
        
-- Tải tọa độ từ file đang chọn nếu có
if selectedPositionFile then
    savedPosition = readPositionFromFile(selectedPositionFile) or savedPosition
end

--// Create Window (MacLib)
local Window = MacLib:Window({
    Title = "DuongTuan Hub",
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

-- Global settings
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

MacLib:SetFolder("DuongTuanHub")

local tabGroup = Window:TabGroup()
local tabs = {
    Main = tabGroup:Tab({ Name = "Auto Play", Image = "rbxassetid://10734923549" }),
    Teleport = tabGroup:Tab({ Name = "Teleport", Image = "rbxassetid://11963373994" }),
    Settings = tabGroup:Tab({ Name = "Settings", Image = "rbxassetid://10734950309" })
}

local sections = {
    Position = tabs.Main:Section({ Side = "Left" }),
    AutoSell = tabs.Main:Section({ Side = "Right" }),
    Teleport = tabs.Teleport:Section({ Side = "Left" }),
    SettingsInfo = tabs.Settings:Section({ Side = "Left" })
}

sections.Position:Header({ Name = "Auto Farm" })

sections.Position:Input({
    Name = "Name Position",
    Placeholder = "Name File",
    AcceptedCharacters = "All",
    Callback = function(input)
        positionNameInput = input or ""
    end,
    onChanged = function(input)
        positionNameInput = input or ""
    end,
}, "NamePositionInput")

sections.Position:Button({
    Name = "Create Position",
    Callback = function()
        local sanitized = sanitizeFileName(positionNameInput)
        if not sanitized then
            notify("Lỗi", "Vui lòng nhập tên vị trí hợp lệ!", 4)
            return
        end

        local fileName = sanitized
        if not fileName:lower():match("%.txt$") then
            fileName = fileName .. ".txt"
        end

        local path = PositionsFolder .. "/" .. fileName
        if isfile and isfile(path) then
            notify("Thông báo", "File này đã tồn tại!", 4)
            return
        end

        local defaultPosition = serializeCFrameData(CFrame.new(0, 0, 0))
        if savePositionToFile(fileName, defaultPosition) then
            notify("Create Position", "Đã tạo file: " .. fileName, 4)
            refreshDropdownOptions()
        else
            notify("Lỗi", "Không thể tạo file! (thiếu quyền?)", 4)
        end
    end,
}, "CreatePositionButton")

positionOptions = refreshDropdownOptions()
positionDropdown = sections.Position:Dropdown({
    Name = "Select Position",
    Multi = false,
    Required = false,
    Options = positionOptions,
    Default = getDefaultOption(positionOptions, selectedPositionFile),
    Callback = function(value)
        local chosen = value
        if typeof(value) == "table" then
            for name, state in pairs(value) do
                if state then
                    chosen = name
                    break
                            end
            end
        end

        if not chosen or chosen == "" then
            selectedPositionFile = nil
            ConfigSystem.CurrentConfig.SelectedPositionFile = nil
            savedPosition = nil
            ConfigSystem.CurrentConfig.SavedPosition = nil
            ConfigSystem.SaveConfig()
            return
        end

        selectedPositionFile = chosen
        ConfigSystem.CurrentConfig.SelectedPositionFile = chosen
        savedPosition = readPositionFromFile(chosen)
        ConfigSystem.CurrentConfig.SavedPosition = savedPosition
        ConfigSystem.SaveConfig()

        if savedPosition then
            notify("Select Position", "Đang sử dụng file: " .. chosen, 4)
                else
            notify("Thông báo", "File chưa có tọa độ! Hãy Save Pos.", 4)
                end
    end,
}, "SelectPositionDropdown")

sections.Position:Button({
    Name = "Save Position",
    Callback = function()
        if not selectedPositionFile then
            notify("Lỗi", "Chưa chọn file vị trí! Hãy dùng dropdown.", 4)
            return
        end

        local player = Players.LocalPlayer
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local hrp = character.HumanoidRootPart
            local cf = hrp.CFrame
            local pos = cf.Position
            savedPosition = serializeCFrameData(cf)
            ConfigSystem.CurrentConfig.SavedPosition = savedPosition
            ConfigSystem.SaveConfig()

            if savePositionToFile(selectedPositionFile, savedPosition) then
                notify("Save Position", string.format(
                    "Đã lưu tọa độ vào %s\nX=%.2f, Y=%.2f, Z=%.2f",
                    selectedPositionFile, pos.X, pos.Y, pos.Z
                ), 5)
            else
                notify("Lỗi", "Không thể ghi file vị trí!", 4)
            end
        else
            notify("Lỗi", "Không tìm thấy nhân vật!", 3)
        end
    end,
}, "SavePositionButton")

sections.Position:Button({
    Name = "Delete Position File",
    Callback = function()
        if not selectedPositionFile then
            notify("Thông báo", "Chưa chọn file vị trí để xóa.", 4)
            return
        end

        if deletePositionFile(selectedPositionFile) then
            notify("Delete Position", "Đã xóa file: " .. selectedPositionFile, 4)
            selectedPositionFile = nil
            savedPosition = nil
            ConfigSystem.CurrentConfig.SelectedPositionFile = nil
            ConfigSystem.CurrentConfig.SavedPosition = nil
            ConfigSystem.SaveConfig()
            refreshDropdownOptions()
        else
            notify("Lỗi", "Không thể xóa file vị trí!", 4)
                end
    end,
}, "DeletePositionButton")

sections.AutoSell:Header({ Name = "Auto Sell" })

sections.AutoSell:Dropdown({
    Name = "Select Sell Rarity",
    Multi = false,
    Required = false,
    Options = { "Legend", "Mythic" },
    Default = autoSellRarity,
    Callback = function(value)
        if not value then
            return
        end
        autoSellRarity = value
        ConfigSystem.CurrentConfig.AutoSellRarity = value
        ConfigSystem.SaveConfig()
        notify("Auto Sell", "Đã chọn độ hiếm: " .. value, 3)
    end,
}, "AutoSellRarityDropdown")

sections.AutoSell:Input({
    Name = "Delay Time (minutes)",
    Placeholder = "(1-60)",
    Callback = function(input)
        local value = tonumber(input)
        if not value then
            notify("Auto Sell", "Giá trị không hợp lệ!", 3)
            return
        end
        value = math.clamp(math.floor(value + 0.5), 1, 60)
        autoSellDelayMinutes = value
        ConfigSystem.CurrentConfig.AutoSellDelay = autoSellDelayMinutes
        ConfigSystem.SaveConfig()
        notify("Auto Sell", "Thời gian chờ: " .. autoSellDelayMinutes .. " phút", 3)
    end,
    onChanged = function(input)
        local value = tonumber(input)
        if value then
            autoSellDelayMinutes = math.clamp(math.floor(value + 0.5), 1, 60)
        end
    end,
    Default = tostring(autoSellDelayMinutes)
}, "AutoSellDelayInput")

sections.AutoSell:Toggle({
    Name = "Auto Sell",
    Default = autoSellEnabled,
    Callback = function(value)
        autoSellEnabled = value
        ConfigSystem.CurrentConfig.AutoSellEnabled = value
        ConfigSystem.SaveConfig()

        if value then
            lastAutoSell = 0
            notify("Auto Sell", "Đã bật Auto Sell", 3)
        else
            notify("Auto Sell", "Đã tắt Auto Sell", 3)
        end
    end,
}, "AutoSellToggle")

-- Hàm kiểm tra và di chuyển đến tọa độ đã lưu
local function moveToSavedPosition()
    local upgraded, targetCF = getCFrameFromSaved(savedPosition)
    if not targetCF then
        return false
    end

    if upgraded and upgraded ~= savedPosition then
        savedPosition = upgraded
        ConfigSystem.CurrentConfig.SavedPosition = upgraded
        ConfigSystem.SaveConfig()
    end

    local player = Players.LocalPlayer
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local hrp = character.HumanoidRootPart
    if (hrp.Position - targetCF.Position).Magnitude > 5 then
        hrp.CFrame = targetCF
    else
        hrp.CFrame = targetCF
    end
    task.wait(0.5)
    return true
end

local function executeAutoFish()
    if not autoFishEnabled or not selectedPositionFile then
        return
    end

    if not moveToSavedPosition() then
        return
    end

    local ok, autoErr = pcall(function()
        -- Bước 0
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
            :WaitForChild("RE/EquipToolFromHotbar"):FireServer(1)

        -- Bước 1
        task.wait(0.5)
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
            :WaitForChild("RF/ChargeFishingRod"):InvokeServer()

        -- Bước 2
        task.wait(1)
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
            :WaitForChild("RF/RequestFishingMinigameStarted")
            :InvokeServer(-1.233184814453125, 0.9940152067553181, 1763908713.407927)

        -- Bước 3
        task.wait(3)
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
            :WaitForChild("RE/FishingCompleted"):FireServer()
    end)

    if not ok then
        warn("Lỗi Auto Fish: " .. tostring(autoErr))
    end
end

sections.Position:Toggle({
    Name = "Auto Fish",
    Default = ConfigSystem.CurrentConfig.AutoFishEnabled or false,
    Callback = function(value)
        autoFishEnabled = value
        ConfigSystem.CurrentConfig.AutoFishEnabled = value
        ConfigSystem.SaveConfig()

        if value then
            if not selectedPositionFile then
                notify("Cảnh báo", "Chưa chọn file vị trí! Vui lòng tạo/chọn file.", 5)
                return
            end

            local _, cf = getCFrameFromSaved(savedPosition)
            if not cf then
                notify("Cảnh báo", "File chưa có tọa độ! Vui lòng Save Pos trước.", 5)
            else
                notify("Auto Fish", "Đã bật Auto Fish", 3)
            end
        else
            notify("Auto Fish", "Đã tắt Auto Fish", 3)
                end
    end,
}, "AutoFishToggle")
            
local function executeAutoSell()
    if not autoSellEnabled then
        return
    end

    local threshold = autoSellRarity == "Mythic" and 6 or 5

    local success, err = pcall(function()
        local netFolder = game:GetService("ReplicatedStorage")
            :WaitForChild("Packages")
            :WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0")
            :WaitForChild("net")

        netFolder:WaitForChild("RF/UpdateAutoSellThreshold"):InvokeServer(threshold)
        task.wait(1)
        netFolder:WaitForChild("RF/SellAllItems"):InvokeServer()
    end)

    if not success then
        warn("Lỗi Auto Sell: " .. tostring(err))
    else
        notify("Auto Sell", "Đã bán item ( " .. tostring(autoSellRarity) .. " )", 3)
    end
end

sections.SettingsInfo:Header({ Name = "Thông tin Script" })
sections.SettingsInfo:Label({
    Text = "Script Hub v1.0\nNgười chơi: " .. playerName
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

-- Teleport tab content
sections.Teleport:Header({ Name = "Island Teleport" })

teleportDropdown = sections.Teleport:Dropdown({
    Name = "Select Island",
    Multi = false,
    Required = false,
    Options = refreshIslandDropdown(),
    Callback = function(value)
        if typeof(value) == "table" then
            for name, state in pairs(value) do
                if state then
                    value = name
                    break
                end
            end
        end

        if value and islandParts[value] then
            selectedIsland = value
            notify("Island Selected", "Đã chọn đảo: " .. value, 3)
        else
            selectedIsland = nil
        end
    end,
}, "IslandDropdown")

sections.Teleport:Button({
    Name = "Refresh Island List",
    Callback = function()
        refreshIslandDropdown()
        notify("Teleport", "Đã cập nhật danh sách đảo.", 3)
    end,
}, "RefreshIslandButton")

sections.Teleport:Button({
    Name = "Teleport To Island",
    Callback = function()
        if not selectedIsland or not islandParts[selectedIsland] then
            notify("Lỗi", "Chưa chọn đảo hợp lệ!", 4)
            return
        end

        local player = Players.LocalPlayer
        local character = player.Character
        if not character then
            notify("Lỗi", "Không tìm thấy nhân vật!", 3)
            return
        end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        local targetPart = islandParts[selectedIsland]

        if not hrp or not targetPart then
            notify("Lỗi", "Không thể tìm HRP hoặc Part của đảo!", 3)
            return
        end

        hrp.CFrame = targetPart.CFrame + Vector3.new(0, 5, 0)
        notify("Teleport", "Đã dịch chuyển tới " .. selectedIsland, 4)
    end,
}, "TeleportToIslandButton")

tabs.Main:Select()

Window.onUnloaded(function()
    notify("Script Hub", "UI đã được đóng.", 3)
end)

MacLib:LoadAutoLoadConfig()

-- Auto Save Config
local function AutoSaveConfig()
    task.spawn(function()
        while task.wait(5) do
            pcall(ConfigSystem.SaveConfig)
        end
    end)
end

AutoSaveConfig()

-- Loop chính cho Auto Fish
task.spawn(function()
    while task.wait(0.5) do
        if autoFishEnabled then
            executeAutoFish()
    end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if autoSellEnabled then
            local delaySeconds = math.clamp(autoSellDelayMinutes or 10, 1, 60) * 60
            if os.clock() - lastAutoSell >= delaySeconds then
                lastAutoSell = os.clock()
                executeAutoSell()
            end
        end
    end
end)

-- Tạo icon floating để giả lập nút Left Alt cho mobile
task.spawn(function()
    local ok, errorMsg = pcall(function()
        if not getgenv().LoadedMobileUI == true then
            getgenv().LoadedMobileUI = true
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

            OpenUI.Name = "MobileUIButton"
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
        warn("Lỗi khi tạo nút Mobile UI: " .. tostring(errorMsg))
    end
end)

notify("Script Hub", "Script đã tải thành công!\nNhấn Left Alt hoặc icon để ẩn/hiện UI", 5)
print("Script Hub đã tải thành công!")
print("Sử dụng Left Alt hoặc icon floating để thu nhỏ/mở rộng UI")
