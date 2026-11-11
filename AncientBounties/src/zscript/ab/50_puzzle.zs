// ============================================================================
// Puzzles.  A map places one AB_PuzzleCore per puzzle (args: id, type, gate
// sector tag, element count) plus its parts (args: id, index).  Solutions are
// rolled when the level starts, so no two expeditions share an answer.
// ============================================================================
class AB_PuzzlePart : Actor abstract
{
	AB_PuzzleCore core; int pid, idx; int glyph; Actor tablet;
	Default { Radius 14; Height 40; +SOLID; +DONTTHRUST; +NOBLOOD; Mass 100000; }
	override void PostBeginPlay() { Super.PostBeginPlay(); pid = args[0]; idx = args[1]; glyph = -1; }
	override bool Used(Actor user)
	{
		if (!user || !user.player || !core) return false;
		if (level.maptime < core.useLock) return false;
		core.useLock = level.maptime + 10;
		core.PartUsed(self, user);
		return true;
	}
	void ShowGlyph(int g, bool lit = false)
	{
		glyph = g;
		if (!tablet) tablet = Spawn("AB_GlyphTablet", pos + (0, 0, 0));
		if (tablet) { tablet.SetOrigin(pos + (0, 0, Height - 18), false); tablet.frame = g; tablet.sprite = GetSpriteIndex(lit ? "ABGM" : "ABGL"); tablet.bBright = lit; }
	}
}

class AB_GlyphTablet : Actor
{
	Default { +NOBLOCKMAP; +NOGRAVITY; +NOINTERACTION; Scale 0.8; }
	States { Spawn: ABGL A -1; Stop; ABGL BCDEF 0; ABGM ABCDEF 0; }
}

class AB_Lever : AB_PuzzlePart
{
	Default { Radius 12; Height 36; }
	States { Spawn: ABLV A -1; Stop; ABLV B 0; }
	void Pull(bool on) { frame = on ? 1 : 0; A_StartSound("ab/lever", CHAN_BODY); }
}

class AB_Brazier : AB_PuzzlePart
{
	int colour;		// -1 unlit, 0..3
	Default { Radius 12; Height 40; }
	States { Spawn: ABBZ A -1; Stop; ABBZ BCDEFGHI 0; }
	override void Tick()
	{
		Super.Tick();
		if (colour < 0) { frame = 0; bBright = false; }
		else { frame = 1 + colour * 2 + ((level.maptime / 5) & 1); bBright = true; }
	}
	override void PostBeginPlay() { Super.PostBeginPlay(); colour = -1; }
}

class AB_Totem : AB_PuzzlePart
{
	int flash;
	Default { Radius 14; Height 64; }
	States { Spawn: ABTT A -1; Stop; ABTT BCDE 0; }
	override void Tick()
	{
		Super.Tick();
		if (flash > 0) { flash--; frame = 1 + (idx & 3); bBright = true; } else { frame = 0; bBright = false; }
	}
	void Light(int tics) { flash = tics; A_StartSound("ab/totem", CHAN_BODY, 0, 1.0, ATTN_NORM, 0.8 + 0.15 * (idx & 3)); }
}

class AB_Plate : AB_PuzzlePart
{
	bool pressed;
	Default { Radius 24; Height 4; -SOLID; +NOBLOCKMAP; }
	States { Spawn: ABPP A -1; Stop; ABPP B 0; }
	override void Tick()
	{
		Super.Tick();
		if (level.maptime & 3) return;
		bool now = false;
		let it = BlockThingsIterator.Create(self, 40);
		while (it.Next())
		{
			let t = it.thing;
			if (t == self || abs(t.pos.z - pos.z) > 24) continue;
			if ((t is "AB_Block" || t.player) && Distance2D(t) < 30) { now = true; break; }
		}
		if (now != pressed) { pressed = now; frame = now ? 1 : 0; A_StartSound(now ? "ab/plate" : "ab/lever", CHAN_BODY); if (core) core.PartUsed(self, null); }
	}
}

class AB_Block : Actor
{
	Default { Radius 22; Height 46; Mass 400; +SOLID; +PUSHABLE; +SLIDESONWALLS; +CANPASS; +NOBLOOD; +SHOOTABLE; +INVULNERABLE; +NODAMAGE; +DONTTHRUST; +NOTAUTOAIMED; PushFactor 0.35; }
	States { Spawn: ABBK A -1; Stop; }
	override bool Used(Actor user)
	{	// drag the block toward whoever grabs it, so it can never get stuck in a corner
		if (!user || !user.player) return false;
		Vector2 d = user.pos.XY - pos.XY; if (d.Length() < 1) return false;
		Vel.XY = d.Unit() * 5; A_StartSound("ab/stone", CHAN_BODY, 0, 0.6);
		return true;
	}
}

