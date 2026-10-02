local HttpService = game:GetService("HttpService")

local function newManager()
    local ThemeManager = { Version = "1.0.2", Folder = "Viz", Current = "Default" }
    local window, context
    local Theme, defaultTheme
    local function bound()
        assert(context and context.IsAlive(), "SetLibrary must reference a live Viz window")
        return context
    end
    function ThemeManager:SetLibrary(library)
        assert(type(library) == "table", "SetLibrary expects a Viz library or window")
        window = library._Viz and library or library.Window
        assert(window and window._Viz, "Create a Viz window before SetLibrary")
        context = window._Viz
        Theme, defaultTheme = window.Theme, context.Defaults
        self.BuiltInThemes = context.Theme.BuiltInThemes
        self.Library = library
        return self
    end
    local function safeName(name)
        return type(name) == "string"
            and #name > 0
            and #name <= 80
            and name:match("^[%w _%-]+$") ~= nil
            and name:match("%S") ~= nil
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
            full.Selected = full.Background:Lerp(full.Accent, 0.18)
            full.Search = full.Card:Lerp(full.Background, 0.3)
            full.Navigation = full.Card:Lerp(full.Text, 0.08)
            full.Muted = full.Text:Lerp(full.Background, 0.55)
            full.Icon = full.Accent
            full.Hover = full.Card:Lerp(full.Accent, 0.16)
            full.Pressed = full.Card:Lerp(full.Accent, 0.3)
            full.Font = "BuilderSans"
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
    function ThemeManager:SaveCustomTheme(name)
        if self.BuiltInThemes[name] then return false, "Choose a custom theme name" end
        return writeJSON(self, "themes", name, self:SaveJSON())
    end
    function ThemeManager:ReloadCustomThemes() return listJSON(self, "themes") end
    function ThemeManager:Delete(name) return deleteJSON(self, "themes", name) end
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
        return self:ApplyTheme(name)
    end

    function ThemeManager:SetFolder(name)
        assert(bound().Storage.SafeFolder(name), "Invalid folder")
        self.Folder = name:gsub("\\", "/")
    end
    function ThemeManager:Validate(data) return bound().Theme:Validate(data) end
    function ThemeManager:ApplyThemeData(data, keepPopup) return bound().Theme:ApplyThemeData(data, keepPopup) end
    function ThemeManager:GetContrastRatio() return bound().Theme:GetContrastRatio() end
    function ThemeManager:SyncPreset(name)
        bound().Theme.Current = name
        bound().Theme:SyncPreset(name)
    end
    function ThemeManager:ApplyToTab(tab)
        local group = tab:AddGroup({ Name = "Themes", Side = "Right", Icon = "palette" })
        local colors = group:AddTab("Colors")
        local style = group:AddTab("Style")
        self.StyleSection = style
        window:AddStyleControls(style)
        local saved = group:AddTab("Presets")
        local function names()
            local result = { "Default", "Light", "Black", "Mint", "Nord", "Dracula" }
            for _, name in ipairs(self:ReloadCustomThemes()) do
                if not self.BuiltInThemes[name] then table.insert(result, name) end
            end
            return result
        end
        local selector = saved:AddDropdown({
            Name = "Theme",
            Options = names(),
            Default = "Default",
            NoSave = true,
            Callback = function(value)
                if value then
                    local ok, err = self:ApplyTheme(value)
                    if not ok then report("Theme", ok, err) end
                end
            end,
        })
        self.PresetSelector = selector
        self.ColorControls = {}
        for _, role in ipairs({ "Accent", "Icon", "Background", "Card", "Text", "Border" }) do
            self.ColorControls[role] = colors:AddColorPicker({
                Name = role,
                Default = Theme[role],
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
        self.FontControl = style:AddDropdown({
            Name = "Font Face",
            Options = { "BuilderSans", "Code", "Gotham", "SourceSans" },
            Default = context.GetFont(),
            NoSave = true,
            Callback = function(value) self:ApplyThemeData({ Font = value }) end,
        })
        self.ImageControl = style:AddTextbox({
            Name = "Background Image",
            Placeholder = "Roblox asset ID",
            NoSave = true,
            Callback = function(value)
                local ok, err = self:ApplyThemeData({ BackgroundImage = value:match("^%s*(.-)%s*$") })
                if not ok then
                    self.ImageControl.Text = context.Theme.BackgroundImage or ""
                    report("Background image", ok, err)
                end
            end,
        })
        style:AddButton({
            Name = "Reset theme",
            Callback = function()
                showDialog({
                    Title = "Reset theme",
                    Content = "Restore the default UI colors?",
                    OnConfirm = function()
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
        saved:AddDivider()
        local nameBox = saved:AddTextbox({ Name = "Theme name", Default = "My theme", NoSave = true })
        saved:AddButton({
            Name = "Save theme",
            Callback = function()
                local ok, err = self:SaveCustomTheme(nameBox.Text)
                if ok then
                    selector:SetValues(names())
                    selector:Set(nameBox.Text, true)
                    self.Current = nameBox.Text
                end
                report("Save theme", ok, err)
            end,
        })
        saved:AddButton({
            Name = "Set default theme",
            Callback = function() report("Default theme", self:SaveDefault(selector.Value)) end,
        })
        saved:AddButton({
            Name = "Refresh themes",
            Callback = function() selector:SetValues(names()) end,
        })
        saved:AddButton({
            Name = "Delete custom theme",
            Callback = function()
                local name = selector.Value
                if not name then return end
                showDialog({
                    Title = "Delete theme",
                    Content = 'Delete "' .. name .. '"?',
                    ConfirmText = "Delete",
                    OnConfirm = function()
                        local ok, err = self:Delete(name)
                        if ok then selector:SetValues(names()) end
                        report("Delete theme", ok, err)
                    end,
                })
            end,
        })
        local core = bound().Theme
        core.ColorControls, core.FontControl, core.ImageControl =
            self.ColorControls, self.FontControl, self.ImageControl
        core.ContrastLabel, core.PresetSelector = self.ContrastLabel, self.PresetSelector
        return group
    end

    ThemeManager.new = newManager
    return ThemeManager
end

return newManager()
