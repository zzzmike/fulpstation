/*
 *		TO PLUG INTO LIFE:
 *
 * Cancel BLOOD life
 * Cancel METABOLISM life   (or find a way to control what gets digested)
 *
 * 		EXAMINE
 *
 * Show as dead when...
 *
 * How to Burn Vamps:
 *		C.adjustFireLoss(20)
 *		C.adjust_fire_stacks(6)
 *		C.IgniteMob()
 */

/// Runs from COMSIG_LIVING_BIOLOGICAL_LIFE, handles Bloodsucker constant proccesses.
/datum/antagonist/bloodsucker/proc/LifeTick()
	SIGNAL_HANDLER

	if(!owner)
		return
	// Deduct Blood
	if(owner.current.stat == CONSCIOUS && !HAS_TRAIT(owner.current, TRAIT_IMMOBILIZED) && !HAS_TRAIT(owner.current, TRAIT_NODEATH))
		INVOKE_ASYNC(src, .proc/AddBloodVolume, passive_blood_drain) // -.1 currently
	if(HandleHealing(1))
		if(!notice_healing && owner.current.blood_volume > 0)
			to_chat(owner, span_notice("The power of your blood begins knitting your wounds..."))
			notice_healing = TRUE
	else if(notice_healing)
		notice_healing = FALSE
	// Standard Updates
	INVOKE_ASYNC(src, .proc/HandleDeath)
	INVOKE_ASYNC(src, .proc/HandleStarving)
	INVOKE_ASYNC(src, .proc/HandleTorpor)

	// Clan-unique Checks
	if(my_clan == CLAN_TREMERE)
		var/area/A = get_area(owner.current)
		if(istype(A, /area/service/chapel))
			to_chat(owner.current, span_warning("You don't belong in holy areas!"))
			owner.current.adjustFireLoss(10)
			owner.current.adjust_fire_stacks(2)
			owner.current.IgniteMob()
	if(my_clan == CLAN_MALKAVIAN)
		if(prob(85) || owner.current.stat != CONSCIOUS || HAS_TRAIT(owner.current, TRAIT_MASQUERADE))
			return
		var/message = pick(strings("malkavian_revelations.json", "revelations", "fulp_modules"))
		INVOKE_ASYNC(owner.current, /atom/movable/proc/say, message, , , , , , CLAN_MALKAVIAN)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//			BLOOD

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/antagonist/bloodsucker/proc/AddBloodVolume(value)
	owner.current.blood_volume = clamp(owner.current.blood_volume + value, 0, max_blood_volume)
	update_hud()

/datum/antagonist/bloodsucker/proc/AddHumanityLost(value)
	if(humanity_lost >= 500)
		to_chat(owner.current, span_warning("You hit the maximum amount of lost Humanty, you are far from Human."))
		return
	humanity_lost += value
	to_chat(owner.current, span_warning("You feel as if you lost some of your humanity, you will now enter Frenzy at [FRENZY_THRESHOLD_ENTER + (humanity_lost * 10)] Blood."))

