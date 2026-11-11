// ============================================================================
// AB_Game - persistent meta game (profile, camp, crew, rival, expedition state)
// Lives for the whole session; mirrored into the 'ab_profile' config cvar so it
// survives death, new games and quitting.  Everything is mutated through
// network events so menus (ui scope) never touch play data directly.
// ============================================================================
class AB_Game : StaticEventHandler
{
	const PROFILE_VERSION = 3;
	int v[AB.P_SIZE];
	Array<String> repTitle, repBody;	// camp report popups (not persisted)
	int offer[3];						// boon choices on the stage-clear screen
	int offerExtra;						// bonus gold shown on the clear screen
	String toastText; int toastTic;			// menu feedback line
	String taunt; int tauntTic;			// rival radio line (shown by the level HUD)
	bool loaded;

	static clearscope AB_Game Get() { return AB_Game(StaticEventHandler.Find("AB_Game")); }

	override void OnRegister() { SetOrder(100); LoadProfile(); }

	// ------------------------------------------------------------ persistence
	void NewProfile()
	{
		for (int i = 0; i < AB.P_SIZE; i++) v[i] = 0;
		v[AB.P_VERSION] = PROFILE_VERSION;
		v[AB.P_GOLD] = 150; v[AB.P_SUPPLIES] = 140; v[AB.P_MATERIALS] = 60; v[AB.P_DAY] = 1;
		v[AB.P_BLD + AB.B_COMMAND] = 1;
		v[AB.P_WOWN + 0] = 1; v[AB.P_WEQ + 0] = 1;		// machete
		v[AB.P_WOWN + 2] = 1; v[AB.P_WEQ + 2] = 1;		// colt
		v[AB.P_REGION + 0] = AB.RS_OPEN;
		v[AB.P_PARTNER] = -1;
		for (int i = 0; i < 3; i++) v[AB.P_CAND + i * 3] = -1;
		// one founding crew member
		SetCrew(0, 1, 0, 0, 1, 0, 0, 0);
		RollCandidates();
	}

	void LoadProfile()
	{
		loaded = true;
		CVar c = CVar.FindCVar("ab_profile");
		String s = c ? c.GetString() : "";
		Array<String> parts; s.Split(parts, ",");
		if (parts.Size() != AB.P_SIZE || parts[0].ToInt() != PROFILE_VERSION) { NewProfile(); return; }
		for (int i = 0; i < AB.P_SIZE; i++) v[i] = parts[i].ToInt();
	}

	void SaveProfile(bool flush = false)
	{
		String s = "";
		for (int i = 0; i < AB.P_SIZE; i++) { if (i) s.AppendFormat(","); s.AppendFormat("%d", v[i]); }
		CVar c = CVar.FindCVar("ab_profile");
		if (c) c.SetString(s);
		if (flush) CVar.SaveConfig();
	}

