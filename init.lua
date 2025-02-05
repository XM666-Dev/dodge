dofile_once("mods/dodge/files/tactic.lua")
dofile_once("mods/dodge/files/input.lua")

---@class Player: Entity
---@field controls ControlsComponent?
---@field character_platforming CharacterPlatformingComponent?
---@field character_data CharacterDataComponent?
---@field shooter PlatformShooterPlayerComponent?
---@field damage_model DamageModelComponent?
---@field stains SpriteStainsComponent?
---@field stainless_sprite SpriteComponent
---@field dodging boolean
---@type fun(entity_id: integer): Player
local Player = Entity{
    controls = ComponentField("ControlsComponent"),
    character_platforming = ComponentField("CharacterPlatformingComponent"),
    character_data = ComponentField("CharacterDataComponent"),
    shooter = ComponentField("PlatformShooterPlayerComponent"),
    damage_model = ComponentField("DamageModelComponent"),
    stains = ComponentField("SpriteStainsComponent"),
    stainless_sprite = ComponentField{"SpriteComponent", "dodge.stainless", _tags = "dodge.stainless"},
    sound_air = ComponentField("AudioLoopComponent", "sound_air_whoosh"),
    inventory = ComponentField("Inventory2Component"),
    dodging = VariableField("dodge.dodging", "value_bool"),
}
function Player:get_max_dodges()
    return self.character_data and self.character_data.fly_time_max * 2 ^ GameGetGameEffectCount(self.id, "HOVER_BOOST") * ModSettingGet("dodge.dodge_multiplier") or 0
end

local input_frame_pre = 0
local input_frame_post = 0
local input_frame = 0
local cooldown_frame = 0
local ready_frame = 0
local last_frame_left = 0
local last_frame_right = 0
local last_frame_up = 0
local last_frame_down = 0

