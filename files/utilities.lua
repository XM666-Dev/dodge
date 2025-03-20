dofile_once("mods/dodge/files/tactic.lua")

---@class Player: Entity
---@field controls ControlsComponent?
---@field controls_ ControlsComponent?
---@field character_platforming CharacterPlatformingComponent?
---@field character_platforming_ CharacterPlatformingComponent?
---@field character_data CharacterDataComponent?
---@field character_data_ CharacterDataComponent?
---@field shooter PlatformShooterPlayerComponent?
---@field shooter_ PlatformShooterPlayerComponent?
---@field damage_model DamageModelComponent?
---@field damage_model_ DamageModelComponent?
---@field stains SpriteStainsComponent?
---@field stains_ SpriteStainsComponent?
---@field stainless_sprite SpriteComponent
---@field sound_air AudioLoopComponent?
---@field sound_air_ AudioLoopComponent?
---@field inventory Inventory2Component?
---@field inventory_ Inventory2Component?
---@field jetpack_emitter ParticleEmitterComponent?
---@field jetpack_emitter_ ParticleEmitterComponent?
---@field dodging boolean
Player = nil
---@type fun(entity_id: integer): Player
Player = Entity{
    controls = ComponentField("ControlsComponent"),
    character_platforming = ComponentField("CharacterPlatformingComponent"),
    character_data = ComponentField("CharacterDataComponent", EntityGetFirstComponent),
    shooter = ComponentField("PlatformShooterPlayerComponent"),
    damage_model = ComponentField("DamageModelComponent", EntityGetFirstComponent),
    stains = ComponentField("SpriteStainsComponent"),
    stainless_sprite = ComponentField{"SpriteComponent", "dodge.stainless", _tags = "dodge.stainless", image_file = ""},
    sound_air = ComponentField("AudioLoopComponent", "sound_air_whoosh"),
    inventory = ComponentField("Inventory2Component"),
    jetpack_emitter = ComponentField("ParticleEmitterComponent", "jetpack"),
    script_damage = ComponentField{"LuaComponent", "dodge.script_damage", _tags = "dodge.script_damage", script_damage_about_to_be_received = "mods/dodge/files/dodge_damage.lua"},
    dodging = VariableField("dodge.dodging", "value_bool"),
}
function Player:get_max_dodges()
    if not self.character_data_.flying_needs_recharge then return math.huge end
    return self.character_data.fly_time_max * 2 ^ GameGetGameEffectCount(self.id, "HOVER_BOOST") * ModSettingGet("dodge.dodge_multiplier")
end
