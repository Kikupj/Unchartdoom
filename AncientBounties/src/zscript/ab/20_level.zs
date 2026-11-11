// ============================================================================
// AB_Level - per-map director: populates the map, runs the expedition flow,
// handles failure/extraction and draws the field HUD.
// ============================================================================
class AB_Level : EventHandler
{
	bool isCamp, isMission, exiting, tookGreat, exitArmed;
	int myRun, failTic, kickTic, bossCount, enemiesPlaced;
	String sayText; int sayStart, sayUntil;
	Array<String> tickText; Array<int> tickTic;
	// puzzle clue shown on the HUD
	int cluePid; String clueText; Array<int> clueGlyph, clueColour;
	Array<int> fragPid; int fragHave, fragNeed;
	String objective;
	int openMenuTic;

	static clearscope AB_Level Get() { return AB_Level(EventHandler.Find("AB_Level")); }

	// ------------------------------------------------------------ messages
	void Say(String s, int tics = 140) { sayText = s; sayStart = level.maptime; sayUntil = level.maptime + tics; }
	void Ticker(String s)
	{
		tickText.Push(s); tickTic.Push(level.maptime);
		if (tickText.Size() > 5) { tickText.Delete(0); tickTic.Delete(0); }
	}
	void SetClue(int pid, String text, Array<int> glyphs, Array<int> colours)
	{
		cluePid = pid; clueText = text; clueGlyph.Copy(glyphs); clueColour.Copy(colours);
		Say("\cfYou copy the carving into your journal.\c-", 90);
	}
	void PuzzleSolved(int pid) { if (cluePid == pid) { cluePid = 0; clueGlyph.Clear(); clueColour.Clear(); } }
	void FragmentFound(int pid)
	{
		let it = ThinkerIterator.Create("AB_PuzzleCore"); AB_PuzzleCore c;
		while (c = AB_PuzzleCore(it.Next())) if (c.pid == pid) { c.fragsHave++; Say(String.Format("\cfIdol fragment\c-  %d of %d\n%s", c.fragsHave, c.fragsNeeded, c.fragsHave >= c.fragsNeeded ? "Take them to the altar." : ""), 100); }
	}

	// ------------------------------------------------------------ loot
	int AddHaul(String kind, int amount)
	{
		let g = AB_Game.Get();
		if (kind == "gold" && g)
		{
			double f = 1.0 + 0.3 * g.Boon(AB.BN_FORTUNE) + 1.0 * g.Boon(AB.BN_CURSE) + (g.HasGear(AB.G_COMPASS) ? 0.2 : 0) + (g.SetDone(1) ? 0.15 : 0);
			amount = int(amount * f + 0.5);
		}
		if (!g || !g.InRun()) return amount;
		if (kind == "gold") g.v[AB.R_GOLD] += amount;
		else if (kind == "materials") g.v[AB.R_MAT] += amount;
		else if (kind == "supplies") g.v[AB.R_SUP] += amount;
		else if (kind == "intel") g.v[AB.R_INTEL] += amount;
		return amount;
	}

	// ------------------------------------------------------------ vault
	bool CanTakeGreat()
	{
		if (bossCount > 0) { if (level.maptime > sayUntil) Say("\cgNot while he's still standing.\c-", 70); return false; }
		return true;
	}
	void GreatTaken()
	{
		let g = AB_Game.Get();
		tookGreat = true; exitArmed = true;
		int region = g ? g.v[AB.R_REGION] : 0;
		AddHaul("gold", 150);
		Say(String.Format("\cf%s\c-\nis yours. Now get to the flare - alive.", AB.GreatName[region]), 175);
		objective = "Reach the extraction flare";
		TriggerGroup(9, "");
		if (g && region != AB.CITADEL) g.Radio("Thorne: \"" .. AB.ThorneTaunt[random[ABL](0, AB.ThorneTaunt.Size() - 1)] .. "\"");
	}

