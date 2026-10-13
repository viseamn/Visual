local HttpService = game:GetService("HttpService")

local function newManager()
    local ThemeManager = { Version = "1.0.3", Folder = "Viz", Current = "Default" }
    local window, context
    local Theme, defaultTheme
    local presetListener
    local function bound()
        assert(context and context.IsAlive(), "SetLibrary must reference a live Viz window")
        return context
    end
    function ThemeManager:SetLibrary(library)
        assert(type(library) == "table", "SetLibrary expects a Viz library or window")
        local target = library._Viz and library or library.Window
        assert(target and target._Viz and target._Viz.IsAlive(), "Create a live Viz window before SetLibrary")
        if context and context ~= target._Viz then
            if context.Theme.OnPresetChanged == presetListener then context.Theme.OnPresetChanged = nil end
            self.ColorControls, self.FontControl, self.ImageControl = nil, nil, nil
            self.ContrastLabel, self.PresetSelector, self.StyleSection = nil, nil, nil
        end
        window = target
        context = window._Viz
        Theme, defaultTheme = window.Theme, context.Defaults
        self.BuiltInThemes = context.Theme.BuiltInThemes
        self.Current = context.Theme.Current
        presetListener = function(name) self.Current = name end
        context.Theme.OnPresetChanged = presetListener
        self.Library = library
        return self
    end
    local function safeName(name)
        return bound().Storage.SafeName(name)
    end
    local function hasFiles() return bound().Storage.Available() end
    local function folderPath(manager, category) return bound().Storage.Folder(manager, category) end
    local function writeJSON(manager, category, name, content)
        return bound().Storage.Write(manager, category, name, content)
    end
    local function readJSON(manager, category, name) return bound().Storage.Read(manager, category, name) end
    local function listJSON(manager, category) return bound().Storage.List(manager, category) end
    local function deleteJSON(manager, category, name) return bound().Storage.Delete(manager, category, name) end
    local function notify(info) return window:Notify(info) end
    local function showDialog(info) return window:Dialog(info) end
    local function report(title, ok, err)
        notify({ Title = title, Content = ok and "Done" or tostring(err), Icon = ok and "check" or "info" })
    end
    function ThemeManager:ApplyTheme(name)
        bound()
        local data = self.BuiltInThemes[name]
        if data then
            local full = table.clone(defaultTheme)
            for role, value in pairs(data) do
                full[role] = Color3.fromHex(value)
            end
            if not data.Accent then
                local function luminance(color) return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B end
                if math.abs(luminance(full.Accent) - luminance(full.Card)) < 0.35 then full.Accent = full.Text end
            end
            full.Selected = full.Background:Lerp(full.Accent, 0.18)
            full.Search = full.Card:Lerp(full.Background, 0.3)
            full.Navigation = full.Card:Lerp(full.Text, 0.08)
            full.Muted = full.Text:Lerp(full.Background, 0.55)
            full.Icon = full.Accent
            full.Hover = full.Card:Lerp(full.Accent, 0.16)
            full.Pressed = full.Card:Lerp(full.Accent, 0.3)
            full.Font = context.GetFont()
            full.BackgroundImage = ""
            local ok, err = self:ApplyThemeData(full)
            if ok then
                self.Current = name
                self:SyncPreset(name)
            end
            return ok, err
        end
        local ok, content = readJSON(self, "themes", name)
        if not ok then return false, content end
        local applied, err = self:LoadJSON(content)
        if applied then
            self.Current = name
            self:SyncPreset(name)
        end
        return applied, err
    end
    function ThemeManager:SaveJSON() return HttpService:JSONEncode(bound().ExportTheme()) end
    function ThemeManager:LoadJSON(content)
        local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
        if not ok then return false, "Invalid theme JSON" end
        return self:ApplyThemeData(data)
    end
    function ThemeManager:SaveCustomTheme(name, overwrite)
        bound()
        if not safeName(name) then return false, "Invalid theme name (maximum 64 characters)" end
        if self.BuiltInThemes[name] then return false, "Choose a custom theme name" end
        local ok, exists = pcall(function() return isfile(folderPath(self, "themes") .. "/" .. name .. ".json") end)
        if not ok then return false, exists end
        if exists and not overwrite then return false, "Theme already exists; use Overwrite theme." end
        if overwrite and not exists then return false, "Theme not found" end
        local encoded, content = pcall(function() return self:SaveJSON() end)
        if not encoded then return false, content end
        return writeJSON(self, "themes", name, content)
    end
    function ThemeManager:ReloadCustomThemes() return listJSON(self, "themes") end
    function ThemeManager:Delete(name)
        local ok, err = deleteJSON(self, "themes", name)
        if ok and self.Current == name then self:SyncPreset(nil) end
        return ok, err
    end
    function ThemeManager:SaveDefault(name)
        if not safeName(name) then return false, "Invalid theme name" end
        return pcall(function()
            local folder = folderPath(self, "themes")
            assert(self.BuiltInThemes[name] or isfile(folder .. "/" .. name .. ".json"), "Theme not found")
            writefile(self.Folder .. "/theme-default.txt", name)
        end)
    end
    function ThemeManager:LoadDefault()
        if not hasFiles() then return true end
        local ok, name = pcall(function()
            local path = self.Folder .. "/theme-default.txt"
            if isfile(path) then return readfile(path) end
        end)
        if not ok then return false, name end
        if not name then return true end
        name = name:match("^%s*(.-)%s*$")
        if not safeName(name) then return false, "Invalid default theme name" end
        return self:ApplyTheme(name)
    end

    function ThemeManager:SetFolder(name)
        assert(bound().Storage.SafeFolder(name), "Invalid folder")
        self.Folder = name:gsub("\\", "/")
        return self
    end
    function ThemeManager:Validate(data) return bound().Theme:Validate(data) end
    function ThemeManager:ApplyThemeData(data, keepPopup) return bound().Theme:ApplyThemeData(data, keepPopup) end
    function ThemeManager:GetContrastRatio() return bound().Theme:GetContrastRatio() end
    function ThemeManager:SyncPreset(name)
        self.Current = name
        bound().Theme:SyncPreset(name)
    end
    function ThemeManager:ApplyToTab(tab)
        local group = tab:AddGroup({ Name = "Appearance", Side = "Right", Icon = "palette" })
        local theme = group:AddTab("Theme")
        local colors = group:AddTab("Colors")
        local interface = group:AddTab("Interface")
        local saved = group:AddTab("Saved")
        self.StyleSection = interface
        if window.AddInterfaceControls then
            window:AddInterfaceControls(interface)
        else
            window:AddStyleControls(interface)
        end
        local builtIn = bound().Theme.BuiltInOrder or { "Default", "Light", "Black", "Mint", "Nord", "Dracula" }
        local function names()
            local result = table.clone(builtIn)
            if not hasFiles() then return result end
            local customNames, err = self:ReloadCustomThemes()
            if err then report("Refresh themes", false, err) end
            for _, name in ipairs(customNames) do
                if not self.BuiltInThemes[name] then table.insert(result, name) end
            end
            return result, err
        end
        local initialNames = names()
        local selector = theme:AddDropdown({
            Name = "Theme",
            Options = initialNames,
            Default = self.Current and table.find(initialNames, self.Current) and self.Current or initialNames[1],
            FormatDisplayValue = function(value, fallback) return value == nil and "Custom" or fallback end,
            AllowNull = true,
            NoSave = true,
            Callback = function(value)
                if value then
                    local ok, err = self:ApplyTheme(value)
                    if not ok then
                        self:SyncPreset(self.Current)
                        report("Theme", ok, err)
                    end
                end
            end,
        })
        self.PresetSelector = selector
        self.FontControl = theme:AddDropdown({
            Name = "Font",
            Options = table.clone(context.Fonts or { "BuilderSans", "Code", "Gotham", "SourceSans" }),
            Default = context.GetFont(),
            NoSave = true,
            Callback = function(value)
                if value then self:ApplyThemeData({ Font = value }) end
            end,
        })
        self.ImageControl = theme:AddTextbox({
            Name = "Background",
            Default = context.Theme.BackgroundImage or "",
            Placeholder = "Image asset ID",
            NoSave = true,
            Callback = function(value)
                local ok, err = self:ApplyThemeData({ BackgroundImage = value:match("^%s*(.-)%s*$") })
                if not ok then
                    self.ImageControl.Text = context.Theme.BackgroundImage or ""
                    report("Background image", ok, err)
                end
            end,
        })
        theme:AddButton({
            Name = "Reset theme",
            Callback = function()
                showDialog({
                    Title = "Reset theme",
                    Content = "Restore the default UI colors and font?",
                    OnConfirm = function()
                        self:ApplyThemeData({ Font = "BuilderSans" })
                        local ok, err = self:ApplyTheme("Default")
                        if ok then
                            selector:Set("Default", true)
                        else
                            report("Reset theme", ok, err)
                        end
                    end,
                })
            end,
        })
        self.ColorControls = {}
        for _, role in ipairs({ "Accent", "Icon", "Background", "Card", "Text", "Border" }) do
            self.ColorControls[role] = colors:AddColorPicker({
                Name = role,
                Default = Theme[role],
                Alpha = false,
                NoSave = true,
                Callback = function(color) self:ApplyThemeData({ [role] = color }, true) end,
            })
        end
        self.ContrastLabel = colors:AddLabel(
            string.format(
                "Text/card contrast: %s (%.1f:1)",
                self:GetContrastRatio() >= 4.5 and "good" or "low",
                self:GetContrastRatio()
            )
        )
        local nameBox = saved:AddTextbox({ Name = "Name", Placeholder = "My theme", NoSave = true })
        local function refreshList()
            local values, err = names()
            if not err then
                selector:SetValues(values, true)
                self:SyncPreset(self.Current)
            end
        end
        local function typedName()
            local name = nameBox.Text:match("^%s*(.-)%s*$")
            return name ~= "" and name or self.Current
        end
        local function saveTheme()
            local name = nameBox.Text:match("^%s*(.-)%s*$")
            local function finish(ok, err)
                if ok then
                    refreshList()
                    self:SyncPreset(name)
                end
                report("Save theme", ok, err)
            end
            local ok, err = self:SaveCustomTheme(name)
            if not ok and tostring(err):find("already exists", 1, true) then
                showDialog({
                    Title = "Save theme",
                    Content = 'Replace "' .. name .. '" with the current theme?',
                    ConfirmText = "Replace",
                    OnConfirm = function() finish(self:SaveCustomTheme(name, true)) end,
                })
                return
            end
            finish(ok, err)
        end
        nameBox.FocusLost:Connect(function(enterPressed)
            if enterPressed and nameBox.Text:match("%S") then saveTheme() end
        end)
        saved:AddButton({
            Name = "Save",
            Callback = saveTheme,
            Buttons = {
                {
                    Name = "Set default",
                    Callback = function()
                        local name = typedName()
                        if not name then
                            report("Default theme", false, "Save this theme first")
                            return
                        end
                        report("Default theme", self:SaveDefault(name))
                    end,
                },
                {
                    Name = "Delete",
                    Callback = function()
                        local name = typedName()
                        if not name or self.BuiltInThemes[name] then
                            report("Delete theme", false, "Enter a saved theme name")
                            return
                        end
                        showDialog({
                            Title = "Delete theme",
                            Content = 'Delete "' .. name .. '"?',
                            ConfirmText = "Delete",
                            OnConfirm = function()
                                local ok, err = self:Delete(name)
                                if ok then
                                    if self.Current == name then self:SyncPreset(nil) end
                                    refreshList()
                                end
                                report("Delete theme", ok, err)
                            end,
                        })
                    end,
                },
            },
        })
        local core = bound().Theme
        core.ColorControls, core.FontControl, core.ImageControl =
            self.ColorControls, self.FontControl, self.ImageControl
        core.ContrastLabel, core.PresetSelector = self.ContrastLabel, self.PresetSelector
        self:SyncPreset(self.Current)
        return group
    end

    ThemeManager.new = newManager
    return ThemeManager
end

return newManager()
