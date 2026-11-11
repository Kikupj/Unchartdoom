// ============================================================================
// Treasure, intel, supplies and the randomised spots that hand them out.
// ============================================================================
class AB_Pickup : Inventory abstract
{
	int amount; String kind;
	property Loot: kind, amount;
	Default { +INVENTORY.ALWAYSPICKUP; Inventory.PickupSound "ab/coin"; Inventory.MaxAmount 0; Radius 16; Height 16; }
	virtual String Describe(int got) { return ""; }
	override bool TryPickup(in out Actor toucher)
	{
		if (!toucher || !toucher.player) return false;
		let lv = AB_Level.Get();
		int got = lv ? lv.AddHaul(kind, amount) : amount;
		String d = Describe(got);
		if (d.Length() && lv) lv.Ticker(d);
		GoAwayAndDie();
		return true;
	}
	override String PickupMessage() { return ""; }
}

class AB_Coins : AB_Pickup    { Default { AB_Pickup.Loot "gold", 8; }  override void PostBeginPlay() { Super.PostBeginPlay(); amount = random[ABL](5, 12); } States { Spawn: ABCN A -1; Stop; } override String Describe(int g) { return String.Format("\cf+%d\c- gold coins", g); } }
class AB_GoldBar : AB_Pickup  { Default { AB_Pickup.Loot "gold", 30; } States { Spawn: ABBR A -1; Stop; } override String Describe(int g) { return String.Format("\cf+%d\c- gold bars", g); } }
class AB_Gem : AB_Pickup
{
	Default { AB_Pickup.Loot "gold", 20; Inventory.PickupSound "ab/gem"; }
	override void PostBeginPlay() { Super.PostBeginPlay(); frame = random[ABL](0, 2); }
	States { Spawn: ABJW A -1 Bright; Stop; ABJW BC 0; }
	override String Describe(int g) { return String.Format("\cf+%d\c- uncut gemstone", g); }
}
class AB_Chalice : AB_Pickup  { Default { AB_Pickup.Loot "gold", 45; Inventory.PickupSound "ab/gem"; } States { Spawn: ABCH A -1; Stop; } override String Describe(int g) { return String.Format("\cf+%d\c- jewelled chalice", g); } }
class AB_Idol : AB_Pickup     { Default { AB_Pickup.Loot "gold", 90; Inventory.PickupSound "ab/relic"; } States { Spawn: ABID A -1; Stop; } override String Describe(int g) { return String.Format("\cf+%d\c- golden idol", g); } }
class AB_Intel : AB_Pickup    { Default { AB_Pickup.Loot "intel", 1; Inventory.PickupSound "ab/intel"; } States { Spawn: ABIN A -1; Stop; } override String Describe(int g) { return "\cv+1 Intel\c- - Meridian field orders"; } }
class AB_SupplyCrate : AB_Pickup { Default { AB_Pickup.Loot "supplies", 20; Inventory.PickupSound "ab/crate"; } States { Spawn: ABSP A -1; Stop; } override String Describe(int g) { return String.Format("\cd+%d Supplies\c-", g); } }
class AB_Materials : AB_Pickup   { Default { AB_Pickup.Loot "materials", 30; Inventory.PickupSound "ab/crate"; } override void PostBeginPlay() { Super.PostBeginPlay(); amount = random[ABL](24, 44); } States { Spawn: ABMT A -1; Stop; } override String Describe(int g) { return String.Format("\cq+%d Materials\c-", g); } }

// A numbered relic for the Archive.
class AB_RelicPickup : AB_Pickup
{
	Default { AB_Pickup.Loot "relic", 1; Inventory.PickupSound "ab/relic"; Scale 0.55; +FLOATBOB; }
	States { Spawn: ABRL AB 12 Bright; Loop; }
	override bool TryPickup(in out Actor toucher)
	{
		if (!toucher || !toucher.player) return false;
		let g = AB_Game.Get(); let lv = AB_Level.Get();
		int region = g ? g.v[AB.R_REGION] : 0;
		int rel = (g && g.InRun() && region < 4) ? g.PickNewRelic(region) : -1;
		if (rel >= 0) { g.v[AB.R_RELICS] |= 1 << (rel % 5); if (lv) { lv.AddHaul("gold", 60); lv.Say("\cfRELIC FOUND\c-\n" .. AB.RelicName[rel] .. "\n\cjGet it home to add it to the Archive.", 175); } }
		else if (lv) { int got = lv.AddHaul("gold", 120); lv.Ticker(String.Format("\cf+%d\c- antique curio", got)); }
		GoAwayAndDie(); return true;
	}
}

// The prize at the bottom of every expedition.
class AB_GreatTreasure : AB_Pickup
{
	Default { AB_Pickup.Loot "great", 1; Inventory.PickupSound "ab/great"; +FLOATBOB; Radius 20; Height 40; }
	States { Spawn: ABRL AB 10 Bright; Loop; }
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		let g = AB_Game.Get();
		if (g && g.InRun() && !g.GreatAvailable())
		{	// somebody already has it: leave a consolation hoard
			for (int i = 0; i < 4; i++)
			{
				Vector3 p = pos + (frandom[ABL](-24, 24), frandom[ABL](-24, 24), 0);
				if (i == 0) Spawn("AB_Idol", p); else Spawn("AB_GoldBar", p);
			}
			Destroy();
		}
	}
	override bool TryPickup(in out Actor toucher)
	{
		if (!toucher || !toucher.player) return false;
		let g = AB_Game.Get(); let lv = AB_Level.Get();
		if (lv && !lv.CanTakeGreat()) return false;
		if (g && g.InRun()) g.v[AB.R_GREAT] = 1;
		if (lv) lv.GreatTaken();
		GoAwayAndDie(); return true;
	}
}

