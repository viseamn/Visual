local HttpService = game:GetService("HttpService")

local function newManager()
    local SaveManager = { Version = "1.0.3", Folder = "Viz", Ignore = {} }
    local window, context
    local controlRegistry, ThemeManager
    local lastWritten, autoSaveThread, loading = nil, nil, false
    local pendingAutoSave
    local function callback(self, name, ...)
        if type(self[name]) ~= "function" then return end
        local ok, err = pcall(self[name], ...)
        if not ok then warn(err) end
    end
    local function copy(value)
        if type(value) ~= "table" then return value end
        local result = {}
        for key, item in pairs(value) do result[key] = copy(item) end
        return result
    end
    local function bound()
        assert(context and context.IsAlive(), "SetLibrary must reference a live Viz window")
        return context
    end
    function SaveManager:SetLibrary(library)
        assert(type(library) == "table", "SetLibrary expects a Viz library or window")
        local target = library._Viz and library or library.Window
        assert(target and target._Viz and target._Viz.IsAlive(), "Create a live Viz window before SetLibrary")
        assert(not loading, "Cannot change library while loading")
        if context and context ~= target._Viz then
            self:SetAutoSave(false)
            self.ActiveConfig, lastWritten = nil, nil
        end
        window = target
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
        assert(not loading, "Cannot change folder while loading")
        local folder = name:gsub("\\", "/")
        if folder ~= self.Folder then
            self:SetAutoSave(false)
            self.Folder = folder
            self.ActiveConfig, lastWritten = nil, nil
            callback(self, "OnActiveConfigChanged", nil)
        end
        return self
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
            if not self.Ignore[id] then data.Controls[id] = { Type = entry.Kind, Value = copy(entry.Read()) } end
        end
        if not self.IgnoreTheme then data.Theme = context.ExportTheme() end
        return data
    end
    function SaveManager:SaveJSON() return HttpService:JSONEncode(snapshot(self)) end

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
    SaveManager.AutoSave = false
    SaveManager.AutoSaveInterval = 1
    local function markActive(self, name, savedData)
        self.ActiveConfig = name
        if savedData then
            lastWritten = savedData
        else
            local ok, data = pcall(snapshot, self)
            lastWritten = ok and data or nil
        end
        if self.AutoSave and name then
            pcall(writefile, self.Folder .. "/autosave-config.txt", name)
        end
        callback(self, "OnActiveConfigChanged", name)
    end
    function SaveManager:GetActiveConfig() return self.ActiveConfig end
    local function unchanged(self)
        if not lastWritten then return false end
        local count = 0
        for id, entry in pairs(controlRegistry) do
            if not self.Ignore[id] then
                count = count + 1
                local previous = lastWritten.Controls[id]
                if not previous or previous.Type ~= entry.Kind or not same(entry.Read(), previous.Value) then
                    return false
                end
            end
        end
        for _ in pairs(lastWritten.Controls) do count = count - 1 end
        if count ~= 0 then return false end
        if self.IgnoreTheme then return lastWritten.Theme == nil end
        return same(context.ExportTheme(), lastWritten.Theme)
    end
    local function autoSaveStep(self)
        if loading or (context.IsLoading and context.IsLoading()) then return end
        if unchanged(self) then return end
        local ok, data = pcall(snapshot, self)
        if not ok then error(data) end
        if same(data, lastWritten) then return end
        local name = self.ActiveConfig or "autosave"
        local written, err = writeJSON(self, "configs", name, HttpService:JSONEncode(data))
        if not written then
            self:SetAutoSave(false)
            report("Auto save", false, err)
            return
        end
        lastWritten = data
        if not self.ActiveConfig then markActive(self, name, data) end
        callback(self, "OnAutoSaved", name)
    end
    function SaveManager:SetAutoSave(enabled)
        enabled = enabled == true
        if enabled then
            bound()
            if not hasFiles() then return false, "File storage unavailable" end
            local interval = self.AutoSaveInterval
            if type(interval) ~= "number" or interval ~= interval or interval < 0.1 or interval == math.huge then
                return false, "AutoSaveInterval must be a finite number of at least 0.1 seconds"
            end
        end
        pendingAutoSave = nil
        self.AutoSave = enabled
        if context and context.IsAlive() and hasFiles() then pcall(function()
            folderPath(self, "configs")
            writefile(self.Folder .. "/autosave.txt", enabled and "1" or "0")
            if enabled and self.ActiveConfig then
                writefile(self.Folder .. "/autosave-config.txt", self.ActiveConfig)
            end
        end) end
        if not enabled and autoSaveThread then
            local thread = autoSaveThread
            autoSaveThread = nil
            if thread ~= coroutine.running() then task.cancel(thread) end
        end
        if enabled and not autoSaveThread then
            autoSaveThread = coroutine.create(function()
                while self.AutoSave do
                    local interval = tonumber(self.AutoSaveInterval) or 1
                    if interval ~= interval or interval == math.huge then interval = 1 end
                    task.wait(math.max(0.1, interval))
                    if not (self.AutoSave and context and context.IsAlive()) then break end
                    local ok, err = pcall(autoSaveStep, self)
                    if not ok then
                        self:SetAutoSave(false)
                        pcall(report, "Auto save", false, err)
                        break
                    end
                end
                if autoSaveThread == coroutine.running() then
                    autoSaveThread = nil
                    if self.AutoSave then
                        self.AutoSave = false
                        callback(self, "OnAutoSaveChanged", false)
                    end
                end
            end)
            task.spawn(autoSaveThread)
        end
        callback(self, "OnAutoSaveChanged", enabled)
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
        if not ok or type(data) ~= "table" or (data.Format ~= nil and data.Format ~= "Viz")
            or data.Version ~= 1 or type(data.Controls) ~= "table" then
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
                item.Previous = copy(item.Entry.Read())
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
        if loading or (context and context.IsLoading and context.IsLoading()) then
            return false, "A config is already loading"
        end
        loading = true
        local ok, result, err = pcall(loadJSON, self, content)
        if context then context.SetLoading(false) end
        loading = false
        if not ok then return false, tostring(result) end
        return result, err
    end
    function SaveManager:Save(name)
        local savedData
        local ok, content = pcall(function()
            savedData = snapshot(self)
            return HttpService:JSONEncode(savedData)
        end)
        if not ok then return false, content end
        local written, err = writeJSON(self, "configs", name, content)
        if written then markActive(self, name, savedData) end
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
        if loaded or (err and err:find("^Values loaded")) then markActive(self, name) end
        return loaded, err
    end
    function SaveManager:RefreshConfigList() return listJSON(self, "configs") end
    function SaveManager:Delete(name)
        local ok, err = deleteJSON(self, "configs", name)
        if ok and self.ActiveConfig == name then
            self.ActiveConfig, lastWritten = nil, nil
            callback(self, "OnActiveConfigChanged", nil)
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
        local resume = pendingAutoSave
        if resume == nil then resume = not self.AutoSave and savedAutoSave(self) end
        pendingAutoSave = nil
        local name = self:GetAutoloadConfig()
        if not name and resume then
            local ok, target = pcall(function()
                local path = self.Folder .. "/autosave-config.txt"
                local hasTarget = isfile(path)
                local saved = hasTarget and readfile(path) or "autosave"
                assert(safeName(saved), "Invalid autosave config name")
                local exists = isfile(folderPath(self, "configs") .. "/" .. saved .. ".json")
                assert(not hasTarget or exists, "Autosave config not found: " .. saved)
                return exists and saved or nil
            end)
            if not ok then
                callback(self, "OnAutoSaveChanged", false)
                return false, tostring(target)
            end
            name = target
        end
        if name then
            local ok, err = self:Load(name)
            if not ok then
                if resume then callback(self, "OnAutoSaveChanged", false) end
                return false, err
            end
        end
        if resume then return self:SetAutoSave(true) end
        return true
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
            files:AddLabel("File storage is unavailable here. Use the JSON tab.")
        end
        local function configNames()
            if not hasFiles() then return {} end
            local names, err = self:RefreshConfigList()
            if err then report("Configs", false, err) end
            return names, err
        end
        local selector = files:AddDropdown({ Name = "Config", Options = configNames(), NoSave = true })
        local autoloadToggle
        local refreshing = false
        local function refresh(select)
            if refreshing then return end
            refreshing = true
            local names, err = configNames()
            if not err then pcall(selector.SetValues, selector, names) end
            if select and table.find(names, select) then pcall(selector.Set, selector, select, true) end
            refreshing = false
            if autoloadToggle then
                local autoload = self:GetAutoloadConfig()
                autoloadToggle:Set(autoload ~= nil and autoload == selector.Value, true)
            end
        end
        local function selected(title)
            if selector.Value then return selector.Value end
            report(title, false, "Select a config first")
        end
        local loadButton = files:AddButton({
            Name = "Load",
            Callback = function()
                local name = selected("Load config")
                if not name then return end
                local ok, err = self:Load(name)
                refresh(name)
                report("Load config", ok, err)
            end,
            Buttons = {
                {
                    Name = "Save",
                    Callback = function()
                        local name = selected("Save config")
                        if not name then return end
                        showDialog({
                            Title = "Save config",
                            Content = 'Replace "' .. name .. '" with the current settings?',
                            ConfirmText = "Save",
                            OnConfirm = function()
                                local ok, err = self:Overwrite(name)
                                refresh(name)
                                report("Save config", ok, err)
                            end,
                        })
                    end,
                },
                {
                    Name = "Delete",
                    Callback = function()
                        local name = selected("Delete config")
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
                },
            },
        })
        local nameBox = files:AddTextbox({ Name = "New config", Placeholder = "Name, then Enter", NoSave = true })
        nameBox.FocusLost:Connect(function(enterPressed)
            local name = nameBox.Text:match("^%s*(.-)%s*$")
            if not enterPressed or name == "" then return end
            local ok, err = self:Create(name)
            if ok then
                nameBox.Text = ""
                refresh(name)
            end
            report("Create config", ok, err)
        end)
        local autoSaveToggle = files:AddToggle({
            Name = "Auto save",
            Default = self.AutoSave,
            NoSave = true,
            Callback = function(value)
                local ok, err = self:SetAutoSave(value)
                if not ok then report("Auto save", ok, err) end
            end,
        })
        autoloadToggle = files:AddToggle({
            Name = "Load on startup",
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
                if not ok then report("Load on startup", false, err) end
            end,
        })
        selector:OnChanged(function() refresh() end)

        local row = loadButton.Parent
        local function arrange(buttons)
            local count = #buttons
            for index, button in ipairs(buttons) do
                button.Size = UDim2.new(1 / count, -6 * (count - 1) / count, 0, 28)
                button.Position = UDim2.new((index - 1) / count, (index - 1) * 6 / count, 0, 0)
            end
        end
        local saveButton, deleteButton
        for _, child in ipairs(row:GetChildren()) do
            if child:IsA("TextButton") and child.Text == "Save" then saveButton = child end
            if child:IsA("TextButton") and child.Text == "Delete" then deleteButton = child end
        end
        local function applyAutoSaveState(enabled)
            autoSaveToggle:Set(enabled, true)
            saveButton.Visible = not enabled
            arrange(enabled and { loadButton, deleteButton } or { loadButton, saveButton, deleteButton })
            group:SetControlVisible(nameBox, not enabled)
            refresh(self.ActiveConfig)
        end
        self.OnAutoSaveChanged = applyAutoSaveState
        self.OnActiveConfigChanged = function(name) refresh(name) end
        self.OnAutoSaved = function(name)
            if selector.Value ~= name then refresh(name) end
        end
        if not hasFiles() then
            group:SetControlDisabled(autoSaveToggle, true)
            group:SetControlDisabled(autoloadToggle, true)
        end
        pendingAutoSave = not self.AutoSave and savedAutoSave(self) or nil
        applyAutoSaveState(self.AutoSave or pendingAutoSave == true)

        local jsonBox = transfer:AddTextbox({
            Name = "Config JSON",
            Placeholder = "Paste a config here",
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
                        notify({ Title = "Export config", Content = copied and "Copied to clipboard" or "Ready above" })
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
