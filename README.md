# Viz 1.0.1

A Roblox client UI library with detachable groupboxes, search, keybinds, and configurable navigation.

The release has three runtime modules:

| File | Purpose |
| --- | --- |
| `Library.lua` | Windows, tabs, controls, input, animation, and live theme colors. |
| `SaveManager.lua` | Config files, JSON import/export, ignored controls, and autoload. |
| `ThemeManager.lua` | Theme presets, custom themes, theme files, and the theme settings panel. |

`Example.lua` shows the complete setup. Loading the modules does not create a window or load configs automatically.

## Setup

**Roblox Studio:** create three ModuleScripts named `Library`, `SaveManager`, and `ThemeManager` beside a LocalScript containing `Example.lua`. The UI runs on the client.

**Executor:** copy the `Viz` folder into the executor's file workspace and run `Example.lua`. Its loader reads the three local files; there is no required remote loader. The runtime modules also work through `loadstring`.

```lua
local Library = require(script.Parent.Library)
local SaveManager = require(script.Parent.SaveManager)
local ThemeManager = require(script.Parent.ThemeManager)

local Window = Library:CreateWindow({Title = "Viz", Layout = "Top bar"})
local Main = Window:AddTab("Main", "house")
local Group = Main:AddLeftGroupbox("Controls", "sliders-horizontal")

Group:AddToggle("Enabled", {Text = "Enabled", Default = true})
Group:AddSlider("Speed", {Text = "Speed", Min = 0, Max = 100, Default = 50})

local Settings = Window:CreateSettingsTab()
SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:SetFolder("Viz/My Game")
ThemeManager:SetFolder("Viz/My Game")
SaveManager:BuildConfigSection(Settings)
ThemeManager:ApplyToTab(Settings)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
```

## Controls

Use a unique string ID for each saved control. Display text can change without changing its config ID.

```lua
Group:AddCheckbox("Details", {Text = "Show details", Default = false})
Group:AddDropdown("Mode", {Text = "Mode", Values = {"Default", "Compact"}, Default = "Default"})
Group:AddDropdown("Items", {Text = "Items", Values = {"Names", "Health"}, Multi = true, Default = {"Names"}})
Group:AddRangeSlider("Range", {Text = "Range", Min = 0, Max = 100, Default = {20, 80}})
Group:AddColorPicker("Color", {Text = "Color", Default = Color3.fromRGB(199, 83, 224), Alpha = false})
Group:AddInput("Name", {Text = "Name", Placeholder = "Enter a name"})
Group:AddKeybind("ActionKey", {Text = "Action key", Default = Enum.KeyCode.F})
Group:AddButton({Text = "Run", Callback = function() print("Run") end})
Group:AddLabel("Status: ready")
Group:AddDivider()

Library.Options.Speed:SetValue(75)
Library.Toggles.Enabled:SetValue(false)
Library.Options.Name.Text = "Player"
```

`Name` is an alias for `Text`, and `SaveId` can be supplied in an options table instead of a separate ID. The table-only API remains available: `Group:AddSlider({Name = "Speed", SaveId = "Speed", Min = 0, Max = 100})`.

Toggle, checkbox, slider, dropdown, color picker, and keybind return control objects. Input, button, label, and divider return Roblox instances. Controls with `Set` also expose `SetValue`. The keybind editor exposes `SetKeybind` and `SetModifiers`; it does not dispatch an action by itself. A toggle can dispatch through `Keybind = "F"`, `Mode = "Toggle"` or `"Hold"`, and `Modifiers = {Ctrl = true}`.

Controls accept `Callback`, `NoSave`, `Disabled`, `Visible`, `Tooltip`, and `DisabledTooltip` where applicable. Use `control:SetDisabled(true)` / `SetVisible(false)` for control objects, or `Group:SetControlDisabled(instance, true)` / `SetControlVisible(instance, false)` for returned instances.

Groupboxes have `Detach`, `Attach`, `IsDetached`, `SetCollapsed`, and `ToggleCollapsed`. Drag the header to detach; release it inside the main window to attach again. `Group:AddTab("General")` creates a section supporting the same control constructors. `AddTextbox` aliases `AddInput`, and `AddDoubleSlider` aliases `AddRangeSlider`.

## Window

```lua
Window:SetVisible(false)
Window:Toggle()
Window:SetStyle("Top bar") -- Normal, Top bar, Bottom bar
Window:SetAutoHide(true)
Window:SetSize(Vector2.new(700, 480))
Window:SetSearch("speed")
Window:SetTitle("My UI")
Window:Notify({Title = "Viz", Content = "Ready"})
Window:Dialog({Title = "Continue?", Content = "Confirm this action.", OnConfirm = function() end})
Library:Unload()
```

`CreateWindow` accepts `Title`, `Size` (`Vector2`), `Layout`, `MenuKey`, and `AutoHide`. It replaces the previous window created by that library instance. The default layout is Top bar; the menu key is RightShift. Create your tabs before loading a config. After replacing a window, bind managers again with `SetLibrary`.

Navigation uses compact icon buttons with tooltips and a subtle selected state. Quick settings and user profiles are removed. Theme controls are available in the Settings tab through ThemeManager. Corner radius, animation speed, and UI scale are fixed; the window still fits the viewport automatically. Group positions stay in the current session. Configs save control values, layout, menu key, navigation auto-hide, keybind list visibility, and theme.

## Config and theme API

```lua
local ok, err = SaveManager:Create("default") -- refuses to replace a file
ok, err = SaveManager:Overwrite("default") -- requires an existing file
ok, err = SaveManager:Load("default")
SaveManager:SaveAutoloadConfig("default")
SaveManager:SetIgnoreIndexes({"TemporaryControl"})
SaveManager:IgnoreThemeSettings()
local json = SaveManager:SaveJSON()
ok, err = SaveManager:LoadJSON(json)

ThemeManager:ApplyTheme("Light") -- Default, Light, Black, Mint, Nord, Dracula
ThemeManager:ApplyThemeData({Accent = Color3.fromRGB(87, 212, 178)})
ThemeManager:SaveCustomTheme("My theme")
ThemeManager:SaveDefault("My theme")
```

File operations require the executor's file functions. Studio can use `SaveJSON` / `LoadJSON` and store the JSON through its own persistence code. File/config methods return `ok, err`; JSON export returns a string. Folder names may contain safe subfolders; config/theme names cannot contain path separators.

Config values and theme data are validated before application. A failed write rolls back prior values. Callbacks run after the complete restore; callback failures are reported after application. Unknown IDs are ignored so configs can survive removed controls. Viz uses config schema version 1 and accepts the earlier Base UI schema when IDs still match. Managers expose `new()` for independent instances and accept either `SetLibrary(Library)` or `SetLibrary(Window)`.

## Validation

The release compiles with Luau and passes `Test/viz_runtime_checks.cjs`: the complete example, ID handling, config/theme round-trips, invalid input, rollback, file operations, nested folders, autoload, detaching/attaching, visibility reversal, clean navigation, removed profiles, cleanup, and rebinding. These are headless checks with Roblox service mocks. Direct in-game rendering still needs verification; the connected client closed during that check.

```powershell
node Test/viz_runtime_checks.cjs <path-to-luau.exe>
```
