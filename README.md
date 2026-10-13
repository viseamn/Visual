<p align="center">
  <img src="assets/banner.jpg" alt="Viz" width="100%">
</p>

<p align="center">
  <b>A clean, glassy UI library for Roblox</b><br>
  Dockable tab bar · detachable groupboxes · search · keybinds · themes · configs
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.3-white?style=flat-square" alt="Version 1.0.3">
  <img src="https://img.shields.io/badge/Roblox-Luau-22232E?style=flat-square" alt="Roblox Luau">
  <img src="https://img.shields.io/badge/icons-Lucide-white?style=flat-square" alt="Lucide icons">
</p>

---

## Features

- **Dock bar** on any screen edge (bottom, top, left, right), with optional auto-hide and a built-in search pill
- **Groupboxes** that collapse, split into sections, and detach into floating cards by dragging their header
- **Every common control**: toggle, checkbox, button, slider, range slider, dropdown (single, multi, player, team), textbox, keybind, color picker, label, divider
- **Toggle keybinds** with a popup to pick *Toggle* or *Hold* and press a key, including Ctrl / Shift / Alt
- **Global search** that filters tabs, groupboxes and controls as you type
- **Lucide icons** rendered from an icon font, so they stay sharp at any size
- **Themes**: 18 presets (dark and light) plus your own, 16 fonts, all applied live
- **Configs**: save, load, auto save, autoload and JSON import/export
- **DPI scale** from 50% to 200%, and the window always fits the screen

## Files

| File | Purpose |
| --- | --- |
| [`Library.lua`](Library.lua) | Window, tabs, controls, input, animation and theme colors |
| [`ThemeManager.lua`](ThemeManager.lua) | Theme presets, custom themes and the theme settings panel |
| [`SaveManager.lua`](SaveManager.lua) | Config files, JSON import/export, ignored controls and autoload |
| [`Example.lua`](Example.lua) | Every element in one script. Start here |

## Quick start

### Executor

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/viseamn/Visual/main/Example.lua"))()
```

### Your own script

```lua
local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Viz",
    Layout = "Bottom bar",
    MenuKey = Enum.KeyCode.RightShift,
})

local Tabs = {
    Main = Window:AddTab("Main", "house"),
    Settings = Window:CreateSettingsTab(),
}

local Group = Tabs.Main:AddLeftGroupbox("Controls", "sliders-horizontal")
Group:AddToggle("Enabled", { Text = "Enabled", Default = true, Keybind = "F" })
Group:AddSlider("Speed", { Text = "Speed", Min = 0, Max = 100, Default = 50 })

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("Viz/MyGame")
SaveManager:SetFolder("Viz/MyGame")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
```

### Roblox Studio

Create three ModuleScripts named `Library`, `ThemeManager` and `SaveManager` next to a LocalScript, then swap the `loadstring` lines for `require`:

```lua
local Library = require(script.Parent.Library)
local ThemeManager = require(script.Parent.ThemeManager)
local SaveManager = require(script.Parent.SaveManager)
```

The UI runs on the client only. Loading the modules does not create a window or load configs by itself.

## Controls

Give each saved control a unique string ID. You can change the display text later without breaking saved configs.

```lua
Group:AddToggle("MyToggle", { Text = "Toggle", Default = false, Keybind = "F", Mode = "Toggle" })
Group:AddCheckbox("MyCheckbox", { Text = "Checkbox", Default = false })
Group:AddButton({ Text = "Button", Callback = function() print("Pressed") end })
Group:AddButton({ Text = "Left", Callback = print, Buttons = { { Name = "Right", Callback = print } } }) -- one row
Group:AddSlider("MySlider", { Text = "Slider", Min = 0, Max = 100, Default = 50, Suffix = "%" })
Group:AddRangeSlider("MyRange", { Text = "Range", Min = 0, Max = 100, Default = { 20, 80 } })
Group:AddInput("MyInput", { Text = "Textbox", Placeholder = "Type here" })
Group:AddKeybind("MyKey", { Text = "Keybind", Default = Enum.KeyCode.G })
Group:AddColorPicker("MyColor", { Text = "Color", Default = Color3.fromRGB(255, 255, 255) })
Group:AddDropdown("MyDropdown", { Text = "Dropdown", Values = { "One", "Two" }, Default = "One" })
Group:AddDropdown("MyMulti", { Text = "Multi", Values = { "A", "B", "C" }, Multi = true, Default = { "A" } })
Group:AddDropdown("MyPlayer", { Text = "Player", SpecialType = "Player" })
Group:AddLabel("Status: ready")
Group:AddDivider()
```

Read and change values through `Library.Toggles` and `Library.Options`:

```lua
local Toggles, Options = Library.Toggles, Library.Options