class AB_Stele : AB_PuzzlePart
{
	Default { Radius 16; Height 56; }
	States { Spawn: ABST A -1; Stop; }
}

class AB_Altar : AB_PuzzlePart
{
	Default { Radius 18; Height 28; }
	States { Spawn: ABAL A -1; Stop; ABAL B 0; }
}

class AB_FragmentSpot : AB_Spot { }

class AB_PuzzleCore : AB_Spot
{
	enum EType { PZ_GLYPHS = 1, PZ_BRAZIERS, PZ_PLATES, PZ_SIMON, PZ_FRAGMENTS, PZ_TIMED }
	int pid, ptype, gateTag, count;
	bool ready, solved, clueRead;
	int useLock;
	Array<AB_PuzzlePart> parts;
	Array<int> solution;
	int progress;
	// simon
	int round, showPos, showTic; bool showing;
	// fragments
	int fragsNeeded, fragsHave;
	// timed
	int closeTic;

	override void PostBeginPlay() { Super.PostBeginPlay(); pid = args[0]; ptype = args[1]; gateTag = args[2]; count = args[3]; }

	void Setup()
	{
		ready = true;
		let it = ThinkerIterator.Create("AB_PuzzlePart");
		AB_PuzzlePart p;
		while (p = AB_PuzzlePart(it.Next())) if (p.pid == pid) { p.core = self; parts.Push(p); }
		// order parts by index
		for (int i = 0; i < parts.Size(); i++) for (int j = i + 1; j < parts.Size(); j++) if (parts[j].idx < parts[i].idx) { let t = parts[i]; parts[i] = parts[j]; parts[j] = t; }
		Array<int> g6; for (int i = 0; i < 6; i++) g6.Push(i);
		for (int i = 5; i > 0; i--) { int j = random[ABP](0, i); int t = g6[i]; g6[i] = g6[j]; g6[j] = t; }
		int k = 0;
		switch (ptype)
		{
		case PZ_GLYPHS:
			for (int i = 0; i < parts.Size(); i++) if (parts[i] is "AB_Lever") { parts[i].ShowGlyph(g6[k % 6]); solution.Push(g6[k % 6]); k++; }
			for (int i = solution.Size() - 1; i > 0; i--) { int j = random[ABP](0, i); int t = solution[i]; solution[i] = solution[j]; solution[j] = t; }
			break;
		case PZ_BRAZIERS:
			for (int i = 0; i < parts.Size(); i++) if (parts[i] is "AB_Brazier") { parts[i].ShowGlyph(g6[k % 6]); solution.Push(random[ABP](0, 3)); k++; }
			break;
		case PZ_SIMON:
			round = 0; NewSimon();
			break;
		case PZ_FRAGMENTS:
			{
				let fi = ThinkerIterator.Create("AB_FragmentSpot"); AB_FragmentSpot fs;
				while (fs = AB_FragmentSpot(fi.Next())) if (fs.args[0] == pid) { let f = Spawn("AB_Fragment", fs.pos); if (f) { f.args[0] = pid; fragsNeeded++; } fs.Destroy(); }
			}
			break;
		}
	}

	void NewSimon()
	{
		solution.Clear(); progress = 0;
		int n = 0; for (int i = 0; i < parts.Size(); i++) if (parts[i] is "AB_Totem") n++;
		if (n < 1) return;
		int last = -1;
		for (int i = 0; i < 3 + round; i++) { int t; do { t = random[ABP](0, n - 1); } while (t == last && n > 1); solution.Push(t); last = t; }
	}

	AB_PuzzlePart Nth(String cls, int n)
	{
		int k = 0;
		for (int i = 0; i < parts.Size(); i++) if (parts[i].GetClassName() == cls) { if (k == n) return parts[i]; k++; }
		return null;
	}

