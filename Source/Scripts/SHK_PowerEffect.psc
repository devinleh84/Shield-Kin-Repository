Scriptname SHK_PowerEffect extends ActiveMagicEffect
{The Shield-Kin lesser power: opens the menu, on the follower under the crosshair if any.}

Event OnEffectStart(Actor akTarget, Actor akCaster)
	SHK_Core core = Quest.GetQuest("SHK_Core") as SHK_Core
	if core
		Actor focus = Game.GetCurrentCrosshairRef() as Actor
		if focus && !focus.IsInFaction(core.FollowerFaction)
			focus = None
		endif
		core.OpenMenuSoon(focus)
	endif
EndEvent
