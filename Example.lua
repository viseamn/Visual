local function run()
    local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
    local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
    local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()
    local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()

    local Window = Library:CreateWindow({
        Title = "Viz",
        Size = Vector2.new(640, 460),
        Layout = "Bottom bar",
        MenuKey = Enum.KeyCode.RightShift,
    })

    local Main = Window:AddTab("Main", "house")
    local Controls = Main:AddLeftGroupbox("Controls", "sliders-horizontal")
    local Options = Main:AddRightGroupbox("Options", "layout-grid")

    Controls:AddToggle("Enabled", {
        Text = "Enabled",
        Default = true,
        Keybind = "F",
        Tooltip = "Enable advanced controls",
        Callback = function(value) print("Enabled:", value) end,
    })
    local Advanced = Controls:AddDependencyBox()
    Advanced:AddSlider("Amount", {
        Text = "Amount",
        Min = 0,
        Max = 100,
        Default = 50,
        Increment = 1,
    })
    Advanced:SetupDependencies({ { Library.Toggles.Enabled, true } })
    Controls:AddRangeSlider("Range", {
        Text = "Range",
        Min = 0,
        Max = 100,
        Default = { 20, 80 },
    })
    Controls:AddColorPicker("Color", {
        Text = "Color",
        Default = Color3.fromRGB(199, 83, 224),
        Alpha = false,
    })

    Options:AddDropdown("Mode", {
        Text = "Mode",
        Values = { "Default", "Compact", "Detailed" },
        Default = "Default",
    })
    Options:AddDropdown("Items", {
        Text = "Items",
        Values = { "Names", "Health", "Distance" },
        Multi = true,
        Default = { "Names", "Health" },
    })
    Options:AddInput("Name", { Text = "Name", Placeholder = "Enter a name" })
    local CountInput = Options:AddInput("Count", {
        Text = "Count", Default = "10", Numeric = true, MaxLength = 3,
        AllowEmpty = false, Finished = true,
        VerifyValue = function(value) return tonumber(value) <= 100 end,
        Tooltip = "Enter a number up to 100, then press Enter",
    })
    Options:GetControl(CountInput):OnChanged(function(value) print("Count:", value) end)
    Options:AddButton({
        Text = "Test notification",
        Callback = function() Window:Notify({ Title = "Viz", Content = "Ready", Icon = "check" }) end,
    })

    local Settings = Window:CreateSettingsTab()
    SaveManager:SetLibrary(Library)
    ThemeManager:SetLibrary(Library)
    SaveManager:SetFolder("Viz")
    ThemeManager:SetFolder("Viz")
    SaveManager:BuildConfigSection(Settings)
    ThemeManager:ApplyToTab(Settings)

    local ok, err = ThemeManager:LoadDefault()
    if not ok then warn(err) end
    ok, err = SaveManager:LoadAutoloadConfig()
    if not ok then warn(err) end

    -- Library.Options.Amount:SetValue(75)
    -- Library.Toggles.Enabled:SetValue(false)
    -- Window:SetVisible(false)
    -- Library:Unload()

    return { Library = Library, Window = Window, SaveManager = SaveManager, ThemeManager = ThemeManager }

end

local ok, result = xpcall(run, debug.traceback)
if not ok then
    warn("Viz startup failed:\n" .. tostring(result))
    -- A plain GUI reports startup errors even when grouped textures cannot render.
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        if not player then return end
        local gui = Instance.new("ScreenGui")
        gui.Name = "VizStartupError"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 10000
        gui.Parent = player:WaitForChild("PlayerGui")
        local message = Instance.new("TextButton")
        message.Name = "Error"
        message.AnchorPoint = Vector2.new(0.5, 0.5)
        message.Position = UDim2.fromScale(0.5, 0.5)
        message.Size = UDim2.new(0.9, 0, 0.6, 0)
        message.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        message.TextColor3 = Color3.fromRGB(255, 190, 190)
        message.Font = Enum.Font.SourceSans
        message.TextSize = 14
        message.TextWrapped = true
        message.Text = "Viz could not start\n\n" .. tostring(result) .. "\n\nTap to close"
        message.Parent = gui
        message.Activated:Connect(function() gui:Destroy() end)
    end)
    error(result, 0)
end
return result