	// ------------------------------------------------------------ accessors (ui safe)
	clearscope int Bld(int b) const { return v[AB.P_BLD + b]; }
	clearscope bool Owns(int w) const { return v[AB.P_WOWN + w] != 0; }
	clearscope bool Equipped(int w) const { return v[AB.P_WEQ + w] != 0; }
	clearscope bool HasGear(int g) const { return v[AB.P_GEAR + g] != 0; }
	clearscope int RegionState(int r) const { return v[AB.P_REGION + r]; }
	clearscope double Rival(int r) const { return v[AB.P_RIVAL + r] / 10.0; }
	clearscope bool HasRelic(int i) const { return v[AB.P_RELIC + i] != 0; }
	clearscope int Crew(int i, int f) const { return v[AB.P_CREW + i * AB.CREW_F + f]; }	// f: 0 used 1 name 2 class 3 level 4 xp 5 status 6 days
	clearscope bool InRun() const { return v[AB.R_ACTIVE] != 0; }
	clearscope int Boon(int b) const { return v[AB.R_BOON + b]; }
	clearscope int CrewCount() const { int n = 0; for (int i = 0; i < AB.CREW_MAX; i++) if (Crew(i, 0)) n++; return n; }
	clearscope int Heat() const
	{
		int h = v[AB.P_NGPLUS];
		for (int r = 0; r < 4; r++) if (RegionState(r) == AB.RS_WON) h++;
		return h;
	}
	clearscope int RelicsIn(int region) const { int n = 0; for (int i = 0; i < 5; i++) if (HasRelic(region * 5 + i)) n++; return n; }
	clearscope bool SetDone(int region) const { return RelicsIn(region) >= 5; }
	clearscope int TreasuresWon() const { int n = 0; for (int r = 0; r < 4; r++) if (RegionState(r) == AB.RS_WON) n++; return n; }
	clearscope int TreasuresLost() const { int n = 0; for (int r = 0; r < 4; r++) if (RegionState(r) == AB.RS_LOST) n++; return n; }
	clearscope int MaxHealthNow() const
	{
		int h = 100 + 15 * Bld(AB.B_INFIRMARY) + (SetDone(0) ? 10 : 0) + 10 * Boon(AB.BN_SUN);
		int p = v[AB.P_PARTNER];
		if (InRun() && p >= 0 && Crew(p, 0) && Crew(p, 2) == 3) h += 20;
		return h;
	}
	clearscope int PartnerClass() const { int p = v[AB.P_PARTNER]; return (p >= 0 && Crew(p, 0) && Crew(p, 5) == 0) ? Crew(p, 2) : -1; }
	clearscope int FirearmCap() const { return HasGear(AB.G_HOLSTER) ? 4 : 3; }
	clearscope int BldCostMat(int b) const { return AB.BldMat[b * 3 + clamp(Bld(b), 0, 2)]; }
	clearscope int BldCostSup(int b) const { return AB.BldSup[b * 3 + clamp(Bld(b), 0, 2)]; }
	clearscope int DispatchSlots() const { return Bld(AB.B_RADIO); }
	clearscope int DispatchCost(int region) const { return 15 * AB.RegionDiff[region]; }
	clearscope bool CitadelReady() const
	{
		for (int r = 0; r < 4; r++) if (RegionState(r) != AB.RS_WON && RegionState(r) != AB.RS_LOST) return false;
		return true;
	}
	clearscope String UnlockBlocker(int r) const
	{
		if (RegionState(r) != AB.RS_LOCKED) return "";
		if (r == AB.CITADEL && !CitadelReady()) return "Settle all four treasures first";
		if (Bld(AB.B_COMMAND) < AB.RegionCmd[r]) return String.Format("Needs Command Tent Lv %d", AB.RegionCmd[r]);
		if (v[AB.P_INTEL] < AB.RegionIntel[r]) return String.Format("Needs %d Intel", AB.RegionIntel[r]);
		return "";
	}
	clearscope int TeamPower(int mask) const
	{
		int p = 0;
		for (int i = 0; i < AB.CREW_MAX; i++) if ((mask & (1 << i)) && Crew(i, 0)) p += 10 + 6 * Crew(i, 3);
		return p;
	}
	clearscope int DispatchChance(int region, int mask) const
	{
		int need = 25 + 18 * AB.RegionDiff[region] + 5 * Heat();
		return clamp(50 + (TeamPower(mask) - need) * 3 / 2, 10, 95);
	}

	// ------------------------------------------------------------ small mutators
	void SetCrew(int i, int used, int name, int cls, int level, int xp, int status, int days)
	{
		int b = AB.P_CREW + i * AB.CREW_F;
		v[b] = used; v[b + 1] = name; v[b + 2] = cls; v[b + 3] = level; v[b + 4] = xp; v[b + 5] = status; v[b + 6] = days;
	}
	void Toast(String s) { toastText = s; toastTic = gametic; }
	void Report(String title, String body) { repTitle.Push(title); repBody.Push(body); }
	void Radio(String s) { taunt = s; tauntTic = gametic; }
	bool NameTaken(int n)
	{
		for (int i = 0; i < AB.CREW_MAX; i++) if (Crew(i, 0) && Crew(i, 1) == n) return true;
		for (int i = 0; i < 3; i++) if (v[AB.P_CAND + i * 3] == n) return true;
		return false;
	}
	void RollCandidates()
	{
		for (int i = 0; i < 3; i++)
		{
			int n, tries = 0;
			do { n = random[ABG](0, AB.CrewNames.Size() - 1); } while (NameTaken(n) && ++tries < 60);
			v[AB.P_CAND + i * 3] = n;
			v[AB.P_CAND + i * 3 + 1] = random[ABG](0, 3);
			v[AB.P_CAND + i * 3 + 2] = 1 + (random[ABG](0, 99) < 25 * (Bld(AB.B_COMMAND) - 1) ? 1 : 0) + (random[ABG](0, 99) < 15 ? 1 : 0);
		}
		v[AB.P_CANDDAY] = v[AB.P_DAY];
	}