	override void Tick()
	{
		if (!ready) { if (level.maptime >= 2) Setup(); return; }
		if (ptype == PZ_SIMON && showing && level.maptime >= showTic)
		{
			if (showPos < solution.Size()) { let t = AB_Totem(Nth("AB_Totem", solution[showPos])); if (t) t.Light(18); showPos++; showTic = level.maptime + 26; }
			else { showing = false; progress = 0; }
		}
		if (ptype == PZ_TIMED && closeTic && level.maptime >= closeTic)
		{
			closeTic = 0;
			if (!solved) { level.ExecuteSpecial(10, self, null, false, gateTag, 32); for (int i = 0; i < parts.Size(); i++) if (parts[i] is "AB_Lever") AB_Lever(parts[i]).Pull(false); }
		}
		if (ptype == PZ_TIMED && closeTic && !solved)
		{
			// once the hunter is well past the gate it stays open
			let lv = AB_Level.Get();
			if (lv && ((closeTic - level.maptime) % 35) == 0 && closeTic - level.maptime > 0) lv.Ticker(String.Format("\cgGate closes in %d\c-", (closeTic - level.maptime) / 35));
		}
	}

	void Fail(Actor user, String why)
	{
		let lv = AB_Level.Get(); let g = AB_Game.Get();
		A_StartSound("ab/wrong", CHAN_AUTO, 0, 1.0, ATTN_NONE);
		bool safe = g && g.HasGear(AB.G_RUBBING);
		if (lv) lv.Say(why .. (safe ? "" : "\n\cgThe trap bites."), 90);
		if (user && !safe) { user.DamageMobj(self, self, random[ABP](8, 14), "Trap"); user.A_StartSound("ab/dart", CHAN_AUTO); }
	}

	void Solve()
	{
		if (solved) return;
		solved = true;
		level.ExecuteSpecial(11, self, null, false, gateTag, 12);		// Door_Open
		A_StartSound("ab/solve", CHAN_AUTO, 0, 1.0, ATTN_NONE);
		let lv = AB_Level.Get();
		if (lv) { lv.Say("\cfThe old mechanism wakes.\c-\nSomewhere, stone grinds on stone.", 120); lv.AddHaul("gold", 25); lv.PuzzleSolved(pid); }
		for (int i = 0; i < parts.Size(); i++) if (parts[i].tablet) { parts[i].tablet.sprite = GetSpriteIndex("ABGM"); parts[i].tablet.bBright = true; }
	}

	void PartUsed(AB_PuzzlePart part, Actor user)
	{
		let lv = AB_Level.Get();
		if (solved) { if (user && lv) lv.Ticker("It has done its work."); return; }
		if (part is "AB_Stele") { ReadClue(); return; }
		switch (ptype)
		{
		case PZ_GLYPHS:
			{
				let lv2 = AB_Lever(part); if (!lv2) return;
				if (lv2.frame == 1) return;
				if (part.glyph == solution[progress])
				{
					lv2.Pull(true); progress++;
					if (progress >= solution.Size()) Solve(); else if (lv) lv.Ticker(String.Format("Click. (%d of %d)", progress, solution.Size()));
				}
				else
				{
					progress = 0;
					for (int i = 0; i < parts.Size(); i++) if (parts[i] is "AB_Lever") parts[i].frame = 0;
					Fail(user, clueRead ? "Wrong order. The levers snap back." : "The levers snap back. There must be a clue nearby.");
				}
			}
			break;
		case PZ_BRAZIERS:
			{
				let b = AB_Brazier(part); if (!b) return;
				b.colour = (b.colour + 1) % 4; b.A_StartSound("ab/flame", CHAN_BODY);
				bool all = true; int k = 0;
				for (int i = 0; i < parts.Size(); i++) { let bb = AB_Brazier(parts[i]); if (!bb) continue; if (bb.colour != solution[k]) all = false; k++; }
				if (all) Solve();
			}
			break;
		case PZ_PLATES:
			{
				bool all = true; int n = 0;
				for (int i = 0; i < parts.Size(); i++) { let pl = AB_Plate(parts[i]); if (!pl) continue; n++; if (!pl.pressed) all = false; }
				if (all && n > 0) Solve();
			}
			break;
		case PZ_SIMON:
			{
				let t = AB_Totem(part); if (!t || showing) return;
				if (solution.Size() == 0) return;
				if (progress == 0 && !clueRead && showPos == 0) { StartShow(); return; }
				int want = solution[progress];
				if (Nth("AB_Totem", want) == part)
				{
					t.Light(10); progress++;
					if (progress >= solution.Size())
					{
						round++;
						if (round >= 3) Solve();
						else { if (lv) lv.Ticker(String.Format("The totems hum. (%d of 3)", round)); NewSimon(); showPos = 0; showing = true; showTic = level.maptime + 50; }
					}
				}
				else { Fail(user, "The totems fall dark. Watch again."); NewSimon(); showPos = 0; showing = true; showTic = level.maptime + 60; }
			}
			break;
		case PZ_FRAGMENTS:
			if (part is "AB_Altar")
			{
				if (fragsHave >= fragsNeeded) { part.frame = 1; part.bBright = true; Solve(); }
				else if (lv) lv.Say(String.Format("The altar has three hollows.\nIdol fragments: %d of %d", fragsHave, fragsNeeded), 90);
			}
			break;
		case PZ_TIMED:
			{
				let l = AB_Lever(part); if (!l || closeTic) return;
				l.Pull(true);
				level.ExecuteSpecial(11, self, null, false, gateTag, 64);
				closeTic = level.maptime + 35 * max(6, count);
				if (lv) lv.Say("\cfA counterweight drops.\c-\nThe gate is open - but not for long. RUN!", 90);
			}
			break;
		}
	}

