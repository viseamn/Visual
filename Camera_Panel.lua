-- Camera panel: toggle-gated sliders for the 0118 menu.
-- Drop into the Client tab. Every slider row stays hidden until its toggle is on.

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Player = Players.LocalPlayer
local Connections_Manager = {}

-- Hides a whole option row. The search filter reads the same attribute, so a
-- hidden row stays hidden when the user types in the search box.
local function Row_Visible(Row, On)
    if not Row then return end
    Row:SetAttribute('UserVisible', On == true)
    Row.Visible = On == true
end

-- Toggle row plus slider row. The slider row is the last element the group
-- added, so it is reachable through Group.Elements without touching the library.
local function Add_Toggle_Slider(Group, Id, Opt)
    local Slider, Sync
    local Toggle = Group:AddToggle(Id .. '_Toggle', {
        Text = Opt.ToggleText or Opt.Text,
        Default = Opt.ToggleDefault == true,
        Callback = function(On)
            if Sync then Sync() end
            if Opt.OnToggle then Opt.OnToggle(On) end
        end
    })
    Slider = Group:AddSlider(Id .. '_Slider', {
        Text = Opt.Text,
        Default = Opt.Default,
        Min = Opt.Min,
        Max = Opt.Max,
        Increment = Opt.Increment,
        Suffix = Opt.Suffix,
        Callback = function(Value)
            if Opt.OnChange then Opt.OnChange(Value) end
        end
    })
    local Row = Group.Elements and Group.Elements[#Group.Elements]
    Sync = function() Row_Visible(Row, Toggle.Value == true) end
    Sync()
    return Toggle, Slider
end

local function Build_Camera_Panel(Camera_Group)
    local MaxZoom = 75
    local Unlock_Toggle

    local function ApplyCameraSettings()
        Player.CameraMode = Enum.CameraMode.Classic
        Player.CameraMinZoomDistance = 0.5
        Player.CameraMaxZoomDistance = (Unlock_Toggle and Unlock_Toggle.Value) and MaxZoom or 70
    end

    Unlock_Toggle = Add_Toggle_Slider(Camera_Group, 'Camera_Unlock', {
        Text = 'Max Zoom Distance',
        ToggleText = 'Unlock Camera',
        ToggleDefault = true,
        Default = 75,
        Min = 5,
        Max = 200,
        Increment = 1,
        OnToggle = function() ApplyCameraSettings() end,
        OnChange = function(Value)
            MaxZoom = Value
            if Unlock_Toggle and Unlock_Toggle.Value then ApplyCameraSettings() end
        end
    })

    ApplyCameraSettings()

    local Stretch_Value = 1

    local function Stretch_Stop()
        if Connections_Manager['Stretch_Screen'] then
            Connections_Manager['Stretch_Screen']:Disconnect()
            Connections_Manager['Stretch_Screen'] = nil
        end
    end

    local function Stretch_Start()
        if Connections_Manager['Stretch_Screen'] then return end
        Connections_Manager['Stretch_Screen'] = RunService.RenderStepped:Connect(function()
            local cam = workspace.CurrentCamera
            if not cam then return end
            cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, Stretch_Value, 0, 0, 0, 1)
        end)
    end

    Add_Toggle_Slider(Camera_Group, 'Stretch_Screen', {
        Text = 'Stretch Value',
        ToggleText = 'Stretch Screen',
        ToggleDefault = false,
        Default = 1,
        Min = 0.1,
        Max = 1,
        Increment = 0.01,
        OnToggle = function(On)
            if On then Stretch_Start() else Stretch_Stop() end
        end,
        OnChange = function(Value)
            Stretch_Value = Value
        end
    })

    local FOV_Toggle, FOV_Slider
    local FOV_Original = nil

    local function Restore_FOV()
        if FOV_Original ~= nil then
            workspace.CurrentCamera.FieldOfView = FOV_Original
            FOV_Original = nil
        end
    end
    getgenv()._Restore_FOV = Restore_FOV

    FOV_Toggle, FOV_Slider = Add_Toggle_Slider(Camera_Group, 'FOV', {
        Text = 'FOV',
        ToggleText = 'FOV',
        ToggleDefault = false,
        Default = 70,
        Min = 70,
        Max = 120,
        Increment = 1,
        OnToggle = function(On)
            if On then
                if FOV_Original == nil then
                    FOV_Original = workspace.CurrentCamera.FieldOfView
                end
                workspace.CurrentCamera.FieldOfView = FOV_Slider and FOV_Slider.Value or 70
            else
                Restore_FOV()
            end
        end,
        OnChange = function(Value)
            if FOV_Toggle and FOV_Toggle.Value then
                workspace.CurrentCamera.FieldOfView = Value
            end
        end
    })
end

return Build_Camera_Panel