	void TriggerGroup(int group, String msg)
	{
		int n = 0;
		let it = ThinkerIterator.Create("AB_EnemySpot"); AB_EnemySpot s;
		Array<AB_EnemySpot> list;
		while (s = AB_EnemySpot(it.Next())) if (s.args[1] == group) list.Push(s);
		for (int i = 0; i < list.Size(); i++) if (list[i].Fire(true)) n++;
		if (n && msg.Length()) { Say(msg, 100); S_StartSound("ab/alarm", CHAN_AUTO, 0, 0.8, ATTN_NONE); }
	}

	// ------------------------------------------------------------ flow
	void Fail()
	{
		if (failTic) return;
		failTic = level.maptime + 120;
		S_StartSound("ab/fail", CHAN_AUTO, 0, 1.0, ATTN_NONE);
	}

	void ReachExit(Actor who)
	{
		if (exiting || failTic) return;
		let g = AB_Game.Get();
		let p = PlayerPawn(who); if (!p) return;
		if (!g || !g.InRun() || !isMission) { exiting = true; level.ChangeLevel("ABCAMP", 0, CHANGELEVEL_NOINTERMISSION | CHANGELEVEL_RESETINVENTORY | CHANGELEVEL_RESETHEALTH); return; }
		if (g.StageType() == 2 && g.GreatAvailable() && !tookGreat) { if (level.maptime > sayUntil) Say("You didn't come all this way to leave it behind.", 80); return; }
		exiting = true;
		p.bInvulnerable = true; p.Vel = (0, 0, 0);
		if (p.player) p.player.cheats |= CF_TOTALLYFROZEN;
		S_StartSound("ab/extract", CHAN_AUTO, 0, 1.0, ATTN_NONE);
		g.StageDone(p);
	}

	override void WorldLoaded(WorldEvent e)
	{
		let g = AB_Game.Get();
		String mn = level.MapName; mn = mn.MakeUpper();
		isCamp = mn == "ABCAMP";
		isMission = !isCamp && mn != "TITLEMAP";
		if (e.IsSaveGame || e.IsReopen)
		{
			if (isMission && g && (!g.InRun() || g.v[AB.R_ID] != myRun) && myRun != 0) kickTic = level.maptime + 70;
			return;
		}
		if (!g) return;
		if (isCamp)
		{
			if (g.InRun())
			{	// quit mid-expedition last session
				for (int i = AB.P_RUN; i < AB.P_SIZE; i++) g.v[i] = 0;
				g.Report("EXPEDITION ABANDONED", "You walked away from the last expedition before it was finished. Whatever you were carrying is still out there.");
			}
			if (!g.v[AB.P_INTRO])
			{
				g.v[AB.P_INTRO] = 1;
				g.Report("WELCOME TO THE OUTFIT", "You hunt treasure for a living. So does \cgMagnus Thorne\c- - only he does it with a private army called Thorne Meridian, and he hates being beaten to a find.\n\nFour great treasures are still in the ground. Launch expeditions from the \cfMISSIONS\c- tab, bring the loot home, and build this camp into something that can outrun him.\n\nIf an expedition goes wrong you wake up back here with whatever Storage managed to save. Thorne's dig teams never stop, so neither should you.\n\n\cjWalk up to a signpost and press USE, or press B, to manage the camp.");
			}
			g.SaveProfile();
			openMenuTic = 30;
			objective = "";
			return;
		}
		if (!isMission) return;
		myRun = g.InRun() ? g.v[AB.R_ID] : -1;
		// population
		int th = AB_Roster.Threat();
		int skip = clamp(34 - th / 2, 4, 34);
		let it = ThinkerIterator.Create("AB_EnemySpot"); AB_EnemySpot s; Array<AB_EnemySpot> list;
		while (s = AB_EnemySpot(it.Next())) if (s.args[1] == 0) list.Push(s);
		for (int i = 0; i < list.Size(); i++)
		{
			s = list[i];
			if (s.args[0] >= 5) { if (s.Fire(false)) bossCount++; continue; }
			if (!s.args[2] && random[ABL](0, 99) < skip) { s.Destroy(); continue; }
			if (s.Fire(false)) enemiesPlaced++;
		}
		int type = g.InRun() ? g.StageType() : 0;
		if (type == 2) objective = g.GreatAvailable() ? "Claim the treasure" : "Loot the vault and get out";
		else if (type == 1) objective = "Open the way forward";
		else objective = "Fight through to the extraction flare";
		exitArmed = type != 2 || !g.GreatAvailable();
	}

