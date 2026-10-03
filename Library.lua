-- Viz 1.0.3
local Library = { Version = "1.0.3" }
local function safeName(name)
    return type(name) == "string" and #name > 0 and #name <= 64 and name:match("^[%w _%-]+$") and name:match("%S")
end
local function hasFiles()
    return type(isfolder) == "function"
        and type(makefolder) == "function"
        and type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"
end
local function safeFolder(name)
    if type(name) ~= "string" or #name == 0 or #name > 160 then return false end
    name = name:gsub("\\", "/")
    if name:match("^/") or name:match("/$") or name:find("//", 1, true) then return false end
    for segment in name:gmatch("[^/]+") do
        if not safeName(segment) then return false end
    end
    return true
end
local function folderPath(manager, category)
    assert(hasFiles(), "File storage is unavailable. Use JSON import/export instead.")
    assert(safeFolder(manager.Folder), "Invalid folder name")
    local current = ""
    for segment in manager.Folder:gmatch("[^/]+") do
        current = current == "" and segment or current .. "/" .. segment
        if not isfolder(current) then makefolder(current) end
    end
    local folder = manager.Folder .. "/" .. category
    if not isfolder(folder) then makefolder(folder) end
    return folder
end
local function writeJSON(manager, category, name, content)
    if not safeName(name) then return false, "Use letters, numbers, spaces, - or _ for the name." end
    return pcall(function() writefile(folderPath(manager, category) .. "/" .. name .. ".json", content) end)
end
local function readJSON(manager, category, name)
    if not safeName(name) then return false, "Invalid name" end
    return pcall(function() return readfile(folderPath(manager, category) .. "/" .. name .. ".json") end)
end
local function listJSON(manager, category)
    local ok, result = pcall(function()
        assert(type(listfiles) == "function", "Listing files is unavailable")
        local names = {}
        for _, path in ipairs(listfiles(folderPath(manager, category))) do
            local name = path:gsub("\\", "/"):match("([^/]+)%.json$")
            if name and safeName(name) then table.insert(names, name) end
        end
        table.sort(names)
        return names
    end)
    if ok then return result end
    return {}, tostring(result)
end
local function deleteJSON(manager, category, name)
    if not safeName(name) then return false, "Invalid name" end
    return pcall(function()
        assert(type(delfile) == "function", "Deleting files is unavailable")
        local path = folderPath(manager, category) .. "/" .. name .. ".json"
        assert(isfile(path), "File not found")
        delfile(path)
    end)
end

Library._Storage = {
    SafeName = safeName,
    SafeFolder = safeFolder,
    Available = hasFiles,
    Folder = folderPath,
    Write = writeJSON,
    Read = readJSON,
    List = listJSON,
    Delete = deleteJSON,
}

