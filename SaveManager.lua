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
    function SaveManager:SaveJSON()
        bound()
        local data = { Format = "Viz", Version = 1, Controls = {} }
        for id, entry in pairs(controlRegistry) do
            if not self.Ignore[id] then data.Controls[id] = { Type = entry.Kind, Value = entry.Read() } end
        end
        if not self.IgnoreTheme then data.Theme = context.ExportTheme() end
        return HttpService:JSONEncode(data)
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
        return writeJSON(self, "configs", name, content)
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
        return self:LoadJSON(content)
    end
    function SaveManager:RefreshConfigList() return listJSON(self, "configs") end
    function SaveManager:Delete(name) return deleteJSON(self, "configs", name) end
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
        local files = group:AddTab("Files")
        local create = group:AddTab("New")
        local startup = group:AddTab("Startup")
        local transfer = group:AddTab("JSON")
        if not hasFiles() then
            files:AddLabel("File storage unavailable. JSON import/export is available through the API.")
        end
        local nameBox = create:AddTextbox({ Name = "Config name", Default = "default", NoSave = true })
        local function configNames()
            if not hasFiles() then return {} end
            local names, err = self:RefreshConfigList()
            if err then report("Refresh configs", false, err) end
            return names, err
        end
        local initialNames = configNames()
        local selector = files:AddDropdown({ Name = "Saved configs", Options = initialNames, NoSave = true })
        local autoLabel = startup:AddLabel("Autoload: " .. (self:GetAutoloadConfig() or "None"))
        local function refresh()
            local names, err = configNames()
            if not err then selector:SetValues(names) end
            autoLabel.Text = "Autoload: " .. (self:GetAutoloadConfig() or "None")
        end
        create:AddButton({
            Name = "Create config",
            Callback = function()
                local ok, err = self:Create(nameBox.Text)
                if ok then
                    refresh()
                    selector:Set(nameBox.Text, true)
                    files:Activate()
                end
                report("Create config", ok, err)
            end,
        })
        files:AddButton({
            Name = "Load config",
            Callback = function() report("Load config", self:Load(selector.Value)) end,
        })
        files:AddButton({
            Name = "Overwrite config",
            Callback = function()
                local name = selector.Value
                if not name then
                    report("Overwrite config", false, "Select a saved config first")
                    return
                end
                showDialog({
                    Title = "Overwrite config",
                    Content = 'Replace "' .. name .. '" with the current settings?',
                    ConfirmText = "Overwrite",
                    OnConfirm = function() report("Overwrite config", self:Overwrite(name)) end,
                })
            end,
        })
        files:AddButton({ Name = "Refresh configs", Callback = refresh })
        startup:AddButton({
            Name = "Set autoload",
            Callback = function()
                local ok, err = self:SaveAutoloadConfig(selector.Value)
                refresh()
                report("Autoload", ok, err)
            end,
        })
        startup:AddButton({
            Name = "Clear autoload",
            Callback = function()
                local ok, err = self:DeleteAutoLoadConfig()
                refresh()
                report("Autoload", ok, err)
            end,
        })
        files:AddButton({
            Name = "Delete selected config",
            Callback = function()
                local name = selector.Value
                if not name then return end
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
        })
        local jsonBox = transfer:AddTextbox({
            Name = "Config JSON",
            Placeholder = "Paste Viz config JSON",
            NoSave = true,
            MultiLine = true,
        })
        transfer:AddButton({
            Name = "Import config",
            Callback = function()
                local ok, err = self:LoadJSON(jsonBox.Text)
                refresh()
                report("Import config", ok, err)
            end,
        })
        transfer:AddButton({
            Name = "Export current config",
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
                    Content = copied and "JSON copied to clipboard and shown below."
                        or "JSON is ready in the Config JSON field.",
                })
            end,
        })
        return group
    end

    SaveManager.new = newManager
    return SaveManager
end

return newManager()
