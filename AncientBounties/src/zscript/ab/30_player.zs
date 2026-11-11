// ============================================================================
// The treasure hunter: never really dies (an expedition "fails" instead),
// can dodge-roll, carries medkits, and has run-long boon modifiers.
// ============================================================================
class AB_Hands : Weapon
{
	Default { Weapon.SelectionOrder 9000; Tag "Empty Hands"; +WEAPON.CHEATNOTWEAPON; +WEAPON.NOALERT; }
	States
	{
	Ready:    TNT1 A 1 A_WeaponReady; Loop;
	Deselect: TNT1 A 1 A_Lower(18); Loop;
	Select:   TNT1 A 1 A_Raise(18); Loop;
	Fire:     TNT1 A 12; Goto Ready;
	Spawn:    TNT1 A -1; Stop;
	}
}

class AB_ArmorShard : BasicArmorBonus
{
	Default { Armor.SavePercent 40; Armor.SaveAmount 1; Armor.MaxSaveAmount 200; Inventory.PickupMessage ""; +INVENTORY.ALWAYSPICKUP; }
	States { Spawn: BON2 A -1; Stop; }
}

// Outgoing damage boons.
class AB_Perks : Inventory
{
	Default { Inventory.MaxAmount 1; +INVENTORY.UNDROPPABLE; +INVENTORY.UNTOSSABLE; +INVENTORY.PERSISTENTPOWER; }
	override void ModifyDamage(int damage, Name damageType, out int newdamage, bool passive, Actor inflictor, Actor source, int flags)
	{
		if (passive || damage <= 0) return;
		let g = AB_Game.Get(); if (!g) return;
		double f = 1.0 + 0.20 * g.Boon(AB.BN_FURY);
		if (g.SetDone(3)) f += 0.10;
		if (g.InRun() && g.PartnerClass() == 1) f += 0.10;
		if (f != 1.0) newdamage = max(1, int(damage * f + 0.5));
	}
}

class AB_Player : DoomPlayer
{
	int dodgeReady, dodgeUntil;
	bool down;

	Default
	{
		Player.DisplayName "Treasure Hunter";
		Player.StartItem "AB_Hands";
		Player.WeaponSlot 1, "Machete", "Knife", "AB_Hands";
		Player.WeaponSlot 2, "Colt45", "MicroUzi";
		Player.WeaponSlot 3, "Coachgun", "TacticalShotgun", "RiotShotgun";
		Player.WeaponSlot 4, "MP5", "SuppressedMP5", "AK47", "VM16", "HMachinegun";
		Player.WeaponSlot 5, "HuntingRifle", "Flaregun";
		Player.WeaponSlot 6, "HandGrenade", "MolotovCocktail";
		Player.JumpZ 9;
		+BUDDHA
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (down) return 0;
		let g = AB_Game.Get();
		if (level.maptime < dodgeUntil && !(flags & DMG_FORCED)) return 0;		// roll i-frames
		if (g && damage > 0)
		{
			double f = 1.0;
			for (int i = 0; i < g.Boon(AB.BN_SCALES); i++) f *= 0.85;
			if (g.Boon(AB.BN_CURSE) && source && source.bIsMonster) f *= 1.25;
			damage = max(1, int(damage * f));
		}
		int r = Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		if (health <= 1 && !down) GoDown();
		return r;
	}

	void GoDown()
	{
		let g = AB_Game.Get();
		let lv = AB_Level.Get();
		if (!g || !lv || lv.isCamp) { A_SetHealth(MaxHealth); return; }
		if (g.InRun() && g.v[AB.R_REVIVES] > 0)
		{
			g.v[AB.R_REVIVES]--;
			A_SetHealth(max(30, MaxHealth * 2 / 5));
			dodgeUntil = level.maptime + 70;
			A_StartSound("ab/revive", CHAN_BODY);
			lv.Say("\cdSECOND WIND\c-  You claw your way back up.", 120);
			return;
		}
		down = true;
		bInvulnerable = true; bShootable = false;
		Vel = (0, 0, 0);
		if (player) { player.cheats |= CF_TOTALLYFROZEN; player.damagecount = 60; }
		A_StartSound("*death", CHAN_VOICE);
		lv.Fail();
	}

	void TryDodge()
	{
		if (down || !player || !player.onground || level.maptime < dodgeReady) return;
		let g = AB_Game.Get();
		Vector2 dir = (player.cmd.forwardmove, -player.cmd.sidemove);
		if (dir.Length() < 1) dir = (-1, 0);		// no input: hop backwards
		dir = RotateVector(dir.Unit(), angle);
		Vel.XY = dir * 15;
		Vel.Z = 2.5;
		dodgeUntil = level.maptime + 12;
		dodgeReady = level.maptime + ((g && g.Boon(AB.BN_FLEET)) ? 30 : 55);
		player.crouchfactor = 0.6;
		A_StartSound("ab/dodge", CHAN_BODY, 0, 0.7);
	}