	// ------------------------------------------------------------ the calendar
	void AdvanceDay(int n = 1)
	{
		for (int d = 0; d < n; d++)
		{
			v[AB.P_DAY]++;
			// radio intel trickle
			if (Bld(AB.B_RADIO) >= 2 && (v[AB.P_DAY] % (Bld(AB.B_RADIO) >= 3 ? 2 : 3)) == 0) v[AB.P_INTEL]++;
			// crew recovery
			for (int i = 0; i < AB.CREW_MAX; i++)
			{
				int b = AB.P_CREW + i * AB.CREW_F;
				if (v[b] && v[b + 5] == 2 && --v[b + 6] <= 0) { v[b + 5] = 0; v[b + 6] = 0; }
			}
			// dispatched teams
			for (int t = 0; t < 3; t++)
			{
				int b = AB.P_DISP + t * 3;
				if (v[b] > 0 && --v[b + 1] <= 0) ResolveDispatch(t);
			}
			RivalDay();
			if (v[AB.P_DAY] - v[AB.P_CANDDAY] >= 4) RollCandidates();
		}
	}

	void RivalDay()
	{
		int focus = -1; int best = -1;
		for (int r = 0; r < 4; r++)
		{
			int st = RegionState(r);
			if (st == AB.RS_WON || st == AB.RS_LOST) continue;
			int score = v[AB.P_RIVAL + r] * 10 + (3 - r);
			if (score > best) { best = score; focus = r; }
		}
		for (int r = 0; r < 4; r++)
		{
			int st = RegionState(r);
			if (st == AB.RS_WON || st == AB.RS_LOST) continue;
			int rate = 12 + 4 * Heat() + (r == focus ? 45 : 0);
			if (InRun() && v[AB.R_REGION] == r) rate /= 2;		// he's busy shooting at you
			int before = v[AB.P_RIVAL + r];
			v[AB.P_RIVAL + r] = min(1000, before + rate);
			if (before < 750 && v[AB.P_RIVAL + r] >= 750)
				Report("RADIO INTERCEPT", String.Format("Meridian dig teams are closing on \cf%s\c- in %s. Thorne will have it within days unless someone slows him down.", AB.GreatName[r], AB.RegionName[r]));
			if (v[AB.P_RIVAL + r] >= 1000 && !(InRun() && v[AB.R_REGION] == r))
			{
				v[AB.P_REGION + r] = AB.RS_LOST;
				Report("THORNE GOT THERE FIRST", String.Format("Meridian contractors airlifted \cf%s\c- out of %s this morning.\n\nIt is on its way to Thorne's vault on Skerry Rock. The site is still worth raiding for relics - and the vault can be cracked. Eventually.", AB.GreatName[r], AB.RegionName[r]));
				Radio("Thorne: \"" .. AB.ThorneTaunt[random[ABG](0, AB.ThorneTaunt.Size() - 1)] .. "\"");
			}
		}
		if (RegionState(AB.CITADEL) == AB.RS_LOCKED && CitadelReady() && !v[AB.P_FINALE])
		{
			v[AB.P_FINALE] = 1;
			Report("THE LAST JOB", "Every great treasure is accounted for - yours in the lockbox, his on Skerry Rock.\n\nThorne's fortress is the only dig site left. Get the Command Tent to Level 3, gather the intel, and go knock on his door.");
		}
	}

