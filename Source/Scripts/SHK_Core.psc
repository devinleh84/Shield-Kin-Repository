Scriptname SHK_Core extends Quest
{Shield-Kin follower framework: roster, orders, settings and the Magelight menu bridge.
 Forms are looked up by FormID at runtime so the ESP needs no script properties.
 Per-follower data lives in PapyrusUtil StorageUtil keyed on the follower actor.
 All JSON keys and command words are lowercase because Papyrus strings are case-insensitive.}

; ---------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------

string Property PluginName = "Shield-Kin.esp" AutoReadOnly
string Property ModId = "ShieldKin" AutoReadOnly
int Property MaxSlots = 30 AutoReadOnly
int Property RequiemSlots = 20 AutoReadOnly

int Property ModeFollow = 0 AutoReadOnly
int Property ModeWait = 1 AutoReadOnly
int Property ModeSandbox = 2 AutoReadOnly
int Property ModeHome = 3 AutoReadOnly
int Property ModeCamp = 4 AutoReadOnly
int Property ModeRelax = 5 AutoReadOnly
int Property ModeSell = 6 AutoReadOnly

int Property StyleDefault = 0 AutoReadOnly
int Property StyleMelee = 1 AutoReadOnly
int Property StyleArcher = 2 AutoReadOnly
int Property StyleMage = 3 AutoReadOnly
int Property StyleHealer = 4 AutoReadOnly
int Property StyleTank = 5 AutoReadOnly

int Property StanceBalanced = 0 AutoReadOnly
int Property StanceAggressive = 1 AutoReadOnly
int Property StanceDefensive = 2 AutoReadOnly
int Property StancePassive = 3 AutoReadOnly

int Property ProtMortal = 0 AutoReadOnly
int Property ProtProtected = 1 AutoReadOnly
int Property ProtEssential = 2 AutoReadOnly

; outfit sets
int Property SetTravel = 0 AutoReadOnly
int Property SetTown = 1 AutoReadOnly
int Property SetHome = 2 AutoReadOnly
int Property SetSleep = 3 AutoReadOnly
int Property SetCombat = 4 AutoReadOnly

; ---------------------------------------------------------------------------
; Forms (filled by LoadForms)
; ---------------------------------------------------------------------------

Keyword Property LinkHome Auto Hidden
Keyword Property LinkCamp Auto Hidden
Keyword Property LinkRelax Auto Hidden
Keyword Property LinkSell Auto Hidden
Faction Property FollowerFaction Auto Hidden
Faction Property ModeFaction Auto Hidden
Faction Property DistFaction Auto Hidden
Outfit Property EmptyOutfit Auto Hidden
Package Property PkgHome Auto Hidden

Faction Property CurrentFollowerFaction Auto Hidden
Faction Property PlayerFollowerFaction Auto Hidden
Faction Property DismissedFollowerFaction Auto Hidden
Faction Property CurrentHireling Auto Hidden
GlobalVariable Property PlayerFollowerCount Auto Hidden
Static Property XMarkerHeading Auto Hidden
MiscObject Property Gold Auto Hidden
Keyword Property LocTypePlayerHouse Auto Hidden
Keyword Property LocTypeCity Auto Hidden
Keyword Property LocTypeTown Auto Hidden
Keyword Property LocTypeInn Auto Hidden
Keyword Property LocTypeSettlement Auto Hidden
Keyword Property LocTypeHabitation Auto Hidden
CombatStyle Property CsMelee Auto Hidden
CombatStyle Property CsArcher Auto Hidden
CombatStyle Property CsMage Auto Hidden
CombatStyle Property CsTank Auto Hidden
Spell Property HealOther Auto Hidden
Spell Property HealingHands Auto Hidden
Spell Property GrandHealing Auto Hidden
Spell Property CloseWounds Auto Hidden
Spell Property FastHealing Auto Hidden
Spell Property Healing Auto Hidden

Actor Property PlayerRef Auto Hidden
Spell Property MenuPower Auto Hidden
Spell Property SellPower Auto Hidden

; ---------------------------------------------------------------------------
; Runtime state
; ---------------------------------------------------------------------------

int menuView = 0
int boundKey = 0
bool menuOpen = false
bool domReady = false
int menuAck = 0
Actor pendingFocus = None
bool pendingOpen = false
int lastPlayerLevel = 0
ObjectReference campMarker = None

; ---------------------------------------------------------------------------
; Lifecycle
; ---------------------------------------------------------------------------

Event OnInit()
	Startup()
	RegisterForSingleUpdate(5.0)
EndEvent

; Called by SHK_PlayerAlias on every save load.
Function OnGameLoaded()
	Startup()
	ReapplyAll()
EndFunction

Function Startup()
	LoadForms()
	PlayerRef = Game.GetPlayer()
	if StorageUtil.GetIntValue(None, "shk.set.init", 0) == 0
		StorageUtil.SetIntValue(None, "shk.set.init", 1)
		StorageUtil.SetIntValue(None, "shk.set.key", 65) ; F7
		StorageUtil.SetFloatValue(None, "shk.set.catchup", 3000.0)
		StorageUtil.SetIntValue(None, "shk.set.level", 0)
		StorageUtil.SetFloatValue(None, "shk.set.levelpct", 90.0)
		StorageUtil.SetIntValue(None, "shk.set.notify", 1)
		StorageUtil.SetIntValue(None, "shk.set.autooutfit", 1)
		StorageUtil.SetIntValue(None, "shk.set.dist", 1)
		StorageUtil.SetFloatValue(None, "shk.set.scale", 100.0)
		StorageUtil.SetStringValue(None, "shk.set.theme", "vellum")
	endif
	BindMenuKey(StorageUtil.GetIntValue(None, "shk.set.key", 65))
	UpdatePower()
	SetupMenu()
	; keep vanilla "Follow me" dialogue available for every potential follower
	if PlayerFollowerCount && PlayerFollowerCount.GetValue() > 0
		DialogueFollowerScript dfs = Game.GetFormFromFile(0x000750BA, "Skyrim.esm") as DialogueFollowerScript
		if dfs && dfs.pFollowerAlias && dfs.pFollowerAlias.GetReference() == None
			PlayerFollowerCount.SetValue(0)
		endif
	endif
EndFunction

