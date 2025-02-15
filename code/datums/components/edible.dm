/*!
This component makes it possible to make things edible. What this means is that you can take a bite or force someone to take a bite (in the case of items).
These items take a specific time to eat, and can do most of the things our original food items could.
Behavior that's still missing from this component that original food items had that should either be put into seperate components or somewhere else:
	Components:
	Drying component (jerky etc)
	Customizable component (custom pizzas etc)
	Processable component (Slicing and cooking behavior essentialy, making it go from item A to B when conditions are met.)
	Dunkable component (Dunking things into reagent containers to absorb a specific amount of reagents)
	Misc:
	Something for cakes (You can store things inside)
*/
/datum/component/edible
	///Amount of reagents taken per bite
	var/bite_consumption = 2
	///Amount of bites taken so far
	var/bitecount = 0
	///Flags for food
	var/food_flags = NONE
	///Bitfield of the types of this food
	var/foodtypes = NONE
	///Amount of seconds it takes to eat this food
	var/eat_time = 30
	///Defines how much it lowers someones satiety (Need to eat, essentialy)
	var/junkiness = 0
	///Message to send when eating
	var/list/eatverbs
	///Callback to be ran for when you take a bite of something
	var/datum/callback/after_eat
	///Last time we checked for food likes
	var/last_check_time

/datum/component/edible/Initialize(list/initial_reagents, food_flags = NONE, foodtypes = NONE, volume = 50, eat_time = 30, list/tastes, list/eatverbs = list("bite","chew","nibble","gnaw","gobble","chomp"), bite_consumption = 2, datum/callback/after_eat)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE

	RegisterSignal(parent, COMSIG_PARENT_EXAMINE, .proc/examine)
	RegisterSignal(parent, COMSIG_ATOM_ATTACK_ANIMAL, .proc/UseByAnimal)
	if(isitem(parent))
		RegisterSignal(parent, COMSIG_ITEM_ATTACK, .proc/UseFromHand)
	else if(isturf(parent))
		RegisterSignal(parent, COMSIG_ATOM_ATTACK_HAND, .proc/TryToEatTurf)

	src.bite_consumption = bite_consumption
	src.food_flags = food_flags
	src.foodtypes = foodtypes
	src.eat_time = eat_time
	src.eatverbs = eatverbs
	src.junkiness = junkiness
	src.after_eat = after_eat

	var/atom/owner = parent

	if(!owner.reagents) //we don't want to override what's in the item if it possibly contains reagents already
		owner.create_reagents(volume, INJECTABLE)

	if(initial_reagents)
		for(var/rid in initial_reagents)
			var/amount = initial_reagents[rid]
			if(tastes && tastes.len && (rid == /datum/reagent/consumable/nutriment || rid == /datum/reagent/consumable/nutriment/vitamin))
				owner.reagents.add_reagent(rid, amount, tastes.Copy())
			else
				owner.reagents.add_reagent(rid, amount)

/datum/component/edible/proc/examine(datum/source, mob/user, list/examine_list)
	if(!(food_flags & FOOD_IN_CONTAINER))
		switch (bitecount)
			if (0)
				return
			if(1)
				examine_list += "[parent] was bitten by someone!"
			if(2,3)
				examine_list += "[parent] was bitten [bitecount] times!"
			else
				examine_list += "[parent] was bitten multiple times!"

/datum/component/edible/proc/UseFromHand(obj/item/source, mob/living/M, mob/living/user)
	return TryToEat(M, user)

/datum/component/edible/proc/TryToEatTurf(datum/source, mob/user)
	return TryToEat(user, user)

