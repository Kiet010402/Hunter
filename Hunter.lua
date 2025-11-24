--// Services
local UserInputService = game:GetService("UserInputService")

--// Load UI Library với error handling
local Library = nil
local success, err = pcall(function()
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/lxte/lates-lib/main/Main.lua"))()
end)

if not success or not Library then
    warn("Lỗi khi tải UI Library: " .. tostring(err))
    return
end

-- Hệ thống lưu trữ cấu hình
local ConfigSystem = {}
ConfigSystem.FileName = "ScriptConfig_" .. game:GetService("Players").LocalPlayer.Name .. ".json"
ConfigSystem.DefaultConfig = {
    SavedPosition = nil, -- Lưu tọa độ {X, Y, Z}
    AutoFishEnabled = false
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

--// Themes
local Themes = {
    Light = {
        --// Frames:
        Primary = Color3.fromRGB(232, 232, 232),
        Secondary = Color3.fromRGB(255, 255, 255),
        Component = Color3.fromRGB(245, 245, 245),
        Interactables = Color3.fromRGB(235, 235, 235),
        --// Text:
        Tab = Color3.fromRGB(50, 50, 50),
        Title = Color3.fromRGB(0, 0, 0),
        Description = Color3.fromRGB(100, 100, 100),
        --// Outlines:
        Shadow = Color3.fromRGB(255, 255, 255),
        Outline = Color3.fromRGB(210, 210, 210),
        --// Image:
        Icon = Color3.fromRGB(100, 100, 100),
    },
    Dark = {
        --// Frames:
        Primary = Color3.fromRGB(30, 30, 30),
        Secondary = Color3.fromRGB(35, 35, 35),
        Component = Color3.fromRGB(40, 40, 40),
        Interactables = Color3.fromRGB(45, 45, 45),
        --// Text:
        Tab = Color3.fromRGB(200, 200, 200),
        Title = Color3.fromRGB(240, 240, 240),
        Description = Color3.fromRGB(200, 200, 200),
        --// Outlines:
        Shadow = Color3.fromRGB(0, 0, 0),
        Outline = Color3.fromRGB(40, 40, 40),
        --// Image:
        Icon = Color3.fromRGB(220, 220, 220),
    },
    Void = {
        --// Frames:
        Primary = Color3.fromRGB(15, 15, 15),
        Secondary = Color3.fromRGB(20, 20, 20),
        Component = Color3.fromRGB(25, 25, 25),
        Interactables = Color3.fromRGB(30, 30, 30),
        --// Text:
        Tab = Color3.fromRGB(200, 200, 200),
        Title = Color3.fromRGB(240, 240, 240),
        Description = Color3.fromRGB(200, 200, 200),
        --// Outlines:
        Shadow = Color3.fromRGB(0, 0, 0),
        Outline = Color3.fromRGB(40, 40, 40),
        --// Image:
        Icon = Color3.fromRGB(220, 220, 220),
    },
}

--// Create Window
local Window = Library:CreateWindow({
    Title = "DuongTuan Hub",
    Theme = "Dark",
    Size = UDim2.fromOffset(570, 370),
    Transparency = 0.2,
    Blurring = true,
    MinimizeKeybind = Enum.KeyCode.LeftAlt,
})

--// Set the default theme
Window:SetTheme(Themes.Dark)

--// Tab Sections
Window:AddTabSection({
    Name = "Main",
    Order = 1,
})

Window:AddTabSection({
    Name = "Settings",
    Order = 2,
})

--// Tab [MAIN]
local Main = Window:AddTab({
    Title = "Main",
    Section = "Main",
    Icon = "rbxassetid://13311802307"
})

--// Section: Auto Farm
Window:AddSection({ Name = "Auto Farm", Tab = Main })

-- Button Save Pos
Window:AddButton({
    Title = "Save Pos",
    Description = "Lưu tọa độ hiện tại",
    Tab = Main,
    Callback = function()
        local player = game:GetService("Players").LocalPlayer
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local hrp = character.HumanoidRootPart
            local pos = hrp.Position
            savedPosition = { pos.X, pos.Y, pos.Z }
            ConfigSystem.CurrentConfig.SavedPosition = savedPosition
            ConfigSystem.SaveConfig()

            Window:Notify({
                Title = "Save Pos",
                Description = string.format("Đã lưu tọa độ: X=%.2f, Y=%.2f, Z=%.2f", pos.X, pos.Y, pos.Z),
                Duration = 5
            })
        else
            Window:Notify({
                Title = "Lỗi",
                Description = "Không tìm thấy nhân vật!",
                Duration = 3
            })
        end
    end,
})

-- Hàm kiểm tra và di chuyển đến tọa độ đã lưu
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

    -- Kiểm tra khoảng cách (nếu cách xa hơn 5 studs thì di chuyển)
    local distance = (currentPos - targetPos).Magnitude
    if distance > 5 then
        hrp.CFrame = CFrame.new(targetPos)
        wait(0.5) -- Đợi một chút để đảm bảo di chuyển xong
        return true
    end

    return true
end

-- Hàm thực thi Auto Fish
local function executeAutoFish()
    if not autoFishEnabled then
        return
    end

    -- Kiểm tra và di chuyển đến tọa độ đã lưu nếu cần
    if savedPosition then
        moveToSavedPosition()
        wait(0.5)
    end

    local success, err = pcall(function()
        -- Bước 0: Equip Tool From Hotbar
        local args = {
            1
        }
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
        unpack(
            args))

        -- Bước 3: Đợi 4 giây rồi Fire Fishing Completed
        wait(4)
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild(
            "sleitnick_net@0.2.0"):WaitForChild("net"):WaitForChild("RE/FishingCompleted"):FireServer()
    end)

    if not success then
        warn("Lỗi Auto Fish: " .. tostring(err))
                end
            end
            
