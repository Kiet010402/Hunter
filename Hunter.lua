-- Load UI Library với error handling
local success, err = pcall(function()
    Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
    SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
    InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
end)

if not success then
    warn("Lỗi khi tải UI Library: " .. tostring(err))
    return
end

-- Đợi đến khi Fluent được tải hoàn tất
if not Fluent then
    warn("Không thể tải thư viện Fluent!")
    return
end

-- Hệ thống lưu trữ cấu hình
local ConfigSystem = {}
ConfigSystem.FileName = "HTHubFishIt_" .. game:GetService("Players").LocalPlayer.Name .. ".json"
ConfigSystem.DefaultConfig = {
    -- Auto Farm Settings
    savedPosition = nil, -- {x, y, z}
    autoFishEnabled = false
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

-- Biến lưu trạng thái của tab Main


-- Lấy tên người chơi
local playerName = game:GetService("Players").LocalPlayer.Name

-- Cấu hình UI
local Window = Fluent:CreateWindow({
    Title = "HT HUB | Fish It",
    SubTitle = nil,
    TabWidth = 80,
    Size = UDim2.fromOffset(300, 220),
    Acrylic = true,
    Theme = "Amethyst",
    MinimizeKey = Enum.KeyCode.LeftControl
})

if not Window then
    warn("Không thể tạo Window!")
    return
end

-- Hệ thống Tạo Tab

-- Tạo Tab Main
local MainTab = Window:AddTab({ Title = "Farm", Icon = "rbxassetid://13311802307" })
-- Tạo Tab Settings
local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "rbxassetid://13311798537" })

if not MainTab then
    warn("Không thể tạo MainTab!")
    return
end

if not SettingsTab then
    warn("Không thể tạo SettingsTab!")
    return
end

-- Tab Main
-- Section Auto Farm trong tab Main
local AutoFarmSection = MainTab:AddSection("Auto Farm")

if not AutoFarmSection then
    warn("Không thể tạo AutoFarmSection!")
    return
end

-- Lấy LocalPlayer và Character
local LocalPlayer = game:GetService("Players").LocalPlayer
local Character = nil
local HumanoidRootPart = nil

-- Hàm để đảm bảo Character được load
local function ensureCharacter()
    if not Character or not Character.Parent then
        Character = LocalPlayer.Character
        if not Character then
            Character = LocalPlayer.CharacterAdded:Wait()
        end
        HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 10)
    end
    return Character ~= nil and HumanoidRootPart ~= nil
end

-- Khởi tạo Character
task.spawn(function()
    ensureCharacter()
end)

-- Hàm di chuyển đến vị trí
local function moveToPosition(targetPosition, tolerance)
    if not ensureCharacter() then return false end
    tolerance = tolerance or 3
    local humanoid = Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    local startTime = tick()
    local maxTime = 10 -- Tối đa 10 giây để di chuyển
    
    while (HumanoidRootPart.Position - targetPosition).Magnitude > tolerance do
        if tick() - startTime > maxTime then
            return false -- Timeout
        end
        
        humanoid:MoveTo(targetPosition)
        task.wait(0.1)
        
        -- Kiểm tra nếu character bị thay đổi
        if not ensureCharacter() then return false end
        humanoid = Character:FindFirstChild("Humanoid")
        if not humanoid then return false end
    end
    
    return true
end

-- Hàm thực thi Auto Fish
local function executeFishing()
    if not ensureCharacter() or not HumanoidRootPart then
        warn("Không thể thực thi fishing: Character chưa sẵn sàng")
        return false
    end
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
    
    -- Bước 1: Charge Fishing Rod
    local success1, err1 = pcall(function()
        net:WaitForChild("RF/ChargeFishingRod"):InvokeServer()
    end)
    
    if not success1 then
        warn("Lỗi Bước 1 - ChargeFishingRod:", err1)
        return false
    end
    
    -- Đợi 1 giây
    task.wait(1)
    
    -- Bước 2: Request Fishing Minigame
    local success2, err2 = pcall(function()
        if ConfigSystem.CurrentConfig.savedPosition then
            local pos = ConfigSystem.CurrentConfig.savedPosition
            local args = {
                pos.x,
                pos.y,
                pos.z
            }
            net:WaitForChild("RF/RequestFishingMinigameStarted"):InvokeServer(unpack(args))
        else
            -- Nếu chưa có vị trí lưu, sử dụng vị trí hiện tại
            if not ensureCharacter() or not HumanoidRootPart then
                return false
            end
            local currentPos = HumanoidRootPart.Position
            local args = {
                currentPos.X,
                currentPos.Y,
                currentPos.Z
            }
            net:WaitForChild("RF/RequestFishingMinigameStarted"):InvokeServer(unpack(args))
        end
    end)
    
    if not success2 then
        warn("Lỗi Bước 2 - RequestFishingMinigameStarted:", err2)
        return false
    end
    
    -- Đợi 1.5 giây
    task.wait(1.5)
    
    -- Bước 3: Fishing Completed
    local success3, err3 = pcall(function()
        net:WaitForChild("RE/FishingCompleted"):FireServer()
    end)
    
    if not success3 then
        warn("Lỗi Bước 3 - FishingCompleted:", err3)
        return false
    end
    
    return true
end

-- Biến để kiểm soát Auto Fish loop
local autoFishRunning = false