///All the checks for the act of eating itself and
/datum/component/edible/proc/TryToEat(mob/living/eater, mob/living/feeder)

	set waitfor = FALSE

	var/atom/owner = parent

	if(feeder.a_intent == INTENT_HARM)
		return
	if(!owner.reagents.total_volume)//Shouldn't be needed but it checks to see if it has anything left in it.
		to_chat(feeder, SPAN_WARNING("None of [owner] left, oh no!"))
		if(isturf(parent))
			var/turf/T = parent
			T.ScrapeAway(1, CHANGETURF_INHERIT_AIR)
		else
			qdel(parent)
		return
	if(!CanConsume(eater, feeder))
		return
	var/fullness = eater.nutrition + 10 //The theoretical fullness of the person eating if they were to eat this
	for(var/datum/reagent/consumable/C in eater.reagents.reagent_list) //we add the nutrition value of what we're currently digesting
		fullness += C.nutriment_factor * C.volume / C.metabolization_rate

	. = COMPONENT_ITEM_NO_ATTACK //Point of no return I suppose

	var/time_to_eat = eat_time
	if(HAS_TRAIT(eater, TRAIT_VORACIOUS))
		time_to_eat *= 0.5 // faster to eat, also faster to be fed
	if(eater == feeder)//If you're eating it yourself.
		if(!do_mob(feeder, eater, time_to_eat)) //Gotta pass the minimal eat time
			return
		var/eatverb = pick(eatverbs)
		if(junkiness && eater.satiety < -150 && eater.nutrition > NUTRITION_LEVEL_STARVING + 50)
			if(HAS_TRAIT(eater, TRAIT_VORACIOUS))
				to_chat(eater, span_notice("You happily choke down yet more junk food!"))
				eater.adjust_disgust(-1)
			else
				to_chat(eater, SPAN_DANGER("You feel sick as you choke down yet more junk food!"))
				eater.adjust_disgust(1)
		switch(fullness)
			if(-INFINITY to 50)
				if(HAS_TRAIT(eater, TRAIT_VORACIOUS))
					eater.visible_message(
						span_notice("[eater] ravenously [eatverb]s \the [parent], gobbling it down!"), 
						span_notice("You ravenously [eatverb] \the [parent], gobbling it down!"))
				else
					eater.visible_message(
						span_notice("[eater] hungrily [eatverb]s \the [parent], gobbling it down!"), 
						span_notice("You hungrily [eatverb] \the [parent], gobbling it down!"))
			if(50 to 200)
				if(HAS_TRAIT(eater, TRAIT_VORACIOUS))
					eater.visible_message(
						span_notice("[eater] ravenously [eatverb]s \the [parent]!"), 
						span_notice("You ravenously [eatverb] \the [parent]!"))
				else
					eater.visible_message(
						span_notice("[eater] hungrily [eatverb]s \the [parent]."), 
						span_notice("You hungrily [eatverb] \the [parent]."))
			if(200 to 500)
				if(HAS_TRAIT(eater, TRAIT_VORACIOUS))
					eater.visible_message(
						span_notice("[eater] vigorously [eatverb]s \the [parent]!"), 
						span_notice("You vigorously [eatverb] \the [parent]!"))
				else
					eater.visible_message(
						span_notice("[eater] [eatverb]s \the [parent]."), 
						span_notice("You [eatverb] \the [parent]."))
			if(500 to 650)
				if(HAS_TRAIT(eater, TRAIT_VORACIOUS))
					eater.visible_message(
						span_notice("[eater] gluttonously [eatverb]s \the [parent]!"), 
						span_notice("You gluttonously [eatverb] \the [parent]!"))
				else
					eater.visible_message(
						span_notice("[eater] unwillingly [eatverb]s \the [parent]."), 
						span_notice("You unwillingly [eatverb] \the [parent]."))
			if((600 * (1 + eater.overeatduration / 1000)) to INFINITY)
				if(HAS_TRAIT(eater, TRAIT_VORACIOUS))
					eater.visible_message(
						span_notice("[eater] gluttonously [eatverb]s \the [parent], cramming it down [eater.p_their()] throat!"), 
						span_notice("You gluttonously [eatverb] \the [parent], cramming it down your throat!"))
				else
					eater.visible_message(
						SPAN_WARNING("[eater] cannot force any more of \the [parent] to go down [eater.p_their()] throat!"), 
						SPAN_WARNING("You cannot force any more of \the [parent] to go down your throat!"))
					return
	else //If you're feeding it to someone else.
		if(isbrain(eater))
			to_chat(feeder, SPAN_WARNING("[eater] doesn't seem to have a mouth!"))
			return
		if(fullness <= (600 * (1 + eater.overeatduration / 1000)) || HAS_TRAIT(eater, TRAIT_VORACIOUS))
			eater.visible_message(
				SPAN_WARNING("[feeder] attempts to feed [eater] [parent]."),
				span_userdanger("[feeder] attempts to feed you [parent]."))
		else
			eater.visible_message(
				SPAN_WARNING("[feeder] cannot force any more of [parent] down [eater]'s throat!"),
				SPAN_WARNING("[feeder] cannot force any more of [parent] down your throat!"))
			return
		if(!do_mob(feeder, eater, time_to_eat)) //Wait 3 / 1.5 seconds before you can feed
			return

		log_combat(feeder, eater, "fed", owner.reagents.log_list())
		eater.visible_message(
			SPAN_DANGER("[feeder] forces [eater] to eat [parent]!</span>"),
			span_userdanger("[feeder] forces you to eat [parent]!</span>"))

	TakeBite(eater, feeder)

