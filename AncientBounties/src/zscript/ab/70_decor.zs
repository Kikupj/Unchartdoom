// ============================================================================
// Scenery, camp stations, the extraction flare.
// ============================================================================
class AB_Decor : Actor abstract { Default { Radius 12; Height 32; +SOLID; +NOBLOOD; +DONTTHRUST; Mass 100000; } }
class AB_Fern : AB_Decor       { Default { -SOLID; Radius 8; Height 16; } States { Spawn: ABV1 A -1; Stop; } }
class AB_Palm : AB_Decor       { Default { Radius 10; Height 140; } States { Spawn: ABV2 A -1; Stop; } }
class AB_DryShrub : AB_Decor   { Default { -SOLID; Radius 8; Height 16; } States { Spawn: ABV3 A -1; Stop; } }
class AB_Pine : AB_Decor       { Default { Radius 12; Height 124; } States { Spawn: ABV4 A -1; Stop; } }
class AB_Column : AB_Decor     { Default { Radius 14; Height 60; } States { Spawn: ABV5 A -1; Stop; } }
class AB_PrayerFlags : AB_Decor{ Default { Radius 6; Height 88; } States { Spawn: ABV6 A -1; Stop; } }
class AB_Bones : AB_Decor      { Default { -SOLID; Radius 8; Height 16; } States { Spawn: ABV7 A -1; Stop; } }
class AB_Lantern : AB_Decor    { Default { Radius 6; Height 60; } States { Spawn: ABLN A -1 Bright; Stop; } }
class AB_Antenna : AB_Decor    { Default { Radius 12; Height 168; } States { Spawn: ABAN A -1; Stop; } }
class AB_Campfire : AB_Decor   { Default { Radius 16; Height 24; } States { Spawn: ABFR ABC 4 Bright; Loop; } override void PostBeginPlay() { Super.PostBeginPlay(); A_StartSound("ab/fire", CHAN_BODY, CHANF_LOOPING, 0.5, 2.0); } }
class AB_Torch : AB_Decor      { Default { Radius 10; Height 44; } States { Spawn: ABBZ HI 5 Bright; Loop; } }

// A camp signpost; USE opens the matching manager tab.
class AB_Station : Actor
{
	Default { Radius 20; Height 60; +SOLID; +DONTTHRUST; +NOBLOOD; Mass 100000; }
	States { Spawn: ABSG A -1; Stop; ABSG BCDEFGH 0; }
	override void PostBeginPlay() { Super.PostBeginPlay(); frame = clamp(args[1], 0, 7); }
	override bool Used(Actor user)
	{
		if (!user || !user.player) return false;
		EventHandler.SendInterfaceEvent(user.PlayerNumber(), "ab_open_camp", args[0]);
		return true;
	}
}

// Camp crew standing around (static poses borrowed from the contractor sprites)
class AB_CrewNPC : Actor
{
	Default { Radius 16; Height 56; +SOLID; +DONTTHRUST; +NOBLOOD; Mass 100000; }
	States { Spawn: TNT1 A -1; Stop; }
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		static const String looks[] = { "specopF", "MiltiaSMGmTan", "specopMkak", "MiltiaSMGFkak", "terroristbrown" };
		class<Actor> c = (class<Actor>)(looks[args[0] % looks.Size()]);
		if (c) { let d = GetDefaultByType(c); sprite = d.SpawnState.sprite; frame = d.SpawnState.frame; Translation = d.Translation; Scale = d.Scale; }
	}
	override bool Used(Actor user)
	{
		static const String lines[] = { "\"Jeep's fuelled. Say the word.\"", "\"Thorne pays triple. We're still here. Remember that.\"", "\"Bring back something shiny.\"", "\"Radio says Meridian moved another dig crew in last night.\"", "\"Try not to get shot this time, boss.\"" };
		let lv = AB_Level.Get(); if (lv && user && user.player) lv.Say(lines[random[ABL](0, lines.Size() - 1)], 90);
		return true;
	}
}

// Green flare marking the way out.
class AB_ExitPad : Actor
{
	Default { Radius 24; Height 64; +NOGRAVITY; +NOBLOCKMAP; +DONTSPLASH; RenderStyle "Translucent"; Alpha 0.85; }
	States { Spawn: ABEX ABC 5 Bright; Loop; }
	override void Tick()
	{
		Super.Tick();
		if (level.maptime < 20 || (level.maptime & 3)) return;
		let p = players[consoleplayer].mo;
		if (p && Distance2D(p) < 40 && abs(p.pos.z - pos.z) < 48) { let lv = AB_Level.Get(); if (lv) lv.ReachExit(p); }
	}
}
