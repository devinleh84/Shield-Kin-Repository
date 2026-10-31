Scriptname SHK_RequiemBridge Hidden
{Registers Shield-Kin follower slots with Requiem's follower registry, if Requiem is loaded.
 Requiem keeps room for 30 aliases in total, so only the first slots are registered.}

bool Function RegisterSlots(Quest shk, int count) Global
	if Game.GetModByName("Requiem.esp") == 255
		return true
	endif
	REQ_FollowerRegistration req = Game.GetFormFromFile(0x0082F3AF, "Requiem.esp") as REQ_FollowerRegistration
	if !req
		return false
	endif
	int i = 0
	while i < count
		ReferenceAlias ra = shk.GetAlias(i) as ReferenceAlias
		if ra
			req.RegisterFollowerAlias(ra)
		endif
		i += 1
	endwhile
	return true
EndFunction
