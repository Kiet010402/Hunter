-- Hunter.lua
-- Simple UI using Rayfield Library for Hunters Game

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Player reference
local player = Players.LocalPlayer
local playerName = player.Name
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Config System (inspired by Arise.lua)
local ConfigSystem = {}
ConfigSystem.FileName = "HunterConfig_" .. playerName .. ".json"
ConfigSystem.DefaultConfig = {
    AutoRoll = false,
    RollDelay = 1,
    AutoAttack = false,
    AttackDelay = 1,
    SelectedMap = "",
    AutoFarm = false,
    TeleportDistance = 5,
    SelectedMob = "All Mobs"
}
ConfigSystem.CurrentConfig = {}

-- Function to save config
ConfigSystem.SaveConfig = function()
    local success, err = pcall(function()
        writefile(ConfigSystem.FileName, HttpService:JSONEncode(ConfigSystem.CurrentConfig))
    end)
    if success then
        print("Config saved successfully!")
    else
        warn("Failed to save config:", err)
    end
end

-- Function to load config
ConfigSystem.LoadConfig = function()
    local success, content = pcall(function()
        if isfile(ConfigSystem.FileName) then
            return readfile(ConfigSystem.FileName)
        end
        return nil
    end)
    
    if success and content then
        local data = HttpService:JSONDecode(content)
        ConfigSystem.CurrentConfig = data
        return true
    else
        ConfigSystem.CurrentConfig = table.clone(ConfigSystem.DefaultConfig)
        ConfigSystem.SaveConfig()
        return false
    end
end

-- Load config on startup
ConfigSystem.LoadConfig()

-- Initialize Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create Window (Without saving functionality)
local Window = Rayfield:CreateWindow({
    Name = "KaihonHub",
    LoadingTitle = "KaihonHub",
    LoadingSubtitle = "by DuongTuan",
    ConfigurationSaving = {
        Enabled = false -- Disable Rayfield's built-in saving
    },
    KeySystem = false
})

-- Create Main Tab
local MainTab = Window:CreateTab("Main", 4483362458) -- Home icon

-- Create Map Tab
local MapTab = Window:CreateTab("Map", 9288394834) -- Map icon

-- Create Play Tab
local PlayTab = Window:CreateTab("Play", 4483362927) -- Play icon

-- Main Section
local MainSection = MainTab:CreateSection("Roll Settings")

-- Auto Roll Toggle
local rollConnection = nil
local AutoRollToggle = MainTab:CreateToggle({
    Name = "Auto Roll",
    CurrentValue = ConfigSystem.CurrentConfig.AutoRoll or false,
    Flag = "AutoRoll",
    Callback = function(Value)
        if Value then
            -- Start auto roll
            if rollConnection then rollConnection:Disconnect() end
            
            rollConnection = game:GetService("RunService").Heartbeat:Connect(function()
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Roll"):InvokeServer()
                wait(ConfigSystem.CurrentConfig.RollDelay or 1) -- Use saved delay
            end)
            
            Rayfield:Notify({
                Title = "Auto Roll Enabled",
                Content = "Now automatically rolling...",
                Duration = 3,
                Image = "dice", -- Lucide icon
            })
        else
            -- Stop auto roll
            if rollConnection then 
                rollConnection:Disconnect()
                rollConnection = nil
                
                Rayfield:Notify({
                    Title = "Auto Roll Disabled",
                    Content = "Auto roll has been stopped",
                    Duration = 3,
                    Image = "square", -- Lucide icon
                })
            end
        end
        
        -- Save to config
        ConfigSystem.CurrentConfig.AutoRoll = Value
        ConfigSystem.SaveConfig()
    end,
})

-- Roll Delay Slider
local RollDelaySlider = MainTab:CreateSlider({
    Name = "Roll Delay (seconds)",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = ConfigSystem.CurrentConfig.RollDelay or 1,
    Flag = "RollDelay",
    Callback = function(Value)
        -- The delay will be applied on the next toggle enable
        Rayfield:Notify({
            Title = "Roll Delay Updated",
            Content = "New delay: " .. Value .. " seconds",
            Duration = 2,
            Image = "timer", -- Lucide icon
        })
        
        -- Save to config
        ConfigSystem.CurrentConfig.RollDelay = Value
        ConfigSystem.SaveConfig()
    end,
})

