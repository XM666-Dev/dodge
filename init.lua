dofile_once("mods/dodge/files/tactic.lua")
dofile_once("mods/dodge/files/input.lua")

local Player = setmetatable(Class {
    controls = ComponentAccessor(EntityGetFirstComponent, "ControlsComponent"),
    character_platforming = ComponentAccessor(EntityGetFirstComponent, "CharacterPlatformingComponent"),
    character_data = ComponentAccessor(EntityGetFirstComponent, "CharacterDataComponent"),
    shooter = ComponentAccessor(EntityGetFirstComponent, "PlatformShooterPlayerComponent"),
    damage_model = ComponentAccessor(EntityGetFirstComponent, "DamageModelComponent"),
    stains = ComponentAccessor(EntityGetFirstComponent, "SpriteStainsComponent"),
    stainless_sprite = ComponentValidAccessor("SpriteComponent", { _tags = "dodge.stainless", offset_x = math.huge }),
    dodging = VariableAccessor("dodge.dodging", "value_bool"),
    is_jumping = ConstantAccessor(function(self)
        return self.character_platforming ~= nil and self.character_platforming.mIsPrecisionJumping
    end),
}, { __call = function(t, ...) return setmetatable({ id = ... }, t) end })

local input_duration = 10
local pre_dodge_duration = 1
local dodge_duration = 30
local x_speed = 256
local y_speed = 256

local button_frame = -1
local consume_frame = -1
local dodge_frame = -1
local input_frame = -1
local last_frame_left = -1
local last_frame_right = -1
local last_frame_up = -1
local last_frame_down = -1
function OnWorldPreUpdate()
    local player = EntityGetWithTag("player_unit")[1]
    if player == nil then return end
    local player_object = Player(player)

    local frame = GameGetFrameNum()
    local button
    local input = tostring(ModSettingGet("dodge.key"))
    if input == "Mouse_left" and player_object.controls ~= nil then
        button = player_object.controls.mButtonFrameLeftClick == frame
    elseif input == "Mouse_right" and player_object.controls ~= nil then
        button = player_object.controls.mButtonFrameRightClick == frame
    else
        button = read_input_just(input)
    end
    if button then
        button_frame = frame + input_duration
    end
    if frame < button_frame and frame > consume_frame and frame > dodge_frame and not player_object:is_jumping() then
        consume_frame = frame + dodge_duration
        dodge_frame = frame + pre_dodge_duration
        input_frame = frame
    end
    if player_object.controls ~= nil then
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
    end
    if player_object:is_jumping() then
        local internal = ModTextFileGetContent("mods/fpspp/files/internal.txt") ~= "false"
        if player_object.dodging and internal then
            player_object.character_platforming.mPrecisionJumpingSpeedX = player_object.character_platforming.mPrecisionJumpingSpeedX * 0.9375

            if player_object.damage_model ~= nil then
                player_object.damage_model.mFireFramesLeft = math.max(player_object.damage_model.mFireFramesLeft - 5, 0)
            end

            if player_object.shooter ~= nil then
                player_object.shooter.mFastMovementParticlesAlphaSmoothed = player_object.shooter.mFastMovementParticlesAlphaSmoothed - 0.5 / dodge_duration + 0.2
            end
        end
    else
        if player_object.dodging then
            player_object.dodging = false
            if player_object.character_platforming ~= nil then
                player_object.character_platforming.pixel_gravity = 350
            end

            EntityAddTag(player, "hittable")
            if player_object.damage_model ~= nil then
                player_object.damage_model.materials_damage = true
                player_object.damage_model.fire_probability_of_ignition = 1
            end
            player_object.stains.sprite_id = 0
            if player_object.character_data ~= nil then
                player_object.character_data.buoyancy_check_offset_y = -7
            end
        end
        if frame == dodge_frame then
            local x
            local left = last_frame_left >= input_frame
            local right = last_frame_right >= input_frame
            if left and right then
                if last_frame_left > last_frame_right then
                    x = -1
                else
                    x = 1
                end
            elseif left then
                x = -1
            elseif right then
                x = 1
            else
                x = 0
            end
            local y
            local up = last_frame_up >= input_frame
            local down = last_frame_down >= input_frame
            if up and down then
                if last_frame_up > last_frame_down then
                    y = -1
                else
                    y = 1
                end
            elseif up then
                y = -1
            elseif down then
                y = 1
            else
                y = 0
            end
            if x ~= 0 or y ~= 0 then
                player_object.dodging = true
                x, y = vec_normalize(x, y)
                x, y = vec_scale(x, y, x_speed, y_speed)
                local velocity = {}
                if player_object.character_data ~= nil then
                    velocity[1] = player_object.character_data.mVelocity[1] + x
                else
                    velocity[1] = 0
                end
                velocity[2] = y
                if player_object.character_platforming ~= nil then
                    if y == 0 then
                        player_object.character_platforming.pixel_gravity = 175
                    elseif y > 0 then
                        player_object.character_platforming.pixel_gravity = 0
                    end
                end
                if player_object.character_platforming ~= nil then
                    player_object.character_platforming.precision_jumping_max_duration_frames = dodge_duration
                    player_object.character_platforming.mPrecisionJumpingSpeedX = velocity[1]
                    player_object.character_platforming.mIsPrecisionJumping = true
                end
                if player_object.character_data ~= nil then
                    player_object.character_data.mVelocity = velocity
                end

                EntityRemoveTag(player, "hittable")
                if player_object.damage_model ~= nil then
                    player_object.damage_model.materials_damage = false
                    player_object.damage_model.fire_probability_of_ignition = 0
                end
                local stainless_sprite = player_object.stainless_sprite._id
                for i, sprite in ipairs(EntityGetComponentIncludingDisabled(player, "SpriteComponent") or {}) do
                    if sprite == stainless_sprite then
                        player_object.stains.sprite_id = i - 1
                        break
                    end
                end
                if player_object.character_data ~= nil then
                    player_object.character_data.buoyancy_check_offset_y = 0x7fff
                end

                if player_object.shooter ~= nil then
                    player_object.shooter.mFastMovementParticlesAlphaSmoothed = 0.5 + 0.2
                end
                local player_x, player_y = EntityGetTransform(player)
                GamePlaySound("data/audio/Desktop/player.bank", "player/kick", player_x, player_y)
            end
        end
    end
end
