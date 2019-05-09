/* Simple object type, calls a proc when "stepped" on by something */

/obj/effect/step_trigger
	var/affect_ghosts = 0
	var/stopper = 1 // stops throwers
	invisibility = 101 // nope cant see this shit
	anchored = 1

/obj/effect/step_trigger/proc/Trigger(var/atom/movable/A)
	return 0

/obj/effect/step_trigger/Crossed(H as mob|obj)
	..()
	if(!H)
		return
	if(istype(H, /mob/observer) && !affect_ghosts)
		return
	Trigger(H)



/* Tosses things in a certain direction */

/obj/effect/step_trigger/thrower
	var/direction = SOUTH // the direction of throw
	var/tiles = 3	// if 0: forever until atom hits a stopper
	var/immobilize = 1 // if nonzero: prevents mobs from moving while they're being flung
	var/speed = 1	// delay of movement
	var/facedir = 0 // if 1: atom faces the direction of movement
	var/nostop = 0 // if 1: will only be stopped by teleporters
	var/list/affecting = list()

	Trigger(var/atom/A)
		if(!A || !istype(A, /atom/movable))
			return
		var/atom/movable/AM = A
		var/curtiles = 0
		var/stopthrow = 0
		for(var/obj/effect/step_trigger/thrower/T in orange(2, src))
			if(AM in T.affecting)
				return

		if(ismob(AM))
			var/mob/M = AM
			if(immobilize)
				M.canmove = 0

		affecting.Add(AM)
		while(AM && !stopthrow)
			if(tiles)
				if(curtiles >= tiles)
					break
			if(AM.z != src.z)
				break

			curtiles++

			sleep(speed)

			// Calculate if we should stop the process
			if(!nostop)
				for(var/obj/effect/step_trigger/T in get_step(AM, direction))
					if(T.stopper && T != src)
						stopthrow = 1
			else
				for(var/obj/effect/step_trigger/teleporter/T in get_step(AM, direction))
					if(T.stopper)
						stopthrow = 1

			if(AM)
				var/predir = AM.dir
				step(AM, direction)
				if(!facedir)
					AM.setDir(predir)



		affecting.Remove(AM)

		if(ismob(AM))
			var/mob/M = AM
			if(immobilize)
				M.canmove = 1

/* Stops things thrown by a thrower, doesn't do anything */

/obj/effect/step_trigger/stopper

/* Instant teleporter */

/obj/effect/step_trigger/teleporter
	var/teleport_x = 0	// teleportation coordinates (if one is null, then no teleport!)
	var/teleport_y = 0
	var/teleport_z = 0

/obj/effect/step_trigger/teleporter/Trigger(atom/movable/A)
	if(teleport_x && teleport_y && teleport_z)
		var/turf/T = locate(teleport_x, teleport_y, teleport_z)
		if(isliving(A))
			var/mob/living/L = A
			if(L.pulling)
				var/atom/movable/P = L.pulling
				L.stop_pulling()
				P.forceMove(T)
				L.forceMove(T)
				L.start_pulling(P)
			else
				A.forceMove(T)
		else
			A.forceMove(T)

/* Random teleporter, teleports atoms to locations ranging from teleport_x - teleport_x_offset, etc */

/obj/effect/step_trigger/teleporter/random
	var/teleport_x_offset = 0
	var/teleport_y_offset = 0
	var/teleport_z_offset = 0

/obj/effect/step_trigger/teleporter/random/Trigger(atom/movable/A)
		if(teleport_x && teleport_y && teleport_z)
			if(teleport_x_offset && teleport_y_offset && teleport_z_offset)
				var/turf/T = locate(rand(teleport_x, teleport_x_offset), rand(teleport_y, teleport_y_offset), rand(teleport_z, teleport_z_offset))
				A.forceMove(T)

/* Teleporter that sends objects stepping on it to a specific landmark. */

/obj/effect/step_trigger/teleporter/landmark
	var/landmark_id

/obj/effect/step_trigger/teleporter/landmark/Initialize(mapload)
	. = ..()
	if(mapload)
		if(!landmark_id)
			stack_trace("Warning: Teleportation step trigger at [COORD(src)] that uses landmark ID target system does not have a set ID! Deleting!")
			return INITIALIZE_HINT_QDEL
		return INITIALIZE_HINT_LATELOAD

/obj/effect/step_trigger/teleporter/landmark/LateInitialize()
	if(!GLOB.landmarks_id_target[landmark_id])
		stack_trace("Warning: Teleportation step trigger at [COORD(src)] that uses landmark ID target system can't find its target landmark!")

/obj/effect/step_trigger/teleporter/landmark/Trigger(atom/movable/A)
	var/obj/effect/landmark/id_target/the_landmark = GLOB.landmarks_id_target[landmark_id]
	if(the_landmark)
		A.forceMove(get_turf(the_landmark))

/* Teleporter which simulates falling out of the sky. */

/obj/effect/step_trigger/teleporter/planetary_fall
	var/datum/planet/planet = null

// First time setup, which planet are we aiming for?
/obj/effect/step_trigger/teleporter/planetary_fall/proc/find_planet()
	return

/obj/effect/step_trigger/teleporter/planetary_fall/Trigger(var/atom/movable/A)
	if(!planet)
		find_planet()

	if(planet)
		if(!planet.planet_floors.len)
			message_admins("ERROR: planetary_fall step trigger's list of outdoor floors was empty.")
			return
		var/turf/simulated/T = null
		var/safety = 100 // Infinite loop protection.
		while(!T && safety)
			var/turf/simulated/candidate = pick(planet.planet_floors)
			if(!istype(candidate) || istype(candidate, /turf/simulated/sky))
				safety--
				continue
			else if(candidate && !candidate.outdoors)
				safety--
				continue
			else
				T = candidate
				break

		if(!T)
			message_admins("ERROR: planetary_fall step trigger could not find a suitable landing turf.")
			return

		if(isobserver(A))
			A.forceMove(T) // Harmlessly move ghosts.
			return

		A.forceMove(T)
		// Living things should probably be logged when they fall...
		if(isliving(A))
			message_admins("\The [A] fell out of the sky.")
		// ... because they're probably going to die from it.
		A.fall_impact(T, 42, 90, FALSE, TRUE)	//You will not be defibbed from this.
	else
		message_admins("ERROR: planetary_fall step trigger lacks a planet to fall onto.")
		return
