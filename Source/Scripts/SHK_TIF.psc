Scriptname SHK_TIF extends TopicInfo Hidden
{Dialogue fragments for Shield-Kin's follower topics.}

SHK_Core Function Core()
	return Quest.GetQuest("SHK_Core") as SHK_Core
EndFunction

Function Fragment_Orders(ObjectReference akSpeakerRef)
	Core().OpenMenuSoon(akSpeakerRef as Actor)
EndFunction

Function Fragment_Wait(ObjectReference akSpeakerRef)
	Core().SetMode(akSpeakerRef as Actor, 1)
EndFunction

Function Fragment_Follow(ObjectReference akSpeakerRef)
	Core().SetMode(akSpeakerRef as Actor, 0)
EndFunction

Function Fragment_Trade(ObjectReference akSpeakerRef)
	(akSpeakerRef as Actor).OpenInventory(true)
EndFunction

Function Fragment_Dismiss(ObjectReference akSpeakerRef)
	Core().Dismiss(akSpeakerRef as Actor)
EndFunction
