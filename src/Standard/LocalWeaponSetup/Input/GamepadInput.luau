--Handles inputs for gaempads.
--!strict

local START_FIRE_THRESHOLD = 0.7
local STOP_FIRE_THRESHOLD = 0.5

local UserInputService = game:GetService("UserInputService")

local BaseInput = require(script.Parent:WaitForChild("BaseInput"))

local GamepadInput = {}
GamepadInput.__index = GamepadInput
setmetatable(GamepadInput, BaseInput)

export type GamepadInput = typeof(setmetatable({}, GamepadInput)) & BaseInput.BaseInput



--[[
Creates a gamepad input.
--]]
function GamepadInput.new(FireButton: Enum.KeyCode, ScopeButton: Enum.KeyCode?): GamepadInput
    local self = setmetatable(BaseInput.new(), GamepadInput) :: GamepadInput

    --Connect firing events.
    local FireActive = false
    table.insert(self.Events, UserInputService.InputChanged:Connect(function(Input, Processed)
        if Input.KeyCode ~= FireButton then return end
        if Input.Position.Z >= START_FIRE_THRESHOLD and not FireActive and not Processed then
            FireActive = true
            self.StartFire:Fire()
        elseif Input.Position.Z <= STOP_FIRE_THRESHOLD and FireActive then
            FireActive = false
            self.EndFire:Fire()
        end
    end))

    if ScopeButton then
        local ScopeActive = false
        table.insert(self.Events, UserInputService.InputChanged:Connect(function(Input, Processed)
            if Input.KeyCode ~= ScopeButton then return end
            if Input.Position.Z >= START_FIRE_THRESHOLD and not ScopeActive and not Processed then
                ScopeActive = true
                self.StartScope:Fire()
            elseif Input.Position.Z <= STOP_FIRE_THRESHOLD and ScopeActive then
                ScopeActive = false
                self.EndScope:Fire()
            end
        end))
        table.insert(self.Events, UserInputService.InputBegan:Connect(function(Input, Processed)
            if Processed then return end
            if Input.KeyCode ~= ScopeButton then return end
            if ScopeActive then return end
            ScopeActive = true
            self.StartScope:Fire()
        end))
        table.insert(self.Events, UserInputService.InputEnded:Connect(function(Input)
            if Input.KeyCode ~= ScopeButton then return end
            if not ScopeActive then return end
            ScopeActive = false
            self.EndScope:Fire()
        end))
    end
    return self
end



return GamepadInput