Scriptname SHK_SellPowerEffect extends ActiveMagicEffect
{The Shield-Kin selling power: hand items to a follower, who goes to sell them when you close the window.}

Event OnEffectStart(Actor akTarget, Actor akCaster)
	SHK_Core core = Quest.GetQuest("SHK_Core") as SHK_Core
	if !core
		return
	endif
	Actor a = core.AimedOrNearestFollower()
	if !a
		Debug.Notification("No sworn follower close enough to sell for you.")
		return
	endif
	core.GiveItemsToSell(a, true)
EndEvent