	void ResolveDispatch(int t)
	{
		int b = AB.P_DISP + t * 3;
		int region = v[b] - 1; v[b] = 0; v[b + 1] = 0;
		int mask = v[b + 2]; v[b + 2] = 0;
		int chance = DispatchChance(region, mask);
		bool ok = random[ABG](0, 99) < chance;
		int diff = AB.RegionDiff[region];
		bool scholar = false, scout = false; String names = "";
		for (int i = 0; i < AB.CREW_MAX; i++) if ((mask & (1 << i)) && Crew(i, 0))
		{
			if (Crew(i, 2) == 2) scholar = true;
			if (Crew(i, 2) == 0) scout = true;
			if (names.Length()) names = names .. ", ";
			names = names .. AB.CrewNames[Crew(i, 1)];
		}
		String body = "Team: " .. names .. "\n\n";
		if (ok)
		{
			int g = random[ABG](70, 130) * diff, m = random[ABG](45, 85) * diff, s = random[ABG](15, 40), it = 1 + (scout ? 1 : 0);
			v[AB.P_GOLD] += g; v[AB.P_MATERIALS] += m; v[AB.P_SUPPLIES] += s; v[AB.P_INTEL] += it;
			body = body .. String.Format("They slipped past the Meridian pickets and came home loaded.\n\n\cf+%d Gold   +%d Materials   +%d Supplies   +%d Intel\c-", g, m, s, it);
			if (region < 4)
			{
				v[AB.P_RIVAL + region] = max(0, v[AB.P_RIVAL + region] - 100);
				body = body .. "\nThorne's dig was set back.";
				if (random[ABG](0, 99) < (scholar ? 35 : 15))
				{
					int rel = PickNewRelic(region);
					if (rel >= 0) { v[AB.P_RELIC + rel] = 1; v[AB.P_GOLD] += 100; body = body .. String.Format("\n\nThey also recovered a relic: \cf%s\c-!", AB.RelicName[rel]); }
				}
			}
		}
		else
		{
			int g = random[ABG](15, 40) * diff; v[AB.P_GOLD] += g;
			body = body .. String.Format("Ambushed by contractors on the way in. They got out with %d Gold and their lives.", g);
		}
		for (int i = 0; i < AB.CREW_MAX; i++) if ((mask & (1 << i)) && Crew(i, 0))
		{
			int cb = AB.P_CREW + i * AB.CREW_F;
			v[cb + 5] = 0; v[cb + 6] = 0;
			if (ok)
			{
				v[cb + 4]++;
				if (v[cb + 3] < 5 && v[cb + 4] >= v[cb + 3] * 2) { v[cb + 4] = 0; v[cb + 3]++; body = body .. String.Format("\n%s is now Level %d.", AB.CrewNames[v[cb + 1]], v[cb + 3]); }
			}
			else if (random[ABG](0, 99) < 50)
			{
				v[cb + 5] = 2; v[cb + 6] = max(1, 4 - Bld(AB.B_INFIRMARY));
				body = body .. String.Format("\n%s is wounded (%d days).", AB.CrewNames[v[cb + 1]], v[cb + 6]);
			}
		}
		Report(ok ? ("TEAM RETURNS - " .. AB.RegionName[region]) : ("TEAM ROUTED - " .. AB.RegionName[region]), body);
	}

	int PickNewRelic(int region)
	{
		Array<int> free;
		for (int i = 0; i < 5; i++) if (!HasRelic(region * 5 + i) && !(InRun() && (v[AB.R_RELICS] & (1 << i)))) free.Push(region * 5 + i);
		return free.Size() ? free[random[ABG](0, free.Size() - 1)] : -1;
	}

	// ------------------------------------------------------------ expeditions
	void StartRun(int region)
	{
		for (int i = AB.P_RUN; i < AB.P_SIZE; i++) v[i] = 0;
		v[AB.R_ACTIVE] = 1; v[AB.R_REGION] = region; v[AB.R_STAGE] = 0; v[AB.R_ID] = random[ABG](1, 999999); v[AB.R_SEED] = random[ABG](1, 999999);
		v[AB.P_RUNS]++;
		v[AB.P_SUPPLIES] -= AB.RegionCost[region];
		if (region == AB.CITADEL)
		{
			v[AB.R_NSTAGES] = 3;
			v[AB.R_TYPE0] = 0; v[AB.R_TYPE1] = 1; v[AB.R_TYPE2] = 2;
			v[AB.R_VAR0] = random[ABG](0, 1);
		}
		else
		{
			v[AB.R_NSTAGES] = 4;
			v[AB.R_TYPE0] = 0; v[AB.R_TYPE1] = 1; v[AB.R_TYPE2] = random[ABG](0, 1); v[AB.R_TYPE3] = 2;
			v[AB.R_VAR0] = random[ABG](0, 2); v[AB.R_VAR1] = random[ABG](0, 2);
			int other = v[AB.R_TYPE2] == 0 ? v[AB.R_VAR0] : v[AB.R_VAR1];
			do { v[AB.R_VAR2] = random[ABG](0, 2); } while (v[AB.R_VAR2] == other);
		}
		v[AB.R_REVIVES] = HasGear(AB.G_CHARM) ? 1 : 0;
		v[AB.R_MEDKITS] = (HasGear(AB.G_MEDKIT) ? 1 : 0) + (HasGear(AB.G_MEDKIT2) ? 1 : 0);
		SaveProfile(true);
		level.ChangeLevel(CurrentMap(), 0, CHANGELEVEL_NOINTERMISSION | CHANGELEVEL_RESETINVENTORY | CHANGELEVEL_RESETHEALTH);
	}

	clearscope String CurrentMap() const
	{
		int s = v[AB.R_STAGE];
		return AB.MapFor(v[AB.R_REGION], v[AB.R_TYPE0 + s], v[AB.R_VAR0 + s]);
	}
	clearscope int StageType() const { return v[AB.R_TYPE0 + v[AB.R_STAGE]]; }
	clearscope bool LastStage() const { return v[AB.R_STAGE] >= v[AB.R_NSTAGES] - 1; }
	clearscope bool GreatAvailable() const { int r = v[AB.R_REGION]; return r == AB.CITADEL || RegionState(r) == AB.RS_OPEN; }

