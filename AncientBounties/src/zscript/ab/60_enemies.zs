// ============================================================================
// Thorne Meridian contractors.  Maps only contain "spots"; who actually shows
// up is rolled per expedition from the region, stage, and Thorne's heat.
// ============================================================================
class AB_Roster play
{
	// tier 0 grunts, 1 soldiers, 2 heavies, 3 elites, 4 marksmen
	static const String T0[] = { "terrorist", "terroristbrown", "terroristgreenbrown", "terroristgreygreen", "specopM", "specopMkak", "specopMbrown", "specopF", "specopFkak",
		"MiltiaSMGm", "MiltiaSMGmTan", "MiltiaShotgun", "MiltiaShotgunTan", "MiltiaSMGF", "MiltiaSMGFkak" };
	static const String T1[] = { "PMCdude", "PMCdudeA", "PMCdudeRed", "PMCdudeRedA", "PMCdudeGreen", "Elite1w", "EliteF1w", "EliteShotgunW", "Elite1w2", "EliteF1w2" };
	static const String T2[] = { "PMCBig", "PMCBig2", "Elite1", "EliteF1", "EliteShotgun", "Enforcer", "EnforcerGrey", "EnforcerBrown", "ChunkySSG", "ChunkySSGgreen" };
	static const String T3[] = { "BadassElite", "BadassElite2", "BadassPara", "BigElite", "Rocketeer", "RocketeerGreyBrown", "Pyro", "PyroBrown" };
	static const String T4[] = { "Sniper", "Sniper2" };

	static String Pick(int tier)
	{
		switch (tier)
		{
		case 0: return AB_Roster.T0[random[ABE](0, AB_Roster.T0.Size() - 1)];
		case 1: return AB_Roster.T1[random[ABE](0, AB_Roster.T1.Size() - 1)];
		case 2: return AB_Roster.T2[random[ABE](0, AB_Roster.T2.Size() - 1)];
		case 3: return AB_Roster.T3[random[ABE](0, AB_Roster.T3.Size() - 1)];
		case 4: return AB_Roster.T4[random[ABE](0, AB_Roster.T4.Size() - 1)];
		case 5: return "AB_Lieutenant";
		case 6: return "AB_Thorne";
		}
		return AB_Roster.T0[0];
	}

	// 0..100 "threat" used for tier promotion and head-count
	static int Threat()
	{
		let g = AB_Game.Get();
		if (!g || !g.InRun()) return 20;
		return 10 * AB.RegionDiff[g.v[AB.R_REGION]] + 7 * g.v[AB.R_STAGE] + 8 * g.Heat() + (g.RegionState(g.v[AB.R_REGION]) == AB.RS_LOST ? 10 : 0);
	}

	static Actor SpawnEnemy(Vector3 pos, double ang, int tier, bool alert)
	{
		int th = Threat();
		if (tier <= 2 && random[ABE](0, 99) < th / 2) tier++;			// promotion
		else if (tier >= 1 && tier <= 3 && random[ABE](0, 99) < 22 - th / 3) tier--;	// early regions go easier
		class<Actor> c;
		for (int tries = 0; tries < 4 && !c; tries++) c = (class<Actor>)(Pick(tier));
		if (!c) return null;
		Actor a = Actor.Spawn(c, pos, ALLOW_REPLACE);
		if (!a) return null;
		a.angle = ang;
		if (!a.TestMobjLocation()) { a.ClearCounters(); a.Destroy(); return null; }
		int heat = AB_Game.Get() ? AB_Game.Get().Heat() : 0;
		if (heat > 0 && tier < 5) { a.health = a.health * (10 + heat) / 10; }
		if (alert)
		{
			a.target = players[consoleplayer].mo;
			if (a.SeeState) a.SetState(a.SeeState);
		}
		return a;
	}
}

class AB_EnemySpot : AB_Spot
{
	// args: 0 tier, 1 group (0 = present from the start), 2 = always spawn
	bool Fire(bool alert)
	{
		let a = AB_Roster.SpawnEnemy(pos, angle, args[0], alert);
		if (a && alert) a.Spawn("TeleportFog", a.pos + (0, 0, 20));
		Destroy();
		return a != null;
	}
}

// Springs an ambush group when the player walks close.
class AB_ArenaTrigger : AB_Spot
{
	override void Tick()
	{
		if (level.maptime < 35 || (level.maptime & 7)) return;
		let p = players[consoleplayer].mo;
		if (!p || Distance2D(p) > max(1, args[1]) * 64.0 || abs(p.pos.z - pos.z) > 96) return;
		let lv = AB_Level.Get();
		if (lv) lv.TriggerGroup(args[0], args[2] ? "" : "\cgAMBUSH!\c-  Meridian contractors closing in.");
		Destroy();
	}
}