-- Manual Roll Button
local RollButton = MainTab:CreateButton({
    Name = "Manual Roll",
    Callback = function()
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Roll"):InvokeServer()
        
        Rayfield:Notify({
            Title = "Manual Roll",
            Content = "Roll executed!",
            Duration = 2,
            Image = "dice", -- Lucide icon
        })
    end,
})

-- Attack Section
local AttackSection = MainTab:CreateSection("Attack Settings")

-- Auto Attack Toggle
local attackConnection = nil
local AutoAttackToggle = MainTab:CreateToggle({
    Name = "Auto Attack",
    CurrentValue = ConfigSystem.CurrentConfig.AutoAttack or false,
    Flag = "AutoAttack",
    Callback = function(Value)
        if Value then
            -- Start auto attack
            if attackConnection then attackConnection:Disconnect() end
            
            attackConnection = game:GetService("RunService").Heartbeat:Connect(function()
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Combat"):FireServer()
                wait(ConfigSystem.CurrentConfig.AttackDelay or 1) -- Use saved delay
            end)
            
            Rayfield:Notify({
                Title = "Auto Attack Enabled",
                Content = "Now automatically attacking...",
                Duration = 3,
                Image = "swords", -- Lucide icon
            })
        else
            -- Stop auto attack
            if attackConnection then 
                attackConnection:Disconnect()
                attackConnection = nil
                
                Rayfield:Notify({
                    Title = "Auto Attack Disabled",
                    Content = "Auto attack has been stopped",
                    Duration = 3,
                    Image = "square", -- Lucide icon
                })
            end
        end
        
        -- Save to config
        ConfigSystem.CurrentConfig.AutoAttack = Value
        ConfigSystem.SaveConfig()
    end,
})

-- Attack Delay Slider
local AttackDelaySlider = MainTab:CreateSlider({
    Name = "Attack Delay (seconds)",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = ConfigSystem.CurrentConfig.AttackDelay or 1,
    Flag = "AttackDelay",
    Callback = function(Value)
        -- The delay will be applied on the next toggle enable
        Rayfield:Notify({
            Title = "Attack Delay Updated",
            Content = "New delay: " .. Value .. " seconds",
            Duration = 2,
            Image = "timer", -- Lucide icon
        })
        
        -- Save to config
        ConfigSystem.CurrentConfig.AttackDelay = Value
        ConfigSystem.SaveConfig()
    end,
})

-- Manual Attack Button
local AttackButton = MainTab:CreateButton({
    Name = "Manual Attack",
    Callback = function()
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Combat"):FireServer()
        
        Rayfield:Notify({
            Title = "Manual Attack",
            Content = "Attack executed!",
            Duration = 2,
            Image = "swords", -- Lucide icon
        })
    end,
})

-- Status Section
local StatusSection = MainTab:CreateSection("Status")

-- Create Stats Label
local statusLabel = MainTab:CreateLabel("Player: " .. playerName)
local rollsLabel = MainTab:CreateLabel("Rolls: 0")
local attacksLabel = MainTab:CreateLabel("Attacks: 0")

-- Roll counter
local rollCount = 0

-- Function to update roll count
local function updateRollCount()
    rollCount = rollCount + 1
    rollsLabel:Set("Rolls: " .. rollCount)
end

-- Attack counter
local attackCount = 0

-- Function to update attack count
local function updateAttackCount()
    attackCount = attackCount + 1
    attacksLabel:Set("Attacks: " .. attackCount)
end

-- Hook the update roll count to both manual and auto roll
local oldRollCallback = RollButton.Callback
RollButton.Callback = function()
    oldRollCallback()
    updateRollCount()
end

-- Hook the update attack count to manual attack
local oldAttackCallback = AttackButton.Callback
AttackButton.Callback = function()
    oldAttackCallback()
    updateAttackCount()
end

-- Map Tab Content
local MapSelectionSection = MapTab:CreateSection("Map Selection")

-- Map selection variable
local selectedMap = ConfigSystem.CurrentConfig.SelectedMap or nil
local mapCodes = {
    ["SINGULARITY"] = "DoubleDungeonD",
    ["GOBLIN CAVES"] = "GoblinCave",
    ["SPIDER CAVERN"] = "SpiderCavern"
}

