dofile_once("mods/dodge/files/utilities.lua")
dofile_once("mods/dodge/files/input.lua")

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
local collided_horizontally_second = false
local collided_horizontally_third = false
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
        down = player_object.controls_.mButtonFrameLeftClick == frame
    elseif input == "Mouse_right" then
        down = player_object.controls_.mButtonFrameRightClick == frame
    end
    if down then
        input_frame_pre = frame + input_duration
    end

    if player_object.character_data_.is_on_ground then
        dodges = 0
    end
    local collided_horizontally_first = player_object.character_data_.mCollidedHorizontally
    if collided_horizontally_second and player_object.dodging and not player_object.character_platforming_.mIsPrecisionJumping then
        dodges = dodges - 1
    end
    if (collided_horizontally_first or collided_horizontally_second or collided_horizontally_third) and read_input(input) then
        local y = player_object.character_data_.mVelocity_[2] or 0
        local gravity = (player_object.character_platforming_.pixel_gravity or 0) * 0.01666666666666667
        player_object.character_data_.mVelocity_[2] = math.max(y - friction, -gravity)
    end
    collided_horizontally_third = collided_horizontally_second
    collided_horizontally_second = collided_horizontally_first

    if input_frame_post < input_frame_pre and frame < input_frame_pre and cooldown_frame < frame and ready_frame < frame and not player_object.character_platforming_.mIsPrecisionJumping and dodges < max_dodges then
        input_frame_post = input_frame_pre
        input_frame = frame
        cooldown_frame = frame + cooldown_duration
        ready_frame = frame + ready_duration
        dodges = dodges + 1
    end
    if player_object.controls_.mButtonDownLeft then
        last_frame_left = frame
    end
    if player_object.controls_.mButtonDownRight then
        last_frame_right = frame
    end
    if player_object.controls_.mButtonDownUp then
        last_frame_up = frame
    end
    if player_object.controls_.mButtonDownDown then
        last_frame_down = frame
    end

    if not player_object.character_platforming_.mIsPrecisionJumping then
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
                player_object.character_platforming_.mPrecisionJumpingSpeedX = (player_object.character_data_.mVelocity_[1] or 0) + x
                player_object.character_platforming_.mPrecisionJumpingTimeLeft = dodge_duration
                player_object.character_data_.mVelocity_[2] = y
                player_object.character_data_.climb_over_y = (player_object.character_data_.climb_over_y or 0) * 2
                player_object.character_data_.buoyancy_check_offset_y = 0x1FFFF

                EntityRemoveTag(player, "hittable")
                player_object.damage_model_.materials_damage = false
                player_object.damage_model_.fire_probability_of_ignition = 0
                local stainless_sprite = player_object.stainless_sprite._id
                local sprites = EntityGetComponentIncludingDisabled(player, "SpriteComponent") or {}
                player_object.stains_.sprite_id = select(2, table.find(sprites, stainless_sprite)) - 1

                local max = dodges >= max_dodges
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
            player_object.character_platforming_.mPrecisionJumpingSpeedX = (player_object.character_platforming_.mPrecisionJumpingSpeedX or 0) * 0.9375
        end
        player_object.character_data_.mVelocity_[2] = (player_object.character_data_.mVelocity_[2] or 0) + (player_object.character_platforming_.pixel_gravity or 0) * gravity_scale
        player_object.controls_.mJumpVelocity = {0, 0}

        player_object.damage_model_.mFireFramesLeft = math.max((player_object.damage_model_.mFireFramesLeft or 0) - 7, 0)

        local weight = (player_object.character_platforming_.mPrecisionJumpingTime or 0) / dodge_duration
        player_object.shooter_.mFastMovementParticlesAlphaSmoothed = lerp(0.5, 0, weight) + tonumber(MagicNumbersGetValue("PLAYER_FAST_MOVEMENT_PARTICLES_ALPHA_CHANGE_SPD"))
        player_object.sound_air_.volume_autofade_speed = lerp(-1, 0.5, weight)
    end

    --assert(player_object.script_damage)

    player_object.character_platforming_.fly_model_player = ModSettingGet("dodge.jump_only") and (player_object.character_platforming_.mFramesSwimming or 0) < 1
    player_object.character_platforming_.jump_velocity_y = (ModSettingGet("dodge.jump_only") and 1.5 or 1) * -95
    player_object.jetpack_emitter_.custom_alpha = ModSettingGet("dodge.jump_only") and 0 or -1
end

local gui = GuiCreate()
function OnWorldPostUpdate()
    local player = EntityGetWithTag("player_unit")[1]
    if player == nil then return end
    local player_object = Player(player)

    if not player_object.character_data_.flying_needs_recharge or player_object.character_data.fly_time_max <= 0 then return end

    GuiStartFrame(gui)
    local text = math.ceil(player_object:get_max_dodges()) - dodges
    local ability = EntityGetFirstComponentIncludingDisabled(player_object.inventory_.mActiveItem, "AbilityComponent")
    local mana = ability and math.floor(ComponentGetValue2(ability, "mana")) or 0
    local n = 0
    if player_object.damage_model ~= nil then
        n = n + 1
        if player_object.damage_model.air_in_lungs < player_object.damage_model.air_in_lungs_max then
            n = n + 1
        end
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
