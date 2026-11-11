version "4.10"

// ============================================================================
// WinBack / Time Crisis Tactical Duck & Dodge AI
// Non-destructive EventHandler + Inventory Controller for Human Enemies
// Featuring:
//  - Pop-Up & Duck Cycle + Evasive Side-Step / 360 Combat Roll
//  - 3D Geometry & Wall-Edge Cover Detection + WinBack Corner Peeking
//  - Tactical Retreat Under Player Gunfire
//  - Aggressive Push When Player is Out of View & Not Firing
//  - Per-Enemy Magazine Ammo Tracking & Crouched Tactical Reloads
//  - Shootable Cooking Explosive Barrels & Random Enemy Panic-Flee Behavior
// ============================================================================

class TacticalAIEventHandler : EventHandler
{
	Array<Actor> ActiveProjectiles;

	override void WorldTick()
	{
		for (int i = ActiveProjectiles.Size() - 1; i >= 0; i--)
		{
			Actor proj = ActiveProjectiles[i];
			if (!proj || !proj.bMISSILE || proj.Vel.LengthSquared() < 0.01)
			{
				ActiveProjectiles.Delete(i);
			}
		}
	}

	override void WorldThingSpawned(WorldEvent e)
	{
		if (!e.Thing)
			return;

		Actor mo = e.Thing;

		// 1. Detect player hitscan BulletPuffs to trigger nearby enemy gunfire suppression!
		if (mo is "BulletPuff")
		{
			AlertMonstersNearImpact(mo.pos, 220.0);
			return;
		}

		// 2. Handle projectiles:
		//    - Track active projectiles in `ActiveProjectiles` for 3D trajectory dodging (KAI / Smart Marines port)
		//    - Player projectiles alert nearby monsters
		//    - Enemy projectiles adjust height when crouched AND decrement enemy magazine ammo!
		if (mo.bMISSILE && mo.target)
		{
			if (!(mo is "TacticalSpentMag"))
			{
				ActiveProjectiles.Push(mo);
			}

			if (mo.target.player)
			{
				AlertMonstersNearImpact(mo.pos, 256.0);
				return;
			}

			let ctrl = TacticalAIController(mo.target.FindInventory("TacticalAIController"));
			if (ctrl)
			{
				if (ctrl.IsCrouchedPosture())
				{
					Vector3 newPos = mo.pos;
					newPos.z = max(mo.target.pos.z + 8.0, mo.pos.z - 15.0);
					mo.SetOrigin(newPos, false);
				}

				// Count shot toward enemy magazine reload
				ctrl.NotifyWeaponFired(mo);
			}
			return;
		}

		// 3. Attach TacticalAIController to eligible grounded human-sized monsters.
		if (IsEligibleMonster(mo))
		{
			if (!mo.FindInventory("TacticalAIController"))
			{
				mo.GiveInventory("TacticalAIController", 1);
			}
		}
	}

	override void WorldThingDamaged(WorldEvent e)
	{
		if (!e.Thing || e.Thing.health <= 0)
			return;

		let ctrl = TacticalAIController(e.Thing.FindInventory("TacticalAIController"));
		if (ctrl)
		{
			ctrl.NotifyDamaged(e.DamageSource, e.Damage);
		}
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name ~== "nbc_reset_defaults")
		{
			ResetCVarBool('nbc_tactical_enable', true);
			ResetCVarInt('nbc_duck_chance', 75);
			ResetCVarInt('nbc_dodge_chance', 65);
			ResetCVarBool('nbc_roll_enable', true);
			ResetCVarBool('nbc_crouch_fire', true);
			ResetCVarBool('nbc_telegraph_flash', true);

			ResetCVarBool('nbc_proj_dodge_enable', true);
			ResetCVarInt('nbc_proj_dodge_range', 384);
			ResetCVarBool('nbc_dodge_attack', true);
			ResetCVarBool('nbc_active_cover_run', true);
			ResetCVarBool('nbc_prop_cover_enable', true);

			ResetCVarBool('nbc_reload_enable', true);
			ResetCVarInt('nbc_reload_tics', 52);
			ResetCVarInt('nbc_reload_shots', 0);

			ResetCVarBool('nbc_barrel_cook_enable', true);
			ResetCVarInt('nbc_barrel_cook_tics', 52);
			ResetCVarInt('nbc_barrel_flee_chance', 65);
			ResetCVarInt('nbc_barrel_panic_radius', 240);
			ResetCVarFloat('nbc_barrel_flee_speed', 1.55);

			ResetCVarBool('nbc_cover_seek', true);
			ResetCVarBool('nbc_corner_peek', true);
			ResetCVarBool('nbc_open_duck', true);
			ResetCVarInt('nbc_cover_search_dist', 128);

			ResetCVarBool('nbc_retreat_enable', true);
			ResetCVarInt('nbc_retreat_chance', 55);
			ResetCVarFloat('nbc_retreat_speed', 1.35);
			ResetCVarInt('nbc_retreat_tics', 45);

			ResetCVarBool('nbc_push_enable', true);
			ResetCVarInt('nbc_push_delay_tics', 35);
			ResetCVarFloat('nbc_push_speed', 1.45);
			ResetCVarInt('nbc_push_tics', 85);

			ResetCVarFloat('nbc_roll_speed', 6.0);
			ResetCVarInt('nbc_roll_tics', 24);
			ResetCVarFloat('nbc_strafe_speed', 6.5);
			ResetCVarInt('nbc_strafe_tics', 18);
			ResetCVarInt('nbc_duck_tics', 40);

			Console.Printf("\c[Cyan][TacticalAI]\c- All parameters reset to default values.");
		}
	}

	static void ResetCVarBool(Name n, bool val)
	{
		CVar c = CVar.FindCVar(n);
		if (c) c.SetBool(val);
	}

	static void ResetCVarInt(Name n, int val)
	{
		CVar c = CVar.FindCVar(n);
		if (c) c.SetInt(val);
	}

	static void ResetCVarFloat(Name n, double val)
	{
		CVar c = CVar.FindCVar(n);
		if (c) c.SetFloat(val);
	}

	void AlertMonstersNearImpact(Vector3 impactPos, double radius)
	{
		BlockThingsIterator it = BlockThingsIterator.CreateFromPos(
			impactPos.x, impactPos.y, impactPos.z, 64.0, radius, false);

		while (it.Next())
		{
			Actor mo = it.Thing;
			if (!mo || !mo.bISMONSTER || mo.health <= 0)
				continue;

			double dist = Level.Vec3Diff(impactPos, mo.pos).Length();
			if (dist <= radius)
			{
				let ctrl = TacticalAIController(mo.FindInventory("TacticalAIController"));
				if (ctrl)
				{
					ctrl.NotifyNearGunfire(impactPos, dist);
				}
			}
		}
	}

	static bool IsEligibleMonster(Actor mo)
	{
		if (!mo || !mo.bISMONSTER || mo.bCORPSE || mo.health <= 0)
			return false;

		// Exclude flying/floating enemies (e.g., drones, jetpackers) and huge bosses
		if (mo.bFLOAT || mo.bNOGRAVITY || mo.bBOSS)
			return false;

		if (mo.default.Radius > 36 || mo.default.Height > 72)
			return false;

		return true;
	}
}

// ============================================================================
// Cooking Explosive Barrel:
// Instead of detonating instantaneously, lethal damage starts a sizzling,
// shaking `Cooking` state for `nbc_barrel_cook_tics`. Follow-up shots or
// nearby explosions while cooking accelerate or immediately trigger detonation!
// ============================================================================
class TacticalBarrelSpark : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOTELEPORT
		+DONTSPLASH
		+BRIGHT
		RenderStyle "Add";
		Alpha 0.90;
		Scale 0.45;
	}

	States
	{
	Spawn:
		PUFF A 2 Bright A_SetScale(Scale.X * 1.15);
		PUFF B 2 Bright A_FadeOut(0.25);
		PUFF C 2 Bright A_FadeOut(0.30);
		PUFF D 2 Bright A_FadeOut(0.35);
		Stop;
	}
}

class CookingExplosiveBarrel : ExplosiveBarrel replaces ExplosiveBarrel
{
	int cookTimer;
	int totalCookTics;
	bool isCooking;
	bool hasExploded;
	Actor cookInstigator;

	Default
	{
		+ROLLSPRITE
		+ROLLCENTER
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		CVar cCook = CVar.FindCVar('nbc_barrel_cook_enable');
		bool allowCook = (!cCook || cCook.GetBool());

		if (allowCook && !hasExploded)
		{
			if (!isCooking && (health - damage <= 0))
			{
				// Heavy single-hit blast (>= 60 dmg, e.g. direct rocket) detonates immediately
				if (damage < 60)
				{
					isCooking = true;
					cookInstigator = source;
					CVar cTics = CVar.FindCVar('nbc_barrel_cook_tics');
					totalCookTics = cTics ? max(10, cTics.GetInt()) : 52;
					cookTimer = totalCookTics;

					health = 1;
					A_StartSound("weapons/flamer", CHAN_BODY, CHANF_OVERLAP, 0.9);
					AlertNearbyEnemies();
					SetStateLabel("CookLoop");
					return 0;
				}
			}
			else if (isCooking)
			{
				// Shooting a cooking barrel again speeds up detonation (or triggers it!)
				if (source)
					cookInstigator = source;

				cookTimer -= max(10, damage * 2);
				if (cookTimer > 0)
				{
					health = 1;
					return 0;
				}
				// Let fatal damage fall through to Death -> ExplodeNow!
			}
		}

		return Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
	}

	States
	{
	CookLoop:
		BAR1 A 2 Bright
		{
			if (TickCookingBarrel())
				return ResolveState("TriggerDetonation");
			return ResolveState(null);
		}
		BEXP A 2 Bright
		{
			if (TickCookingBarrel())
				return ResolveState("TriggerDetonation");
			return ResolveState(null);
		}
		BAR1 B 2 Bright
		{
			if (TickCookingBarrel())
				return ResolveState("TriggerDetonation");
			return ResolveState(null);
		}
		BEXP B 2 Bright
		{
			if (TickCookingBarrel())
				return ResolveState("TriggerDetonation");
			return ResolveState(null);
		}
		Loop;

	TriggerDetonation:
		BEXP B 0 Bright
		{
			isCooking = false;
			hasExploded = true;
			bShootable = false;
			if (cookInstigator)
				target = cookInstigator;
		}
		Goto Death;

	Death:
		BEXP B 4 Bright
		{
			isCooking = false;
			hasExploded = true;
			Roll = 0.0;
			Scale = (1.0, 1.0);
			if (cookInstigator && !target)
				target = cookInstigator;
			A_Scream();
		}
		BEXP C 4 Bright;
		BEXP D 10 Bright A_Explode;
		BEXP E 10 Bright;
		TNT1 A 1050 Bright A_BarrelDestroy;
		TNT1 A 5 A_Respawn;
		Wait;
	}