-- Map Dropdown
local MapDropdown = MapTab:CreateDropdown({
    Name = "Chọn Map",
    Options = {"SINGULARITY", "GOBLIN CAVES", "SPIDER CAVERN"},
    CurrentOption = selectedMap and {selectedMap} or {}, -- Use saved map
    MultipleOptions = false,
    Flag = "SelectedMap",
    Callback = function(Option)
        selectedMap = Option[1]
        Rayfield:Notify({
            Title = "Map Selected",
            Content = "You selected: " .. selectedMap,
            Duration = 2,
            Image = "map", -- Lucide icon
        })
        
        -- Save to config
        ConfigSystem.CurrentConfig.SelectedMap = selectedMap
        ConfigSystem.SaveConfig()
    end,
})

-- Current Map Label
local CurrentMapLabel = MapTab:CreateLabel("Selected Map: " .. (selectedMap or "None"))

-- Update map label when selection changes
local oldMapCallback = MapDropdown.Callback
MapDropdown.Callback = function(Option)
    oldMapCallback(Option)
    CurrentMapLabel:Set("Selected Map: " .. Option[1])
end

-- Map Control Section
local MapControlSection = MapTab:CreateSection("Map Controls")

-- Start button (toggle)
local startConnection = nil
local StartToggle = MapTab:CreateToggle({
    Name = "Start Map",
    CurrentValue = false,
    Flag = "StartMap",
    Callback = function(Value)
        if Value then
            if selectedMap == nil then
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Please select a map first!",
                    Duration = 3,
                    Image = "alert-triangle", -- Lucide icon
                })
                StartToggle:Set(false)
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
            
            Rayfield:Notify({
                Title = "Map Started",
                Content = "Starting " .. selectedMap .. "...",
                Duration = 3,
                Image = "play", -- Lucide icon
            })
            
            -- Auto reset the toggle after starting
            wait(1)
            StartToggle:Set(false)
        end
    end,
})

