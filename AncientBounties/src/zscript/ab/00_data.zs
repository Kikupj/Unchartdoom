// ============================================================================
// ANCIENT BOUNTIES - static game data
// ============================================================================
class AB
{
	// ---- profile slots (all persistent state lives in AB_Game.v[])
	enum EProfile
	{
		P_VERSION = 0, P_GOLD, P_SUPPLIES, P_MATERIALS, P_INTEL, P_DAY, P_WINS, P_DEATHS, P_RUNS, P_BESTHAUL,
		P_INTRO, P_PARTNER, P_CANDDAY, P_KILLS, P_NGPLUS, P_FINALE,
		P_BLD = 20,      // 6 buildings
		P_WOWN = 30,     // 16 weapons owned
		P_WEQ = 46,      // 16 weapons equipped
		P_GEAR = 62,     // 10 gear
		P_REGION = 72,   // 5 region states
		P_RIVAL = 77,    // 5 rival progress (x10)
		P_RELIC = 82,    // 20 lesser relics
		P_CREW = 102,    // 8 crew * 6 fields: used,name,class,level,xp,status(0 ready 1 away 2 hurt),days  -> 7 fields
		P_CAND = 160,    // 3 candidates * 3 (name,class,level)   name<0 = hired/empty
		P_DISP = 170,    // 3 teams * 3 (region+1 (0=idle), days left, kind)
		P_RUN = 180,     // run block
		P_SIZE = 240
	}
	enum ERun
	{
		R_ACTIVE = 180, R_REGION, R_STAGE, R_ID, R_NSTAGES,
		R_TYPE0, R_TYPE1, R_TYPE2, R_TYPE3,      // 0 action 1 puzzle 2 vault
		R_VAR0, R_VAR1, R_VAR2, R_VAR3,
		R_GOLD, R_MAT, R_SUP, R_INTEL, R_RELICS, R_GREAT, R_REVIVES, R_MEDKITS, R_KILLS, R_EQUIPPED, R_SEED,
		R_BOON = 210     // 12 boon counters
	}
	enum ERegionState { RS_LOCKED, RS_OPEN, RS_WON, RS_LOST }
	enum EBld { B_COMMAND, B_ARMORY, B_WORKSHOP, B_INFIRMARY, B_STORAGE, B_RADIO, NUM_BLD }
	enum EBoon { BN_FURY, BN_SCALES, BN_SUN, BN_POCKETS, BN_FORTUNE, BN_BLOOD, BN_FLEET, BN_VULTURE, BN_QUARTER, BN_IRON, BN_CURSE, BN_WIND, NUM_BOON }
	enum EGear { G_VEST1, G_VEST2, G_SATCHEL, G_MEDKIT, G_COMPASS, G_HOLSTER, G_BANDOLIER, G_CHARM, G_RUBBING, G_MEDKIT2, NUM_GEAR }
	const CREW_MAX = 8;
	const CREW_F = 7;
	const NUM_REGIONS = 5;
	const NUM_WEAPONS = 16;
	const CITADEL = 4;

	// ---- regions
	static const String RegionName[]  = { "PERU", "EGYPT", "CARIBBEAN", "NEPAL", "MERIDIAN CITADEL" };
	static const String RegionPlace[] = { "Madre de Dios, Amazon Basin", "The Western Desert", "The Windward Isles", "Upper Mustang, Himalaya", "Skerry Rock, North Atlantic" };
	static const String RegionCode[]  = { "PE", "EG", "CA", "NE", "CI" };
	static const String GreatName[]   = { "The Jaguar Sun", "Scarab of the Nameless King", "The Corsair's Crown", "The Thunder Vajra", "Thorne's Private Collection" };
	static const String RegionBlurb[] = {
		"A drowned temple city under the canopy. Stone jaguars guard a disc of beaten gold that the Inca hid from everyone.",
		"A tomb with no name on any king-list. The scarab buried there was meant to stay buried.",
		"Sea caves, a rotted fort and the last hoard of a pirate who crowned himself king of nothing.",
		"A cliff monastery above the snow line. The monks are gone. The thunderbolt they kept is not.",
		"Magnus Thorne keeps what he takes in a vault under his company's fortress. Go and take it back." };
	static const int RegionDiff[]     = { 1, 2, 2, 3, 4 };
	static const int RegionCost[]     = { 40, 60, 60, 80, 120 };
	static const int RegionIntel[]    = { 0, 2, 3, 5, 8 };      // intel needed to unlock
	static const int RegionCmd[]      = { 1, 1, 1, 2, 3 };      // command tent level needed
	static const double RegionLon[]   = { -71, 27, -61, 84, -18 };
	static const double RegionLat[]   = { -12, 26, 14, 29, 61 };
	static const String RelicName[] = {
		"Feathered Mask", "Obsidian Mirror", "Quipu of Kings", "Emerald Hummingbird", "Golden Llama",
		"Ankh of Dusk", "Canopic Jackal", "Lapis Collar", "Sun-Boat Model", "Papyrus of Gates",
		"Doubloon Chest", "Admiral's Sextant", "Pearl Cutlass", "Jade Kraken", "Log of the Revenant",
		"Singing Bowl", "Snow Lion Seal", "Turquoise Mandala", "Yak-Bone Flute", "The Lost Sutra" };
	static const String SetBonus[] = { "+10 max health", "+15% gold found", "+1 boon choice", "+10% weapon damage" };