	bool TickCookingBarrel()
	{
		cookTimer -= 2;

		double progress = 1.0 - (double(max(0, cookTimer)) / double(max(1, totalCookTics)));

		// Escalating vibration / bulge as pressure builds inside the barrel
		double shakeAmp = 2.0 + progress * 9.0;
		Roll = Random[BarrelCook](-100, 100) * 0.01 * shakeAmp;
		Scale.X = 1.0 + sin(cookTimer * 45.0) * (0.03 + progress * 0.08);
		Scale.Y = 1.0 - sin(cookTimer * 45.0) * (0.03 + progress * 0.06);

		// Spawn rising flame/spark jets from the top of the barrel
		Vector3 jetPos = pos + (Random[BarrelCook](-6, 6), Random[BarrelCook](-6, 6), Height - 4.0);
		Actor spk = Actor.Spawn("TacticalBarrelSpark", jetPos, ALLOW_REPLACE);
		if (spk)
		{
			spk.Vel = (Random[BarrelCook](-15, 15) * 0.1, Random[BarrelCook](-15, 15) * 0.1, Random[BarrelCook](20, 45) * 0.1);
			spk.Scale *= (0.8 + progress * 0.7);
		}

		if (cookTimer % 12 == 0)
		{
			A_StartSound("weapons/flamer", CHAN_BODY, CHANF_OVERLAP, 0.85);
		}
		if (cookTimer % 6 == 0)
		{
			AlertNearbyEnemies();
		}

		return (cookTimer <= 0);
	}

	void AlertNearbyEnemies()
	{
		CVar cRad = CVar.FindCVar('nbc_barrel_panic_radius');
		double panicRadius = cRad ? max(64.0, double(cRad.GetInt())) : 240.0;

		BlockThingsIterator it = BlockThingsIterator.CreateFromPos(
			pos.x, pos.y, pos.z, Height, panicRadius, false);

		while (it.Next())
		{
			Actor mo = it.Thing;
			if (!mo || !mo.bISMONSTER || mo.health <= 0)
				continue;

			double dist = Level.Vec3Diff(pos, mo.pos).Length();
			if (dist <= panicRadius && CheckSight(mo))
			{
				let ctrl = TacticalAIController(mo.FindInventory("TacticalAIController"));
				if (ctrl)
				{
					ctrl.NotifyCookingBarrel(self, dist);
				}
			}
		}
	}
}

// ============================================================================
// Subtle visual glint when an enemy pops up or peeks out from cover to shoot
// ============================================================================
class TacticalTelegraphGlint : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOTELEPORT
		+DONTSPLASH
		+BRIGHT
		RenderStyle "Add";
		Alpha 0.85;
		Scale 0.35;
	}

	States
	{
	Spawn:
		PUFF A 2 Bright A_FadeOut(0.25);
		PUFF B 2 Bright A_FadeOut(0.30);
		Stop;
	}
}

// ============================================================================
// Ejected Empty Magazine prop dropped when an enemy reloads
// ============================================================================
class TacticalSpentMag : Actor
{
	Default
	{
		Radius 3;
		Height 4;
		Scale 0.42;
		BounceType "Doom";
		BounceFactor 0.45;
		BounceCount 3;
		+MISSILE
		+NOBLOCKMAP
		+DROPOFF
		+NOTELEPORT
		+FLOORCLIP
		+ROLLSPRITE
		+ROLLCENTER
	}

	States
	{
	Spawn:
		CLIP A 2
		{
			Roll += 28.0;
		}
		Loop;
	Death:
		CLIP A 140
		{
			Roll = 90.0;
		}
	FadeLoop:
		CLIP A 2 A_FadeOut(0.08);
		Loop;
	}
}

// ============================================================================
// Per-Enemy Tactical AI Controller
// ============================================================================
class TacticalAIController : Inventory
{
	enum ETacticalState
	{
		TSTATE_NORMAL = 0,     // Standard movement / chasing
		TSTATE_DUCK,           // Crouched down (stationary, low hitbox, holding cover)
		TSTATE_POPUP,          // Standing back up & telegraphing before burst
		TSTATE_CROUCH_FIRE,    // Firing a burst from a crouched posture
		TSTATE_DODGE_STRAFE,   // Leaning lateral evade dash (WinBack style)
		TSTATE_DODGE_ROLL,     // 360-degree combat dive-roll (Time Crisis style)
		TSTATE_CORNER_HIDE,    // Hiding behind a full wall corner / pillar edge
		TSTATE_CORNER_PEEK,    // Stepping back out from a wall edge to fire!
		TSTATE_RETREAT,        // Backing away / retreating into cover under player gunfire
		TSTATE_PUSH,           // Aggressively advancing when player is out of view & silent
		TSTATE_RELOAD,         // Crouched tactical weapon reload (cannot fire until complete)
		TSTATE_BARREL_FLEE,    // Panicked sprint away from a cooking explosive barrel!
		TSTATE_SEEK_COVER      // Actively sprinting to distant cover (Smart Marines port)
	};

	enum ECoverType
	{
		COVER_NONE = 0,        // Exposed at both crouched and standing heights
		COVER_LOW  = 1,        // Waist-high geometry blocks crouched height, clear at standing height
		COVER_FULL = 2         // Solid wall/pillar blocks both crouched and standing heights
	};

	int tacState;
	int stateTimer;
	int stateDuration;

	// Cooldowns & trackers
	int actionCooldown;
	int missileTics;
	int maxBurstTics;
	int aimedAtTics;
	int suppressedTics;
	int outOfSightTics;
	int playerSilentTics;
	int pushSightRegainedTics;
	bool wasInMissile;
	bool initialized;
	bool corpseCleaned;

	// Magazine & Reload state
	int currentAmmo;
	int maxAmmo;
	bool ammoConfigured;
	bool isShotgunner;
	bool pendingReload;
	int reloadStage;

	// Cooking Barrel hazard tracking
	Actor hazardBarrel;
	Actor lastEvaluatedBarrel;
	bool pendingBarrelFlee;

	// Stationary anchor, corner peek memory & locked poses
	Vector2 duckAnchorXY;
	Vector2 dodgeStartXY;
	Vector2 peekOriginXY;
	bool hasPeekOrigin;
	int peekSign;
	SpriteID aimSprite;
	int aimFrame;
	SpriteID idleSprite;
	int idleFrame;

	// Dodge parameters
	double dodgeAngle;
	double dodgeSpeed;
	int lastDodgeSign; // +1 left, -1 right
	bool didMidDodgeShot;
	Name cachedProjectileClass;

	// Active Cover Pathing (Smart Marines port)
	Vector2 coverGoalXY;
	int coverGoalType;

	// Cached baseline actor properties
	double baseHeight;
	double baseRadius;
	double baseScaleX;
	double baseScaleY;
	double baseSpeed;
	bool baseFrightened;

	Default
	{
		Inventory.MaxAmount 1;
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		+INVENTORY.AUTOACTIVATE
	}

	bool IsCrouchedPosture() const
	{
		return (tacState == TSTATE_DUCK || tacState == TSTATE_CROUCH_FIRE ||
		        tacState == TSTATE_DODGE_ROLL || tacState == TSTATE_CORNER_HIDE ||
		        tacState == TSTATE_RELOAD);
	}

	void InitBaseline()
	{
		if (!Owner || initialized)
			return;

		baseHeight     = Owner.default.Height;
		baseRadius     = Owner.default.Radius;
		baseScaleX     = Owner.Scale.X;
		baseScaleY     = Owner.Scale.Y;
		baseSpeed      = Owner.Speed;
		baseFrightened = Owner.bFRIGHTENED;

		if (Owner.SeeState)
		{
			idleSprite = Owner.SeeState.sprite;
			idleFrame  = Owner.SeeState.Frame;
		}
		else
		{
			idleSprite = Owner.sprite;
			idleFrame  = 0;
		}

		if (Owner.MissileState)
		{
			aimSprite = Owner.MissileState.sprite;
			aimFrame  = Owner.MissileState.Frame;
		}
		else
		{
			aimSprite = idleSprite;
			aimFrame  = idleFrame;
		}

		int overrideShots = GetCVarInt('nbc_reload_shots', 0);
		maxAmmo = (overrideShots > 0) ? overrideShots : 8;
		currentAmmo = maxAmmo;

		Owner.bROLLSPRITE = true;
		Owner.bROLLCENTER = true;

		lastDodgeSign = (Random[TacAI](0, 1) == 0) ? 1 : -1;
		maxBurstTics = Random[TacAI](25, 45);
		actionCooldown = Random[TacAI](10, 25);
		initialized = true;
	}

	// ========================================================================
	// Called by EventHandler whenever this enemy spawns a projectile/tracer
	// ========================================================================
	void NotifyWeaponFired(Actor proj)
	{
		if (proj && !(proj is "TacticalSpentMag") && cachedProjectileClass == 'None')
		{
			cachedProjectileClass = proj.GetClassName();
		}

		if (!Owner || !GetCVarBool('nbc_reload_enable', true))
			return;

		int overrideShots = GetCVarInt('nbc_reload_shots', 0);
		if (overrideShots > 0)
		{
			if (maxAmmo != overrideShots)
			{
				maxAmmo = overrideShots;
				currentAmmo = min(currentAmmo, maxAmmo);
			}
			ammoConfigured = true;
		}
		else if (!ammoConfigured && proj)
		{
			Name cls = proj.GetClassName();
			if (cls == 'EnemySMGTracer' || cls == 'EnemyChaingunTracer')
			{
				maxAmmo = Random[TacAI](16, 22); // SMGs / Assault Rifles / Uzis
			}
			else if (cls == 'EnemyLMGTracer')
			{
				maxAmmo = Random[TacAI](5, 7);   // Shotguns / Heavy bursts
				isShotgunner = true;
			}
			else if (cls == 'EnemyRifleTracer')
			{
				maxAmmo = Random[TacAI](5, 8);   // Rifles / Snipers
			}
			else
			{
				maxAmmo = Random[TacAI](7, 10);  // Pistols / Revolvers
			}
			currentAmmo = maxAmmo;
			ammoConfigured = true;
		}

		currentAmmo--;
		if (currentAmmo <= 0)
		{
			pendingReload = true;
		}
	}

