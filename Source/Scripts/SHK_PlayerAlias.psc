Scriptname SHK_PlayerAlias extends ReferenceAlias
{Tells SHK_Core when a save is loaded.}

Event OnPlayerLoadGame()
	(GetOwningQuest() as SHK_Core).OnGameLoaded()
EndEvent