	void UseMedkit()
	{
		let g = AB_Game.Get(); let lv = AB_Level.Get();
		if (down || !g || !g.InRun() || !lv) return;
		if (g.v[AB.R_MEDKITS] <= 0) { lv.Say("No medkits left.", 60); return; }
		if (health >= MaxHealth) { lv.Say("You're in one piece. Save it.", 60); return; }
		g.v[AB.R_MEDKITS]--;
		GiveBody(50, MaxHealth);
		A_StartSound("ab/medkit", CHAN_ITEM);
		lv.Say(String.Format("\cdMedkit used.\c-  %d left.", g.v[AB.R_MEDKITS]), 70);
	}

	static void SetAmmo(Actor p, String cls, int amount)
	{
		class<Inventory> c = (class<Inventory>)(cls); if (!c) return;
		let it = p.FindInventory(c);
		if (!it) { p.GiveInventory(c, 1); it = p.FindInventory(c); }
		if (it) it.Amount = clamp(amount, 0, it.MaxAmount);
	}

	// pct of max ammo to top up to; also restocks throwables
	static void Refill(Actor p, int pct)
	{
		for (let it = p.Inv; it; it = it.Inv)
		{
			let am = Ammo(it); if (!am) continue;
			String n = am.GetClassName();
			if (n == "HandGrenadeAmmo" || n == "MolotovAmmo") { am.Amount = min(am.MaxAmount, am.Amount + 2); continue; }
			if (n == "ThrowPower" || n.IndexOf("Token") >= 0) continue;
			am.Amount = max(am.Amount, am.MaxAmount * pct / 100);
		}
	}

	static bool Has(Actor p, String cls) { class<Inventory> c = (class<Inventory>)(cls); return c && p.FindInventory(c); }

	// called once at the start of an expedition
	static void GiveLoadout(PlayerPawn p)
	{
		let g = AB_Game.Get(); if (!g || !p) return;
		p.TakeInventory("AB_Hands", 1);
		String first = "";
		for (int w = 0; w < AB.NUM_WEAPONS; w++)
		{
			if (!g.Equipped(w)) continue;
			class<Inventory> c = (class<Inventory>)(AB.WpnClass[w]);
			if (c) { p.GiveInventory(c, 1); if (AB.WpnKind[w] == 1 || (AB.WpnKind[w] == 2 && first == "")) first = AB.WpnClass[w]; }
		}
		double mul = 1.0 + (g.HasGear(AB.G_SATCHEL) ? 0.5 : 0) + (g.PartnerClass() == 1 ? 0.3 : 0);
		int arm = g.Bld(AB.B_ARMORY);
		SetAmmo(p, "Clip", int((60 + 15 * arm) * mul));
		if (Has(p, "Coachgun") || Has(p, "TacticalShotgun") || Has(p, "RiotShotgun")) SetAmmo(p, "Shell", int((14 + 4 * arm) * mul));
		if (Has(p, "RiotShotgun")) SetAmmo(p, "RicoShell", 8);
		if (Has(p, "MicroUzi")) SetAmmo(p, "UziAmmo", int(90 * mul));
		if (Has(p, "Flaregun")) SetAmmo(p, "Flares", 9);
		int extra = g.HasGear(AB.G_BANDOLIER) ? 3 : 0;
		if (Has(p, "HandGrenade")) SetAmmo(p, "HandGrenadeAmmo", 4 + extra);
		if (Has(p, "MolotovCocktail")) SetAmmo(p, "MolotovAmmo", 3 + extra);
		if (g.HasGear(AB.G_VEST2)) p.GiveInventory("AB_ArmorShard", 100);
		else if (g.HasGear(AB.G_VEST1)) p.GiveInventory("AB_ArmorShard", 50);
		if (first != "") { class<Weapon> wc = (class<Weapon>)(first); if (wc) p.A_SelectWeapon(wc); }
	}

	// called at the start of every stage
	static void Prepare(PlayerPawn p, bool fullHeal)
	{
		let g = AB_Game.Get(); if (!g || !p) return;
		p.MaxHealth = g.MaxHealthNow();
		if (fullHeal) p.A_SetHealth(p.MaxHealth);
		p.Speed = 1.0 + 0.12 * g.Boon(AB.BN_FLEET);
		if (!p.FindInventory("AB_Perks")) p.GiveInventory("AB_Perks", 1);
		let ap = AB_Player(p);
		if (ap) { ap.down = false; ap.bInvulnerable = false; ap.bShootable = true; ap.dodgeReady = 0; ap.dodgeUntil = 0; }
		if (p.player) p.player.cheats &= ~CF_TOTALLYFROZEN;
	}
}
