/mob/living/basic/cockroach
	name = "cockroach"
	desc = "This station is just crawling with bugs."
	icon_state = "cockroach"
	icon_dead = "cockroach" //Make this work
	density = FALSE
	mob_biotypes = MOB_ORGANIC|MOB_BUG
	mob_size = MOB_SIZE_TINY
	health = 1
	maxHealth = 1
	speed = 1.25
	gold_core_spawnable = FRIENDLY_SPAWN
	pass_flags = PASSTABLE | PASSGRILLE | PASSMOB

	verb_say = "chitters"
	verb_ask = "chitters inquisitively"
	verb_exclaim = "chitters loudly"
	verb_yell = "chitters loudly"
	response_disarm_continuous = "shoos"
	response_disarm_simple = "shoo"
	response_harm_continuous = "splats"
	response_harm_simple = "splat"
	speak_emote = list("chitters")

	basic_mob_flags = DEL_ON_DEATH
	faction = list("hostile")

	ai_controller = /datum/ai_controller/basic_controller/cockroach

/mob/living/basic/cockroach/Initialize()
	. = ..()
	AddElement(/datum/element/death_drops, list(/obj/effect/decal/cleanable/insectguts))
	AddElement(/datum/element/swabable, CELL_LINE_TABLE_COCKROACH, CELL_VIRUS_TABLE_GENERIC_MOB, 1, 7)
	AddElement(/datum/element/basic_body_temp_sensitive, 270, INFINITY)
	AddComponent(/datum/component/squashable, squash_chance = 50, squash_damage = 1)
	ADD_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)

/mob/living/basic/cockroach/death(gibbed)
	if(GLOB.station_was_nuked) //If the nuke is going off, then cockroaches are invincible. Keeps the nuke from killing them, cause cockroaches are immune to nukes.
		return
	..()

/mob/living/basic/cockroach/ex_act() //Explosions are a terrible way to handle a cockroach.
	return FALSE


/datum/ai_controller/basic_controller/cockroach
	blackboard = list(
		BB_TARGETTING_DATUM = new /datum/targetting_datum/basic()
	)

	ai_traits = STOP_MOVING_WHEN_PULLED
	ai_movement = /datum/ai_movement/basic_avoidance
	planning_subtrees = list(
		/datum/ai_planning_subtree/random_speech/cockroach,
		/datum/ai_planning_subtree/find_and_hunt_target
)


/datum/ai_controller/basic_controller/cockroach/PerformIdleBehavior(delta_time)
	. = ..()
	var/mob/living/living_pawn = pawn

	if(DT_PROB(25, delta_time) && (living_pawn.mobility_flags & MOBILITY_MOVE) && isturf(living_pawn.loc) && !living_pawn.pulledby)
		var/move_dir = pick(GLOB.alldirs)
		living_pawn.Move(get_step(living_pawn, move_dir), move_dir)


/obj/projectile/glockroachbullet
	damage = 10 //same damage as a hivebot
	damage_type = BRUTE

/obj/item/ammo_casing/glockroach
	name = "0.9mm bullet casing"
	desc = "A... 0.9mm bullet casing? What?"
	projectile_type = /obj/projectile/glockroachbullet


/mob/living/basic/cockroach/glockroach
	name = "glockroach"
	desc = "HOLY SHIT, THAT COCKROACH HAS A GUN!"
	icon_state = "glockroach"
	melee_damage_lower = 2.5
	melee_damage_upper = 10
	obj_damage = 10
	gold_core_spawnable = HOSTILE_SPAWN
	faction = list("hostile")
	ai_controller = /datum/ai_controller/basic_controller/cockroach/glockroach

/mob/living/basic/cockroach/glockroach/Initialize()
	. = ..()
	AddElement(/datum/element/ranged_attacks, /obj/item/ammo_casing/glockroach)

/datum/ai_controller/basic_controller/cockroach/glockroach
	planning_subtrees = list(
		/datum/ai_planning_subtree/random_speech/cockroach,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/glockroach, //If we are attacking someone, this will prevent us from hunting
		/datum/ai_planning_subtree/find_and_hunt_target
	)

/datum/ai_planning_subtree/basic_ranged_attack_subtree/glockroach
	ranged_attack_behavior = /datum/ai_behavior/basic_ranged_attack/glockroach

/datum/ai_behavior/basic_ranged_attack/glockroach //Slightly slower, as this is being made in feature freeze ;)
	action_cooldown = 1 SECONDS

/mob/living/basic/cockroach/hauberoach
	name = "hauberoach"
	desc = "Is that cockroach wearing a tiny yet immaculate replica 19th century Prussian spiked helmet? ...Is that a bad thing?"
	icon_state = "hauberoach"
	attack_verb_continuous = "rams its spike into"
	attack_verb_simple = "ram your spike into"
	melee_damage_lower = 2.5
	melee_damage_upper = 10
	obj_damage = 10
	gold_core_spawnable = HOSTILE_SPAWN
	attack_sound = 'sound/weapons/bladeslice.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	faction = list("hostile")
	sharpness = SHARP_POINTY
	ai_controller = /datum/ai_controller/basic_controller/cockroach/hauberoach

/mob/living/basic/cockroach/hauberoach/Initialize()
	. = ..()
	AddComponent(/datum/component/caltrop, min_damage = 10, max_damage = 15, flags = (CALTROP_BYPASS_SHOES | CALTROP_SILENT))
	AddComponent(/datum/component/squashable, squash_chance = 100, squash_damage = 1, squash_callback = /mob/living/basic/cockroach/hauberoach/.proc/on_squish)

///Proc used to override the squashing behavior of the normal cockroach.
/mob/living/basic/cockroach/hauberoach/proc/on_squish(mob/living/cockroach, mob/living/living_target)
	if(!istype(living_target))
		return FALSE //We failed to run the invoke. Might be because we're a structure. Let the squashable element handle it then!
	if(!HAS_TRAIT(living_target, TRAIT_PIERCEIMMUNE))
		living_target.visible_message(span_danger("[living_target] steps onto [cockroach]'s spike!"), span_userdanger("You step onto [cockroach]'s spike!"))
		return TRUE
	living_target.visible_message(span_notice("[living_target] squashes [cockroach], not even noticing its spike."), span_notice("You squashed [cockroach], not even noticing its spike."))
	return FALSE
/datum/ai_controller/basic_controller/cockroach/hauberoach
	planning_subtrees = list(
		/datum/ai_planning_subtree/random_speech/cockroach,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree/hauberoach,  //If we are attacking someone, this will prevent us from hunting
		/datum/ai_planning_subtree/find_and_hunt_target
	)

/datum/ai_planning_subtree/basic_melee_attack_subtree/hauberoach
	melee_attack_behavior = /datum/ai_behavior/basic_melee_attack/hauberoach

/datum/ai_behavior/basic_melee_attack/hauberoach //Slightly slower, as this is being made in feature freeze ;)
	action_cooldown = 1 SECONDS
