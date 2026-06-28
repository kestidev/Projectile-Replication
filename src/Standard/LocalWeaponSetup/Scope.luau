--!strict

local DEFAULT_MOUSE_SENSITIVITY = 0.3
local DEFAULT_GAMEPAD_SENSITIVITY = 120
local DEFAULT_TOUCH_SENSITIVITY = 0.3
local GAMEPAD_DEADZONE = 0.15
local MIN_PITCH = math.rad(-75)
local MAX_PITCH = math.rad(75)
local AIM_DISTANCE = 10000
local POSITION_SMOOTHING = 20
local RENDER_BIND_NAME = "ProjectileReplicationScope"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Types = require(script.Parent.Parent.Parent:WaitForChild("Types"))

local Scope = {}
Scope.__index = Scope

export type Scope = {
    ScopeAttachment: Attachment,
    Configuration: Types.StandardConfiguration,
    Scoped: boolean,
    Yaw: number,
    Pitch: number,
    GamepadLook: Vector2,
    TouchLookDelta: Vector2,
    Events: {RBXScriptConnection},
    OriginalFieldOfView: number?,
    OriginalCameraType: Enum.CameraType?,
    LastCameraCFrame: CFrame?,
} & typeof(setmetatable({}, Scope))



function Scope.new(ScopeAttachment: Attachment, Configuration: Types.StandardConfiguration): Scope
    return setmetatable({
        ScopeAttachment = ScopeAttachment,
        Configuration = Configuration,
        Scoped = false,
        Yaw = 0,
        Pitch = 0,
        GamepadLook = Vector2.zero,
        TouchLookDelta = Vector2.zero,
        Events = {},
    }, Scope) :: Scope
end

function Scope.IsScoped(self: Scope): boolean
    return self.Scoped
end

function Scope.GetAimPosition(self: Scope): Vector3?
    if not self.Scoped then return nil end
    local Character = Players.LocalPlayer.Character
    if not Character then return nil end
    local Head = Character:FindFirstChild("Head") :: BasePart?
    if not Head then return nil end
    local Direction = (CFrame.Angles(0, self.Yaw, 0) * CFrame.Angles(self.Pitch, 0, 0)).LookVector
    return Head.Position + (Direction * AIM_DISTANCE)
end

function Scope.Start(self: Scope): ()
    if self.Scoped then return end
    local Camera = Workspace.CurrentCamera
    if not Camera then return end
    self.Scoped = true

    self.OriginalFieldOfView = Camera.FieldOfView
    self.OriginalCameraType = Camera.CameraType
    self.LastCameraCFrame = Camera.CFrame

    local LookVector = Camera.CFrame.LookVector
    self.Yaw = math.atan2(-LookVector.X, -LookVector.Z)
    self.Pitch = math.asin(math.clamp(LookVector.Y, -1, 1))

    Camera.CameraType = Enum.CameraType.Scriptable
    if self.Configuration.ScopeFieldOfView then
        Camera.FieldOfView = self.Configuration.ScopeFieldOfView
    end

    table.insert(self.Events, UserInputService.InputChanged:Connect(function(Input)
        if Input.KeyCode == Enum.KeyCode.Thumbstick2 then
            local StickPosition = Vector2.new(Input.Position.X, Input.Position.Y)
            self.GamepadLook = (StickPosition.Magnitude >= GAMEPAD_DEADZONE) and StickPosition or Vector2.zero
        elseif Input.UserInputType == Enum.UserInputType.Touch then
            self.TouchLookDelta += Vector2.new(Input.Delta.X, Input.Delta.Y)
        end
    end))

    RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(DeltaTime)
        self:Update(DeltaTime)
    end)
end

function Scope.Update(self: Scope, DeltaTime: number): ()
    if not self.Scoped then return end
    local Camera = Workspace.CurrentCamera
    local Character = Players.LocalPlayer.Character
    local ScopeAttachment = self.ScopeAttachment
    if not Camera or not Character or not ScopeAttachment.Parent then return end

    if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end

    local MouseDelta = UserInputService:GetMouseDelta()
    local MouseSensitivity = math.rad(self.Configuration.ScopeMouseSensitivity or DEFAULT_MOUSE_SENSITIVITY)
    self.Yaw -= MouseDelta.X * MouseSensitivity
    self.Pitch -= MouseDelta.Y * MouseSensitivity

    if self.GamepadLook.Magnitude > 0 then
        local GamepadSensitivity = math.rad(self.Configuration.ScopeGamepadSensitivity or DEFAULT_GAMEPAD_SENSITIVITY)
        self.Yaw -= self.GamepadLook.X * GamepadSensitivity * DeltaTime
        self.Pitch += self.GamepadLook.Y * GamepadSensitivity * DeltaTime
    end

    if self.TouchLookDelta.Magnitude > 0 then
        local TouchSensitivity = math.rad(self.Configuration.ScopeTouchSensitivity or DEFAULT_TOUCH_SENSITIVITY)
        self.Yaw -= self.TouchLookDelta.X * TouchSensitivity
        self.Pitch -= self.TouchLookDelta.Y * TouchSensitivity
        self.TouchLookDelta = Vector2.zero
    end
    self.Pitch = math.clamp(self.Pitch, MIN_PITCH, MAX_PITCH)

    local TargetCFrame = CFrame.new(ScopeAttachment.WorldPosition) * CFrame.Angles(0, self.Yaw, 0) * CFrame.Angles(self.Pitch, 0, 0)

    local CurrentCFrame = self.LastCameraCFrame or TargetCFrame
    local Alpha = math.clamp(DeltaTime * POSITION_SMOOTHING, 0, 1)
    local SmoothedPosition = CurrentCFrame.Position:Lerp(TargetCFrame.Position, Alpha)
    local NewCFrame = CFrame.new(SmoothedPosition) * (TargetCFrame - TargetCFrame.Position)
    self.LastCameraCFrame = NewCFrame
    Camera.CFrame = NewCFrame
end

function Scope.Stop(self: Scope): ()
    if not self.Scoped then return end
    self.Scoped = false

    RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
    for _, Connection in self.Events do
        Connection:Disconnect()
    end
    self.Events = {}
    self.GamepadLook = Vector2.zero
    self.TouchLookDelta = Vector2.zero
    self.LastCameraCFrame = nil

    local Camera = Workspace.CurrentCamera
    if Camera then
        if self.OriginalCameraType then
            Camera.CameraType = self.OriginalCameraType
        end
        if self.OriginalFieldOfView then
            Camera.FieldOfView = self.OriginalFieldOfView
        end
    end
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

function Scope.Destroy(self: Scope): ()
    self:Stop()
end



return Scope
