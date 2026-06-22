local Types = require(script.Parent.Parent.Types)
local ProjectileUtils = {}

function ProjectileUtils.FetchProjectileTemplate(
    State: Folder,
    ConfigurationData: Types.StandardConfiguration
)

    local ForcedTemplate = ConfigurationData.ProjectilePreset
    if ForcedTemplate then
        return ForcedTemplate
    end

    if ConfigurationData.DefaultAdditionalState and ConfigurationData.ProjectilePresets then
        local AdditionalState = State:FindFirstChild("AdditionalState") :: StringValue
        local SelectedTemplate = ConfigurationData.ProjectilePresets[AdditionalState.Value]
        return SelectedTemplate
    end

    return nil
end

return ProjectileUtils