/// mult: SILENT feed is 1/3 the amount
/datum/antagonist/bloodsucker/proc/HandleFeeding(mob/living/carbon/target, mult=1, power_level)
	// Starts at 15 (now 8 since we doubled the Feed time)
	var/feed_amount = 15 + (power_level * 2)
	var/blood_taken = min(feed_amount, target.blood_volume) * mult
	target.blood_volume -= blood_taken
	// Simple Animals lose a LOT of blood, and take damage. This is to keep cats, cows, and so forth from giving you insane amounts of blood.
	if(!ishuman(target))
		target.blood_volume -= (blood_taken / max(target.mob_size, 0.1)) * 3.5 // max() to prevent divide-by-zero
		target.apply_damage_type(blood_taken / 3.5) // Don't do too much damage, or else they die and provide no blood nourishment.
		if(target.blood_volume <= 0)
			target.blood_volume = 0
			target.death(0)
	///////////
	// Shift Body Temp (toward Target's temp, by volume taken)
	owner.current.bodytemperature = ((owner.current.blood_volume * owner.current.bodytemperature) + (blood_taken * target.bodytemperature)) / (owner.current.blood_volume + blood_taken)
	// our volume * temp, + their volume * temp, / total volume
	///////////
	// Reduce Value Quantity
	if(target.stat == DEAD) // Penalty for Dead Blood
		blood_taken /= 3
	if(!ishuman(target)) // Penalty for Non-Human Blood
		blood_taken /= 2
	//if (!iscarbon(target)) // Penalty for Animals (they're junk food)
	// Apply to Volume
	AddBloodVolume(blood_taken)
	// Reagents (NOT Blood!)
	if(target.reagents && target.reagents.total_volume)
		target.reagents.trans_to(owner.current, INGEST, 1) // Run transfer of 1 unit of reagent from them to me.
	owner.current.playsound_local(null, 'sound/effects/singlebeat.ogg', 40, 1) // Play THIS sound for user only. The "null" is where turf would go if a location was needed. Null puts it right in their head.
	total_blood_drank += blood_taken
	if(frenzied)
		frenzy_blood_drank += blood_taken
	return blood_taken

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//			HEALING

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// It is called from your coffin on close (by you only)
/datum/antagonist/bloodsucker/proc/HandleHealing(mult = 1)
	var/actual_regen = bloodsucker_regen_rate + additional_regen
	// Don't heal if I'm staked or on Masquerade (+ not in a Coffin). Masqueraded Bloodsuckers in a Coffin however, will heal.
	if(owner.current.AmStaked() || (HAS_TRAIT(owner.current, TRAIT_MASQUERADE) && !HAS_TRAIT(owner.current, TRAIT_NODEATH)))
		return FALSE
	owner.current.adjustCloneLoss(-1 * (actual_regen * 4) * mult, 0)
	owner.current.adjustOrganLoss(ORGAN_SLOT_BRAIN, -1 * (actual_regen * 4) * mult) //adjustBrainLoss(-1 * (actual_regen * 4) * mult, 0)
	if(iscarbon(owner.current)) // Damage Heal: Do I have damage to ANY bodypart?
		var/mob/living/carbon/C = owner.current
		var/costMult = 1 // Coffin makes it cheaper
		var/bruteheal = min(C.getBruteLoss_nonProsthetic(), actual_regen) // BRUTE: Always Heal
		var/fireheal = 0 // BURN: Heal in Coffin while Fakedeath, or when damage above maxhealth (you can never fully heal fire)
		/// Checks if you're in a coffin here, additionally checks for Torpor right below it.
		var/amInCoffin = istype(C.loc, /obj/structure/closet/crate/coffin)
		if(amInCoffin && HAS_TRAIT(C, TRAIT_NODEATH))
			if(HAS_TRAIT(owner.current, TRAIT_MASQUERADE))
				to_chat(C, span_warning("You will not heal while your Masquerade ability is active."))
				return
			fireheal = min(C.getFireLoss_nonProsthetic(), actual_regen)
			mult *= 5 // Increase multiplier if we're sleeping in a coffin.
			costMult /= 2 // Decrease cost if we're sleeping in a coffin.
			C.extinguish_mob()
			C.remove_all_embedded_objects() // Remove Embedded!
			if(check_limbs(costMult))
				return TRUE
		// In Torpor, but not in a Coffin? Heal faster anyways.
		else if(HAS_TRAIT(C, TRAIT_NODEATH))
			mult *= 3
		// Heal if Damaged
		if((bruteheal + fireheal > 0) && mult != 0) // Just a check? Don't heal/spend, and return.
			// We have damage. Let's heal (one time)
			C.adjustBruteLoss(-bruteheal * mult, forced=TRUE) // Heal BRUTE / BURN in random portions throughout the body.
			C.adjustFireLoss(-fireheal * mult, forced=TRUE)
			AddBloodVolume(((bruteheal * -0.5) + (fireheal * -1)) * costMult * mult) // Costs blood to heal
			return TRUE