	void StartShow() { clueRead = true; showPos = 0; showing = true; showTic = level.maptime + 20; let lv = AB_Level.Get(); if (lv) lv.Say("The totems stir. Watch the order, then repeat it.", 90); }

	void ReadClue()
	{
		let lv = AB_Level.Get(); if (!lv) return;
		clueRead = true;
		A_StartSound("ab/clue", CHAN_AUTO, 0, 1.0, ATTN_NONE);
		let g = AB_Game.Get();
		bool scholar = g && g.PartnerClass() == 2;
		switch (ptype)
		{
		case PZ_GLYPHS:
			{ Array<int> none; lv.SetClue(pid, "Pull the levers in this order:", solution, none); }
			break;
		case PZ_BRAZIERS:
			{
				Array<int> gl; for (int i = 0; i < parts.Size(); i++) if (parts[i] is "AB_Brazier") gl.Push(parts[i].glyph);
				lv.SetClue(pid, "Each sign burns with its own flame:", gl, solution);
			}
			break;
		case PZ_PLATES: lv.Say("\cfThe carving shows stone blocks resting on every seal.\c-\nPush the blocks onto the plates. (Use a block to drag it toward you.)", 175); break;
		case PZ_SIMON: StartShow(); break;
		case PZ_FRAGMENTS: lv.Say(String.Format("\cfThe carving shows a broken idol made whole upon the altar.\c-\nFragments found: %d of %d", fragsHave, fragsNeeded), 175); break;
		case PZ_TIMED: lv.Say("\cfThe carving shows a runner and a falling gate.\c-\nPull the lever, then do not stop for anything.", 175); break;
		}
	}
}

// ---------------------------------------------------------------- traps
class AB_SpikeTrap : Actor
{
	int phase;
	Default { Radius 16; Height 4; +NOBLOCKMAP; }
	States { Spawn: ABSK A -1; Stop; ABSK BC 0; }
	override void Tick()
	{
		Super.Tick();
		int period = args[1] ? args[1] * 35 / 4 : 105;
		int t = (level.maptime + args[0] * 12) % period;
		int f = t < period - 45 ? 0 : (t < period - 30 ? 1 : 2);
		if (f != frame)
		{
			frame = f;
			if (f == 1) A_StartSound("ab/spikewarn", CHAN_BODY, 0, 0.5);
			if (f == 2) A_StartSound("ab/spike", CHAN_BODY, 0, 0.8);
		}
		if (f == 2 && (t & 7) == 0)
		{
			let it = BlockThingsIterator.Create(self, 32);
			while (it.Next()) { let a = it.thing; if (a != self && a.bShootable && Distance2D(a) < 22 && abs(a.pos.z - pos.z) < 24) a.DamageMobj(self, self, 12, "Trap"); }
		}
	}
}

class AB_Dart : Actor
{
	Default { Radius 3; Height 3; Speed 26; DamageFunction (random(6, 10)); Projectile; +THRUGHOST; SeeSound "ab/dart"; DamageType "Trap"; }
	States { Spawn: ABDT A -1; Stop; Death: TNT1 A 1; Stop; }
}

class AB_DartTrap : AB_Spot
{
	override void Tick()
	{
		int period = args[0] ? args[0] * 35 / 4 : 70;
		if (((level.maptime + args[1] * 9) % period) != 0) return;
		let p = players[consoleplayer].mo;
		if (!p || Distance3D(p) > 900) return;
		let d = Spawn("AB_Dart", pos + (0, 0, 28));
		if (d) { d.target = self; d.angle = angle; d.VelFromAngle(d.Speed, angle); d.A_StartSound("ab/dart", CHAN_BODY, 0, 0.6); }
	}
}