-- Manual Create Lobby Button
local CreateLobbyButton = MapTab:CreateButton({
    Name = "Create Lobby Only",
    Callback = function()
        if selectedMap == nil then
            Rayfield:Notify({
                Title = "Error",
                Content = "Please select a map first!",
                Duration = 3,
                Image = "alert-triangle", -- Lucide icon
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
        
        Rayfield:Notify({
            Title = "Lobby Created",
            Content = "Created lobby for " .. selectedMap,
            Duration = 3,
            Image = "users", -- Lucide icon
        })
    end,
})

-- Manual Start Button
local StartLobbyButton = MapTab:CreateButton({
    Name = "Start Lobby Only",
    Callback = function()
        -- Start the lobby
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("LobbyStart"):FireServer()
        
        Rayfield:Notify({
            Title = "Lobby Started",
            Content = "Starting lobby...",
            Duration = 3,
            Image = "play", -- Lucide icon
        })
    end,
})

-- Play Tab Content
local FarmSection = PlayTab:CreateSection("Auto Farm")

-- Available mobs
local mobList = {"All Mobs", "Golem Mage"}
local selectedMob = ConfigSystem.CurrentConfig.SelectedMob or "All Mobs"

-- Mob selection dropdown
local MobDropdown = PlayTab:CreateDropdown({
    Name = "Select Target",
    Options = mobList,
    CurrentOption = {selectedMob}, -- Use saved mob
    MultipleOptions = false,
    Flag = "SelectedMob",
    Callback = function(Option)
        selectedMob = Option[1]
        Rayfield:Notify({
            Title = "Target Selected",
            Content = "Now targeting: " .. selectedMob,
            Duration = 2,
            Image = "target", -- Lucide icon
        })
        
        -- Save to config
        ConfigSystem.CurrentConfig.SelectedMob = selectedMob
        ConfigSystem.SaveConfig()
    end,
})

-- Teleport distance slider
local TeleportDistanceSlider = PlayTab:CreateSlider({
    Name = "Teleport Distance",
    Range = {0, 10},
    Increment = 0.5,
    Suffix = "studs",
    CurrentValue = ConfigSystem.CurrentConfig.TeleportDistance or 5,
    Flag = "TeleportDistance",
    Callback = function(Value)
        Rayfield:Notify({
            Title = "Distance Updated",
            Content = "New teleport distance: " .. Value .. " studs",
            Duration = 2,
            Image = "ruler", -- Lucide icon
        })
        
        -- Save to config
        ConfigSystem.CurrentConfig.TeleportDistance = Value
        ConfigSystem.SaveConfig()
    end,
})

-- Farm toggle
local farmConnection = nil
local AutoFarmToggle = PlayTab:CreateToggle({
    Name = "Auto Farm",
    CurrentValue = ConfigSystem.CurrentConfig.AutoFarm or false,
    Flag = "AutoFarm",
    Callback = function(Value)
        -- Get the character and humanoid root part
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        
        if Value then
            -- Start auto farm
            if farmConnection then farmConnection:Disconnect() end
            
            farmConnection = game:GetService("RunService").Heartbeat:Connect(function()
                -- Find mobs
                local mobsFolder = workspace:FindFirstChild("Mobs")
                if not mobsFolder then
                    Rayfield:Notify({
                        Title = "Error",
                        Content = "Mobs folder not found!",
                        Duration = 3,
                        Image = "alert-triangle", -- Lucide icon
                    })
                    AutoFarmToggle:Set(false)
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
                    local teleportDistance = ConfigSystem.CurrentConfig.TeleportDistance or 5
                    local mobPosition = targetMob.HumanoidRootPart.Position
                    local direction = (humanoidRootPart.Position - mobPosition).Unit
                    local targetPosition = mobPosition + (direction * teleportDistance)
                    
                    -- Teleport to the mob with offset
                    humanoidRootPart.CFrame = CFrame.new(targetPosition, mobPosition)
                    
                    -- Auto attack if enabled
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Combat"):FireServer()
                    wait(0.5) -- Small delay to prevent overwhelming the server
                end
            end)
            
            Rayfield:Notify({
                Title = "Auto Farm Enabled",
                Content = "Now farming: " .. selectedMob,
                Duration = 3,
                Image = "target", -- Lucide icon
            })
        else
            -- Stop auto farm
            if farmConnection then 
                farmConnection:Disconnect()
                farmConnection = nil
                
                Rayfield:Notify({
                    Title = "Auto Farm Disabled",
                    Content = "Auto farming has been stopped",
                    Duration = 3,
                    Image = "square", -- Lucide icon
                })
            end
        end
        
        -- Save to config
        ConfigSystem.CurrentConfig.AutoFarm = Value
        ConfigSystem.SaveConfig()
    end,
})

-- Stats section for farming
local FarmStatsSection = PlayTab:CreateSection("Farm Stats")
local mobsKilledLabel = PlayTab:CreateLabel("Mobs Killed: 0")
local farmTimeLabel = PlayTab:CreateLabel("Farm Time: 0m 0s")

-- Farm stats counters
local mobsKilled = 0
local farmStartTime = 0
local farmTimeUpdateConnection = nil

-- Update farm time
local function updateFarmTime()
    if farmStartTime > 0 then
        local elapsedTime = os.time() - farmStartTime
        local minutes = math.floor(elapsedTime / 60)
        local seconds = elapsedTime % 60
        farmTimeLabel:Set("Farm Time: " .. minutes .. "m " .. seconds .. "s")
    end
end

-- Update farm stats when toggling
local oldFarmCallback = AutoFarmToggle.Callback
AutoFarmToggle.Callback = function(Value)
    oldFarmCallback(Value)
    
    if Value then
        -- Reset and start farm timer
        farmStartTime = os.time()
        
        if farmTimeUpdateConnection then
            farmTimeUpdateConnection:Disconnect()
        end
        
        farmTimeUpdateConnection = game:GetService("RunService").Heartbeat:Connect(function()
            updateFarmTime()
            wait(1) -- Update every second
        end)
    else
        -- Stop farm timer
        if farmTimeUpdateConnection then
            farmTimeUpdateConnection:Disconnect()
            farmTimeUpdateConnection = nil
        end
    end
end

-- Function to update mob kill count
local function updateMobKillCount()
    mobsKilled = mobsKilled + 1
    mobsKilledLabel:Set("Mobs Killed: " .. mobsKilled)
end

-- Reset Stats Button
local ResetStatsButton = PlayTab:CreateButton({
    Name = "Reset Farm Stats",
    Callback = function()
        mobsKilled = 0
        farmStartTime = AutoFarmToggle.CurrentValue and os.time() or 0
        mobsKilledLabel:Set("Mobs Killed: 0")
        updateFarmTime()
        
        Rayfield:Notify({
            Title = "Stats Reset",
            Content = "Farm statistics have been reset",
            Duration = 2,
            Image = "refresh-cw", -- Lucide icon
        })
    end,
})

-- Add auto farm mob kill counter
local function hookMobDeath()
    local mobsFolder = workspace:FindFirstChild("Mobs")
    if mobsFolder then
        mobsFolder.ChildRemoved:Connect(function(child)
            if AutoFarmToggle.CurrentValue then
                updateMobKillCount()
            end
        end)
    end
end

-- Try to hook mob deaths when the script loads
hookMobDeath()

-- Try again when the workspace children change
workspace.ChildAdded:Connect(function(child)
    if child.Name == "Mobs" then
        wait(1) -- Small delay to ensure the folder is properly set up
        hookMobDeath()
    end
end)

-- Add Config Tab for saving/loading
local ConfigTab = Window:CreateTab("Config", 4483362458)

-- Config Section
local ConfigSection = ConfigTab:CreateSection("Configuration")

-- Save Config Button
local SaveConfigButton = ConfigTab:CreateButton({
    Name = "Save Configuration",
    Callback = function()
        ConfigSystem.SaveConfig()
        Rayfield:Notify({
            Title = "Configuration Saved",
            Content = "Your settings have been saved!",
            Duration = 2,
            Image = "save", -- Lucide icon
        })
    end,
})

-- Reset Config Button
local ResetConfigButton = ConfigTab:CreateButton({
    Name = "Reset Configuration",
    Callback = function()
        ConfigSystem.CurrentConfig = table.clone(ConfigSystem.DefaultConfig)
        ConfigSystem.SaveConfig()
        
        -- Update UI with default values
        AutoRollToggle:Set(ConfigSystem.DefaultConfig.AutoRoll)
        RollDelaySlider:Set(ConfigSystem.DefaultConfig.RollDelay)
        AutoAttackToggle:Set(ConfigSystem.DefaultConfig.AutoAttack)
        AttackDelaySlider:Set(ConfigSystem.DefaultConfig.AttackDelay)
        MapDropdown:Set({})
        CurrentMapLabel:Set("Selected Map: None")
        AutoFarmToggle:Set(ConfigSystem.DefaultConfig.AutoFarm)
        TeleportDistanceSlider:Set(ConfigSystem.DefaultConfig.TeleportDistance)
        MobDropdown:Set({ConfigSystem.DefaultConfig.SelectedMob})
        
        Rayfield:Notify({
            Title = "Configuration Reset",
            Content = "All settings have been reset to default!",
            Duration = 2,
            Image = "refresh-cw", -- Lucide icon
        })
    end,
})

-- Auto Save Timer (save every 60 seconds)
spawn(function()
    while true do
        wait(60)
        ConfigSystem.SaveConfig()
    end
end)

-- Save on game close
game:GetService("Players").PlayerRemoving:Connect(function(plr)
    if plr == player then
        ConfigSystem.SaveConfig()
    end
end)

-- Module return
return {
    UI = Window,
    Config = ConfigSystem,
    StopRolling = function()
        if rollConnection then
            rollConnection:Disconnect()
            rollConnection = nil
            AutoRollToggle:Set(false)
        end
    end,
    StopAttacking = function()
        if attackConnection then
            attackConnection:Disconnect()
            attackConnection = nil
            AutoAttackToggle:Set(false)
        end
    end,
    StopFarming = function()
        if farmConnection then
            farmConnection:Disconnect()
            farmConnection = nil
            AutoFarmToggle:Set(false)
        end
        
        if farmTimeUpdateConnection then
            farmTimeUpdateConnection:Disconnect()
            farmTimeUpdateConnection = nil
        end
    end
}