-- Button Save Pos
local SavePosButton = AutoFarmSection:AddButton({
    Title = "Save Pos",
    Description = "Lưu vị trí hiện tại",
    Callback = function()
        if ensureCharacter() and HumanoidRootPart then
            local currentPos = HumanoidRootPart.Position
            ConfigSystem.CurrentConfig.savedPosition = {
                x = currentPos.X,
                y = currentPos.Y,
                z = currentPos.Z
            }
            ConfigSystem.SaveConfig()
            print("Đã lưu vị trí: X=" .. currentPos.X .. ", Y=" .. currentPos.Y .. ", Z=" .. currentPos.Z)
        else
            warn("Không thể lưu vị trí: Character chưa sẵn sàng")
        end
    end
})

-- Hàm để bật/tắt Auto Fish
local function setAutoFish(enabled)
    ConfigSystem.CurrentConfig.autoFishEnabled = enabled
    ConfigSystem.SaveConfig()
    
    if enabled then
        -- Bật Auto Fish
        autoFishRunning = true
        task.spawn(function()
            while autoFishRunning do
                -- Kiểm tra và cập nhật Character nếu cần
                if ensureCharacter() then
                    -- Kiểm tra nếu có vị trí đã lưu
                    if ConfigSystem.CurrentConfig.savedPosition then
                        local savedPos = ConfigSystem.CurrentConfig.savedPosition
                        local targetPosition = Vector3.new(savedPos.x, savedPos.y, savedPos.z)
                        local currentPos = HumanoidRootPart.Position
                        
                        -- Kiểm tra khoảng cách (tolerance 3 studs)
                        if (currentPos - targetPosition).Magnitude > 3 then
                            -- Di chuyển đến vị trí đã lưu
                            moveToPosition(targetPosition, 3)
                            task.wait(0.5) -- Đợi một chút sau khi di chuyển
                        end
                    end
                    
                    -- Thực thi fishing
                    executeFishing()
                    
                    -- Đợi một chút trước khi lặp lại
                    task.wait(1)
                else
                    -- Đợi nếu Character chưa sẵn sàng
                    task.wait(1)
                end
            end
        end)
    else
        -- Tắt Auto Fish
        autoFishRunning = false
    end
end

-- Toggle Auto Fish
local AutoFishToggle = AutoFarmSection:AddToggle({
    Title = "Auto Fish",
    Description = "Tự động câu cá",
    Default = ConfigSystem.CurrentConfig.autoFishEnabled or false,
    Callback = function(value)
        setAutoFish(value)
    end
})

-- Cập nhật lại Character khi respawn
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    if Character then
        HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 10)
    end
end)

-- Tự động bật Auto Fish nếu đã được lưu trong config
task.spawn(function()
    task.wait(1) -- Đợi một chút để đảm bảo mọi thứ đã sẵn sàng
    if ConfigSystem.CurrentConfig.autoFishEnabled then
        setAutoFish(true)
    end
end)

-- Settings tab configuration
local SettingsSection = SettingsTab:AddSection("Script Settings")

-- Integration with SaveManager
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Thay đổi cách lưu cấu hình để sử dụng tên người chơi
InterfaceManager:SetFolder("HTHubFishIt")
SaveManager:SetFolder("HTHubFishIt/" .. playerName)

-- Thêm thông tin vào tab Settings
SettingsTab:AddParagraph({
    Title = "Cấu hình tự động",
    Content = "Cấu hình của bạn đang được tự động lưu theo tên nhân vật: " .. playerName
})

SettingsTab:AddParagraph({
    Title = "Phím tắt",
    Content = "Nhấn LeftControl để ẩn/hiện giao diện"
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

-- Thêm event listener để lưu ngay khi thay đổi giá trị
local function setupSaveEvents()
    for _, tab in pairs({MainTab, SettingsTab}) do
        if tab and tab._components then
            for _, element in pairs(tab._components) do
                if element and element.OnChanged then
                    element.OnChanged:Connect(function()
                        pcall(function()
                            ConfigSystem.SaveConfig()
                        end)
                    end)
                end
            end
        end
    end
end

-- Thiết lập events
setupSaveEvents()

-- Tạo logo để mở lại UI khi đã minimize
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
            
            OpenUI.Name = "OpenUI"
            OpenUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            
            ImageButton.Parent = OpenUI
            ImageButton.BackgroundColor3 = Color3.fromRGB(105,105,105)
            ImageButton.BackgroundTransparency = 0.8
            ImageButton.Position = UDim2.new(0.9,0,0.1,0)
            ImageButton.Size = UDim2.new(0,50,0,50)
            ImageButton.Image = "rbxassetid://13099788281" -- Logo HT Hub
            ImageButton.Draggable = true
            ImageButton.Transparency = 0.2
            
            UICorner.CornerRadius = UDim.new(0,200)
            UICorner.Parent = ImageButton
            
            -- Khi click vào logo sẽ mở lại UI
            ImageButton.MouseButton1Click:Connect(function()
                game:GetService("VirtualInputManager"):SendKeyEvent(true,Enum.KeyCode.LeftControl,false,game)
            end)
        end
    end)
    
    if not success then
        warn("Lỗi khi tạo nút Logo UI: " .. tostring(errorMsg))
    end
end)

print("HT Hub Fish It Script đã tải thành công!")
print("Sử dụng Left Ctrl để thu nhỏ/mở rộng UI")