-- Toggle Auto Fish
Window:AddToggle({
    Title = "Auto Fish",
    Description = "Tự động câu cá",
    Tab = Main,
    Default = ConfigSystem.CurrentConfig.AutoFishEnabled or false,
    Callback = function(Boolean)
        autoFishEnabled = Boolean
        ConfigSystem.CurrentConfig.AutoFishEnabled = Boolean
        ConfigSystem.SaveConfig()

        if Boolean then
            if not savedPosition then
                Window:Notify({
                    Title = "Cảnh báo",
                    Description = "Chưa lưu tọa độ! Vui lòng Save Pos trước.",
                    Duration = 5
                })
            else
                Window:Notify({
                    Title = "Auto Fish",
                    Description = "Đã bật Auto Fish",
                    Duration = 3
                })
            end
        else
            Window:Notify({
                Title = "Auto Fish",
                Description = "Đã tắt Auto Fish",
                Duration = 3
            })
        end
    end,
})

--// Tab [SETTINGS]
local Settings = Window:AddTab({
    Title = "Settings",
    Section = "Settings",
    Icon = "rbxassetid://13311798537",
})

-- Thông tin Script
Window:AddParagraph({
    Title = "Thông tin Script",
    Description = "Script Hub v1.0\nNgười chơi: " .. playerName,
    Tab = Settings
})

Window:AddParagraph({
    Title = "Phím tắt",
    Description = "Nhấn Left Alt để ẩn/hiện giao diện",
    Tab = Settings
})

-- Theme Selector
Window:AddDropdown({
    Title = "Chọn Theme",
    Description = "Thay đổi giao diện",
    Tab = Settings,
    Options = {
        ["Light Mode"] = "Light",
        ["Dark Mode"] = "Dark",
        ["Extra Dark"] = "Void",
    },
    Callback = function(Theme)
        Window:SetTheme(Themes[Theme])
        Window:Notify({
            Title = "Theme",
            Description = "Đã đổi theme thành " .. Theme,
            Duration = 3
        })
    end,
})

-- Auto Save Config
local function AutoSaveConfig()
    spawn(function()
        while wait(5) do -- Lưu mỗi 5 giây
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
        wait(3) -- Đợi 3 giây giữa mỗi lần thực hiện

        if autoFishEnabled then
            executeAutoFish()
        end
                end
            end)
            
-- Tạo icon floating để giả lập nút Left Alt cho mobile
task.spawn(function()
    local success, errorMsg = pcall(function()
        if not getgenv().LoadedMobileUI == true then
            getgenv().LoadedMobileUI = true
            local OpenUI = Instance.new("ScreenGui")
            local ImageButton = Instance.new("ImageButton")
            local UICorner = Instance.new("UICorner")

            -- Kiểm tra môi trường
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
            ImageButton.Image = "rbxassetid://13099788281" -- Có thể thay đổi logo
            ImageButton.Draggable = true
            ImageButton.Transparency = 0.2

            UICorner.CornerRadius = UDim.new(0, 200)
            UICorner.Parent = ImageButton

            -- Hiệu ứng hover
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

            -- Khi click vào icon sẽ giả lập nút Left Alt
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

-- Thông báo khi tải xong
Window:Notify({
    Title = "Script Hub",
    Description = "Script đã tải thành công!\nNhấn Left Alt hoặc icon để ẩn/hiện UI",
    Duration = 5
})

print("Script Hub đã tải thành công!")
print("Sử dụng Left Alt hoặc icon floating để thu nhỏ/mở rộng UI")