/datum/antagonist/bloodsucker/proc/check_limbs(costMult = 1)
	var/limb_regen_cost = 50 * -costMult
	var/mob/living/carbon/C = owner.current
	var/list/missing = C.get_missing_limbs()
	if(missing.len && C.blood_volume < limb_regen_cost + 5)
		return FALSE
	for(var/targetLimbZone in missing) // 1) Find ONE Limb and regenerate it.
		C.regenerate_limb(targetLimbZone, FALSE) // regenerate_limbs() <--- If you want to EXCLUDE certain parts, do it like this ----> regenerate_limbs(0, list("head"))
		AddBloodVolume(limb_regen_cost)
		var/obj/item/bodypart/L = C.get_bodypart(targetLimbZone) // 2) Limb returns Damaged
		L.brute_dam = 60
		to_chat(C, span_notice("Your flesh knits as it regrows your [L]!"))
		playsound(C, 'sound/magic/demon_consume.ogg', 50, TRUE)
		return TRUE

/*
 *	# Heal Vampire Organs
 *
 *	This is used by Bloodsuckers, these are the steps of this proc:
 *	Step 1 - Cure husking and Regenerate organs. regenerate_organs() removes their Vampire Heart & Eye augments, which leads us to...
 *	Step 2 - Repair any (shouldnt be possible) Organ damage, then return their Vampiric Heart & Eye benefits.
 *	Step 3 - Revive them, clear all wounds, remove any Tumors (If any).
 *
 *	This is called on Bloodsucker's Assign, and when they end Torpor.
 */

/datum/antagonist/bloodsucker/proc/HealVampireOrgans()
	var/mob/living/carbon/bloodsuckeruser = owner.current

	// Step 1
	bloodsuckeruser.cure_husk()
	bloodsuckeruser.regenerate_organs()

	// Step 2 NOTE: Giving passive organ regeneration will cause Torpor to spam /datum/client_colour/monochrome at the Bloodsucker, permanently making them colorblind!
	for(var/O in bloodsuckeruser.internal_organs)
		var/obj/item/organ/organ = O
		organ.setOrganDamage(0)
	var/obj/item/organ/heart/O = bloodsuckeruser.getorganslot(ORGAN_SLOT_HEART)
	if(!istype(O, /obj/item/organ/heart/vampheart) || !istype(O, /obj/item/organ/heart/demon) || !istype(O, /obj/item/organ/heart/cursed))
		qdel(O)
		var/obj/item/organ/heart/vampheart/H = new
		H.Insert(owner.current)
		H.Stop()
	var/obj/item/organ/eyes/E = bloodsuckeruser.getorganslot(ORGAN_SLOT_EYES)
	if(E)
		E.flash_protect = max(initial(E.flash_protect) - 1, FLASH_PROTECTION_SENSITIVE)
		E.sight_flags = SEE_MOBS
		E.see_in_dark = 8
		E.lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE
	bloodsuckeruser.update_sight()

	// Step 3
	if(bloodsuckeruser.stat == DEAD)
		bloodsuckeruser.revive(full_heal = FALSE, admin_revive = FALSE)
	for(var/i in bloodsuckeruser.all_wounds)
		var/datum/wound/iter_wound = i
		iter_wound.remove_wound()
	// From [powers/panacea.dm]
	var/list/bad_organs = list(
		bloodsuckeruser.getorgan(/obj/item/organ/body_egg),
		bloodsuckeruser.getorgan(/obj/item/organ/zombie_infection))
	for(var/tumors in bad_organs)
		var/obj/item/organ/yucky_organs = tumors
		if(!istype(yucky_organs))
			continue
		yucky_organs.Remove(bloodsuckeruser)
		yucky_organs.forceMove(get_turf(bloodsuckeruser))

	// Part of Malkavian? Give them their traumas back.
	if(my_clan == CLAN_MALKAVIAN)
		bloodsuckeruser.gain_trauma(/datum/brain_trauma/mild/hallucinations, TRAUMA_RESILIENCE_ABSOLUTE)
		bloodsuckeruser.gain_trauma(/datum/brain_trauma/special/bluespace_prophet, TRAUMA_RESILIENCE_ABSOLUTE)
	// Good to go!

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//			DEATH

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// FINAL DEATH
/datum/antagonist/bloodsucker/proc/HandleDeath()
	/// Not "Alive"?
	if(!owner.current || !isliving(owner.current) || isbrain(owner.current) || !get_turf(owner.current))
		FinalDeath()
		return
	/// Fire Damage? (above double health)
	if(owner.current.getFireLoss() >= owner.current.maxHealth * 2.5)
		FinalDeath()
		return
	/// Staked while "Temp Death" or Asleep
	if(owner.current.StakeCanKillMe() && owner.current.AmStaked())
		FinalDeath()
		return
	/// Not organic/living? (Zombie/Skeleton/Plasmaman)
	if(!(owner.current.mob_biotypes & MOB_ORGANIC))
		FinalDeath()
		return
	/* !! Removed due to killing Slimepeople. Replaced with the ORGANIC check above. Torpor should be checking their organs anyways.
	// Missing Brain or Heart?
	if(!owner.current.HaveBloodsuckerBodyparts())
		FinalDeath()
		return
	*/
	/*
	// Disable Powers: Masquerade * NOTE * This should happen as a FLAW!
	if(stat >= UNCONSCIOUS)
		for(var/datum/action/bloodsucker/masquerade/P in powers)
			P.Deactivate()
	*/
	/// Temporary Death? Convert to Torpor.
	if(owner.current.stat == DEAD)
		var/mob/living/carbon/human/H = owner.current
		/// We won't use the spam check if they're on masquerade, we want to spam them until they notice, else they'll cry to me about shit being broken.
		if(HAS_TRAIT(owner.current, TRAIT_MASQUERADE))
			to_chat(H, span_warning("Your wounds will not heal until you disable the <span class='boldnotice'>Masquerade</span> power."))
		else if(!HAS_TRAIT(H, TRAIT_NODEATH))
			to_chat(H, span_danger("Your immortal body will not yet relinquish your soul to the abyss. You enter Torpor."))
			Check_Begin_Torpor(TRUE)