local dodges = 0
local collided_horizontally_first = false
local collided_horizontally_second = false
local gravity_scale
function OnWorldPreUpdate()
    local player = EntityGetWithTag("player_unit")[1]
    if player == nil then return end
    local player_object = Player(player)

    local input_duration = ModSettingGet("dodge.input_duration")
    local cooldown_duration = ModSettingGet("dodge.cooldown_duration")
    local ready_duration = ModSettingGet("dodge.ready_duration")
    local dodge_duration = ModSettingGet("dodge.dodge_duration")

    local max_dodges = player_object:get_max_dodges()
    local friction = ModSettingGet("dodge.friction")
    local x_speed = ModSettingGet("dodge.x_speed")
    local y_speed = ModSettingGet("dodge.y_speed")

    local frame = GameGetFrameNum()
    local input = tostring(ModSettingGet("dodge.key"))
    local down = read_input_down(input)
    if input == "Mouse_left" then
        down = player_object.controls ~= nil and player_object.controls.mButtonFrameLeftClick == frame
    elseif input == "Mouse_right" then
        down = player_object.controls ~= nil and player_object.controls.mButtonFrameRightClick == frame
    end
    if down then
        input_frame_pre = frame + input_duration
    end

    if player_object.character_data and player_object.character_data.is_on_ground then
        dodges = 0
    end
    local collided_horizontally_third = player_object.character_data ~= nil and player_object.character_data.mCollidedHorizontally
    if collided_horizontally_second and player_object.character_platforming and not player_object.character_platforming.mIsPrecisionJumping and player_object.dodging then
        dodges = dodges - 1
    end
    if (collided_horizontally_first or collided_horizontally_second or collided_horizontally_third) and read_input(input) then
        local y = player_object.character_data and player_object.character_data.mVelocity[2] or 0
        local gravity = player_object.character_platforming and player_object.character_platforming.pixel_gravity / -60 or 0
        if y > gravity then
            y = math.max(y - friction, gravity)
        end
        player_object.character_data_.mVelocity[2] = y
    end
    collided_horizontally_first = collided_horizontally_second
    collided_horizontally_second = collided_horizontally_third

    if input_frame_post < input_frame_pre and frame < input_frame_pre and cooldown_frame < frame and ready_frame < frame and player_object.character_platforming and not player_object.character_platforming.mIsPrecisionJumping and dodges < max_dodges then
        input_frame_post = input_frame_pre
        input_frame = frame
        cooldown_frame = frame + cooldown_duration
        ready_frame = frame + ready_duration
        dodges = dodges + 1
    end
    if player_object.controls and player_object.controls.mButtonDownLeft then
        last_frame_left = frame
    end
    if player_object.controls and player_object.controls.mButtonDownRight then
        last_frame_right = frame
    end
    if player_object.controls and player_object.controls.mButtonDownUp then
        last_frame_up = frame
    end
    if player_object.controls and player_object.controls.mButtonDownDown then
        last_frame_down = frame
    end

    if player_object.character_platforming and not player_object.character_platforming.mIsPrecisionJumping then
        if player_object.dodging then
            player_object.dodging = false
            player_object.character_data_.climb_over_y = 4
            player_object.character_data_.buoyancy_check_offset_y = -7

            EntityAddTag(player, "hittable")
            player_object.damage_model_.materials_damage = true
            player_object.damage_model_.fire_probability_of_ignition = 1
            player_object.stains_.sprite_id = 0

            player_object.sound_air_.volume_autofade_speed = 0.5
        end
        if frame == ready_frame then
            local x = 0
            if last_frame_left >= input_frame or last_frame_right >= input_frame then
                x = -1
                if last_frame_left < last_frame_right then
                    x = 1
                end
            end
            local y = 0
            if last_frame_up >= input_frame or last_frame_down >= input_frame then
                y = -1
                if last_frame_up < last_frame_down then
                    y = 1
                end
            end
            if x ~= 0 or y ~= 0 then
                player_object.dodging = true
                gravity_scale = 0
                if y == 0 then
                    gravity_scale = -0x1.1111111111111000p-7
                elseif y > 0 and x ~= 0 then
                    gravity_scale = -0x1.1111111111111000p-6
                end
                x, y = vec_normalize(x, y)
                x, y = vec_scale(x, y, x_speed, y_speed)
                player_object.character_platforming_.mIsPrecisionJumping = true
                player_object.character_platforming_.mPrecisionJumpingSpeedX = player_object.character_data and player_object.character_data.mVelocity[1] + x
                player_object.character_platforming_.mPrecisionJumpingTimeLeft = dodge_duration
                player_object.character_data_.mVelocity[2] = y
                player_object.character_data_.climb_over_y = player_object.character_data and player_object.character_data.climb_over_y * 2
                player_object.character_data_.buoyancy_check_offset_y = 0x1FFFF

                EntityRemoveTag(player, "hittable")
                player_object.damage_model_.materials_damage = false
                player_object.damage_model_.fire_probability_of_ignition = 0
                player_object.stainless_sprite_.transform_offset = {math.huge, math.huge}
                player_object.stains_.sprite_id = select(2, table.find(EntityGetComponentIncludingDisabled(player, "SpriteComponent") or {}, player_object.stainless_sprite._id)) - 1

                local max = dodges == max_dodges
                local player_x, player_y = EntityGetTransform(player)
                local particle = EntityCreateNew()
                local emitter = EntityAddComponent2(particle, "ParticleEmitterComponent", {
                    emitted_material_name = "spark_white",
                    lifetime_min = 0.1,
                    lifetime_max = 0.5,
                    count_min = max and 60 or 30,
                    count_max = max and 80 or 40,
                    render_on_grid = true,
                    airflow_force = 0.051,
                    airflow_time = 1.01,
                    airflow_scale = 0.03,
                    emission_interval_min_frames = 0,
                    emission_interval_max_frames = 0,
                    emit_cosmetic_particles = true,
                    velocity_always_away_from_center = 11,
                    custom_alpha = max and 1 or 0.5,
                })
                ComponentSetValue2(emitter, "gravity", 0, 0)
                ComponentSetValue2(emitter, "area_circle_radius", max and 4 or 2, max and 4 or 2)
                EntityAddComponent2(particle, "LifetimeComponent", {lifetime = 2})
                EntitySetTransform(particle, player_x, player_y)
                if max then
                    GamePlaySound("data/audio/Desktop/items.bank", "magic_wand/not_enough_mana_for_action", player_x, player_y)
                end
            end
        end
    end
    if player_object.dodging and ModTextFileGetContent("mods/fpspp/files/internal.txt") ~= "false" then
        if frame > ready_frame then
            player_object.character_platforming_.mPrecisionJumpingSpeedX = player_object.character_platforming and player_object.character_platforming.mPrecisionJumpingSpeedX * 0.9375
        end
        player_object.character_data_.mVelocity[2] = player_object.character_data and player_object.character_platforming and player_object.character_data.mVelocity[2] + player_object.character_platforming.pixel_gravity * gravity_scale
        player_object.controls_.mJumpVelocity = {0, 0}

        player_object.damage_model_.mFireFramesLeft = player_object.damage_model and math.max(player_object.damage_model.mFireFramesLeft - 7, 0)

        local weight = player_object.character_platforming and player_object.character_platforming.mPrecisionJumpingTime / dodge_duration or 0
        player_object.shooter_.mFastMovementParticlesAlphaSmoothed = lerp(0.5, 0, weight) + tonumber(MagicNumbersGetValue("PLAYER_FAST_MOVEMENT_PARTICLES_ALPHA_CHANGE_SPD"))
        player_object.sound_air_.volume_autofade_speed = lerp(-1, 0.5, weight)
    end
