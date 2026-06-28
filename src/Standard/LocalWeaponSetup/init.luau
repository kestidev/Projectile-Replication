--Sets up a weapon on the client.
--Moved out of LocalWeapon to make it safe for destroying.
--!strict

local TOOL_SET_UP_TAG = "ProjectileReplicationLoadedTool"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WeaponState = require(script:WaitForChild("WeaponState"))
local Scope = require(script:WaitForChild("Scope"))
local VibrationMotor = require(script:WaitForChild("Common"):WaitForChild("VibrationMotor"))
local CombinedInput = require(script:WaitForChild("Input"):WaitForChild("CombinedInput"))
local GamepadInput = require(script:WaitForChild("Input"):WaitForChild("GamepadInput"))
local MouseInput = require(script:WaitForChild("Input"):WaitForChild("MouseInput"))
local TouchInput = require(script:WaitForChild("Input"):WaitForChild("TouchInput"))
local BaseCrosshair = require(script:WaitForChild("UI"):WaitForChild("BaseCrosshair"))
local MouseCrosshair = require(script:WaitForChild("UI"):WaitForChild("MouseCrosshair"))
local VRCrosshair = require(script:WaitForChild("UI"):WaitForChild("VRCrosshair"))
local Types = require(script.Parent.Parent:WaitForChild("Types"))

local LocalWeaponSetup = {}

export type LocalWeaponSetup = typeof(LocalWeaponSetup)


--[[
Sets up a tool.
--]]
function LocalWeaponSetup.SetupTool(self: LocalWeaponSetup, Tool: Tool): ()
    if Tool:HasTag(TOOL_SET_UP_TAG) then return end
    Tool:AddTag(TOOL_SET_UP_TAG)

    local ProjectileReplication = require(script.Parent.Parent) :: any
    
    local Configuration = require(Tool:WaitForChild("Configuration")) :: Types.StandardConfiguration
    local Handle = Tool:WaitForChild("Handle")
    local StartAttachment = Handle:WaitForChild("StartAttachment") :: Attachment
    local WeaponState = WeaponState.new(Tool)
    if Configuration.GamepadVibrationMotor then
        WeaponState:AddVibrationMotor(VibrationMotor.GetMotor(UserInputService.VREnabled and Enum.VibrationMotor.RightHand or Configuration.GamepadVibrationMotor))
    end

    local CurrentCrosshair: BaseCrosshair.BaseCrosshair? = nil
    local CurrentInput: CombinedInput.CombinedInput? = nil
    local CurrentScope: Scope.Scope? = nil
    local Equipped = false

    local ScopeAttachment = Handle:FindFirstChild("ScopeAttachment") :: Attachment?

    local State = Tool:WaitForChild("State") :: Folder

    --Connect equipping and unequipping the tool.
    Tool.Equipped:Connect(function()
        Equipped = true

        for _, Callback in ProjectileReplication._ToolEquippedCallbacks do
            task.spawn(Callback, Tool, Configuration, State)
        end

        --Create the crosshair.
        local Crosshair = (UserInputService.VREnabled and VRCrosshair.new(StartAttachment) or MouseCrosshair.new())
        Crosshair:ConnectStandard(Tool)
        CurrentCrosshair = Crosshair

        --Create the input.
        local Input = CombinedInput.new(MouseInput.new(), TouchInput.new(), GamepadInput.new(Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2))
        Input:ConnectReloadButton(Enum.KeyCode.ButtonY)
        WeaponState:SetInput(Input)
        CurrentInput = Input

        --Connect using the tool.
        Input.StartFire:Connect(function()
            if not Equipped then return end
            Tool:Activate()
            WeaponState:Fire()
        end)
        Input.EndFire:Connect(function()
            Tool:Deactivate()
            WeaponState:StopFiring()
        end)
        Input.Reload:Connect(function()
            if not Equipped then return end
            WeaponState:Reload()
        end)

        if ScopeAttachment and not UserInputService.VREnabled then
            local ToolScope = Scope.new(ScopeAttachment, Configuration)
            CurrentScope = ToolScope
            Input.StartScope:Connect(function()
                if not Equipped then return end
                ToolScope:Start()
                WeaponState:SetAimOverride(function()
                    return ToolScope:GetAimPosition()
                end)
            end)
            Input.EndScope:Connect(function()
                ToolScope:Stop()
                WeaponState:SetAimOverride(nil)
            end)
        end

        --Update the aim if the user isn't in VR.
        if not UserInputService.VREnabled then
            local Character = Tool.Parent
            if not Character then return end

            local CrosshairAsMouse = (Crosshair :: MouseCrosshair.MouseCrosshair)
            while Equipped do
                CrosshairAsMouse:MoveTo(Input:GetTargetScreenSpace())
                ProjectileReplication:Aim(Players.LocalPlayer, WeaponState:GetAim())
                RunService.RenderStepped:Wait()
            end
        end
    end)
    Tool.Unequipped:Connect(function()
        Equipped = false
        WeaponState:StopFiring()

        for _, Callback in ProjectileReplication._ToolUnequippedCallbacks do
            task.spawn(Callback, Tool, Configuration, State)
        end

        if CurrentScope then
            CurrentScope:Destroy()
            CurrentScope = nil
            WeaponState:SetAimOverride(nil)
        end
        if CurrentCrosshair then
            CurrentCrosshair:Destroy()
            CurrentCrosshair = nil
        end
        if CurrentInput then
            CurrentInput:Destroy()
            CurrentInput = nil
        end
    end)
end

--[[
Binds the tool setup to a different script.
Calls to SetupTool will not properly clear when destroyed. This ensures that SetupTool
is actually called in a different script that can perform the cleanup.
--]]
function LocalWeaponSetup.Bind(self: LocalWeaponSetup): ()
    local OriginalSetupTool = self.SetupTool
    local BindableFunction = Instance.new("BindableFunction")
    BindableFunction.OnInvoke = function(...)
        OriginalSetupTool(self, ...)
    end
    self.SetupTool = function(_, ...)
        BindableFunction:Invoke(...)
    end
end



return LocalWeaponSetup