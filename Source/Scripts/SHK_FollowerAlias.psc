Scriptname SHK_FollowerAlias extends ReferenceAlias
{One Shield-Kin follower slot: outfits by place, catch-up teleport, healer behaviour,
 sell errands and collecting items to sell.}

bool collecting = false

SHK_Core Function Core()
	return GetOwningQuest() as SHK_Core
EndFunction

Function StartTicking()
	RegisterForSingleUpdate(3.0)
EndFunction

Event OnInit()
	if GetReference()
		StartTicking()
	endif
EndEvent

Event OnPlayerLoadGame()
	; not sent to non-player aliases; SHK_Core.ReapplyAll covers reloads
EndEvent

Event OnUpdate()
	Actor a = GetActorRef()
	if !a
		return
	endif
	SHK_Core core = Core()
	int mode = StorageUtil.GetIntValue(a, "shk.mode", 0)
	float nextTick = 3.0

	if mode == core.ModeSell
		TickSell(core, a)
		nextTick = 2.0
	elseif mode == core.ModeFollow
		TickCatchUp(core, a)
	endif

	if a.IsInCombat()
		if StorageUtil.GetIntValue(a, "shk.style", 0) == core.StyleHealer
			TickHealer(core, a)
		endif
		nextTick = 2.0
	endif

	core.UpdateOutfit(a)
	RegisterForSingleUpdate(nextTick)
EndEvent

; Bring a following follower back when they fall far behind or are left in another cell.
Function TickCatchUp(SHK_Core core, Actor a)
	Actor player = core.PlayerRef
	if player.IsInCombat() || a.IsInCombat() || a.IsDead()
		return
	endif
	float limit = StorageUtil.GetFloatValue(None, "shk.set.catchup", 3000.0)
	if limit <= 0.0
		return
	endif
	bool far = !a.Is3DLoaded() || a.GetDistance(player) > limit
	if far && !player.IsOnMount() && !Utility.IsInMenuMode()
		float az = player.GetAngleZ()
		a.MoveTo(player, -120.0 * Math.Sin(az), -120.0 * Math.Cos(az), 0.0, false)
	endif
EndFunction

; Heal the most hurt party member (or self) with a known restoration spell.
Function TickHealer(SHK_Core core, Actor a)
	if a.GetActorValuePercentage("Magicka") < 0.15
		return
	endif
	Actor player = core.PlayerRef
	Actor target = None
	float worst = 0.5
	if player.GetActorValuePercentage("Health") < worst && a.GetDistance(player) < 2048.0
		worst = player.GetActorValuePercentage("Health")
		target = player
	endif
	int i = 0
	while i < core.MaxSlots
		Actor other = core.SlotActor(i)
		if other && other != a && !other.IsDead() && other.GetActorValuePercentage("Health") < worst && a.GetDistance(other) < 2048.0
			worst = other.GetActorValuePercentage("Health")
			target = other
		endif
		i += 1
	endwhile

	if target
		Spell s = None
		if a.HasSpell(core.HealOther)
			s = core.HealOther
		elseif a.HasSpell(core.HealingHands)
			s = core.HealingHands
		endif
		if s
			s.Cast(a, target)
			return
		endif
	endif

	if a.GetActorValuePercentage("Health") < 0.45
		Spell selfHeal = None
		if a.HasSpell(core.GrandHealing)
			selfHeal = core.GrandHealing
		elseif a.HasSpell(core.CloseWounds)
			selfHeal = core.CloseWounds
		elseif a.HasSpell(core.FastHealing)
			selfHeal = core.FastHealing
		elseif a.HasSpell(core.Healing)
			selfHeal = core.Healing
		endif
		if selfHeal
			selfHeal.Cast(a, a)
		endif
	endif
EndFunction

; Walk to the merchant; finish when close, or move them there after 90 seconds.
Function TickSell(SHK_Core core, Actor a)
	Actor merchant = StorageUtil.GetFormValue(a, "shk.sell.merchant") as Actor
	if !merchant || merchant.IsDead()
		core.CancelSell(a, true)
		return
	endif
	if a.GetDistance(merchant) < 300.0
		core.CompleteSale(a)
		return
	endif
	float started = StorageUtil.GetFloatValue(a, "shk.sell.started", 0.0)
	if Utility.GetCurrentRealTime() - started > 90.0 || Utility.GetCurrentRealTime() < started
		a.MoveTo(merchant, 80.0, 0.0, 0.0, false)
		core.CompleteSale(a)
	endif
EndFunction

Event OnLocationChange(Location akOldLoc, Location akNewLoc)
	Actor a = GetActorRef()
	if a
		Core().UpdateOutfit(a)
	endif
EndEvent

Event OnCombatStateChanged(Actor akTarget, int aeCombatState)
	Actor a = GetActorRef()
	if !a
		return
	endif
	SHK_Core core = Core()
	; party members never fight the player or each other
	if akTarget && (akTarget == core.PlayerRef || akTarget.IsInFaction(core.FollowerFaction))
		a.StopCombat()
		return
	endif
	if aeCombatState == 1 && StorageUtil.GetIntValue(a, "shk.stance", 0) == core.StancePassive
		a.StopCombat()
		return
	endif
	core.UpdateOutfit(a)
	if aeCombatState != 0
		RegisterForSingleUpdate(1.0)
	endif
EndEvent

Event OnDeath(Actor akKiller)
	Actor a = GetActorRef()
	if a
		Core().OnFollowerDied(a)
	endif
EndEvent

; --- collecting items to sell -------------------------------------------------

Function BeginCollecting()
	collecting = true
	RegisterForMenu("ContainerMenu")
EndFunction

Event OnMenuClose(string menuName)
	if menuName == "ContainerMenu" && collecting
		collecting = false
		UnregisterForMenu("ContainerMenu")
		Actor a = GetActorRef()
		if a
			int n = Core().SellQueueCount(a)
			if n > 0
				Debug.Notification(a.GetDisplayName() + " is carrying " + n + " items to sell.")
			endif
		endif
	endif
EndEvent

Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
	if collecting && akSourceContainer == Core().PlayerRef
		Core().QueueForSale(GetActorRef(), akBaseItem, aiItemCount)
	endif
EndEvent

Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
	if collecting && akDestContainer == Core().PlayerRef
		Core().UnqueueForSale(GetActorRef(), akBaseItem, aiItemCount)
	endif
EndEvent