/*
 *	High: 	Faster Healing
 *	Med: 	Pale
 *	Low: 	Twitch
 *	V.Low:   Blur Vision
 *	EMPTY:	Frenzy!
 */

/// I am thirsty for blood!
/datum/antagonist/bloodsucker/proc/HandleStarving()
	// Nutrition - The amount of blood is how full we are.
	owner.current.set_nutrition(min(owner.current.blood_volume, NUTRITION_LEVEL_FED))

	// BLOOD_VOLUME_GOOD: [336] - Pale
//	handled in bloodsucker_integration.dm

	// BLOOD_VOLUME_EXIT: [250] - Exit Frenzy (If in one) This is high because we want enough to kill the poor soul they feed off of.
	if(owner.current.blood_volume >= FRENZY_THRESHOLD_EXIT && frenzied && my_clan != CLAN_BRUJAH)
		owner.current.remove_status_effect(STATUS_EFFECT_FRENZY)
	// BLOOD_VOLUME_BAD: [224] - Jitter
	if(owner.current.blood_volume < BLOOD_VOLUME_BAD && prob(0.5) && !HAS_TRAIT(owner.current, TRAIT_NODEATH) && !HAS_TRAIT(owner.current, TRAIT_MASQUERADE))
		owner.current.Jitter(3)
	// BLOOD_VOLUME_SURVIVE: [122] - Blur Vision
	if(owner.current.blood_volume < BLOOD_VOLUME_SURVIVE)
		owner.current.blur_eyes(8 - 8 * (owner.current.blood_volume / BLOOD_VOLUME_BAD))

	// The more blood, the better the Regeneration, get too low blood, and you enter Frenzy.
	if(owner.current.blood_volume < (FRENZY_THRESHOLD_ENTER + (humanity_lost * 10)) && !frenzied)
		if(my_clan != CLAN_BRUJAH)
			owner.current.apply_status_effect(STATUS_EFFECT_FRENZY)
		else
			for(var/datum/action/bloodsucker/power in powers)
				if(istype(power, /datum/action/bloodsucker/brujah))
					if(power.active)
						return
					power.ActivatePower()
	else if(owner.current.blood_volume < BLOOD_VOLUME_BAD)
		additional_regen = 0.1
	else if(owner.current.blood_volume < BLOOD_VOLUME_OKAY)
		additional_regen = 0.2
	else if(owner.current.blood_volume < BLOOD_VOLUME_NORMAL)
		additional_regen = 0.3
	else if(owner.current.blood_volume < BS_BLOOD_VOLUME_MAX_REGEN)
		additional_regen = 0.4
	else
		additional_regen = 0.5

