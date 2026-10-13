local HttpService = game:GetService("HttpService")

local function newManager()
    local SaveManager = { Version = "1.0.3", Folder = "Viz", Ignore = {} }
    local window, context
    local controlRegistry, ThemeManager
    local function bound()
        assert(context and context.IsAlive(), "SetLibrary must reference a live Viz window")
        return context
    end
    function SaveManager:SetLibrary(library)
        assert(type(library) == "table", "SetLibrary expects a Viz library or window")
        window = library._Viz and library or library.Window
        assert(window and window._Viz, "Create a Viz window before SetLibrary")
        context = window._Viz
        controlRegistry = context.Registry
        ThemeManager = context.Theme
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
    function SaveManager:SetFolder(name)
        assert(bound().Storage.SafeFolder(name), "Invalid folder")
        self.Folder = name:gsub("\\", "/")
    end
    function SaveManager:SetIgnoreIndexes(indexes)
        self.Ignore = {}
        for _, id in ipairs(indexes or {}) do
            self.Ignore[id] = true
        end
    end
    function SaveManager:IgnoreThemeSettings() self.IgnoreTheme = true end
    local function snapshot(self)
        bound()
        local data = { Format = "Viz", Version = 1, Controls = {} }
        for id, entry in pairs(controlRegistry) do
            if not self.Ignore[id] then data.Controls[id] = { Type = entry.Kind, Value = entry.Read() } end
        end
        if not self.IgnoreTheme then data.Theme = context.ExportTheme() end
        return data
    end
    function SaveManager:SaveJSON() return HttpService:JSONEncode(snapshot(self)) end

    -- Auto save: once a second, write the current settings to the active config when they differ from what
    -- was last written or loaded. The active config is the one last loaded, created or saved ("autosave" if
    -- none), never merely the one highlighted in the list, so browsing configs cannot overwrite them.
    local function same(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        for key, value in pairs(a) do
            if not same(value, b[key]) then return false end
        end
        for key in pairs(b) do
            if a[key] == nil then return false end
        end
        return true
    end
    local lastWritten, autoSaveRunning
    SaveManager.AutoSave = false
    SaveManager.AutoSaveInterval = 1
    local function markActive(self, name)
        self.ActiveConfig = name
        local ok, data = pcall(snapshot, self)
        lastWritten = ok and data or nil
        if self.OnActiveConfigChanged then self.OnActiveConfigChanged(name) end
    end
    function SaveManager:GetActiveConfig() return self.ActiveConfig end
    local function autoSaveStep(self)
        local ok, data = pcall(snapshot, self)
        if not ok or same(data, lastWritten) then return end
        local name = self.ActiveConfig or "autosave"
        local written, err = writeJSON(self, "configs", name, HttpService:JSONEncode(data))
        if not written then
            self:SetAutoSave(false)
            report("Auto save", false, err)
            return
        end
        lastWritten = data
        if not self.ActiveConfig then markActive(self, name) end
        if self.OnAutoSaved then self.OnAutoSaved(name) end
    end
    function SaveManager:SetAutoSave(enabled)
        enabled = enabled == true
        if enabled and not hasFiles() then return false, "File storage unavailable" end
        self.AutoSave = enabled
        if hasFiles() then pcall(function()
            folderPath(self, "configs")
            writefile(self.Folder .. "/autosave.txt", enabled and "1" or "0")
        end) end
        if self.OnAutoSaveChanged then self.OnAutoSaveChanged(enabled) end
        if enabled and not autoSaveRunning then
            autoSaveRunning = true
            task.spawn(function()
                -- Wait first, so a setup script can still load its autoload config before anything is written.
                while true do
                    task.wait(self.AutoSaveInterval)
                    if not (self.AutoSave and context and context.IsAlive()) then break end
                    autoSaveStep(self)
                end
                autoSaveRunning = false
            end)
        end
        return true
    end
    function SaveManager:IsAutoSaveEnabled() return self.AutoSave end
    local function savedAutoSave(self)
        if not hasFiles() then return false end
        local ok, value = pcall(function()
            local path = self.Folder .. "/autosave.txt"
            return isfile(path) and readfile(path)
        end)
        return ok and value == "1"
    end
    local function loadJSON(self, content)
        bound()
        local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
        if not ok or type(data) ~= "table" or data.Version ~= 1 or type(data.Controls) ~= "table" then
            return false, "Invalid Viz config"
        end
        local pending = {}
        for id, saved in pairs(data.Controls) do
            local entry = controlRegistry[id]
            if entry and not self.Ignore[id] then
                if type(saved) ~= "table" or saved.Type ~= entry.Kind then
                    return false, "Control type mismatch: " .. id
                end
                local valid, result = pcall(entry.Validate, saved.Value)
                if not valid or not result then return false, "Invalid value: " .. id end
                table.insert(pending, { Id = id, Entry = entry, Value = saved.Value })
            end
        end
        if data.Theme and not self.IgnoreTheme then
            local valid, err = ThemeManager:Validate(data.Theme)
            if not valid then return false, err end
        end
        table.sort(pending, function(a, b) return a.Id < b.Id end)
        local previousTheme = data.Theme and not self.IgnoreTheme and context.ExportTheme() or nil
        local previousPreset = ThemeManager.Current
        context.SetLoading(true)
        local applied, err = pcall(function()
            window._Viz.CancelInteractions(true)
            for _, item in ipairs(pending) do
                item.Previous = item.Entry.Read()
                item.Snapshotted = true
            end
            for _, item in ipairs(pending) do
                item.Entry.Write(item.Value)
            end
            if data.Theme and not self.IgnoreTheme then
                local success, themeError = ThemeManager:ApplyThemeData(data.Theme)
                if not success then error(themeError or "Theme could not be applied") end
            end
        end)
        if not applied then
            for _, item in ipairs(pending) do
                if item.Snapshotted then pcall(item.Entry.Write, item.Previous) end
            end
            if previousTheme then
                pcall(ThemeManager.ApplyThemeData, ThemeManager, previousTheme)
                pcall(ThemeManager.SyncPreset, ThemeManager, previousPreset)
            end
            context.SetLoading(false)
            return false, tostring(err)
        end
        local callbackErrors = {}
        for _, item in ipairs(pending) do
            if item.Entry.Changed then
                local success, callbackError = pcall(item.Entry.Changed)
                if not success then table.insert(callbackErrors, tostring(callbackError)) end
            end
        end
        context.SetLoading(false)
        if #callbackErrors > 0 then return false, "Values loaded; a callback failed: " .. callbackErrors[1] end
        return true
    end
    function SaveManager:LoadJSON(content)
        local ok, result, err = pcall(loadJSON, self, content)
        if context then context.SetLoading(false) end
        if not ok then return false, tostring(result) end
        return result, err
    end
    function SaveManager:Save(name)
        local ok, content = pcall(function() return self:SaveJSON() end)
        if not ok then return false, content end
        local written, err = writeJSON(self, "configs", name, content)
        if written then markActive(self, name) end
        return written, err
    end
    function SaveManager:Create(name)
        if not safeName(name) then return false, "Invalid config name" end
        local ok, exists = pcall(function() return isfile(folderPath(self, "configs") .. "/" .. name .. ".json") end)
        if not ok then return false, exists end
        if exists then return false, "Config already exists; use Overwrite config." end
        return self:Save(name)
    end
    function SaveManager:Overwrite(name)
        if not safeName(name) then return false, "Select a saved config first" end
        local ok, exists = pcall(function() return isfile(folderPath(self, "configs") .. "/" .. name .. ".json") end)
        if not ok then return false, exists end
        if not exists then return false, "Config not found" end
        return self:Save(name)
    end
    function SaveManager:Load(name)
        local ok, content = readJSON(self, "configs", name)
        if not ok then return false, content end
        local loaded, err = self:LoadJSON(content)
        -- Even when only a callback failed the values are in place, so auto save continues into this config.
        if loaded or (err and err:find("^Values loaded")) then markActive(self, name) end
        return loaded, err
    end
    function SaveManager:RefreshConfigList() return listJSON(self, "configs") end
    function SaveManager:Delete(name)
        local ok, err = deleteJSON(self, "configs", name)
        if ok and self.ActiveConfig == name then
            self.ActiveConfig = nil
            if self.OnActiveConfigChanged then self.OnActiveConfigChanged(nil) end
        end
        return ok, err
    end
    function SaveManager:SaveAutoloadConfig(name)
        if not safeName(name) then return false, "Select a saved config first" end
        return pcall(function()
            local folder = folderPath(self, "configs")
            assert(isfile(folder .. "/" .. name .. ".json"), "Config not found")
            writefile(self.Folder .. "/autoload.txt", name)
        end)
    end
    function SaveManager:GetAutoloadConfig()
        if not hasFiles() then return nil end
        local ok, name = pcall(function()
            local path = self.Folder .. "/autoload.txt"
            if isfile(path) then return readfile(path) end
        end)
        return ok and safeName(name) and name or nil
    end
    function SaveManager:LoadAutoloadConfig()
        local name = self:GetAutoloadConfig()
        if not name then return true end
        return self:Load(name)
    end
    function SaveManager:DeleteAutoLoadConfig()
        return pcall(function()
            assert(hasFiles() and type(delfile) == "function", "Deleting files is unavailable")
            local path = self.Folder .. "/autoload.txt"
            if isfile(path) then delfile(path) end
        end)
    end

    function SaveManager:BuildConfigSection(tab)
        local group = tab:AddGroup({ Name = "Configurations", Side = "Left", Icon = "settings" })
        local files = group:AddTab("Configs")
        local transfer = group:AddTab("JSON")
        if not hasFiles() then
            files:AddLabel("File storage unavailable. Use the JSON tab to import and export configs.")
        end
        local function configNames()
            if not hasFiles() then return {} end
            local names, err = self:RefreshConfigList()
            if err then report("Refresh configs", false, err) end
            return names, err
        end
        local selector = files:AddDropdown({ Name = "Config", Options = configNames(), NoSave = true })
        local status
        local autoloadBox
        local refreshing = false
        local function refresh()
            -- SetValues can report a changed selection, which calls back into refresh.
            if refreshing then return end
            refreshing = true
            local names, err = configNames()
            if not err then pcall(selector.SetValues, selector, names) end
            refreshing = false
            local autoload = self:GetAutoloadConfig()
            if autoloadBox then autoloadBox:Set(autoload ~= nil and autoload == selector.Value, true) end
            if status then
                status.Text = string.format(
                    "%s: %s  ·  Autoload: %s",
                    self.AutoSave and "Auto saving to" or "Active",
                    self.ActiveConfig or (self.AutoSave and "autosave" or "None"),
                    autoload or "None"
                )
            end
        end
        files:AddButton({
            Name = "Load",
            Callback = function()
                local ok, err = self:Load(selector.Value)
                refresh()
                report("Load config", ok, err)
            end,
            Buttons = {
                { Name = "Refresh", Callback = refresh },
                {
                    Name = "Delete",
                    Callback = function()
                        local name = selector.Value
                        if not name then
                            report("Delete config", false, "Select a saved config first")
                            return
                        end
                        showDialog({
                            Title = "Delete config",
                            Content = 'Delete "' .. name .. '"?',
                            ConfirmText = "Delete",
                            OnConfirm = function()
                                local ok, err = self:Delete(name)
                                if ok and self:GetAutoloadConfig() == name then self:DeleteAutoLoadConfig() end
                                refresh()
                                report("Delete config", ok, err)
                            end,
                        })
                    end,
                },
            },
        })
        -- Manual saving; disabled while auto save is on.
        local nameBox = files:AddTextbox({ Name = "New config", Placeholder = "Config name", NoSave = true })
        local saveButtons = files:AddButton({
            Name = "Create",
            Callback = function()
                local name = nameBox.Text:match("^%s*(.-)%s*$")
                local ok, err = self:Create(name)
                if ok then
                    nameBox.Text = ""
                    refresh()
                    selector:Set(name, true)
                    refresh()
                end
                report("Create config", ok, err)
            end,
            Buttons = {
                {
                    Name = "Save",
                    Callback = function()
                        local name = selector.Value
                        if not name then
                            report("Save config", false, "Select a saved config first")
                            return
                        end
                        showDialog({
                            Title = "Save config",
                            Content = 'Replace "' .. name .. '" with the current settings?',
                            ConfirmText = "Save",
                            OnConfirm = function()
                                local ok, err = self:Overwrite(name)
                                refresh()
                                report("Save config", ok, err)
                            end,
                        })
                    end,
                },
            },
        })
        files:AddDivider()
        local autoSaveBox = files:AddCheckbox({
            Name = "Auto save",
            Default = self.AutoSave,
            NoSave = true,
            Callback = function(value)
                local ok, err = self:SetAutoSave(value)
                if not ok then report("Auto save", ok, err) end
            end,
        })
        autoloadBox = files:AddCheckbox({
            Name = "Load selected on startup",
            Default = false,
            NoSave = true,
            Callback = function(value)
                local ok, err
                if value then
                    ok, err = self:SaveAutoloadConfig(selector.Value)
                else
                    ok, err = self:DeleteAutoLoadConfig()
                end
                refresh()
                if not ok then report("Autoload", ok, err) end
            end,
        })
        status = files:AddLabel("")
        selector:OnChanged(refresh)
        local function applyAutoSaveState(enabled)
            autoSaveBox:Set(enabled, true)
            group:SetControlDisabled(nameBox, enabled)
            group:SetControlDisabled(saveButtons, enabled)
            refresh()
        end
        self.OnAutoSaveChanged = applyAutoSaveState
        self.OnActiveConfigChanged = function() refresh() end
        self.OnAutoSaved = function() refresh() end
        if not hasFiles() then
            group:SetControlDisabled(autoSaveBox, true)
            group:SetControlDisabled(autoloadBox, true)
        end
        -- Restore the auto save choice from the last session.
        if savedAutoSave(self) then self:SetAutoSave(true) else applyAutoSaveState(self.AutoSave) end

        local jsonBox = transfer:AddTextbox({
            Name = "Config JSON",
            Placeholder = "Paste Viz config JSON",
            NoSave = true,
            MultiLine = true,
        })
        transfer:AddButton({
            Name = "Import",
            Callback = function()
                local ok, err = self:LoadJSON(jsonBox.Text)
                refresh()
                report("Import config", ok, err)
            end,
            Buttons = {
                {
                    Name = "Export",
                    Callback = function()
                        local ok, content = pcall(function() return self:SaveJSON() end)
                        if not ok then
                            report("Export config", false, content)
                            return
                        end
                        jsonBox.Text = content
                        local copied = type(setclipboard) == "function" and pcall(setclipboard, content)
                        notify({
                            Title = "Export config",
                            Content = copied and "JSON copied to clipboard and shown above."
                                or "JSON is ready in the Config JSON field.",
                        })
                    end,
                },
            },
        })
        return group
    end

    SaveManager.new = newManager
    return SaveManager
end

return newManager()