	// called by the level handler when the player reaches extraction
	void StageDone(PlayerPawn pmo)
	{
		int region = v[AB.R_REGION];
		AdvanceDay(1);
		if (region < 4) v[AB.P_RIVAL + region] = max(0, v[AB.P_RIVAL + region] - 80);
		if (PartnerClass() == 0) v[AB.R_INTEL]++;
		offerExtra = 20 + 15 * v[AB.R_STAGE] * AB.RegionDiff[region];
		v[AB.R_GOLD] += offerExtra;
		if (LastStage()) { EndRun(2); return; }
		// roll boon choices
		int n = 3;
		Array<int> pool;
		for (int b = 0; b < AB.NUM_BOON; b++)
		{
			if (b == AB.BN_WIND && Boon(b) >= 1) continue;
			if (b == AB.BN_CURSE && Boon(b) >= 1) continue;
			pool.Push(b);
		}
		for (int i = 0; i < 3; i++)
		{
			int k = random[ABG](0, pool.Size() - 1);
			offer[i] = pool[k]; pool.Delete(k);
		}
		SaveProfile();
		EventHandler.SendInterfaceEvent(consoleplayer, "ab_open_clear");
	}

	void TakeBoon(int b, PlayerPawn pmo)
	{
		v[AB.R_BOON + b]++;
		if (!pmo) return;
		switch (b)
		{
		case AB.BN_SUN:		pmo.MaxHealth = MaxHealthNow(); pmo.GiveBody(40, pmo.MaxHealth); break;
		case AB.BN_VULTURE:	v[AB.R_INTEL] += 2; break;
		case AB.BN_QUARTER:	AB_Player.Refill(pmo, 100); break;
		case AB.BN_IRON:	pmo.GiveInventory("AB_ArmorShard", 50); break;
		case AB.BN_WIND:	v[AB.R_REVIVES]++; break;
		}
	}

	void NextStage(PlayerPawn pmo)
	{
		v[AB.R_STAGE]++;
		if (pmo)
		{
			int heal = 15 * Bld(AB.B_INFIRMARY) + (PartnerClass() == 3 ? 20 : 0);
			if (heal) pmo.GiveBody(heal, pmo.MaxHealth);
			if (Boon(AB.BN_IRON)) pmo.GiveInventory("AB_ArmorShard", 25 * Boon(AB.BN_IRON));
		}
		SaveProfile();
		level.ChangeLevel(CurrentMap(), 0, CHANGELEVEL_NOINTERMISSION);
	}

