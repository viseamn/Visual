# Viz 1.0.3

A Roblox client UI library with detachable groupboxes, search, keybinds, and a bottom navigation bar.

The release has three runtime modules:

| File | Purpose |
| --- | --- |
| `Library.lua` | Windows, tabs, controls, input, animation, and live theme colors. |
| `SaveManager.lua` | Config files, JSON import/export, ignored controls, and autoload. |
| `ThemeManager.lua` | Theme presets, custom themes, theme files, and the theme settings panel. |

`Example.lua` shows the complete setup. Loading the modules does not create a window or load configs automatically.

## Setup

**Roblox Studio:** create three ModuleScripts named `Library`, `SaveManager`, and `ThemeManager` beside a LocalScript containing `Example.lua`. The UI runs on the client.

**Executor:** run `loadstring(game:HttpGet("https://raw.githubusercontent.com/viseamn/Visual/main/Example.lua"))()`. The example loads the three modules from the repository. For Studio, replace its three remote module loads with the `require` calls below.

```lua
local Library = require(script.Parent.Library)
local SaveManager = require(script.Parent.SaveManager)
local ThemeManager = require(script.Parent.ThemeManager)

local Window = Library:CreateWindow({Title = "Viz", Layout = "Bottom bar"})
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

Toggle switches support clicking and horizontal dragging with a mouse or touch. Drag the thumb toward the right to enable or left to disable; the value commits on release. Canceling a drag leaves the current value unchanged. `Always` mode keeps the toggle enabled.

Controls accept `Callback`, `NoSave`, `Disabled`, and `Visible` where applicable. There are no hover tooltips; a `Tooltip` string is still matched by search. Use `control:SetDisabled(true)` / `SetVisible(false)` for control objects, or `Group:SetControlDisabled(instance, true)` / `SetControlVisible(instance, false)` for returned instances.

Groupboxes have `Detach`, `Attach`, `IsDetached`, `SetCollapsed`, and `ToggleCollapsed`. Drag the header to detach; release it inside the main window to attach again. `Group:AddTab("General")` creates a section supporting the same control constructors. `AddTextbox` aliases `AddInput`, and `AddDoubleSlider` aliases `AddRangeSlider`.

## Window

```lua
Window:SetVisible(false)
Window:Toggle()
Window:SetStyle("Left bar") -- Bottom bar, Top bar, Left bar, Right bar
Window:SetSearchStyle("Header") -- Bar (default) or Header
Window:SetAutoHide(true)
Window:SetSize(Vector2.new(700, 480))
Window:SetSearch("speed")
Window:SetTitle("My UI")
Window:Notify({Title = "Viz", Content = "Ready"})
Window:SetNotificationPosition("TopRight") -- TopLeft, Top, TopRight, BottomLeft, Bottom, BottomRight
Window:Dialog({Title = "Continue?", Content = "Confirm this action.", OnConfirm = function() end})
Library:Unload()
```

`CreateWindow` accepts `Title`, `Size` (`Vector2`), `Layout`, `SearchStyle`, `MenuKey`, `AutoHide`, and `NotificationPosition` (default `BottomRight`). `SearchStyle` shows one search field: `Bar` (default) puts a taskbar-style search pill in the bar, `Header` uses the field in the window header; players can switch it from the "Search bar" dropdown in the theme Style tab. It replaces the previous window created by that library instance. `Layout` picks the screen edge for the tab bar: `Bottom bar` (default), `Top bar`, `Left bar` or `Right bar`; players can also change it from the "Bar position" dropdown in the theme Style tab. The menu key is RightShift. Create your tabs before loading a config. After replacing a window, bind managers again with `SetLibrary`.

Navigation uses the original bottom bar with icon buttons between two dividers and a decorative user avatar. With `SearchStyle = "Bar"` a search pill sits before the tabs and reopens a hidden window when used; on a left or right bar it is a round button that opens a small search card beside the bar. The avatar has no click action. The header uses the cloud logo and a wide search field. Interface contains the keybind controls; auto-hide is in Themes > Style. Quick settings and the user profile card are removed. Legacy config layout values are restored as Bottom bar. Theme controls are available in the Settings tab through ThemeManager. Corner radius, animation speed, and UI scale are fixed; the window still fits the viewport automatically. Group positions stay in the current session. Configs save control values, layout, search style, menu key, navigation auto-hide, keybind list visibility, and theme.

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

File operations require the executor's file functions. Studio can use `SaveJSON` / `LoadJSON` and store the JSON through its own persistence code. File/config methods return `ok, err`; JSON export returns a string. Folder names may contain safe subfolders; config/theme names cannot contain path separators and are limited to 64 characters. Listing failures are shown in the settings UI without clearing an existing selection.

Touch-enabled devices use ordinary Frames instead of CanvasGroup textures by default to avoid blank rendering when texture memory is exhausted. Group fade effects are skipped in this mode; visibility and control interactions remain available. Set `CanvasGroups = false` in `CreateWindow` to force this mode on any device, or `CanvasGroups = true` to retain grouped fades. `Example.lua` displays startup errors in a plain on-screen panel and also logs the traceback.

Editing colors, font or the background image, and importing theme data, clears the preset selection and displays `Custom`. `SaveCustomTheme(name)` creates a new theme and refuses to overwrite an existing file. Use the settings panel's `Overwrite theme` button with the desired `Theme name`; it asks for confirmation. The API can explicitly overwrite an existing theme with `SaveCustomTheme(name, true)`.

Config values and theme data are validated before application. A failed write rolls back prior values. Callbacks run after the complete restore; callback failures are reported after application. Unknown IDs are ignored so configs can survive removed controls. Viz uses config schema version 1 and accepts the earlier Base UI schema when IDs still match. Managers expose `new()` for independent instances and accept either `SetLibrary(Library)` or `SetLibrary(Window)`.

## Validation

The runtime modules and example compile with Luau. `tests/ui-regressions.js` passes 60 regression checks covering config cancellation, snapshot and callback failures, rollback, shared name limits, theme overwrite confirmation, preset synchronization, file-list errors, modifier keybinds, slider precision, toggle click/drag gestures, the mobile Frame rendering fallback and startup error reporting. These checks use mocked services and UI controls, plus extracted Library functions; they do not verify in-game rendering.

```powershell
node tests/ui-regressions.js <path-to-luau.exe>
```