///This function lets the eater take a bite and transfers the reagents to the eater.
/datum/component/edible/proc/TakeBite(mob/living/eater, mob/living/feeder)

	var/atom/owner = parent

	if(!owner?.reagents)
		return FALSE
	if(eater.satiety > -200)
		eater.satiety -= junkiness
	playsound(eater.loc,'sound/items/eatfood.ogg', rand(10,50), TRUE)
	if(owner.reagents.total_volume)
		SEND_SIGNAL(parent, COMSIG_FOOD_EATEN, eater, feeder)
		var/fraction = min(bite_consumption / owner.reagents.total_volume, 1)
		owner.reagents.reaction(eater, INGEST, fraction)
		owner.reagents.trans_to(eater, bite_consumption)
		bitecount++
		On_Consume(eater)
		checkLiked(fraction, eater)

		//Invoke our after eat callback if it is valid
		if(after_eat)
			after_eat.Invoke(eater, feeder)

		return TRUE

///Checks whether or not the eater can actually consume the food
/datum/component/edible/proc/CanConsume(mob/living/eater, mob/living/feeder)
	if(!iscarbon(eater))
		return FALSE
	var/mob/living/carbon/C = eater
	var/covered = ""
	if(C.is_mouth_covered(head_only = 1))
		covered = "headgear"
	else if(C.is_mouth_covered(mask_only = 1))
		covered = "mask"
	if(covered)
		var/who = (isnull(feeder) || eater == feeder) ? "your" : "[eater.p_their()]"
		to_chat(feeder, SPAN_WARNING("You have to remove [who] [covered] first!"))
		return FALSE
	return TRUE

///Check foodtypes to see if we should send a moodlet
/datum/component/edible/proc/checkLiked(fraction, mob/M)
	if(last_check_time + 50 > world.time)
		return FALSE
	if(!ishuman(M))
		return FALSE
	var/mob/living/carbon/human/H = M
	if(HAS_TRAIT(H, TRAIT_AGEUSIA) && foodtypes & H.dna.species.toxic_food)
		to_chat(H, SPAN_WARNING("You don't feel so good..."))
		H.adjust_disgust(25 + 30 * fraction)
	else
		if(foodtypes & H.dna.species.toxic_food)
			to_chat(H,SPAN_WARNING("What the hell was that thing?!"))
			H.adjust_disgust(25 + 30 * fraction)
			SEND_SIGNAL(H, COMSIG_ADD_MOOD_EVENT, "toxic_food", /datum/mood_event/disgusting_food)
		else if(foodtypes & H.dna.species.disliked_food)
			to_chat(H,SPAN_NOTICE("That didn't taste very good..."))
			H.adjust_disgust(11 + 15 * fraction)
			SEND_SIGNAL(H, COMSIG_ADD_MOOD_EVENT, "gross_food", /datum/mood_event/gross_food)
		else if(foodtypes & H.dna.species.liked_food)
			to_chat(H,SPAN_NOTICE("I love this taste!"))
			H.adjust_disgust(-5 + -2.5 * fraction)
			SEND_SIGNAL(H, COMSIG_ADD_MOOD_EVENT, "fav_food", /datum/mood_event/favorite_food)
	if((foodtypes & BREAKFAST) && world.time - SSticker.round_start_time < STOP_SERVING_BREAKFAST)
		SEND_SIGNAL(H, COMSIG_ADD_MOOD_EVENT, "breakfast", /datum/mood_event/breakfast)
	last_check_time = world.time

///Delete the item when it is fully eaten
/datum/component/edible/proc/On_Consume(mob/living/eater)

	var/atom/owner = parent

	if(!eater)
		return
	if(!owner.reagents.total_volume)
		if(isturf(parent))
			var/turf/T = parent
			T.ScrapeAway(1, CHANGETURF_INHERIT_AIR)
		else
			qdel(parent)

///Ability to feed food to puppers
/datum/component/edible/proc/UseByAnimal(datum/source, mob/user)

	var/atom/owner = parent

	if(!isdog(user))
		return
	var/mob/living/L = user
	if(bitecount == 0 || prob(50))
		L.emote("me", 1, "nibbles away at \the [parent]")
	bitecount++
	. = COMPONENT_ITEM_NO_ATTACK
	L.taste(owner.reagents) // why should carbons get all the fun?
	if(bitecount >= 5)
		var/sattisfaction_text = pick("burps from enjoyment", "yaps for more", "woofs twice", "looks at the area where \the [parent] was")
		if(sattisfaction_text)
			L.emote("me", 1, "[sattisfaction_text]")
		qdel(parent)