Function LoadForms()
	MenuPower = Game.GetFormFromFile(0x822, PluginName) as Spell
	SellPower = Game.GetFormFromFile(0x824, PluginName) as Spell
	LinkHome = Game.GetFormFromFile(0x800, PluginName) as Keyword
	LinkCamp = Game.GetFormFromFile(0x801, PluginName) as Keyword
	LinkRelax = Game.GetFormFromFile(0x802, PluginName) as Keyword
	LinkSell = Game.GetFormFromFile(0x803, PluginName) as Keyword
	FollowerFaction = Game.GetFormFromFile(0x804, PluginName) as Faction
	ModeFaction = Game.GetFormFromFile(0x805, PluginName) as Faction
	DistFaction = Game.GetFormFromFile(0x806, PluginName) as Faction
	EmptyOutfit = Game.GetFormFromFile(0x807, PluginName) as Outfit
	PkgHome = Game.GetFormFromFile(0x80C, PluginName) as Package

	CurrentFollowerFaction = Game.GetFormFromFile(0x05C84E, "Skyrim.esm") as Faction
	PlayerFollowerFaction = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
	DismissedFollowerFaction = Game.GetFormFromFile(0x05C84C, "Skyrim.esm") as Faction
	CurrentHireling = Game.GetFormFromFile(0x0BD738, "Skyrim.esm") as Faction
	PlayerFollowerCount = Game.GetFormFromFile(0x0BCC98, "Skyrim.esm") as GlobalVariable
	XMarkerHeading = Game.GetFormFromFile(0x000034, "Skyrim.esm") as Static
	Gold = Game.GetFormFromFile(0x00000F, "Skyrim.esm") as MiscObject
	LocTypePlayerHouse = Game.GetFormFromFile(0x0FC1A3, "Skyrim.esm") as Keyword
	LocTypeCity = Game.GetFormFromFile(0x013168, "Skyrim.esm") as Keyword
	LocTypeTown = Game.GetFormFromFile(0x013166, "Skyrim.esm") as Keyword
	LocTypeInn = Game.GetFormFromFile(0x01CB87, "Skyrim.esm") as Keyword
	LocTypeSettlement = Game.GetFormFromFile(0x013167, "Skyrim.esm") as Keyword
	LocTypeHabitation = Game.GetFormFromFile(0x039793, "Skyrim.esm") as Keyword
	CsMelee = Game.GetFormFromFile(0x086F4F, "Skyrim.esm") as CombatStyle
	CsArcher = Game.GetFormFromFile(0x03BE1D, "Skyrim.esm") as CombatStyle
	CsMage = Game.GetFormFromFile(0x03BE1C, "Skyrim.esm") as CombatStyle
	CsTank = Game.GetFormFromFile(0x03CF5A, "Skyrim.esm") as CombatStyle
	HealOther = Game.GetFormFromFile(0x012FD2, "Skyrim.esm") as Spell
	HealingHands = Game.GetFormFromFile(0x04D3F2, "Skyrim.esm") as Spell
	GrandHealing = Game.GetFormFromFile(0x0B62EE, "Skyrim.esm") as Spell
	CloseWounds = Game.GetFormFromFile(0x0B62EF, "Skyrim.esm") as Spell
	FastHealing = Game.GetFormFromFile(0x02F3B8, "Skyrim.esm") as Spell
	Healing = Game.GetFormFromFile(0x012FCC, "Skyrim.esm") as Spell
EndFunction

; Slow housekeeping tick: Requiem registration, level scaling, a delayed menu open.
Event OnUpdate()
	if pendingOpen
		pendingOpen = false
		OpenMenu(pendingFocus)
		pendingFocus = None
	endif
	if StorageUtil.GetIntValue(None, "shk.req.done", 0) == 0
		if SHK_RequiemBridge.RegisterSlots(self, RequiemSlots)
			StorageUtil.SetIntValue(None, "shk.req.done", 1)
		endif
	endif
	int lvl = PlayerRef.GetLevel()
	if lvl != lastPlayerLevel
		lastPlayerLevel = lvl
		ApplyLevelingAll()
	endif
	RegisterForSingleUpdate(30.0)
EndEvent

; Re-apply settings the game does not keep in the save (base-form changes, linked refs).
; The "Shield-Kin" lesser power opens the menu; the Settings page can take it away.
Function UpdatePower()
	bool want = StorageUtil.GetIntValue(None, "shk.set.power", 1) == 1
	GivePower(MenuPower, want)
	GivePower(SellPower, want)
EndFunction

Function GivePower(Spell power, bool want)
	if !power
		return
	endif
	if want && !PlayerRef.HasSpell(power)
		PlayerRef.AddSpell(power, false)
	elseif !want && PlayerRef.HasSpell(power)
		PlayerRef.RemoveSpell(power)
	endif
EndFunction

Function ReapplyAll()
	int i = 0
	while i < MaxSlots
		Actor a = SlotActor(i)
		if a
			ApplyProfile(a)
			ApplyLinks(a)
		endif
		i += 1
	endwhile
	int n = StorageUtil.FormListCount(None, "shk.registry")
	i = 0
	while i < n
		Actor r = StorageUtil.FormListGet(None, "shk.registry", i) as Actor
		if r
			ApplyLinks(r)
		endif
		i += 1
	endwhile
EndFunction

; ---------------------------------------------------------------------------
; Slots
; ---------------------------------------------------------------------------

ReferenceAlias Function SlotAlias(int i)
	return GetAlias(i) as ReferenceAlias
EndFunction

Actor Function SlotActor(int i)
	ReferenceAlias ra = SlotAlias(i)
	if ra
		return ra.GetActorRef()
	endif
	return None
EndFunction

int Function FindSlot(Actor a)
	int i = 0
	while i < MaxSlots
		if a && SlotActor(i) == a
			return i
		endif
		i += 1
	endwhile
	return -1
EndFunction

int Function FreeSlot()
	int i = 0
	while i < MaxSlots
		ReferenceAlias ra = SlotAlias(i)
		if ra && ra.GetReference() == None
			return i
		endif
		i += 1
	endwhile
	return -1
EndFunction

int Function CountFollowers()
	int c = 0
	int i = 0
	while i < MaxSlots
		if SlotActor(i)
			c += 1
		endif
		i += 1
	endwhile
	return c
EndFunction

bool Function IsShieldKin(Actor a)
	return a && FindSlot(a) >= 0
EndFunction

; ---------------------------------------------------------------------------
; Recruit and dismiss
; ---------------------------------------------------------------------------

bool Function Recruit(Actor a)
	if !a || a == PlayerRef || a.IsDead()
		return false
	endif
	if FindSlot(a) >= 0
		return true
	endif
	int slot = FreeSlot()
	if slot < 0
		Notify("Your Shield-Kin is full (" + MaxSlots + " followers).")
		return false
	endif

	; first time: remember what to restore on dismissal
	if StorageUtil.GetIntValue(a, "shk.known", 0) == 0
		StorageUtil.SetIntValue(a, "shk.known", 1)
		ActorBase ab = a.GetActorBase()
		StorageUtil.SetFormValue(a, "shk.orig.style", ab.GetCombatStyle())
		StorageUtil.SetFormValue(a, "shk.orig.outfit", ab.GetOutfit())
		StorageUtil.SetFloatValue(a, "shk.orig.aggr", a.GetBaseActorValue("Aggression"))
		StorageUtil.SetFloatValue(a, "shk.orig.conf", a.GetBaseActorValue("Confidence"))
		int prot = ProtMortal
		if ab.IsEssential()
			prot = ProtEssential
		elseif ab.IsProtected()
			prot = ProtProtected
		endif
		StorageUtil.SetIntValue(a, "shk.orig.prot", prot)
		StorageUtil.SetIntValue(a, "shk.prot", prot)
		StorageUtil.SetIntValue(a, "shk.dist", StorageUtil.GetIntValue(None, "shk.set.dist", 1))
	endif

	StorageUtil.FormListRemove(None, "shk.registry", a, true)
	ActorUtil.RemovePackageOverride(a, PkgHome)
	a.RemoveFromFaction(DismissedFollowerFaction)
	if a.GetRelationshipRank(PlayerRef) < 3 && a.GetRelationshipRank(PlayerRef) >= 0
		a.SetRelationshipRank(PlayerRef, 3)
	endif
	a.SetPlayerTeammate(true, true)
	a.AddToFaction(FollowerFaction)
	a.SetFactionRank(CurrentFollowerFaction, 0)
	a.SetFactionRank(PlayerFollowerFaction, 0)
	a.IgnoreFriendlyHits(true)
	StorageUtil.SetIntValue(a, "shk.mode", ModeFollow)
	a.SetActorValue("WaitingForPlayer", 0)

	SlotAlias(slot).ForceRefTo(a)
	ApplyProfile(a)
	ApplyLinks(a)
	ApplyLeveling(a)
	a.EvaluatePackage()
	(SlotAlias(slot) as SHK_FollowerAlias).StartTicking()
	Notify(a.GetDisplayName() + " joined your Shield-Kin.")
	return true
