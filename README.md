<p align="center">
  <img src="assets/banner.jpg" alt="Viz — Roblox UI library" width="100%">
</p>

<p align="center">
  A Roblox UI library with movable panels, keybinds, themes and saved configs.
</p>

<p align="center">
  <a href="#getting-started">Getting started</a> &nbsp; / &nbsp;
  <a href="#controls">Controls</a> &nbsp; / &nbsp;
  <a href="#window">Window</a> &nbsp; / &nbsp;
  <a href="#themes--configs">Themes &amp; configs</a> &nbsp; / &nbsp;
  <a href="Example.lua">Full example</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/1.0.3-22232E?style=flat-square&label=Viz" alt="Viz 1.0.3">
  <img src="https://img.shields.io/badge/Luau-22232E?style=flat-square&label=Roblox" alt="Roblox Luau">
</p>

## Getting started

Run the demo to try the controls:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/viseamn/Visual/main/Example.lua"))()
```

Or start with a window and add what you need:

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

local Main = Window:AddTab("Main", "house")
local Settings = Window:CreateSettingsTab()
local Group = Main:AddLeftGroupbox("Controls", "sliders-horizontal")

Group:AddToggle("Enabled", {
    Text = "Enabled",
    Default = true,
    Keybind = "F",
})

Group:AddSlider("Speed", {
    Text = "Speed",
    Min = 0,
    Max = 100,
    Default = 50,
    Callback = function(value)
        print("Speed:", value)
    end,
})

ThemeManager:SetLibrary(Window)
SaveManager:SetLibrary(Window)
ThemeManager:SetFolder("Viz/MyGame")
SaveManager:SetFolder("Viz/MyGame")

SaveManager:BuildConfigSection(Settings)
ThemeManager:ApplyToTab(Settings)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
```

<details>
<summary><b>Using Roblox Studio</b></summary>

Create three ModuleScripts named `Library`, `ThemeManager` and `SaveManager` beside a LocalScript. Replace the three `loadstring` calls with:

```lua
local Library = require(script.Parent.Library)
local ThemeManager = require(script.Parent.ThemeManager)
local SaveManager = require(script.Parent.SaveManager)
```

Viz runs on the client. In Studio, use JSON import/export with your own storage; executor file functions are unavailable.

</details>

## What's included

| | |
| :--- | :--- |
| **Layout** | Dock on any screen edge, auto-hide, draggable and resizable window |
| **Panels** | Collapsible groupboxes, sections and detachable cards |
| **Controls** | Toggles, sliders, dropdowns, textboxes, keybinds, color pickers and more |
| **Search** | Filter tabs, panels and controls as you type |
| **Appearance** | 18 theme presets, 16 fonts, custom colors and 50–200% DPI scale |
| **Configs** | Save, load, autosave, startup configs and JSON import/export |

## Controls

Use a unique string ID for each saved control. Changing its label later won't break existing configs.

```lua
Group:AddToggle("MyToggle", { Text = "Toggle", Default = false })
Group:AddCheckbox("MyCheckbox", { Text = "Checkbox", Default = false })
Group:AddSlider("MySlider", { Text = "Slider", Min = 0, Max = 100, Default = 50 })
Group:AddRangeSlider("MyRange", { Text = "Range", Min = 0, Max = 100, Default = { 20, 80 } })
Group:AddInput("MyInput", { Text = "Textbox", Placeholder = "Type here" })
Group:AddKeybind("MyKey", { Text = "Keybind", Default = Enum.KeyCode.G })
Group:AddColorPicker("MyColor", { Text = "Color", Default = Color3.fromRGB(255, 255, 255) })
Group:AddDropdown("MyDropdown", { Text = "Dropdown", Values = { "One", "Two" }, Default = "One" })
Group:AddDropdown("MyMulti", { Text = "Multi", Values = { "A", "B", "C" }, Multi = true })
Group:AddButton({ Text = "Button", Callback = function() print("Pressed") end })
Group:AddLabel("Status: ready")
Group:AddDivider()
```

Read values or update controls through `Library.Toggles` and `Library.Options`:

```lua
local Toggles, Options = Library.Toggles, Library.Options

print(Toggles.MyToggle.Value)
Options.MySlider:SetValue(75)
Toggles.MyToggle:OnChanged(function(value)
    print("Toggle:", value)
end)
```