/*
	# Torpor

	Torpor is what deals with the Bloodsucker falling asleep, their healing, the effects, ect.
	This is basically what Sol is meant to do to them, but they can also trigger it manually if they wish to heal, as Burn is only healed through Torpor.
	You cannot manually exit Torpor, it is instead entered/exited by:

	Torpor is triggered by:
	- Being in a Coffin while Sol is on, dealt with by /HandleTorpor()
	- Entering a Coffin with more than 10 combined Brute/Burn damage, dealt with by /closet/crate/coffin/close() [bloodsucker_coffin.dm]
	- Death, dealt with by /HandleDeath()
	Torpor is ended by:
	- Having less than 10 Brute damage while OUTSIDE of your Coffin while it isnt Sol, dealt with by /HandleTorpor()
	- Having less than 10 Brute & Burn Combined while INSIDE of your Coffin while it isnt Sol, dealt with by /HandleTorpor()
	- Sol being over, dealt with by /sunlight/process() [bloodsucker_daylight.dm]
*/

/datum/antagonist/bloodsucker/proc/HandleTorpor()
	if(!owner.current)
		return
	if(istype(owner.current.loc, /obj/structure/closet/crate/coffin))
		if(!HAS_TRAIT(owner.current, TRAIT_NODEATH))
			/// Staked? Dont heal
			if(owner.current.AmStaked())
				to_chat(owner.current, span_userdanger("You are staked! Remove the offending weapon from your heart before sleeping."))
				return
			/// Otherwise, check if it's Sol, to enter Torpor.
			if(clan.bloodsucker_sunlight.amDay)
				Check_Begin_Torpor(TRUE)
	if(HAS_TRAIT(owner.current, TRAIT_NODEATH)) // Check so I don't go insane.
		Check_End_Torpor()

/datum/antagonist/bloodsucker/proc/Check_Begin_Torpor(SkipChecks = FALSE)
	/// Are we entering Torpor via Sol/Death? Then entering it isnt optional!
	if(SkipChecks)
		Torpor_Begin()
		return
	var/mob/living/carbon/user = owner.current
	var/total_brute = user.getBruteLoss_nonProsthetic()
	var/total_burn = user.getFireLoss_nonProsthetic()
	var/total_damage = total_brute + total_burn
	/// Checks - Not daylight & Has more than 10 Brute/Burn & not already in Torpor
	if(!clan.bloodsucker_sunlight.amDay && total_damage >= 10 && !HAS_TRAIT(owner.current, TRAIT_NODEATH))
		Torpor_Begin()

/datum/antagonist/bloodsucker/proc/Check_End_Torpor()
	var/mob/living/carbon/user = owner.current
	var/total_brute = user.getBruteLoss_nonProsthetic()
	var/total_burn = user.getFireLoss_nonProsthetic()
	var/total_damage = total_brute + total_burn
	// You are in a Coffin, so instead we'll check TOTAL damage, here.
	if(istype(user.loc, /obj/structure/closet/crate/coffin))
		if(!clan.bloodsucker_sunlight.amDay && total_damage <= 10)
			Torpor_End()
	// You're not in a Coffin? We won't check for low Burn damage
	else if(!clan.bloodsucker_sunlight.amDay && total_brute <= 10)
		// You're under 10 brute, but over 200 Burn damage? Don't exit Torpor, to prevent spam revival/death. Only way out is healing that Burn.
		if(total_burn >= 199)
			return
		Torpor_End()

/datum/antagonist/bloodsucker/proc/Torpor_Begin()
	to_chat(owner.current, span_notice("You enter the horrible slumber of deathless Torpor. You will heal until you are renewed."))
	/// Force them to go to sleep
	REMOVE_TRAIT(owner.current, TRAIT_SLEEPIMMUNE, BLOODSUCKER_TRAIT)
	/// Without this, you'll just keep dying while you recover.
	ADD_TRAIT(owner.current, TRAIT_NODEATH, BLOODSUCKER_TRAIT)
	ADD_TRAIT(owner.current, TRAIT_FAKEDEATH, BLOODSUCKER_TRAIT)
	ADD_TRAIT(owner.current, TRAIT_DEATHCOMA, BLOODSUCKER_TRAIT)
	ADD_TRAIT(owner.current, TRAIT_RESISTLOWPRESSURE, BLOODSUCKER_TRAIT)
	owner.current.Jitter(0)
	/// Disable ALL Powers
	DisableAllPowers()

