dofile_once("mods/dodge/files/sult.lua")
dofile_once("data/scripts/debug/keycodes.lua")

local player_class = Class {
    character_data = ComponentAccessor(EntityGetFirstComponent, "CharacterDataComponent"),
    character_platforming = ComponentAccessor(EntityGetFirstComponent, "CharacterPlatformingComponent"),
    controls = ComponentAccessor(EntityGetFirstComponent, "ControlsComponent"),
    shooter = ComponentAccessor(EntityGetFirstComponent, "PlatformShooterPlayerComponent"),

}
local function Player(player)
    return validate(player) and setmetatable({ id = player }, player_class) or {}
end

local input_duration = 10
local pre_dodge_duration = 1
local dodge_duration = 30
local x_speed = 256
local y_speed = 256

local input_frame = 0
local handle_frame = 0
local dodge_frame = 0
local last_frame_left = 0
local last_frame_right = 0
local last_frame_up = 0
local last_frame_down = 0
function OnWorldPreUpdate()
    local player = EntityGetWithTag("player_unit")[1]
    local player_object = Player(player)

    local frame = GameGetFrameNum()
    if player_object.controls ~= nil and player_object.controls.mButtonFrameRightClick == frame then
        input_frame = frame + input_duration
    end
    if frame < input_frame and frame > handle_frame and frame > dodge_frame and player_object.character_platforming ~= nil and not player_object.character_platforming.mIsPrecisionJumping then
        handle_frame = input_frame
        dodge_frame = frame + pre_dodge_duration
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
    if player_object.character_platforming ~= nil and player_object.character_platforming.mIsPrecisionJumping then
        player_object.character_platforming.mPrecisionJumpingSpeedX = player_object.character_platforming.mPrecisionJumpingSpeedX * 0.9375
    elseif frame == dodge_frame then
        local x
        local left = last_frame_left >= input_frame - input_duration
        local right = last_frame_right >= input_frame - input_duration
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
        local up = last_frame_up >= input_frame - input_duration
        local down = last_frame_down >= input_frame - input_duration
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
            if player_object.shooter ~= nil then
                player_object.shooter.mFastMovementParticlesAlphaSmoothed = 1
            end
            EntityRemoveTag(player, "hittable")
        end
    else
        if player_object.character_platforming ~= nil then
            player_object.character_platforming.pixel_gravity = 350
        end
        EntityAddTag(player, "hittable")
    end
end