Most controls accept `Callback`, `Tooltip`, `Disabled`, `Visible` and `NoSave`. See [Example.lua](Example.lua) for every control type.

<details>
<summary><b>Toggles &amp; keybinds</b></summary>

Click a toggle or drag its thumb. A drag commits on release.

```lua
Toggles.MyToggle:AddKeyPicker("MyKey", {
    Default = "F",
    Mode = "Hold",
    Text = "My toggle",
})

Options.MyKey:SetValue({ "G", "Toggle" })
Toggles.MyToggle:AddColorPicker({ Default = Color3.fromRGB(255, 255, 255) })
```

- `Keybind = "F"` in the toggle options is shorthand for adding a key picker.
- Modes: `"Toggle"`, `"Hold"` and `"Always"`. Add modifiers with `Modifiers = { Ctrl = true }`.
- Click the key box to open the picker. **Backspace** clears the key; **Escape** cancels.
- `NoUI = true` leaves the binding out of the keybind list.
- Set `Notify = true` or `false` to add the notification bell. Omit it to leave the bell out.
- `AddKeybind` picks a key; it doesn't run an action by itself.

</details>

<details>
<summary><b>Dropdowns</b></summary>

`Values` accepts a list or a map of keys to labels. Multi dropdowns return a selection map, such as `{ A = true, C = true }`.

```lua
Group:AddDropdown("Players", { Text = "Player", SpecialType = "Player" })
Group:AddDropdown("Teams", { Text = "Team", SpecialType = "Team" })
```

| Option | Effect |
| :--- | :--- |
| `Multi = true` | Select several values |
| `Searchable = false` | Hide the search box |
| `MaxVisibleDropdownItems` | Set the number of rows before scrolling |
| `SpecialType = "Player"` or `"Team"` | Keep the list in sync with the server |
| `EnablePlayerImages = false` | Hide player avatars |
| `ValueImages = { key = "rbxassetid://..." }` | Add images to rows |
| `DisabledValues` | Disable specific values |
| `AllowNull` | Allow an empty selection |
| `FormatDisplayValue` | Customize the selected-value text |
| `DragSelect` | Select multiple rows by dragging |

</details>

<details>
<summary><b>Textbox validation</b></summary>

```lua
local Input = Group:AddInput("Count", {
    Text = "Count",
    Default = "10",
    Numeric = true,
    MaxLength = 3,
    AllowEmpty = false,
    EmptyReset = "10",
    Finished = true,
    VerifyValue = function(text)
        return tonumber(text) <= 100
    end,
})

Group:GetControl(Input):OnChanged(function(value)
    print(value)
end)
```

`Finished = true` commits on Enter; `false` commits while typing. Omit it to commit on focus loss. Invalid edits revert to the last valid value. `MaxLength` counts Unicode characters.

`ClearTextOnFocus` and `ClearTextOnBlur` are also available.

</details>

<details>
<summary><b>Panels, sections &amp; dependencies</b></summary>