	override void PlayerEntered(PlayerEvent e)
	{
		let g = AB_Game.Get(); let p = players[e.PlayerNumber].mo;
		if (!g || !p) return;
		if (isCamp) { AB_Player.Prepare(p, true); return; }
		if (!isMission) return;
		if (g.InRun() && !g.v[AB.R_EQUIPPED])
		{
			g.v[AB.R_EQUIPPED] = 1;
			AB_Player.Prepare(p, true);
			AB_Player.GiveLoadout(p);
		}
		else AB_Player.Prepare(p, !g.InRun());
		if (!g.InRun()) { AB_Player.GiveLoadout(p); }		// free-play via console "map"
		if (g.PartnerClass() == 0) p.GiveInventory("Allmap", 1);
	}

	override void PlayerDied(PlayerEvent e)
	{	// should not happen (the hunter is unkillable) but never leave the player stuck
		let p = players[e.PlayerNumber].mo;
		if (p && players[e.PlayerNumber].health <= 0) { players[e.PlayerNumber].Resurrect(); let ap = AB_Player(p); if (ap && !ap.down) ap.GoDown(); }
	}

	override void WorldTick()
	{
		let g = AB_Game.Get(); if (!g) return;
		if (kickTic && level.maptime >= kickTic) { kickTic = 0; level.ChangeLevel("ABCAMP", 0, CHANGELEVEL_NOINTERMISSION | CHANGELEVEL_RESETINVENTORY | CHANGELEVEL_RESETHEALTH); return; }
		if (failTic && level.maptime >= failTic)
		{
			failTic = 0;
			if (g.InRun()) g.EndRun(0);
			else level.ChangeLevel("ABCAMP", 0, CHANGELEVEL_NOINTERMISSION | CHANGELEVEL_RESETINVENTORY | CHANGELEVEL_RESETHEALTH);
			return;
		}
		if (isCamp && openMenuTic && level.maptime >= openMenuTic) { openMenuTic = 0; if (g.repTitle.Size()) EventHandler.SendInterfaceEvent(consoleplayer, "ab_open_camp", 0); }
	}

	override void WorldThingDied(WorldEvent e)
	{
		let t = e.Thing; if (!t || !t.bIsMonster || t.bFriendly) return;
		let g = AB_Game.Get(); if (!g) return;
		String cn = t.GetClassName();
		if (cn == "AB_Thorne" || cn == "AB_Lieutenant")
		{
			bossCount = max(0, bossCount - 1);
			if (cn == "AB_Thorne") { Say("\cfMagnus Thorne is finished.\c-\nHis collection is yours for the taking.", 175); g.Radio("Meridian net: \"...the boss is down. Repeat, the boss is DOWN. Who's paying us now?\""); }
			else Say("The lieutenant is down.", 90);
			for (int i = 0; i < 3; i++) Actor.Spawn("AB_GoldBar", t.pos + (frandom[ABL](-24, 24), frandom[ABL](-24, 24), 8));
		}
		if (!isMission) return;
		g.v[AB.P_KILLS]++;
		if (g.InRun()) g.v[AB.R_KILLS]++;
		let p = players[consoleplayer].mo;
		if (p && g.Boon(AB.BN_BLOOD) && p.health > 0) p.GiveBody(2 * g.Boon(AB.BN_BLOOD), p.MaxHealth);
		int r = random[ABL](0, 99);
		if (r < 4 + 6 * g.Boon(AB.BN_VULTURE)) Actor.Spawn("AB_Intel", t.pos + (0, 0, 8));
		else if (r < 24) Actor.Spawn("AB_Coins", t.pos + (0, 0, 8));
	}

