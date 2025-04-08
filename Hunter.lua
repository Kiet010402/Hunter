-- Hunter.lua
-- Modern UI using Orion Library for Hunters Game

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Player reference
local player = Players.LocalPlayer
local playerName = player.Name
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Config System integration with AutoSave
local AutoSaveSystem = loadstring(readfile("AutoSave.lua"))()

-- Set up configuration specific to Hunter
AutoSaveSystem.FolderPath = "KaihonScriptHub/Hunter"
AutoSaveSystem.DefaultConfig = {
    AutoRoll = false,
    RollDelay = 1,
    AutoAttack = false,
    AttackDelay = 1,
    SelectedMap = "",
    AutoFarm = false,
    TeleportDistance = 5,
    SelectedMob = "All Mobs"
}

-- Initialize AutoSave
AutoSaveSystem.Init()

-- Initialize Orion
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()

-- Create Window
local Window = OrionLib:MakeWindow({
    Name = "KaihonHub | Hunter", 
    HidePremium = true,
    SaveConfig = false, -- Use our custom save system
    ConfigFolder = "",
    IntroEnabled = true,
    IntroText = "KaihonHub",
    IntroIcon = "rbxassetid://4483345998",
    Icon = "rbxassetid://4483345998"
})

-- Create Main Tab
local MainTab = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

-- Create Map Tab
local MapTab = Window:MakeTab({
    Name = "Map",
    Icon = "rbxassetid://9288394834",
    PremiumOnly = false
})

-- Create Play Tab
local PlayTab = Window:MakeTab({
    Name = "Play",
    Icon = "rbxassetid://4483362927",
    PremiumOnly = false
})