/datum/antagonist/bloodsucker/proc/Torpor_End()
	owner.current.grab_ghost()
	to_chat(owner.current, span_warning("You have recovered from Torpor."))
	REMOVE_TRAIT(owner.current, TRAIT_RESISTLOWPRESSURE, BLOODSUCKER_TRAIT)
	REMOVE_TRAIT(owner.current, TRAIT_DEATHCOMA, BLOODSUCKER_TRAIT)
	REMOVE_TRAIT(owner.current, TRAIT_FAKEDEATH, BLOODSUCKER_TRAIT)
	REMOVE_TRAIT(owner.current, TRAIT_NODEATH, BLOODSUCKER_TRAIT)
	ADD_TRAIT(owner.current, TRAIT_SLEEPIMMUNE, BLOODSUCKER_TRAIT)
	HealVampireOrgans()

/// Gibs the Bloodsucker, roundremoving them.
/datum/antagonist/bloodsucker/proc/FinalDeath()
	// Check for non carbons and end it early.
	if(!iscarbon(owner.current))
		owner.current.gib()
		return

	// End Bloodsucker processes
	UnregisterSignal(owner.current, COMSIG_LIVING_BIOLOGICAL_LIFE)
	FreeAllVassals()
	DisableAllPowers()
	// Drop anything in us and play a tune
	owner.current.drop_all_held_items()
	owner.current.unequip_everything()
	var/mob/living/carbon/C = owner.current
	C.remove_all_embedded_objects()
	playsound(owner.current, 'sound/effects/tendril_destroyed.ogg', 40, TRUE)
	// Elders get dusted, Fledglings get gibbed
	if(bloodsucker_level >= 4)
		owner.current.visible_message(
			span_warning("[owner.current]'s skin crackles and dries, their skin and bones withering to dust. A hollow cry whips from what is now a sandy pile of remains."),
			span_userdanger("Your soul escapes your withering body as the abyss welcomes you to your Final Death."),
			span_hear("You hear a dry, crackling sound."))
		addtimer(CALLBACK(owner.current, /mob/living.proc/dust), 5 SECONDS, TIMER_UNIQUE|TIMER_STOPPABLE)
		return
	owner.current.visible_message(
		span_warning("[owner.current]'s skin bursts forth in a spray of gore and detritus. A horrible cry echoes from what is now a wet pile of decaying meat."),
		span_userdanger("Your soul escapes your withering body as the abyss welcomes you to your Final Death."),
		span_hear("<span class='italics'>You hear a wet, bursting sound."))
	owner.current.gib(TRUE, FALSE, FALSE)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//			HUMAN FOOD

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
/// This isnt ever called, someone should really add it eventually...
/mob/proc/CheckBloodsuckerEatFood(food_nutrition)
	if(!isliving(src))
		return
	var/mob/living/L = src
	if(!IS_BLOODSUCKER(L))
		return
	// We're a bloodsucker? Try to eat food...
	var/datum/antagonist/bloodsucker/B = L.mind.has_antag_datum(/datum/antagonist/bloodsucker)
	B.handle_eat_human_food(food_nutrition)


