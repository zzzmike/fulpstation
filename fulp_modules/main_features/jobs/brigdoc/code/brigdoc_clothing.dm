/*
Contains:
	Medical security beret
	Armored labcoat
	Surgery tool-filled medical belt
	Brig physician's jumpsuit
	Brig physician's jumpskirt
	Brig physician's envirosuit
	Brig physician's envirosuit helmet
*/

// Beret

/obj/item/clothing/head/fulpberet/brigphysician
	name = "medical security beret"
	desc = "This proud white-blue beret is a distinct color, mainly used to represent medical professionals that became part of the security department."
	worn_icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_worn.dmi'
	icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_icons.dmi'
	icon_state = "beret_medbay"

// Labcoat

/obj/item/clothing/suit/toggle/labcoat/armored
	name = "armored labcoat"
	desc = "A specialized labcoat with kevlar treading as to provide protection to field doctors."
	worn_icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_worn.dmi'
	icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_icons.dmi'
	icon_state = "labcoat_brigdoc"
	inhand_icon_state = "labcoat"
	blood_overlay_type = "coat"
	body_parts_covered = CHEST|ARMS|GROIN
	allowed = list(/obj/item/analyzer, /obj/item/stack/medical, /obj/item/dnainjector, /obj/item/reagent_containers/dropper, /obj/item/reagent_containers/syringe, /obj/item/reagent_containers/hypospray, /obj/item/healthanalyzer, /obj/item/flashlight/pen, /obj/item/reagent_containers/glass/bottle, /obj/item/reagent_containers/glass/beaker, /obj/item/reagent_containers/pill, /obj/item/storage/pill_bottle, /obj/item/paper, /obj/item/melee/baton/telescopic, /obj/item/soap, /obj/item/sensor_device, /obj/item/tank/internals/emergency_oxygen, /obj/item/tank/internals/plasmaman, /obj/item/melee/baton)
	armor = list(MELEE = 25, BULLET = 25, LASER = 25, ENERGY = 30, BOMB = 20, BIO = 50, RAD = 0, FIRE = 50, ACID = 50, WOUND = 10)

// Surgery belt
/obj/item/storage/belt/medical/surgeryfilled/PopulateContents()
	new /obj/item/healthanalyzer(src)
	new /obj/item/scalpel(src)
	new /obj/item/hemostat(src)
	new /obj/item/retractor(src)
	new /obj/item/circular_saw(src)
	new /obj/item/cautery(src)
	new /obj/item/surgical_drapes(src)

// Jumpsuit and Jumpskirt

/obj/item/clothing/under/rank/medical/brigdoc
	name = "brig physician's jumpsuit"
	desc = "It's made of a special fiber that provides minor protection against biohazards and Close Quarters weaponry. It has a brig physician stripe on it."
	worn_icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_worn.dmi'
	icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_icons.dmi'
	icon_state = "jumpsuit_brigdoc"
	permeability_coefficient = 0.5
	armor = list(MELEE = 10, BULLET = 0, LASER = 0,ENERGY = 0, BOMB = 0, BIO = 10, RAD = 0, FIRE = 30, ACID = 30)
	can_adjust = FALSE
	sensor_mode = SENSOR_COORDS
	random_sensor = FALSE

/obj/item/clothing/under/rank/medical/brigdoc/skirt
	name = "brig physician's jumpskirt"
	icon_state = "jumpskirt_brigdoc"
	fitted = FEMALE_UNIFORM_TOP

// Envirosuit and Envirohelmet

/obj/item/clothing/under/plasmaman/brigdoc
	name = "brig physician's envirosuit"
	desc = "A lightly armoured envirosuit for our plasmamen Brig Physicians."
	worn_icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_worn.dmi'
	icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_icons.dmi'
	icon_state = "envirosuit_brigdoc"
	permeability_coefficient = 0.5
	armor = list(MELEE = 10, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 100, RAD = 0, FIRE = 95, ACID = 95)
	sensor_mode = SENSOR_COORDS
	random_sensor = FALSE

/obj/item/clothing/head/helmet/space/plasmaman/brigdoc
	name = "brig physician's plasma envirosuit helmet"
	desc = "A plasmaman containment helmet for brig physicians."
	worn_icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_worn.dmi'
	icon = 'fulp_modules/main_features/jobs/brigdoc/icons/clothing_icons.dmi'
	icon_state = "brigdoc_envirohelm"
	inhand_icon_state = "security_envirohelm"