EndFunction

Function Dismiss(Actor a, bool silent = false)
	int slot = FindSlot(a)
	if slot < 0
		return
	endif
	ReferenceAlias ra = SlotAlias(slot)
	CancelSell(a, false)
	a.StopCombatAlarm()
	a.SetPlayerTeammate(false)
	a.RemoveFromFaction(FollowerFaction)
	a.RemoveFromFaction(CurrentFollowerFaction)
	a.RemoveFromFaction(PlayerFollowerFaction)
	a.RemoveFromFaction(CurrentHireling)
	a.RemoveFromFaction(ModeFaction)
	a.RemoveFromFaction(DistFaction)
	a.AddToFaction(DismissedFollowerFaction)
	a.IgnoreFriendlyHits(false)
	a.SetActorValue("WaitingForPlayer", 0)
	RestoreProfile(a)
	RemoveLeveling(a)
	ra.Clear()

	StorageUtil.FormListAdd(None, "shk.registry", a, false)
	ObjectReference home = StorageUtil.GetFormValue(a, "shk.home") as ObjectReference
	if home
		PO3_SKSEFunctions.SetLinkedRef(a, home, LinkHome)
		ActorUtil.AddPackageOverride(a, PkgHome, 60)
	endif
	a.EvaluatePackage()
	if !silent
		Notify(a.GetDisplayName() + " has left your Shield-Kin.")
	endif
EndFunction

Function OnFollowerDied(Actor a)
	int slot = FindSlot(a)
	if slot < 0
		return
	endif
	Notify(a.GetDisplayName() + " has fallen.")
	SlotAlias(slot).Clear()
	a.RemoveFromFaction(FollowerFaction)
	a.RemoveFromFaction(CurrentFollowerFaction)
	a.RemoveFromFaction(PlayerFollowerFaction)
	StorageUtil.FormListRemove(None, "shk.registry", a, true)
EndFunction

Function Forget(Actor a)
	StorageUtil.FormListRemove(None, "shk.registry", a, true)
	ActorUtil.RemovePackageOverride(a, PkgHome)
	ClearHome(a)
	a.EvaluatePackage()
EndFunction

Function Summon(Actor a)
	if !a
		return
	endif
	float az = PlayerRef.GetAngleZ()
	a.MoveTo(PlayerRef, -110.0 * Math.Sin(az), -110.0 * Math.Cos(az), 0.0, false)
	if FindSlot(a) >= 0 && StorageUtil.GetIntValue(a, "shk.mode", 0) != ModeSell
		SetMode(a, ModeFollow)
	endif
EndFunction

; ---------------------------------------------------------------------------
; Orders
; ---------------------------------------------------------------------------

Function SetMode(Actor a, int m)
	if !a
		return
	endif
	int old = StorageUtil.GetIntValue(a, "shk.mode", ModeFollow)
	if old == ModeSell && m != ModeSell
		CancelSell(a, false)
	endif
	if m == ModeHome && !StorageUtil.GetFormValue(a, "shk.home")
		Notify(a.GetDisplayName() + " has no home yet.")
		return
	endif
	if m == ModeRelax
		ObjectReference mk = MarkerFor(a, "shk.relax")
		mk.MoveTo(a)
	endif
	if m == ModeCamp && !campMarker
		campMarker = PlayerRef.PlaceAtMe(XMarkerHeading, 1, true)
	endif
	StorageUtil.SetIntValue(a, "shk.mode", m)
	if m == ModeWait
		a.SetActorValue("WaitingForPlayer", 1)
	else
		a.SetActorValue("WaitingForPlayer", 0)
	endif
	a.SetFactionRank(ModeFaction, m)
	ApplyLinks(a)
	a.EvaluatePackage()
EndFunction

Function SetDistance(Actor a, int d)
	StorageUtil.SetIntValue(a, "shk.dist", d)
	a.SetFactionRank(DistFaction, d)
	a.EvaluatePackage()
EndFunction

Function SetStyle(Actor a, int s)
	StorageUtil.SetIntValue(a, "shk.style", s)
	ApplyProfile(a)
EndFunction

Function SetStance(Actor a, int s)
	StorageUtil.SetIntValue(a, "shk.stance", s)
	ApplyProfile(a)
EndFunction

Function SetProtection(Actor a, int p)
	StorageUtil.SetIntValue(a, "shk.prot", p)
	ApplyProfile(a)
EndFunction

; Combat style, stance, protection and faction ranks.
Function ApplyProfile(Actor a)
	ActorBase ab = a.GetActorBase()
	int style = StorageUtil.GetIntValue(a, "shk.style", StyleDefault)
	CombatStyle cs = StorageUtil.GetFormValue(a, "shk.orig.style") as CombatStyle
	if style == StyleMelee
		cs = CsMelee
	elseif style == StyleArcher
		cs = CsArcher
	elseif style == StyleMage || style == StyleHealer
		cs = CsMage
	elseif style == StyleTank
		cs = CsTank
	endif
	if cs
		ab.SetCombatStyle(cs)
	endif

	int stance = StorageUtil.GetIntValue(a, "shk.stance", StanceBalanced)
	if stance == StanceAggressive
		a.SetActorValue("Aggression", 1)
		a.SetActorValue("Confidence", 4)
	elseif stance == StanceDefensive
		a.SetActorValue("Aggression", 0)
		a.SetActorValue("Confidence", 2)
	elseif stance == StancePassive
		a.SetActorValue("Aggression", 0)
		a.SetActorValue("Confidence", 0)
	else
		a.SetActorValue("Aggression", 1)
		a.SetActorValue("Confidence", 3)
	endif

	int prot = StorageUtil.GetIntValue(a, "shk.prot", ProtProtected)
	ab.SetEssential(prot == ProtEssential)
	ab.SetProtected(prot == ProtProtected)

	a.SetFactionRank(ModeFaction, StorageUtil.GetIntValue(a, "shk.mode", ModeFollow))
	a.SetFactionRank(DistFaction, StorageUtil.GetIntValue(a, "shk.dist", 1))
EndFunction