class AB_Fragment : AB_Pickup
{
	Default { AB_Pickup.Loot "none", 0; Inventory.PickupSound "ab/gem"; +FLOATBOB; }
	States { Spawn: ABFG A -1 Bright; Stop; }
	override bool TryPickup(in out Actor toucher)
	{
		if (!toucher || !toucher.player) return false;
		let lv = AB_Level.Get();
		if (lv) lv.FragmentFound(args[0]);
		GoAwayAndDie(); return true;
	}
}

// ---------------------------------------------------------------- spots
class AB_Spot : Actor abstract
{
	Default { +NOBLOCKMAP; +NOINTERACTION; +DONTSPLASH; RenderStyle "None"; Radius 8; Height 8; }
	States { Spawn: TNT1 A -1; Stop; }
	Actor Put(String cls, double spread = 0)
	{
		class<Actor> c = (class<Actor>)(cls); if (!c) return null;
		Vector3 p = pos; if (spread > 0) p.XY += (frandom[ABL](-spread, spread), frandom[ABL](-spread, spread));
		p.Z = GetZAt(p.X, p.Y, 0, GZF_ABSOLUTEPOS);
		return Spawn(c, p, ALLOW_REPLACE);
	}
}

class AB_LootSpot : AB_Spot
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		let g = AB_Game.Get();
		int q = args[0], r = random[ABL](0, 99);
		bool scholar = g && g.PartnerClass() == 2;
		if (q <= 0)      { if (r < 50) Put("AB_Coins"); else if (r < 80) Put("AB_Gem"); else if (r < 92) Put("AB_GoldBar"); else { Put("AB_Coins", 10); Put("AB_Coins", 10); } }
		else if (q == 1) { if (r < 30) Put("AB_GoldBar"); else if (r < 52) Put("AB_Chalice"); else if (r < 66) { Put("AB_Gem", 8); Put("AB_Gem", 8); } else if (r < 84) Put("AB_Materials"); else Put("AB_SupplyCrate"); }
		else if (q == 2) { if (r < (scholar ? 45 : 28)) Put("AB_RelicPickup"); else if (r < 62) Put("AB_Idol"); else if (r < 82) Put("AB_Intel"); else { Put("AB_Chalice", 10); Put("AB_GoldBar", 10); } }
		else if (q == 3) Put("AB_Intel");
		else if (q == 4) Put("AB_RelicPickup");
		else if (q == 5) { Put("AB_Materials"); }
		Destroy();
	}
}

class AB_SupplySpot : AB_Spot
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		int k = args[0], r = random[ABL](0, 99);
		if (k == 2) { k = r < 60 ? 0 : 1; r = random[ABL](0, 99); }
		if (k == 0)
		{
			let p = players[consoleplayer].mo;
			if (r < 40) Put("Clip"); else if (r < 62) Put("Shell"); else if (r < 76) Put("ClipBox"); else if (r < 84) Put("ShellBox");
			else if (p && AB_Player.Has(p, "HandGrenade") && r < 92) Put("HandGrenadeAmmo");
			else if (p && AB_Player.Has(p, "MolotovCocktail") && r < 96) Put("MolotovAmmo");
			else if (p && AB_Player.Has(p, "MicroUzi")) Put("UziAmmo");
			else if (p && AB_Player.Has(p, "Flaregun")) Put("Flares");
			else Put("Clip");
		}
		else { if (r < 55) Put("Stimpack"); else if (r < 80) Put("Medikit"); else if (r < 92) Put("GreenArmor"); else { Put("Stimpack", 10); Put("Stimpack", 10); } }
		Destroy();
	}
}

// What mercs drop instead of Doom guns.
class AB_AmmoDrop : Actor
{
	Default { +NOBLOCKMAP; }
	States { Spawn: TNT1 A 0 NoDelay { Actor a; if (random[ABL](0, 99) < 68) a = Spawn("Clip", pos, ALLOW_REPLACE); else a = Spawn("Shell", pos, ALLOW_REPLACE); if (a) { a.bDropped = true; a.Vel = Vel; } } Stop; }
}

class AB_Urn : Actor
{
	Default { Health 8; Radius 12; Height 28; Mass 100000; +SOLID; +SHOOTABLE; +NOBLOOD; +DONTTHRUST; +NOTAUTOAIMED; DeathSound "ab/urn"; }
	override void PostBeginPlay() { Super.PostBeginPlay(); frame = random[ABL](0, 1); }
	States
	{
	Spawn: ABUR A -1; Stop; ABUR B 0;
	Death:
		TNT1 A 0 { A_Scream(); A_NoBlocking();
			for (int i = 0; i < 6; i++) A_SpawnItemEx("AB_Shard", frandom(-6, 6), frandom(-6, 6), frandom(8, 24), frandom(-3, 3), frandom(-3, 3), frandom(2, 6));
			int r = random[ABL](0, 99);
			if (r < 45) Spawn("AB_Coins", pos); else if (r < 58) Spawn("AB_Gem", pos); else if (r < 66) Spawn("Clip", pos); else if (r < 72) Spawn("Stimpack", pos); }
		TNT1 A 1; Stop;
	}
}
class AB_Shard : Actor
{
	Default { Radius 2; Height 2; +MISSILE; +NOBLOCKMAP; +DROPOFF; Gravity 0.7; Scale 0.35; BounceType "Doom"; BounceCount 2; }
	States { Spawn: ABUR A 30; ABUR A 6 A_FadeOut(0.25); Wait; Death: TNT1 A 1; Stop; }
}