	// ========================================================================
	// Called by CookingExplosiveBarrel when sizzling within panic radius.
	// Each enemy rolls ONCE per cooking barrel against `nbc_barrel_flee_chance`!
	// ========================================================================
	void NotifyCookingBarrel(Actor barrel, double dist)
	{
		if (!Owner || Owner.health <= 0 || !barrel)
			return;

		if (tacState == TSTATE_BARREL_FLEE || pendingBarrelFlee)
			return;

		if (lastEvaluatedBarrel == barrel)
			return;

		lastEvaluatedBarrel = barrel;

		int fleeChance = GetCVarInt('nbc_barrel_flee_chance', 65);
		int roll = Random[TacAI](1, 100);
		if (roll > fleeChance)
		{
			LogDebug(String.Format("IGNORED COOKING BARREL (rolled %d > %d%%)", roll, fleeChance));
			return;
		}

		hazardBarrel = barrel;

		if (Owner.PainSound)
		{
			Owner.A_StartSound(Owner.PainSound, CHAN_VOICE, CHANF_OVERLAP, 1.0);
		}

		// If very close to the cooking barrel (< 120 units), try an emergency dive-roll
		// directly away from the barrel before sprinting away!
		if (dist < 120.0 && GetCVarBool('nbc_roll_enable', true) && Random[TacAI](1, 100) <= 60)
		{
			double awayAng = barrel.AngleTo(Owner) + Random[TacAI](-25, 25);
			int rollTics   = max(6, GetCVarInt('nbc_roll_tics', 24));
			double rollSpd = max(0.5, GetCVarFloat('nbc_roll_speed', 6.0));
			double testDist = clamp(rollSpd * rollTics * 0.75, 48.0, 128.0);

			if (IsDirectionClear(awayAng, testDist))
			{
				RestoreStandingProperties(true);
				if (Owner.SeeState)
					Owner.SetState(Owner.SeeState);

				dodgeAngle = awayAng;
				dodgeStartXY = Owner.pos.xy;
				pendingBarrelFlee = true;

				tacState = TSTATE_DODGE_ROLL;
				stateDuration = rollTics;
				stateTimer = rollTics;
				dodgeSpeed = rollSpd;
				Owner.A_SetSize(baseRadius, baseHeight * 0.50, false);
				if (Owner.pos.z <= Owner.floorz + 1.0)
					Owner.Vel.Z = max(Owner.Vel.Z, 2.5);
				Owner.Speed = 0;
				Owner.tics  = 10;

				LogDebug("COOKING BARREL CLOSE -> DIVE-ROLLING AWAY!");
				return;
			}
		}

		StartBarrelFlee();
	}

	override void DoEffect()
	{
		Super.DoEffect();

		if (!Owner)
			return;

		if (!initialized)
			InitBaseline();

		// Always restore normal visuals/scale/flags immediately on death
		if (Owner.health <= 0 || Owner.bCORPSE)
		{
			if (!corpseCleaned)
			{
				RestoreStandingProperties(false);
				corpseCleaned = true;
			}
			return;
		}

		// Respect master toggle CVar
		CVar cEnable = CVar.FindCVar('nbc_tactical_enable');
		if (cEnable && !cEnable.GetBool())
		{
			if (tacState != TSTATE_NORMAL)
				EnterNormalState();
			return;
		}

		if (actionCooldown > 0)
			actionCooldown--;
		if (suppressedTics > 0)
			suppressedTics--;

		State painSt   = Owner.FindState('Pain');
		bool inMissile = (Owner.MissileState != null && Owner.InStateSequence(Owner.CurState, Owner.MissileState));
		bool inPain    = (painSt != null && Owner.InStateSequence(Owner.CurState, painSt));
		bool inSee     = (Owner.SeeState != null && Owner.InStateSequence(Owner.CurState, Owner.SeeState));

		if (inMissile)
			missileTics++;
		else
			missileTics = 0;

		// Check if enemy just ran out of ammo (unless currently fleeing a barrel or mid-roll)!
		if (pendingReload && tacState != TSTATE_RELOAD && tacState != TSTATE_BARREL_FLEE &&
		    tacState != TSTATE_DODGE_ROLL && tacState != TSTATE_DODGE_STRAFE)
		{
			TriggerOutOfAmmoReload(inMissile);
			wasInMissile = false;
			return;
		}

		// Update player crosshair, gunfire suppression, line-of-sight, and silence trackers
		UpdatePlayerThreatTrackers();

		// Check for incoming 3D projectile trajectory threat (KAI / Smart Marines port)
		if ((tacState == TSTATE_NORMAL || tacState == TSTATE_PUSH || tacState == TSTATE_SEEK_COVER) &&
		    actionCooldown <= 5 && GetCVarBool('nbc_proj_dodge_enable', true))
		{
			Actor threatProj = FindIncomingProjectileThreat();
			if (threatProj && TryDodgeProjectile(threatProj))
			{
				wasInMissile = false;
				return;
			}
		}

		// Execute current tactical state machine
		switch (tacState)
		{
		case TSTATE_NORMAL:
			TickNormal(inMissile, inPain, inSee);
			break;

		case TSTATE_DUCK:
			TickDuck(inPain);
			break;

		case TSTATE_POPUP:
			TickPopUp(inPain);
			break;

		case TSTATE_CROUCH_FIRE:
			TickCrouchFire(inMissile, inPain);
			break;

		case TSTATE_DODGE_STRAFE:
			TickDodgeStrafe(inPain);
			break;

		case TSTATE_DODGE_ROLL:
			TickDodgeRoll(inPain);
			break;

		case TSTATE_CORNER_HIDE:
			TickCornerHide(inPain);
			break;

		case TSTATE_CORNER_PEEK:
			TickCornerPeek(inPain);
			break;

		case TSTATE_RETREAT:
			TickRetreat(inMissile, inPain);
			break;

		case TSTATE_PUSH:
			TickPush(inMissile, inPain);
			break;

		case TSTATE_RELOAD:
			TickReload(inPain);
			break;

		case TSTATE_BARREL_FLEE:
			TickBarrelFlee(inMissile, inPain);
			break;

		case TSTATE_SEEK_COVER:
			TickSeekCover(inMissile, inPain);
			break;
		}

		wasInMissile = inMissile;
	}

	// ========================================================================
	// BARREL FLEE STATE:
	// Enemy sprints away from `hazardBarrel` with an animated run cycle until
	// the barrel detonates or they are safely outside the blast radius!
	// ========================================================================
	void StartBarrelFlee()
	{
		if (!Owner || !hazardBarrel)
			return;

		RestoreStandingProperties(true);
		pendingBarrelFlee = false;

		int cookTics = max(25, GetCVarInt('nbc_barrel_cook_tics', 52) + 15);
		double fleeMult = max(1.0, GetCVarFloat('nbc_barrel_flee_speed', 1.55));

		tacState = TSTATE_BARREL_FLEE;
		stateDuration = cookTics;
		stateTimer = cookTics;
		actionCooldown = 30;

		Owner.Speed = 0; // We drive smooth velocity directly while animating walk frames
		if (Owner.SeeState && !Owner.InStateSequence(Owner.CurState, Owner.SeeState))
		{
			Owner.SetState(Owner.SeeState);
		}
		Owner.tics = 10;

		LogDebug(String.Format("PANIC FLEEING COOKING BARREL! (speed=%.2fx)", fleeMult));
	}

	void TickBarrelFlee(bool inMissile, bool inPain)
	{
		stateTimer--;

		// Slight forward sprint lean
		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX * 1.04, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * 0.90, 0.35);
		Owner.Roll    = Lerp(Owner.Roll, 0.0, 0.4);

		// Check if the barrel already exploded or was destroyed
		let cookBarrel = CookingExplosiveBarrel(hazardBarrel);
		if (!hazardBarrel || hazardBarrel.bInvisible || (cookBarrel && cookBarrel.hasExploded))
		{
			LogDebug("BARREL DETONATED -> RESUMING COMBAT");
			hazardBarrel = null;
			Owner.Vel.X = 0.0;
			Owner.Vel.Y = 0.0;
			if (pendingReload)
				StartReload();
			else
				EnterNormalState();
			return;
		}

		double panicRad = max(96.0, double(GetCVarInt('nbc_barrel_panic_radius', 240)));
		double dist = Level.Vec3Diff(hazardBarrel.pos, Owner.pos).Length();

		// Once safely outside blast radius (+48 buffer), stop fleeing and duck/turn back!
		if (dist > panicRad + 48.0 || stateTimer <= 0)
		{
			LogDebug(String.Format("REACHED SAFE DISTANCE FROM BARREL (%.0f units) -> TAKING COVER", dist));
			hazardBarrel = null;
			Owner.Vel.X = 0.0;
			Owner.Vel.Y = 0.0;
			RestoreStandingProperties(true);
			if (pendingReload)
			{
				StartReload();
			}
			else if (GetCVarBool('nbc_open_duck', true))
			{
				StartDuck(max(15, GetRandomizedDuckTics() / 2));
			}
			else
			{
				EnterNormalState();
			}
			return;
		}

		// Hold A_Chase paused and cycle walking frames A->B->C->D smoothly while sprinting away
		if (!inPain)
		{
			Owner.tics   = 10;
			Owner.sprite = idleSprite;
			Owner.frame  = (stateTimer / 3) & 3;
		}

		// Actively drive velocity away from the cooking barrel (picking a clear path if blocked)
		double awayAng = hazardBarrel.AngleTo(Owner);
		double moveAng = awayAng;

		if (!IsDirectionClear(awayAng, 28.0))
		{
			if (IsDirectionClear(awayAng + 55.0, 28.0))
				moveAng = awayAng + 55.0;
			else if (IsDirectionClear(awayAng - 55.0, 28.0))
				moveAng = awayAng - 55.0;
			else if (IsDirectionClear(awayAng + 100.0, 28.0))
				moveAng = awayAng + 100.0;
			else if (IsDirectionClear(awayAng - 100.0, 28.0))
				moveAng = awayAng - 100.0;
		}