Function RestoreProfile(Actor a)
	ActorBase ab = a.GetActorBase()
	CombatStyle cs = StorageUtil.GetFormValue(a, "shk.orig.style") as CombatStyle
	if cs
		ab.SetCombatStyle(cs)
	endif
	a.SetActorValue("Aggression", StorageUtil.GetFloatValue(a, "shk.orig.aggr", 1.0))
	a.SetActorValue("Confidence", StorageUtil.GetFloatValue(a, "shk.orig.conf", 3.0))
	int prot = StorageUtil.GetIntValue(a, "shk.orig.prot", ProtProtected)
	ab.SetEssential(prot == ProtEssential)
	ab.SetProtected(prot == ProtProtected)
	if StorageUtil.GetIntValue(a, "shk.outfit.managed", 0) == 1
		Outfit o = StorageUtil.GetFormValue(a, "shk.orig.outfit") as Outfit
		if o
			a.SetOutfit(o)
		endif
		StorageUtil.SetIntValue(a, "shk.outfit.managed", 0)
	endif
EndFunction

; Linked refs from PO3 are not saved, so they are set again on every load.
Function ApplyLinks(Actor a)
	ObjectReference home = StorageUtil.GetFormValue(a, "shk.home") as ObjectReference
	if home
		PO3_SKSEFunctions.SetLinkedRef(a, home, LinkHome)
	endif
	ObjectReference relax = StorageUtil.GetFormValue(a, "shk.relax") as ObjectReference
	if relax
		PO3_SKSEFunctions.SetLinkedRef(a, relax, LinkRelax)
	endif
	if campMarker
		PO3_SKSEFunctions.SetLinkedRef(a, campMarker, LinkCamp)
	endif
	Actor merchant = StorageUtil.GetFormValue(a, "shk.sell.merchant") as Actor
	if merchant
		PO3_SKSEFunctions.SetLinkedRef(a, merchant, LinkSell)
	endif
EndFunction

ObjectReference Function MarkerFor(Actor a, string storeKey)
	ObjectReference mk = StorageUtil.GetFormValue(a, storeKey) as ObjectReference
	if !mk
		mk = a.PlaceAtMe(XMarkerHeading, 1, true)
		StorageUtil.SetFormValue(a, storeKey, mk)
	endif
	return mk
EndFunction

; ---------------------------------------------------------------------------
; Homes and camp
; ---------------------------------------------------------------------------

Function SetHomeHere(Actor a)
	ObjectReference mk = MarkerFor(a, "shk.home")
	mk.MoveTo(PlayerRef)
	string where = ""
	Location loc = PlayerRef.GetCurrentLocation()
	if loc
		where = loc.GetName()
	endif
	if where == ""
		where = PlayerRef.GetParentCell().GetName()
	endif
	if where == ""
		where = "Wilderness"
	endif
	StorageUtil.SetStringValue(a, "shk.homename", where)
	ApplyLinks(a)
	Notify(a.GetDisplayName() + " will call " + where + " home.")
EndFunction

Function ClearHome(Actor a)
	ObjectReference mk = StorageUtil.GetFormValue(a, "shk.home") as ObjectReference
	if mk
		mk.Disable()
		mk.Delete()
	endif
	StorageUtil.UnsetFormValue(a, "shk.home")
	StorageUtil.UnsetStringValue(a, "shk.homename")
	if StorageUtil.GetIntValue(a, "shk.mode", 0) == ModeHome
		SetMode(a, ModeFollow)
	endif
EndFunction

Function MakeCamp()
	if !campMarker
		campMarker = PlayerRef.PlaceAtMe(XMarkerHeading, 1, true)
	else
		campMarker.MoveTo(PlayerRef)
	endif
	int i = 0
	while i < MaxSlots
		Actor a = SlotActor(i)
		if a && StorageUtil.GetIntValue(a, "shk.mode", 0) != ModeSell
			SetMode(a, ModeCamp)
		endif
		i += 1
	endwhile
	Notify("Your Shield-Kin makes camp here.")
EndFunction

Function PartyMode(int m)
	int i = 0
	while i < MaxSlots
		Actor a = SlotActor(i)
		if a && StorageUtil.GetIntValue(a, "shk.mode", 0) != ModeSell
			SetMode(a, m)
		endif
		i += 1
	endwhile
EndFunction

Function SummonAll()
	int i = 0
	while i < MaxSlots
		Actor a = SlotActor(i)
		if a
			Summon(a)
		endif
		i += 1
	endwhile
EndFunction

; ---------------------------------------------------------------------------
; Outfits
; ---------------------------------------------------------------------------

string Function OutfitKey(int setIndex)
	return "shk.outfit." + setIndex
EndFunction

Function SaveOutfit(Actor a, int setIndex)
	string k = OutfitKey(setIndex)
	StorageUtil.FormListClear(a, k)
	int slot = 1
	int n = 0
	while n < 32
		Form f = a.GetWornForm(slot)
		if f && (f as Armor)
			StorageUtil.FormListAdd(a, k, f, false)
		endif
		slot = slot * 2
		n += 1
	endwhile
	if n >= 32 && StorageUtil.FormListCount(a, k) == 0
		StorageUtil.SetIntValue(a, k + ".naked", 1)
	else
		StorageUtil.UnsetIntValue(a, k + ".naked")
	endif
	TakeOverOutfit(a)
	StorageUtil.SetIntValue(a, "shk.outfit.current", setIndex)
	Notify(a.GetDisplayName() + "'s " + OutfitName(setIndex) + " outfit saved.")
EndFunction

Function ClearOutfit(Actor a, int setIndex)
	StorageUtil.FormListClear(a, OutfitKey(setIndex))
	StorageUtil.UnsetIntValue(a, OutfitKey(setIndex) + ".naked")
EndFunction

bool Function HasOutfit(Actor a, int setIndex)
	return StorageUtil.FormListCount(a, OutfitKey(setIndex)) > 0 || StorageUtil.GetIntValue(a, OutfitKey(setIndex) + ".naked", 0) == 1
EndFunction

; Swap the default outfit for an empty one so the game stops re-dressing the follower.
; Items the swap removes from the inventory are put back first.
Function TakeOverOutfit(Actor a)
	if StorageUtil.GetIntValue(a, "shk.outfit.managed", 0) == 1
		return
	endif
	Form[] worn = new Form[32]
	int slot = 1
	int n = 0
	while n < 32
		worn[n] = a.GetWornForm(slot)
		slot = slot * 2
		n += 1
	endwhile
	a.SetOutfit(EmptyOutfit)
	n = 0
	while n < 32
		Form f = worn[n]
		if f && a.GetItemCount(f) == 0
			a.AddItem(f, 1, true)
		endif
		if f
			a.EquipItem(f, false, true)
		endif
		n += 1
	endwhile
	StorageUtil.SetIntValue(a, "shk.outfit.managed", 1)
EndFunction

