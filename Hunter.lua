--// Services
local UserInputService = game:GetService("UserInputService")

--// Load UI Library với error handling
local UILib = nil
local success, err = pcall(function()
    UILib = loadstring(game:HttpGet('https://raw.githubusercontent.com/StepBroFurious/Script/main/HydraHubUi.lua'))()
end)

if not success or not UILib then
    warn("Lỗi khi tải UI Library: " .. tostring(err))
    return
end

-- Hệ thống lưu trữ cấu hình
local HttpService = game:GetService("HttpService")
local ConfigSystem = {}
ConfigSystem.FileName = "ScriptConfig_" .. game:GetService("Players").LocalPlayer.Name .. ".json"
ConfigSystem.DefaultConfig = {
    SavedPosition = nil,
    AutoFishEnabled = false,
    SelectedPositionFile = nil
}
ConfigSystem.CurrentConfig = {}

-- Hàm để lưu cấu hình
ConfigSystem.SaveConfig = function()
    local success, err = pcall(function()
        writefile(ConfigSystem.FileName, game:GetService("HttpService"):JSONEncode(ConfigSystem.CurrentConfig))
    end)
    if success then
        print("Đã lưu cấu hình thành công!")
    else
        warn("Lưu cấu hình thất bại:", err)
    end
end

-- Hàm để tải cấu hình
ConfigSystem.LoadConfig = function()
    local success, content = pcall(function()
        if isfile(ConfigSystem.FileName) then
            return readfile(ConfigSystem.FileName)
        end
        return nil
    end)

    if success and content then
        local data = game:GetService("HttpService"):JSONDecode(content)
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
local playerName = game:GetService("Players").LocalPlayer.Name

-- Biến lưu trạng thái Auto Fish
local autoFishEnabled = ConfigSystem.CurrentConfig.AutoFishEnabled or false
local savedPosition = ConfigSystem.CurrentConfig.SavedPosition
local selectedPositionFile = ConfigSystem.CurrentConfig.SelectedPositionFile

-- Thư mục lưu vị trí
local PositionsFolder = "ScriptHub_Positions"
pcall(function()
    if makefolder and isfolder and not isfolder(PositionsFolder) then
        makefolder(PositionsFolder)
    end
end)

local positionNameInput = ""
local positionOptions = {}

-- Hàm sanitize tên file
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

local function getPositionFiles()
    local files = {}

    if not listfiles then
        return files
    end

    local success, list = pcall(function()
        return listfiles(PositionsFolder)
    end)

    if success and list then
        for _, path in ipairs(list) do
            if path:sub(-4):lower() == ".txt" then
                local name = getFileNameFromPath(path)
                table.insert(files, name)
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

    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if success and data and data.X and data.Y and data.Z then
        return { data.X, data.Y, data.Z }
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

    local path = PositionsFolder .. "/" .. fileName
    local payload = {
        X = position[1],
        Y = position[2],
        Z = position[3]
    }

    local success = pcall(function()
        writefile(path, HttpService:JSONEncode(payload))
    end)

    return success
end

local function buildDropdownOptions(files)
    local opts = {}
    for _, name in ipairs(files) do
        opts[name] = name
    end
    return opts
end

-- Tải tọa độ từ file đang chọn nếu có
if selectedPositionFile then
    savedPosition = readPositionFromFile(selectedPositionFile) or savedPosition
end

--// Tạo Hydra Hub UI
local Window = UILib.new("DuongTuan Hub", game.Players.LocalPlayer.UserId, "Main")

--// Tab chính
local MainCategory = Window:Category("Auto Farm", "http://www.roblox.com/asset/?id=8395621517")
local MainButton = MainCategory:Button("Fishing", "http://www.roblox.com/asset/?id=8395747586")
local MainSection = MainButton:Section("Main", "Left")

-- Input: Name Position
MainSection:Textbox({
    Title = "Name Position",
    Description = "Nhập tên file vị trí (không cần .txt)",
    Default = "",
}, function(value)
    positionNameInput = value or ""
end)

-- Button: Create Position
MainSection:Button({
    Title = "Create Position",
    ButtonName = "CREATE",
    Description = "Tạo file .txt để lưu tọa độ",
}, function()
    local sanitized = sanitizeFileName(positionNameInput)
    if not sanitized then
        print("Lỗi: Vui lòng nhập tên vị trí hợp lệ!")
        return
    end

    local fileName = sanitized
    if not fileName:lower():match("%.txt$") then
        fileName = fileName .. ".txt"
    end

    local path = PositionsFolder .. "/" .. fileName
    if isfile and isfile(path) then
        print("Thông báo: File này đã tồn tại!")
        return
    end

    local defaultPosition = { 0, 0, 0 }
    if savePositionToFile(fileName, defaultPosition) then
        print("Create Position: Đã tạo file: " .. fileName)
    else
        print("Lỗi: Không thể tạo file! (thiếu quyền?)")
    end
end)

-- Button: Save Pos
MainSection:Button({
    Title = "Save Position",
    ButtonName = "SAVE",
    Description = "Lưu tọa độ hiện tại",
}, function()
    if not selectedPositionFile then
        print("Lỗi: Chưa chọn file vị trí! Hãy dùng dropdown.")
        return
    end

    local player = game:GetService("Players").LocalPlayer
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local hrp = character.HumanoidRootPart
        local pos = hrp.Position
        savedPosition = { pos.X, pos.Y, pos.Z }
        ConfigSystem.CurrentConfig.SavedPosition = savedPosition
        ConfigSystem.SaveConfig()

        if savePositionToFile(selectedPositionFile, savedPosition) then
            print(string.format("Save Pos: Đã lưu tọa độ vào %s\nX=%.2f, Y=%.2f, Z=%.2f", selectedPositionFile, pos.X, pos.Y, pos.Z))
        else
            print("Lỗi: Không thể ghi file vị trí!")
        end
    else
        print("Lỗi: Không tìm thấy nhân vật!")
    end
end)

