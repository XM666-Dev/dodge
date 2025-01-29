dofile_once("mods/dodge/files/tactic.lua")
dofile_once("mods/dodge/files/input.lua")

---@class Player: Entity
local Player = Entity{
    controls = ComponentField("ControlsComponent"),
    character_platforming = ComponentField("CharacterPlatformingComponent"),
    character_data = ComponentField("CharacterDataComponent"),
    shooter = ComponentField("PlatformShooterPlayerComponent"),
    damage_model = ComponentField("DamageModelComponent"),
    stains = ComponentField("SpriteStainsComponent"),
    stainless_sprite = ComponentField{"SpriteComponent", "dodge.stainless", _tags = "dodge.stainless"},
    dodging = VariableField("dodge.dodging", "value_bool"),
}

local input_duration = 10
local cooldown_duration = 20
local ready_duration = 1
local dodge_duration = 30
local x_speed = 250
local y_speed = 250

local pre_input_frame = 0
local post_input_frame = 0
local input_frame = 0
local cooldown_frame = 0
local ready_frame = 0
local last_frame_left = 0
local last_frame_right = 0
local last_frame_up = 0
local last_frame_down = 0
function OnWorldPreUpdate()
    local player = EntityGetWithTag("player_unit")[1]
    if player == nil then return end
    local player_object = Player(player)

    local frame = GameGetFrameNum()
    local input = tostring(ModSettingGet("dodge.key"))
    local down = read_input_down(input)
    if input == "Mouse_left" then
        down = player_object.controls.mButtonFrameLeftClick == frame
    elseif input == "Mouse_right" then
        down = player_object.controls.mButtonFrameRightClick == frame
    end
    if down then
        pre_input_frame = frame + input_duration
    end
    if post_input_frame < pre_input_frame and frame < pre_input_frame and cooldown_frame < frame and ready_frame < frame and not player_object.character_platforming.mIsPrecisionJumping then
        post_input_frame = pre_input_frame
        input_frame = frame
        cooldown_frame = frame + cooldown_duration
        ready_frame = frame + ready_duration
    end
    if player_object.controls.mButtonDownLeft then
        last_frame_left = frame
    end
    if player_object.controls.mButtonDownRight then
        last_frame_right = frame
    end
    if player_object.controls.mButtonDownUp then
        last_frame_up = frame
    end
    if player_object.controls.mButtonDownDown then
        last_frame_down = frame
    end
    if not player_object.character_platforming.mIsPrecisionJumping then
        if player_object.dodging then
            player_object.dodging = false
            EntityAddTag(player, "hittable")
            player_object.damage_model.materials_damage = true
            player_object.damage_model.fire_probability_of_ignition = 1
            player_object.stains.sprite_id = 0
            player_object.character_data.buoyancy_check_offset_y = -7
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
                x, y = vec_normalize(x, y)
                x, y = vec_scale(x, y, x_speed, y_speed)
                player_object.character_platforming.mIsPrecisionJumping = true
                player_object.character_platforming.mPrecisionJumpingSpeedX = player_object.character_data._id and player_object.character_data.mVelocity[1] + x
                player_object.character_platforming.mPrecisionJumpingTimeLeft = dodge_duration
                ensure(player_object.character_data.mVelocity)[2] = y

                EntityRemoveTag(player, "hittable")
                player_object.damage_model.materials_damage = false
                player_object.damage_model.fire_probability_of_ignition = 0
                player_object.stainless_sprite.transform_offset = {math.huge, math.huge}
                player_object.stains.sprite_id = select(2, table.find(EntityGetComponentIncludingDisabled(player, "SpriteComponent") or {}, player_object.stainless_sprite._id)) - 1
                player_object.character_data.buoyancy_check_offset_y = 0x1FFFF

                player_object.shooter.mFastMovementParticlesAlphaSmoothed = 0.5 + tonumber(MagicNumbersGetValue("PLAYER_FAST_MOVEMENT_PARTICLES_ALPHA_CHANGE_SPD"))
                local player_x, player_y = EntityGetTransform(player)
                GamePlaySound("data/audio/Desktop/player.bank", "player/kick", player_x, player_y)
            end
        end
    end
    if player_object.dodging and ModTextFileGetContent("mods/fpspp/files/internal.txt") ~= "false" then
        if frame > ready_frame then
            player_object.character_platforming.mPrecisionJumpingSpeedX = player_object.character_platforming.mPrecisionJumpingSpeedX * 0.9375
        end
        if last_frame_up < input_frame and last_frame_down < input_frame then
            ensure(player_object.character_data.mVelocity)[2] = player_object.character_data._id and player_object.character_data.mVelocity[2] - player_object.character_platforming.pixel_gravity * 0.5 / 60
        end
        player_object.controls.mJumpVelocity = {0, 0}

        player_object.damage_model.mFireFramesLeft = player_object.damage_model._id and math.max(player_object.damage_model.mFireFramesLeft - 5, 0)

        if frame > ready_frame then
            player_object.shooter.mFastMovementParticlesAlphaSmoothed = player_object.shooter._id and player_object.shooter.mFastMovementParticlesAlphaSmoothed - 0.5 / dodge_duration + tonumber(MagicNumbersGetValue("PLAYER_FAST_MOVEMENT_PARTICLES_ALPHA_CHANGE_SPD"))
        end
    end
end