	// result: 0 = went down, 1 = extracted early, 2 = cleared the final stage
	void EndRun(int result)
	{
		if (!InRun()) return;
		int region = v[AB.R_REGION];
		int keep = result == 0 ? AB.KeepPct(Bld(AB.B_STORAGE)) : 100;
		int g = v[AB.R_GOLD] * keep / 100, m = v[AB.R_MAT] * keep / 100, s = v[AB.R_SUP] * keep / 100, it = v[AB.R_INTEL];
		String body = String.Format("%s - %s\nStages cleared: %d of %d     Contractors dropped: %d\n\n", AB.RegionName[region], AB.RegionPlace[region],
			v[AB.R_STAGE] + (result == 2 ? 1 : 0), v[AB.R_NSTAGES], v[AB.R_KILLS]);
		String title;
		if (result == 0)
		{
			title = "EXPEDITION FAILED";
			v[AB.P_DEATHS]++;
			body = body .. String.Format("The crew dragged you out. Storage saved %d%% of the haul.\n\n", keep);
			int p = v[AB.P_PARTNER];
			if (p >= 0 && Crew(p, 0) && random[ABG](0, 99) < 35)
			{
				int cb = AB.P_CREW + p * AB.CREW_F;
				v[cb + 5] = 2; v[cb + 6] = max(1, 4 - Bld(AB.B_INFIRMARY));
				body = body .. String.Format("%s was hit covering your retreat (%d days).\n\n", AB.CrewNames[v[cb + 1]], v[cb + 6]);
			}
		}
		else
		{
			title = result == 2 ? "EXPEDITION COMPLETE" : "EXTRACTED";
			if (result == 2) v[AB.P_WINS]++;
		}
		v[AB.P_GOLD] += g; v[AB.P_MATERIALS] += m; v[AB.P_SUPPLIES] += s; v[AB.P_INTEL] += it;
		body = body .. String.Format("\cf+%d Gold   +%d Materials   +%d Supplies   +%d Intel\c-", g, m, s, it);
		v[AB.P_BESTHAUL] = max(v[AB.P_BESTHAUL], g);
		if (result != 0)
		{
			for (int i = 0; i < 5; i++) if (v[AB.R_RELICS] & (1 << i))
			{
				if (region < 4 && !HasRelic(region * 5 + i))
				{
					v[AB.P_RELIC + region * 5 + i] = 1;
					body = body .. String.Format("\nRelic secured: \cf%s\c-", AB.RelicName[region * 5 + i]);
					if (SetDone(region)) body = body .. String.Format("\n\cd%s collection complete: %s\c-", AB.RegionName[region], AB.SetBonus[region]);
				}
			}
		}
		else if (v[AB.R_RELICS]) body = body .. "\nThe relics you were carrying were lost.";
		if (result == 2 && v[AB.R_GREAT])
		{
			if (region == AB.CITADEL)
			{
				int back = 0;
				for (int r = 0; r < 4; r++) if (RegionState(r) == AB.RS_LOST) { v[AB.P_REGION + r] = AB.RS_WON; back++; }
				v[AB.P_REGION + AB.CITADEL] = AB.RS_WON;
				v[AB.P_GOLD] += 2000;
				title = "THORNE IS FINISHED";
				body = body .. String.Format("\n\nMagnus Thorne's vault is empty and his company is in receivership.\n%d stolen treasure%s recovered. +2000 Gold.\n\nThe four great treasures are safe - in a museum, where they belong. Mostly.\n\n\cdThe hunt can go on: Meridian's remnants are angrier than ever (Heat +1).\c-", back, back == 1 ? "" : "s");
				v[AB.P_NGPLUS]++;
				for (int r = 0; r < 4; r++) v[AB.P_RIVAL + r] = 0;
			}
			else
			{
				v[AB.P_REGION + region] = AB.RS_WON;
				v[AB.P_GOLD] += 400 * AB.RegionDiff[region];
				body = body .. String.Format("\n\n\cfGREAT TREASURE CLAIMED: %s\c-\n+%d Gold bounty. Thorne will not take this well. (Heat +1)", AB.GreatName[region], 400 * AB.RegionDiff[region]);
				Radio("Thorne: \"" .. AB.ThorneTaunt[random[ABG](0, AB.ThorneTaunt.Size() - 1)] .. "\"");
			}
		}
		Report(title, body);
		for (int i = AB.P_RUN; i < AB.P_SIZE; i++) v[i] = 0;
		AdvanceDay(1);
		SaveProfile(true);
		level.ChangeLevel("ABCAMP", 0, CHANGELEVEL_NOINTERMISSION | CHANGELEVEL_RESETINVENTORY | CHANGELEVEL_RESETHEALTH);
	}

