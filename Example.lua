local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Viz",
    Size = Vector2.new(640, 460),
    Layout = "Top bar",
    MenuKey = Enum.KeyCode.RightShift,
})

local Main = Window:AddTab("Main", "house")
local Controls = Main:AddLeftGroupbox("Controls", "sliders-horizontal")
local Options = Main:AddRightGroupbox("Options", "layout-grid")

Controls:AddToggle("Enabled", {
    Text = "Enabled",
    Default = true,
    Keybind = "F",
    Callback = function(value) print("Enabled:", value) end,
})
Controls:AddSlider("Amount", {
    Text = "Amount",
    Min = 0,
    Max = 100,
    Default = 50,
    Increment = 1,
})
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