; Puts on armour the player handed over, instead of the game's choice by armour rating.
; The follower's base outfit is swapped for an empty one so it cannot come back.
Function WearGiven(Actor a)
	int n = StorageUtil.FormListCount(a, "shk.given")
	if n <= 0
		return
	endif
	Form[] given = StorageUtil.FormListToArray(a, "shk.given")
	StorageUtil.FormListClear(a, "shk.given")
	TakeOverOutfit(a)
	int i = 0
	while i < given.Length
		Armor item = given[i] as Armor
		if item && a.GetItemCount(item) > 0 && item.IsPlayable()
			a.EquipItem(item, false, true)
		endif
		i += 1
	endwhile
	; keep the new look from being swapped out by place-based outfits until a set is saved for it
	int cur = StorageUtil.GetIntValue(a, "shk.outfit.current", -1)
	if cur >= 0 && HasOutfit(a, cur)
		Utility.Wait(0.5)
		SaveOutfit(a, cur)
	endif
EndFunction

Function WearOutfit(Actor a, int setIndex)
	if !HasOutfit(a, setIndex)
		return
	endif
	string k = OutfitKey(setIndex)
	; take off armor that is not part of the set
	int slot = 1
	int n = 0
	while n < 32
		Form f = a.GetWornForm(slot)
		if f && (f as Armor) && !StorageUtil.FormListHas(a, k, f)
			a.UnequipItem(f, false, true)
		endif
		slot = slot * 2
		n += 1
	endwhile
	int count = StorageUtil.FormListCount(a, k)
	int i = 0
	while i < count
		Form item = StorageUtil.FormListGet(a, k, i)
		if item && a.GetItemCount(item) > 0
			a.EquipItem(item, false, true)
		endif
		i += 1
	endwhile
	StorageUtil.SetIntValue(a, "shk.outfit.current", setIndex)
EndFunction

; Pick the right set for where the follower is and what they are doing.
Function UpdateOutfit(Actor a)
	if StorageUtil.GetIntValue(a, "shk.outfit.auto", StorageUtil.GetIntValue(None, "shk.set.autooutfit", 1)) == 0
		return
	endif
	if StorageUtil.GetIntValue(a, "shk.outfit.managed", 0) == 0
		return
	endif
	int want = SetTravel
	Location loc = a.GetCurrentLocation()
	if a.IsInCombat() && HasOutfit(a, SetCombat)
		want = SetCombat
	elseif a.GetSleepState() >= 3 && HasOutfit(a, SetSleep)
		want = SetSleep
	elseif loc && (loc.HasKeyword(LocTypePlayerHouse) || IsAtHome(a)) && HasOutfit(a, SetHome)
		want = SetHome
	elseif loc && (loc.HasKeyword(LocTypeCity) || loc.HasKeyword(LocTypeTown) || loc.HasKeyword(LocTypeInn) || loc.HasKeyword(LocTypeSettlement) || loc.HasKeyword(LocTypeHabitation)) && HasOutfit(a, SetTown)
		want = SetTown
	endif
	if want != StorageUtil.GetIntValue(a, "shk.outfit.current", -1)
		WearOutfit(a, want)
	endif
EndFunction

bool Function IsAtHome(Actor a)
	ObjectReference home = StorageUtil.GetFormValue(a, "shk.home") as ObjectReference
	return home && a.GetParentCell() == home.GetParentCell() && a.GetDistance(home) < 4000.0
EndFunction

string Function OutfitName(int setIndex)
	if setIndex == SetTown
		return "town"
	elseif setIndex == SetHome
		return "home"
	elseif setIndex == SetSleep
		return "sleep"
	elseif setIndex == SetCombat
		return "combat"
	endif
	return "travel"
EndFunction

; ---------------------------------------------------------------------------
; Levelling (optional, off by default)
; ---------------------------------------------------------------------------

Function ApplyLevelingAll()
	int i = 0
	while i < MaxSlots
		Actor a = SlotActor(i)
		if a
			ApplyLeveling(a)
		endif
		i += 1
	endwhile
EndFunction

Function ApplyLeveling(Actor a)
	if StorageUtil.GetIntValue(None, "shk.set.level", 0) == 0
		RemoveLeveling(a)
		return
	endif
	float pct = StorageUtil.GetFloatValue(None, "shk.set.levelpct", 90.0) / 100.0
	int target = (PlayerRef.GetLevel() * pct) as int
	int bonus = target - a.GetLevel()
	if bonus < 0
		bonus = 0
	endif
	int applied = StorageUtil.GetIntValue(a, "shk.lvl.bonus", 0)
	int delta = bonus - applied
	if delta != 0
		ModSkills(a, delta)
		StorageUtil.SetIntValue(a, "shk.lvl.bonus", bonus)
	endif
EndFunction

Function RemoveLeveling(Actor a)
	int applied = StorageUtil.GetIntValue(a, "shk.lvl.bonus", 0)
	if applied != 0
		ModSkills(a, -applied)
		StorageUtil.SetIntValue(a, "shk.lvl.bonus", 0)
	endif
EndFunction

; Each bonus level: +10 health, +5 magicka and stamina, +1 to combat skills.
Function ModSkills(Actor a, int levels)
	a.ModActorValue("Health", 10.0 * levels)
	a.ModActorValue("Magicka", 5.0 * levels)
	a.ModActorValue("Stamina", 5.0 * levels)
	a.ModActorValue("OneHanded", levels)
	a.ModActorValue("TwoHanded", levels)
	a.ModActorValue("Marksman", levels)
	a.ModActorValue("Block", levels)
	a.ModActorValue("HeavyArmor", levels)
	a.ModActorValue("LightArmor", levels)
	a.ModActorValue("Destruction", levels)
	a.ModActorValue("Restoration", levels)
	a.ModActorValue("Conjuration", levels)
	a.ModActorValue("Alteration", levels)
EndFunction

; ---------------------------------------------------------------------------
; Selling
; ---------------------------------------------------------------------------

; Opens the follower's inventory; what the player hands over is queued for sale.
Function GiveItemsToSell(Actor a, bool sellAfter = false)
	int slot = FindSlot(a)
	if slot < 0
		return
	endif
	(SlotAlias(slot) as SHK_FollowerAlias).BeginCollecting(sellAfter)
	CloseMenu()
	a.OpenInventory(true)
EndFunction

; The follower under the crosshair, else the nearest one within reach.
Actor Function AimedOrNearestFollower()
	Actor aimed = Game.GetCurrentCrosshairRef() as Actor
	if aimed && FindSlot(aimed) >= 0
		return aimed
	endif
	Actor best = None
	float bestDist = 1500.0
	int i = 0
	while i < MaxSlots
		Actor a = SlotActor(i)
		if a && !a.IsDead() && a.Is3DLoaded()
			float d = a.GetDistance(PlayerRef)
			if d < bestDist
				bestDist = d
				best = a
			endif
		endif
		i += 1
	endwhile
	return best
EndFunction

int Function SellQueueCount(Actor a)
	int total = 0
	int n = StorageUtil.FormListCount(a, "shk.sell.items")
	int i = 0
	while i < n
		total += StorageUtil.IntListGet(a, "shk.sell.counts", i)
		i += 1
	endwhile
	return total
EndFunction

Function QueueForSale(Actor a, Form item, int count)
	int idx = StorageUtil.FormListFind(a, "shk.sell.items", item)
	if idx < 0
		StorageUtil.FormListAdd(a, "shk.sell.items", item, true)
		StorageUtil.IntListAdd(a, "shk.sell.counts", count, true)
	else
		StorageUtil.IntListSet(a, "shk.sell.counts", idx, StorageUtil.IntListGet(a, "shk.sell.counts", idx) + count)
	endif