print(Toggles.MyToggle.Value)
Options.MySlider:SetValue(75)
Toggles.MyToggle:OnChanged(function(value) print("Toggle:", value) end)
```

Most controls accept `Callback`, `Tooltip`, `Disabled`, `Visible` and `NoSave`.

<details>
<summary><b>Toggles and keybinds</b></summary>

<br>

- Click the switch or drag its thumb. A drag commits when you release.
- Click the key box next to a toggle to open its popup. Pick **Toggle** or **Hold**, then click the box below and press a key. **Backspace** clears the key and **Escape** cancels.
- A toggle has no key box until you give it one, like Obsidian: `Toggles.MyToggle:AddKeyPicker("MyKey", { Default = "F", Mode = "Hold", Text = "My toggle" })`. `NoUI = true` keeps it out of the keybind list. `Options.MyKey:SetValue({ "G", "Toggle" })` changes it.
- The shorthand `Keybind = "F"` in the toggle's options also adds the key box. Other options: `Mode = "Toggle"` / `"Hold"` / `"Always"`, `Modifiers = { Ctrl = true }`.
- `Notify = true` (or `false`) adds a bell icon that turns the on/off notification for that toggle on or off. Without it there is no bell and no notification.
- `Toggles.MyToggle:AddColorPicker({ Default = ... })` adds a color swatch to the row.
- `AddKeybind` is a key picker only. It does not run an action by itself.

</details>

<details>
<summary><b>Dropdowns</b></summary>

<br>

- `Values` can be a list or a `{ key = "Label" }` table. `Multi = true` allows several choices.
- `Searchable = false` hides the search box, and `MaxVisibleDropdownItems` sets how many rows show before scrolling.
- `SpecialType = "Player"` or `"Team"` keeps the list in sync with the server. Player rows show the player's avatar; turn that off with `EnablePlayerImages = false`.
- `ValueImages = { key = "rbxassetid://..." }` puts an image on any row.
- `DisabledValues`, `AllowNull`, `FormatDisplayValue` and `DragSelect` are also supported.

</details>

<details>
<summary><b>Textbox validation</b></summary>

<br>

```lua
local Input = Group:AddInput("Count", {
    Text = "Count", Default = "10", Numeric = true, MaxLength = 3,
    AllowEmpty = false, EmptyReset = "10", Finished = true,
    VerifyValue = function(text) return tonumber(text) <= 100 end,
})
Group:GetControl(Input):OnChanged(function(value) print(value) end)
```

- `Finished = true` commits on Enter. `Finished = false` commits while typing. Leaving it out commits when the box loses focus.
- An invalid edit goes back to the last valid value. `MaxLength` counts Unicode characters.
- `ClearTextOnFocus` and `ClearTextOnBlur` are supported.

</details>

<details>
<summary><b>Dependency boxes</b></summary>

<br>

```lua
local Dep = Group:AddDependencyBox()
Dep:AddSlider("Strength", { Text = "Strength", Min = 1, Max = 10, Default = 5 })
Dep:SetupDependencies({ { Toggles.MyToggle, true } })
```

The rows show only while every `{ control, value }` pair matches. For a multi dropdown, the key just needs to be selected.

</details>

<details>
<summary><b>Groupboxes and sections</b></summary>

<br>

- `Tab:AddLeftGroupbox(name, icon)` / `AddRightGroupbox(name, icon)`. Icons are [Lucide](https://lucide.dev/icons) names.
- `Group:AddTab("General")` adds a section strip inside the groupbox.
- Drag a groupbox header out of the window to detach it, and drop it back inside to attach it again.
- `SetCollapsed`, `ToggleCollapsed`, `Detach`, `Attach` and `IsDetached` are available.
- `Group:GetControl(x)` returns the control API (`SetText`, `SetDisabled`, `SetVisible`, `OnChanged`, `Destroy`) for any control.

</details>

## Window

```lua
local Window = Library:CreateWindow({
    Title = "Viz",
    Size = Vector2.new(640, 460),
    Layout = "Bottom bar",          -- Bottom bar, Top bar, Left bar, Right bar
    SearchStyle = "Bar",            -- Bar (in the dock) or Header (in the window)
    MenuKey = Enum.KeyCode.RightShift,
    AutoHide = false,               -- hide the dock until the mouse reaches the edge
    NotificationPosition = "BottomRight",
    DPIScale = 1,                   -- 0.5 to 2
})
```

```lua
Window:Toggle()
Window:SetVisible(false)
Window:SetStyle("Left bar")
Window:SetSearchStyle("Header")
Window:SetAutoHide(true)
Window:SetDPIScale("125%")
Window:SetSize(Vector2.new(700, 480))
Window:SetSearch("speed")
Window:Notify({ Title = "Viz", Content = "Ready", Icon = "check" })
Window:Dialog({ Title = "Continue?", Content = "Confirm this action.", OnConfirm = function() end })
Library:Unload()
```

Players can change the bar position, search style, auto-hide, keybind menu, menu key, notification position and DPI scale in **Settings > Appearance > Interface** (from `ThemeManager:ApplyToTab`). Without ThemeManager, `CreateSettingsTab` shows these in an Interface card instead, or place them yourself with `Window:AddInterfaceControls(section)`. Drag the window anywhere, even partly off screen, and resize it from the bottom-right corner.

## Themes and configs

```lua
-- Dark: Default, Orchid, Black, Mint, Nord, Dracula, Catppuccin, Tokyo Night, Gruvbox, One Dark,
-- Rose Pine, Monokai, Solarized, Ocean, Crimson. Light: Light, Latte, Sakura. Presets keep the font.
ThemeManager:ApplyTheme("Tokyo Night")
ThemeManager:ApplyThemeData({ Accent = Color3.fromRGB(87, 212, 178) })
-- BuilderSans, Gotham, SourceSans, Roboto, Montserrat, Nunito, Ubuntu, Arimo, JosefinSans,
-- TitilliumWeb, Oswald, Jura, Michroma, FredokaOne, Code, RobotoMono
ThemeManager:ApplyThemeData({ Font = "Montserrat" })
ThemeManager:SaveCustomTheme("My theme")
ThemeManager:SaveDefault("My theme")