-- Dropdown: Select Position (tạo động từ file có sẵn)
local positionDropdownUI = MainSection:Dropdown({
    Title = "Select Position",
    Description = "Chọn file tọa độ để sử dụng",
    Default = selectedPositionFile or "None",
    Options = getPositionFiles()
}, function(value)
    if not value or value == "None" or value == "" then
        selectedPositionFile = nil
        ConfigSystem.CurrentConfig.SelectedPositionFile = nil
        savedPosition = nil
        return
    end

    selectedPositionFile = value
    ConfigSystem.CurrentConfig.SelectedPositionFile = value
    ConfigSystem.SaveConfig()

    savedPosition = readPositionFromFile(value)
    if savedPosition then
        print("Select Position: Đang sử dụng file: " .. value)
    else
        print("Thông báo: File chưa có tọa độ! Hãy Save Pos.")
    end
end)

-- Toggle: Auto Fish
MainSection:Toggle({
    Title = "Auto Fish",
    Description = "Tự động câu cá",
    Default = ConfigSystem.CurrentConfig.AutoFishEnabled or false
}, function(value)
    autoFishEnabled = value
    ConfigSystem.CurrentConfig.AutoFishEnabled = value
    ConfigSystem.SaveConfig()

    if value then
        if not selectedPositionFile then
            print("Cảnh báo: Chưa chọn file vị trí! Vui lòng tạo/chọn file.")
            return
        end

        if not savedPosition then
            print("Cảnh báo: File chưa có tọa độ! Vui lòng Save Pos trước.")
        else
            print("Auto Fish: Đã bật Auto Fish")
        end
    else
        print("Auto Fish: Đã tắt Auto Fish")
    end
end)

--// Tab Settings
local SettingsCategory = Window:Category("Settings", "http://www.roblox.com/asset/?id=8395621517")
local SettingsButton = SettingsCategory:Button("General", "http://www.roblox.com/asset/?id=8395747586")
local SettingsSection = SettingsButton:Section("Settings", "Left")

-- Label: Script Info
SettingsSection:Label("Script Hub v1.0")
SettingsSection:Label("Người chơi: " .. playerName)
SettingsSection:Label("Nhấn Left Alt để ẩn/hiện giao diện")

--// Hàm kiểm tra và di chuyển đến tọa độ đã lưu
local function moveToSavedPosition()
    if not savedPosition then
        return false
    end

    local player = game:GetService("Players").LocalPlayer
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local hrp = character.HumanoidRootPart
    local currentPos = hrp.Position
    local targetPos = Vector3.new(savedPosition[1], savedPosition[2], savedPosition[3])

    local distance = (currentPos - targetPos).Magnitude
    if distance > 5 then
        hrp.CFrame = CFrame.new(targetPos)
        wait(0.5)
        return true
    end

    return true
end

--// Hàm thực thi Auto Fish
local function executeAutoFish()
    if not autoFishEnabled or not selectedPositionFile or not savedPosition then
        return
    end

    if savedPosition then
        moveToSavedPosition()
        wait(0.5)
    end

    local success, err = pcall(function()
        -- Bước 0: Equip Tool From Hotbar
        local args = { 1 }
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild(
            "sleitnick_net@0.2.0"):WaitForChild("net"):WaitForChild("RE/EquipToolFromHotbar"):FireServer(unpack(args))

        -- Bước 1: Charge Fishing Rod
        wait(0.5)
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild(
            "sleitnick_net@0.2.0"):WaitForChild("net"):WaitForChild("RF/ChargeFishingRod"):InvokeServer()

        -- Bước 2: Đợi 1 giây rồi Request Fishing Minigame
        wait(1)
        local args = {
            -1.233184814453125,
            0.9940152067553181,
            1763908713.407927
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild(
            "sleitnick_net@0.2.0"):WaitForChild("net"):WaitForChild("RF/RequestFishingMinigameStarted"):InvokeServer(
            unpack(args))

        -- Bước 3: Đợi 3 giây rồi Fire Fishing Completed
        wait(3)
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild(
            "sleitnick_net@0.2.0"):WaitForChild("net"):WaitForChild("RE/FishingCompleted"):FireServer()
    end)

    if not success then
        warn("Lỗi Auto Fish: " .. tostring(err))
    end
end

-- Auto Save Config
local function AutoSaveConfig()
    spawn(function()
        while wait(5) do
            pcall(function()
                ConfigSystem.SaveConfig()
            end)
        end
    end)
end

-- Thực thi tự động lưu cấu hình
AutoSaveConfig()

-- Loop chính cho Auto Fish
spawn(function()
    while true do
        wait(1)

        if autoFishEnabled then
            executeAutoFish()
        end
    end
end)

-- Tạo icon floating cho mobile
task.spawn(function()
    local success, errorMsg = pcall(function()
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
            ImageButton.Image = "rbxassetid://13099788281"
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
                wait(0.1)
                game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.LeftAlt, false, game)
            end)
        end
    end)

    if not success then
        warn("Lỗi khi tạo nút Mobile UI: " .. tostring(errorMsg))
    end
end)

print("Script Hub đã tải thành công!")
print("Sử dụng Left Alt hoặc icon floating để thu nhỏ/mở rộng UI")