EndFunction

Function UnqueueForSale(Actor a, Form item, int count)
	int idx = StorageUtil.FormListFind(a, "shk.sell.items", item)
	if idx < 0
		return
	endif
	int left = StorageUtil.IntListGet(a, "shk.sell.counts", idx) - count
	if left <= 0
		StorageUtil.FormListRemoveAt(a, "shk.sell.items", idx)
		StorageUtil.IntListRemoveAt(a, "shk.sell.counts", idx)
	else
		StorageUtil.IntListSet(a, "shk.sell.counts", idx, left)
	endif
EndFunction

Function ClearSellQueue(Actor a)
	StorageUtil.FormListClear(a, "shk.sell.items")
	StorageUtil.IntListClear(a, "shk.sell.counts")
EndFunction

Actor Function FindMerchantNear(Actor a)
	Actor[] nearby = PO3_SKSEFunctions.GetActorsByProcessingLevel(0)
	Actor best = None
	float bestDist = 8000.0
	int i = 0
	while i < nearby.Length
		Actor m = nearby[i]
		if m && m != a && m != PlayerRef && IsMerchantCandidate(m)
			Faction vf = PO3_SKSEFunctions.GetVendorFaction(m)
			ObjectReference chest = None
			if vf
				chest = vf.GetMerchantContainer()
			endif
			; a real shopkeeper has a merchant chest with gold in it
			if chest && chest.GetItemCount(Gold) > 0
				float d = m.GetDistance(a)
				if d < bestDist
					bestDist = d
					best = m
				endif
			endif
		endif
		i += 1
	endwhile
	return best
EndFunction

; Not anyone travelling with the player, whatever framework they belong to.
bool Function IsMerchantCandidate(Actor m)
	if m.IsDead() || m.IsPlayerTeammate() || m.IsHostileToActor(PlayerRef) || m.IsInCombat()
		return false
	endif
	if m.IsInFaction(FollowerFaction) || m.IsInFaction(CurrentFollowerFaction) || m.IsInFaction(CurrentHireling)
		return false
	endif
	return m.Is3DLoaded()
EndFunction

Function StartSell(Actor a)
	if SellQueueCount(a) <= 0
		Notify(a.GetDisplayName() + " has nothing to sell. Give them items first.")
		return
	endif
	Actor merchant = FindMerchantNear(a)
	if !merchant
		Notify("No merchant nearby for " + a.GetDisplayName() + " to sell to.")
		return
	endif
	int before = StorageUtil.GetIntValue(a, "shk.mode", ModeFollow)
	if before == ModeSell
		return
	endif
	StorageUtil.SetIntValue(a, "shk.sell.prevmode", before)
	StorageUtil.SetFormValue(a, "shk.sell.merchant", merchant)
	StorageUtil.SetFloatValue(a, "shk.sell.started", Utility.GetCurrentRealTime())
	SetMode(a, ModeSell)
	Notify(a.GetDisplayName() + " heads to " + merchant.GetDisplayName() + " to sell.")
EndFunction

Function CancelSell(Actor a, bool notifyPlayer = true)
	if StorageUtil.GetIntValue(a, "shk.mode", ModeFollow) != ModeSell
		return
	endif
	int prev = StorageUtil.GetIntValue(a, "shk.sell.prevmode", ModeFollow)
	StorageUtil.UnsetFormValue(a, "shk.sell.merchant")
	PO3_SKSEFunctions.SetLinkedRef(a, None, LinkSell)
	StorageUtil.SetIntValue(a, "shk.mode", prev)
	a.SetFactionRank(ModeFaction, prev)
	a.EvaluatePackage()
	if notifyPlayer
		Notify(a.GetDisplayName() + " stopped selling.")
	endif
EndFunction

; Called by the follower alias once they reach the merchant.
Function CompleteSale(Actor a)
	Actor merchant = StorageUtil.GetFormValue(a, "shk.sell.merchant") as Actor
	if !merchant
		CancelSell(a, false)
		return
	endif
	ObjectReference chest = None
	Faction vf = PO3_SKSEFunctions.GetVendorFaction(merchant)
	if vf
		chest = vf.GetMerchantContainer()
	endif
	int purse = 0
	if chest
		purse = chest.GetItemCount(Gold)
	else
		purse = merchant.GetItemCount(Gold)
	endif

	float speech = a.GetActorValue("Speechcraft")
	if speech > 100.0
		speech = 100.0
	endif
	float mult = 0.25 + 0.15 * (speech / 100.0)

	int earned = 0
	int sold = 0
	int n = StorageUtil.FormListCount(a, "shk.sell.items")
	int i = n - 1
	while i >= 0
		Form item = StorageUtil.FormListGet(a, "shk.sell.items", i)
		int want = StorageUtil.IntListGet(a, "shk.sell.counts", i)
		int have = 0
		if item
			have = a.GetItemCount(item)
		endif
		if want > have
			want = have
		endif
		int each = 0
		if item
			each = (item.GetGoldValue() * mult) as int
		endif
		if each < 1
			each = 1
		endif
		int canAfford = want
		if each > 0 && purse - earned < each * want
			canAfford = (purse - earned) / each
		endif
		if canAfford > 0
			if chest
				a.RemoveItem(item, canAfford, true, chest)
			else
				a.RemoveItem(item, canAfford, true, merchant)
			endif
			earned += canAfford * each
			sold += canAfford
			UnqueueForSale(a, item, canAfford)
		elseif have == 0
			StorageUtil.FormListRemoveAt(a, "shk.sell.items", i)
			StorageUtil.IntListRemoveAt(a, "shk.sell.counts", i)
		endif
		i -= 1
	endwhile

	if earned > 0
		if chest
			chest.RemoveItem(Gold, earned, true, PlayerRef)
		else
			merchant.RemoveItem(Gold, earned, true, PlayerRef)
		endif
	endif
	string msg = a.GetDisplayName() + " sold " + sold + " items to " + merchant.GetDisplayName() + " for " + earned + " gold."
	if SellQueueCount(a) > 0
		msg += " " + merchant.GetDisplayName() + " ran out of gold for the rest."
	endif
	Debug.Notification(msg)
	CancelSell(a, false)
EndFunction

; ---------------------------------------------------------------------------
; Hotkey
; ---------------------------------------------------------------------------

Function BindMenuKey(int dik)
	if boundKey > 0
		UnregisterForKey(boundKey)
	endif
	boundKey = dik
	if dik > 0
		RegisterForKey(dik)
	endif
	StorageUtil.SetIntValue(None, "shk.set.key", dik)
EndFunction

Event OnKeyDown(int keyCode)
	if keyCode != boundKey || menuOpen
		return
	endif
	if Utility.IsInMenuMode() || UI.IsTextInputEnabled()
		return
	endif
	Actor target = Game.GetCurrentCrosshairRef() as Actor
	if target && FindSlot(target) < 0
		target = None
	endif
	OpenMenu(target)
EndEvent