SaveManager:Create("default")       -- refuses to replace an existing file
SaveManager:Overwrite("default")
SaveManager:Load("default")
SaveManager:SaveAutoloadConfig("default")
SaveManager:SetAutoSave(true)       -- remembered between sessions; turns off manual Create / Save in the panel
SaveManager:SetIgnoreIndexes({ "TemporaryControl" })
local json = SaveManager:SaveJSON()
SaveManager:LoadJSON(json)
```

<details>
<summary><b>Notes</b></summary>

<br>

- File operations need the executor's file functions. In Studio, use `SaveJSON` / `LoadJSON` with your own storage.
- File and config methods return `ok, err`.
- Auto save checks once a second and writes only when something changed. It writes to the config you last loaded, created or saved (`SaveManager:GetActiveConfig()`), or to `autosave` if there is none. Just selecting a config in the list never makes it the target.
- Configs and themes are validated before they are applied, and a failed load rolls back. Unknown IDs are ignored, so old configs keep working after you remove a control.
- Create all tabs and controls before loading a config. After replacing a window, call `SetLibrary` again.
- On touch devices, Viz uses plain Frames instead of CanvasGroups so the UI does not render blank when texture memory runs out. Force a mode with `CanvasGroups = true` / `false` in `CreateWindow`.
- Icons need `getcustomasset` to load the Lucide font. Without it, Viz falls back to a built-in sprite set with fewer icons.

</details>

## Credits

- Some features and API names are adapted from [Obsidian](https://github.com/deividcomsono/Obsidian) by deividcomsono (MIT). The license notice is at the top of `Library.lua`; keep it when you redistribute.
- Icons by [Lucide](https://lucide.dev), loaded through [lucide-roblox-direct](https://github.com/notpoiu/lucide-roblox-direct).
