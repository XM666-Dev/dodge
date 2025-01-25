dofile_once("mods/dodge/files/tactic.lua")
dofile_once("mods/dodge/files/input.lua")

ModImageMakeEditable("mods/dodge/files/empty.png", 1, 1)

---@class Player
---@field id number
---@field controls table?
---@field character_platforming table?
---@field character_data table?
---@field shooter table?
---@field damage_model table?
---@field stains table?
---@field stainless_sprite table?
---@field dodging boolean
---@field is_jumping fun():boolean
---@type table|fun(id):Player
local Player = setmetatable(Class {
    controls = ComponentAccessor(EntityGetFirstComponent, "ControlsComponent"),
    character_platforming = ComponentAccessor(EntityGetFirstComponent, "CharacterPlatformingComponent"),
    character_data = ComponentAccessor(EntityGetFirstComponent, "CharacterDataComponent"),
    shooter = ComponentAccessor(EntityGetFirstComponent, "PlatformShooterPlayerComponent"),
    damage_model = ComponentAccessor(EntityGetFirstComponent, "DamageModelComponent"),
    stains = ComponentAccessor(EntityGetFirstComponent, "SpriteStainsComponent"),
    stainless_sprite = ComponentValidAccessor("SpriteComponent", { _tags = "dodge.stainless", image_file = "mods/dodge/files/empty.png" }),
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
        button = read_input_down(input)
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
    if not player_object:is_jumping() then
        if player_object.dodging then
            player_object.dodging = false

            EntityAddTag(player, "hittable")
            if player_object.damage_model ~= nil then
                player_object.damage_model.materials_damage = true
                player_object.damage_model.fire_probability_of_ignition = 1
            end
            if player_object.stains ~= nil then
                player_object.stains.sprite_id = 0
            end
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
                if player_object.character_platforming ~= nil then
                    player_object.character_platforming.mPrecisionJumpingTimeLeft = dodge_duration
                    if player_object.character_data ~= nil then
                        player_object.character_platforming.mPrecisionJumpingSpeedX = player_object.character_data.mVelocity[1] + x
                    end
                    player_object.character_platforming.mIsPrecisionJumping = true
                end
                if player_object.character_data ~= nil then
                    player_object.character_data.mVelocity[2] = y
                end

                EntityRemoveTag(player, "hittable")
                if player_object.damage_model ~= nil then
                    player_object.damage_model.materials_damage = false
                    player_object.damage_model.fire_probability_of_ignition = 0
                end
                player_object.stainless_sprite.transform_offset = { math.huge, math.huge }
                for i, sprite in ipairs(EntityGetComponentIncludingDisabled(player, "SpriteComponent") or {}) do
                    if sprite == player_object.stainless_sprite._id and player_object.stains ~= nil then
                        player_object.stains.sprite_id = i - 1
                        break
                    end
                end
                if player_object.character_data ~= nil then
                    player_object.character_data.buoyancy_check_offset_y = 0x1FFFF
                end

                if player_object.shooter ~= nil then
                    player_object.shooter.mFastMovementParticlesAlphaSmoothed = 0.5 + tonumber(MagicNumbersGetValue("PLAYER_FAST_MOVEMENT_PARTICLES_ALPHA_CHANGE_SPD"))
                end
                local player_x, player_y = EntityGetTransform(player)
                GamePlaySound("data/audio/Desktop/player.bank", "player/kick", player_x, player_y)
            end
        end
    end
    if player_object.dodging and ModTextFileGetContent("mods/fpspp/files/internal.txt") ~= "false" then
        if frame > dodge_frame then
            player_object.character_platforming.mPrecisionJumpingSpeedX = player_object.character_platforming.mPrecisionJumpingSpeedX * 0.9375
        end
        if player_object.character_data ~= nil and player_object.character_platforming ~= nil and last_frame_up < input_frame and last_frame_down < input_frame then
            player_object.character_data.mVelocity[2] = player_object.character_data.mVelocity[2] - player_object.character_platforming.pixel_gravity * 0.5 / 60
        end
        player_object.controls.mJumpVelocity = { 0, 0 }

        if player_object.damage_model ~= nil then
            player_object.damage_model.mFireFramesLeft = math.max(player_object.damage_model.mFireFramesLeft - 5, 0)
        end

        if frame > dodge_frame and player_object.shooter ~= nil then
            player_object.shooter.mFastMovementParticlesAlphaSmoothed = player_object.shooter.mFastMovementParticlesAlphaSmoothed - 0.5 / dodge_duration + tonumber(MagicNumbersGetValue("PLAYER_FAST_MOVEMENT_PARTICLES_ALPHA_CHANGE_SPD"))
        end
    end
end
