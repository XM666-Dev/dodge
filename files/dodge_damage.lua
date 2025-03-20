dofile_once("mods/dodge/files/utilities.lua")

local function normalize_angle(r)
    r = r % (2 * math.pi)
    if r > math.pi then
        r = r - 2 * math.pi
    end
    return r
end

local function within_90_deg(a, b)
    local diff = normalize_angle(a - b)
    return math.abs(diff) <= math.pi / 2
end

function damage_about_to_be_received(damage, x, y, entity_thats_responsible, critical_hit_chance)
    local this = GetUpdatedEntityID()
    local this_object = Player(this)
    local pos_x, pos_y = EntityGetTransform(this)
    local center_x, center_y = EntityGetFirstHitboxCenter(this)
    local velocity_x, velocity_y = GameGetVelocityCompVelocity(this)
    local damage_direction = get_direction(x, y, EntityGetTransform(this))
    local velocity_direction = get_direction(0, 0, velocity_x, velocity_y)
    if this_object.dodging and damage > 0 and (x ~= pos_x or y ~= pos_y) and within_90_deg(damage_direction, velocity_direction) then
        damage = 0
    end
    debug_print(x, y, pos_x, pos_y, x == pos_x, y == pos_y)
    return damage, critical_hit_chance
end
