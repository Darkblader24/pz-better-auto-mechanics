-- Create the main section in the "MODS" tab
local modOptions = PZAPI.ModOptions:create("better-auto-mechanics", "Better Auto Mechanics")

-- Arguments: ID, Display Name, Default Value, Tooltip Description
BAM_Options_MinSuccessChance = modOptions:addSlider(
    "BAM_MinSuccessChance",
    getText("UI_BAM_options_title.min_success_chance"),
    0,    -- Min
    100,  -- Max
    1,    -- Step
    30   -- Default
)

-- Add a more detailed description below the option
local desc = getText("UI_BAM_options_desc.min_success_chance_1") .. " <LINE> " ..
       "  - 0% -> " .. getText("UI_BAM_options_desc.min_success_chance_2") .. " <LINE> " ..
       "  - 30% -> " .. getText("UI_BAM_options_desc.min_success_chance_3") .. " <LINE> " ..
       "  - 100% -> " .. getText("UI_BAM_options_desc.min_success_chance_4")
modOptions:addDescription(desc)