	// ------------------------------------------------------------ commands from menus / keys
	override void NetworkProcess(ConsoleEvent e)
	{
		String cmd = e.Name;
		if (cmd.Left(3) != "ab_") return;
		PlayerPawn pmo = players[e.Player].mo;
		int a = e.Args[0], b = e.Args[1];
		if (cmd == "ab_dodge") { if (AB_Player(pmo)) AB_Player(pmo).TryDodge(); return; }
		if (cmd == "ab_medkit") { if (AB_Player(pmo)) AB_Player(pmo).UseMedkit(); return; }
		if (cmd == "ab_ack") { if (repTitle.Size()) { repTitle.Delete(0); repBody.Delete(0); } return; }

		// --- stage clear screen
		if (cmd == "ab_boon")
		{
			if (!InRun() || a < 0 || a > 2) return;
			TakeBoon(offer[a], pmo); NextStage(pmo); return;
		}
		if (cmd == "ab_extract") { if (InRun()) EndRun(1); return; }
		if (cmd == "ab_abandon") { if (InRun()) EndRun(0); return; }

		// --- everything below is camp business
		if (InRun()) return;
		if (cmd == "ab_upgrade")
		{
			if (a < 0 || a >= AB.NUM_BLD) return;
			int lv = Bld(a);
			if (lv >= AB.BldMax[a]) { Toast("Already fully upgraded."); return; }
			if (a != AB.B_COMMAND && lv >= Bld(AB.B_COMMAND)) { Toast("Upgrade the Command Tent first."); return; }
			int cm = BldCostMat(a), cs = BldCostSup(a);
			if (v[AB.P_MATERIALS] < cm || v[AB.P_SUPPLIES] < cs) { Toast("Not enough materials or supplies."); return; }
			v[AB.P_MATERIALS] -= cm; v[AB.P_SUPPLIES] -= cs; v[AB.P_BLD + a]++;
			Toast(String.Format("%s is now Level %d.", AB.BldName[a], Bld(a)));
			S_StartSound("ab/build", CHAN_AUTO, CHANF_UI);
		}
		else if (cmd == "ab_buyw")
		{
			if (a < 0 || a >= AB.NUM_WEAPONS || Owns(a)) return;
			if (AB.WpnTier[a] > Bld(AB.B_ARMORY)) { Toast(String.Format("Needs Armory Lv %d.", AB.WpnTier[a])); return; }
			if (v[AB.P_GOLD] < AB.WpnPrice[a]) { Toast("Not enough gold."); return; }
			v[AB.P_GOLD] -= AB.WpnPrice[a]; v[AB.P_WOWN + a] = 1;
			Toast(AB.WpnName[a] .. " added to the armory.");
			S_StartSound("ab/buy", CHAN_AUTO, CHANF_UI);
			ToggleEquip(a, true);
		}
		else if (cmd == "ab_equip") { if (a >= 0 && a < AB.NUM_WEAPONS && Owns(a)) ToggleEquip(a, false); }
		else if (cmd == "ab_buygear")
		{
			if (a < 0 || a >= AB.NUM_GEAR || HasGear(a)) return;
			if (AB.GearTier[a] > Bld(AB.B_WORKSHOP)) { Toast(String.Format("Needs Workshop Lv %d.", AB.GearTier[a])); return; }
			if (AB.GearReq[a] >= 0 && !HasGear(AB.GearReq[a])) { Toast("Requires " .. AB.GearName[AB.GearReq[a]] .. "."); return; }
			if (v[AB.P_GOLD] < AB.GearPrice[a]) { Toast("Not enough gold."); return; }
			v[AB.P_GOLD] -= AB.GearPrice[a]; v[AB.P_GEAR + a] = 1;
			Toast(AB.GearName[a] .. " crafted.");
			S_StartSound("ab/buy", CHAN_AUTO, CHANF_UI);
		}
		else if (cmd == "ab_recruit")
		{
			if (a < 0 || a > 2 || v[AB.P_CAND + a * 3] < 0) return;
			if (CrewCount() >= AB.CrewCap(Bld(AB.B_COMMAND))) { Toast("No bunks left. Upgrade the Command Tent."); return; }
			int cost = AB.RecruitCost(v[AB.P_CAND + a * 3 + 2]);
			if (v[AB.P_GOLD] < cost) { Toast("Not enough gold."); return; }
			for (int i = 0; i < AB.CREW_MAX; i++) if (!Crew(i, 0))
			{
				v[AB.P_GOLD] -= cost;
				SetCrew(i, 1, v[AB.P_CAND + a * 3], v[AB.P_CAND + a * 3 + 1], v[AB.P_CAND + a * 3 + 2], 0, 0, 0);
				Toast(AB.CrewNames[v[AB.P_CAND + a * 3]] .. " joins the outfit.");
				v[AB.P_CAND + a * 3] = -1;
				S_StartSound("ab/buy", CHAN_AUTO, CHANF_UI);
				break;
			}
		}
		else if (cmd == "ab_dismiss")
		{
			if (a < 0 || a >= AB.CREW_MAX || !Crew(a, 0) || Crew(a, 5) == 1) return;
			if (CrewCount() <= 1) { Toast("Somebody has to mind the camp."); return; }
			Toast(AB.CrewNames[Crew(a, 1)] .. " heads home.");
			SetCrew(a, 0, 0, 0, 0, 0, 0, 0);
			if (v[AB.P_PARTNER] == a) v[AB.P_PARTNER] = -1;
		}
		else if (cmd == "ab_partner")
		{
			if (a < 0 || a >= AB.CREW_MAX || !Crew(a, 0)) return;
			if (v[AB.P_PARTNER] == a) { v[AB.P_PARTNER] = -1; return; }
			if (Crew(a, 5) != 0) { Toast("They're not available."); return; }
			v[AB.P_PARTNER] = a;
		}
		else if (cmd == "ab_unlock")
		{
			if (a < 0 || a >= AB.NUM_REGIONS || RegionState(a) != AB.RS_LOCKED) return;
			String why = UnlockBlocker(a);
			if (why.Length()) { Toast(why .. "."); return; }
			v[AB.P_INTEL] -= AB.RegionIntel[a]; v[AB.P_REGION + a] = AB.RS_OPEN;
			Toast("Route charted: " .. AB.RegionName[a]);
			S_StartSound("ab/build", CHAN_AUTO, CHANF_UI);
		}
		else if (cmd == "ab_sabotage")
		{
			if (a < 0 || a > 3 || RegionState(a) == AB.RS_WON || RegionState(a) == AB.RS_LOST) return;
			if (v[AB.P_INTEL] < 3) { Toast("Sabotage costs 3 Intel."); return; }
			v[AB.P_INTEL] -= 3; v[AB.P_RIVAL + a] = max(0, v[AB.P_RIVAL + a] - 250);
			Toast("Meridian's supply drop in " .. AB.RegionName[a] .. " went missing. Shame.");
			S_StartSound("ab/buy", CHAN_AUTO, CHANF_UI);
		}
		else if (cmd == "ab_dispatch")
		{
			// a = region, b = crew bitmask
			if (a < 0 || a > 3 || RegionState(a) == AB.RS_LOCKED) return;
			int slot = -1, busy = 0;
			for (int t = 0; t < 3; t++) { if (v[AB.P_DISP + t * 3] > 0) busy++; else if (slot < 0) slot = t; }
			if (busy >= DispatchSlots() || slot < 0) { Toast(DispatchSlots() == 0 ? "Build the Radio Tower to dispatch teams." : "All radio channels are busy."); return; }
			int cnt = 0;
			for (int i = 0; i < AB.CREW_MAX; i++) if (b & (1 << i))
			{
				if (!Crew(i, 0) || Crew(i, 5) != 0 || v[AB.P_PARTNER] == i) { Toast("Someone on that team isn't available."); return; }
				cnt++;
			}
			if (cnt < 1 || cnt > 3) { Toast("Pick one to three crew."); return; }
			if (v[AB.P_SUPPLIES] < DispatchCost(a)) { Toast("Not enough supplies."); return; }
			v[AB.P_SUPPLIES] -= DispatchCost(a);
			v[AB.P_DISP + slot * 3] = a + 1; v[AB.P_DISP + slot * 3 + 1] = 2 + AB.RegionDiff[a]; v[AB.P_DISP + slot * 3 + 2] = b;
			for (int i = 0; i < AB.CREW_MAX; i++) if (b & (1 << i)) v[AB.P_CREW + i * AB.CREW_F + 5] = 1;
			Toast(String.Format("Team dispatched to %s. Back in %d days.", AB.RegionName[a], 2 + AB.RegionDiff[a]));
			S_StartSound("ab/radio", CHAN_AUTO, CHANF_UI);
		}
		else if (cmd == "ab_wait") { AdvanceDay(1); Toast(String.Format("Day %d.", v[AB.P_DAY])); }
		else if (cmd == "ab_launch")
		{
			if (a < 0 || a >= AB.NUM_REGIONS || RegionState(a) == AB.RS_LOCKED) return;
			if (a == AB.CITADEL && RegionState(a) == AB.RS_WON && false) return;
			if (v[AB.P_SUPPLIES] < AB.RegionCost[a]) { Toast("Not enough supplies for the trip."); return; }
			EventHandler.SendInterfaceEvent(e.Player, "ab_close_menus");
			StartRun(a);
			return;
		}
		else if (cmd == "ab_reset") { NewProfile(); repTitle.Clear(); repBody.Clear(); Toast("Profile reset."); }
		else if (cmd == "ab_cheat") { v[AB.P_GOLD] += 5000; v[AB.P_SUPPLIES] += 2000; v[AB.P_MATERIALS] += 5000; v[AB.P_INTEL] += 30; }
		else return;
		SaveProfile(true);
	}