function Library:CreateWindow(config)
    config = config or {}
    assert(type(config) == "table", "CreateWindow expects an options table")
    assert(config.Title == nil or type(config.Title) == "string", "Title expects a string")
    assert(config.Layout == nil or config.Layout == "Bottom bar", "Unknown layout")
    if config.Size then
        assert(
            typeof(config.Size) == "Vector2"
                and config.Size.X == config.Size.X
                and config.Size.Y == config.Size.Y
                and math.abs(config.Size.X) < math.huge
                and math.abs(config.Size.Y) < math.huge,
            "Size expects a finite Vector2"
        )
    end
    if config.MenuKey then
        local key = type(config.MenuKey) == "string" and Enum.KeyCode[config.MenuKey] or config.MenuKey
        assert(typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode, "Invalid menu key")
    end
    if self.Window then self.Window:Destroy() end
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")
    local player = Players.LocalPlayer
    assert(player, "Viz must run on the client")

    local playerGui = player:WaitForChild("PlayerGui")

    local Theme = {
        Background = Color3.fromRGB(12, 13, 16),
        Header = Color3.fromRGB(12, 13, 16),
        Search = Color3.fromRGB(22, 23, 28),
        Accent = Color3.fromRGB(199, 83, 224),
        Muted = Color3.fromRGB(105, 107, 119),
        Icon = Color3.fromRGB(199, 83, 224),
        Navigation = Color3.fromRGB(35, 36, 43),
        Card = Color3.fromRGB(17, 18, 22),
        Border = Color3.fromRGB(33, 34, 41),
        Text = Color3.fromRGB(218, 219, 229),
        Selected = Color3.fromRGB(49, 31, 57),
        Hover = Color3.fromRGB(57, 47, 65),
        Pressed = Color3.fromRGB(82, 48, 94),
    }
    local function luminance(color)
        local function linear(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
        return 0.2126 * linear(color.R) + 0.7152 * linear(color.G) + 0.0722 * linear(color.B)
    end
    local function contrast(a, b)
        local x, y = luminance(a), luminance(b)
        return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05)
    end
    local function contrastingText(background)
        local light, dark = Color3.fromRGB(245, 246, 250), Color3.fromRGB(15, 16, 20)
        return contrast(light, background) >= contrast(dark, background) and light or dark
    end
    local function refreshContrastColors()
        Theme.OnAccent = contrastingText(Theme.Accent)
        Theme.SelectedText = contrast(Theme.Accent, Theme.Selected) >= 4.5 and Theme.Accent
            or contrastingText(Theme.Selected)
    end
    refreshContrastColors()
    local themeBindings = {}
    local function rememberTheme(object, property, role)
        if not themeBindings[object] then
            themeBindings[object] = {}
            object.Destroying:Connect(function() themeBindings[object] = nil end)
        end
        themeBindings[object][property] = role
    end
    local function bindTheme(object, property, role)
        rememberTheme(object, property, role)
        object[property] = Theme[role]
    end
    local function unbindTheme(object, property)
        if themeBindings[object] then themeBindings[object][property] = nil end
    end
    local fontBindings = {}
    local fontName = "BuilderSans"
    local fontChoices = {
        BuilderSans = Enum.Font.BuilderSans,
        Code = Enum.Font.Code,
        Gotham = Enum.Font.Gotham,
        SourceSans = Enum.Font.SourceSans,
    }
    local function setUIFont(object, medium)
        if fontBindings[object] == nil then object.Destroying:Connect(function() fontBindings[object] = nil end) end
        fontBindings[object] = medium == true
        local font = fontName == "BuilderSans" and (medium and Enum.Font.BuilderSansMedium or Enum.Font.BuilderSans)
            or fontChoices[fontName]
        object.FontFace = Font.fromEnum(font)
    end
    local controlRegistry = {}
    local Options, Toggles = {}, {}
    local loadingConfig = false
    local function registerControl(id, kind, owner, read, write, validate, changed)
        assert(not controlRegistry[id], "Duplicate SaveId: " .. id)
        controlRegistry[id] = { Kind = kind, Read = read, Write = write, Validate = validate, Changed = changed }
        owner.Destroying:Connect(function() controlRegistry[id] = nil end)
    end

    local screen = Instance.new("ScreenGui")
    screen.Name = "Viz"
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Parent = playerGui

    local function animationDuration(seconds) return seconds end
    local function rounded(className, name, parent, x, y, width, height, color, radius)
        local object = Instance.new(className)
        object.Name = name
        object.Position = UDim2.fromOffset(x, y)
        object.Size = UDim2.fromOffset(width, height)
        local role = type(color) == "string" and color or nil
        object.BackgroundColor3 = role and Theme[role] or color
        if role then bindTheme(object, "BackgroundColor3", role) end
        object.BorderSizePixel = 0
        if object:IsA("TextButton") then
            object.Text = ""
            object.AutoButtonColor = false
        end

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = object
        object.Parent = parent
        return object
    end

    -- Glass is tuned per theme brightness: on light themes a lavender multiply and a see-through
    -- background read as a dirty purple-grey wash, so the sheen goes neutral and the surface goes near-opaque.
    local glassSurfaces = setmetatable({}, { __mode = "k" })
    local glassOpacityFactor = 1
    local darkSheen = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 213, 239))
    local lightSheen = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(244, 243, 248))
    local function refreshGlass()
        local light = luminance(Theme.Background) > 0.5
        glassOpacityFactor = light and 0.25 or 1
        for object, info in pairs(glassSurfaces) do
            if object.Parent then
                info.Sheen.Color = light and lightSheen or darkSheen
                if info.Transparency < 1 then
                    object.BackgroundTransparency = info.Transparency * glassOpacityFactor
                end
            end
        end
    end
    local function glassSurface(object, transparency, existingStroke)
        object.BackgroundTransparency = transparency * (transparency < 1 and glassOpacityFactor or 1)
        local sheen = Instance.new("UIGradient")
        sheen.Name = "GlassSheen"
        sheen.Rotation = 110
        sheen.Color = glassOpacityFactor < 1 and lightSheen or darkSheen
        sheen.Parent = object
        glassSurfaces[object] = { Transparency = transparency, Sheen = sheen }
        local rim = existingStroke or Instance.new("UIStroke")
        rim.Name = "GlassRim"
        rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        rim.Thickness = 1
        if not existingStroke then
            rim.Color = Color3.fromRGB(232, 225, 255)
            rim.Transparency = 0.78
        end
        local reflection = Instance.new("UIGradient")
        reflection.Rotation = 65
        reflection.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05),
            NumberSequenceKeypoint.new(0.3, 0.65),
            NumberSequenceKeypoint.new(0.65, 0.9),
            NumberSequenceKeypoint.new(1, 0.3),
        })
        reflection.Parent = rim
        rim.Parent = object
        return rim
    end

    local viewport = Instance.new("Frame")
    viewport.Name = "Viewport"
    viewport.Size = UDim2.fromScale(1, 1)
    viewport.BackgroundTransparency = 1
    viewport.BorderSizePixel = 0
    viewport.Parent = screen

    local root = Instance.new("Frame")
    root.Name = "Window"
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Size = UDim2.fromOffset(651, 447)
    root.BackgroundTransparency = 0
    bindTheme(root, "BackgroundColor3", "Background")
    local rootCorner = Instance.new("UICorner")
    rootCorner.CornerRadius = UDim.new(0, 22)
    rootCorner.Parent = root
    root.BorderSizePixel = 0
    root.Parent = viewport
    glassSurface(root, 0.12)

    local layoutStyle = "Bottom bar"
    local uiShown = true
    local windowTransitioning = false
    local windowMotionHost = Instance.new("CanvasGroup")
    windowMotionHost.Name = "WindowMotion"
    windowMotionHost.AnchorPoint = Vector2.new(0.5, 0.5)
    windowMotionHost.Size = UDim2.fromOffset(0, 0)
    windowMotionHost.BackgroundTransparency = 1
    windowMotionHost.BorderSizePixel = 0
    windowMotionHost.ZIndex = 15
    windowMotionHost.Visible = false
    windowMotionHost.Parent = viewport
    local windowMotionScale = Instance.new("UIScale")
    windowMotionScale.Scale = 1
    windowMotionScale.Parent = windowMotionHost
    local animateUIVisibility = function(visible) root.Visible = visible end
    local finishUIVisibility = function() end
    local windowContentSize = Vector2.new(584, 447)
    local refreshDockLayout = function() end
    local scale = Instance.new("UIScale")
    scale.Parent = root
    local function resize()
        local size = viewport.AbsoluteSize
        scale.Scale =
            math.max(0.01, math.min(1, (size.X - 32) / root.Size.X.Offset, (size.Y - 32) / root.Size.Y.Offset))
        if windowTransitioning then return end
        local position = root.Position
        local halfWidth, halfHeight = root.Size.X.Offset * scale.Scale / 2, root.Size.Y.Offset * scale.Scale / 2
        local x = math.clamp(
            size.X * position.X.Scale + position.X.Offset,
            halfWidth,
            math.max(halfWidth, size.X - halfWidth)
        )
        local y = math.clamp(
            size.Y * position.Y.Scale + position.Y.Offset,
            halfHeight,
            math.max(halfHeight, size.Y - halfHeight)
        )
        root.Position =
            UDim2.new(position.X.Scale, x - size.X * position.X.Scale, position.Y.Scale, y - size.Y * position.Y.Scale)
    end
    local resizeConnection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    screen.Destroying:Connect(function() resizeConnection:Disconnect() end)
    resize()

    local sidebar = rounded("Frame", "Sidebar", root, 0, 0, 0, 447, "Background", 17)
    sidebar.BackgroundTransparency = 1
    local body = rounded("Frame", "Body", root, 0, 0, 584, 447, "Background", 17)
    body.BackgroundTransparency = 1
    local backgroundImage = Instance.new("ImageLabel")
    backgroundImage.Name = "BackgroundImage"
    backgroundImage.Size = UDim2.fromScale(1, 1)
    backgroundImage.BackgroundTransparency = 1
    backgroundImage.ImageTransparency = 0.82
    backgroundImage.ScaleType = Enum.ScaleType.Crop
    backgroundImage.Visible = false
    backgroundImage.Parent = body
    local backgroundCorner = Instance.new("UICorner")
    backgroundCorner.CornerRadius = UDim.new(0, 17)
    backgroundCorner.Parent = backgroundImage
    local header = rounded("Frame", "Header", root, 0, 0, 584, 54, "Background", 17)
    header.BackgroundTransparency = 1

    local iconAtlas = {
        ["house"] = { 325, 675 },
        ["binoculars"] = { 400, 50 },
        ["globe"] = { 50, 900 },
        ["settings"] = { 525, 900 },
        ["cpu"] = { 500, 275 },
        ["shopping-bag"] = { 925, 550 },
        ["search"] = { 850, 575 },
        ["sliders-horizontal"] = { 800, 700 },
        ["layout-grid"] = { 825, 225 },
        ["info"] = { 850, 175 },
        ["palette"] = { 825, 400 },
        ["check"] = { 400, 225 },
        ["chevron-down"] = { 175, 450 },
        ["bell"] = { 125, 300 },
        ["bell-off"] = { 200, 225 },
        ["keyboard"] = { 500, 525 },
        ["copy"] = { 775, 0 },
        ["arrow-left-right"] = { 50, 225 },
    }
    local function icon(parent, name, x, y, size, color, role)
        local coords = iconAtlas[name] or iconAtlas["layout-grid"]
        local image = Instance.new("ImageLabel")
        image.Name = "Icon"
        image.BackgroundTransparency = 1
        image.Position = UDim2.fromOffset(x, y)
        image.Size = UDim2.fromOffset(size, size)
        image.Image = "rbxassetid://97854828246256"
        image.ImageRectSize = Vector2.new(24, 24)
        image.ImageRectOffset = Vector2.new(coords[1], coords[2])
        role = role or (type(color) == "string" and color or (color == nil and "Icon" or nil))
        image.ImageColor3 = role and Theme[role] or color
        if role then bindTheme(image, "ImageColor3", role) end
        image.Parent = parent
        return image
    end

    local logo = Instance.new("ImageLabel")
    logo.Name = "Logo"
    logo.BackgroundTransparency = 1
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.new(0, 30, 0.5, 0)
    logo.Size = UDim2.fromOffset(32, 32)
    logo.Image = "rbxassetid://95943456246483"
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Parent = header

    local navigationGroup = Instance.new("ScrollingFrame")
    navigationGroup.Name = "NavigationGroup"
    navigationGroup.Size = UDim2.fromScale(1, 1)
    navigationGroup.BackgroundTransparency = 1
    navigationGroup.BorderSizePixel = 0
    navigationGroup.CanvasSize = UDim2.fromOffset(0, 0)
    navigationGroup.AutomaticCanvasSize = Enum.AutomaticSize.Y
    navigationGroup.ScrollingDirection = Enum.ScrollingDirection.Y
    navigationGroup.ScrollBarThickness = 0
    navigationGroup.Active = true
    navigationGroup.Parent = sidebar

    local navigationLayout = Instance.new("UIListLayout")
    navigationLayout.FillDirection = Enum.FillDirection.Vertical
    navigationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    navigationLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    navigationLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navigationLayout.Padding = UDim.new(0, 6)
    navigationLayout.Parent = navigationGroup
    local navigationPadding = Instance.new("UIPadding")
    navigationPadding.Parent = navigationGroup
    local function centerNavigation() refreshDockLayout() end

    local navigation, tabs = {}, {}
    local activeTab
    local connections = {}
    local themeTweens = setmetatable({}, { __mode = "k" })
    local openDropdown
    local activeSlider
    local function finishSlider()
        local previous = activeSlider
        activeSlider = nil
        if previous and previous.Release then previous.Release() end
    end
    local activeColorDrag
    local function finishColorDrag()
        local previous = activeColorDrag
        activeColorDrag = nil
        if previous and previous.Release then previous.Release() end
    end
    local keybindControls = {}
    local shortKeyNames = {
        LeftControl = "Ctrl",
        RightControl = "Ctrl",
        LeftShift = "Shft",
        RightShift = "Shft",
        LeftAlt = "Alt",
        RightAlt = "Alt",
        CapsLock = "Caps",
        Return = "Ent",
        Backspace = "Bksp",
        Delete = "Del",
        Insert = "Ins",
        PageUp = "PgU",
        PageDown = "PgD",
        Space = "Spc",
    }
    local capturingKeybind
    local closeDropdown
    local menuKeybind
    local cancelWindowDrag = function() end
    local cancelWindowResize = function() end
    local uiAlive = true
    local dialogOpen = false
    local function track(connection)
        table.insert(connections, connection)
        return connection
    end
    local dragStarts = setmetatable({}, { __mode = "k" })
    local function passesInput(object)
        return (object:IsA("Frame") or object:IsA("ScrollingFrame"))
            and not object.Active
            and object.BackgroundTransparency >= 1
    end
    local function findDragStart(objects, boundary, bindings)
        for _, hit in ipairs(objects) do
            if not hit:IsDescendantOf(boundary) then return end
            local ancestor = hit
            while ancestor and ancestor ~= boundary do
                if bindings[ancestor] then return bindings[ancestor], hit end
                ancestor = ancestor.Parent
            end
            if not passesInput(hit) then return end
        end
    end
    local function windowDragAllowed(hit, window, touch)
        while hit and hit ~= window do
            if
                hit:IsA("GuiButton")
                or hit:IsA("TextBox")
                or hit:GetAttribute("BlocksWindowDrag")
                or (touch and hit:IsA("ScrollingFrame") and hit.ScrollingEnabled)
            then
                return false
            end
            hit = hit.Parent
        end
        return hit == window
    end
    local function dropInsideWindow(point, window)
        local origin, size = window.AbsolutePosition, window.AbsoluteSize
        return not windowTransitioning
            and window.Visible
            and point.X >= origin.X
            and point.X <= origin.X + size.X
            and point.Y >= origin.Y
            and point.Y <= origin.Y + size.Y
    end
    local function bindDragStart(surface, callback) dragStarts[surface] = callback end
    track(UserInputService.InputBegan:Connect(function(input)
        if not uiAlive or dialogOpen then return end
        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        local callback, hit =
            findDragStart(playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y), screen, dragStarts)
        if callback and not (windowTransitioning and (hit == root or hit:IsDescendantOf(root))) then
            callback(input, hit)
        end
    end))
    local function tween(object, properties, duration)
        local changesColor = false
        for property, value in pairs(properties) do
            if type(value) == "string" and Theme[value] then
                changesColor = true
                rememberTheme(object, property, value)
                properties[property] = Theme[value]
            elseif typeof(value) == "Color3" then
                unbindTheme(object, property)
            end
        end
        local animation = TweenService:Create(
            object,
            TweenInfo.new(animationDuration(duration or 0.2), Enum.EasingStyle.Quint),
            properties
        )
        if changesColor then themeTweens[animation] = true end
        animation:Play()
        return animation
    end
    local motions = {}
    local function motion(object, properties, duration, immediate)
        if not motions[object] then
            motions[object] = {}
            object.Destroying:Connect(function()
                for _, animation in pairs(motions[object] or {}) do
                    animation:Cancel()
                end
                motions[object] = nil
            end)
        end
        for property, value in pairs(properties) do
            local old = motions[object][property]
            if old then old:Cancel() end
            if immediate then
                motions[object][property] = nil
                if type(value) == "string" and Theme[value] then
                    bindTheme(object, property, value)
                else
                    object[property] = value
                    if typeof(value) == "Color3" then unbindTheme(object, property) end
                end
            else
                motions[object][property] = tween(object, { [property] = value }, duration)
            end
        end
    end
    local function tweenIcon(image, role, rotation)
        local properties = { ImageColor3 = role }
        if rotation then properties.Rotation = rotation end
        tween(image, properties, 0.16)
        rememberTheme(image, "ImageColor3", role)
    end
    local function animateButton(button, baseColor)
        local hovering = false
        local baseRole = type(baseColor) == "string" and baseColor or nil
        button.MouseEnter:Connect(function()
            hovering = true
            tween(button, { BackgroundColor3 = "Hover" }, 0.16)
        end)
        button.MouseLeave:Connect(function()
            hovering = false
            tween(button, { BackgroundColor3 = baseRole or baseColor }, 0.2)
        end)
        button.InputBegan:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                tween(button, { BackgroundColor3 = "Pressed" }, 0.08)
            end
        end)
        button.InputEnded:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                tween(button, { BackgroundColor3 = hovering and "Hover" or (baseRole or baseColor) }, 0.18)
            end
        end)
    end
    local function label(parent, text, size)
        local object = Instance.new("TextLabel")
        object.BackgroundTransparency = 1
        object.Text = text
        setUIFont(object)
        object.TextSize = size or 12
        bindTheme(object, "TextColor3", "Text")
        object.TextXAlignment = Enum.TextXAlignment.Left
        object.Parent = parent
        return object
    end
    local toastStack = Instance.new("Frame")
    toastStack.Name = "Notifications"
    toastStack.AnchorPoint = Vector2.new(1, 1)
    toastStack.Position = UDim2.new(1, -16, 1, -16)
    toastStack.Size = UDim2.new(1, -32, 1, -32)
    toastStack.BackgroundTransparency = 1
    toastStack.ZIndex = 200
    toastStack.Parent = viewport
    local toastLimit = Instance.new("UISizeConstraint")
    toastLimit.MaxSize = Vector2.new(420, 100000)
    toastLimit.Parent = toastStack
    local toastLayout = Instance.new("UIListLayout")
    toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
    toastLayout.Padding = UDim.new(0, 8)
    toastLayout.Parent = toastStack
    local toasts, toastOrder = {}, 0
    local function notify(config)
        if not uiAlive then return end
        if type(config) == "string" then config = { Title = config } end
        config = config or {}
        toastOrder = toastOrder + 1
        local duration = math.clamp(tonumber(config.Duration) or 3, 1, 30)
        local function escape(text)
            return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
        end
        local titleText = config.Title and escape(config.Title) or nil
        local contentText = config.Content or config.Description
        contentText = contentText and contentText ~= "" and escape(contentText) or nil
        local text = titleText and contentText
                and string.format('<b>%s</b>  <font transparency="0.35">%s</font>', titleText, contentText)
            or titleText
            or contentText
            or "Notification"

        local card = rounded("CanvasGroup", "Notification", toastStack, 0, 0, 0, 0, "Background", 12)
        card.AutomaticSize = Enum.AutomaticSize.XY
        card.BackgroundTransparency = 0.04
        card.LayoutOrder = toastOrder
        card.GroupTransparency = 1
        local stroke = Instance.new("UIStroke")
        bindTheme(stroke, "Color", "Text")
        stroke.Transparency = 0.9
        stroke.Parent = card
        local cardScale = Instance.new("UIScale")
        cardScale.Scale = 0.94
        cardScale.Parent = card

        local row = Instance.new("Frame")
        row.Name = "Row"
        row.AutomaticSize = Enum.AutomaticSize.XY
        row.BackgroundTransparency = 1
        row.Parent = card
        local rowPadding = Instance.new("UIPadding")
        rowPadding.PaddingTop = UDim.new(0, 12)
        rowPadding.PaddingBottom = UDim.new(0, 12)
        rowPadding.PaddingLeft = UDim.new(0, 14)
        rowPadding.PaddingRight = UDim.new(0, 18)
        rowPadding.Parent = row
        local rowLayout = Instance.new("UIListLayout")
        rowLayout.FillDirection = Enum.FillDirection.Horizontal
        rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rowLayout.Padding = UDim.new(0, 12)
        rowLayout.Parent = row
        local toastIcon = icon(row, config.Icon or "info", 0, 0, 18, "Text", "Text")
        toastIcon.LayoutOrder = 1
        local message = label(row, text, 14)
        message.Name = "Message"
        message.LayoutOrder = 2
        message.RichText = true
        message.TextWrapped = true
        message.AutomaticSize = Enum.AutomaticSize.XY
        message.Size = UDim2.fromOffset(0, 18)
        local messageLimit = Instance.new("UISizeConstraint")
        messageLimit.MaxSize = Vector2.new(420 - 14 - 18 - 18 - 12, 100000)
        messageLimit.Parent = message

        local close = Instance.new("TextButton")
        close.Name = "Dismiss"
        close.Text = ""
        close.AutoButtonColor = false
        close.BackgroundTransparency = 1
        close.Size = UDim2.fromScale(1, 1)
        close.ZIndex = 2
        close.Parent = card
        local progress = rounded("Frame", "Lifetime", card, 0, 0, 0, 2, "Text", 1)
        progress.AnchorPoint = Vector2.new(0, 1)
        progress.Position = UDim2.fromScale(0, 1)
        progress.Size = UDim2.new(1, 0, 0, 2)
        progress.BackgroundTransparency = 0.8
        local timer = TweenService:Create(
            progress,
            TweenInfo.new(duration, Enum.EasingStyle.Linear),
            { Size = UDim2.new(0, 0, 0, 2) }
        )
        timer:Play()
        local entrance = tween(card, { GroupTransparency = 0 }, 0.2)
        motion(cardScale, { Scale = 1 }, 0.2)
        local toast = { Closed = false }
        function toast:Dismiss(immediate)
            if self.Closed then return end
            self.Closed = true
            timer:Cancel()
            entrance:Cancel()
            for index, item in ipairs(toasts) do
                if item == self then
                    table.remove(toasts, index)
                    break
                end
            end
            if immediate then
                card:Destroy()
                return
            end
            tween(card, { GroupTransparency = 1 }, 0.18)
            motion(cardScale, { Scale = 0.94 }, 0.18)
            task.delay(animationDuration(0.18), function()
                if uiAlive and card.Parent then card:Destroy() end
            end)
        end
        table.insert(toasts, toast)
        if #toasts > 4 then toasts[1]:Dismiss(true) end
        close.Activated:Connect(function() toast:Dismiss() end)
        task.delay(duration, function()
            if uiAlive then toast:Dismiss() end
        end)
        return toast
    end

    local refreshKeybindMenu = function() end
    local function canInteract(object)
        if dialogOpen then return false end
        if windowTransitioning and object and (object == root or object:IsDescendantOf(root)) then return false end
        while object and object ~= screen do
            if object:IsA("GuiObject") and (not object.Visible or object:GetAttribute("Disabled")) then return false end
            object = object.Parent
        end
        return true
    end
    local modifierKeys = {
        Ctrl = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl },
        Shift = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
        Alt = { Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt },
    }
    local function heldModifiers()
        local result = {}
        for name, keys in pairs(modifierKeys) do
            if UserInputService:IsKeyDown(keys[1]) or UserInputService:IsKeyDown(keys[2]) then result[name] = true end
        end
        return result
    end
    local function releaseHolds()
        for control in pairs(keybindControls) do
            if control.Holding then
                control.Holding = false
                control:Set(false)
            end
        end
    end
    local function cancelKeyCapture()
        if capturingKeybind then
            local previousCapture = capturingKeybind
            capturingKeybind = nil
            previousCapture:RefreshKeybind()
        end
    end
    local function setUIVisible(visible)
        if dialogOpen then return end
        visible = visible == true
        if uiShown == visible then return end
        uiShown = visible
        cancelKeyCapture()
        closeDropdown(true)
        finishSlider()
        finishColorDrag()
        releaseHolds()
        cancelWindowDrag()
        cancelWindowResize()
        local focused = UserInputService:GetFocusedTextBox()
        if focused then focused:ReleaseFocus() end
        animateUIVisibility(visible)
    end
    local function handleKeyInput(input, processed)
        if UserInputService:GetFocusedTextBox() then return end
        if capturingKeybind then
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local control = capturingKeybind
            if input.KeyCode == Enum.KeyCode.Escape then
                cancelKeyCapture()
                return
            end
            if input.KeyCode == Enum.KeyCode.Unknown then return end
            local modifiers = heldModifiers()
            for name, keys in pairs(modifierKeys) do
                if table.find(keys, input.KeyCode) then
                    if not control.AllowModifierKey then return end
                    modifiers[name] = nil
                end
            end
            capturingKeybind = nil
            control:SetModifiers(input.KeyCode == Enum.KeyCode.Backspace and {} or modifiers)
            control:SetKeybind(input.KeyCode == Enum.KeyCode.Backspace and Enum.KeyCode.Unknown or input.KeyCode)
            return
        end
        if processed or dialogOpen or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if menuKeybind and menuKeybind.Keybind ~= Enum.KeyCode.Unknown and input.KeyCode == menuKeybind.Keybind then
            local held, matches = heldModifiers(), true
            for name, keys in pairs(modifierKeys) do
                if table.find(keys, input.KeyCode) then held[name] = nil end
                if (held[name] == true) ~= (menuKeybind.Modifiers[name] == true) then matches = false end
            end
            if matches then
                setUIVisible(not uiShown)
                return
            end
        end
        if openDropdown then return end
        for control in pairs(keybindControls) do
            if
                not control.Disabled
                and control.Keybind ~= Enum.KeyCode.Unknown
                and control.Keybind == input.KeyCode
            then
                local held, matches = heldModifiers(), true
                for name in pairs(modifierKeys) do
                    if (held[name] == true) ~= (control.Modifiers[name] == true) then matches = false end
                end
                if matches then
                    if control.KeybindMode == "Hold" then
                        control.Holding = true
                        control:Set(true)
                    elseif control.KeybindMode == "Toggle" then
                        control:Set(not control.Value)
                    end
                end
            end
        end
    end
    track(UserInputService.InputBegan:Connect(handleKeyInput))
    track(UserInputService.InputEnded:Connect(function(input)
        for control in pairs(keybindControls) do
            if control.Holding then
                local released = input.KeyCode == control.Keybind
                for name in pairs(control.Modifiers) do
                    if modifierKeys[name] and table.find(modifierKeys[name], input.KeyCode) then released = true end
                end
                if released then
                    control.Holding = false
                    control:Set(false)
                end
            end
        end
    end))
    track(UserInputService.WindowFocusReleased:Connect(function()
        cancelKeyCapture()
        releaseHolds()
    end))
    track(UserInputService.TextBoxFocused:Connect(function()
        cancelKeyCapture()
        releaseHolds()
    end))
    screen.Destroying:Connect(function()
        uiAlive = false
        capturingKeybind = nil
        keybindControls = {}
        while #toasts > 0 do
            toasts[1]:Dismiss(true)
        end
    end)
    local content = Instance.new("Frame")
    content.Name = "Pages"
    content.ZIndex = 2
    content.Position = UDim2.fromOffset(12, 54)
    content.Size = UDim2.new(1, -24, 1, -66)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.Parent = body

    local dropdownOverlay = Instance.new("Frame")
    dropdownOverlay.Name = "DropdownOverlay"
    dropdownOverlay.Size = UDim2.fromScale(1, 1)
    dropdownOverlay.BackgroundTransparency = 1
    dropdownOverlay.ZIndex = 180
    dropdownOverlay.Visible = false
    dropdownOverlay.Active = false
    dropdownOverlay.Parent = viewport

    closeDropdown = function(immediate)
        if openDropdown then
            local previous = openDropdown
            openDropdown = nil
            previous:Close(immediate)
        end
    end
    track(UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            closeDropdown()
            return
        end
        if not openDropdown then return end
        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        local popup, trigger = openDropdown.Options, openDropdown.Trigger
        for _, object in ipairs(playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)) do
            if
                object == popup
                or object:IsDescendantOf(popup)
                or (trigger and (object == trigger or object:IsDescendantOf(trigger)))
            then
                return
            end
        end
        closeDropdown(true)
    end))
    root:GetPropertyChangedSignal("Position"):Connect(function() closeDropdown(true) end)
    viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() closeDropdown(true) end)
    local searchField = rounded("Frame", "SearchField", header, 66, 13, 220, 28, "Search", 8)
    icon(searchField, "search", 10, 6, 16, "Muted")
    local globalSearch = rounded("TextBox", "GlobalSearch", searchField, 36, 0, 172, 28, "Search", 0)
    globalSearch.BackgroundTransparency = 1
    globalSearch.Text = ""
    globalSearch.PlaceholderText = "search"
    globalSearch.TextXAlignment = Enum.TextXAlignment.Left
    globalSearch.ClearTextOnFocus = false
    globalSearch.TextSize = 12
    setUIFont(globalSearch)
    bindTheme(globalSearch, "TextColor3", "Text")
    bindTheme(globalSearch, "PlaceholderColor3", "Muted")
    local function searchMatches(text, query)
        return query == "" or string.find(string.lower(tostring(text or "")), query, 1, true) ~= nil
    end
    local function filterCards()
        local query = string.lower(globalSearch.Text:match("^%s*(.-)%s*$"))
        for _, tab in ipairs(tabs) do
            local visibleGroups = 0
            for _, group in ipairs(tab.Groups) do
                local nameMatch = searchMatches(tab.Name, query) or searchMatches(group.Name, query)
                local matched, sections = false, {}
                for _, element in ipairs(group.Elements) do
                    local section = group.RowSections[element]
                    local match = nameMatch
                        or searchMatches(element.Name, query)
                        or searchMatches(element:GetAttribute("SearchText"), query)
                        or (section and searchMatches(section.Name, query))
                    element.Visible = element:GetAttribute("UserVisible") ~= false and match == true
                    if element.Visible then
                        matched = true
                        if section then sections[section] = true end
                    end
                end
                matched = matched or nameMatch
                group.Frame.Visible = matched
                if group.DetachedWindow then group.DetachedWindow.Visible = matched end
                if matched then visibleGroups = visibleGroups + 1 end
                if query ~= "" and matched then
                    if not group.SearchState then
                        group.SearchState = { Collapsed = group.Collapsed, Section = group.ActiveSection }
                    end
                    if group.Collapsed then group:SetCollapsed(false, true) end
                    if group.ActiveSection and not sections[group.ActiveSection] then
                        for _, section in ipairs(group.Sections) do
                            if sections[section] then
                                section:Activate()
                                break
                            end
                        end
                    end
                elseif query == "" and group.SearchState then
                    local previous = group.SearchState
                    group.SearchState = nil
                    group:SetCollapsed(previous.Collapsed, true)
                    if previous.Section then previous.Section:Activate() end
                end
            end
            tab.SearchMatches = visibleGroups
            tab.Empty.Visible = visibleGroups == 0
            tab.Empty.Text = query == "" and "No cards yet" or "No matching controls"
        end
    end
    globalSearch:GetPropertyChangedSignal("Text"):Connect(function()
        cancelKeyCapture()
        closeDropdown(true)
        finishSlider()
        finishColorDrag()
        filterCards()
        if globalSearch.Text ~= "" and activeTab and activeTab.SearchMatches == 0 then
            for _, tab in ipairs(tabs) do
                if tab.SearchMatches > 0 then
                    tab:Activate()
                    break
                end
            end
        end
    end)

    local addTooltip
    do
        local tooltip = rounded("CanvasGroup", "Tooltip", viewport, 0, 0, 248, 0, "Card", 9)
        tooltip.ZIndex = 300
        tooltip.AutomaticSize = Enum.AutomaticSize.Y
        tooltip.Visible = false
        tooltip.GroupTransparency = 1
        glassSurface(tooltip, 0.02)
        local padding = Instance.new("UIPadding")
        padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
        padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
        padding.Parent = tooltip
        local text = label(tooltip, "", 12)
        text.Size = UDim2.new(1, 0, 0, 0)
        text.AutomaticSize = Enum.AutomaticSize.Y
        text.TextWrapped = true
        local owner, normalText, disabledText, revision
        revision = 0
        local function dismiss()
            revision = revision + 1
            owner = nil
            tooltip.Visible = false
            motion(tooltip, { GroupTransparency = 1 }, 0, true)
        end
        local function description()
            local object, disabled = owner, false
            while object and object ~= screen do
                if object:IsA("GuiObject") and not object.Visible then return nil end
                if object:GetAttribute("Disabled") then disabled = true end
                object = object.Parent
            end
            if not object or dialogOpen then return nil end
            return disabled and (disabledText or normalText) or normalText
        end
        addTooltip = function(target, content, disabledContent)
            if not content and not disabledContent then return end
            local connections, destroyed = {}, false
            connections[1] = target.MouseEnter:Connect(function()
                dismiss()
                owner, normalText, disabledText = target, content, disabledContent
                local current = revision
                task.delay(0.35, function()
                    if not uiAlive or destroyed or revision ~= current then return end
                    local message = description()
                    if not message or message == "" then return end
                    text.Text = tostring(message)
                    tooltip.Visible = true
                    motion(tooltip, { GroupTransparency = 0 }, 0.14)
                end)
            end)
            connections[2] = target.MouseLeave:Connect(function()
                if owner == target then dismiss() end
            end)
            local binding = {}
            function binding:Destroy()
                if destroyed then return end
                destroyed = true
                if owner == target then dismiss() end
                for _, connection in ipairs(connections) do
                    connection:Disconnect()
                end
            end
            connections[3] = target.Destroying:Connect(function() binding:Destroy() end)
            return binding
        end
        track(UserInputService.InputBegan:Connect(dismiss))
        track(game:GetService("RunService").RenderStepped:Connect(function()
            if not owner or not tooltip.Visible then return end
            local message = description()
            if not message or message == "" then
                dismiss()
                return
            end
            text.Text = tostring(message)
            local available = viewport.AbsoluteSize
            tooltip.Size = UDim2.fromOffset(math.max(1, math.min(248, available.X - 16)), 0)
            local mouse = UserInputService:GetMouseLocation()
                - game:GetService("GuiService"):GetGuiInset()
                - viewport.AbsolutePosition
            local size = tooltip.AbsoluteSize
            tooltip.Position = UDim2.fromOffset(
                math.clamp(mouse.X + 14, 8, math.max(8, available.X - size.X - 8)),
                math.clamp(mouse.Y + 18, 8, math.max(8, available.Y - size.Y - 8))
            )
        end))
    end

    local function createColorPicker(owner, swatch, options)
        options = options or {}
        unbindTheme(swatch, "BackgroundColor3")
        local picker = { Revision = 0, Trigger = swatch }
        local hue, saturation, brightness, opacity = 0, 1, 1, 1
        local alphaEnabled = options.Alpha ~= false
        local padding, wheelSize = 12, 180
        local center = wheelSize / 2
        local hueRadius, hueThickness = 82, 9
        local squareSize = 96
        local pickerWidth = wheelSize + padding * 2
        local alphaY = padding + wheelSize + 10
        local hexY = alphaY + (alphaEnabled and 24 or 0)
        local fieldsY = hexY + 34
        local pickerHeight = fieldsY + 26 + padding
        -- Styled like the dropdown menu so the popup reads as part of the same UI.
        local panel =
            rounded("CanvasGroup", "ColorPicker", dropdownOverlay, 0, 0, pickerWidth, pickerHeight, "Card", 9)
        panel.ZIndex = 2
        panel.Visible = false
        picker.Options = panel
        local panelScale = Instance.new("UIScale")
        panelScale.Parent = panel
        local border = Instance.new("UIStroke")
        bindTheme(border, "Color", "Border")
        border.Transparency = 0.2
        border.Parent = panel

        local wheel = rounded("TextButton", "Wheel", panel, padding, padding, wheelSize, wheelSize, "Card", 0)
        wheel.BackgroundTransparency = 1
        local rings = Instance.new("Frame")
        rings.Name = "Ring"
        rings.Size = UDim2.fromScale(1, 1)
        rings.BackgroundTransparency = 1
        rings.Parent = wheel
        local function polar(angle, radius)
            local radians = math.rad(angle)
            return UDim2.fromOffset(center + radius * math.cos(radians), center - radius * math.sin(radians))
        end

        -- Saturation/brightness square inside the ring: always visible, even for near-black colours.
        local square = rounded("Frame", "SaturationValue", wheel, 0, 0, squareSize, squareSize, Color3.new(1, 1, 1), 6)
        square.AnchorPoint = Vector2.new(0.5, 0.5)
        square.Position = UDim2.fromOffset(center, center)
        local saturationGradient = Instance.new("UIGradient")
        saturationGradient.Parent = square
        local shade = rounded("Frame", "ValueShade", square, 0, 0, 0, 0, Color3.new(0, 0, 0), 6)
        shade.Size = UDim2.fromScale(1, 1)
        local shadeGradient = Instance.new("UIGradient")
        shadeGradient.Rotation = 90
        shadeGradient.Transparency = NumberSequence.new(1, 0)
        shadeGradient.Parent = shade

        local function makeThumb(parent, name, size)
            local knob = rounded("Frame", name, parent, 0, 0, size, size, Color3.new(1, 1, 1), size / 2)
            knob.AnchorPoint = Vector2.new(0.5, 0.5)
            knob.ZIndex = 4
            local outline = Instance.new("UIStroke")
            outline.Color = Color3.new(0, 0, 0)
            outline.Transparency = 0.55
            outline.Parent = knob
            local core = rounded("Frame", "Color", knob, 3, 3, size - 6, size - 6, Color3.new(1, 0, 0), (size - 6) / 2)
            core.ZIndex = 5
            local thumbScale = Instance.new("UIScale")
            thumbScale.Parent = knob
            return knob, core, thumbScale
        end
        local hueKnob, hueCore, hueScale = makeThumb(wheel, "HueKnob", 16)
        local marker, markerCore, markerScale = makeThumb(square, "Selection", 14)

        -- Opacity uses the same track/fill/knob language as the library's sliders.
        local alphaHit = rounded("TextButton", "Opacity", panel, padding, alphaY, wheelSize, 16, "Card", 0)
        alphaHit.BackgroundTransparency = 1
        alphaHit.Visible = alphaEnabled
        local alphaTrack = rounded("Frame", "Track", alphaHit, 0, 4, wheelSize, 8, "Navigation", 4)
        local alphaFill = rounded("Frame", "Fill", alphaTrack, 0, 0, 0, 0, Color3.new(1, 1, 1), 4)
        alphaFill.Size = UDim2.fromScale(1, 1)
        local alphaGradient = Instance.new("UIGradient")
        alphaGradient.Transparency = NumberSequence.new(1, 0)
        alphaGradient.Parent = alphaFill
        local alphaKnob = rounded("Frame", "Knob", alphaTrack, 0, 4, 16, 12, "Text", 6)
        alphaKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        alphaKnob.ZIndex = 2
        local alphaScale = Instance.new("UIScale")
        alphaScale.Parent = alphaKnob

        local preview = rounded("Frame", "Preview", panel, padding, hexY, 26, 26, Color3.new(1, 1, 1), 6)
        local previewStroke = Instance.new("UIStroke")
        bindTheme(previewStroke, "Color", "Border")
        previewStroke.Parent = preview
        local hexContainer = rounded("Frame", "Hex", panel, padding + 32, hexY, wheelSize - 32, 26, "Search", 6)
        local hexInput = Instance.new("TextBox")
        hexInput.Name = "HexInput"
        hexInput.BackgroundTransparency = 1
        hexInput.Position = UDim2.fromOffset(8, 0)
        hexInput.Size = UDim2.new(1, -36, 1, 0)
        setUIFont(hexInput)
        hexInput.TextSize = 12
        bindTheme(hexInput, "TextColor3", "Text")
        hexInput.TextXAlignment = Enum.TextXAlignment.Left
        hexInput.ClearTextOnFocus = false
        hexInput.Parent = hexContainer
        local copyButton = rounded("TextButton", "CopyHex", hexContainer, 0, 3, 22, 20, "Search", 4)
        copyButton.Position = UDim2.new(1, -25, 0, 3)
        local copyIcon = icon(copyButton, "copy", 4, 3, 14, "Muted")
        animateButton(copyButton, "Search")

        local fieldNames = alphaEnabled and { "R", "G", "B", "A" } or { "R", "G", "B" }
        local fields = {}
        local fieldGap = 6
        local fieldWidth = (wheelSize - fieldGap * (#fieldNames - 1)) / #fieldNames
        for index, name in ipairs(fieldNames) do
            local container =
                rounded("Frame", name, panel, padding + (index - 1) * (fieldWidth + fieldGap), fieldsY, fieldWidth, 26, "Search", 6)
            local caption = label(container, name, 11)
            bindTheme(caption, "TextColor3", "Muted")
            caption.Position = UDim2.fromOffset(7, 0)
            caption.Size = UDim2.new(0, 10, 1, 0)
            local box = Instance.new("TextBox")
            box.Name = "Value"
            box.BackgroundTransparency = 1
            box.Position = UDim2.fromOffset(16, 0)
            box.Size = UDim2.new(1, -22, 1, 0)
            box.ClearTextOnFocus = false
            setUIFont(box)
            box.TextSize = 12
            bindTheme(box, "TextColor3", "Text")
            box.TextXAlignment = Enum.TextXAlignment.Right
            box.Parent = container
            fields[name] = box
        end

        local thumbScales = { Hue = hueScale, Square = markerScale, Opacity = alphaScale }
        local hoverPart
        local feedbackAnimations = {}
        local function feedback()
            for name, item in pairs(thumbScales) do
                if feedbackAnimations[name] then feedbackAnimations[name]:Cancel() end
                local pressed = activeColorDrag and activeColorDrag.Picker == picker and activeColorDrag.Part == name
                feedbackAnimations[name] =
                    tween(item, { Scale = pressed and 1.2 or (hoverPart == name and 1.1 or 1) }, 0.12)
            end
        end
        local function wheelPoint(position)
            local factor = math.max(0.01, wheel.AbsoluteSize.X / wheelSize)
            local origin = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
            return (position.X - origin.X) / factor, (position.Y - origin.Y) / factor
        end
        local function partAt(position)
            local dx, dy = wheelPoint(position)
            local half = squareSize / 2 + 4
            if math.abs(dx) <= half and math.abs(dy) <= half then return "Square" end
            local radius = math.sqrt(dx * dx + dy * dy)
            if radius >= hueRadius - 16 and radius <= hueRadius + 14 then return "Hue" end
        end
        local function setHover(part)
            if part == hoverPart then return end
            hoverPart = part
            feedback()
        end
        local function mouseLocation()
            return UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
        end
        wheel.MouseMoved:Connect(function() setHover(partAt(mouseLocation())) end)
        wheel.MouseLeave:Connect(function() setHover(nil) end)
        alphaHit.MouseEnter:Connect(function() setHover("Opacity") end)
        alphaHit.MouseLeave:Connect(function() setHover(nil) end)

        -- Roblox has no conic gradient and rotated frames render without anti-aliasing, so the
        -- hue ring is a dense chain of overlapping round dots (anti-aliased corners, smooth edge).
        local built = false
        local function build()
            if built then return end
            built = true
            local count = math.ceil(2 * math.pi * hueRadius / 2)
            for index = 0, count - 1 do
                local t = index / count
                local dot = rounded("Frame", "Hue", rings, 0, 0, hueThickness, hueThickness, Color3.fromHSV(t, 1, 1), 0)
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.Position = polar(t * 360, hueRadius)
                dot:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
            end
        end

        local hexValue = ""
        local function refresh(fire)
            local color = Color3.fromHSV(hue, saturation, brightness)
            picker.Value = color
            picker.Transparency = 1 - opacity
            swatch.BackgroundColor3 = color
            swatch.BackgroundTransparency = 0
            local pure = Color3.fromHSV(hue, 1, 1)
            hueKnob.Position = polar(hue * 360, hueRadius)
            hueCore.BackgroundColor3 = pure
            saturationGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), pure)
            marker.Position = UDim2.fromScale(saturation, 1 - brightness)
            markerCore.BackgroundColor3 = color
            alphaFill.BackgroundColor3 = color
            alphaKnob.Position = UDim2.new(opacity, 0, 0, 4)
            preview.BackgroundColor3 = color
            preview.BackgroundTransparency = (1 - opacity) * 0.85
            local channels = {
                R = math.floor(color.R * 255 + 0.5),
                G = math.floor(color.G * 255 + 0.5),
                B = math.floor(color.B * 255 + 0.5),
            }
            hexValue = string.format("%02X%02X%02X", channels.R, channels.G, channels.B)
            if alphaEnabled and opacity < 1 then
                hexValue = hexValue .. string.format("%02X", math.floor(opacity * 255 + 0.5))
            end
            if not hexInput:IsFocused() then hexInput.Text = "#" .. hexValue end
            for name, box in pairs(fields) do
                if not box:IsFocused() then
                    box.Text = name == "A" and string.format("%d%%", math.floor(opacity * 100 + 0.5))
                        or tostring(channels[name])
                end
            end
            if fire and options.Callback then options.Callback(color, picker.Transparency) end
        end
        function picker:Set(color, transparency, silent)
            assert(typeof(color) == "Color3", "Color picker expects Color3")
            hue, saturation, brightness = color:ToHSV()
            if transparency ~= nil then opacity = 1 - math.clamp(transparency, 0, 1) end
            if not alphaEnabled then opacity = 1 end
            refresh(not silent)
        end
        local function beginPick(input, part, update)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                if not canInteract(owner) then return end
                finishColorDrag()
                activeColorDrag = { Input = input, Update = update, Picker = picker, Part = part, Release = feedback }
                feedback()
                update(input.Position)
            end
        end
        wheel.InputBegan:Connect(function(input)
            local part = partAt(input.Position)
            if not part then return end
            beginPick(input, part, function(position)
                local dx, dy = wheelPoint(position)
                if part == "Hue" then
                    hue = (math.deg(math.atan2(-dy, dx)) / 360) % 1
                else
                    saturation = math.clamp(dx / squareSize + 0.5, 0, 1)
                    brightness = 1 - math.clamp(dy / squareSize + 0.5, 0, 1)
                end
                refresh(true)
            end)
        end)
        alphaHit.InputBegan:Connect(function(input)
            beginPick(input, "Opacity", function(position)
                opacity = math.clamp(
                    (position.X - alphaTrack.AbsolutePosition.X) / math.max(1, alphaTrack.AbsoluteSize.X),
                    0,
                    1
                )
                refresh(true)
            end)
        end)
        hexInput.FocusLost:Connect(function()
            local hex = hexInput.Text:gsub("%s", ""):gsub("^#", "")
            if (#hex == 6 or #hex == 8) and hex:match("^[%x]+$") then
                local color = Color3.fromRGB(
                    tonumber(hex:sub(1, 2), 16),
                    tonumber(hex:sub(3, 4), 16),
                    tonumber(hex:sub(5, 6), 16)
                )
                picker:Set(color, #hex == 8 and (1 - tonumber(hex:sub(7, 8), 16) / 255) or picker.Transparency)
            end
            hexInput.Text = "#" .. hexValue
        end)
        for name, box in pairs(fields) do
            box.FocusLost:Connect(function()
                local number = tonumber((box.Text:gsub("[%s%%]", "")))
                if number then
                    if name == "A" then
                        picker:Set(picker.Value, 1 - math.clamp(number, 0, 100) / 100)
                    else
                        local channels = {
                            R = math.floor(picker.Value.R * 255 + 0.5),
                            G = math.floor(picker.Value.G * 255 + 0.5),
                            B = math.floor(picker.Value.B * 255 + 0.5),
                        }
                        channels[name] = math.clamp(math.floor(number + 0.5), 0, 255)
                        picker:Set(Color3.fromRGB(channels.R, channels.G, channels.B), picker.Transparency)
                    end
                end
                refresh(false)
            end)
        end
        copyButton.Activated:Connect(function()
            local copied = type(setclipboard) == "function" and pcall(setclipboard, hexValue)
            if copied then
                bindTheme(copyIcon, "ImageColor3", "Accent")
                task.delay(0.6, function()
                    if uiAlive and copyIcon.Parent then bindTheme(copyIcon, "ImageColor3", "Muted") end
                end)
            else
                hexInput:CaptureFocus()
                hexInput.CursorPosition = #hexInput.Text + 1
                hexInput.SelectionStart = 1
            end
        end)

        function picker:Close(immediate)
            self.Revision = self.Revision + 1
            local revision = self.Revision
            if activeColorDrag and activeColorDrag.Picker == self then finishColorDrag() end
            hoverPart = nil
            feedback()
            if self.Animation then self.Animation:Cancel() end
            local function finish()
                if self.Revision ~= revision then return end
                panel.Visible = false
                if not openDropdown then dropdownOverlay.Visible = false end
            end
            if immediate then
                finish()
            else
                self.Animation = tween(panel, { GroupTransparency = 1 }, 0.12)
                task.delay(animationDuration(0.12), finish)
            end
        end
        function picker:Open()
            if not canInteract(owner) then return end
            build()
            cancelKeyCapture()
            closeDropdown(true)
            self.Revision = self.Revision + 1
            if self.Animation then self.Animation:Cancel() end
            openDropdown = self
            local available = viewport.AbsoluteSize
            local uiScale = math.max(
                0.1,
                math.min(scale.Scale, (available.Y - 16) / pickerHeight, (available.X - 16) / pickerWidth)
            )
            panelScale.Scale = uiScale
            local origin = swatch.AbsolutePosition - viewport.AbsolutePosition
            local x = origin.X + swatch.AbsoluteSize.X - pickerWidth * uiScale
            local below = origin.Y + swatch.AbsoluteSize.Y + 6
            local y = below + pickerHeight * uiScale <= available.Y - 8 and below
                or origin.Y - pickerHeight * uiScale - 6
            x = math.clamp(x, 8, math.max(8, available.X - pickerWidth * uiScale - 8))
            y = math.clamp(y, 8, math.max(8, available.Y - pickerHeight * uiScale - 8))
            panel.Position = UDim2.fromOffset(x, y + 4)
            panel.GroupTransparency = 1
            panel.Visible = true
            dropdownOverlay.Visible = true
            self.Animation = tween(panel, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) }, 0.18)
        end
        swatch.Activated:Connect(function()
            if openDropdown == picker then
                closeDropdown()
            else
                picker:Open()
            end
        end)

        owner.Destroying:Connect(function()
            if openDropdown == picker then closeDropdown(true) end
            picker.Revision = picker.Revision + 1
            if picker.Animation then picker.Animation:Cancel() end
            for _, animation in pairs(feedbackAnimations) do
                animation:Cancel()
            end
            panel:Destroy()
        end)
        picker:Set(options.Default or Theme.Accent, options.Transparency or 0, true)
        return picker
    end
    track(UserInputService.InputChanged:Connect(function(input)
        if
            activeColorDrag
            and (
                input == activeColorDrag.Input
                or (
                    activeColorDrag.Input.UserInputType == Enum.UserInputType.MouseButton1
                    and input.UserInputType == Enum.UserInputType.MouseMovement
                )
            )
        then
            activeColorDrag.Update(input.Position)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if activeColorDrag and input == activeColorDrag.Input then finishColorDrag() end
    end))
    track(UserInputService.WindowFocusReleased:Connect(function() finishColorDrag() end))
    screen.Destroying:Connect(function() finishColorDrag() end)

    local dropdownData = {}
    function dropdownData.Normalize(source)
        assert(type(source) == "table", "Dropdown values must be a table")
        local array, count = true, #source
        for key in pairs(source) do
            if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
                array = false
                break
            end
        end
        local keys, labels = {}, {}
        if array then
            for _, value in ipairs(source) do
                assert(
                    type(value) == "string" or type(value) == "number",
                    "Dropdown list values must be strings or numbers"
                )
                if labels[value] == nil then
                    table.insert(keys, value)
                    labels[value] = tostring(value)
                end
            end
        else
            for key, value in pairs(source) do
                assert(
                    type(key) == "string" or type(key) == "number",
                    "Dropdown dictionary keys must be strings or numbers"
                )
                table.insert(keys, key)
                labels[key] = tostring(value)
            end
            table.sort(keys, function(a, b)
                local x, y = string.lower(labels[a]), string.lower(labels[b])
                if x == y then return tostring(a) < tostring(b) end
                return x < y
            end)
        end
        return keys, labels, not array
    end
    function dropdownData.Prune(value, keys, multi)
        if not multi then return table.find(keys, value) and value or nil end
        local result = {}
        if type(value) ~= "table" then return result end
        for _, key in ipairs(keys) do
            if value[key] == true or table.find(value, key) then result[key] = true end
        end
        return result
    end
    function dropdownData.Equal(a, b)
        if type(a) ~= "table" or type(b) ~= "table" then return a == b end
        for key, value in pairs(a) do
            if b[key] ~= value then return false end
        end
        for key, value in pairs(b) do
            if a[key] ~= value then return false end
        end
        return true
    end
    function dropdownData.Disabled(source, keys, labels)
        local result = {}
        for _, key in ipairs(keys) do
            if source[key] == true or table.find(source, key) or table.find(source, labels[key]) then
                result[key] = true
            end
        end
        return result
    end
    function dropdownData.Valid(value, keys, multi)
        if not multi then return value == nil or table.find(keys, value) ~= nil end
        if type(value) ~= "table" then return false end
        for key, item in pairs(value) do
            if item == true then
                if not table.find(keys, key) then return false end
            elseif type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #value or not table.find(keys, item) then
                return false
            end
        end
        return true
    end

    local function addGroup(tab, config)
        config = config or {}
        local side = config.Side or "Left"
        assert(side == "Left" or side == "Right", "Group Side must be Left or Right")
        local group = { Name = config.Name or "Group", Elements = {}, RowSections = {} }
        group.SearchText = group.Name
        local frame = rounded("Frame", group.Name, tab.Columns[side], 0, 0, 0, 0, "Card", 12)
        frame.Size = UDim2.new(1, config.FrameInset or -6, 0, 0)
        frame.AutomaticSize = Enum.AutomaticSize.None
        frame.ClipsDescendants = true
        frame.LayoutOrder = #tab.Groups + 1
        group.Frame = frame
        frame:SetAttribute("BlocksWindowDrag", true)
        local border = Instance.new("UIStroke")
        bindTheme(border, "Color", "Border")
        border.Parent = frame
        border.Transparency = 0.35
        glassSurface(frame, 0.08, border)
        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 10)
        padding.PaddingBottom = UDim.new(0, 10)
        padding.PaddingLeft = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 10)
        padding.Parent = frame
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        layout.Parent = frame
        local title = Instance.new("TextButton")
        title.AutoButtonColor = false
        title.Text = ""
        title.Name = "Title"
        title.Size = UDim2.new(1, 0, 0, 24)
        title.BackgroundTransparency = 1
        title.Parent = frame
        local titleIcon = icon(title, config.Icon or "layout-grid", 0, 0, 16, "Icon", "Icon")
        titleIcon.AnchorPoint = Vector2.new(0, 0.5)
        titleIcon.Position = UDim2.new(0, 0, 0.5, 0)
        local titleText = label(title, group.Name, 13)
        setUIFont(titleText, true)
        titleText.Position = UDim2.fromOffset(24, 0)
        titleText.Size = UDim2.new(1, -48, 1, 0)
        titleText.TextYAlignment = Enum.TextYAlignment.Center

        if config.Description then
            title.Size = UDim2.new(1, 0, 0, 38)
            titleText.Size = UDim2.new(1, -48, 0, 20)
            local description = label(title, config.Description, 11)
            description.Name = "Description"
            description.Position = UDim2.fromOffset(24, 20)
            description.Size = UDim2.new(1, -48, 0, 18)
            description.TextTruncate = Enum.TextTruncate.AtEnd
            bindTheme(description, "TextColor3", "Muted")
        end
        local collapseArrow = icon(title, "chevron-down", 0, 4, 16)
        collapseArrow.Position = UDim2.new(1, -18, 0.5, -8)
        collapseArrow.Rotation = 180
        collapseArrow.Visible = config.Collapsible ~= false
        local groupContent = Instance.new("CanvasGroup")
        groupContent.Name = "Content"
        groupContent.Size = UDim2.new(1, 0, 0, 0)
        groupContent.AutomaticSize = Enum.AutomaticSize.Y
        groupContent.BackgroundTransparency = 1
        groupContent.LayoutOrder = 1
        groupContent.Parent = frame
        local innerLayout = Instance.new("UIListLayout")
        innerLayout.SortOrder = Enum.SortOrder.LayoutOrder
        innerLayout.Padding = UDim.new(0, 6)
        innerLayout.Parent = groupContent
        local collapseRevision = 0
        local detachedHost, detachedScale
        local detachedWidth = 260
        local groupDrag, groupDragStart, groupDragOrigin, groupDragTarget, groupDragPoint
        local draggedTitle = false
        local groupConnections = {}
        local function groupTrack(connection)
            table.insert(groupConnections, connection)
            return connection
        end
        local function groupFactor()
            return detachedScale and detachedScale.Scale
                or (
                    config.ScaleProvider and config.ScaleProvider()
                    or scale.Scale * (windowTransitioning and windowMotionScale.Scale or 1)
                )
        end
        local function clampGroupPosition(position)
            local available = viewport.AbsoluteSize
            local size = detachedHost and detachedHost.AbsoluteSize or frame.AbsoluteSize
            return Vector2.new(
                math.clamp(position.X, 0, math.max(0, available.X - size.X)),
                math.clamp(position.Y, 0, math.max(0, available.Y - size.Y))
            )
        end
        local function resizeGroup(immediate)
            if not frame.Parent then return end
            local height = padding.PaddingTop.Offset + title.Size.Y.Offset + padding.PaddingBottom.Offset
            if not group.Collapsed then
                height = height
                    + layout.Padding.Offset
                    + innerLayout.AbsoluteContentSize.Y / math.max(0.01, groupFactor())
            end
            motion(frame, { Size = UDim2.new(1, config.FrameInset or -6, 0, height) }, 0.2, immediate)
            if detachedHost then
                local maximum = math.max(1, (viewport.AbsoluteSize.Y - 16) / math.max(0.01, groupFactor()))
                detachedHost.Size = UDim2.fromOffset(detachedWidth, math.min(height + 4, maximum))
                local factor = groupFactor()
                detachedHost.Position = UDim2.fromOffset(
                    math.clamp(
                        detachedHost.Position.X.Offset,
                        0,
                        math.max(0, viewport.AbsoluteSize.X - detachedWidth * factor)
                    ),
                    math.clamp(
                        detachedHost.Position.Y.Offset,
                        0,
                        math.max(0, viewport.AbsoluteSize.Y - detachedHost.Size.Y.Offset * factor)
                    )
                )
            end
        end
        innerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() resizeGroup(false) end)
        local groupScaleConnection = scale:GetPropertyChangedSignal("Scale"):Connect(function() resizeGroup(true) end)
        frame.Destroying:Connect(function() groupScaleConnection:Disconnect() end)
        function group:SetCollapsed(collapsed, immediate)
            self.Collapsed = collapsed == true
            collapseRevision = collapseRevision + 1
            local revision = collapseRevision
            groupContent.Visible = true
            groupContent:SetAttribute("Disabled", self.Collapsed)
            motion(collapseArrow, { Rotation = self.Collapsed and 0 or 180 }, 0.18, immediate)
            motion(groupContent, { GroupTransparency = self.Collapsed and 1 or 0 }, 0.16, immediate)
            resizeGroup(immediate)
            if self.Collapsed then
                finishSlider()
                finishColorDrag()
                if openDropdown and openDropdown.Trigger:IsDescendantOf(frame) then closeDropdown(true) end
                local focused = UserInputService:GetFocusedTextBox()
                if focused and focused:IsDescendantOf(frame) then focused:ReleaseFocus() end
                cancelKeyCapture()
                if immediate then
                    groupContent.Visible = false
                else
                    task.delay(animationDuration(0.2), function()
                        if frame.Parent and collapseRevision == revision and self.Collapsed then
                            groupContent.Visible = false
                        end
                    end)
                end
            end
        end
        function group:ToggleCollapsed() self:SetCollapsed(not self.Collapsed) end
        title.Activated:Connect(function()
            if not draggedTitle and config.Collapsible ~= false and not dialogOpen then group:ToggleCollapsed() end
        end)
        function group:Detach(position)
            if config.Detachable == false or detachedHost then return false end
            if position ~= nil then assert(typeof(position) == "Vector2", "Detached position expects Vector2") end
            local origin = position or (frame.AbsolutePosition - viewport.AbsolutePosition)
            detachedWidth = math.max(160, frame.AbsoluteSize.X / math.max(0.01, scale.Scale) + 6)
            cancelKeyCapture()
            closeDropdown(true)
            finishSlider()
            finishColorDrag()
            local focused = UserInputService:GetFocusedTextBox()
            if focused and focused:IsDescendantOf(frame) then focused:ReleaseFocus() end
            detachedHost = Instance.new("ScrollingFrame")
            detachedHost.Name = group.Name .. "DetachedPanel"
            detachedHost.BackgroundTransparency = 1
            detachedHost.BorderSizePixel = 0
            detachedHost.ZIndex = 50
            detachedHost.ScrollBarThickness = 3
            bindTheme(detachedHost, "ScrollBarImageColor3", "Muted")
            detachedHost.ScrollBarImageTransparency = 0.5
            detachedHost.CanvasSize = UDim2.fromOffset(0, 0)
            detachedHost.AutomaticCanvasSize = Enum.AutomaticSize.Y
            detachedHost.ScrollingDirection = Enum.ScrollingDirection.Y
            detachedHost.ScrollingEnabled = groupDrag == nil
            detachedHost.Size = UDim2.fromOffset(detachedWidth, 100)
            detachedHost.Parent = viewport
            detachedScale = Instance.new("UIScale")
            detachedScale.Scale = math.min(scale.Scale, math.max(0.01, (viewport.AbsoluteSize.X - 16) / detachedWidth))
            detachedScale.Parent = detachedHost
            frame.Parent = detachedHost
            detachedHost:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                if openDropdown and openDropdown.Trigger and openDropdown.Trigger:IsDescendantOf(frame) then
                    closeDropdown(true)
                end
            end)
            frame.Position = UDim2.fromOffset(3, 2)
            group.Detached, group.DetachedWindow = true, detachedHost
            resizeGroup(true)
            local clamped = clampGroupPosition(origin)
            detachedHost.Position = UDim2.fromOffset(clamped.X, clamped.Y)
            return true
        end
        function group:Attach()
            if not detachedHost then return false end
            cancelKeyCapture()
            closeDropdown(true)
            finishSlider()
            finishColorDrag()
            local focused = UserInputService:GetFocusedTextBox()
            if focused and focused:IsDescendantOf(frame) then focused:ReleaseFocus() end
            groupDrag, groupDragTarget = nil, nil
            local host = detachedHost
            frame.Parent = tab.Columns[side]
            frame.Position = UDim2.fromOffset(0, 0)
            detachedHost, detachedScale = nil, nil
            group.Detached, group.DetachedWindow = false, nil
            host:Destroy()
            resizeGroup(true)
            return true
        end
        function group:IsDetached() return detachedHost ~= nil end
        bindDragStart(title, function(input)
            if config.Detachable == false or dialogOpen or groupDrag then return end
            if
                input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch
            then
                return
            end
            draggedTitle = false
            groupDrag, groupDragStart = input, Vector2.new(input.Position.X, input.Position.Y)
            groupDragPoint = groupDragStart
            groupDragOrigin = (detachedHost or frame).AbsolutePosition - viewport.AbsolutePosition
            if detachedHost then detachedHost.ScrollingEnabled = false end
        end)
        groupTrack(UserInputService.InputChanged:Connect(function(input)
            if not groupDrag or dialogOpen then return end
            local mouse = groupDrag.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseMovement
            if input ~= groupDrag and not mouse then return end
            groupDragPoint = Vector2.new(input.Position.X, input.Position.Y)
            local delta = groupDragPoint - groupDragStart
            if not draggedTitle and delta.Magnitude < 6 then return end
            draggedTitle = true
            if not detachedHost then group:Detach(groupDragOrigin) end
            groupDragTarget = clampGroupPosition(groupDragOrigin + delta)
        end))
        groupTrack(UserInputService.InputEnded:Connect(function(input)
            if input == groupDrag then
                local point = input.UserInputType == Enum.UserInputType.Touch
                        and Vector2.new(input.Position.X, input.Position.Y)
                    or groupDragPoint
                local dropIntoUI = draggedTitle
                    and detachedHost ~= nil
                    and not dialogOpen
                    and dropInsideWindow(point, root)
                groupDrag = nil
                if dropIntoUI then
                    group:Attach()
                    if activeTab ~= tab then tab:Activate() end
                    return
                end
                if detachedHost then detachedHost.ScrollingEnabled = true end
            end
        end))
        groupTrack(UserInputService.WindowFocusReleased:Connect(function()
            groupDrag, groupDragTarget = nil, nil
            if detachedHost then detachedHost.ScrollingEnabled = true end
        end))
        groupTrack(game:GetService("RunService").RenderStepped:Connect(function(dt)
            if not detachedHost or not groupDragTarget then return end
            if dialogOpen then
                groupDrag, groupDragTarget = nil, nil
                detachedHost.ScrollingEnabled = true
                return
            end
            local current = Vector2.new(detachedHost.Position.X.Offset, detachedHost.Position.Y.Offset)
            local target = clampGroupPosition(groupDragTarget)
            local nextPosition = current:Lerp(target, 1 - math.exp(-32 * dt))
            if (nextPosition - target).Magnitude < 0.2 then
                nextPosition = target
                if not groupDrag then groupDragTarget = nil end
            end
            detachedHost.Position = UDim2.fromOffset(nextPosition.X, nextPosition.Y)
        end))
        local function resizeDetached()
            if not detachedHost then return end
            groupDrag, groupDragTarget = nil, nil
            detachedHost.ScrollingEnabled = true
            detachedScale.Scale = math.min(scale.Scale, math.max(0.01, (viewport.AbsoluteSize.X - 16) / detachedWidth))
            resizeGroup(true)
            local position =
                clampGroupPosition(Vector2.new(detachedHost.Position.X.Offset, detachedHost.Position.Y.Offset))
            detachedHost.Position = UDim2.fromOffset(position.X, position.Y)
        end
        groupTrack(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeDetached))
        groupTrack(scale:GetPropertyChangedSignal("Scale"):Connect(resizeDetached))
        groupTrack(tab.Columns[side].Destroying:Connect(function()
            if detachedHost then detachedHost:Destroy() end
        end))
        frame.Destroying:Connect(function()
            for _, connection in ipairs(groupConnections) do
                connection:Disconnect()
            end
            local host = detachedHost
            detachedHost, detachedScale = nil, nil
            if host then
                task.defer(function()
                    if host.Parent then host:Destroy() end
                end)
            end
        end)
        group:SetCollapsed(config.Collapsed == true, true)
        local insertionSection
        local function row(name, height)
            local object = Instance.new("CanvasGroup")
            object.Name = name
            object.BackgroundTransparency = 1
            object.Size = UDim2.new(1, 0, 0, height)
            object.LayoutOrder = #group.Elements + 1
            object:SetAttribute("UserVisible", true)
            object.Parent = insertionSection and insertionSection.Frame or groupContent
            group.RowSections[object] = insertionSection
            table.insert(group.Elements, object)
            group.SearchText = group.SearchText .. " " .. name
            if insertionSection then insertionSection.SearchText = insertionSection.SearchText .. " " .. name end
            filterCards()
            return object
        end
        local function persist(options, kind, owner, read, write, validate, changed)
            if options.NoSave then return end
            local id = options.SaveId
                or (
                    tab.Name
                    .. "/"
                    .. group.Name
                    .. "/"
                    .. (insertionSection and (insertionSection.Name .. "/") or "")
                    .. (options.Name or kind)
                )
            registerControl(id, kind, owner, read, write, validate, changed)
        end
        local function persistColor(options, picker, owner)
            persist(
                options,
                "ColorPicker",
                owner,
                function() return { Color = picker.Value:ToHex(), Transparency = picker.Transparency } end,
                function(value) picker:Set(Color3.fromHex(value.Color), value.Transparency, true) end,
                function(value)
                    return type(value) == "table"
                        and type(value.Color) == "string"
                        and value.Color:match("^%x%x%x%x%x%x$") ~= nil
                        and type(value.Transparency) == "number"
                        and value.Transparency >= 0
                        and value.Transparency <= 1
                end,
                function()
                    if options.Callback then options.Callback(picker.Value, picker.Transparency) end
                end
            )
        end
        function group:AddKeybind(options)
            options = options or {}
            local container = row(options.Name or "Keybind", 28)
            local text = label(container, options.Name or "Keybind")
            text.Size = UDim2.new(1, -32, 1, 0)
            local button = rounded("TextButton", "Keybind", container, 0, 3, 24, 22, "Search", 6)
            button.Position = UDim2.new(1, -24, 0, 3)
            button.BackgroundTransparency = 1
            button.TextSize = 10
            setUIFont(button, true)
            local keyboardIcon = icon(button, "keyboard", 5, 4, 14)
            button.TextTruncate = Enum.TextTruncate.AtEnd
            animateButton(button, "Search")
            local control = { Keybind = Enum.KeyCode.Unknown, Modifiers = {}, AllowModifierKey = true }
            function control:RefreshKeybind()
                local listening = capturingKeybind == self
                local iconOnly = not listening and self.Keybind == Enum.KeyCode.Unknown
                keyboardIcon.Visible = iconOnly
                button.Text = iconOnly and ""
                    or (listening and "..." or shortKeyNames[self.Keybind.Name] or self.Keybind.Name)
                tween(button, { TextColor3 = listening and "Accent" or "Muted" }, 0.12)
            end
            function control:SetModifiers(value)
                self.Modifiers = {}
                for name in pairs(modifierKeys) do
                    if value[name] == true then self.Modifiers[name] = true end
                end
                self:RefreshKeybind()
            end
            function control:SetKeybind(key)
                if type(key) == "string" then key = Enum.KeyCode[key] end
                assert(typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode, "Invalid keybind")
                self.Keybind = key
                for name, keys in pairs(modifierKeys) do
                    if table.find(keys, key) then self.Modifiers[name] = nil end
                end
                self:RefreshKeybind()
            end
            button.Activated:Connect(function()
                if not canInteract(container) then return end
                local listening = capturingKeybind == control
                cancelKeyCapture()
                if not listening then
                    closeDropdown(true)
                    releaseHolds()
                    capturingKeybind = control
                    control:RefreshKeybind()
                end
            end)
            container.Destroying:Connect(function()
                if capturingKeybind == control then capturingKeybind = nil end
            end)
            control:SetKeybind(options.Default or Enum.KeyCode.Unknown)
            persist(
                options,
                "Keybind",
                container,
                function() return { Keybind = control.Keybind.Name, Modifiers = table.clone(control.Modifiers) } end,
                function(value)
                    control:SetModifiers(value.Modifiers or {})
                    control:SetKeybind(value.Keybind)
                end,
                function(value)
                    if type(value) ~= "table" or type(value.Keybind) ~= "string" then return false end
                    local ok, key = pcall(function() return Enum.KeyCode[value.Keybind] end)
                    if not ok or not key then return false end
                    if value.Modifiers ~= nil then
                        if type(value.Modifiers) ~= "table" then return false end
                        for name, enabled in pairs(value.Modifiers) do
                            if not modifierKeys[name] or type(enabled) ~= "boolean" then return false end
                        end
                    end
                    return true
                end
            )
            return control
        end
        function group:AddDivider(options)
            options = type(options) == "string" and { Text = options } or (options or {})
            local container = row("Divider", options.Text and 24 or 10)
            local line = rounded("Frame", "Line", container, 0, 4, 0, 1, "Border", 0)
            line.Size = UDim2.new(1, 0, 0, 1)
            if options.Text then
                line.Position = UDim2.fromOffset(0, 23)
                local title = label(container, options.Text, 11)
                title.Size = UDim2.new(1, 0, 0, 19)
                bindTheme(title, "TextColor3", "Muted")
            end
            return container
        end
        function group:AddCheckbox(options)
            options = options or {}
            local container = row(options.Name or "Checkbox", 28)
            local text = label(container, options.Name or "Checkbox")
            text.Size = UDim2.new(1, -30, 1, 0)
            text.TextTruncate = Enum.TextTruncate.AtEnd
            local button = rounded("TextButton", "Checkbox", container, 0, 5, 18, 18, "Search", 4)
            button.Position = UDim2.new(1, -18, 0, 5)
            local stroke = Instance.new("UIStroke")
            bindTheme(stroke, "Color", "Border")
            stroke.Parent = button
            local check = icon(button, "check", 2, 2, 14, "OnAccent")
            local control = { Value = false }
            function control:Set(value, silent)
                self.Value = value == true
                check.Visible = self.Value
                tween(button, { BackgroundColor3 = self.Value and "Accent" or "Search" })
                tween(stroke, { Color = self.Value and "Accent" or "Border" })
                if not silent and options.Callback then options.Callback(self.Value) end
            end
            control.SetValue = control.Set
            button.Activated:Connect(function()
                if canInteract(container) then control:Set(not control.Value) end
            end)
            control:Set(options.Default, true)
            persist(
                options,
                "Checkbox",
                container,
                function() return control.Value end,
                function(value) control:Set(value, true) end,
                function(value) return type(value) == "boolean" end,
                function()
                    if options.Callback then options.Callback(control.Value) end
                end
            )
            return control
        end
        group.AddCheckboxes = group.AddCheckbox
        function group:AddLabel(text)
            if type(text) == "table" then text = text.Text end
            local container = row(text or "Label", 0)
            container.AutomaticSize = Enum.AutomaticSize.Y
            local object = label(container, text or "Label")
            object.Size = UDim2.new(1, 0, 0, 16)
            object.AutomaticSize = Enum.AutomaticSize.Y
            object.TextWrapped = true
            bindTheme(object, "TextColor3", "Muted")
            return object
        end
        function group:AddColorPicker(options)
            options = options or {}
            local container = row(options.Name or "Color picker", 28)
            local text = label(container, options.Name or "Color picker")
            text.Size = UDim2.new(1, -36, 1, 0)
            text.TextTruncate = Enum.TextTruncate.AtEnd
            local swatch = rounded("TextButton", "ColorSwatch", container, 0, 5, 18, 18, "Accent", 4)
            swatch.Position = UDim2.new(1, -18, 0, 5)
            local stroke = Instance.new("UIStroke")
            bindTheme(stroke, "Color", "Muted")
            stroke.Parent = swatch
            local picker = createColorPicker(container, swatch, options)
            persistColor(options, picker, container)
            tab.Columns[side]:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                if openDropdown == picker then closeDropdown(true) end
            end)
            return picker
        end
        function group:AddToggle(options)
            options = options or {}
            local container = row(options.Name or "Toggle", 28)
            local text = label(container, options.Name or "Toggle")
            text.Size = UDim2.new(1, -128, 1, 0)
            text.TextTruncate = Enum.TextTruncate.AtEnd
            local bell = rounded("TextButton", "Notify", container, 0, 2, 24, 24, "Card", 6)
            bell.Position = UDim2.new(1, -120, 0, 2)
            bell.BackgroundTransparency = 1
            local bellIcon = icon(bell, "bell", 5, 5, 14)
            local keyButton = rounded("TextButton", "Keybind", container, 0, 3, 48, 22, "Search", 6)
            keyButton.Position = UDim2.new(1, -90, 0, 3)
            setUIFont(keyButton, true)
            keyButton.TextSize = 10
            bindTheme(keyButton, "TextColor3", "Muted")
            keyButton.TextTruncate = Enum.TextTruncate.AtEnd
            local keyboardIcon = icon(keyButton, "keyboard", 5, 4, 14)
            local keyBorder = Instance.new("UIStroke")
            bindTheme(keyBorder, "Color", "Border")
            keyBorder.Parent = keyButton
            animateButton(keyButton, "Search")
            local button = rounded("TextButton", "Switch", container, 0, 4, 34, 20, "Navigation", 10)
            button.Position = UDim2.new(1, -34, 0, 4)
            local dot = rounded("Frame", "Dot", button, 10, 10, 14, 14, "Muted", 7)
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            local toggleRevision = 0
            local control = {
                Value = false,
                Notify = options.Notify ~= false,
                Keybind = Enum.KeyCode.Unknown,
                ColorSpace = 0,
                KeybindMode = "Toggle",
                Modifiers = {},
                Name = options.Name or "Toggle",
            }
            function control:RefreshKeybind()
                local listening = capturingKeybind == self
                local iconOnly = not listening and self.Keybind == Enum.KeyCode.Unknown
                local width = 24
                keyButton.Size = UDim2.fromOffset(width, 22)
                keyButton.Position = UDim2.new(1, -42 - width - self.ColorSpace, 0, 3)
                keyButton.BackgroundTransparency = 1
                keyBorder.Transparency = 1
                keyboardIcon.Visible = iconOnly
                bell.Position = UDim2.new(1, -72 - width - self.ColorSpace, 0, 2)
                text.Size = UDim2.new(1, -80 - width - self.ColorSpace, 1, 0)
                local keyName = self.Keybind == Enum.KeyCode.Unknown and "-" or self.Keybind.Name
                keyButton.Text = iconOnly and "" or (listening and "..." or shortKeyNames[keyName] or keyName)
                tween(keyButton, { TextColor3 = listening and "Accent" or "Muted" }, 0.15)
                tween(keyBorder, { Color = listening and "Accent" or "Border" }, 0.15)
                refreshKeybindMenu()
            end
            function control:AddColorPicker(colorOptions)
                if self.ColorPicker then return self.ColorPicker end
                local swatch = rounded("TextButton", "ColorSwatch", container, 0, 5, 18, 18, "Accent", 4)
                swatch.Position = UDim2.new(1, -58, 0, 5)
                local stroke = Instance.new("UIStroke")
                bindTheme(stroke, "Color", "Muted")
                stroke.Parent = swatch
                colorOptions = colorOptions or {}
                colorOptions.Name = colorOptions.Name or ((options.Name or "Toggle") .. " color")
                colorOptions.NoSave = colorOptions.NoSave or options.NoSave
                self.ColorPicker = createColorPicker(container, swatch, colorOptions)
                persistColor(colorOptions, self.ColorPicker, container)
                self.ColorSpace = 24
                self:RefreshKeybind()
                tab.Columns[side]:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                    if openDropdown == self.ColorPicker then closeDropdown(true) end
                end)
                return self.ColorPicker
            end
            function control:SetKeybind(key)
                if self.Holding then
                    self.Holding = false
                    self:Set(false)
                end
                if type(key) == "string" then
                    local success, result = pcall(function() return Enum.KeyCode[key] end)
                    assert(success and result, "Unknown keybind: " .. key)
                    key = result
                end
                self.Keybind = key or Enum.KeyCode.Unknown
                self:RefreshKeybind()
            end
            function control:SetModifiers(modifiers)
                if self.Holding then
                    self.Holding = false
                    self:Set(false)
                end
                self.Modifiers = {}
                for name, enabled in pairs(modifiers or {}) do
                    if type(name) == "number" then
                        name, enabled = enabled, true
                    end
                    assert(modifierKeys[name], "Unknown modifier")
                    if enabled then self.Modifiers[name] = true end
                end
                self:RefreshKeybind()
                refreshKeybindMenu()
            end
            function control:SetKeybindMode(mode, silent)
                assert(mode == "Toggle" or mode == "Hold" or mode == "Always", "Invalid keybind mode")
                if self.Holding then
                    self.Holding = false
                    self:Set(false, silent)
                end
                self.KeybindMode = mode
                if mode == "Always" then self:Set(true, silent) end
                refreshKeybindMenu()
            end
            function control:SetNotify(enabled)
                self.Notify = enabled == true
                local coords = iconAtlas["bell"]
                bellIcon.ImageRectOffset = Vector2.new(coords[1], coords[2])
                tween(bellIcon, {
                    ImageColor3 = self.Notify and "Text" or "Muted",
                    ImageTransparency = 0,
                }, 0.18)
            end
            function control:Set(value, silent)
                if self.KeybindMode == "Always" then value = true end
                local previousValue = self.Value
                self.Value = value == true
                toggleRevision = toggleRevision + 1
                local revision = toggleRevision
                motion(button, { BackgroundColor3 = self.Value and "Accent" or "Navigation" }, 0.18, silent)
                motion(dot, {
                    Position = UDim2.fromOffset(self.Value and 24 or 10, 10),
                    BackgroundColor3 = self.Value and "OnAccent" or "Muted",
                }, 0.18, silent)
                motion(dot, { Size = UDim2.fromOffset(silent and 14 or 17, silent and 14 or 12) }, 0.07, silent)
                if not silent then
                    task.delay(animationDuration(0.07), function()
                        if dot.Parent and toggleRevision == revision then
                            motion(dot, { Size = UDim2.fromOffset(14, 14) }, 0.16)
                        end
                    end)
                end
                if not silent and options.Callback then options.Callback(self.Value) end
                refreshKeybindMenu()
                if not silent and not loadingConfig and self.Notify and previousValue ~= self.Value then
                    notify({
                        Title = options.Name or "Toggle",
                        Content = self.Value and "Enabled" or "Disabled",
                        Icon = self.Value and "check" or "bell-off",
                    })
                end
            end
            bell.Activated:Connect(function()
                if canInteract(container) then control:SetNotify(not control.Notify) end
            end)
            keyButton.Activated:Connect(function()
                if not canInteract(container) then return end
                local wasCapturing = capturingKeybind == control
                cancelKeyCapture()
                if not wasCapturing then
                    capturingKeybind = control
                    control:RefreshKeybind()
                    notify({
                        Title = "Set keybind",
                        Content = "Press a key (Ctrl/Shift/Alt allowed). Escape: cancel / Backspace: clear.",
                        Icon = "keyboard",
                        Duration = 4,
                    })
                end
            end)
            button.Activated:Connect(function()
                if canInteract(container) then control:Set(not control.Value) end
            end)
            container.Destroying:Connect(function()
                keybindControls[control] = nil
                refreshKeybindMenu()
                if capturingKeybind == control then capturingKeybind = nil end
            end)
            keybindControls[control] = true
            control:SetKeybind(options.Keybind)
            control:SetNotify(control.Notify)
            control:SetModifiers(options.Modifiers)
            control:SetKeybindMode(options.Mode or "Toggle", true)
            control:Set(options.Default, true)
            persist(
                options,
                "Toggle",
                container,
                function()
                    return {
                        Value = control.Value,
                        Keybind = control.Keybind.Name,
                        Notify = control.Notify,
                        Mode = control.KeybindMode,
                        Modifiers = table.clone(control.Modifiers),
                    }
                end,
                function(value)
                    control:SetKeybindMode(value.Mode or "Toggle", true)
                    control:SetModifiers(value.Modifiers)
                    control:Set(value.Value, true)
                    control:SetKeybind(value.Keybind)
                    control:SetNotify(value.Notify)
                end,
                function(value)
                    if
                        type(value) ~= "table"
                        or type(value.Value) ~= "boolean"
                        or type(value.Notify) ~= "boolean"
                        or type(value.Keybind) ~= "string"
                    then
                        return false
                    end
                    if value.Mode and value.Mode ~= "Toggle" and value.Mode ~= "Hold" and value.Mode ~= "Always" then
                        return false
                    end
                    if value.Modifiers ~= nil then
                        if type(value.Modifiers) ~= "table" then return false end
                        for name, enabled in pairs(value.Modifiers) do
                            if not modifierKeys[name] or type(enabled) ~= "boolean" then return false end
                        end
                    end
                    return pcall(function() assert(Enum.KeyCode[value.Keybind]) end)
                end,
                function()
                    if options.Callback then options.Callback(control.Value) end
                end
            )
            if options.ColorPicker then control:AddColorPicker(options.ColorPicker) end
            return control
        end
        function group:AddButton(options)
            options = options or {}
            local container = row(options.Name or "Button", 28)
            local button = rounded("TextButton", "Button", container, 0, 0, 0, 28, "Navigation", 6)
            button.Size = UDim2.new(1, 0, 0, 28)
            button.Text = options.Name or "Button"
            bindTheme(button, "TextColor3", "Text")
            setUIFont(button, true)
            button.TextSize = 12
            animateButton(button, "Navigation")
            button.Activated:Connect(function()
                if canInteract(container) and options.Callback then options.Callback() end
            end)
            return button
        end
        function group:AddSlider(options)
            options = options or {}
            local minimum, maximum = options.Min or 0, options.Max or 100
            local step = options.Increment or 1
            local isRange = options.Range == true
            assert(maximum > minimum and step > 0, "Invalid slider range")
            local container = row(options.Name or "Slider", 28)
            local text = label(container, options.Name or "Slider")
            local trackStart = 0.62
            text.Size = UDim2.new(trackStart, isRange and -97 or -51, 1, 0)
            text.TextTruncate = Enum.TextTruncate.AtEnd
            local function input(name, x, width)
                local field = Instance.new("TextBox")
                field.Name = name
                field.BackgroundTransparency = 1
                setUIFont(field)
                field.TextSize = 12
                field.ClearTextOnFocus = false
                field.Position = UDim2.new(trackStart, x, 0, 0)
                field.Size = UDim2.new(0, width, 1, 0)
                field.TextXAlignment = Enum.TextXAlignment.Center
                bindTheme(field, "TextColor3", "Text")
                field.Parent = container
                return field
            end
            local first = input(isRange and "LowInput" or "ValueInput", isRange and -92 or -44, 30)
            local second
            if isRange then
                local separator = icon(container, "arrow-left-right", 0, 0, 16, "Muted")
                separator.Name = "RangeSeparator"
                separator.AnchorPoint = Vector2.new(0, 0.5)
                separator.Position = UDim2.new(trackStart, -61, 0.5, 0)
                second = input("HighInput", -44, 30)
            end
            local hit = rounded("TextButton", "TrackHit", container, 0, 0, 0, 28, "Card", 0)
            hit.Position = UDim2.new(trackStart, 0, 0, 0)
            hit.Size = UDim2.new(1 - trackStart, -8, 1, 0)
            hit.BackgroundTransparency = 1
            local trackFrame = rounded("Frame", "Track", hit, 0, 10, 0, 8, "Navigation", 4)
            trackFrame.Size = UDim2.new(1, 0, 0, 8)
            local fill = rounded("Frame", "Fill", trackFrame, 0, 0, 0, 8, "Accent", 4)
            local highlight = Instance.new("UIGradient")
            highlight.Transparency =
                NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) })
            highlight.Parent = fill
            local function thumb(name)
                local knob = rounded("Frame", name, trackFrame, 0, 4, 16, 12, "Text", 6)
                knob.AnchorPoint = Vector2.new(0.5, 0.5)
                knob.ZIndex = 2
                local knobScale = Instance.new("UIScale")
                knobScale.Parent = knob
                return knob
            end
            local lowKnob = isRange and thumb("LowKnob") or nil
            local highKnob = thumb(isRange and "HighKnob" or "Knob")
            local control = {}
            local function quantize(value)
                assert(
                    type(value) == "number" and value == value and math.abs(value) < math.huge,
                    "Slider expects finite numbers"
                )
                if value <= minimum then return minimum end
                if value >= maximum then return maximum end
                return math.clamp(minimum + math.floor((value - minimum) / step + 0.5) * step, minimum, maximum)
            end
            local function display(value) return string.format("%.4g", value) .. (options.Suffix or "") end
            function control:Set(value, silent)
                local low, high
                if isRange then
                    assert(type(value) == "table", "Range slider expects {low, high}")
                    low, high = quantize(value[1]), quantize(value[2])
                    if low > high then
                        low, high = high, low
                    end
                    self.Value = { low, high }
                    self.Low, self.High = low, high
                else
                    low, high = minimum, quantize(value)
                    self.Value = high
                end
                local a, b = (low - minimum) / (maximum - minimum), (high - minimum) / (maximum - minimum)
                local duration = activeSlider and activeSlider.Control == self and 0.065 or 0.2
                motion(fill, { Position = UDim2.fromScale(a, 0), Size = UDim2.fromScale(b - a, 1) }, duration, silent)
                motion(highKnob, { Position = UDim2.new(b, 0, 0.5, 0) }, duration, silent)
                if isRange then
                    motion(lowKnob, { Position = UDim2.new(a, 0, 0.5, 0) }, duration, silent)
                    first.Text, second.Text = display(low), display(high)
                else
                    first.Text = display(high)
                end
                if not silent and options.Callback then
                    options.Callback(isRange and table.clone(self.Value) or self.Value)
                end
            end
            control.SetValue = control.Set
            local selectedHandle = "High"
            local sliderHovered = false
            local function sliderFeedback()
                for name, knob in pairs({ Low = lowKnob, High = highKnob }) do
                    local pressed = activeSlider and activeSlider.Control == control and selectedHandle == name
                    motion(knob.UIScale, { Scale = pressed and 1.18 or (sliderHovered and 1.08 or 1) }, 0.12)
                end
            end
            hit.MouseEnter:Connect(function()
                sliderHovered = true
                sliderFeedback()
            end)
            hit.MouseLeave:Connect(function()
                sliderHovered = false
                sliderFeedback()
            end)
            local function valueAt(position)
                return minimum
                    + math.clamp((position.X - hit.AbsolutePosition.X) / math.max(1, hit.AbsoluteSize.X), 0, 1)
                        * (maximum - minimum)
            end
            local function update(position)
                local value = quantize(valueAt(position))
                if isRange then
                    if selectedHandle == "Low" then
                        control:Set({ math.min(value, control.High), control.High })
                    else
                        control:Set({ control.Low, math.max(value, control.Low) })
                    end
                else
                    control:Set(value)
                end
            end
            hit.InputBegan:Connect(function(input)
                if not canInteract(container) then return end
                if
                    input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch
                then
                    if isRange then
                        local value = valueAt(input.Position)
                        local lowDistance, highDistance = math.abs(value - control.Low), math.abs(value - control.High)
                        selectedHandle = (
                            lowDistance < highDistance
                            or (lowDistance == highDistance and value < control.Low)
                        )
                                and "Low"
                            or "High"
                    end
                    finishSlider()
                    activeSlider = {
                        Input = input,
                        Update = update,
                        Control = control,
                        Release = function()
                            sliderFeedback()
                            if options.OnDragEnd then options.OnDragEnd() end
                        end,
                    }
                    sliderFeedback()
                    update(input.Position)
                end
            end)
            local function bindInput(field, index)
                field.Focused:Connect(
                    function() field.Text = string.format("%.4g", isRange and control.Value[index] or control.Value) end
                )
                field.FocusLost:Connect(function()
                    local parsed = tonumber(field.Text)
                    if not parsed or parsed ~= parsed or math.abs(parsed) == math.huge then
                        control:Set(control.Value, true)
                        return
                    end
                    if isRange then
                        local values = table.clone(control.Value)
                        values[index] = index == 1 and math.min(parsed, control.High) or math.max(parsed, control.Low)
                        control:Set(values)
                    else
                        control:Set(parsed)
                    end
                end)
            end
            bindInput(first, 1)
            if second then bindInput(second, 2) end
            control:Set(options.Default or (isRange and { minimum, maximum } or minimum), true)
            persist(
                options,
                isRange and "RangeSlider" or "Slider",
                container,
                function() return isRange and table.clone(control.Value) or control.Value end,
                function(value) control:Set(value, true) end,
                function(value)
                    local function valid(number)
                        return type(number) == "number" and number == number and number >= minimum and number <= maximum
                    end
                    if isRange then
                        return type(value) == "table"
                            and #value == 2
                            and valid(value[1])
                            and valid(value[2])
                            and value[1] <= value[2]
                    end
                    return valid(value)
                end,
                function()
                    if options.Callback then
                        options.Callback(isRange and table.clone(control.Value) or control.Value)
                    end
                end
            )
            return control
        end
        function group:AddRangeSlider(options)
            options = table.clone(options or {})
            options.Range = true
            return self:AddSlider(options)
        end
        group.AddDoubleSlider = group.AddRangeSlider
        function group:AddTextbox(options)
            options = options or {}
            local container = row(options.Name or "Textbox", options.MultiLine and 106 or 28)
            local text = label(container, options.Name or "Textbox")
            text.Size = options.MultiLine and UDim2.new(1, 0, 0, 20) or UDim2.new(0.48, -8, 1, 0)
            text.TextTruncate = Enum.TextTruncate.AtEnd
            local input = rounded("TextBox", "Input", container, 0, 24, 0, 26, "Search", 6)
            input.Position = options.MultiLine and UDim2.fromOffset(0, 24) or UDim2.new(0.48, 0, 0, 1)
            input.Size = options.MultiLine and UDim2.new(1, 0, 0, 80) or UDim2.new(0.52, 0, 0, 26)
            input.TextXAlignment = Enum.TextXAlignment.Left
            local inputPadding = Instance.new("UIPadding")
            inputPadding.PaddingLeft = UDim.new(0, 8)
            inputPadding.PaddingRight = UDim.new(0, 8)
            inputPadding.Parent = input
            input.MultiLine = options.MultiLine == true
            input.TextWrapped = options.MultiLine == true
            input.TextYAlignment = options.MultiLine and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
            input.Text = options.Default or ""
            input.PlaceholderText = options.Placeholder or "Enter text"
            bindTheme(input, "PlaceholderColor3", "Muted")
            bindTheme(input, "TextColor3", "Text")
            setUIFont(input)
            input.TextSize = 12
            input.ClearTextOnFocus = false
            input.FocusLost:Connect(function()
                if options.Callback then options.Callback(input.Text) end
            end)
            persist(
                options,
                "Textbox",
                container,
                function() return input.Text end,
                function(value) input.Text = value end,
                function(value) return type(value) == "string" end,
                function()
                    if options.Callback then options.Callback(input.Text) end
                end
            )
            return input
        end
        function group:AddDropdown(options)
            options = options or {}
            local values, labels, dictionary = {}, {}, false
            local sourceValues, disabledValues, images = {}, options.DisabledValues or {}, options.ValueImages or {}
            local initialized = false
            local container = row(options.Name or "Dropdown", 28)
            local text = label(container, options.Name or "Dropdown")
            text.Size = UDim2.new(0.48, -8, 1, 0)
            text.TextTruncate = Enum.TextTruncate.AtEnd
            local button = rounded("TextButton", "Choice", container, 0, 1, 0, 26, "Search", 6)
            button.Position = UDim2.new(0.48, 0, 0, 1)
            button.Size = UDim2.new(0.52, 0, 0, 26)
            local buttonBorder = Instance.new("UIStroke")
            bindTheme(buttonBorder, "Color", "Border")
            buttonBorder.Parent = button
            local valueLabel = label(button, "Select an option", 12)
            valueLabel.Position = UDim2.fromOffset(11, 0)
            valueLabel.Size = UDim2.new(1, -42, 1, 0)
            valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
            local arrow = icon(button, "chevron-down", 0, 5, 16)
            arrow.Position = UDim2.new(1, -23, 0, 5)
            animateButton(button, "Search")
            local menu = rounded("CanvasGroup", "DropdownMenu", dropdownOverlay, 0, 0, 240, 100, "Card", 9)
            menu.ZIndex = 2
            menu.Visible = false
            local menuScale = Instance.new("UIScale")
            menuScale.Parent = menu
            local menuBorder = Instance.new("UIStroke")
            bindTheme(menuBorder, "Color", "Border")
            menuBorder.Transparency = 0.2
            menuBorder.Parent = menu
            local list = Instance.new("ScrollingFrame")
            list.Name = "Choices"
            list.Position = UDim2.fromOffset(6, 6)
            list.Size = UDim2.new(1, -12, 1, -12)
            list.BackgroundTransparency = 1
            list.BorderSizePixel = 0
            list.CanvasSize = UDim2.fromOffset(0, 0)
            list.AutomaticCanvasSize = Enum.AutomaticSize.Y
            list.ScrollingDirection = Enum.ScrollingDirection.Y
            list.ScrollBarThickness = 3
            bindTheme(list, "ScrollBarImageColor3", "Muted")
            list.Active = true
            list.Parent = menu
            local layout = Instance.new("UIListLayout")
            layout.Padding = UDim.new(0, 3)
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Parent = list
            local searchEnabled = options.Searchable ~= false
            local menuSearch = rounded("TextBox", "Search", menu, 6, 6, 0, 26, "Search", 5)
            menuSearch.Size = UDim2.new(1, -12, 0, 26)
            menuSearch.Text = ""
            menuSearch.PlaceholderText = "Search..."
            setUIFont(menuSearch)
            menuSearch.TextSize = 12
            menuSearch.ClearTextOnFocus = false
            menuSearch.Visible = searchEnabled
            bindTheme(menuSearch, "TextColor3", "Text")
            bindTheme(menuSearch, "PlaceholderColor3", "Muted")
            if searchEnabled then
                list.Position = UDim2.fromOffset(6, 38)
                list.Size = UDim2.new(1, -12, 1, -44)
            end
            local noResults = label(menu, "No results", 12)
            noResults.Position = UDim2.fromOffset(6, searchEnabled and 38 or 6)
            noResults.Size = UDim2.new(1, -12, 0, 32)
            noResults.TextXAlignment = Enum.TextXAlignment.Center
            noResults.Visible = false
            local control = {
                Options = menu,
                Trigger = button,
                Arrow = arrow,
                Entries = {},
                Revision = 0,
                Multi = options.Multi == true,
                AllowNull = options.AllowNull ~= false,
                DragSelect = options.DragSelect == true,
                Value = {},
            }
            local listeners, connections, thumbnailCache = {}, {}, {}
            local dragInput, dragDesired, dragSeen, dragReleased = nil, false, {}, 0
            local function notifyChanged()
                local function snapshot() return control.Multi and table.clone(control.Value) or control.Value end
                if options.Callback then options.Callback(snapshot()) end
                for _, callback in ipairs(listeners) do
                    callback(snapshot())
                end
            end
            local function selected(value)
                return control.Multi and control.Value[value] == true or (not control.Multi and value == control.Value)
            end
            local function listLabel(key)
                return tostring(options.FormatListValue and options.FormatListValue(key, labels[key]) or labels[key])
            end
            local function updateDisplay()
                local names = {}
                for _, key in ipairs(values) do
                    if selected(key) then table.insert(names, labels[key]) end
                end
                local empty = #names == 0
                local fallback = empty and (control.Multi and "Select values" or "Select an option")
                    or table.concat(names, ", ")
                local value = control.Multi and table.clone(control.Value) or control.Value
                valueLabel.Text =
                    tostring(options.FormatDisplayValue and options.FormatDisplayValue(value, fallback) or fallback)
                bindTheme(valueLabel, "TextColor3", empty and "Muted" or "Text")
            end
            local function updateSelectionGroups()
                local visible = {}
                for _, entry in ipairs(control.Entries) do
                    entry.JoinTop.Visible, entry.JoinBottom.Visible = false, false
                    if entry.Button.Visible then table.insert(visible, entry) end
                end
                if not control.Multi then return end
                for index, entry in ipairs(visible) do
                    if selected(entry.Value) then
                        local previous, following = visible[index - 1], visible[index + 1]
                        entry.JoinTop.Visible = previous ~= nil and selected(previous.Value)
                        entry.JoinBottom.Visible = following ~= nil and selected(following.Value)
                    end
                end
            end
            local function filterOptions()
                local query, count = string.lower(menuSearch.Text), 0
                for _, entry in ipairs(control.Entries) do
                    entry.Button.Visible = searchMatches(entry.Label.Text, query) or searchMatches(entry.Value, query)
                    if entry.Button.Visible then count = count + 1 end
                end
                noResults.Visible = count == 0
                list.CanvasPosition = Vector2.zero
                updateSelectionGroups()
            end
            menuSearch:GetPropertyChangedSignal("Text"):Connect(filterOptions)
            local function paint(entry, hovering)
                local isSelected = selected(entry.Value)
                motion(entry.Button, {
                    BackgroundColor3 = isSelected and "Selected" or "Navigation",
                    BackgroundTransparency = (isSelected or (hovering and not entry.Disabled)) and 0 or 1,
                }, 0.14)
                motion(
                    entry.Label,
                    { TextColor3 = entry.Disabled and "Muted" or (isSelected and "SelectedText" or "Text") },
                    0.14
                )
                entry.Label.TextTransparency = entry.Disabled and 0.35 or 0
                entry.Check.Visible = isSelected
                entry.Button.Interactable = not entry.Disabled and not control.Disabled
            end
            local function stopDrag()
                if dragInput then dragReleased = os.clock() + 0.15 end
                dragInput, dragSeen = nil, {}
                list.ScrollingEnabled = true
            end
            function control:Close(immediate)
                stopDrag()
                menuSearch:ReleaseFocus()
                self.Revision = self.Revision + 1
                local revision = self.Revision
                if self.Animation then self.Animation:Cancel() end
                tweenIcon(arrow, "Icon", 0)
                tween(buttonBorder, { Color = "Border" }, 0.16)
                local function finish()
                    if self.Revision ~= revision then return end
                    menu.Visible = false
                    if not openDropdown then dropdownOverlay.Visible = false end
                end
                if immediate then
                    finish()
                else
                    self.Animation = tween(menu, { GroupTransparency = 1 }, 0.12)
                    task.delay(animationDuration(0.12), finish)
                end
            end
            function control:Set(value, silent)
                if self.Multi then
                    assert(type(value) == "table", "Multi dropdown expects a list or selection map")
                else
                    assert(value == nil or table.find(values, value), "Unknown dropdown value")
                end
                local nextValue = dropdownData.Prune(value, values, self.Multi)
                local empty = self.Multi and next(nextValue) == nil or (not self.Multi and nextValue == nil)
                if empty and not self.AllowNull and #values > 0 then
                    nextValue = self.Multi and { [values[1]] = true } or values[1]
                end
                self.Value = nextValue
                updateDisplay()
                for _, entry in ipairs(self.Entries) do
                    paint(entry, false)
                end
                updateSelectionGroups()
                if not self.Multi and openDropdown == self then closeDropdown() end
                if not silent then notifyChanged() end
            end
            control.SetValue = control.Set
            function control:OnChanged(callback)
                assert(type(callback) == "function", "OnChanged expects a function")
                table.insert(listeners, callback)
                return self
            end
            function control:GetActiveValues(returnCount)
                local result = {}
                for _, key in ipairs(values) do
                    if selected(key) then table.insert(result, key) end
                end
                return returnCount and #result or result
            end
            function control:Open()
                if not canInteract(container) or #values == 0 then return end
                cancelKeyCapture()
                closeDropdown(true)
                self.Revision = self.Revision + 1
                if self.Animation then self.Animation:Cancel() end
                openDropdown = self
                menuSearch.Text = ""
                filterOptions()
                local limit = math.clamp(math.floor(tonumber(options.MaxVisibleDropdownItems) or 6), 1, 30)
                local count = math.min(#values, limit)
                local height = count * 35 - 3 + 12 + (searchEnabled and 32 or 0)
                local width = math.max(180, button.AbsoluteSize.X / math.max(0.01, scale.Scale))
                local available = viewport.AbsoluteSize
                local factor =
                    math.max(0.01, math.min(scale.Scale, (available.X - 16) / width, (available.Y - 16) / height))
                menuScale.Scale = factor
                local origin = button.AbsolutePosition - viewport.AbsolutePosition
                local below = origin.Y + button.AbsoluteSize.Y + 6 * factor
                local y = below + height * factor <= available.Y - 8 and below
                    or origin.Y - height * factor - 6 * factor
                local x = math.clamp(
                    origin.X + button.AbsoluteSize.X - width * factor,
                    8,
                    math.max(8, available.X - width * factor - 8)
                )
                y = math.clamp(y, 8, math.max(8, available.Y - height * factor - 8))
                menu.Size = UDim2.fromOffset(width, height)
                menu.Position = UDim2.fromOffset(x, y + 4 * factor)
                menu.GroupTransparency = 1
                menu.Visible, dropdownOverlay.Visible = true, true
                local selectedIndex = 1
                for index, entry in ipairs(self.Entries) do
                    paint(entry, false)
                    if selected(entry.Value) then selectedIndex = index end
                end
                list.CanvasPosition =
                    Vector2.new(0, math.max(0, math.min((selectedIndex - 1) * 35, (#values - count) * 35)))
                tweenIcon(arrow, "Icon", 180)
                tween(buttonBorder, { Color = "Accent" }, 0.18)
                self.Animation = tween(menu, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) }, 0.18)
            end
            local function choose(entry, desired)
                if entry.Disabled or not canInteract(container) then return end
                if control.Multi then
                    local nextValue = table.clone(control.Value)
                    nextValue[entry.Value] = desired or nil
                    if not control.AllowNull and next(nextValue) == nil then return end
                    control:Set(nextValue)
                else
                    control:Set(entry.Value)
                end
            end
            local function dragChoose(entry)
                if not dragInput or dragSeen[entry.Value] then return end
                dragSeen[entry.Value] = true
                choose(entry, dragDesired)
            end
            local function updateImage(entry)
                local asset = images[entry.Value]
                entry.Image.Image = asset
                        and (tostring(asset):match("^%d+$") and "rbxassetid://" .. tostring(asset) or tostring(asset))
                    or ""
                entry.Image.Visible = asset ~= nil
                local imageEnabled = asset ~= nil
                    or (options.SpecialType == "Player" and options.EnablePlayerImages == true)
                entry.Label.Position = UDim2.fromOffset(imageEnabled and 35 or 9, 0)
                entry.Label.Size = UDim2.new(1, imageEnabled and -65 or -39, 1, 0)
                if not asset and imageEnabled then
                    local target = Players:FindFirstChild(tostring(entry.Value))
                    if target then
                        entry.Image.Visible = true
                        if thumbnailCache[target.UserId] then
                            entry.Image.Image = thumbnailCache[target.UserId]
                        else
                            task.spawn(function()
                                local ok, thumbnail = pcall(
                                    function()
                                        return Players:GetUserThumbnailAsync(
                                            target.UserId,
                                            Enum.ThumbnailType.HeadShot,
                                            Enum.ThumbnailSize.Size100x100
                                        )
                                    end
                                )
                                if ok then
                                    thumbnailCache[target.UserId] = thumbnail
                                    if uiAlive and entry.Image.Parent and not images[entry.Value] then
                                        entry.Image.Image = thumbnail
                                    end
                                end
                            end)
                        end
                    end
                end
            end
            function control:SetValues(newValues, silent)
                if openDropdown == self then closeDropdown(true) end
                local nextKeys, nextLabels, isDictionary = dropdownData.Normalize(newValues)
                for _, entry in ipairs(self.Entries) do
                    entry.Button:Destroy()
                end
                self.Entries = {}
                sourceValues, values, labels, dictionary = table.clone(newValues), nextKeys, nextLabels, isDictionary
                self.Values = table.clone(sourceValues)
                local disabled = dropdownData.Disabled(disabledValues, values, labels)
                for index, key in ipairs(values) do
                    local option = rounded("TextButton", "Option", list, 0, 0, 0, 32, "Navigation", 6)
                    option.Size = UDim2.new(1, 0, 0, 32)
                    option.LayoutOrder = index
                    option.BackgroundTransparency = 1
                    local joinTop = rounded("Frame", "JoinTop", option, 0, 0, 0, 6, "Selected", 0)
                    joinTop.Size = UDim2.new(1, 0, 0, 6)
                    local joinBottom = rounded("Frame", "JoinBottom", option, 0, 26, 0, 9, "Selected", 0)
                    joinBottom.Size = UDim2.new(1, 0, 0, 9)
                    joinTop.Visible, joinBottom.Visible = false, false
                    local optionImage = Instance.new("ImageLabel")
                    optionImage.BackgroundTransparency = 1
                    optionImage.Position = UDim2.fromOffset(8, 6)
                    optionImage.Size = UDim2.fromOffset(20, 20)
                    optionImage.Parent = option
                    local optionLabel = label(option, listLabel(key), 12)
                    optionLabel.TextTruncate = Enum.TextTruncate.AtEnd
                    local check = icon(option, "check", 0, 8, 16, "Accent")
                    check.Position = UDim2.new(1, -25, 0, 8)
                    local entry = {
                        Value = key,
                        Button = option,
                        Label = optionLabel,
                        Image = optionImage,
                        Check = check,
                        Disabled = disabled[key] == true,
                        JoinTop = joinTop,
                        JoinBottom = joinBottom,
                    }
                    table.insert(self.Entries, entry)
                    updateImage(entry)
                    option.MouseEnter:Connect(function()
                        dragChoose(entry)
                        paint(entry, true)
                    end)
                    option.MouseLeave:Connect(function() paint(entry, false) end)
                    option.InputBegan:Connect(function(input)
                        if
                            not control.Multi
                            or not control.DragSelect
                            or entry.Disabled
                            or not canInteract(container)
                        then
                            return
                        end
                        if
                            input.UserInputType ~= Enum.UserInputType.MouseButton1
                            and input.UserInputType ~= Enum.UserInputType.Touch
                        then
                            return
                        end
                        dragInput, dragDesired, dragSeen = input, not selected(key), {}
                        list.ScrollingEnabled = false
                        dragChoose(entry)
                    end)
                    option.Activated:Connect(function()
                        if dragInput or os.clock() < dragReleased then return end
                        choose(entry, not selected(key))
                    end)
                end
                local previous = self.Value
                self:Set(dropdownData.Prune(previous, values, self.Multi), true)
                filterOptions()
                if initialized and not silent and not dropdownData.Equal(previous, self.Value) then notifyChanged() end
                initialized = true
            end
            function control:AddValues(newValues)
                if type(newValues) ~= "table" then newValues = { newValues } end
                local nextValues = table.clone(sourceValues)
                local keys, newLabels, newDictionary = dropdownData.Normalize(newValues)
                if dictionary or newDictionary then
                    if not dictionary then
                        nextValues = {}
                        for _, key in ipairs(values) do
                            nextValues[key] = labels[key]
                        end
                    end
                    for _, key in ipairs(keys) do
                        nextValues[key] = newLabels[key]
                    end
                else
                    for _, key in ipairs(keys) do
                        if not table.find(nextValues, key) then table.insert(nextValues, key) end
                    end
                end
                self:SetValues(nextValues)
            end
            function control:SetDisabledValues(newValues)
                assert(type(newValues) == "table", "DisabledValues expects a list or map")
                disabledValues = table.clone(newValues)
                local disabled = dropdownData.Disabled(disabledValues, values, labels)
                for _, entry in ipairs(self.Entries) do
                    entry.Disabled = disabled[entry.Value] == true
                    paint(entry, false)
                end
            end
            function control:SetValueImages(newImages)
                assert(type(newImages) == "table", "ValueImages expects a map")
                images = table.clone(newImages)
                for _, entry in ipairs(self.Entries) do
                    updateImage(entry)
                end
            end
            function control:SetDragSelect(enabled)
                self.DragSelect = enabled == true
                if not self.DragSelect then stopDrag() end
            end
            local function specialValues()
                local result = {}
                if options.SpecialType == "Player" then
                    for _, target in ipairs(Players:GetPlayers()) do
                        if not options.ExcludeLocalPlayer or target ~= player then
                            result[target.Name] = target.DisplayName .. " (@" .. target.Name .. ")"
                        end
                    end
                elseif options.SpecialType == "Team" then
                    for _, team in ipairs(game:GetService("Teams"):GetTeams()) do
                        result[team.Name] = team.Name
                    end
                end
                return result
            end
            if options.SpecialType then
                assert(
                    options.SpecialType == "Player" or options.SpecialType == "Team",
                    "SpecialType must be Player or Team"
                )
            end
            control:SetValues(
                options.SpecialType and specialValues() or (options.Options or options.Values or {}),
                true
            )
            local default = options.Default
            if default == nil then default = control.Multi and {} or values[1] end
            if
                not control.Multi
                and type(default) == "number"
                and not table.find(values, default)
                and not dictionary
            then
                default = values[default]
            end
            control:Set(default, true)
            button.Activated:Connect(function()
                if openDropdown == control then
                    closeDropdown()
                else
                    control:Open()
                end
            end)
            connections[#connections + 1] = tab.Columns[side]
                :GetPropertyChangedSignal("CanvasPosition")
                :Connect(function()
                    if openDropdown == control then closeDropdown(true) end
                end)
            connections[#connections + 1] = UserInputService.InputEnded:Connect(function(input)
                if input == dragInput then stopDrag() end
            end)
            connections[#connections + 1] = UserInputService.WindowFocusReleased:Connect(stopDrag)
            connections[#connections + 1] = UserInputService.InputChanged:Connect(function(input)
                if
                    not dragInput
                    or (input ~= dragInput and input.UserInputType ~= Enum.UserInputType.MouseMovement)
                then
                    return
                end
                local point = input.Position
                for _, entry in ipairs(control.Entries) do
                    local origin, size = entry.Button.AbsolutePosition, entry.Button.AbsoluteSize
                    if
                        entry.Button.Visible
                        and point.X >= origin.X
                        and point.X <= origin.X + size.X
                        and point.Y >= origin.Y
                        and point.Y <= origin.Y + size.Y
                    then
                        dragChoose(entry)
                        break
                    end
                end
            end)
            if options.SpecialType then
                local function refresh()
                    task.defer(function()
                        if uiAlive and container.Parent then control:SetValues(specialValues()) end
                    end)
                end
                if options.SpecialType == "Player" then
                    connections[#connections + 1] = Players.PlayerAdded:Connect(refresh)
                    connections[#connections + 1] = Players.PlayerRemoving:Connect(refresh)
                else
                    local teams = game:GetService("Teams")
                    connections[#connections + 1] = teams.ChildAdded:Connect(refresh)
                    connections[#connections + 1] = teams.ChildRemoved:Connect(refresh)
                end
            end
            container.Destroying:Connect(function()
                control.Revision = control.Revision + 1
                if openDropdown == control then closeDropdown(true) end
                if control.Animation then control.Animation:Cancel() end
                for _, connection in ipairs(connections) do
                    connection:Disconnect()
                end
                menu:Destroy()
            end)
            persist(
                options,
                control.Multi and "MultiDropdown" or "Dropdown",
                container,
                function() return control.Multi and control:GetActiveValues() or control.Value end,
                function(value) control:Set(value, true) end,
                function(value) return dropdownData.Valid(value, values, control.Multi) end,
                notifyChanged
            )
            return control
        end

        local stateByControl = {}
        function group:SetControlDisabled(control, disabled)
            assert(stateByControl[control], "Control does not belong to this card")
            stateByControl[control].Disable(disabled)
        end
        function group:SetControlVisible(control, visible)
            assert(stateByControl[control], "Control does not belong to this card")
            stateByControl[control].Visible(visible)
        end
        for _, method in ipairs({
            "AddKeybind",
            "AddToggle",
            "AddCheckbox",
            "AddCheckboxes",
            "AddSlider",
            "AddDropdown",
            "AddTextbox",
            "AddColorPicker",
            "AddButton",
            "AddLabel",
            "AddDivider",
        }) do
            local original = group[method]
            group[method] = function(self, options)
                local control = original(self, options)
                local container = group.Elements[#group.Elements]
                local config = type(options) == "table" and options or {}
                container:SetAttribute("SearchText", config.Tooltip or "")
                local function stopInteraction()
                    finishSlider()
                    finishColorDrag()
                    if
                        openDropdown
                        and (openDropdown.Trigger == container or openDropdown.Trigger:IsDescendantOf(container))
                    then
                        closeDropdown(true)
                    end
                    if capturingKeybind == control then cancelKeyCapture() end
                    if type(control) == "table" and control.Holding then
                        control.Holding = false
                        control:Set(false)
                    end
                end
                local function disable(disabled)
                    disabled = disabled == true
                    container:SetAttribute("Disabled", disabled)
                    container.GroupTransparency = disabled and 0.55 or 0
                    if type(control) == "table" then control.Disabled = disabled end
                    for _, child in ipairs(container:GetDescendants()) do
                        if child:IsA("GuiButton") then child.Interactable = not disabled end
                        if child:IsA("TextBox") then
                            child.TextEditable = not disabled
                            if disabled then child:ReleaseFocus() end
                        end
                    end
                    if disabled then stopInteraction() end
                    refreshKeybindMenu()
                end
                local function visible(value)
                    container:SetAttribute("UserVisible", value ~= false)
                    filterCards()
                    if not table.find(tab.Groups, group) then container.Visible = value ~= false end
                    if not container.Visible then stopInteraction() end
                end
                stateByControl[control] = { Disable = disable, Visible = visible }
                if type(control) == "table" then
                    control.Frame = container
                    function control:SetDisabled(value) disable(value) end
                    function control:SetVisible(value) visible(value) end
                end
                disable(config.Disabled)
                visible(config.Visible)
                addTooltip(container, config.Tooltip, config.DisabledTooltip)
                container.Destroying:Connect(function()
                    if activeSlider and activeSlider.Control == control then finishSlider() end
                    stateByControl[control] = nil
                end)
                return control
            end
        end
        group.Sections = {}
        function group:AddTab(name)
            if not self.TabStrip then
                self.TabStrip = rounded("Frame", "TabStrip", groupContent, 0, 0, 0, 28, "Search", 6)
                self.TabStrip.Size = UDim2.new(1, 0, 0, 28)
                self.TabStrip.LayoutOrder = 1
                self.TabIndicator = rounded("Frame", "Selection", self.TabStrip, 2, 2, 0, 24, "Selected", 5)
            end
            local section = { Name = name, SearchText = name, Index = #self.Sections + 1 }
            local page = Instance.new("CanvasGroup")
            page.Name = name
            page.Size = UDim2.new(1, 0, 0, 0)
            page.AutomaticSize = Enum.AutomaticSize.Y
            page.BackgroundTransparency = 1
            page.LayoutOrder = 2
            page.Visible = false
            page.Parent = groupContent
            section.Frame = page
            local pageLayout = Instance.new("UIListLayout")
            pageLayout.Padding = UDim.new(0, 6)
            pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
            pageLayout.Parent = page
            local button = rounded("TextButton", name, self.TabStrip, 0, 0, 0, 28, "Selected", 5)
            button.Text = name
            button.BackgroundTransparency = 1
            button.ZIndex = 2
            setUIFont(button, true)
            button.TextSize = 12
            section.Button = button
            table.insert(self.Sections, section)
            for index, item in ipairs(self.Sections) do
                item.Button.Size = UDim2.new(1 / #self.Sections, -4, 1, -4)
                item.Button.Position = UDim2.new((index - 1) / #self.Sections, 2, 0, 2)
            end
            if self.ActiveSection then
                self.TabIndicator.Size = UDim2.new(1 / #self.Sections, -4, 1, -4)
                self.TabIndicator.Position = UDim2.new((self.ActiveSection.Index - 1) / #self.Sections, 2, 0, 2)
            end
            function section:Activate()
                if group.ActiveSection == self then return end
                local firstActivation = group.ActiveSection == nil
                closeDropdown(true)
                finishSlider()
                group.ActiveSection = self
                motion(group.TabIndicator, {
                    Size = UDim2.new(1 / #group.Sections, -4, 1, -4),
                    Position = UDim2.new((self.Index - 1) / #group.Sections, 2, 0, 2),
                }, 0.2, firstActivation)
                for _, item in ipairs(group.Sections) do
                    local selected = item == self
                    item.Frame.Visible = selected
                    item.Button.BackgroundTransparency = 1
                    motion(item.Button, { TextColor3 = selected and "SelectedText" or "Muted" }, 0.16, firstActivation)
                    motion(item.Frame, { GroupTransparency = selected and not firstActivation and 1 or 0 }, 0, true)
                    if selected then motion(item.Frame, { GroupTransparency = 0 }, 0.2, firstActivation) end
                end
            end
            for _, method in ipairs({
                "AddKeybind",
                "AddToggle",
                "AddCheckbox",
                "AddCheckboxes",
                "AddSlider",
                "AddRangeSlider",
                "AddDoubleSlider",
                "AddDropdown",
                "AddTextbox",
                "AddColorPicker",
                "AddDivider",
                "AddLabel",
                "AddButton",
            }) do
                section[method] = function(_, options, info)
                    insertionSection = section
                    local ok, result = pcall(group[method], group, options, info)
                    insertionSection = nil
                    if not ok then error(result, 2) end
                    return result
                end
            end
            button.Activated:Connect(function() section:Activate() end)
            if #self.Sections == 1 then
                section:Activate()
            else
                bindTheme(button, "TextColor3", "Muted")
                button.BackgroundTransparency = 1
            end
            section.AddInput = section.AddTextbox
            return section
        end

        for _, method in ipairs({
            "AddKeybind",
            "AddToggle",
            "AddCheckbox",
            "AddSlider",
            "AddRangeSlider",
            "AddDropdown",
            "AddTextbox",
            "AddColorPicker",
            "AddButton",
            "AddDivider",
            "AddLabel",
        }) do
            local create = group[method]
            group[method] = function(self, id, info)
                local options = type(id) == "string" and info and table.clone(info) or id
                if type(options) == "table" then
                    options = table.clone(options)
                    options.Name = options.Name or options.Text
                    if type(id) == "string" and info then options.SaveId = id end
                    if method == "AddLabel" then options.Text = options.Text or options.Name end
                    if options.SaveId then
                        assert(
                            not Options[options.SaveId] and not controlRegistry[options.SaveId],
                            "Duplicate control ID: " .. options.SaveId
                        )
                    end
                end
                local control = create(self, options)
                if type(control) == "table" and control.Set then control.SetValue = control.Set end
                if type(options) == "table" and options.SaveId then
                    Options[options.SaveId] = control
                    if method == "AddToggle" or method == "AddCheckbox" then Toggles[options.SaveId] = control end
                    local owner = type(control) == "table" and control.Frame or control
                    if owner and typeof(owner) == "Instance" then
                        owner.Destroying:Connect(function()
                            Options[options.SaveId], Toggles[options.SaveId] = nil, nil
                        end)
                    end
                end
                return control
            end
        end
        group.AddInput = group.AddTextbox
        group.AddCheckboxes = group.AddCheckbox
        group.AddDoubleSlider = group.AddRangeSlider

        table.insert(tab.Groups, group)
        filterCards()
        return group
    end

    local function selectTab(selected)
        local target = type(selected) == "table" and selected or tabs[selected]
        if not target or activeTab == target then return end
        cancelKeyCapture()
        closeDropdown()
        finishSlider()
        for _, tab in ipairs(tabs) do
            if tab.Fade then tab.Fade:Cancel() end
            local active = tab == target
            tab.Page.Visible = active
            tab.Page.GroupTransparency = active and 1 or 0
            tab.Page.Position = UDim2.fromOffset(0, active and 6 or 0)
            motion(tab.Button, { BackgroundTransparency = active and 0.12 or 1 }, 0.22)
            motion(tab.Scale, { Scale = active and 1.04 or 1 }, 0.22)
            motion(tab.Stroke, { Transparency = active and 0.18 or 1 }, 0.22)
            tweenIcon(tab.Icon, "Icon")
            tween(tab.Icon, { ImageTransparency = active and 0 or 0.4 }, 0.16)
        end
        activeTab = target
        target.Fade = tween(target.Page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.3)
        filterCards()
    end
    local function addTab(config)
        config = config or {}
        local index = #tabs + 1
        local tab = { Name = config.Name or ("Tab " .. index), Groups = {}, Columns = {} }
        local button = rounded("TextButton", tab.Name, navigationGroup, 0, 0, 40, 40, "Selected", 10)
        button.LayoutOrder = index
        button.BackgroundTransparency = 1
        tab.Button = button
        navigation[index] = button
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        bindTheme(stroke, "Color", "Accent")
        stroke.Transparency = 1
        stroke.Parent = button
        tab.Stroke = stroke
        glassSurface(button, 1, stroke)
        addTooltip(button, tab.Name)
        tab.Scale = Instance.new("UIScale")
        tab.Scale.Parent = button
        tab.Icon = icon(button, config.Icon or "layout-grid", 10, 10, 20)
        tab.Icon.ImageTransparency = 0.4
        tab.Title = label(button, tab.Name, 12)
        tab.Title.Position = UDim2.fromOffset(38, 0)
        tab.Title.Size = UDim2.new(1, -44, 1, 0)
        tab.Title.Visible = false
        tab.Title.TextTruncate = Enum.TextTruncate.AtEnd
        local page = Instance.new("CanvasGroup")
        page.Name = tab.Name
        page.Size = UDim2.fromScale(1, 1)
        page.BackgroundTransparency = 1
        page.Visible = false
        page.Parent = content
        tab.Page = page
        for _, side in ipairs({ "Left", "Right" }) do
            local column = Instance.new("ScrollingFrame")
            column.Name = side
            column.BackgroundTransparency = 1
            column.BorderSizePixel = 0
            column.Size = UDim2.new(0.5, -1, 1, 0)
            column.Position = side == "Left" and UDim2.fromOffset(0, 0) or UDim2.new(0.5, 1, 0, 0)
            column.CanvasSize = UDim2.fromOffset(0, 0)
            column.AutomaticCanvasSize = Enum.AutomaticSize.Y
            column.ScrollingDirection = Enum.ScrollingDirection.Y
            column.ScrollingEnabled = true
            column.ScrollBarThickness = 0
            column.ScrollBarImageTransparency = 1
            bindTheme(column, "ScrollBarImageColor3", "Muted")
            column.Active = true
            column.Parent = page
            local padding = Instance.new("UIPadding")
            padding.PaddingTop = UDim.new(0, 2)
            padding.PaddingBottom = UDim.new(0, 8)
            padding.PaddingLeft = UDim.new(0, 3)
            padding.Parent = column
            local layout = Instance.new("UIListLayout")
            layout.Padding = UDim.new(0, 8)
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Parent = column
            tab.Columns[side] = column
        end
        tab.Empty = label(page, "No cards yet", 13)
        tab.Empty.Size = UDim2.fromScale(1, 1)
        tab.Empty.TextXAlignment = Enum.TextXAlignment.Center
        bindTheme(tab.Empty, "TextColor3", "Muted")
        tab.AddGroup = addGroup
        function tab:AddLeftGroupbox(name, iconName)
            return self:AddGroup({ Name = name, Icon = iconName, Side = "Left" })
        end
        function tab:AddRightGroupbox(name, iconName)
            return self:AddGroup({ Name = name, Icon = iconName, Side = "Right" })
        end
        function tab:Activate() selectTab(self) end
        button.Activated:Connect(function()
            if not uiShown then setUIVisible(true) end
            selectTab(tab)
        end)
        local hovering = false
        local function navigationFeedback(pressed)
            local selected = activeTab == tab
            motion(tab.Scale, { Scale = pressed and 0.94 or ((selected or hovering) and 1.04 or 1) }, 0.16)
            motion(button, { BackgroundTransparency = selected and 0.12 or (hovering and 0.62 or 1) }, 0.16)
            motion(stroke, { Transparency = selected and 0.18 or (hovering and 0.75 or 1) }, 0.16)
            motion(tab.Icon, { ImageTransparency = (selected or hovering) and 0 or 0.4 }, 0.16)
        end
        button.MouseEnter:Connect(function()
            hovering = true
            navigationFeedback(false)
        end)
        button.MouseLeave:Connect(function()
            hovering = false
            navigationFeedback(false)
        end)
        button.InputBegan:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                navigationFeedback(true)
            end
        end)
        button.InputEnded:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                navigationFeedback(false)
            end
        end)
        table.insert(tabs, tab)
        centerNavigation()
        if #tabs == 1 then selectTab(tab) end
        return tab
    end
    track(UserInputService.InputChanged:Connect(function(input)
        if
            activeSlider
            and (
                input == activeSlider.Input
                or (
                    activeSlider.Input.UserInputType == Enum.UserInputType.MouseButton1
                    and input.UserInputType == Enum.UserInputType.MouseMovement
                )
            )
        then
            activeSlider.Update(input.Position)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if activeSlider and input == activeSlider.Input then finishSlider() end
    end))
    track(UserInputService.WindowFocusReleased:Connect(function() finishSlider() end))
    screen.Destroying:Connect(function()
        finishSlider()
        for _, tab in ipairs(tabs) do
            if tab.Fade then tab.Fade:Cancel() end
        end
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
    end)

    local activeDialog
    local function showDialog(config)
        config = config or {}
        if activeDialog then activeDialog:Close() end
        closeDropdown(true)
        cancelKeyCapture()
        releaseHolds()
        dialogOpen = true
        local shade = rounded("TextButton", "DialogOverlay", viewport, 0, 0, 0, 0, Color3.new(0, 0, 0), 0)
        shade.Size = UDim2.fromScale(1, 1)
        shade.BackgroundTransparency = 0.35
        shade.ZIndex = 250
        local panel = rounded("Frame", "Dialog", shade, 0, 0, 340, 166, "Card", 10)
        panel.AnchorPoint = Vector2.new(0.5, 0.5)
        panel.Position = UDim2.fromScale(0.5, 0.5)
        local panelScale = Instance.new("UIScale")
        panelScale.Scale = scale.Scale
        panelScale.Parent = panel
        local title = label(panel, config.Title or "Confirm", 15)
        title.Position = UDim2.fromOffset(16, 12)
        title.Size = UDim2.new(1, -32, 0, 26)
        local message = label(panel, config.Content or "Are you sure?", 12)
        message.TextWrapped = true
        message.Position = UDim2.fromOffset(16, 44)
        message.Size = UDim2.new(1, -32, 0, 64)
        local cancel = rounded("TextButton", "Cancel", panel, 16, 120, 148, 30, "Navigation", 6)
        local confirm = rounded("TextButton", "Confirm", panel, 176, 120, 148, 30, "Accent", 6)
        cancel.Text = config.CancelText or "Cancel"
        confirm.Text = config.ConfirmText or "Confirm"
        for _, button in ipairs({ cancel, confirm }) do
            setUIFont(button, true)
            button.TextSize = 12
            bindTheme(button, "TextColor3", "Text")
        end
        bindTheme(confirm, "TextColor3", "OnAccent")
        local dialog = { Frame = shade }
        function dialog:Close()
            if activeDialog ~= self then return end
            activeDialog = nil
            dialogOpen = false
            shade:Destroy()
        end
        activeDialog = dialog
        cancel.Activated:Connect(function()
            dialog:Close()
            if config.OnCancel then config.OnCancel() end
        end)
        confirm.Activated:Connect(function()
            if activeDialog ~= dialog then return end
            dialog:Close()
            if config.OnConfirm then config.OnConfirm() end
        end)
        return dialog
    end
    track(UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape and activeDialog then activeDialog:Close() end
    end))
    local function addOverlay(config)
        config = config or {}
        local frame = rounded("TextButton", config.Name or "InfoOverlay", viewport, 18, 18, 245, 32, "Card", 8)
        frame.ZIndex = 150
        frame.Position = config.Position or UDim2.fromOffset(18, 18)
        frame.Text = config.Text or "Viz"
        setUIFont(frame, true)
        frame.TextSize = 12
        bindTheme(frame, "TextColor3", "Text")
        local dragging, start, origin
        local move = UserInputService.InputChanged:Connect(function(input)
            if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - start
                frame.Position = UDim2.fromOffset(
                    math.clamp(origin.X + delta.X, 0, math.max(0, viewport.AbsoluteSize.X - frame.AbsoluteSize.X)),
                    math.clamp(origin.Y + delta.Y, 0, math.max(0, viewport.AbsoluteSize.Y - frame.AbsoluteSize.Y))
                )
            end
        end)
        frame.InputBegan:Connect(function(input)
            if dialogOpen then return end
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging, start = input, input.Position
                origin = frame.AbsolutePosition - viewport.AbsolutePosition
            end
        end)
        local ending = UserInputService.InputEnded:Connect(function(input)
            if input == dragging then dragging = nil end
        end)
        local focus = UserInputService.WindowFocusReleased:Connect(function() dragging = nil end)
        local overlay = { Frame = frame }
        function overlay:SetText(text) frame.Text = tostring(text) end
        function overlay:SetVisible(visible)
            frame.Visible = visible == true
            if not visible then dragging = nil end
        end
        function overlay:Destroy() frame:Destroy() end
        local heartbeat
        if config.Stats then
            local elapsed, frames = 0, 0
            heartbeat = game:GetService("RunService").RenderStepped:Connect(function(dt)
                if not frame.Visible then
                    elapsed, frames = 0, 0
                    return
                end
                elapsed, frames = elapsed + dt, frames + 1
                if elapsed >= 1 then
                    local ok, ping = pcall(
                        function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end
                    )
                    frame.Text = string.format(
                        "Viz | %d FPS | %s ms",
                        math.floor(frames / elapsed + 0.5),
                        ok and tostring(math.floor(ping + 0.5)) or "--"
                    )
                    elapsed, frames = 0, 0
                end
            end)
        end
        frame.Destroying:Connect(function()
            move:Disconnect()
            ending:Disconnect()
            focus:Disconnect()
            if heartbeat then heartbeat:Disconnect() end
        end)
        overlay:SetVisible(config.Visible ~= false)
        return overlay
    end

    local ThemeManager = { Current = "Default" }
    local defaultTheme = table.clone(Theme)
    ThemeManager.BuiltInThemes = {
        Default = {},
        Light = {
            Background = "F2F2F7",
            Card = "FFFFFF",
            Border = "D4D5DF",
            Text = "22232E",
        },
        Black = { Background = "010102", Card = "0C0C10", Border = "24242C", Text = "E8E8F0" },
        Mint = { Accent = "3DB488", Background = "1C1C1C", Card = "242424", Border = "373737" },
        Nord = {
            Accent = "88C0D0",
            Background = "2E3440",
            Card = "3B4252",
            Border = "4C566A",
            Text = "ECEFF4",
        },
        Dracula = {
            Accent = "FF79C6",
            Background = "282A36",
            Card = "44475A",
            Border = "6272A4",
            Text = "F8F8F2",
        },
    }
    function ThemeManager:Validate(data)
        if type(data) ~= "table" then return false, "Invalid theme" end
        data = table.clone(data)
        data.Profile = nil
        if data.ActiveIcon ~= nil then
            data.Icon = data.Icon or data.ActiveIcon
            data.ActiveIcon = nil
        end
        for role, color in pairs(data) do
            if role == "Font" then
                if type(color) ~= "string" or not fontChoices[color] then return false, "Unknown font" end
            elseif role == "BackgroundImage" then
                if
                    type(color) ~= "string"
                    or (#color > 0 and not color:match("^%d+$") and not color:match("^rbxassetid://%d+$"))
                then
                    return false, "Use a Roblox image asset ID"
                end
            elseif
                not defaultTheme[role]
                or not (typeof(color) == "Color3" or (type(color) == "string" and color:match("^%x%x%x%x%x%x$")))
            then
                return false, "Invalid theme color: " .. tostring(role)
            end
        end
        return true
    end
    function ThemeManager:ApplyThemeData(data, keepPopup)
        if type(data) == "table" then
            data = table.clone(data)
            data.Profile = nil
            if data.ActiveIcon ~= nil then
                data.Icon = data.Icon or data.ActiveIcon
                data.ActiveIcon = nil
            end
        end
        local valid, err = self:Validate(data)
        if not valid then return false, err end
        if not keepPopup then closeDropdown(true) end
        for animation in pairs(themeTweens) do
            animation:Cancel()
        end
        if keepPopup and openDropdown then openDropdown.Options.GroupTransparency = 0 end
        for role, color in pairs(data) do
            if defaultTheme[role] then Theme[role] = typeof(color) == "Color3" and color or Color3.fromHex(color) end
        end
        if data.Font then
            fontName = data.Font
            for object, medium in pairs(fontBindings) do
                if object.Parent then setUIFont(object, medium) end
            end
        end
        if data.BackgroundImage ~= nil then
            self.BackgroundImage = data.BackgroundImage
            backgroundImage.Image = data.BackgroundImage == "" and ""
                or (
                    data.BackgroundImage:match("^%d+$") and "rbxassetid://" .. data.BackgroundImage
                    or data.BackgroundImage
                )
            backgroundImage.Visible = data.BackgroundImage ~= ""
        end
        Theme.Header = Theme.Background
        if (data.Accent or data.Background or data.Card) and not data.Selected then
            Theme.Selected = Theme.Card:Lerp(Theme.Accent, 0.22)
            if contrast(Theme.Selected, Theme.Search) < 1.15 then
                Theme.Selected = Theme.Search:Lerp(Theme.Text, 0.14)
            end
        end
        refreshContrastColors()
        if not data.Hover then Theme.Hover = Theme.Card:Lerp(Theme.Accent, 0.16) end
        if not data.Pressed then Theme.Pressed = Theme.Card:Lerp(Theme.Accent, 0.3) end
        for object, bindings in pairs(themeBindings) do
            if object.Parent then
                for property, role in pairs(bindings) do
                    object[property] = Theme[role]
                end
            end
        end
        refreshGlass()
        if self.ColorControls then
            for role, picker in pairs(self.ColorControls) do
                picker:Set(Theme[role], 0, true)
            end
        end
        if self.FontControl then self.FontControl:Set(fontName, true) end
        if self.ImageControl then self.ImageControl.Text = self.BackgroundImage or "" end
        if self.ContrastLabel then
            local ratio = self:GetContrastRatio()
            self.ContrastLabel.Text =
                string.format("Text/card contrast: %s (%.1f:1)", ratio >= 4.5 and "good" or "low", ratio)
        end
        return true
    end
    function ThemeManager:GetContrastRatio()
        local function luminance(color)
            local function linear(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
            return 0.2126 * linear(color.R) + 0.7152 * linear(color.G) + 0.0722 * linear(color.B)
        end
        local a, b = luminance(Theme.Text), luminance(Theme.Card)
        return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
    end
    function ThemeManager:SyncPreset(name)
        if not self.PresetSelector then return end
        for _, entry in ipairs(self.PresetSelector.Entries) do
            if entry.Value == name then
                self.PresetSelector:Set(name, true)
                return
            end
        end
    end
    function ThemeManager:Export()
        local data = {}
        for role, color in pairs(Theme) do
            data[role] = color:ToHex()
        end
        data.Font, data.BackgroundImage = fontName, self.BackgroundImage or ""
        return data
    end

    local keybindMenu = addOverlay({ Name = "KeybindMenu", Text = "Keybinds", Visible = false })
    keybindMenu.Frame.Size = UDim2.fromOffset(280, 64)
    keybindMenu.Frame.Text = ""
    local keybindTitle = label(keybindMenu.Frame, "Keybinds", 13)
    keybindTitle.Position = UDim2.fromOffset(12, 0)
    keybindTitle.Size = UDim2.new(1, -24, 0, 32)
    setUIFont(keybindTitle, true)
    local keybindList = Instance.new("ScrollingFrame")
    keybindList.Name = "Entries"
    keybindList.Position = UDim2.fromOffset(8, 32)
    keybindList.Size = UDim2.new(1, -16, 1, -40)
    keybindList.BackgroundTransparency = 1
    keybindList.BorderSizePixel = 0
    keybindList.ScrollBarThickness = 0
    keybindList.CanvasSize = UDim2.fromOffset(0, 0)
    keybindList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    keybindList.Parent = keybindMenu.Frame
    local keybindLayout = Instance.new("UIListLayout")
    keybindLayout.Padding = UDim.new(0, 4)
    keybindLayout.SortOrder = Enum.SortOrder.LayoutOrder
    keybindLayout.Parent = keybindList
    keybindMenu.ShowToggleButtons = true
    refreshKeybindMenu = function()
        if not uiAlive or not keybindMenu.Frame.Parent then return end
        for _, child in ipairs(keybindList:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        local controls = {}
        for control in pairs(keybindControls) do
            table.insert(controls, control)
        end
        table.sort(controls, function(a, b) return a.Name < b.Name end)
        for index, control in ipairs(controls) do
            local row = rounded("Frame", control.Name, keybindList, 0, 0, 0, 26, "Search", 5)
            row.Size = UDim2.new(1, 0, 0, 26)
            row.LayoutOrder = index
            local name = label(row, control.Name, 12)
            name.Position = UDim2.fromOffset(7, 0)
            name.Size = UDim2.new(0.52, -7, 1, 0)
            name.TextTruncate = Enum.TextTruncate.AtEnd
            bindTheme(name, "TextColor3", control.Value and not control.Disabled and "Text" or "Muted")
            local keys = {}
            for _, modifier in ipairs({ "Ctrl", "Shift", "Alt" }) do
                if control.Modifiers[modifier] then table.insert(keys, modifier) end
            end
            table.insert(keys, control.Keybind == Enum.KeyCode.Unknown and "?" or control.Keybind.Name)
            local shortcut = label(row, table.concat(keys, "+"), 11)
            shortcut.Name = "Shortcut"
            shortcut.Position = UDim2.new(0.52, 0, 0, 0)
            shortcut.Size = UDim2.new(0.48, -32, 1, 0)
            shortcut.TextXAlignment = Enum.TextXAlignment.Right
            shortcut.TextTruncate = Enum.TextTruncate.AtEnd
            bindTheme(shortcut, "TextColor3", "Muted")
            local state =
                rounded("TextButton", "State", row, 0, 4, 18, 18, control.Value and "Accent" or "Navigation", 4)
            state.Position = UDim2.new(1, -23, 0, 4)
            local check = icon(state, "check", 2, 2, 14, "OnAccent")
            check.Visible = control.Value
            state.Interactable = control.KeybindMode == "Toggle"
                and not control.Disabled
                and keybindMenu.ShowToggleButtons
            state.Visible = control.KeybindMode ~= "Toggle" or keybindMenu.ShowToggleButtons
            state.Activated:Connect(function()
                if not dialogOpen and state.Interactable then control:Set(not control.Value) end
            end)
        end
        if #controls == 0 then
            local empty = label(keybindList, "No keybinds", 12)
            empty.Size = UDim2.new(1, 0, 0, 26)
            bindTheme(empty, "TextColor3", "Muted")
        end
        keybindMenu.Frame.Size = UDim2.fromOffset(280, 40 + math.min(206, math.max(26, #controls * 30 - 4)))
    end
    function keybindMenu:SetShowToggleButtons(enabled)
        self.ShowToggleButtons = enabled == true
        refreshKeybindMenu()
    end
    refreshKeybindMenu()
    local profile = rounded("ImageLabel", "Profile", sidebar, 0, 0, 40, 40, Color3.fromRGB(114, 105, 133), 20)
    profile.AnchorPoint = Vector2.new(1, 0.5)
    profile.Position = UDim2.new(1, -12, 0.5, 0)
    profile.ClipsDescendants = true
    local profileRim = Instance.new("UIStroke")
    profileRim.Color = Color3.fromRGB(239, 228, 255)
    profileRim.Transparency = 0.68
    profileRim.Thickness = 1
    profileRim.Parent = profile
    task.spawn(function()
        local ok, thumbnail = pcall(
            function()
                return Players:GetUserThumbnailAsync(
                    player.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size100x100
                )
            end
        )
        if ok and profile.Parent then profile.Image = thumbnail end
    end)

    local dockHost = Instance.new("Frame")
    dockHost.Name = "BottomBar"
    dockHost.AnchorPoint = Vector2.new(0.5, 1)
    dockHost.Position = UDim2.new(0.5, 0, 1, 76)
    dockHost.Size = UDim2.fromOffset(180, 64)
    dockHost.BackgroundTransparency = 1
    dockHost.Visible = false
    dockHost.ZIndex = 20
    dockHost.Parent = viewport
    local dockScale = Instance.new("UIScale")
    dockScale.Parent = dockHost
    local dockGlass = rounded("Frame", "DockGlass", dockHost, 0, 0, 0, 0, "Background", 22)
    dockGlass.Size = UDim2.fromScale(1, 1)
    dockGlass.BackgroundTransparency = 0.08
    local dockRim = Instance.new("UIStroke")
    bindTheme(dockRim, "Color", "Text")
    dockRim.Transparency = 0.92
    dockRim.Thickness = 1
    dockRim.Parent = dockGlass
    local dockDivider = rounded("Frame", "ProfileDivider", dockGlass, 0, 16, 1, 32, "Text", 1)
    dockDivider.Position = UDim2.new(1, -62, 0, 16)
    dockDivider.BackgroundTransparency = 0.9
    local dockReveal = rounded("TextButton", "RevealBottomBar", viewport, 0, 0, 104, 20, "Background", 6)
    dockReveal.BackgroundTransparency = 1
    dockReveal.AnchorPoint = Vector2.new(0.5, 1)
    dockReveal.Position = UDim2.new(0.5, 0, 1, -2)
    dockReveal.ZIndex = 21
    dockReveal.Visible = false
    local grip = rounded("Frame", "Grip", dockReveal, 0, 0, 80, 4, "Text", 2)
    grip.BackgroundTransparency = 0.55
    grip.AnchorPoint = Vector2.new(0.5, 0.5)
    grip.Position = UDim2.fromScale(0.5, 0.5)
    local dockAutoHide, dockExpanded, dockHoverUntil = false, false, 0
    local dockProgress, dockVelocity, dockFitScale = 0, 0, 1
    local revealHover, revealHoverAmount = false, 0
    local function renderDock()
        local progress = math.clamp(dockProgress, 0, 1)
        dockHost.AnchorPoint = Vector2.new(0.5, 1)
        dockHost.Position = UDim2.new(0.5, 0, 1, 76 - 90 * dockProgress)
        dockScale.Scale = dockFitScale * (0.94 + 0.06 * dockProgress)
        dockGlass.BackgroundTransparency = (0.08 + (1 - progress) * 0.22) * glassOpacityFactor
        dockRim.Transparency = 0.92 + (1 - progress) * 0.08
        local reveal = dockAutoHide and (1 - progress) or 0
        dockReveal.Visible = reveal > 0.005
        dockReveal.Interactable = not dockExpanded and reveal > 0.2
        dockReveal.AnchorPoint = Vector2.new(0.5, 1)
        dockReveal.Position = UDim2.new(0.5, 0, 1, -2 + 6 * progress)
        grip.Size = UDim2.fromOffset((80 + 8 * revealHoverAmount) * (0.86 + 0.14 * reveal), 4)
        grip.BackgroundTransparency = 1 - reveal * (0.45 + 0.12 * revealHoverAmount)
    end
    local function showDock(expanded, immediate)
        dockExpanded = expanded
        if immediate then
            dockProgress, dockVelocity = expanded and 1 or 0, 0
        end
        renderDock()
    end
    refreshDockLayout = function()
        for _, tab in ipairs(tabs) do
            tab.Button.Size = UDim2.fromOffset(44, 44)
            tab.Icon.Position = UDim2.fromOffset(11, 11)
            tab.Icon.Size = UDim2.fromOffset(22, 22)
            tab.Title.Visible = false
        end
        local width = math.min(76 + #tabs * 52, math.max(128, viewport.AbsoluteSize.X - 24))
        dockHost.Size = UDim2.fromOffset(width, 64)
        dockFitScale = math.min(1, math.max(0.1, (viewport.AbsoluteSize.X - 24) / width))
        renderDock()
        sidebar.Size = UDim2.fromScale(1, 1)
        navigationGroup.Position = UDim2.fromOffset(8, 6)
        navigationGroup.Size = UDim2.new(1, -72, 0, 52)
        navigationPadding.PaddingTop = UDim.new(0, 4)
        navigationPadding.PaddingBottom = UDim.new(0, 4)
        navigationPadding.PaddingLeft = UDim.new(0, 4)
        navigationPadding.PaddingRight = UDim.new(0, 4)
    end
    local function setLayoutStyle(value)
        assert(value == "Bottom bar", "Viz only supports Bottom bar")
        finishUIVisibility()
        cancelKeyCapture()
        closeDropdown(true)
        finishSlider()
        finishColorDrag()
        cancelWindowDrag()
        cancelWindowResize()
        sidebar.Parent = dockHost
        sidebar.Position = UDim2.fromOffset(0, 0)
        sidebar.Active = false
        navigationLayout.Padding = UDim.new(0, 8)
        navigationLayout.FillDirection = Enum.FillDirection.Horizontal
        navigationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        navigationLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        navigationGroup.CanvasPosition = Vector2.zero
        navigationGroup.CanvasSize = UDim2.fromOffset(0, 0)
        navigationGroup.AutomaticCanvasSize = Enum.AutomaticSize.X
        navigationGroup.ScrollingDirection = Enum.ScrollingDirection.X
        root.Size = UDim2.fromOffset(windowContentSize.X, windowContentSize.Y)
        body.Position = UDim2.fromOffset(0, 0)
        header.Position = UDim2.fromOffset(0, 0)
        body.Size = UDim2.fromScale(1, 1)
        header.Size = UDim2.new(1, 0, 0, 54)
        dockHost.Visible = true
        refreshDockLayout()
        resize()
        dockHoverUntil = os.clock() + 1.2
        showDock(true, true)
    end
    do
        -- Spring-driven open/close: progress 0 = tucked into the dock, 1 = resting at home.
        -- Reversing mid-flight keeps the current velocity, so rapid toggles never snap.
        local home, savedPosition
        local progress, velocity, target = 1, 0, 1
        local minimumScale, hostPadding = 0.14, 12
        local function landingPoint()
            local center = 14 + 32 * dockFitScale
            return Vector2.new(viewport.AbsoluteSize.X / 2, viewport.AbsoluteSize.Y - center)
        end
        local function smoothstep(value)
            value = math.clamp(value, 0, 1)
            return value * value * (3 - 2 * value)
        end
        local function render()
            local clamped = math.clamp(progress, 0, 1)
            -- Position leads the scale so the window looks like it lifts out of the dock.
            local travel = 1 - (1 - clamped) ^ 3
            local point = landingPoint():Lerp(home, travel)
            local size = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset) * scale.Scale
            windowMotionHost.Size = UDim2.fromOffset(size.X + hostPadding * 2, size.Y + hostPadding * 2)
            windowMotionHost.Position = UDim2.fromOffset(point.X, point.Y)
            windowMotionScale.Scale = math.max(0.01, minimumScale + (1 - minimumScale) * progress)
            windowMotionHost.GroupTransparency = 1 - smoothstep(clamped / 0.6)
        end
        finishUIVisibility = function()
            if windowTransitioning then
                root.Parent = viewport
                root.Position = savedPosition
                windowMotionScale.Scale = 1
                windowMotionHost.GroupTransparency = 0
                windowMotionHost.Visible = false
                windowTransitioning = false
                home, savedPosition = nil, nil
            end
            progress, velocity, target = uiShown and 1 or 0, 0, uiShown and 1 or 0
            root.Visible = uiShown
            resize()
        end
        animateUIVisibility = function(visible)
            if not windowTransitioning then
                savedPosition = root.Position
                home = Vector2.new(
                    root.Position.X.Scale * viewport.AbsoluteSize.X + root.Position.X.Offset,
                    root.Position.Y.Scale * viewport.AbsoluteSize.Y + root.Position.Y.Offset
                )
                progress, velocity = visible and 0 or 1, 0
                windowTransitioning = true
                root.Parent = windowMotionHost
                root.Position = UDim2.fromScale(0.5, 0.5)
                windowMotionHost.Visible = true
            end
            target = visible and 1 or 0
            root.Visible = true
            dockHoverUntil = os.clock() + 1.2
            showDock(true)
            render()
        end
        track(game:GetService("RunService").RenderStepped:Connect(function(dt)
            if not windowTransitioning then return end
            dt = math.min(dt, 1 / 30)
            -- Opening settles with a slight overshoot; closing is near-critically damped and quicker.
            local omega, damping = 17, 0.72
            if target == 0 then omega, damping = 22, 0.95 end
            local frequency = omega * math.sqrt(1 - damping * damping)
            local offset = progress - target
            local coefficient = (velocity + damping * omega * offset) / frequency
            local decay = math.exp(-damping * omega * dt)
            local cosine, sine = math.cos(frequency * dt), math.sin(frequency * dt)
            local wave = offset * cosine + coefficient * sine
            progress = target + decay * wave
            velocity = decay * (-damping * omega * wave + frequency * (-offset * sine + coefficient * cosine))
            local settled = math.abs(progress - target) < 0.002 and math.abs(velocity) < 0.02
            if settled or (target == 0 and progress < 0.015) then
                finishUIVisibility()
                return
            end
            render()
        end))
        track(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(finishUIVisibility))
    end
    local function setDockAutoHide(value)
        dockAutoHide = value == true
        showDock(not dockAutoHide)
    end
    dockReveal.Activated:Connect(function()
        dockHoverUntil = os.clock() + 2
        showDock(true)
    end)
    dockReveal.MouseEnter:Connect(function() revealHover = true end)
    dockReveal.MouseLeave:Connect(function() revealHover = false end)
    track(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshDockLayout))
    local function updateDockHover(mouse, now)
        if not dockAutoHide then return end
        local half = dockExpanded and (dockHost.AbsoluteSize.X / 2 + 12) or 56
        local near = math.abs(mouse.X - viewport.AbsoluteSize.X / 2) <= half
            and mouse.Y >= viewport.AbsoluteSize.Y - (dockExpanded and 96 or 18)
            and mouse.Y <= viewport.AbsoluteSize.Y + 2
        if near then dockHoverUntil = now + 0.65 end
        local expanded = near or now < dockHoverUntil
        if expanded ~= dockExpanded then showDock(expanded) end
    end
    track(game:GetService("RunService").RenderStepped:Connect(function(dt)
        updateDockHover(
            UserInputService:GetMouseLocation()
                - game:GetService("GuiService"):GetGuiInset()
                - viewport.AbsolutePosition,
            os.clock()
        )
        local target = dockExpanded and 1 or 0
        local omega, damping = 18, 0.86
        local frequency = omega * math.sqrt(1 - damping * damping)
        local offset = dockProgress - target
        local coefficient = (dockVelocity + damping * omega * offset) / frequency
        local decay = math.exp(-damping * omega * dt)
        local cosine, sine = math.cos(frequency * dt), math.sin(frequency * dt)
        local wave = offset * cosine + coefficient * sine
        dockProgress = target + decay * wave
        dockVelocity = decay * (-damping * omega * wave + frequency * (-offset * sine + coefficient * cosine))
        if math.abs(dockProgress - target) < 0.0005 and math.abs(dockVelocity) < 0.005 then
            dockProgress, dockVelocity = target, 0
        end
        revealHoverAmount = revealHoverAmount
            + ((revealHover and 1 or 0) - revealHoverAmount) * (1 - math.exp(-16 * dt))
        renderDock()
    end))
    local dragInput, dragStart, windowStart, dragTarget, dragRendered
    cancelWindowDrag = function()
        dragInput, dragTarget, dragRendered = nil, nil, nil
    end
    local function windowAnchor()
        local size = viewport.AbsoluteSize
        return Vector2.new(
            root.Position.X.Scale * size.X + root.Position.X.Offset,
            root.Position.Y.Scale * size.Y + root.Position.Y.Offset
        )
    end
    local function clampWindow(position)
        local available = viewport.AbsoluteSize
        local size = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset) * scale.Scale
        local low = Vector2.new(size.X * root.AnchorPoint.X, size.Y * root.AnchorPoint.Y)
        local high = Vector2.new(
            math.max(low.X, available.X - size.X * (1 - root.AnchorPoint.X)),
            math.max(low.Y, available.Y - size.Y * (1 - root.AnchorPoint.Y))
        )
        return Vector2.new(math.clamp(position.X, low.X, high.X), math.clamp(position.Y, low.Y, high.Y))
    end
    local function inside(point, object)
        local p, size = object.AbsolutePosition, object.AbsoluteSize
        return point.X >= p.X and point.X <= p.X + size.X and point.Y >= p.Y and point.Y <= p.Y + size.Y
    end
    local resizeHandle
    local function beginDrag(input, hit)
        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        if inside(input.Position, dockHost) then return end
        if
            windowTransitioning
            or dragInput
            or root:GetAttribute("Resizing")
            or dialogOpen
            or activeSlider
            or activeColorDrag
            or UserInputService:GetFocusedTextBox()
        then
            return
        end
        if not windowDragAllowed(hit, root, input.UserInputType == Enum.UserInputType.Touch) then return end
        closeDropdown(true)
        dragInput = input
        dragStart = Vector2.new(input.Position.X, input.Position.Y)
        windowStart = windowAnchor()
        dragTarget = windowStart
        dragRendered = windowStart
    end
    body.Active = true
    sidebar.Active = false
    header.Active = true
    bindDragStart(root, beginDrag)
    local function moveDrag(input)
        if not dragInput then return end
        local mouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        if input ~= dragInput and not mouse then return end
        local pointer = Vector2.new(input.Position.X, input.Position.Y)
        dragTarget = clampWindow(windowStart + pointer - dragStart)
    end
    local moveConnection = UserInputService.InputChanged:Connect(moveDrag)
    local dragFrameConnection = game:GetService("RunService").RenderStepped:Connect(function(dt)
        if not dragTarget then return end
        local current = dragRendered or windowAnchor()
        dragTarget = clampWindow(dragTarget)
        local nextPosition = current:Lerp(dragTarget, 1 - math.exp(-32 * math.min(dt, 0.1)))
        if (nextPosition - dragTarget).Magnitude < 0.2 then
            nextPosition = dragTarget
            if not dragInput then dragTarget = nil end
        end
        dragRendered = nextPosition
        root.Position = UDim2.fromOffset(math.floor(nextPosition.X + 0.5), math.floor(nextPosition.Y + 0.5))
    end)
    local endConnection = UserInputService.InputEnded:Connect(function(input)
        if input == dragInput then dragInput = nil end
    end)
    local focusConnection = UserInputService.WindowFocusReleased:Connect(function()
        dragInput, dragTarget, dragRendered = nil, nil, nil
    end)
    local dragResizeConnection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if root.Position.X.Scale == 0 and root.Position.Y.Scale == 0 then
            dragInput = nil
            dragRendered = windowAnchor()
            dragTarget = clampWindow(dragRendered)
        end
    end)
    screen.Destroying:Connect(function()
        dragInput, dragTarget, dragRendered = nil, nil, nil
        moveConnection:Disconnect()
        dragFrameConnection:Disconnect()
        endConnection:Disconnect()
        focusConnection:Disconnect()
        dragResizeConnection:Disconnect()
    end)

    local function setWindowSize(size)
        assert(typeof(size) == "Vector2", "Window size expects Vector2")
        local sidebarWidth = 0
        windowContentSize = Vector2.new(math.clamp(size.X - sidebarWidth, 420, 1600), math.clamp(size.Y, 320, 1000))
        root.Size = UDim2.fromOffset(windowContentSize.X + sidebarWidth, windowContentSize.Y)
        resize()
        if root.Position.X.Scale == 0 and root.Position.Y.Scale == 0 then
            local position = clampWindow(windowAnchor())
            root.Position = UDim2.fromOffset(position.X, position.Y)
        end
    end
    do
        resizeHandle = rounded("TextButton", "ResizeWindow", root, 0, 0, 22, 22, "Background", 6)
        resizeHandle.AnchorPoint = Vector2.new(1, 1)
        resizeHandle.Position = UDim2.new(1, -3, 1, -3)
        resizeHandle.BackgroundTransparency = 1
        resizeHandle.ZIndex = 10
        local image = icon(resizeHandle, "arrow-left-right", 5, 5, 12, "Muted")
        image.Rotation = 45
        addTooltip(resizeHandle, "Drag to resize the window")
        local input, pointerStart, initialSize, initialScale, topLeft, target
        cancelWindowResize = function()
            input, target = nil, nil
            root:SetAttribute("Resizing", false)
        end
        resizeHandle.InputBegan:Connect(function(event)
            if
                windowTransitioning
                or dialogOpen
                or input
                or (
                    event.UserInputType ~= Enum.UserInputType.MouseButton1
                    and event.UserInputType ~= Enum.UserInputType.Touch
                )
            then
                return
            end
            cancelWindowDrag()
            cancelKeyCapture()
            closeDropdown(true)
            finishSlider()
            finishColorDrag()
            input = event
            root:SetAttribute("Resizing", true)
            pointerStart = Vector2.new(event.Position.X, event.Position.Y)
            initialSize = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset)
            initialScale = scale.Scale
            topLeft = root.AbsolutePosition - viewport.AbsolutePosition
            target = initialSize
        end)
        track(UserInputService.InputChanged:Connect(function(event)
            if not input then return end
            local mouse = input.UserInputType == Enum.UserInputType.MouseButton1
                and event.UserInputType == Enum.UserInputType.MouseMovement
            if event ~= input and not mouse then return end
            local delta = (Vector2.new(event.Position.X, event.Position.Y) - pointerStart) / initialScale
            local minimumWidth = 420
            local available = viewport.AbsoluteSize
            local maxWidth = math.max(minimumWidth, math.min(1600, (available.X - topLeft.X - 16) / initialScale))
            local maxHeight = math.max(320, math.min(1000, (available.Y - topLeft.Y - 16) / initialScale))
            target = Vector2.new(
                math.clamp(initialSize.X + delta.X, minimumWidth, maxWidth),
                math.clamp(initialSize.Y + delta.Y, 320, maxHeight)
            )
        end))
        track(game:GetService("RunService").RenderStepped:Connect(function(dt)
            if not target then return end
            if dialogOpen or not root.Visible then
                cancelWindowResize()
                return
            end
            local current = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset)
            local nextSize = current:Lerp(target, 1 - math.exp(-32 * dt))
            if (nextSize - target).Magnitude < 0.5 then
                nextSize = target
                if not input then
                    target = nil
                    root:SetAttribute("Resizing", false)
                end
            end
            setWindowSize(nextSize)
            local center = clampWindow(topLeft + Vector2.new(root.Size.X.Offset, root.Size.Y.Offset) * scale.Scale / 2)
            root.Position = UDim2.fromOffset(center.X, center.Y)
        end))
        track(UserInputService.InputEnded:Connect(function(event)
            if event == input then input = nil end
        end))
        track(UserInputService.WindowFocusReleased:Connect(cancelWindowResize))
        track(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(cancelWindowResize))
    end

    local autoHideControl, keybindListControl, settingsTab
    menuKeybind = { Keybind = config.MenuKey or Enum.KeyCode.RightShift, Modifiers = {} }
    function menuKeybind:RefreshKeybind() end
    function menuKeybind:SetModifiers(value)
        self.Modifiers = {}
        for name in pairs(modifierKeys) do
            if value[name] == true then self.Modifiers[name] = true end
        end
    end
    function menuKeybind:SetKeybind(key)
        if type(key) == "string" then key = Enum.KeyCode[key] end
        assert(typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode, "Invalid menu key")
        self.Keybind = key
    end
    menuKeybind:SetKeybind(menuKeybind.Keybind)
    registerControl(
        "ui_menu_keybind",
        "Keybind",
        root,
        function() return { Keybind = menuKeybind.Keybind.Name, Modifiers = table.clone(menuKeybind.Modifiers) } end,
        function(value)
            menuKeybind:SetModifiers(value.Modifiers or {})
            menuKeybind:SetKeybind(value.Keybind)
        end,
        function(value)
            if type(value) ~= "table" or type(value.Keybind) ~= "string" then return false end
            local ok, key = pcall(function() return Enum.KeyCode[value.Keybind] end)
            if not ok or not key then return false end
            if value.Modifiers ~= nil then
                if type(value.Modifiers) ~= "table" then return false end
                for name, enabled in pairs(value.Modifiers) do
                    if not modifierKeys[name] or type(enabled) ~= "boolean" then return false end
                end
            end
            return true
        end
    )
    local function applyStyle(value) setLayoutStyle("Bottom bar") end
    local function applyAutoHide(value)
        setDockAutoHide(value)
        if autoHideControl then autoHideControl:Set(value, true) end
    end
    local function applyKeybindList(value)
        keybindMenu:SetVisible(value)
        if keybindListControl then keybindListControl:Set(value, true) end
    end
    registerControl(
        "ui_layout_style",
        "Dropdown",
        root,
        function() return layoutStyle end,
        applyStyle,
        function(value) return value == "Normal" or value == "Top bar" or value == "Bottom bar" end
    )
    registerControl(
        "ui_dock_autohide",
        "Checkbox",
        root,
        function() return dockAutoHide end,
        applyAutoHide,
        function(value) return type(value) == "boolean" end
    )
    registerControl(
        "ui_stats",
        "Checkbox",
        root,
        function() return keybindMenu.Frame.Visible end,
        applyKeybindList,
        function(value) return type(value) == "boolean" end
    )
    applyStyle("Bottom bar")
    applyAutoHide(config.AutoHide == true)
    if config.Size then
        assert(typeof(config.Size) == "Vector2", "Window Size expects Vector2")
        setWindowSize(config.Size)
    end
    local title = label(header, config.Title or "Viz", 13)
    setUIFont(title, true)
    title.Position = UDim2.fromOffset(54, 0)
    title.Size = UDim2.new(0, 118, 1, 0)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Visible = false

    local window = {
        Version = Library.Version,
        Screen = screen,
        Window = root,
        Header = header,
        Body = body,
        Sidebar = sidebar,
        Logo = logo,
        Title = title,
        Search = globalSearch,
        Tabs = tabs,
        Options = Options,
        Toggles = Toggles,
        Theme = Theme,
        Navigation = navigation,
        NavigationBar = dockHost,
        BottomBar = dockHost,
        Profile = profile,
        KeybindMenu = keybindMenu,
        KeybindFrame = keybindMenu.Frame,
        MenuKeybind = menuKeybind,
        _Viz = {
            Registry = controlRegistry,
            Theme = ThemeManager,
            Defaults = defaultTheme,
            Storage = Library._Storage,
            ExportTheme = function() return ThemeManager:Export() end,
            GetFont = function() return fontName end,
            SetLoading = function(value) loadingConfig = value end,
            CancelInteractions = function()
                cancelKeyCapture()
                closeDropdown(true)
                finishSlider()
                finishColorDrag()
                releaseHolds()
                cancelWindowDrag()
                cancelWindowResize()
                finishUIVisibility()
            end,
            IsAlive = function() return uiAlive end,
        },
    }
    function window:AddTab(name, iconName)
        return addTab(type(name) == "table" and name or { Name = name, Icon = iconName })
    end
    function window:SelectTab(tab) selectTab(tab) end
    function window:SetSearch(text) globalSearch.Text = tostring(text or "") end
    function window:SetSize(size)
        finishUIVisibility()
        cancelWindowDrag()
        cancelWindowResize()
        closeDropdown(true)
        setWindowSize(size)
    end
    function window:SetVisible(value) setUIVisible(value) end
    function window:IsVisible() return uiShown end
    function window:Toggle() setUIVisible(not uiShown) end
    function window:SetStyle(value)
        assert(value == "Bottom bar", "Viz only supports Bottom bar")
        applyStyle(value)
    end
    function window:GetStyle() return layoutStyle end
    function window:SetAutoHide(value) applyAutoHide(value == true) end
    function window:SetTitle(text) title.Text = tostring(text) end
    function window:Notify(options) return notify(options) end
    function window:Dialog(options) return showDialog(options) end
    function window:AddOverlay(options) return addOverlay(options) end
    function window:AddTooltip(object, text, disabledText) return addTooltip(object, text, disabledText) end
    function window:CreateSettingsTab(name)
        if settingsTab then return settingsTab end
        settingsTab = addTab({ Name = name or "Settings", Icon = "settings" })
        local group = settingsTab:AddLeftGroupbox("Interface", "settings")
        keybindListControl = group:AddCheckbox({
            Name = "Keybind Menu",
            Default = keybindMenu.Frame.Visible,
            NoSave = true,
            Callback = applyKeybindList,
        })
        local previous = menuKeybind
        menuKeybind = group:AddKeybind({ Name = "Menu keybind", Default = previous.Keybind, NoSave = true })
        menuKeybind:SetModifiers(previous.Modifiers)
        self.MenuKeybind = menuKeybind
        return settingsTab
    end
    function window:AddStyleControls(section)
        if autoHideControl then return end
        autoHideControl = section:AddCheckbox({
            Name = "Auto-hide bar",
            Default = dockAutoHide,
            NoSave = true,
            Callback = applyAutoHide,
        })
    end
    function window:Destroy()
        if uiAlive then screen:Destroy() end
        table.clear(Options)
        table.clear(Toggles)
    end
    self.Window = window
    self.Options, self.Toggles = Options, Toggles
    return window
end

function Library:Unload()
    if self.Window then
        self.Window:Destroy()
        self.Window = nil
    end
end

return Library