end

local gui = GuiCreate()
function OnWorldPostUpdate()
    local player = EntityGetWithTag("player_unit")[1]
    if player == nil then return end
    local player_object = Player(player)

    GuiStartFrame(gui)
    local text = player_object:get_max_dodges() - dodges
    local ability = player_object.inventory and validate(player_object.inventory.mActiveItem) and EntityGetFirstComponentIncludingDisabled(player_object.inventory.mActiveItem, "AbilityComponent")
    local mana = ability and math.floor(ComponentGetValue2(ability, "mana")) or 0
    local n = 1
    if player_object.damage_model and player_object.damage_model.air_in_lungs < player_object.damage_model.air_in_lungs_max then
        n = n + 1
    end
    local x, y = GuiGetScreenDimensions(gui) + tonumber(MagicNumbersGetValue("UI_BARS2_OFFSET_X")) + tonumber(MagicNumbersGetValue("UI_STAT_BAR_TEXT_OFFSET_X")),
        tonumber(MagicNumbersGetValue("UI_BARS_POS_Y"))
    local spacing = tonumber(MagicNumbersGetValue("UI_STAT_BAR_EXTRA_SPACING"))
    local height = select(2, GuiGetTextDimensions(gui, text, 1, 2, "data/fonts/font_small_numbers.xml"))

    GuiLayoutBeginHorizontal(gui, x, y, true)
    GuiLayoutAddHorizontalSpacing(gui)
    GuiLayoutBeginVertical(gui, 0, 0, true, 0, spacing)

    GuiLayoutAddVerticalSpacing(gui, (spacing + height) * n)
    GuiColorSetForNextWidget(gui, 0xcc / 0xff, 0xcc / 0xff, 0xcc / 0xff, 0xff / 0xff)
    GuiText(gui, 0, 0, text, 1, "data/fonts/font_small_numbers.xml")

    GuiColorSetForNextWidget(gui, 0xcc / 0xff, 0xcc / 0xff, 0xcc / 0xff, 0xff / 0xff)
    --GuiText(gui, 0, 0, mana, 1, "data/fonts/font_small_numbers.xml")

    GuiLayoutEnd(gui)
    GuiLayoutEnd(gui)
end