; From dialogue: wait for the dialogue menu to close first.
Function OpenMenuSoon(Actor focus)
	pendingFocus = focus
	pendingOpen = true
	RegisterForSingleUpdate(0.5)
EndFunction

; ---------------------------------------------------------------------------
; Magelight menu
; ---------------------------------------------------------------------------

Function SetupMenu()
	domReady = false
	menuOpen = false
	if Magelight.GetVersion() <= 0
		return
	endif
	Magelight.RegisterMod(ModId, "Shield-Kin")
	menuView = Magelight.FindView(ModId, "main")
	if menuView == 0
		menuView = Magelight.CreateView(ModId, "main", "index.html", 0, 0, 0, 0, "panel", "top-left", false, false)
	else
		domReady = true
	endif
	if menuView != 0
		Magelight.RegisterListener(menuView, "shk")
		Magelight.SetHibernate(menuView, 0)
	endif
	RegisterForModEvent("Magelight_JS_shk", "OnMenuCommand")
	RegisterForModEvent("Magelight_ViewDomReady", "OnMenuDomReady")
	RegisterForModEvent("Magelight_ViewReloaded", "OnMenuDomReady")
	RegisterForModEvent("Magelight_UIModeExited", "OnMenuUIExited")
EndFunction

Function OpenMenu(Actor focus = None)
	if menuView == 0
		SetupMenu()
	endif
	if menuView == 0
		Debug.MessageBox("Shield-Kin's menu needs Magelight UI.")
		return
	endif
	menuOpen = true
	PushState(focus)
	Magelight.ShowView(menuView, true)
	if !Magelight.RequestUIMode(menuView, true)
		menuOpen = false
		Magelight.ShowView(menuView, false)
		Debug.Notification("Shield-Kin: " + Magelight.GetLastError(ModId))
		return
	endif
	Magelight.PlaySound(menuView, "open")
EndFunction

Function CloseMenu()
	if menuView == 0
		return
	endif
	if menuOpen
		Magelight.PlaySound(menuView, "close")
	endif
	menuOpen = false
	Magelight.ReleaseUIMode(ModId)
	Magelight.ShowView(menuView, false)
EndFunction

Function PushState(Actor focus = None)
	if menuView == 0
		return
	endif
	Magelight.Call(menuView, "shkState", BuildState(focus))
EndFunction

Event OnMenuDomReady(string eventName, string strArg, float numArg, Form sender)
	if (numArg as int) == menuView
		domReady = true
		if menuOpen
			PushState(None)
		endif
	endif
EndEvent

Event OnMenuUIExited(string eventName, string strArg, float numArg, Form sender)
	if menuOpen && StringUtil.Find(strArg, ModId) == 0
		menuOpen = false
		Magelight.ShowView(menuView, false)
	endif
EndEvent

Event OnMenuCommand(string eventName, string strArg, float numArg, Form sender)
	string[] p = StringUtil.Split(strArg, "|")
	if p.Length == 0
		return
	endif
	; the page appends a sequence number; the state echoes it back as "ack"
	int n = p.Length
	if n >= 2
		menuAck = p[n - 1] as int
		n -= 1
	endif
	string kind = p[0]
	Actor focus = None
	bool push = true
	if kind == "close"
		CloseMenu()
		return
	elseif kind == "refresh"
	elseif kind == "f" && n >= 3
		focus = Game.GetForm(p[1] as int) as Actor
		string arg = ""
		if n >= 4
			arg = p[3]
		endif
		if focus
			if !FollowerCommand(focus, p[2], arg)
				return
			endif
			; the page already shows these; rebuilding the state while paused is slow
			push = !IsQuickVerb(p[2]) || (p[2] == "mode" && (arg as int) == ModeHome)
		endif
	elseif kind == "p" && n >= 2
		PartyCommand(p[1])
		push = !(p[1] == "follow" || p[1] == "wait" || p[1] == "sandbox")
	elseif kind == "r" && n >= 3
		Actor r = Game.GetForm(p[1] as int) as Actor
		if r
			RegistryCommand(r, p[2])
		endif
	elseif kind == "s" && n >= 3
		SettingCommand(p[1], p[2])
		push = false
	endif
	if menuOpen && push
		PushState(focus)
	endif
EndEvent

bool Function IsQuickVerb(string verb)
	return verb == "mode" || verb == "dist" || verb == "style" || verb == "stance" || verb == "prot" || verb == "outfitauto"
EndFunction

; Returns false when the command closed the menu.
bool Function FollowerCommand(Actor a, string verb, string arg)
	int n = arg as int
	if verb == "mode"
		SetMode(a, n)
	elseif verb == "dist"
		SetDistance(a, n)
	elseif verb == "style"
		SetStyle(a, n)
	elseif verb == "stance"
		SetStance(a, n)
	elseif verb == "prot"
		SetProtection(a, n)
	elseif verb == "sethome"
		SetHomeHere(a)
	elseif verb == "clearhome"
		ClearHome(a)
	elseif verb == "summon"
		Summon(a)
	elseif verb == "outfitsave"
		SaveOutfit(a, n)
	elseif verb == "outfitclear"
		ClearOutfit(a, n)
	elseif verb == "outfitwear"
		TakeOverOutfit(a)
		WearOutfit(a, n)
	elseif verb == "outfitauto"
		StorageUtil.SetIntValue(a, "shk.outfit.auto", n)
		UpdateOutfit(a)
	elseif verb == "sell"
		StartSell(a)
	elseif verb == "sellcancel"
		CancelSell(a, true)
	elseif verb == "sellclear"
		ClearSellQueue(a)
	elseif verb == "give"
		GiveItemsToSell(a)
		return false
	elseif verb == "trade"
		CloseMenu()
		a.OpenInventory(true)
		return false
	elseif verb == "dismiss"
		Dismiss(a)
	endif
	return true
EndFunction

Function PartyCommand(string verb)
	if verb == "follow"
		PartyMode(ModeFollow)
	elseif verb == "wait"
		PartyMode(ModeWait)
	elseif verb == "sandbox"
		PartyMode(ModeSandbox)
	elseif verb == "summon"
		SummonAll()
	elseif verb == "camp"
		MakeCamp()
	elseif verb == "breakcamp"
		PartyMode(ModeFollow)
	endif
EndFunction

Function RegistryCommand(Actor r, string verb)
	if verb == "recall"
		Summon(r)
		Recruit(r)
	elseif verb == "summon"
		Summon(r)
	elseif verb == "forget"
		Forget(r)
	elseif verb == "clearhome"
		ClearHome(r)
		ActorUtil.RemovePackageOverride(r, PkgHome)
		r.EvaluatePackage()
	endif
EndFunction

Function SettingCommand(string k, string v)
	if k == "key"
		BindMenuKey(v as int)
	elseif k == "catchup"
		StorageUtil.SetFloatValue(None, "shk.set.catchup", v as float)
	elseif k == "level"
		StorageUtil.SetIntValue(None, "shk.set.level", v as int)
		ApplyLevelingAll()
	elseif k == "levelpct"
		StorageUtil.SetFloatValue(None, "shk.set.levelpct", v as float)
		ApplyLevelingAll()
	elseif k == "notify"
		StorageUtil.SetIntValue(None, "shk.set.notify", v as int)
	elseif k == "autooutfit"
		StorageUtil.SetIntValue(None, "shk.set.autooutfit", v as int)
	elseif k == "dist"
		StorageUtil.SetIntValue(None, "shk.set.dist", v as int)
	elseif k == "scale"
		StorageUtil.SetFloatValue(None, "shk.set.scale", v as float)
	elseif k == "theme"
		StorageUtil.SetStringValue(None, "shk.set.theme", v)
	elseif k == "power"
		StorageUtil.SetIntValue(None, "shk.set.power", v as int)
		UpdatePower()
	endif