	override void CheckReplacement(ReplaceEvent e)
	{
		static const String junk[] = { "Shotgun", "SuperShotgun", "Chaingun", "RocketLauncher", "PlasmaRifle", "BFG9000", "Pistol", "Chainsaw", "Cell", "CellPack", "RocketAmmo", "RocketBox" };
		if (!e.Replacee) return;
		String n = e.Replacee.GetClassName();
		for (int i = 0; i < junk.Size(); i++) if (n == junk[i]) { e.Replacement = "AB_AmmoDrop"; return; }
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name == "ab_openmenu")
		{
			if (isCamp) EventHandler.SendInterfaceEvent(e.Player, "ab_open_camp", -1);
			else
			{
				let g = AB_Game.Get();
				if (g && g.InRun()) Say(String.Format("\cfFIELD JOURNAL\c-\n%s - stage %d of %d\nHaul: %d gold, %d materials, %d supplies, %d intel\nMedkits %d   Second winds %d", AB.RegionName[g.v[AB.R_REGION]], g.v[AB.R_STAGE] + 1, g.v[AB.R_NSTAGES],
					g.v[AB.R_GOLD], g.v[AB.R_MAT], g.v[AB.R_SUP], g.v[AB.R_INTEL], g.v[AB.R_MEDKITS], g.v[AB.R_REVIVES]), 175);
			}
		}
	}

	override void InterfaceProcess(ConsoleEvent e)
	{
		if (e.Name == "ab_open_camp")
		{
			if (Menu.GetCurrentMenu() is "AB_CampMenu") return;
			let m = AB_CampMenu(new("AB_CampMenu"));
			m.Init(null); m.Open(e.Args[0]); m.ActivateMenu();
		}
		else if (e.Name == "ab_open_clear")
		{
			if (Menu.GetCurrentMenu() is "AB_ClearMenu") return;
			let m = AB_ClearMenu(new("AB_ClearMenu"));
			m.Init(null); m.ActivateMenu();
		}
		else if (e.Name == "ab_close_menus")
		{
			let m = Menu.GetCurrentMenu();
			if (m && (m is "AB_CampMenu" || m is "AB_ClearMenu")) m.Close();
		}
	}

	// ------------------------------------------------------------ HUD
	ui void HText(Font f, int col, double x, double y, String s, double vw, double a = 1.0, double sc = 1.0)
	{
		Screen.DrawText(f, col, x / sc, y / sc, s, DTA_VirtualWidthF, vw / sc, DTA_VirtualHeightF, 360.0 / sc, DTA_KeepRatio, true, DTA_Alpha, a);
	}
	ui void HFill(double x, double y, double w, double h, Color c, double a)
	{
		double k = Screen.GetHeight() / 360.0;
		Screen.Dim(c, a, int(x * k), int(y * k), int(w * k + 0.5), int(h * k + 0.5));
	}
	ui void HCenter(Font f, int col, double y, String s, double vw, double a = 1.0, double sc = 1.0)
	{
		HText(f, col, (vw - f.StringWidth(s) * sc) / 2, y, s, vw, a, sc);
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (automapactive) return;
		let g = AB_Game.Get(); if (!g) return;
		double vw = 360.0 * Screen.GetWidth() / Screen.GetHeight();
		Font sm = "NewSmallFont"; Font big = "BigFont";
		int now = level.maptime;

		if (isCamp)
		{
			if (!menuactive)
			{
				HText(sm, Font.CR_GOLD, 8, 6, "ANCIENT BOUNTIES", vw, 0.9);
				HText(sm, Font.CR_WHITE, 8, 16, String.Format("Base Camp  -  Day %d", g.v[AB.P_DAY]), vw, 0.8);
				HText(sm, Font.CR_DARKGRAY, 8, 26, "Press \cfB\c- or USE a signpost to manage the camp", vw, 0.8);
			}
			return;
		}
		if (!isMission) return;

		// ---- title card
		if (now < 175 && g.InRun())
		{
			double a = now < 20 ? now / 20.0 : (now > 140 ? (175 - now) / 35.0 : 1.0);
			int r = g.v[AB.R_REGION];
			HFill(0, 62, vw, 56, "000000", 0.55 * a);
			HCenter(big, Font.CR_GOLD, 68, AB.RegionName[r], vw, a, 1.5);
			HCenter(sm, Font.CR_WHITE, 96, AB.RegionPlace[r] .. "  -  Day " .. g.v[AB.P_DAY], vw, a);
			HCenter(sm, Font.CR_TAN, 106, String.Format("Stage %d of %d:  %s", g.v[AB.R_STAGE] + 1, g.v[AB.R_NSTAGES], AB.StageTitle(r, g.StageType(), g.v[AB.R_STAGE])), vw, a);
		}

		// ---- objective + boons (top left)
		if (objective.Length()) { HText(sm, Font.CR_DARKGRAY, 8, 6, "OBJECTIVE", vw, 0.8, 0.75); HText(sm, Font.CR_WHITE, 8, 14, objective, vw, 0.9); }
		double by = 28;
		for (int b = 0; b < AB.NUM_BOON; b++) if (g.Boon(b))
		{
			HText(sm, Font.CR_GREEN, 8, by, g.Boon(b) > 1 ? String.Format("%s x%d", AB.BoonName[b], g.Boon(b)) : AB.BoonName[b], vw, 0.7, 0.75); by += 8;
		}

		// ---- haul (top right)
		if (g.InRun())
		{
			double x = vw - 96;
			HFill(x - 6, 4, 98, 44, "000000", 0.35);
			HText(sm, Font.CR_GOLD, x, 6, String.Format("GOLD       %5d", g.v[AB.R_GOLD]), vw, 0.95);
			HText(sm, Font.CR_BROWN, x, 16, String.Format("MATERIALS  %5d", g.v[AB.R_MAT]), vw, 0.9);
			HText(sm, Font.CR_GREEN, x, 26, String.Format("SUPPLIES   %5d", g.v[AB.R_SUP]), vw, 0.9);
			HText(sm, Font.CR_LIGHTBLUE, x, 36, String.Format("INTEL      %5d", g.v[AB.R_INTEL]), vw, 0.9);
			String kit = "";
			if (g.v[AB.R_MEDKITS]) kit = String.Format("\cd[F] Medkit x%d\c-  ", g.v[AB.R_MEDKITS]);
			if (g.v[AB.R_REVIVES]) kit = kit .. String.Format("\cfSecond Wind x%d", g.v[AB.R_REVIVES]);
			int rel = 0; for (int i = 0; i < 5; i++) if (g.v[AB.R_RELICS] & (1 << i)) rel++;
			if (rel) kit = kit .. String.Format("  \cfRelics x%d", rel);
			if (kit.Length()) HText(sm, Font.CR_WHITE, vw - 8 - sm.StringWidth(kit) * 0.75, 52, kit, vw, 0.85, 0.75);
		}

		// ---- puzzle clue (top centre)
		if (cluePid && clueGlyph.Size())
		{
			int n = clueGlyph.Size(); double w = n * 26 + 12, x0 = (vw - w) / 2;
			HFill(x0, 4, w, 42, "1A140C", 0.75);
			HCenter(sm, Font.CR_TAN, 6, clueText, vw, 0.95, 0.75);
			static const String gl[] = { "ABGMA0", "ABGMB0", "ABGMC0", "ABGMD0", "ABGME0", "ABGMF0" };
			static const Color cc[] = { 0xFFE63C28, 0xFF46D250, 0xFF468CFA, 0xFFFAC83C };
			for (int i = 0; i < n; i++)
			{
				TextureID t = TexMan.CheckForTexture(gl[clamp(clueGlyph[i], 0, 5)], TexMan.Type_Any);
				if (t.IsValid()) Screen.DrawTexture(t, false, x0 + 6 + i * 26 - 10, 12, DTA_VirtualWidthF, vw, DTA_VirtualHeightF, 360.0, DTA_KeepRatio, true, DTA_TopLeft, true, DTA_DestWidthF, 46.0 * 0.6, DTA_DestHeightF, 46.0 * 0.6);
				if (i < clueColour.Size()) HFill(x0 + 6 + i * 26 + 1, 39, 16, 4, cc[clueColour[i] & 3], 1.0);
				else if (n > 1) HText(sm, Font.CR_GOLD, x0 + 6 + i * 26 + 6, 37, String.Format("%d", i + 1), vw, 1.0, 0.75);
			}
		}

		// ---- pickup ticker (left, above status bar)
		double ty = 250;
		for (int i = tickText.Size() - 1; i >= 0; i--)
		{
			int age = now - tickTic[i]; if (age > 150) continue;
			HText(sm, Font.CR_WHITE, 8, ty, tickText[i], vw, age > 115 ? (150 - age) / 35.0 : 1.0); ty -= 10;
		}

		// ---- centre message
		if (now < sayUntil && sayText.Length())
		{
			double a = min(1.0, (now - sayStart) / 8.0, (sayUntil - now) / 18.0);
			BrokenLines bl = sm.BreakLines(sayText, int(vw * 0.7));
			double y = 132;
			HFill(vw * 0.12, y - 6, vw * 0.76, bl.Count() * 11 + 12, "000000", 0.5 * a);
			for (int i = 0; i < bl.Count(); i++) HCenter(sm, Font.CR_WHITE, y + i * 11, bl.StringAt(i), vw, a);
		}

		// ---- Thorne on the radio
		if (g.taunt.Length() && gametic - g.tauntTic < 245 && gametic >= g.tauntTic)
		{
			int age = gametic - g.tauntTic; double a = age < 10 ? age / 10.0 : (age > 210 ? (245 - age) / 35.0 : 1.0);
			BrokenLines bl = sm.BreakLines(g.taunt, int(vw * 0.6));
			double h = bl.Count() * 10 + 18, y = 196;
			HFill(vw * 0.18, y, vw * 0.64, h, "2A0608", 0.8 * a); HFill(vw * 0.18, y, vw * 0.64, 1, "C8282C", a);
			HText(sm, Font.CR_RED, vw * 0.18 + 6, y + 3, "MERIDIAN RADIO INTERCEPT", vw, a, 0.75);
			for (int i = 0; i < bl.Count(); i++) HText(sm, Font.CR_WHITE, vw * 0.18 + 6, y + 13 + i * 10, bl.StringAt(i), vw, a);
		}

		// ---- going down
		if (failTic)
		{
			double a = clamp(1.0 - (failTic - now) / 120.0, 0, 1);
			Screen.Dim("300000", min(0.92, a * 1.3), 0, 0, Screen.GetWidth(), Screen.GetHeight());
			HCenter(big, Font.CR_RED, 140, "EXPEDITION FAILED", vw, min(1.0, a * 2), 1.5);
			HCenter(sm, Font.CR_TAN, 172, "The crew is dragging you back to camp...", vw, min(1.0, a * 2));
		}
		if (kickTic) HCenter(sm, Font.CR_TAN, 150, "That expedition is already over. Returning to camp...", vw);
	}
}