Use `Tab:AddLeftGroupbox(name, icon)` or `AddRightGroupbox(name, icon)`. Icons use [Lucide](https://lucide.dev/icons) names. `Group:AddTab("General")` adds a section inside a panel.

Drag a panel's header outside the window to detach it. Drop it back inside to reattach. You can also call `SetCollapsed`, `ToggleCollapsed`, `Detach`, `Attach` and `IsDetached`.

Dependency boxes show their rows when every condition matches:

```lua
local Dep = Group:AddDependencyBox()
Dep:AddSlider("Strength", { Text = "Strength", Min = 1, Max = 10, Default = 5 })
Dep:SetupDependencies({ { Toggles.MyToggle, true } })
```

For a multi dropdown, the expected key must be selected.

`Group:GetControl(control)` returns the API for a control, including `SetText`, `SetDisabled`, `SetVisible`, `OnChanged` and `Destroy`.

To put buttons on the same row:

```lua
Group:AddButton({
    Text = "Left",
    Callback = function() print("Left") end,
    Buttons = {
        { Name = "Right", Callback = function() print("Right") end },
    },
})
```

</details>

## Window

```lua
local Window = Library:CreateWindow({
    Title = "Viz",
    Size = Vector2.new(640, 460),
    Layout = "Bottom bar",
    SearchStyle = "Bar",
    MenuKey = Enum.KeyCode.RightShift,
    AutoHide = false,
    NotificationPosition = "BottomRight",
    DPIScale = 1,
})
```

`Layout` accepts `"Bottom bar"`, `"Top bar"`, `"Left bar"` or `"Right bar"`. `SearchStyle` accepts `"Bar"` or `"Header"`.

<details>
<summary><b>Window methods</b></summary>

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
Window:Dialog({
    Title = "Continue?",
    Content = "Confirm this action.",
    OnConfirm = function() end,
})

Library:Unload()
```

With ThemeManager, interface settings live under **Settings → Appearance → Interface**. Otherwise, `CreateSettingsTab` adds an Interface card. Use `Window:AddInterfaceControls(section)` to place them yourself.

Drag the window to move it; drag the bottom-right corner to resize it. A floating show/hide button is enabled by default on touch devices. Set `ToggleButton = true` to enable it elsewhere.

</details>

## Themes & configs

Both managers accept a window or the library through `SetLibrary`. Create your controls before loading a config. Call `SetLibrary` again after replacing a window.

```lua
ThemeManager:ApplyTheme("Tokyo Night")
ThemeManager:ApplyThemeData({ Accent = Color3.fromRGB(87, 212, 178) })
ThemeManager:ApplyThemeData({ Font = "Montserrat" })
ThemeManager:SaveCustomTheme("My theme")
ThemeManager:SaveDefault("My theme")

SaveManager:Create("default")
SaveManager:Overwrite("default")
SaveManager:Load("default")
SaveManager:SaveAutoloadConfig("default")
SaveManager:SetAutoSave(true)
SaveManager:SetIgnoreIndexes({ "TemporaryControl" })
```

`Create` refuses to replace an existing config. Use `Overwrite` to replace one. File save/load methods return `ok, err`:

```lua
local ok, err = SaveManager:Load("default")
if not ok then warn(err) end
```

<details>
<summary><b>Presets &amp; fonts</b></summary>

**Dark:** Default, Orchid, Black, Mint, Nord, Dracula, Catppuccin, Tokyo Night, Gruvbox, One Dark, Rose Pine, Monokai, Solarized, Ocean, Crimson.

**Light:** Light, Latte, Sakura.

Presets keep the current font. Available fonts: BuilderSans, Gotham, SourceSans, Roboto, Montserrat, Nunito, Ubuntu, Arimo, JosefinSans, TitilliumWeb, Oswald, Jura, Michroma, FredokaOne, Code and RobotoMono.

</details>

<details>
<summary><b>Autosave &amp; JSON</b></summary>

Autosave checks once a second and writes only when data changes. It saves to the last config you loaded, created or saved, or to `autosave` if there isn't one. Selecting a config in the list doesn't change the save target.

```lua
print(SaveManager:GetActiveConfig())
SaveManager.AutoSaveInterval = 2
SaveManager:SetAutoSave(true)

local json = SaveManager:SaveJSON()
local ok, err = SaveManager:LoadJSON(json)
```

The autosave preference is remembered between sessions. When enabled, the manual Save button and New config field are hidden.

Configs are validated before applying values. A failed application rolls back; a callback error is reported after values have loaded. Unknown control IDs are ignored. Changing the manager's folder or window stops autosave and clears the active config.

</details>

<details>
<summary><b>Runtime notes</b></summary>

- File storage requires executor file functions. JSON import/export works with your own storage.
- On touch devices, Viz uses Frames instead of CanvasGroups to reduce texture-memory issues. Override this with `CanvasGroups = true` or `false` in `CreateWindow`.
- The Lucide font needs `getcustomasset`. Without it, Viz uses a smaller built-in icon sprite set.

</details>

## Source

| File | Contents |
| :--- | :--- |
| [Library.lua](Library.lua) | Window, panels, controls, input and animation |
| [ThemeManager.lua](ThemeManager.lua) | Theme presets, custom themes and appearance settings |
| [SaveManager.lua](SaveManager.lua) | Config files, autosave, startup loading and JSON |
| [Example.lua](Example.lua) | A working example of every control |

## Credits

Some features and API names are adapted from [Obsidian](https://github.com/deividcomsono/Obsidian) by deividcomsono. Icons are from [Lucide](https://lucide.dev), loaded through [lucide-roblox-direct](https://github.com/notpoiu/lucide-roblox-direct).