	// ---- buildings
	static const String BldName[] = { "Command Tent", "Armory", "Workshop", "Infirmary", "Storage", "Radio Tower" };
	static const String BldDesc[] = {
		"The operational hub. Caps every other building's level, sets crew capacity and opens harder destinations.",
		"Unlocks better firearms for purchase and adds starting ammunition.",
		"Unlocks field gear: vests, satchels, medkits and lucky charms.",
		"Raises your maximum health, patches you up between stages and gets injured crew back on their feet sooner.",
		"Protects part of your haul when an expedition goes wrong.",
		"Lets you dispatch crew teams, gathers intel and tracks how close Thorne is to each treasure." };
	static const int BldMax[] = { 3, 3, 3, 3, 3, 3 };
	// cost to reach level L (1..3): materials, supplies
	static const int BldMat[] = { 0, 220, 480,   90, 240, 480,   110, 260, 500,   90, 220, 460,   70, 180, 380,   130, 280, 520 };
	static const int BldSup[] = { 0, 150, 300,   40, 110, 240,   50, 130, 250,   70, 150, 290,   30, 90, 190,    70, 150, 270 };

	// ---- weapons: class, display name, kind (0 melee 1 sidearm 2 long gun 3 throwable), armory tier, price
	static const String WpnClass[] = { "Machete", "Knife", "Colt45", "MicroUzi", "Coachgun", "TacticalShotgun", "RiotShotgun", "MP5",
		"SuppressedMP5", "AK47", "VM16", "HMachinegun", "HuntingRifle", "Flaregun", "HandGrenade", "MolotovCocktail" };
	static const String WpnName[] = { "Machete", "Combat Knife", "Colt .45", "Micro Uzi", "Coach Gun", "Tactical Shotgun", "Riot Shotgun", "MP5",
		"Suppressed MP5", "AK-47", "M16 Rifle", "Heavy Machine Gun", "Hunting Rifle", "Flare Gun", "Hand Grenades", "Molotov Cocktails" };
	static const String WpnNote[] = { "Reliable jungle blade.", "Fast, quiet, short reach.", "Seven rounds of persuasion.", "Sprays bullets from the hip.",
		"Two barrels, one argument.", "Pump-action room clearer.", "Riot gun with ricochet shells.", "Compact and controllable.",
		"Quiet. Mercs notice later.", "Hits hard, kicks harder.", "Three-round bursts, long reach.", "Belt-fed. Eats ammunition.",
		"Scoped. One shot, one merc.", "Sets things on fire. People too.", "Pull pin, throw, duck.", "Area denial in a bottle." };
	static const int WpnKind[]  = { 0, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3 };
	static const int WpnTier[]  = { 0, 0, 0, 1, 0, 1, 2, 1, 2, 2, 3, 3, 1, 1, 1, 2 };
	static const int WpnPrice[] = { 0, 60, 0, 220, 120, 320, 520, 300, 420, 600, 700, 1100, 380, 260, 200, 300 };