		Owner.angle = moveAng;
		double fleeVel = max(4.5, (baseSpeed * GetCVarFloat('nbc_barrel_flee_speed', 1.55)) * 0.45);
		Vector2 stepVec = Actor.AngleToVector(moveAng, fleeVel);
		Owner.Vel.X = stepVec.X;
		Owner.Vel.Y = stepVec.Y;
	}

	// ========================================================================
	// Triggered when `currentAmmo <= 0`:
	// ========================================================================
	void TriggerOutOfAmmoReload(bool inMissile)
	{
		if (!Owner)
			return;

		if (inMissile && Owner.SeeState)
		{
			Owner.SetState(Owner.SeeState);
		}

		if (GetCVarBool('nbc_cover_seek', true) && ClassifyCoverAt(Owner.pos.xy) == COVER_NONE)
		{
			actionCooldown = 0;
			if (TryStartDodge(true))
			{
				LogDebug("MAG EMPTY IN OPEN -> DIVING TO COVER FOR RELOAD!");
				return;
			}
		}

		StartReload();
	}

	// ========================================================================
	// RELOAD STATE:
	// ========================================================================
	void TickReload(bool inPain)
	{
		stateTimer--;
		double progress = 1.0 - (double(stateTimer) / double(max(1, stateDuration)));

		double bob = sin(progress * 540.0);
		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX * 1.06, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * (0.58 + 0.03 * abs(bob)), 0.35);
		Owner.Roll    = Lerp(Owner.Roll, bob * 5.0, 0.4);

		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;
		if ((Owner.pos.xy - duckAnchorXY).Length() > 0.1)
		{
			Owner.SetOrigin((duckAnchorXY.x, duckAnchorXY.y, Owner.pos.z), true);
		}

		if (!inPain)
		{
			Owner.tics   = 10;
			Owner.sprite = idleSprite;
			Owner.frame  = idleFrame;
		}

		if (Owner.target)
			Owner.A_FaceTarget(10);

		if (reloadStage == 1 && progress >= 0.52)
		{
			reloadStage = 2;
			Owner.A_StartSound("weapons/sshotl", CHAN_AUTO, CHANF_OVERLAP, 0.85);
		}
		else if (reloadStage == 2 && progress >= 0.84)
		{
			reloadStage = 3;
			if (isShotgunner)
				Owner.A_StartSound("en/shotpump", CHAN_AUTO, CHANF_OVERLAP, 1.0);
			else
				Owner.A_StartSound("en/mgCOCK", CHAN_AUTO, CHANF_OVERLAP, 1.0);

			Owner.sprite = aimSprite;
			Owner.frame  = aimFrame;
		}

		if (stateTimer <= 0)
		{
			int overrideShots = GetCVarInt('nbc_reload_shots', 0);
			if (overrideShots > 0)
				maxAmmo = overrideShots;

			currentAmmo = maxAmmo;
			pendingReload = false;
			Owner.Roll = 0.0;

			LogDebug(String.Format("RELOAD COMPLETE (ammo=%d/%d)", currentAmmo, maxAmmo));

			if (Owner.target && Owner.target.health > 0)
			{
				int cov = ClassifyCoverAt(Owner.pos.xy);
				if (Owner.CheckSight(Owner.target) || cov == COVER_LOW)
				{
					StartPopUp();
					return;
				}
				else if (cov == COVER_FULL && hasPeekOrigin && GetCVarBool('nbc_corner_peek', true))
				{
					StartCornerPeek();
					return;
				}
			}

			EnterNormalState();
		}
	}

	// ========================================================================
	// NORMAL STATE:
	// ========================================================================
	void TickNormal(bool inMissile, bool inPain, bool inSee)
	{
		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY, 0.35);
		Owner.Roll    = Lerp(Owner.Roll, 0.0, 0.4);

		if (!Owner.target || Owner.target.health <= 0)
			return;

		int duckChance  = GetCVarInt('nbc_duck_chance', 75);
		int dodgeChance = GetCVarInt('nbc_dodge_chance', 65);

		if (ShouldTriggerPush())
		{
			StartPush();
			return;
		}

		if (inMissile && missileTics >= maxBurstTics)
		{
			missileTics = 0;
			maxBurstTics = Random[TacAI](25, 48);

			if (ExecuteSmartCoverOrDuck(duckChance, dodgeChance, false))
				return;
		}

		if (wasInMissile && !inMissile && !inPain)
		{
			if (ExecuteSmartCoverOrDuck(duckChance, dodgeChance, false))
				return;
		}

		if (inSee && actionCooldown <= 0 && suppressedTics >= 4)
		{
			suppressedTics = 0;
			if (HandleGunfireReaction(duckChance, dodgeChance))
				return;
		}

		if (inSee && actionCooldown <= 0 && aimedAtTics >= 5)
		{
			bool playerFiring = IsPlayerFiring();

			if (playerFiring || aimedAtTics >= 8)
			{
				aimedAtTics = 0;
				if (playerFiring && HandleGunfireReaction(duckChance, dodgeChance))
					return;

				if (!ExecuteSmartCoverOrDuck(duckChance, dodgeChance, true))
				{
					actionCooldown = 20;
				}
			}
		}
	}

	bool HandleGunfireReaction(int duckChance, int dodgeChance)
	{
		if (!Owner || !Owner.target)
			return false;

		bool allowRetreat = GetCVarBool('nbc_retreat_enable', true);
		int retreatChance = GetCVarInt('nbc_retreat_chance', 55);

		if (GetCVarBool('nbc_cover_seek', true) && ClassifyCoverAt(Owner.pos.xy) == COVER_LOW)
		{
			LogDebug("UNDER GUNFIRE AT LOW WALL -> DUCK!");
			StartDuck(GetRandomizedDuckTics());
			return true;
		}

		if (GetCVarBool('nbc_cover_seek', true) && Random[TacAI](1, 100) <= dodgeChance)
		{
			if (TryStartDodge(true))
				return true;
		}

		if (allowRetreat && Random[TacAI](1, 100) <= retreatChance)
		{
			if (StartRetreat())
				return true;
		}

		return ExecuteSmartCoverOrDuck(duckChance, dodgeChance, true);
	}

	bool ExecuteSmartCoverOrDuck(int duckChance, int dodgeChance, bool preferDodge)
	{
		if (!Owner || !Owner.target)
			return false;

		bool seekCover = GetCVarBool('nbc_cover_seek', true);
		bool allowOpenDuck = GetCVarBool('nbc_open_duck', true);
		int curCover = seekCover ? ClassifyCoverAt(Owner.pos.xy) : COVER_NONE;

		if (curCover == COVER_LOW && Random[TacAI](1, 100) <= max(duckChance, 85))
		{
			LogDebug("LOW COVER DETECTED HERE -> DUCK BEHIND LEDGE");
			StartDuck(GetRandomizedDuckTics());
			return true;
		}

		if (seekCover && curCover == COVER_NONE)
		{
			if (Random[TacAI](1, 100) <= max(dodgeChance, duckChance))
			{
				if (TryStartDodge(true))
					return true;

				// Ported from Smart Marines (`SM_LocateNearbyCover`):
				// If no cover is within single-roll range, scan up to 256u and sprint to it!
				if (GetCVarBool('nbc_active_cover_run', true) && TryStartSeekCover())
					return true;
			}
		}

		if (preferDodge)
		{
			if (Random[TacAI](1, 100) <= dodgeChance && TryStartDodge(false))
				return true;
			if (allowOpenDuck && Random[TacAI](1, 100) <= duckChance)
			{
				StartDuck(GetRandomizedDuckTics());
				return true;
			}
		}
		else
		{
			if (allowOpenDuck && Random[TacAI](1, 100) <= duckChance)
			{
				StartDuck(GetRandomizedDuckTics());
				return true;
			}
			if (Random[TacAI](1, 100) <= dodgeChance && TryStartDodge(false))
				return true;
		}

		return false;
	}

	void TickRetreat(bool inMissile, bool inPain)
	{
		stateTimer--;

		// Ported from Smart Marines (`SM_Chase` / `SpriteRotation = 180`):
		// Face the rendered sprite toward the player while backing away (`bFRIGHTENED`)!
		Owner.SpriteRotation = 180.0;
		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX * 1.03, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * 0.86, 0.35);
		Owner.Roll    = Lerp(Owner.Roll, 0.0, 0.4);

		if (inMissile && stateTimer > stateDuration - 12 && Owner.SeeState)
		{
			Owner.SetState(Owner.SeeState);
		}

		if (stateTimer % 4 == 0 && GetCVarBool('nbc_cover_seek', true))
		{
			int cov = ClassifyCoverAt(Owner.pos.xy);
			if (cov == COVER_FULL && GetCVarBool('nbc_corner_peek', true))
			{
				LogDebug("RETREAT REACHED WALL CORNER -> CORNER HIDE!");
				RestoreStandingProperties(true);
				StartCornerHide(GetRandomizedDuckTics());
				return;
			}
			else if (cov == COVER_LOW)
			{
				LogDebug("RETREAT REACHED LOW LEDGE -> DUCK IN COVER!");
				RestoreStandingProperties(true);
				StartDuck(GetRandomizedDuckTics());
				return;
			}
		}

		if (ShouldTriggerPush())
		{
			RestoreStandingProperties(true);
			StartPush();
			return;
		}

		if (stateTimer <= 0)
		{
			EnterNormalState();
		}
	}

	void TickPush(bool inMissile, bool inPain)
	{
		stateTimer--;

		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY, 0.35);
		Owner.Roll    = Lerp(Owner.Roll, 0.0, 0.4);

		if (!Owner.target || Owner.target.health <= 0)
		{
			EnterNormalState();
			return;
		}

		bool hasSight = Owner.CheckSight(Owner.target);
		bool playerFiring = IsPlayerFiring();

		if ((hasSight && playerFiring) || suppressedTics >= 3)
		{
			LogDebug("PUSH ABORTED -> PLAYER OPENED FIRE!");
			suppressedTics = 0;
			RestoreStandingProperties(true);
			int duckChance  = GetCVarInt('nbc_duck_chance', 75);
			int dodgeChance = GetCVarInt('nbc_dodge_chance', 65);
			if (!HandleGunfireReaction(duckChance, dodgeChance))
			{
				EnterNormalState();
			}
			return;
		}

		if (hasSight)
		{
			pushSightRegainedTics++;
			if (pushSightRegainedTics >= 6)
			{
				LogDebug("PUSH REGAINED SIGHT -> ENGAGING TARGET!");
				RestoreStandingProperties(true);
				StartPopUp();
				return;
			}
		}
		else
		{
			pushSightRegainedTics = 0;
		}

		if (stateTimer <= 0)
		{
			LogDebug("PUSH COMPLETE -> NORMAL");
			EnterNormalState();
		}
	}

	void TickDuck(bool inPain)
	{
		stateTimer--;

		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX * 1.07, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * 0.58, 0.35);
		Owner.Roll    = Lerp(Owner.Roll, 0.0, 0.4);

		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;
		if ((Owner.pos.xy - duckAnchorXY).Length() > 0.1)
		{
			Owner.SetOrigin((duckAnchorXY.x, duckAnchorXY.y, Owner.pos.z), true);
		}

		if (!inPain)
		{
			Owner.tics   = 10;
			Owner.sprite = aimSprite;
			Owner.frame  = aimFrame;
		}

		if (Owner.target)
			Owner.A_FaceTarget(12);

		if (GetCVarBool('nbc_reload_enable', true) && currentAmmo <= max(1, maxAmmo / 4))
		{
			LogDebug("LOW AMMO WHILE DUCKED -> TACTICAL RELOAD!");
			StartReload();
			return;
		}

		if (ShouldTriggerPush())
		{
			RestoreStandingProperties(true);
			StartPush();
			return;
		}

		if (stateTimer <= 0)
		{
			if (Owner.target && Owner.target.health > 0)
			{
				int cov = ClassifyCoverAt(Owner.pos.xy);
				if (Owner.CheckSight(Owner.target) || cov == COVER_LOW)
				{
					bool allowCrouchFire = GetCVarBool('nbc_crouch_fire', true);
					if (allowCrouchFire && cov == COVER_NONE && Owner.MissileState && Random[TacAI](1, 100) <= 28)
					{
						StartCrouchFire();
						Owner.SetState(Owner.MissileState);
					}
					else
					{
						StartPopUp();
					}
					return;
				}
			}

			EnterNormalState();
		}
	}

	void TickPopUp(bool inPain)
	{
		stateTimer--;

		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX, 0.45);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY, 0.45);
		Owner.Roll    = Lerp(Owner.Roll, 0.0, 0.5);

		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;

		if (Owner.target)
			Owner.A_FaceTarget(20);

		if (!inPain)
		{
			Owner.tics   = 10;
			Owner.sprite = aimSprite;
			Owner.frame  = aimFrame;
		}

		if (stateTimer <= 0)
		{
			EnterNormalState();
			actionCooldown = Random[TacAI](25, 45);

			if (Owner.MissileState && Owner.target && Owner.target.health > 0 && Owner.CheckSight(Owner.target))
			{
				missileTics = 0;
				maxBurstTics = Random[TacAI](24, 42);
				Owner.SetState(Owner.MissileState);
			}
		}
	}

	void TickCrouchFire(bool inMissile, bool inPain)
	{
		stateTimer--;

		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX * 1.06, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * 0.62, 0.35);
		Owner.Roll    = 0.0;

		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;

		if (!inMissile || stateTimer <= 0 || inPain)
		{
			if (!inPain && Random[TacAI](1, 100) <= 50)
			{
				StartDuck(max(12, GetRandomizedDuckTics() / 2));
			}
			else
			{
				EnterNormalState();
				if (Owner.SeeState && inMissile)
					Owner.SetState(Owner.SeeState);
			}
		}
	}

	void TickDodgeStrafe(bool inPain)
	{
		stateTimer--;
		double progress = 1.0 - (double(stateTimer) / double(max(1, stateDuration)));

		if (!inPain)
		{
			Owner.tics = 10;
		}

		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX * 1.05, 0.4);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * 0.80, 0.4);

		double targetRoll = lastDodgeSign * 14.0 * sin(progress * 180.0);
		Owner.Roll = Lerp(Owner.Roll, targetRoll, 0.5);

		if (progress < 0.70)
		{
			Vector2 dir = Actor.AngleToVector(dodgeAngle, dodgeSpeed);
			Owner.Vel.X = dir.X;
			Owner.Vel.Y = dir.Y;
		}
		else
		{
			Owner.Vel.X *= 0.72;
			Owner.Vel.Y *= 0.72;
		}

		if (Owner.target)
			Owner.A_FaceTarget(15);

		if (!didMidDodgeShot && progress >= 0.45 && progress <= 0.65 &&
		    GetCVarBool('nbc_dodge_attack', true))
		{
			TryFireMidDodgeSnapShot();
		}

		if (stateTimer <= 0)
		{
			double movedDist = (Owner.pos.xy - dodgeStartXY).Length();
			LogDebug(String.Format("STRAFE END (measured dist=%.1f units over %d tics @ %.1f u/tic)", movedDist, stateDuration, dodgeSpeed));
			FinishDodge();
		}
	}

	void TickDodgeRoll(bool inPain)
	{
		stateTimer--;
		double progress = 1.0 - (double(stateTimer) / double(max(1, stateDuration)));

		if (!inPain)
		{
			Owner.tics   = 10;
			Owner.sprite = aimSprite;
			Owner.frame  = aimFrame;
		}

		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX * 0.95, 0.4);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * 0.65, 0.4);

		Owner.Roll = lastDodgeSign * (progress * 360.0);

		if (progress < 0.75)
		{
			Vector2 dir = Actor.AngleToVector(dodgeAngle, dodgeSpeed);
			Owner.Vel.X = dir.X;
			Owner.Vel.Y = dir.Y;
		}
		else
		{
			Owner.Vel.X *= 0.68;
			Owner.Vel.Y *= 0.68;
		}

		if (Owner.target)
			Owner.A_FaceTarget(15);

		if (!didMidDodgeShot && progress >= 0.48 && progress <= 0.68 &&
		    GetCVarBool('nbc_dodge_attack', true))
		{
			TryFireMidDodgeSnapShot();
		}

		if (stateTimer <= 0)
		{
			Owner.Roll = 0.0;
			double movedDist = (Owner.pos.xy - dodgeStartXY).Length();
			LogDebug(String.Format("ROLL END (measured dist=%.1f units over %d tics @ %.1f u/tic)", movedDist, stateDuration, dodgeSpeed));
			FinishDodge();
		}
	}

	void TickCornerHide(bool inPain)
	{
		stateTimer--;

		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX * 1.06, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * 0.62, 0.35);
		Owner.Roll    = Lerp(Owner.Roll, 0.0, 0.4);

		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;
		if ((Owner.pos.xy - duckAnchorXY).Length() > 0.1)
		{
			Owner.SetOrigin((duckAnchorXY.x, duckAnchorXY.y, Owner.pos.z), true);
		}

		if (!inPain)
		{
			Owner.tics   = 10;
			Owner.sprite = aimSprite;
			Owner.frame  = aimFrame;
		}

		if (Owner.target)
			Owner.A_FaceTarget(15);

		if (GetCVarBool('nbc_reload_enable', true) && currentAmmo <= max(1, maxAmmo / 3))
		{
			LogDebug("LOW AMMO BEHIND CORNER -> TACTICAL RELOAD!");
			StartReload();
			return;
		}

		if (stateTimer > 6 && Owner.target && Owner.CheckSight(Owner.target))
		{
			LogDebug("PLAYER FLANKED CORNER -> POP UP!");
			StartPopUp();
			return;
		}

		if (stateTimer <= 0)
		{
			if (hasPeekOrigin && Owner.target && Owner.target.health > 0 && GetCVarBool('nbc_corner_peek', true))
			{
				StartCornerPeek();
			}
			else if (ShouldTriggerPush())
			{
				RestoreStandingProperties(true);
				StartPush();
			}
			else
			{
				EnterNormalState();
			}
		}
	}

	void TickCornerPeek(bool inPain)
	{
		stateTimer--;

		if (!inPain)
		{
			Owner.tics   = 10;
			Owner.sprite = aimSprite;
			Owner.frame  = aimFrame;
		}

		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * 0.88, 0.35);
		Owner.Roll    = Lerp(Owner.Roll, -peekSign * 10.0, 0.4);

		Vector2 toPeek = peekOriginXY - Owner.pos.xy;
		double distToPeek = toPeek.Length();

		if (distToPeek > 6.0)
		{
			double peekSpd = max(3.0, GetCVarFloat('nbc_strafe_speed', 6.5) * 0.85);
			Vector2 stepVel = (toPeek / distToPeek) * min(peekSpd, distToPeek);
			Owner.Vel.X = stepVel.X;
			Owner.Vel.Y = stepVel.Y;
		}
		else
		{
			Owner.Vel.X = 0.0;
			Owner.Vel.Y = 0.0;
		}

		if (Owner.target)
			Owner.A_FaceTarget(20);

		int elapsed = stateDuration - stateTimer;
		if (elapsed >= 4 && Owner.target && Owner.CheckSight(Owner.target))
		{
			Owner.Vel.X = 0.0;
			Owner.Vel.Y = 0.0;
			Owner.Roll  = 0.0;
			LogDebug("CORNER PEEK CLEARED EDGE -> OPEN FIRE!");
			StartPopUp();
			return;
		}

		if (stateTimer <= 0 || distToPeek <= 6.0)
		{
			Owner.Vel.X = 0.0;
			Owner.Vel.Y = 0.0;
			Owner.Roll  = 0.0;
			if (Owner.target && Owner.CheckSight(Owner.target))
			{
				StartPopUp();
			}
			else if (ShouldTriggerPush())
			{
				RestoreStandingProperties(true);
				StartPush();
			}
			else
			{
				EnterNormalState();
			}
		}
	}

	// ========================================================================
	// State Transitions & Cover Evaluation Helpers
	// ========================================================================
	int GetRandomizedDuckTics()
	{
		int baseTics = max(8, GetCVarInt('nbc_duck_tics', 40));
		int variance = max(2, baseTics / 4);
		return baseTics + Random[TacAI](-variance, variance);
	}

	bool ShouldTriggerPush()
	{
		if (!Owner || !Owner.target || Owner.target.health <= 0)
			return false;

		if (!GetCVarBool('nbc_push_enable', true))
			return false;

		int delayTics = max(10, GetCVarInt('nbc_push_delay_tics', 35));
		return (outOfSightTics >= delayTics && playerSilentTics >= delayTics);
	}

	void StartReload()
	{
		if (!Owner)
			return;

		int relTics = max(15, GetCVarInt('nbc_reload_tics', 52));
		tacState = TSTATE_RELOAD;
		stateDuration = relTics;
		stateTimer = relTics;
		reloadStage = 1;
		pendingReload = false;
		actionCooldown = relTics + Random[TacAI](15, 25);

		duckAnchorXY = Owner.pos.xy;
		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;

		Owner.A_SetSize(baseRadius, baseHeight * 0.50, false);
		Owner.Speed = 0;

		if (Owner.SeeState)
		{
			Owner.SetState(Owner.SeeState);
		}
		Owner.tics   = 10;
		Owner.sprite = idleSprite;
		Owner.frame  = idleFrame;

		Owner.A_StartSound("weapons/sshoto", CHAN_AUTO, CHANF_OVERLAP, 0.85);
		Vector3 magPos = Owner.pos + (0, 0, baseHeight * 0.38);
		Actor mag = Actor.Spawn("TacticalSpentMag", magPos, ALLOW_REPLACE);
		if (mag)
		{
			double ejectAng = Owner.angle + Random[TacAI](65, 115);
			Vector2 ejectVel = Actor.AngleToVector(ejectAng, Random[TacAI](2, 4));
			mag.Vel = (ejectVel.x, ejectVel.y, 3.0);
		}

		LogDebug(String.Format("RELOAD START (duration=%d tics / %.2fs, refilling %d rounds)",
			relTics, relTics / 35.0, maxAmmo));
	}

	bool StartRetreat()
	{
		if (!Owner || !Owner.target)
			return false;

		double awayAng = Owner.AngleTo(Owner.target) + 180.0;
		double backAng = awayAng + Random[TacAI](-35, 35);
		if (!IsDirectionClear(backAng, 36.0) && !IsDirectionClear(awayAng + 65.0, 36.0) && !IsDirectionClear(awayAng - 65.0, 36.0))
			return false;

		int retTics = max(15, GetCVarInt('nbc_retreat_tics', 45));
		double retMult = max(1.0, GetCVarFloat('nbc_retreat_speed', 1.35));

		RestoreStandingProperties(true);
		tacState = TSTATE_RETREAT;
		stateDuration = retTics;
		stateTimer = retTics;
		actionCooldown = retTics + Random[TacAI](15, 30);

		Owner.bFRIGHTENED = true;
		Owner.SpriteRotation = 180.0;
		Owner.Speed = baseSpeed * retMult;

		Vector2 stepAway = Actor.AngleToVector(backAng, 4.5);
		Owner.Vel.X = stepAway.X;
		Owner.Vel.Y = stepAway.Y;

		if (Owner.SeeState && Owner.InStateSequence(Owner.CurState, Owner.MissileState))
		{
			Owner.SetState(Owner.SeeState);
		}

		LogDebug(String.Format("RETREAT UNDER GUNFIRE (speed=%.2fx, duration=%d tics)", retMult, retTics));
		return true;
	}

	void StartPush()
	{
		if (!Owner || !Owner.target)
			return;

		int pushTics = max(25, GetCVarInt('nbc_push_tics', 85));
		double pushMult = max(1.0, GetCVarFloat('nbc_push_speed', 1.45));

		RestoreStandingProperties(true);
		tacState = TSTATE_PUSH;
		stateDuration = pushTics;
		stateTimer = pushTics;
		pushSightRegainedTics = 0;
		outOfSightTics = 0;
		actionCooldown = 35;

		Owner.bFRIGHTENED = false;
		Owner.Speed = baseSpeed * pushMult;

		if (Owner.SeeState && !Owner.InStateSequence(Owner.CurState, Owner.SeeState))
		{
			Owner.SetState(Owner.SeeState);
		}

		LogDebug(String.Format("PUSHING SILENT/HIDDEN PLAYER (speed=%.2fx, max=%d tics)", pushMult, pushTics));
	}

	void StartDuck(int duration)
	{
		if (!Owner)
			return;

		tacState = TSTATE_DUCK;
		stateDuration = duration;
		stateTimer = duration;
		actionCooldown = duration + Random[TacAI](15, 30);

		duckAnchorXY = Owner.pos.xy;
		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;

		Owner.A_SetSize(baseRadius, baseHeight * 0.50, false);
		Owner.Speed = 0;

		if (Owner.SeeState)
		{
			Owner.SetState(Owner.SeeState);
		}
		Owner.tics   = 10;
		Owner.sprite = aimSprite;
		Owner.frame  = aimFrame;

		int cov = ClassifyCoverAt(Owner.pos.xy);
		String covStr = (cov == COVER_LOW) ? "LOW-WALL COVER" : ((cov == COVER_FULL) ? "FULL COVER" : "OPEN GROUND");
		LogDebug(String.Format("DUCK START [%s] (duration=%d tics / %.2fs)", covStr, duration, duration / 35.0));
	}

	void StartCornerHide(int duration)
	{
		if (!Owner)
			return;

		tacState = TSTATE_CORNER_HIDE;
		stateDuration = duration;
		stateTimer = duration;
		actionCooldown = duration + Random[TacAI](20, 35);

		duckAnchorXY = Owner.pos.xy;
		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;

		Owner.A_SetSize(baseRadius, baseHeight * 0.55, false);
		Owner.Speed = 0;

		if (Owner.SeeState)
		{
			Owner.SetState(Owner.SeeState);
		}
		Owner.tics   = 10;
		Owner.sprite = aimSprite;
		Owner.frame  = aimFrame;

		LogDebug(String.Format("CORNER HIDE BEHIND WALL (duration=%d tics / %.2fs)", duration, duration / 35.0));
	}

	void StartCornerPeek()
	{
		if (!Owner)
			return;

		RestoreStandingProperties(true);
		int strafeTics = max(10, GetCVarInt('nbc_strafe_tics', 18) + 6);
		tacState = TSTATE_CORNER_PEEK;
		stateDuration = strafeTics;
		stateTimer = strafeTics;
		Owner.Speed = 0;
		Owner.tics  = 10;

		LogDebug("CORNER PEEK OUT -> STEPPING TO FIRING EDGE");
	}

	void StartPopUp()
	{
		if (!Owner)
			return;

		RestoreStandingProperties(true);
		tacState = TSTATE_POPUP;
		stateDuration = 9;
		stateTimer = 9;
		Owner.Speed = 0;
		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;
		Owner.tics  = 10;

		if (GetCVarBool('nbc_telegraph_flash', true))
		{
			Vector3 glintPos = Owner.pos + (0, 0, baseHeight * 0.68);
			Actor.Spawn("TacticalTelegraphGlint", glintPos, ALLOW_REPLACE);
		}

		LogDebug(String.Format("POP-UP -> AIM (ammo=%d/%d)", currentAmmo, maxAmmo));
	}

	void StartCrouchFire()
	{
		if (!Owner)
			return;

		tacState = TSTATE_CROUCH_FIRE;
		stateDuration = Random[TacAI](22, 36);
		stateTimer = stateDuration;
		actionCooldown = stateDuration + Random[TacAI](20, 35);

		duckAnchorXY = Owner.pos.xy;
		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;
		Owner.A_SetSize(baseRadius, baseHeight * 0.52, false);
		Owner.Speed = 0;

		if (GetCVarBool('nbc_telegraph_flash', true))
		{
			Vector3 glintPos = Owner.pos + (0, 0, baseHeight * 0.42);
			Actor.Spawn("TacticalTelegraphGlint", glintPos, ALLOW_REPLACE);
		}

		LogDebug(String.Format("CROUCH-FIRE (ammo=%d/%d)", currentAmmo, maxAmmo));
	}

	bool TryStartDodge(bool requireCoverHit = false)
	{
		if (!Owner || !Owner.target || actionCooldown > 0)
			return false;

		bool allowRoll = GetCVarBool('nbc_roll_enable', true);
		bool doRoll = allowRoll && (Random[TacAI](1, 100) <= 45);

		int rollTics     = max(6, GetCVarInt('nbc_roll_tics', 24));
		double rollSpd   = max(0.5, GetCVarFloat('nbc_roll_speed', 6.0));
		int strafeTics   = max(6, GetCVarInt('nbc_strafe_tics', 18));
		double strafeSpd = max(0.5, GetCVarFloat('nbc_strafe_speed', 6.5));

		double estDist = doRoll ? (rollSpd * rollTics * 0.78) : (strafeSpd * strafeTics * 0.75);
		double maxSearch = max(48.0, double(GetCVarInt('nbc_cover_search_dist', 128)));
		double testDist = clamp(estDist, 48.0, maxSearch);

		double angToTarget = Owner.AngleTo(Owner.target);
		bool seekCover = GetCVarBool('nbc_cover_seek', true);

		static const double relAngles[] = { 90.0, -90.0, 68.0, -68.0, 112.0, -112.0 };

		double bestAngle = 0.0;
		int bestScore = -1;
		int bestSign = lastDodgeSign;
		int bestCoverType = COVER_NONE;

		for (int i = 0; i < 6; i++)
		{
			double rel = relAngles[i];
			int sign = (rel >= 0) ? 1 : -1;
			double candAng = angToTarget + rel;

			if (!IsDirectionClear(candAng, testDist))
				continue;

			Vector2 destXY = Owner.pos.xy + Actor.AngleToVector(candAng, testDist);
			int score = 10;
			int cov = COVER_NONE;

			if (seekCover)
			{
				cov = ClassifyCoverAt(destXY);
				if (cov == COVER_FULL)
				{
					score += 100;
				}
				else if (cov == COVER_LOW)
				{
					score += 80;
				}
				else
				{
					score += GetWallProximityScore(destXY);
				}
			}

			if (sign == -lastDodgeSign)
				score += 5;

			if (score > bestScore)
			{
				bestScore = score;
				bestAngle = candAng;
				bestSign  = sign;
				bestCoverType = cov;
			}
		}

		if (requireCoverHit && bestCoverType == COVER_NONE)
			return false;

		if (bestScore < 0)
		{
			if (!requireCoverHit && GetCVarBool('nbc_open_duck', true))
			{
				StartDuck(GetRandomizedDuckTics());
				return true;
			}
			return false;
		}

		hasPeekOrigin = Owner.CheckSight(Owner.target);
		if (hasPeekOrigin)
		{
			peekOriginXY = Owner.pos.xy;
			peekSign = bestSign;
		}

		dodgeAngle = bestAngle;
		lastDodgeSign = bestSign;
		dodgeStartXY = Owner.pos.xy;
		didMidDodgeShot = false;

		if (Owner.SeeState)
		{
			Owner.SetState(Owner.SeeState);
		}

		String covLabel = (bestCoverType == COVER_FULL) ? "-> WALL CORNER" :
		                  ((bestCoverType == COVER_LOW) ? "-> LOW COVER" : "-> EVADE");

		if (allowRoll && (bestCoverType != COVER_NONE) && Random[TacAI](1, 100) <= 70)
		{
			doRoll = true;
		}

		if (doRoll)
		{
			tacState = TSTATE_DODGE_ROLL;
			stateDuration = rollTics;
			stateTimer = rollTics;
			dodgeSpeed = rollSpd;
			Owner.A_SetSize(baseRadius, baseHeight * 0.50, false);
			if (Owner.pos.z <= Owner.floorz + 1.0)
				Owner.Vel.Z = max(Owner.Vel.Z, 2.2);

			LogDebug(String.Format("ROLL START %s (speed=%.1f u/tic, %d tics / %.2fs)",
				covLabel, rollSpd, rollTics, rollTics / 35.0));
		}
		else
		{
			tacState = TSTATE_DODGE_STRAFE;
			stateDuration = strafeTics;
			stateTimer = strafeTics;
			dodgeSpeed = strafeSpd;
			Owner.A_SetSize(baseRadius, baseHeight * 0.68, false);

			LogDebug(String.Format("STRAFE START %s (speed=%.1f u/tic, %d tics / %.2fs)",
				covLabel, strafeSpd, strafeTics, strafeTics / 35.0));
		}

		Owner.Speed = 0;
		Owner.tics  = 10;
		actionCooldown = stateDuration + Random[TacAI](25, 45);
		return true;
	}

	void FinishDodge()
	{
		if (!Owner)
			return;

		Owner.Roll  = 0.0;
		Owner.Vel.X = 0.0;
		Owner.Vel.Y = 0.0;

		if (pendingBarrelFlee && hazardBarrel)
		{
			StartBarrelFlee();
			return;
		}

		if (pendingReload)
		{
			StartReload();
			return;
		}

		if (Owner.target && Owner.target.health > 0)
		{
			int landedCover = ClassifyCoverAt(Owner.pos.xy);

			if (landedCover == COVER_FULL && GetCVarBool('nbc_corner_peek', true))
			{
				StartCornerHide(GetRandomizedDuckTics());
				return;
			}

			if (landedCover == COVER_LOW)
			{
				StartDuck(GetRandomizedDuckTics());
				return;
			}

			if (Owner.CheckSight(Owner.target))
			{
				int postChoice = Random[TacAI](1, 100);
				if (GetCVarBool('nbc_open_duck', true) && postChoice <= 40)
				{
					StartDuck(max(14, GetRandomizedDuckTics() / 2));
					return;
				}
				else if (postChoice <= 85)
				{
					StartPopUp();
					return;
				}
			}
		}

		EnterNormalState();
	}

	void EnterNormalState()
	{
		tacState = TSTATE_NORMAL;
		stateTimer = 0;
		RestoreStandingProperties(true);
		if (Owner && Owner.SeeState && !Owner.InStateSequence(Owner.CurState, Owner.MissileState))
		{
			Owner.SetState(Owner.SeeState);
		}
	}

	void RestoreStandingProperties(bool checkCeiling)
	{
		if (!Owner)
			return;

		if (!checkCeiling || Owner.A_SetSize(baseRadius, baseHeight, true))
		{
			Owner.A_SetSize(baseRadius, baseHeight, false);
		}

		Owner.Speed          = baseSpeed;
		Owner.bFRIGHTENED    = baseFrightened;
		Owner.SpriteRotation = 0.0;
		Owner.Roll           = 0.0;
		Owner.Scale.X        = baseScaleX;
		Owner.Scale.Y        = baseScaleY;
	}

	void NotifyDamaged(Actor source, int dmg)
	{
		if (!Owner || Owner.health <= 0 || actionCooldown > 10 ||
		    tacState == TSTATE_RELOAD || tacState == TSTATE_BARREL_FLEE)
			return;

		int dodgeChance = GetCVarInt('nbc_dodge_chance', 65);
		int duckChance  = GetCVarInt('nbc_duck_chance', 75);
		if ((tacState == TSTATE_NORMAL || tacState == TSTATE_PUSH) && Random[TacAI](1, 100) <= max(dodgeChance, 75))
		{
			actionCooldown = 0;
			HandleGunfireReaction(duckChance, dodgeChance);
		}
	}

	void NotifyNearGunfire(Vector3 impactPos, double dist)
	{
		if (!Owner || Owner.health <= 0 || !Owner.target)
			return;

		playerSilentTics = 0;
		suppressedTics = min(20, suppressedTics + 6);
	}

	// ========================================================================
	// Ported KAI & Smart Marines Mechanics:
	//  1. 3D Projectile Trajectory Dodging (`SM_ShouldDodgeProjectile` + `Distance3DLine`)
	//  2. Mid-Dodge Snap-Shot Attack (`Jump.Dodge.Attack`)
	//  3. Active Cover Pathing up to 256u (`SM_LocateNearbyCover` / `TSTATE_SEEK_COVER`)
	// ========================================================================
	static double Distance3DLine(Vector3 p, Vector3 a, Vector3 b)
	{
		Vector3 ab = b - a;
		double abLenSq = ab dot ab;
		if (abLenSq < 0.0001)
			return (p - a).Length();

		double t = ((p - a) dot ab) / abLenSq;
		t = clamp(t, 0.0, 1.0);
		Vector3 closest = a + ab * t;
		return (p - closest).Length();
	}

	Actor FindIncomingProjectileThreat()
	{
		if (!Owner)
			return null;

		let handler = TacticalAIEventHandler(EventHandler.Find("TacticalAIEventHandler"));
		if (!handler)
			return null;

		double maxRange = max(96.0, double(GetCVarInt('nbc_proj_dodge_range', 384)));
		double maxRangeSq = maxRange * maxRange;
		Vector3 myCenter = Owner.pos + (0, 0, Owner.Height * 0.5);

		for (int i = handler.ActiveProjectiles.Size() - 1; i >= 0; i--)
		{
			Actor proj = handler.ActiveProjectiles[i];
			if (!proj || !proj.bMISSILE || proj.target == Owner)
				continue;

			// Ignore friendly projectiles fired by other monsters unless targeting us
			if (proj.target && proj.target.bISMONSTER && proj.target != Owner.target)
				continue;

			double velLen = proj.Vel.Length();
			if (velLen < 1.0)
				continue;

			Vector3 toProj = Level.Vec3Diff(myCenter, proj.pos);
			double distSq = toProj.LengthSquared();
			if (distSq > maxRangeSq || distSq < 16.0)
				continue;

			// Projectile must be flying toward our position (dot < -0.15)
			Vector3 toProjDir = toProj.Unit();
			Vector3 velDir = proj.Vel / velLen;
			if ((toProjDir dot velDir) > -0.15)
				continue;

			// Ported from Smart Marines (`SM_ShouldDodgeProjectile` / `KAI_Math.distance3dline`):
			// Compute closest distance from our 3D center to the projectile's trajectory segment
			double segLen = max(distSq > 0 ? sqrt(distSq) * 1.25 : 128.0, velLen * 12.0);
			Vector3 segEnd = proj.pos + velDir * segLen;
			double lineDist = Distance3DLine(myCenter, proj.pos, segEnd);
			double safeRadius = proj.Radius + Owner.Radius + 24.0;

			if (lineDist <= safeRadius && Owner.CheckSight(proj))
			{
				return proj;
			}
		}

		return null;
	}

	bool TryDodgeProjectile(Actor proj)
	{
		if (!Owner || !proj)
			return false;

		int dodgeChance = GetCVarInt('nbc_dodge_chance', 65);
		if (Random[TacAI](1, 100) > max(dodgeChance, 75))
		{
			actionCooldown = 14;
			return false;
		}

		// If already standing behind waist-high cover (`COVER_LOW`), duck immediately so the projectile flies overhead!
		if (GetCVarBool('nbc_cover_seek', true) && ClassifyCoverAt(Owner.pos.xy) == COVER_LOW)
		{
			LogDebug(String.Format("INCOMING PROJECTILE (%s) AT LOW COVER -> DUCK UNDER IT!", proj.GetClassName()));
			StartDuck(GetRandomizedDuckTics());
			return true;
		}

		// Ported from Smart Marines (`SM_HandleDodging`):
		// Choose the perpendicular evade direction away from the side the projectile is passing on
		double projAng = VectorAngle(proj.Vel.X, proj.Vel.Y);
		double projOppositeAng = projAng + 180.0;
		double angToProj = Owner.AngleTo(proj);
		double delta = Actor.DeltaAngle(projOppositeAng, angToProj);

		double prefSign = (delta >= 0.0) ? -1.0 : 1.0;
		double candAng1 = projOppositeAng + (prefSign * 90.0);
		double candAng2 = projOppositeAng - (prefSign * 90.0);

		bool allowRoll = GetCVarBool('nbc_roll_enable', true);
		bool doRoll = allowRoll && (Random[TacAI](1, 100) <= 60);

		int rollTics     = max(6, GetCVarInt('nbc_roll_tics', 24));
		double rollSpd   = max(0.5, GetCVarFloat('nbc_roll_speed', 6.0));
		int strafeTics   = max(6, GetCVarInt('nbc_strafe_tics', 18));
		double strafeSpd = max(0.5, GetCVarFloat('nbc_strafe_speed', 6.5));
		double testDist  = clamp(doRoll ? (rollSpd * rollTics * 0.72) : (strafeSpd * strafeTics * 0.70), 44.0, 112.0);

		double chosenAng = 0.0;
		int chosenSign = int(prefSign);
		bool foundClear = false;

		if (IsDirectionClear(candAng1, testDist))
		{
			chosenAng = candAng1;
			chosenSign = int(prefSign);
			foundClear = true;
		}
		else if (IsDirectionClear(candAng2, testDist))
		{
			chosenAng = candAng2;
			chosenSign = int(-prefSign);
			foundClear = true;
		}

		if (!foundClear)
		{
			// If boxed in laterally and projectile is flying high enough, emergency duck!
			if (proj.pos.z > Owner.pos.z + baseHeight * 0.48)
			{
				LogDebug("INCOMING HIGH PROJECTILE & BOXED IN -> EMERGENCY DUCK!");
				StartDuck(max(16, GetRandomizedDuckTics() / 2));
				return true;
			}
			return false;
		}

		RestoreStandingProperties(true);
		if (Owner.SeeState)
			Owner.SetState(Owner.SeeState);

		dodgeAngle = chosenAng;
		lastDodgeSign = chosenSign;
		dodgeStartXY = Owner.pos.xy;
		didMidDodgeShot = false;

		if (doRoll)
		{
			tacState = TSTATE_DODGE_ROLL;
			stateDuration = rollTics;
			stateTimer = rollTics;
			dodgeSpeed = rollSpd;
			Owner.A_SetSize(baseRadius, baseHeight * 0.50, false);
			if (Owner.pos.z <= Owner.floorz + 1.0)
				Owner.Vel.Z = max(Owner.Vel.Z, 2.4);
		}
		else
		{
			tacState = TSTATE_DODGE_STRAFE;
			stateDuration = strafeTics;
			stateTimer = strafeTics;
			dodgeSpeed = strafeSpd;
			Owner.A_SetSize(baseRadius, baseHeight * 0.68, false);
		}

		Owner.Speed = 0;
		Owner.tics  = 10;
		actionCooldown = stateDuration + Random[TacAI](18, 32);

		LogDebug(String.Format("3D PROJECTILE DODGE (%s) -> %s!",
			proj.GetClassName(), doRoll ? "DIVE-ROLL" : "STRAFE-DASH"));
		return true;
	}

	void TryFireMidDodgeSnapShot()
	{
		didMidDodgeShot = true;
		if (!Owner || !Owner.target || Owner.target.health <= 0)
			return;

		if (pendingReload || (GetCVarBool('nbc_reload_enable', true) && currentAmmo <= 0))
			return;

		if (Random[TacAI](1, 100) > 65 || !Owner.CheckSight(Owner.target))
			return;

		Name projType = (cachedProjectileClass != 'None') ? cachedProjectileClass : 'DoomImpBall';
		if (Class<Actor>(projType) == null)
			return;

		Owner.A_FaceTarget(25);
		Actor shot = Owner.A_SpawnProjectile(projType, Owner.Height * 0.55, 0, Random[TacAI](-4, 4), CMF_AIMOFFSET);
		if (shot)
		{
			if (Owner.AttackSound)
				Owner.A_StartSound(Owner.AttackSound, CHAN_WEAPON, CHANF_OVERLAP, 0.9);
			LogDebug(String.Format("MID-DODGE SNAP-SHOT (%s)!", projType));
		}
	}

	// ========================================================================
	// Active Cover Pathing (`SM_LocateNearbyCover` -> `TSTATE_SEEK_COVER`):
	// When an enemy is in the open and no cover is within single-roll distance,
	// scan forward and laterally up to 256 map units for a reachable cover spot
	// (`COVER_LOW` or `COVER_FULL`) and sprint directly to it!
	// ========================================================================
	bool TryStartSeekCover()
	{
		if (!Owner || !Owner.target || actionCooldown > 0)
			return false;

		double angToTarget = Owner.AngleTo(Owner.target);
		static const double scanAngles[] = { 90.0, -90.0, 55.0, -55.0, 0.0, 125.0, -125.0 };
		static const double scanDists[]  = { 96.0, 144.0, 192.0, 248.0 };

		Vector2 bestSpot = (0, 0);
		int bestType = COVER_NONE;
		int bestScore = -1;

		for (int d = 0; d < 4; d++)
		{
			double dist = scanDists[d];
			for (int a = 0; a < 7; a++)
			{
				double candAng = angToTarget + scanAngles[a];
				if (!IsDirectionClear(candAng, dist))
					continue;

				Vector2 candXY = Owner.pos.xy + Actor.AngleToVector(candAng, dist);
				int cov = ClassifyCoverAt(candXY);
				if (cov == COVER_NONE)
					continue;

				// Prefer closer cover and waist-high ledges (`COVER_LOW`) or corners (`COVER_FULL`)
				int score = (cov == COVER_LOW ? 110 : 95) - int(dist * 0.25);
				if (score > bestScore)
				{
					bestScore = score;
					bestSpot  = candXY;
					bestType  = cov;
				}
			}
		}

		if (bestType == COVER_NONE)
			return false;

		RestoreStandingProperties(true);
		hasPeekOrigin = Owner.CheckSight(Owner.target);
		if (hasPeekOrigin)
		{
			peekOriginXY = Owner.pos.xy;
			double relAng = Actor.DeltaAngle(angToTarget, VectorAngle(bestSpot.x - Owner.pos.x, bestSpot.y - Owner.pos.y));
			peekSign = (relAng >= 0.0) ? 1 : -1;
		}

		coverGoalXY   = bestSpot;
		coverGoalType = bestType;
		tacState      = TSTATE_SEEK_COVER;
		stateDuration = 55;
		stateTimer    = 55;
		actionCooldown = 50;

		Owner.Speed = 0;
		if (Owner.SeeState && !Owner.InStateSequence(Owner.CurState, Owner.SeeState))
			Owner.SetState(Owner.SeeState);
		Owner.tics = 10;

		double goalDist = (coverGoalXY - Owner.pos.xy).Length();
		LogDebug(String.Format("SPRINTING TO DISTANT %s COVER (%.0f units away)",
			bestType == COVER_LOW ? "LOW-WALL" : "CORNER", goalDist));
		return true;
	}

	void TickSeekCover(bool inMissile, bool inPain)
	{
		stateTimer--;

		Owner.Scale.X = Lerp(Owner.Scale.X, baseScaleX * 1.04, 0.35);
		Owner.Scale.Y = Lerp(Owner.Scale.Y, baseScaleY * 0.88, 0.35);
		Owner.Roll    = Lerp(Owner.Roll, 0.0, 0.4);

		if (!inPain)
		{
			Owner.tics   = 10;
			Owner.sprite = idleSprite;
			Owner.frame  = (stateTimer / 3) & 3;
		}

		Vector2 toGoal = coverGoalXY - Owner.pos.xy;
		double dist = toGoal.Length();
		int curCov = ClassifyCoverAt(Owner.pos.xy);

		// Arrived at cover goal or entered valid cover along the way!
		if (dist <= 22.0 || curCov != COVER_NONE)
		{
			Owner.Vel.X = 0.0;
			Owner.Vel.Y = 0.0;
			RestoreStandingProperties(true);

			int finalCov = (curCov != COVER_NONE) ? curCov : coverGoalType;
			if (finalCov == COVER_FULL && GetCVarBool('nbc_corner_peek', true))
			{
				LogDebug("ARRIVED AT DISTANT CORNER COVER -> CORNER HIDE!");
				StartCornerHide(GetRandomizedDuckTics());
			}
			else
			{
				LogDebug("ARRIVED AT DISTANT LOW COVER -> DUCK!");
				StartDuck(GetRandomizedDuckTics());
			}
			return;
		}

		if (stateTimer <= 0)
		{
			Owner.Vel.X = 0.0;
			Owner.Vel.Y = 0.0;
			EnterNormalState();
			return;
		}

		double moveAng = VectorAngle(toGoal.x, toGoal.y);
		if (!IsDirectionClear(moveAng, min(28.0, dist)))
		{
			Owner.Vel.X = 0.0;
			Owner.Vel.Y = 0.0;
			EnterNormalState();
			return;
		}

		Owner.angle = moveAng;
		double runSpd = max(4.5, (baseSpeed * 1.45) * 0.45);
		Vector2 stepVec = Actor.AngleToVector(moveAng, min(runSpd, dist));
		Owner.Vel.X = stepVec.X;
		Owner.Vel.Y = stepVec.Y;
	}

	// ========================================================================
	// 3D Geometry & Cover Classification Utilities
	// ========================================================================
	int ClassifyCoverAt(Vector2 testXY)
	{
		if (!Owner || !Owner.target)
			return COVER_NONE;

		Actor plr = Owner.target;
		double floorZ = Owner.GetZAt(testXY.x, testXY.y, 0, GZF_ABSOLUTEPOS);

		Vector3 lowPt  = (testXY.x, testXY.y, floorZ + baseHeight * 0.34);
		Vector3 highPt = (testXY.x, testXY.y, floorZ + baseHeight * 0.78);

		bool lowBlocked  = IsRayFromTargetBlockedByGeometry(plr, lowPt);
		bool highBlocked = IsRayFromTargetBlockedByGeometry(plr, highPt);

		if (lowBlocked && highBlocked)
			return COVER_FULL;
		if (lowBlocked && !highBlocked)
			return COVER_LOW;

		return COVER_NONE;
	}

	bool IsRayFromTargetBlockedByGeometry(Actor plr, Vector3 worldPt)
	{
		double eyeZ = plr.player ? plr.player.viewz : (plr.pos.z + plr.Height * 0.75);
		Vector3 startPt = (plr.pos.x, plr.pos.y, eyeZ);
		Vector3 diff = Level.Vec3Diff(startPt, worldPt);
		double dist = diff.Length();

		if (dist < 16.0)
			return false;

		double ang = VectorAngle(diff.x, diff.y);
		double pit = -VectorAngle(diff.xy.Length(), diff.z);
		double offsetZ = eyeZ - plr.pos.z;

		FLineTraceData trace;
		plr.LineTrace(ang, dist, pit, TRF_THRUACTORS, offsetZ, 0.0, 0.0, trace);

		if (trace.HitType != TRACE_HitNone && trace.Distance < dist - 8.0)
		{
			return true;
		}

		// Ported from Smart Marines (`SM_UpdateCover`):
		// Optionally treat solid non-monster props/obstacles (barricades, crates, tech pillars) as cover!
		if (GetCVarBool('nbc_prop_cover_enable', true))
		{
			FLineTraceData propTrace;
			plr.LineTrace(ang, dist, pit, 0, offsetZ, 0.0, 0.0, propTrace);
			if (propTrace.HitType == TRACE_HitActor && propTrace.HitActor && propTrace.Distance < dist - 8.0)
			{
				Actor hitMo = propTrace.HitActor;
				if (hitMo != Owner && hitMo != plr && hitMo.bSOLID && !hitMo.bISMONSTER &&
				    !hitMo.player && !(hitMo is "ExplosiveBarrel") &&
				    hitMo.Radius >= 10.0 && hitMo.Height >= 20.0)
				{
					return true;
				}
			}
		}

		return false;
	}

	int GetWallProximityScore(Vector2 testXY)
	{
		if (!Owner)
			return 0;

		Vector2 rel = testXY - Owner.pos.xy;
		double forwardOff = rel.x * cos(Owner.angle) + rel.y * sin(Owner.angle);
		double sideOff    = rel.x * sin(Owner.angle) - rel.y * cos(Owner.angle);

		int wallHits = 0;
		for (int a = 0; a < 360; a += 90)
		{
			FLineTraceData td;
			Owner.LineTrace(a, 44.0, 0.0, TRF_THRUACTORS, baseHeight * 0.5, forwardOff, sideOff, td);
			if (td.HitType == TRACE_HitWall)
				wallHits++;
		}

		return wallHits * 15;
	}

	bool IsDirectionClear(double testAngle, double dist)
	{
		if (!Owner)
			return false;

		Vector2 step1 = Owner.pos.xy + Actor.AngleToVector(testAngle, dist * 0.35);
		Vector2 step2 = Owner.pos.xy + Actor.AngleToVector(testAngle, dist * 0.70);
		Vector2 step3 = Owner.pos.xy + Actor.AngleToVector(testAngle, dist);

		if (!Owner.CheckMove(step1) || !Owner.CheckMove(step2) || !Owner.CheckMove(step3))
			return false;

		return true;
	}

	bool IsPlayerFiring() const
	{
		if (!Owner || !Owner.target || !Owner.target.player)
			return false;

		return (Owner.target.player.cmd.buttons & BT_ATTACK) != 0;
	}

	void UpdatePlayerThreatTrackers()
	{
		if (!Owner || !Owner.target || Owner.target.health <= 0)
		{
			aimedAtTics = 0;
			outOfSightTics = 0;
			playerSilentTics = 0;
			return;
		}

		Actor plr = Owner.target;
		bool hasSight = Owner.CheckSight(plr);
		bool firing   = IsPlayerFiring();

		if (!hasSight)
			outOfSightTics++;
		else
			outOfSightTics = 0;

		if (!firing)
			playerSilentTics++;
		else
			playerSilentTics = 0;

		if (!plr.player)
			return;

		Vector3 eyePos = (plr.pos.x, plr.pos.y, plr.player.viewz);
		Vector3 myCenter = (Owner.pos.x, Owner.pos.y, Owner.pos.z + Owner.Height * 0.6);
		Vector3 toMe = Level.Vec3Diff(eyePos, myCenter);
		double dist = toMe.Length();

		if (dist < 64.0 || dist > 2048.0 || !hasSight)
		{
			aimedAtTics = max(0, aimedAtTics - 1);
			return;
		}

		toMe = toMe / dist;

		double cp = cos(plr.pitch);
		Vector3 viewVec = (cos(plr.angle) * cp, sin(plr.angle) * cp, -sin(plr.pitch));
		double aimDot = toMe dot viewVec;

		if (aimDot > 0.984)
		{
			aimedAtTics++;
		}
		else
		{
			aimedAtTics = max(0, aimedAtTics - 1);
		}

		if (firing && aimDot > 0.91)
		{
			suppressedTics = min(20, suppressedTics + 2);
		}
	}

	static double Lerp(double a, double b, double t)
	{
		return a + (b - a) * t;
	}

	int GetCVarInt(Name cvarName, int fallback)
	{
		CVar c = CVar.FindCVar(cvarName);
		return c ? c.GetInt() : fallback;
	}

	double GetCVarFloat(Name cvarName, double fallback)
	{
		CVar c = CVar.FindCVar(cvarName);
		return c ? c.GetFloat() : fallback;
	}

	bool GetCVarBool(Name cvarName, bool fallback)
	{
		CVar c = CVar.FindCVar(cvarName);
		return c ? c.GetBool() : fallback;
	}

	void LogDebug(String msg)
	{
		if (GetCVarBool('nbc_debug_tactical', false) && Owner)
		{
			Console.Printf("\c[Cyan][TacticalAI]\c- %s: %s", Owner.GetTag(), msg);
		}
	}
}