-- Create Config Tab
local ConfigTab = Window:MakeTab({
    Name = "Config",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Main Tab Content
local MainSection = MainTab:AddSection({
    Name = "Roll Settings"
})

-- Roll counters and connections
local rollConnection = nil
local rollCount = 0

-- Auto Roll Toggle
MainTab:AddToggle({
    Name = "Auto Roll",
    Default = AutoSaveSystem.GetData("AutoRoll") or false,
    Flag = "AutoRoll",
    Save = false,
    Callback = function(Value)
        if Value then
            -- Start auto roll
            if rollConnection then rollConnection:Disconnect() end
            
            rollConnection = RunService.Heartbeat:Connect(function()
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Roll"):InvokeServer()
                task.wait(AutoSaveSystem.GetData("RollDelay") or 1) -- Use saved delay
            end)
            
            OrionLib:MakeNotification({
                Name = "Auto Roll Enabled",
                Content = "Now automatically rolling...",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        else
            -- Stop auto roll
            if rollConnection then 
                rollConnection:Disconnect()
                rollConnection = nil
                
                OrionLib:MakeNotification({
                    Name = "Auto Roll Disabled",
                    Content = "Auto roll has been stopped",
                    Image = "rbxassetid://4483345998",
                    Time = 3
                })
            end
        end
        
        -- Save to config
        AutoSaveSystem.UpdateData("AutoRoll", Value)
    end
})

-- Roll Delay Slider
MainTab:AddSlider({
    Name = "Roll Delay (seconds)",
    Min = 0.1,
    Max = 5,
    Default = AutoSaveSystem.GetData("RollDelay") or 1,
    Color = Color3.fromRGB(255, 185, 0),
    Increment = 0.1,
    ValueName = "seconds",
    Flag = "RollDelay",
    Save = false,
    Callback = function(Value)
        OrionLib:MakeNotification({
            Name = "Roll Delay Updated",
            Content = "New delay: " .. Value .. " seconds",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
        
        -- Save to config
        AutoSaveSystem.UpdateData("RollDelay", Value)
    end
})

-- Manual Roll Button
MainTab:AddButton({
    Name = "Manual Roll",
    Callback = function()
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Roll"):InvokeServer()
        
        -- Update roll count
        rollCount = rollCount + 1
        
        OrionLib:MakeNotification({
            Name = "Manual Roll",
            Content = "Roll executed!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- Attack Section
local AttackSection = MainTab:AddSection({
    Name = "Attack Settings"
})

-- Attack counters and connections
local attackConnection = nil
local attackCount = 0

-- Auto Attack Toggle
MainTab:AddToggle({
    Name = "Auto Attack",
    Default = AutoSaveSystem.GetData("AutoAttack") or false,
    Flag = "AutoAttack",
    Save = false,
    Callback = function(Value)
        if Value then
            -- Start auto attack
            if attackConnection then attackConnection:Disconnect() end
            
            attackConnection = RunService.Heartbeat:Connect(function()
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Combat"):FireServer()
                task.wait(AutoSaveSystem.GetData("AttackDelay") or 1) -- Use saved delay
            end)
            
            OrionLib:MakeNotification({
                Name = "Auto Attack Enabled",
                Content = "Now automatically attacking...",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        else
            -- Stop auto attack
            if attackConnection then 
                attackConnection:Disconnect()
                attackConnection = nil
                
                OrionLib:MakeNotification({
                    Name = "Auto Attack Disabled",
                    Content = "Auto attack has been stopped",
                    Image = "rbxassetid://4483345998",
                    Time = 3
                })
            end
        end
        
        -- Save to config
        AutoSaveSystem.UpdateData("AutoAttack", Value)
    end
})

-- Attack Delay Slider
MainTab:AddSlider({
    Name = "Attack Delay (seconds)",
    Min = 0.1,
    Max = 5,
    Default = AutoSaveSystem.GetData("AttackDelay") or 1,
    Color = Color3.fromRGB(255, 0, 0),
    Increment = 0.1,
    ValueName = "seconds",
    Flag = "AttackDelay",
    Save = false,
    Callback = function(Value)
        OrionLib:MakeNotification({
            Name = "Attack Delay Updated",
            Content = "New delay: " .. Value .. " seconds",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
        
        -- Save to config
        AutoSaveSystem.UpdateData("AttackDelay", Value)
    end
})

-- Manual Attack Button
MainTab:AddButton({
    Name = "Manual Attack",
    Callback = function()
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Combat"):FireServer()
        
        -- Update attack count
        attackCount = attackCount + 1
        
        OrionLib:MakeNotification({
            Name = "Manual Attack",
            Content = "Attack executed!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- Status Section
local StatusSection = MainTab:AddSection({
    Name = "Status"
})

-- Create Stats
MainTab:AddParagraph("Player Statistics", "Player: " .. playerName .. 
                     "\nRolls: " .. rollCount .. 
                     "\nAttacks: " .. attackCount)

-- Function to update status paragraph
local function updateStatsParagraph()
    MainTab:AddParagraph("Player Statistics", "Player: " .. playerName .. 
                         "\nRolls: " .. rollCount .. 
                         "\nAttacks: " .. attackCount)
end

-- Update stats every second
task.spawn(function()
    while true do
        updateStatsParagraph()
        task.wait(1)
    end
end)

-- Map Tab Content
local MapSelectionSection = MapTab:AddSection({
    Name = "Map Selection"
})

-- Map selection variable
local selectedMap = AutoSaveSystem.GetData("SelectedMap") or ""
local mapCodes = {
    ["SINGULARITY"] = "DoubleDungeonD",
    ["GOBLIN CAVES"] = "GoblinCave",
    ["SPIDER CAVERN"] = "SpiderCavern"
}

-- Map Dropdown
MapTab:AddDropdown({
    Name = "Select Map",
    Default = selectedMap ~= "" and selectedMap or nil,
    Options = {"SINGULARITY", "GOBLIN CAVES", "SPIDER CAVERN"},
    Flag = "SelectedMap",
    Save = false,
    Callback = function(Option)
        selectedMap = Option
        OrionLib:MakeNotification({
            Name = "Map Selected",
            Content = "You selected: " .. selectedMap,
            Image = "rbxassetid://4483345998",
            Time = 2
        })
        
        -- Save to config
        AutoSaveSystem.UpdateData("SelectedMap", selectedMap)
        
        -- Update current map paragraph
        MapTab:AddParagraph("Current Map", "Selected Map: " .. Option)
    end
})

-- Current Map display
MapTab:AddParagraph("Current Map", "Selected Map: " .. (selectedMap ~= "" and selectedMap or "None"))

-- Map Control Section
local MapControlSection = MapTab:AddSection({
    Name = "Map Controls"
})

-- Start Map Button
MapTab:AddButton({
    Name = "Start Map",
    Callback = function()
        if selectedMap == "" then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Please select a map first!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
            return
        end
        
        -- Create the lobby with selected map
        local mapCode = mapCodes[selectedMap]
        local args = {
            [1] = mapCode
        }
        
        -- Create lobby
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("createLobby"):InvokeServer(unpack(args))
        
        -- Start the lobby
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("LobbyStart"):FireServer()
        
        OrionLib:MakeNotification({
            Name = "Map Started",
            Content = "Starting " .. selectedMap .. "...",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
    end
})

-- Create Lobby Button
MapTab:AddButton({
    Name = "Create Lobby Only",
    Callback = function()
        if selectedMap == "" then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Please select a map first!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
            return
        end
        
        -- Create the lobby with selected map
        local mapCode = mapCodes[selectedMap]
        local args = {
            [1] = mapCode
        }
        
        -- Create lobby
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("createLobby"):InvokeServer(unpack(args))
        
        OrionLib:MakeNotification({
            Name = "Lobby Created",
            Content = "Created lobby for " .. selectedMap,
            Image = "rbxassetid://4483345998",
            Time = 3
        })
    end
})

-- Start Lobby Button
MapTab:AddButton({
    Name = "Start Lobby Only",
    Callback = function()
        -- Start the lobby
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("LobbyStart"):FireServer()
        
        OrionLib:MakeNotification({
            Name = "Lobby Started",
            Content = "Starting lobby...",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
    end
})

-- Play Tab Content
local FarmSection = PlayTab:AddSection({
    Name = "Auto Farm"
})

-- Available mobs
local mobList = {"All Mobs", "Golem Mage"}
local selectedMob = AutoSaveSystem.GetData("SelectedMob") or "All Mobs"

-- Mob selection dropdown
PlayTab:AddDropdown({
    Name = "Select Target",
    Default = selectedMob,
    Options = mobList,
    Flag = "SelectedMob",
    Save = false,
    Callback = function(Option)
        selectedMob = Option
        OrionLib:MakeNotification({
            Name = "Target Selected",
            Content = "Now targeting: " .. selectedMob,
            Image = "rbxassetid://4483345998",
            Time = 2
        })
        
        -- Save to config
        AutoSaveSystem.UpdateData("SelectedMob", selectedMob)
    end
})

-- Teleport distance slider
PlayTab:AddSlider({
    Name = "Teleport Distance",
    Min = 0,
    Max = 10,
    Default = AutoSaveSystem.GetData("TeleportDistance") or 5,
    Color = Color3.fromRGB(0, 170, 255),
    Increment = 0.5,
    ValueName = "studs",
    Flag = "TeleportDistance",
    Save = false,
    Callback = function(Value)
        OrionLib:MakeNotification({
            Name = "Distance Updated",
            Content = "New teleport distance: " .. Value .. " studs",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
        
        -- Save to config
        AutoSaveSystem.UpdateData("TeleportDistance", Value)
    end
})

-- Farm variables
local farmConnection = nil
local mobsKilled = 0
local farmStartTime = 0
local farmTimeUpdateConnection = nil

-- Farm toggle
PlayTab:AddToggle({
    Name = "Auto Farm",
    Default = AutoSaveSystem.GetData("AutoFarm") or false,
    Flag = "AutoFarm",
    Save = false,
    Callback = function(Value)
        -- Get the character and humanoid root part
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        
        if Value then
            -- Start farm timer
            farmStartTime = os.time()
            
            -- Start auto farm
            if farmConnection then farmConnection:Disconnect() end
            
            farmConnection = RunService.Heartbeat:Connect(function()
                -- Find mobs
                local mobsFolder = workspace:FindFirstChild("Mobs")
                if not mobsFolder then
                    OrionLib:MakeNotification({
                        Name = "Error",
                        Content = "Mobs folder not found!",
                        Image = "rbxassetid://4483345998",
                        Time = 3
                    })
                    PlayTab:UpdateToggle("AutoFarm", false)
                    return
                end
                
                local targetMob = nil
                
                -- Choose target based on selection
                if selectedMob == "All Mobs" then
                    -- Find the closest mob
                    local closestDistance = math.huge
                    for _, mob in pairs(mobsFolder:GetChildren()) do
                        if mob:FindFirstChild("HumanoidRootPart") then
                            local distance = (mob.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
                            if distance < closestDistance then
                                closestDistance = distance
                                targetMob = mob
                            end
                        end
                    end
                else
                    -- Find the selected mob type
                    if mobsFolder:FindFirstChild(selectedMob) and mobsFolder[selectedMob]:FindFirstChild("HumanoidRootPart") then
                        targetMob = mobsFolder[selectedMob]
                    end
                end
                
                -- Teleport to mob if found
                if targetMob and targetMob:FindFirstChild("HumanoidRootPart") then
                    local teleportDistance = AutoSaveSystem.GetData("TeleportDistance") or 5
                    local mobPosition = targetMob.HumanoidRootPart.Position
                    local direction = (humanoidRootPart.Position - mobPosition).Unit
                    local targetPosition = mobPosition + (direction * teleportDistance)
                    
                    -- Teleport to the mob with offset
                    humanoidRootPart.CFrame = CFrame.new(targetPosition, mobPosition)
                    
                    -- Auto attack if enabled
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Combat"):FireServer()
                    task.wait(0.5) -- Small delay to prevent overwhelming the server
                end
            end)
            
            -- Start farm time update
            if farmTimeUpdateConnection then
                farmTimeUpdateConnection:Disconnect()
            end
            
            farmTimeUpdateConnection = RunService.Heartbeat:Connect(function()
                local elapsedTime = os.time() - farmStartTime
                local minutes = math.floor(elapsedTime / 60)
                local seconds = elapsedTime % 60
                PlayTab:UpdateParagraph("Farm Statistics", "Mobs Killed: " .. mobsKilled .. 
                                     "\nFarm Time: " .. minutes .. "m " .. seconds .. "s")
                task.wait(1) -- Update every second
            end)
            
            OrionLib:MakeNotification({
                Name = "Auto Farm Enabled",
                Content = "Now farming: " .. selectedMob,
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        else
            -- Stop auto farm
            if farmConnection then 
                farmConnection:Disconnect()
                farmConnection = nil
            end
            
            -- Stop farm timer
            if farmTimeUpdateConnection then
                farmTimeUpdateConnection:Disconnect()
                farmTimeUpdateConnection = nil
            end
            
            OrionLib:MakeNotification({
                Name = "Auto Farm Disabled",
                Content = "Auto farming has been stopped",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
        
        -- Save to config
        AutoSaveSystem.UpdateData("AutoFarm", Value)
    end
})

-- Stats section for farming
local FarmStatsSection = PlayTab:AddSection({
    Name = "Farm Stats"
})

-- Farm statistics paragraph
PlayTab:AddParagraph("Farm Statistics", "Mobs Killed: 0\nFarm Time: 0m 0s")

-- Reset Stats Button
PlayTab:AddButton({
    Name = "Reset Farm Stats",
    Callback = function()
        mobsKilled = 0
        farmStartTime = os.time()
        PlayTab:UpdateParagraph("Farm Statistics", "Mobs Killed: 0\nFarm Time: 0m 0s")
        
        OrionLib:MakeNotification({
            Name = "Stats Reset",
            Content = "Farm statistics have been reset",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- Add auto farm mob kill counter
local function hookMobDeath()
    local mobsFolder = workspace:FindFirstChild("Mobs")
    if mobsFolder then
        mobsFolder.ChildRemoved:Connect(function(child)
            if AutoSaveSystem.GetData("AutoFarm") then
                mobsKilled = mobsKilled + 1
                PlayTab:UpdateParagraph("Farm Statistics", "Mobs Killed: " .. mobsKilled .. 
                                     "\nFarm Time: " .. 
                                     math.floor((os.time() - farmStartTime) / 60) .. "m " .. 
                                     (os.time() - farmStartTime) % 60 .. "s")
            end
        end)
    end
end

-- Try to hook mob deaths when the script loads
hookMobDeath()

-- Try again when the workspace children change
workspace.ChildAdded:Connect(function(child)
    if child.Name == "Mobs" then
        task.wait(1) -- Small delay to ensure the folder is properly set up
        hookMobDeath()
    end
end)

-- Config Tab Content
local ConfigSection = ConfigTab:AddSection({
    Name = "Configuration"
})

-- Save Config Button
ConfigTab:AddButton({
    Name = "Save Configuration",
    Callback = function()
        AutoSaveSystem.SaveConfig()
        OrionLib:MakeNotification({
            Name = "Configuration Saved",
            Content = "Your settings have been saved!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- Reset Config Button
ConfigTab:AddButton({
    Name = "Reset Configuration",
    Callback = function()
        -- Reset to default values
        for key, value in pairs(AutoSaveSystem.DefaultConfig) do
            AutoSaveSystem.UpdateData(key, value)
        end
        
        -- Update UI elements with default values
        -- Main Tab
        MainTab:UpdateToggle("AutoRoll", AutoSaveSystem.DefaultConfig.AutoRoll)
        MainTab:UpdateSlider("RollDelay", AutoSaveSystem.DefaultConfig.RollDelay)
        MainTab:UpdateToggle("AutoAttack", AutoSaveSystem.DefaultConfig.AutoAttack)
        MainTab:UpdateSlider("AttackDelay", AutoSaveSystem.DefaultConfig.AttackDelay)
        
        -- Map Tab
        MapTab:UpdateDropdown("SelectedMap", AutoSaveSystem.DefaultConfig.SelectedMap)
        MapTab:UpdateParagraph("Current Map", "Selected Map: None")
        
        -- Play Tab
        PlayTab:UpdateToggle("AutoFarm", AutoSaveSystem.DefaultConfig.AutoFarm)
        PlayTab:UpdateSlider("TeleportDistance", AutoSaveSystem.DefaultConfig.TeleportDistance)
        PlayTab:UpdateDropdown("SelectedMob", AutoSaveSystem.DefaultConfig.SelectedMob)
        
        OrionLib:MakeNotification({
            Name = "Configuration Reset",
            Content = "All settings have been reset to default!",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

-- Info Section
local InfoSection = ConfigTab:AddSection({
    Name = "Information"
})

-- Add information
ConfigTab:AddParagraph("About", "KaihonHub | Hunter\nCreated by DuongTuan\nUsing Orion UI Library")

-- Handle game close
game:GetService("Players").PlayerRemoving:Connect(function(plr)
    if plr == player then
        -- Save config on exit
        AutoSaveSystem.SaveConfig()
        
        -- Clean up connections
        if rollConnection then rollConnection:Disconnect() end
        if attackConnection then attackConnection:Disconnect() end
        if farmConnection then farmConnection:Disconnect() end
        if farmTimeUpdateConnection then farmTimeUpdateConnection:Disconnect() end
        
        -- Destroy UI
        OrionLib:Destroy()
    end
end)

-- Initialize the UI
OrionLib:Init()

-- Module return
return {
    UI = OrionLib,
    Config = AutoSaveSystem,
    StopRolling = function()
        if rollConnection then
            rollConnection:Disconnect()
            rollConnection = nil
            MainTab:UpdateToggle("AutoRoll", false)
        end
    end,
    StopAttacking = function()
        if attackConnection then
            attackConnection:Disconnect()
            attackConnection = nil
            MainTab:UpdateToggle("AutoAttack", false)
        end
    end,
    StopFarming = function()
        if farmConnection then
            farmConnection:Disconnect()
            farmConnection = nil
            PlayTab:UpdateToggle("AutoFarm", false)
        end
        
        if farmTimeUpdateConnection then
            farmTimeUpdateConnection:Disconnect()
            farmTimeUpdateConnection = nil
        end
    end
}