	void ToggleEquip(int w, bool forceOn)
	{
		int kind = AB.WpnKind[w];
		if (Equipped(w) && !forceOn)
		{
			if (kind == 0) return;	// always carry a blade
			v[AB.P_WEQ + w] = 0; return;
		}
		if (Equipped(w)) return;
		if (kind == 0) { for (int i = 0; i < AB.NUM_WEAPONS; i++) if (AB.WpnKind[i] == 0) v[AB.P_WEQ + i] = 0; }
		else if (kind == 3)
		{
			int n = 0; for (int i = 0; i < AB.NUM_WEAPONS; i++) if (AB.WpnKind[i] == 3 && Equipped(i)) n++;
			if (n >= (HasGear(AB.G_BANDOLIER) ? 2 : 1)) { for (int i = 0; i < AB.NUM_WEAPONS; i++) if (AB.WpnKind[i] == 3) v[AB.P_WEQ + i] = 0; }
		}
		else
		{
			int n = 0; for (int i = 0; i < AB.NUM_WEAPONS; i++) if ((AB.WpnKind[i] == 1 || AB.WpnKind[i] == 2) && Equipped(i)) n++;
			if (n >= FirearmCap()) { if (!forceOn) Toast(String.Format("You can carry %d firearms. Unequip one first.", FirearmCap())); return; }
		}
		v[AB.P_WEQ + w] = 1;
	}
}
