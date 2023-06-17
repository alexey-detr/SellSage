local _, SellSage = ...

SellSage.SettingsControls = {}

function SellSage.RegisterSettingsUI()
    local category = Settings.RegisterVerticalLayoutCategory("SellSage")

    local variable = "SellSageMinItemLevelMinItemLevel"
    local name = "Sell gear below selected level"
    local tooltip = "All gear items (armor and weapons) will be sold if their item level is below the selected value."
    local minValue = 0
    local maxValue = 500
    local step = 5

    local setting = Settings.RegisterAddOnSetting(category, name, variable, type(SellSageMinItemLevelMinItemLevel), SellSageMinItemLevelMinItemLevel)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.SetOnValueChangedCallback(variable, function()
        _G[variable] = setting:GetValue();
    end);
    Settings.CreateSlider(category, setting, options, tooltip)

    SellSage.SettingsControls[variable] = setting

    Settings.RegisterAddOnCategory(category)
end