	// ---- gear: name, description, workshop tier, price
	static const String GearName[] = { "Kevlar Vest", "Ceramic Plates", "Ammo Satchel", "Field Medkit", "Compass of Fortune", "Extra Holster", "Bandolier", "Lucky Charm", "Rubbing Kit", "Trauma Kit" };
	static const String GearDesc[] = { "Start every expedition with 50 armor.", "Vest upgrade: start with 100 armor.", "+50% starting ammunition.", "One medkit per expedition (heals 50).",
		"+20% gold from everything you find.", "Carry a fourth firearm.", "Carry both throwables, +3 of each.", "Cheat death once per expedition.", "Wrong puzzle answers no longer spring traps.", "Carry a second medkit." };
	static const int GearTier[]  = { 1, 2, 1, 1, 2, 2, 2, 3, 1, 3 };
	static const int GearPrice[] = { 250, 500, 200, 250, 400, 450, 350, 900, 180, 500 };
	static const int GearReq[]   = { -1, 0, -1, -1, -1, -1, -1, -1, -1, 3 };

	// ---- boons
	static const String BoonName[] = { "Jaguar's Fury", "Serpent Scales", "Sun's Blessing", "Smuggler's Pockets", "Fortune's Favor", "Blood Offering",
		"Fleet Foot", "Vulture's Eye", "Quartermaster", "Iron Hide", "Cursed Idol", "Second Wind" };
	static const String BoonDesc[] = { "+20% weapon damage.", "Take 15% less damage.", "Heal 40 now, +10 max health.", "+50% ammo from pickups.", "+30% gold found.",
		"Every kill heals 2 health.", "Move faster; dodge recharges quicker.", "+2 Intel now, mercs may drop more.", "Refill all ammo, +2 throwables.", "+50 armor now, +25 each new stage.",
		"Double gold. Mercs hit 25% harder.", "Survive one killing blow." };

	// ---- crew
	static const String CrewNames[] = { "Rosa Quintero", "Tobias Finch", "Amara Okoye", "Henrik Dahl", "Mei-Lin Zhao", "Samir Haddad", "Josie Blackwood", "Kofi Mensah",
		"Ilse Brandt", "Rafael Souza", "Nadia Petrov", "Duncan Hale", "Yuki Morita", "Esteban Cruz", "Greta Lindqvist", "Omar Farouk",
		"Tamsin Reyes", "Vikram Rao", "Colette Marchand", "Jonah Pike", "Leilani Kahale", "Bram Okafor", "Sunniva Aas", "Declan Moore" };
	static const String ClassName[] = { "Scout", "Gunner", "Scholar", "Medic" };
	static const String ClassPerk[] = { "Partner: +1 Intel per stage cleared.", "Partner: +30% starting ammo, +10% damage.", "Partner: more relics, steles show an extra clue.", "Partner: +20 health, +20 healing between stages." };

	static const String ThorneTaunt[] = {
		"You're digging in my sandbox, friend. I own the sand.",
		"Every relic you lift, I've already had appraised.",
		"My people get paid whether you live or not. Think about that.",
		"History belongs to whoever can afford the security.",
		"I admire persistence. I also bury it.",
		"Finders keepers is a children's rule. I run a company.",
		"Leave the idol on the plinth and I'll forget your face.",
		"That was a week's payroll you just shot. I'm adding it to your bill." };

	// ---- helpers
	static clearscope String MapFor(int region, int type, int variant)
	{
		static const String T[] = { "A", "P", "V" };
		return String.Format("%s%s%d", AB.RegionCode[region], T[type], variant + 1);
	}
	static clearscope String StageTitle(int region, int type, int stage)
	{
		static const String act[] = { "The Approach", "Tomb Road", "Smuggler's Landing", "The Pass", "Outer Perimeter" };
		static const String puz[] = { "Hall of Glyphs", "The Sealed Galleries", "The Flooded Vaults", "Monastery of Echoes", "Security Wing" };
		static const String vlt[] = { "Vault of the Jaguar Sun", "Chamber of the Nameless King", "The Corsair's Hoard", "Shrine of the Thunderbolt", "Thorne's Vault" };
		if (type == 2) return vlt[region];
		if (type == 1) return puz[region];
		return stage >= 2 ? "The Inner Stronghold" : act[region];
	}
	static clearscope int CrewCap(int cmdLevel) { return 1 + cmdLevel * 2; }
	static clearscope int KeepPct(int storageLevel) { static const int k[] = { 25, 45, 65, 85 }; return k[clamp(storageLevel, 0, 3)]; }
	static clearscope int RecruitCost(int level) { return 80 + 60 * level; }
}
