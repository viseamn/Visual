-- Viz example. Every element type is shown once; copy what you need.
local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Viz",
    Size = Vector2.new(640, 460),
    Layout = "Bottom bar", -- "Bottom bar", "Top bar", "Left bar" or "Right bar"
    MenuKey = Enum.KeyCode.RightShift,
})

-- Every control created with an ID ends up here, e.g. Toggles.MyToggle.Value
local Options = Library.Options
local Toggles = Library.Toggles

-- Icons are Lucide names: https://lucide.dev/icons
local Tabs = {
    Main = Window:AddTab("Main", "house"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Settings = Window:CreateSettingsTab(),
}

--// Main: left column \\--
local LeftGroupbox = Tabs.Main:AddLeftGroupbox("Groupbox", "boxes")

LeftGroupbox:AddToggle("MyToggle", {
    Text = "This is a toggle",
    Default = true,
    Keybind = "F", -- optional, press F to flip it
    Tooltip = "Hover text",
    Callback = function(value)
        print("MyToggle:", value)
    end,
})
Toggles.MyToggle:AddColorPicker({ Default = Color3.fromRGB(255, 255, 255) })

LeftGroupbox:AddCheckbox("MyCheckbox", {
    Text = "This is a checkbox",
    Default = false,
})

LeftGroupbox:AddButton({
    Text = "Button",
    Callback = function()
        Window:Notify({ Title = "Viz", Content = "Button pressed", Icon = "check" })
    end,
})
LeftGroupbox:AddButton({ Text = "Disabled button", Disabled = true })

LeftGroupbox:AddDivider()
LeftGroupbox:AddLabel("This is a label")

LeftGroupbox:AddSlider("MySlider", {
    Text = "Slider",
    Min = 0,
    Max = 100,
    Default = 50,
    Increment = 1,
})
LeftGroupbox:AddRangeSlider("MyRange", {
    Text = "Range slider",
    Min = 0,
    Max = 100,
    Default = { 20, 80 },
})

LeftGroupbox:AddInput("MyInput", {
    Text = "Textbox",
    Placeholder = "Type here",
    Finished = true, -- only fire Callback when Enter is pressed
})

LeftGroupbox:AddKeybind("MyKeybind", {
    Text = "Keybind",
    Default = Enum.KeyCode.G,
})

LeftGroupbox:AddColorPicker("MyColor", {
    Text = "Color picker",
    Default = Color3.fromRGB(255, 255, 255),
})

-- Only shown while MyToggle is on.
local Dependent = LeftGroupbox:AddDependencyBox()
Dependent:AddSlider("Strength", { Text = "Strength", Min = 1, Max = 10, Default = 5 })
Dependent:SetupDependencies({ { Toggles.MyToggle, true } })

--// Main: right column \\--
local RightGroupbox = Tabs.Main:AddRightGroupbox("Dropdowns", "list")

RightGroupbox:AddDropdown("MyDropdown", {
    Text = "A dropdown",
    Values = { "This", "is", "a", "dropdown" },
    Default = "This",
})
RightGroupbox:AddDropdown("MyMultiDropdown", {
    Text = "A multi dropdown",
    Values = { "Names", "Health", "Distance" },
    Default = { "Names", "Health" },
    Multi = true,
})
RightGroupbox:AddDropdown("MyPlayer", {
    Text = "A player dropdown",
    SpecialType = "Player",
})

--// Visuals: ESP settings with a live preview \\--
local ESPGroup = Tabs.Visuals:AddLeftGroupbox("ESP", "scan-eye")
local Preview = Tabs.Visuals:AddRightGroupbox("ESP Preview", "user"):AddESPPreview()

-- Each toggle shows or hides one part of the preview, and its color picker recolors it.
-- Parts: Body, Box, Skeleton, Health, Armor, Team, Level, Name, Id, Flag, Distance, Weapon
for _, part in ipairs({ "Box", "Skeleton", "Health", "Name", "Distance", "Weapon" }) do
    ESPGroup:AddToggle("ESP" .. part, {
        Text = part,
        Default = true,
        Callback = function(value) Preview:Set(part, { Visible = value }) end,
    })
    Toggles["ESP" .. part]:AddColorPicker({
        Default = Preview:Get(part).Color,
        Callback = function(color) Preview:Set(part, { Color = color }) end,
    })
end
ESPGroup:AddDropdown("ESPBoxStyle", {
    Text = "Box style",
    Values = { "Corner", "Full" },
    Default = "Corner",
    Callback = function(value) Preview:Set("Box", { Style = value }) end,
})
ESPGroup:AddSlider("ESPPreviewHealth", {
    Text = "Preview health",
    Min = 0,
    Max = 100,
    Default = 70,
    Callback = function(value) Preview:Set("Health", { Value = value / 100 }) end,
})
-- Preview:Set("Name", { Text = "Enemy", Color = Color3.fromRGB(255, 80, 80) })

--// Reading and changing values \\--
Toggles.MyToggle:OnChanged(function(value)
    print("MyToggle changed to", value)
end)
Options.MySlider:OnChanged(function(value)
    print("MySlider changed to", value)
end)

-- Options.MySlider:SetValue(75)
-- Toggles.MyToggle:SetValue(false)
-- print(Options.MyDropdown.Value)

--// Settings tab: themes and configs \\--
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("Viz")
SaveManager:SetFolder("Viz")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()

-- Library:Unload() removes the UI.