EndFunction

; ---------------------------------------------------------------------------
; JSON for the menu
; ---------------------------------------------------------------------------

string Function Esc(string s)
	if StringUtil.Find(s, "\"") >= 0
		s = PapyrusUtil.StringJoin(PapyrusUtil.StringSplit(s, "\""), "'")
	endif
	if StringUtil.Find(s, "\\") >= 0
		s = PapyrusUtil.StringJoin(PapyrusUtil.StringSplit(s, "\\"), "/")
	endif
	return s
EndFunction

string Function Str(string k, string v)
	return "\"" + k + "\":\"" + Esc(v) + "\""
EndFunction

string Function Num(string k, float v)
	return "\"" + k + "\":" + (v as int)
EndFunction

string Function NumI(string k, int v)
	return "\"" + k + "\":" + v
EndFunction

string Function BuildState(Actor focus)
	string s = "{\"v\":1," + NumI("ack", menuAck)
	if focus
		s += "," + NumI("focus", focus.GetFormID())
	else
		s += ",\"focus\":0"
	endif
	s += ",\"max\":" + MaxSlots
	s += ",\"settings\":{" + Num("key", StorageUtil.GetIntValue(None, "shk.set.key", 65))
	s += "," + Num("catchup", StorageUtil.GetFloatValue(None, "shk.set.catchup", 3000.0))
	s += "," + Num("level", StorageUtil.GetIntValue(None, "shk.set.level", 0))
	s += "," + Num("levelpct", StorageUtil.GetFloatValue(None, "shk.set.levelpct", 90.0))
	s += "," + Num("notify", StorageUtil.GetIntValue(None, "shk.set.notify", 1))
	s += "," + Num("autooutfit", StorageUtil.GetIntValue(None, "shk.set.autooutfit", 1))
	s += "," + Num("dist", StorageUtil.GetIntValue(None, "shk.set.dist", 1))
	s += "," + Num("scale", StorageUtil.GetFloatValue(None, "shk.set.scale", 100.0))
	s += "," + Num("power", StorageUtil.GetIntValue(None, "shk.set.power", 1))
	s += "," + Str("theme", StorageUtil.GetStringValue(None, "shk.set.theme", "vellum")) + "}"

	s += ",\"followers\":["
	bool first = true
	int i = 0
	while i < MaxSlots
		Actor a = SlotActor(i)
		if a
			if !first
				s += ","
			endif
			first = false
			s += FollowerJson(a)
		endif
		i += 1
	endwhile
	s += "]"

	s += ",\"others\":["
	first = true
	Actor[] team = PO3_SKSEFunctions.GetPlayerFollowers()
	i = 0
	while i < team.Length
		Actor o = team[i]
		if o && FindSlot(o) < 0 && !o.IsDead()
			if !first
				s += ","
			endif
			first = false
			s += "{" + NumI("id", o.GetFormID()) + "," + Str("name", o.GetDisplayName()) + "," + Str("race", o.GetRace().GetName())
			s += "," + Num("lvl", o.GetLevel()) + "," + Num("hp", o.GetActorValuePercentage("Health") * 100.0) + "}"
		endif
		i += 1
	endwhile
	s += "]"

	s += ",\"registry\":["
	first = true
	int n = StorageUtil.FormListCount(None, "shk.registry")
	i = 0
	while i < n
		Actor r = StorageUtil.FormListGet(None, "shk.registry", i) as Actor
		if r && !r.IsDead()
			if !first
				s += ","
			endif
			first = false
			s += "{" + NumI("id", r.GetFormID()) + "," + Str("name", r.GetDisplayName()) + "," + Str("race", r.GetRace().GetName())
			s += "," + Num("lvl", r.GetLevel()) + "," + Str("home", StorageUtil.GetStringValue(r, "shk.homename", "")) + "}"
		endif
		i += 1
	endwhile
	s += "]}"
	return s
EndFunction

string Function FollowerJson(Actor a)
	string cls = ""
	Class c = a.GetActorBase().GetClass()
	if c
		cls = c.GetName()
	endif
	string s = "{" + NumI("id", a.GetFormID())
	s += "," + Str("name", a.GetDisplayName())
	s += "," + Str("race", a.GetRace().GetName())
	s += "," + Str("cls", cls)
	s += "," + Num("lvl", a.GetLevel())
	s += "," + Num("hp", a.GetActorValuePercentage("Health") * 100.0)
	s += "," + Num("mp", a.GetActorValuePercentage("Magicka") * 100.0)
	s += "," + Num("sp", a.GetActorValuePercentage("Stamina") * 100.0)
	s += "," + Num("mode", StorageUtil.GetIntValue(a, "shk.mode", 0))
	s += "," + Num("dist", StorageUtil.GetIntValue(a, "shk.dist", 1))
	s += "," + Num("style", StorageUtil.GetIntValue(a, "shk.style", 0))
	s += "," + Num("stance", StorageUtil.GetIntValue(a, "shk.stance", 0))
	s += "," + Num("prot", StorageUtil.GetIntValue(a, "shk.prot", 1))
	s += "," + Num("away", a.GetDistance(PlayerRef))
	s += "," + Num("combat", a.IsInCombat() as int)
	s += "," + Str("home", StorageUtil.GetStringValue(a, "shk.homename", ""))
	s += "," + Num("outfitauto", StorageUtil.GetIntValue(a, "shk.outfit.auto", StorageUtil.GetIntValue(None, "shk.set.autooutfit", 1)))
	s += "," + Num("outfitnow", StorageUtil.GetIntValue(a, "shk.outfit.current", -1))
	s += ",\"outfits\":[" + StorageUtil.FormListCount(a, OutfitKey(0)) + "," + StorageUtil.FormListCount(a, OutfitKey(1)) + "," + StorageUtil.FormListCount(a, OutfitKey(2)) + "," + StorageUtil.FormListCount(a, OutfitKey(3)) + "," + StorageUtil.FormListCount(a, OutfitKey(4)) + "]"
	s += "," + Num("sell", SellQueueCount(a))
	Actor m = StorageUtil.GetFormValue(a, "shk.sell.merchant") as Actor
	if m
		s += "," + Str("merchant", m.GetDisplayName())
	endif
	s += "," + Num("bonus", StorageUtil.GetIntValue(a, "shk.lvl.bonus", 0))
	s += "}"
	return s
EndFunction

; ---------------------------------------------------------------------------
; Helpers
; ---------------------------------------------------------------------------

Function Notify(string msg)
	if StorageUtil.GetIntValue(None, "shk.set.notify", 1) == 1
		Debug.Notification(msg)
	endif
EndFunction