/datum/antagonist/bloodsucker/proc/handle_eat_human_food(food_nutrition, puke_blood = TRUE, masquerade_override) // Called from snacks.dm and drinks.dm
	set waitfor = FALSE
	if(!owner.current || !iscarbon(owner.current))
		return
	var/mob/living/carbon/C = owner.current
	// Remove Nutrition, Give Bad Food
	C.adjust_nutrition(-food_nutrition)
	foodInGut += food_nutrition
	// Already ate some bad clams? Then we can back out, because we're already sick from it.
	if(foodInGut != food_nutrition)
		return
	// Haven't eaten, but I'm in a Human Disguise.
	else if(HAS_TRAIT(owner.current, TRAIT_MASQUERADE) && !masquerade_override)
		to_chat(C, span_notice("Your stomach turns, but your \"human disguise\" keeps the food down...for now."))
	// Keep looping until we purge. If we have activated our Human Disguise, we ignore the food. But it'll come up eventually...
	var/sickphase = 0
	while(foodInGut && do_mob(C, C, 5 SECONDS, timed_action_flags = (IGNORE_USER_LOC_CHANGE|IGNORE_TARGET_LOC_CHANGE|IGNORE_HELD_ITEM|IGNORE_INCAPACITATED), progress = FALSE))
		C.adjust_disgust(10 * sickphase)
		// Wait an interval...
		sleep(50 + 50 * sickphase) // At intervals of 100, 150, and 200. (10 seconds, 15 seconds, and 20 seconds)
		// Died? Cancel
		if(C.stat == DEAD)
			return
		// Put up disguise? Then hold off the vomit.
		if(HAS_TRAIT(owner.current, TRAIT_MASQUERADE) && !masquerade_override)
			if(sickphase > 0)
				to_chat(C, span_notice("Your stomach settles temporarily. You regain your composure...for now."))
			sickphase = 0
			continue
		switch(sickphase)
			if(1)
				to_chat(C, span_warning("You feel unwell. You can taste ash on your tongue."))
				C.Stun(10)
			if(2)
				to_chat(C, span_warning("Your stomach turns. Whatever you ate tastes of grave dirt and brimstone."))
				C.Dizzy(15)
				C.Stun(13)
			if(3)
				to_chat(C, span_warning("You purge the food of the living from your viscera! You've never felt worse."))
				 //Puke blood only if puke_blood is true, and loose some blood, else just puke normally.
				if(puke_blood)
					C.blood_volume = max(0, C.blood_volume - foodInGut * 2)
					C.vomit(foodInGut * 4, foodInGut * 2, 0)
				else
					C.vomit(foodInGut * 4, FALSE, 0)
				C.Stun(30)
				//C.Dizzy(50)
				foodInGut = 0
				SEND_SIGNAL(C, COMSIG_ADD_MOOD_EVENT, "vampdisgust", /datum/mood_event/bloodsucker_disgust)
		sickphase++
*/

/// Bloodsuckers moodlets
/datum/mood_event/drankblood
	description = "<span class='nicegreen'>I have fed greedly from that which nourishes me.</span>\n"
	mood_change = 10
	timeout = 8 MINUTES

/datum/mood_event/drankblood_bad
	description = "<span class='boldwarning'>I drank the blood of a lesser creature. Disgusting.</span>\n"
	mood_change = -4
	timeout = 3 MINUTES

/datum/mood_event/drankblood_dead
	description = "<span class='boldwarning'>I drank dead blood. I am better than this.</span>\n"
	mood_change = -7
	timeout = 8 MINUTES

/datum/mood_event/drankblood_synth
	description = "<span class='boldwarning'>I drank synthetic blood. What is wrong with me?</span>\n"
	mood_change = -7
	timeout = 8 MINUTES

/datum/mood_event/drankkilled
	description = "<span class='boldwarning'>I drank from my victim until they died. I feel... less human.</span>\n"
	mood_change = -15
	timeout = 10 MINUTES

/datum/mood_event/madevamp
	description = "<span class='boldwarning'>A soul has been cursed to undeath by my own hand.</span>\n"
	mood_change = 15
	timeout = 20 MINUTES

/datum/mood_event/vampatefood
	description = "<span class='boldwarning'>Mortal nourishment no longer sustains me. I feel unwell.</span>\n"
	mood_change = -6
	timeout = 8 MINUTES

/datum/mood_event/coffinsleep
	description = "<span class='nicegreen'>I slept in a coffin during the day. I feel whole again.</span>\n"
	mood_change = 10
	timeout = 6 MINUTES

/datum/mood_event/daylight_1
	description = "<span class='boldwarning'>I slept poorly in a makeshift coffin during the day.</span>\n"
	mood_change = -3
	timeout = 6 MINUTES

/datum/mood_event/daylight_2
	description = "<span class='boldwarning'>I have been scorched by the unforgiving rays of the sun.</span>\n"
	mood_change = -6
	timeout = 6 MINUTES

/datum/mood_event/bloodsucker_disgust
	description = "<span class='boldwarning'>Something I recently ate was horrifyingly disgusting.</span>\n"
	mood_change = -5
	timeout = 5 MINUTES

/// Candelabrum
/datum/mood_event/vampcandle
	description = "<span class='boldwarning'>Something is making your mind feel... loose.</span>\n"
	mood_change = -15
	timeout = 5 MINUTES

