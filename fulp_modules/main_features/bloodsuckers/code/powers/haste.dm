/* Level 1: Speed to location
 * Level 2: Dodge Bullets
 * Level 3: Stun People Passed
 */

/datum/action/bloodsucker/targeted/haste
	name = "Immortal Haste"
	desc = "Dash somewhere with supernatural speed. Those nearby may be knocked away, stunned, or left empty-handed."
	button_icon_state = "power_speed"
	power_explanation = "<b>Immortal Haste</b>:\n\
		Click anywhere to immediately dash towards that location.\n\
		The Power will not work if you are lying down, in no gravity, or are aggressively grabbed.\n\
		Anyone in your way during your Haste will be knocked down and Payalyzed, moreso if they are using Flow.\n\
		Higher levels will increase the knockdown dealt to enemies."
	power_flags = NONE
	check_flags = BP_CANT_USE_IN_TORPOR|BP_CANT_USE_IN_FRENZY|BP_CANT_USE_WHILE_INCAPACITATED|BP_CANT_USE_WHILE_UNCONSCIOUS
	purchase_flags = BLOODSUCKER_CAN_BUY|VASSAL_CAN_BUY
	bloodcost = 6
	cooldown = 12 SECONDS
	target_range = 15
	power_activates_immediately = TRUE
	var/list/hit //current hit, set while power is in use as we can't pass the list as an extra calling argument in registersignal.
	/// If set, uses this speed in deciseconds instead of world.tick_lag
	var/speed_override

/datum/action/bloodsucker/targeted/haste/CheckCanUse(display_error)
	. = ..()
	if(!.)
		return FALSE
	// Being Grabbed
	if(owner.pulledby && owner.pulledby.grab_state >= GRAB_AGGRESSIVE)
		if(display_error)
			owner.balloon_alert(owner, "you're being grabbed!")
		return FALSE
	if(!owner.has_gravity(owner.loc)) //We dont want people to be able to use this to fly around in space
		if(display_error)
			owner.balloon_alert(owner, "you cannot dash while floating!")
		return FALSE
	var/mob/living/user = owner
	if(user.body_position == LYING_DOWN)
		if(display_error)
			owner.balloon_alert(owner, "you must be standing to tackle!")
		return FALSE
	return TRUE

/// Anything will do, if it's not me or my square
/datum/action/bloodsucker/targeted/haste/CheckValidTarget(atom/A)
	return isturf(A) || A.loc != owner.loc

/datum/action/bloodsucker/targeted/haste/CheckCanTarget(atom/A, display_error)
	// DEFAULT CHECKS (Distance)
	if (!..())
		return FALSE
	// Check: Range
	//if (!(A in view(target_range, get_turf(owner))))
	//	return FALSE
	return TRUE

/// This is a non-async proc to make sure the power is "locked" until this finishes.
/datum/action/bloodsucker/targeted/haste/FireTargetedPower(atom/A)
	. = ..()
	hit = list()
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, .proc/on_move)
	var/mob/living/user = owner
	var/turf/T = isturf(A) ? A : get_turf(A)
	// Pulled? Not anymore.
	user.pulledby?.stop_pulling()
	// Go to target turf
	// DO NOT USE WALK TO.
	owner.balloon_alert(owner, "you dash into the air!")
	playsound(get_turf(owner), 'sound/weapons/punchmiss.ogg', 25, 1, -1)
	var/safety = get_dist(user, T) * 3 + 1
	var/consequetive_failures = 0
	var/speed = isnull(speed_override)? world.tick_lag : speed_override
	while(--safety && (get_turf(user) != T))
		var/success = step_towards(user, T) //This does not try to go around obstacles.
		if(!success)
			success = step_to(user, T) //this does
		if(!success)
			if(++consequetive_failures >= 3) //if 3 steps don't work
				break //just stop
		else
			consequetive_failures = 0
		if(user.resting)
			user.setDir(turn(user.dir, 90)) //down? spin2win :^)
		if(user.incapacitated(ignore_restraints = TRUE, ignore_grab = TRUE)) //actually down? stop.
			break
		if(success) //don't sleep if we failed to move.
			sleep(speed)
	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)
	hit = null

/datum/action/bloodsucker/targeted/haste/DeactivatePower(mob/living/user = owner, mob/living/target)
	..() // activate = FALSE

/datum/action/bloodsucker/targeted/haste/proc/on_move()
	for(var/mob/living/L in dview(1, get_turf(owner)))
		if(!hit[L] && (L != owner))
			hit[L] = TRUE
			playsound(L, "sound/weapons/punch[rand(1,4)].ogg", 15, 1, -1)
			L.Knockdown(10 + level_current * 5)
			L.Paralyze(0.1)
			L.spin(10, 1)
			if(IS_MONSTERHUNTER(L) && HAS_TRAIT(L, TRAIT_STUNIMMUNE))
				L.balloon_alert(L, "your victim's blood is fatally low!")
				for(var/datum/action/bloodsucker/power in L.actions)
					if(power.active)
						power.DeactivatePower()
				L.Jitter(20)
				L.set_confusion(max(8, L.get_confusion()))
				L.stuttering = max(8, L.stuttering)
				L.Knockdown(10 + level_current * 5) // Re-knock them down, the first one didn't work due to stunimmunity
