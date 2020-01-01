#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <hl>
#include <hlsdk_const>
#include <xs>

#pragma semicolon 1
#pragma ctrlchar '\'

#define EULER	2.71828182846
#define EULER2	5.43656365692

#define MAX_INT 2147483647

#define MAX_ENTITIES 1060 // https://forums.alliedmods.net/showpost.php?p=657925&postcount=2

#define WAYPOINT_DISTANCE_THRESHOLD			20.0
#define MOVEMENT_BLOCKED_THRESHOLD			1.0
#define MAX_SPAWNPOINTS						15
#define MAX_WAYPOINT_NEIGHBOURS				32
#define TOUCH_GROUND_DISTANCE				4.0
#define MAX_ACCUMULATED_UNSTUCK_VELOCITY	500.0

#define DEFAULT_MONSTER_FRAMETIME			0.1
#define DEFAULT_MONSTER_DAMAGE				20.0
#define DEFAULT_MONSTER_HEALTH				150.0
#define DEFAULT_MONSTER_SPEED				300.0

#define POINTS_TO_CREDITS_FACTOR			0.1
#define REWARD_RECEIVAL_THRESHOLD1			50000.0
#define REWARD_RECEIVAL_THRESHOLD2			20000.0
#define POINTS_REWARD1						10000.0
#define POINTS_REWARD2						2500.0
#define DEFAULT_POINTS_REWARD				100.0

#define GARBAGE_REMOVAL_TIME				30.0

#define WP_SPAWN				(1<<0)	// spawn point
#define WP_BOSS					(1<<1)	// special spawn point, e.g.: for tentacles to spawn there
#define WP_LAND					(1<<2)	// is it accessible by ground monsters?
#define WP_AIR					(1<<3)	// is it accessible by flying monsters?
#define WP_JUMP_FROM			(1<<4)	// monster can perform a big jump from here directly to a WP_JUMP_TO
#define WP_JUMP_TO				(1<<5)	// monster can perform a big jump from a WP_JUMP_FROM to this point
#define WP_NEXUS_ATTACK_MELEE	(1<<6)	// from this point the Nexus can be attacked with melee attacks
#define WP_NEXUS_ATTACK_RANGED	(1<<7)	// good position to perform ranged attacks to the Nexus

#define DIFFICULTY_SURVIVAL		0x00	// Logarithmic multiplier for stats, unlimited rounds
#define DIFFICULTY_TEST			0x01	// -60% stats, 5 rounds
#define DIFFICULTY_VERY_EASY	0x02	// -40% stats, 10 rounds
#define DIFFICULTY_EASY			0x03	// -20% stats, 10 rounds
#define DIFFICULTY_NORMAL		0x04	// Normal stats, 15 rounds
#define DIFFICULTY_HARD			0x05	// +20% stats, 20 rounds
#define DIFFICULTY_VERY_HARD	0x06	// +40% stats, 25 rounds
#define DIFFICULTY_ELITE		0x07	// +80% stats, 30 rounds
#define DIFFICULTY_INSANE		0x08	// +150% stats, 40 rounds
#define DIFFICULTY_NIGHTMARE	0x09	// +200% stats, 50 rounds
#define DIFFICULTY_IMPOSSIBLE	0x10	// +400% stats, 60 rounds

#define DEFAULT_DIFFICULTY		DIFFICULTY_NORMAL

#define AGVOTE_UNDECIDED		0x00
#define AGVOTE_YES 				0x01
#define AGVOTE_NO 				0x02

// Vote status
#define AGVOTE_NOT_RUNNING		0x00
#define AGVOTE_CALLED			0x01
#define AGVOTE_ACCEPTED			0x02
#define AGVOTE_DENIED			0x03

// Material of the gibs when some breakable thing breaks
#define BREAK_GLASS				0x01
#define BREAK_METAL				0x02
#define BREAK_FLESH				0x04
#define BREAK_WOOD				0x08
#define BREAK_CONCRETE			0x40

// Game status
#define GAME_IDLE				0x00
#define GAME_STARTING			0x01
#define GAME_RUNNING			0x02
#define GAME_ABORTED			0x03
#define GAME_DEFEAT				0x04
#define GAME_VICTORY			0x05

#define MODE_FUN				0x00
#define MODE_COMPETITIVE		0x01

#define TASKID_SPAWN_MONSTER_WAVE 			518934
#define TASKID_RESET_MONSTER_SPAWN 			578931
#define TASKID_START_ROUND 					689151
#define TASKID_UNSTUCK_ENTITY 				291739
#define TASKID_UNSTUCK_ENTITY_WITH_MONSTER 	234787
#define TASKID_GARBAGE_REMOVAL				456050
#define TASKID_GONARCH_REMOVAL				234782
#define TASKID_INIT_PLAYER					892349

#define isPlayer(%1) (1 <= %1 <= g_MaxPlayers)
#define isSpectator(%1) (pev(%1, pev_iuser1) > 0)

/*
	MONSTER						MODEL 							CPP FILE
	******************************************************************************
	monster_alien_controller	models/controller.mdl 			controller.cpp		MISSING AIRBORNE WAYPOINTS
	monster_alien_grunt			models/agrunt.mdl 				agrunt.cpp			DONE
	monster_alien_slave			models/islave.mdl 				islave.cpp			DONE
	monster_apache				models/apache.mdl 				apache.cpp
	monster_babycrab			models/baby_headcrab.mdl 		headcrab.cpp
	monster_barnacle			models/barnacle.mdl 			barnacle.cpp
	monster_barney				models/barney.mdl 				barney.cpp
	monster_bigmomma			models/big_mom.mdl 				bigmomma.cpp		DONE
	monster_bloater				models/floater.mdl 				bloater.cpp
	monster_bullchicken			models/bullsquid.mdl 			bullsquid.cpp		DONE
	monster_cockroach			models/roach.mdl 				roach.cpp
	monster_flyer_flock			models/boid.mdl 				aflock.cpp
	monster_gargantua			models/garg.mdl 				gargantua.cpp		DONE
	monster_gman				models/gman.mdl 				gman.cpp
	monster_grunt_repel			models/hgrunt.mdl 				hgrunt.cpp
	monster_headcrab			models/headcrab.mdl 			headcrab.cpp		DONE
	monster_houndeye			models/houndeye.mdl 			houndeye.cpp		DONE
	monster_human_assassin		models/hassassin.mdl 			hassassin.cpp
	monster_ichthyosaur			models/icky.mdl 				ichtyosaur.cpp
	monster_leech				models/leech.mdl 				leech.cpp
	monster_nihilanth			models/nihilanth.mdl 			nihilant.cpp		MISSING AIRBORNE WAYPOINTS
	monster_osprey				models/osprey.mdl 				osprey.cpp
	monster_rat					models/bigrat.mdl 				rat.cpp
	monster_scientist			models/scientist.mdl 			scientist.cpp
	monster_snark				models/w_squeak.mdl 			squeakgrenade.cpp
	monster_tentacle			models/tentacle2.mdl 			tentacle.cpp
	monster_zombie				models/zombie.mdl 				zombie.cpp			DONE

	(TO BE IMPLEMENTED)
	- 							models/aflock.mdl 				-
	- 							models/archer.mdl 				-
	- 							models/big_eye_chumtoad.mdl 	-
	- 							models/charger.mdl 				-
	- 							models/chumtoad.mdl 			-
	- 							models/crystal.mdl 				-
	- 							models/diablo.mdl 				-
	- 							models/doctor.mdl 				- 					BLUE/RED/GREEN TOO
	- 							models/friendly.mdl 			-
	- 							models/gasbag.mdl 				-
	- 							models/hassault.mdl 			-
	- 							models/kingpin.mdl 				-
	- 							models/probe.mdl 				-
	- 							models/probeboss.mdl 			-
	- 							models/protozoa.mdl 			-
	- 							models/redheadcrab.mdl 			-
	- 							models/snapbug.mdl				- 					ONLY IDLE
	- 							models/sphere.mdl 				-
	- 							models/w_sqknest.mdl 			-
	- 							models/st/hunter.mdl 			-
	- 							models/st/licker.mdl 			-
	- 							models/st/zombie3.mdl 			-




	MONSTER 					ANIMATION
	*******************************************************************
	monster_zombie				8=attack, 10=walk, 22=attack, 24=push
*/

enum _:WAYPOINT
{
	WP_ID[17],				// unique identifier, e.g.: "wp29"
	Float:WP_ORIGIN[3],		// waypoint location
	WP_WEIGHT_NEXUS,		// the nearer by Nexus, the higher weight; especially important for land monsters to find the path correctly
	WP_WEIGHT_TAKE_COVER,	// how good is it for taking cover
	WP_FLAGS,				// different properties a waypoint may have (see WP_ defines)
	Array:WP_NEIGHBOURS		// an array where other waypoints identifiers are put, indicating you can access those from this waypoint
}

enum _:ENTITY_STATE
{
	Float:ENT_GAMETIME,
	Float:ENT_ORIGIN[3],
	Float:ENT_ANGLES[3],
	Float:ENT_VELOCITY[3],
	Float:ENT_GRAVITY_VELOCITY,
	ENT_FLAGS
}

enum _:MONSTER_DATA
{
	MONSTER_ENTITY_NAME[32],
	MONSTER_MODEL[64],
	Float:MONSTER_DAMAGE,
	Float:MONSTER_HEALTH,
	Float:MONSTER_SPEED,
	bool:MONSTER_IS_CUSTOM,
	bool:MONSTER_IS_AIRBORNE
}

enum _:DIFFICULTY
{
	Float:DIFFICULTY_STATS_MULTIPLIER,
	DIFFICULTY_ROUNDS
}

enum
{
	ZOMBIE_ATTACK1_SEQ	= 8,
	ZOMBIE_ATTACK2_SEQ	= 22,
	ZOMBIE_PUSH_SEQ		= 24,
	ZOMBIE_WALK_SEQ		= 10
}

new const g_GameStateString[][] =
{
	"idle",
	"running",
	"defeat",
	"aborted",
	"victory"
};

new const g_GibModels[][] =
{
	"models/bonegibs.mdl",
	"models/bookgibs.mdl",
	"models/cactusgibs.mdl",
	"models/ceilinggibs.mdl",
	"models/cindergibs.mdl",
	"models/computergibs.mdl",
	"models/garbagegibs.mdl",
	"models/glassgibs.mdl",
	"models/hgibs.mdl",
	"models/metalplategibs.mdl",
	"models/rockgibs.mdl",
	"models/webgibs.mdl",
	"models/woodgibs.mdl",
};

new const g_GibMaterials[sizeof(g_GibModels)] =
{
	BREAK_FLESH,
	BREAK_GLASS,
	BREAK_WOOD,
	BREAK_METAL,
	BREAK_CONCRETE,
	BREAK_CONCRETE,
	BREAK_METAL,
	BREAK_CONCRETE,
	BREAK_FLESH,
	BREAK_FLESH,
	BREAK_FLESH,
	BREAK_WOOD,
	BREAK_FLESH
};

new const g_Models[][] = {
	"models/aflock.mdl",
	"models/agrunt.mdl",
	"models/baby_headcrab.mdl",
	"models/big_mom.mdl",
	"models/boid.mdl",
	"models/bullsquid.mdl",
	//"models/charger.mdl",
	"models/chumtoad.mdl",
	"models/controller.mdl",
	"models/floater.mdl",
	"models/friendly.mdl",
	"models/garg.mdl",
	"models/gasbag.mdl",
	"models/headcrab.mdl",
	"models/houndeye.mdl",
	"models/hunter.mdl",
	"models/islave.mdl",
	"models/kingpin.mdl",
	"models/nihilanth.mdl",
	"models/pantagruel.mdl",
	"models/panther.mdl",
	"models/protozoa.mdl",
	//"models/redheadcrab.mdl",
	"models/snapbug.mdl",
	"models/tentacle2.mdl",
	"models/w_sqknest.mdl",
	"models/zombie.mdl"
};

new const g_Sounds[][] =
{
	"agrunt/ag_alert1.wav",
	"agrunt/ag_alert3.wav",
	"agrunt/ag_alert4.wav",
	"agrunt/ag_alert5.wav",
	"agrunt/ag_attack1.wav",
	"agrunt/ag_attack2.wav",
	"agrunt/ag_attack3.wav",
	"agrunt/ag_die1.wav",
	"agrunt/ag_die4.wav",
	"agrunt/ag_die5.wav",
	"agrunt/ag_idle1.wav",
	"agrunt/ag_idle2.wav",
	"agrunt/ag_idle3.wav",
	"agrunt/ag_idle4.wav",
	"agrunt/ag_pain1.wav",
	"agrunt/ag_pain2.wav",
	"agrunt/ag_pain3.wav",
	"agrunt/ag_pain4.wav",
	"agrunt/ag_pain5.wav",
	"ambience/flies.wav",
	"ambience/squirm2.wav",
	"aslave/slv_die1.wav",
	"aslave/slv_die2.wav",
	"aslave/slv_pain1.wav",
	"aslave/slv_pain2.wav",
	"boid/boid_alert1.wav",
	"boid/boid_alert2.wav",
	"boid/boid_idle1.wav",
	"boid/boid_idle2.wav",
	"bullchicken/bc_acid1.wav",
	"bullchicken/bc_attack2.wav",
	"bullchicken/bc_attack3.wav",
	"bullchicken/bc_attackgrowl.wav",
	"bullchicken/bc_attackgrowl2.wav",
	"bullchicken/bc_attackgrowl3.wav",
	"bullchicken/bc_bite2.wav",
	"bullchicken/bc_bite3.wav",
	"bullchicken/bc_die1.wav",
	"bullchicken/bc_die2.wav",
	"bullchicken/bc_die3.wav",
	"bullchicken/bc_idle1.wav",
	"bullchicken/bc_idle2.wav",
	"bullchicken/bc_idle3.wav",
	"bullchicken/bc_idle4.wav",
	"bullchicken/bc_idle5.wav",
	"bullchicken/bc_pain1.wav",
	"bullchicken/bc_pain2.wav",
	"bullchicken/bc_pain3.wav",
	"bullchicken/bc_pain4.wav",
	"bullchicken/bc_spithit1.wav",
	"bullchicken/bc_spithit2.wav",
	"common/bodydrop2.wav",
	"controller/con_alert1.wav",
	"controller/con_alert2.wav",
	"controller/con_alert3.wav",
	"controller/con_attack1.wav",
	"controller/con_attack2.wav",
	"controller/con_attack3.wav",
	"controller/con_die1.wav",
	"controller/con_die2.wav",
	"controller/con_idle1.wav",
	"controller/con_idle2.wav",
	"controller/con_idle3.wav",
	"controller/con_idle4.wav",
	"controller/con_idle5.wav",
	"controller/con_pain1.wav",
	"controller/con_pain2.wav",
	"controller/con_pain3.wav",
	"debris/beamstart7.wav",
	"debris/metal4.wav",
	"debris/metal6.wav",
	"debris/zap1.wav",
	"debris/zap4.wav",
	"garg/gar_alert1.wav",
	"garg/gar_alert2.wav",
	"garg/gar_alert3.wav",
	"garg/gar_attack1.wav",
	"garg/gar_attack2.wav",
	"garg/gar_attack3.wav",
	"garg/gar_breathe1.wav",
	"garg/gar_breathe2.wav",
	"garg/gar_breathe3.wav",
	"garg/gar_flameoff1.wav",
	"garg/gar_flameon1.wav",
	"garg/gar_flamerun1.wav",
	"garg/gar_flameoff1.wav",
	"garg/gar_flameon1.wav",
	"garg/gar_flamerun1.wav",
	"garg/gar_idle1.wav",
	"garg/gar_idle2.wav",
	"garg/gar_idle3.wav",
	"garg/gar_idle4.wav",
	"garg/gar_idle5.wav",
	"garg/gar_pain1.wav",
	"garg/gar_pain2.wav",
	"garg/gar_pain3.wav",
	"garg/gar_step1.wav",
	"garg/gar_step2.wav",
	"garg/gar_stomp1.wav",
	"gonarch/gon_alert1.wav",
	"gonarch/gon_alert2.wav",
	"gonarch/gon_alert3.wav",
	"gonarch/gon_attack1.wav",
	"gonarch/gon_attack2.wav",
	"gonarch/gon_attack3.wav",
	"gonarch/gon_birth1.wav",
	"gonarch/gon_birth2.wav",
	"gonarch/gon_birth3.wav",
	"gonarch/gon_childdie1.wav",
	"gonarch/gon_childdie2.wav",
	"gonarch/gon_childdie3.wav",
	"gonarch/gon_die1.wav",
	"gonarch/gon_pain2.wav",
	"gonarch/gon_pain4.wav",
	"gonarch/gon_pain5.wav",
	"gonarch/gon_sack1.wav",
	"gonarch/gon_sack2.wav",
	"gonarch/gon_sack3.wav",
	"gonarch/gon_step1.wav",
	"gonarch/gon_step2.wav",
	"gonarch/gon_step3.wav",
	"hassault/hw_shoot1.wav",
	"headcrab/hc_alert1.wav",
	"headcrab/hc_attack1.wav",
	"headcrab/hc_attack2.wav",
	"headcrab/hc_attack3.wav",
	"headcrab/hc_die1.wav",
	"headcrab/hc_die2.wav",
	"headcrab/hc_headbite.wav",
	"headcrab/hc_idle1.wav",
	"headcrab/hc_idle2.wav",
	"headcrab/hc_idle3.wav",
	"headcrab/hc_pain1.wav",
	"headcrab/hc_pain2.wav",
	"headcrab/hc_pain3.wav",
	"houndeye/he_alert1.wav",
	"houndeye/he_alert2.wav",
	"houndeye/he_alert3.wav",
	"houndeye/he_attack1.wav",
	"houndeye/he_attack3.wav",
	"houndeye/he_blast1.wav",
	"houndeye/he_blast2.wav",
	"houndeye/he_blast3.wav",
	"houndeye/he_die1.wav",
	"houndeye/he_die2.wav",
	"houndeye/he_die3.wav",
	"houndeye/he_idle1.wav",
	"houndeye/he_idle2.wav",
	"houndeye/he_idle3.wav",
	"houndeye/he_hunt1.wav",
	"houndeye/he_hunt2.wav",
	"houndeye/he_hunt3.wav",
	"houndeye/he_pain1.wav",
	"houndeye/he_pain3.wav",
	"houndeye/he_pain4.wav",
	"houndeye/he_pain5.wav",/*
	"player/pl_dirt1.wav",
	"player/pl_dirt2.wav",
	"player/pl_dirt3.wav",
	"player/pl_dirt4.wav",
	"player/pl_slosh1.wav",
	"player/pl_slosh2.wav",
	"player/pl_slosh3.wav",
	"player/pl_slosh4.wav",*/
	"tentacle/te_alert1.wav",
	"tentacle/te_alert2.wav",
	"tentacle/te_flies1.wav",
	"tentacle/te_move1.wav",
	"tentacle/te_move2.wav",
	"tentacle/te_roar1.wav",
	"tentacle/te_roar2.wav",
	"tentacle/te_search1.wav",
	"tentacle/te_search2.wav",
	"tentacle/te_sing1.wav",
	"tentacle/te_sing2.wav",
	"tentacle/te_squirm2.wav",
	"tentacle/te_strike1.wav",
	"tentacle/te_strike2.wav",
	"tentacle/te_swing1.wav",
	"tentacle/te_swing2.wav",
	"weapons/cbar_miss1.wav",
	"weapons/electro4.wav",
	"weapons/mine_charge.wav",
	"weapons/ric1.wav",
	"weapons/ric2.wav",
	"weapons/ric3.wav",
	"weapons/ric4.wav",
	"weapons/ric5.wav",
	"X/x_attack1.wav",
	"X/x_attack2.wav",
	"X/x_attack3.wav",
	"X/x_ballattack1.wav",
	"X/x_die1.wav",
	"X/x_laugh1.wav",
	"X/x_laugh2.wav",
	"X/x_pain1.wav",
	"X/x_pain2.wav",
	"X/x_recharge1.wav",
	"X/x_recharge2.wav",
	"X/x_recharge3.wav",
	"X/x_shoot1.wav",
	"x/x_teleattack1.wav",
	"zombie/claw_miss1.wav",
	"zombie/claw_miss2.wav",
	"zombie/claw_strike1.wav",
	"zombie/claw_strike2.wav",
	"zombie/claw_strike3.wav",
	"zombie/zo_alert10.wav",
	"zombie/zo_alert20.wav",
	"zombie/zo_alert30.wav",
	"zombie/zo_attack1.wav",
	"zombie/zo_attack2.wav",
	"zombie/zo_idle1.wav",
	"zombie/zo_idle2.wav",
	"zombie/zo_idle3.wav",
	"zombie/zo_idle4.wav",
	"zombie/zo_pain1.wav",
	"zombie/zo_pain2.wav"
};

new const g_Sprites[][] = {
	"sprites/animglow01.spr",
	"sprites/bigspit.spr",
	"sprites/exit1.spr",
	"sprites/flare6.spr",
	"sprites/gargeye1.spr",
	"sprites/lgtning.spr",
	"sprites/mommablob.spr",
	"sprites/mommaspit.spr",
	"sprites/mommaspout.spr",
	"sprites/muz4.spr",
	"sprites/muzzleflash3.spr",
	"sprites/nhth1.spr",
	"sprites/shockwave.spr",
	"sprites/tele1.spr",
	"sprites/tinyspit.spr",
	"sprites/xbeam3.spr",
	"sprites/xspark1.spr",
	"sprites/xspark4.spr",
};

new const g_GarbageEntities[][] =
{
	"beam",
	"bmortar",	// the thing that gonarchs throw when attacking
	"env_sprite",
	"gib",
	"weaponbox"
};

new const g_Difficulties[][] = {
	"survival",
	"test",
	"very easy",
	"easy",
	"normal",
	"hard",
	"very hard",
	"elite",
	"insane",
	"nightmare",
	"impossible"
};

new const g_Modes[][] = {
	"fun",
	"competitive"
};

new g_DifficultyStats[][DIFFICULTY] = {
	{0.0, MAX_INT},
	{0.4, 5},
	{0.6, 10},
	{0.8, 10},
	{1.0, 15},
	{1.2, 20},
	{1.4, 25},
	{1.8, 30},
	{2.5, 40},
	{3.0, 50},
	{5.0, 60}
};

new const AUTHOR[]					= "naz";
new const PLUGIN_NAME[]				= "Alien Defense";
new const PLUGIN_TAG[]				= "AD";
new const VERSION[]					= "0.9.3-alpha";

new const NEXUS_NAME[]				= "ad_nexus";
new const WAYPOINTS_FILENAME[]		= "waypoints.ini";
new const WAYPOINTS_A5_FILENAME[]	= "waypoints_a5.ini";
new const ROUNDS_FILENAME[]			= "rounds.ini";
new const PLUGIN_CONFIGS_DIR[]		= "/alien_defense";

new g_ConfigsDir[256];
new g_Map[64];
new g_OriginalHostname[64];

new g_MainMenuItemCallback;
new g_ShopMenuItemCallback;
new g_AdminMenuItemCallback;
//new g_SpawnMenuItemCallback;
//new g_RemoveMenuItemCallback;

// Stores entities with key wp_id and such, so you can create waypoints with VHE/JACK/Sledge, compile map,
// run it and copy the corresponding console output to a waypoints.ini
new g_WaypointsArr[MAX_ENTITIES+1][WAYPOINT];
new Trie:g_Waypoints;
new Trie:g_Gibs; // model_path -> [model_number, material]; e.g.: "models/woodgibs.mdl" -> [2, BREAK_WOOD]
new Trie:g_ShopItems; // name -> price; e.g.: "gauss" -> 150.0
new Trie:g_MonsterData;
new Array:g_MonsterTypesPerRound; // rounds are stored here, and each round is an Array of monsters that will be spawned
new Array:g_MonsterSpawns;
new g_MonsterSpawn[MAX_SPAWNPOINTS]; // to check whether a spawn has been already used by a monster to get spawned
new g_MonsterClass[MAX_ENTITIES+1][MONSTER_DATA];
new g_MonsterPathPoint[MAX_ENTITIES+1][WAYPOINT]; // waypoint where the monster is located
new g_MonsterNextPathPoint[MAX_ENTITIES+1][WAYPOINT]; // waypoint where the monster is going
new Float:g_MonsterFallStartTime[MAX_ENTITIES+1]; // how much time has been falling, to calculate the z-velocity based on gravity
new g_OldEntityState[MAX_ENTITIES+1][ENTITY_STATE]; // info of a entity in its previous frame
new bool:g_isMonsterUnstucking[MAX_ENTITIES+1]; // monsters in the process of getting unstuck
new bool:g_MonsterBeingRemoved[MAX_ENTITIES+1];

new Float:g_GarbageSpawnTime[MAX_ENTITIES+1];

new Float:g_PlayerScore[MAX_PLAYERS+1]; // TODO: this score should be restored when player leaves and rejoins if the same game is still ongoing
new Float:g_PlayerCredits[MAX_PLAYERS+1];
new g_PlayerLastSatchel[MAX_PLAYERS+1]; // last thrown satchel's entity's index

new g_MaxPlayers;
new Array:g_MonstersAlive;
new g_CurrRound;
new g_CurrDifficulty = DEFAULT_DIFFICULTY;
new g_CurrMode = MODE_FUN;
new Float:g_RoundEndTime;
new bool:g_IsAgstartFull;
new g_Nexus;
new g_TaskEntity;
new g_HudEntity;
new g_CheckerEntity;

// TODO: remove this as it's now deprecated with the adstart changes and min. players to agstart
new g_Bot; // a fakeclient to be able to agstart

new g_GameState;
new Float:g_NexusEndHP;

new Float:g_NextSatchelsMsgTime; // cooldown for showing the message about satchel amount in the map

// Vote control
//new Float:g_NextAgVoteMinTime;
//new g_PlayerAgVote[MAX_PLAYERS+1]; // 0 = undecided, 1 = yes, 2 = no
//new bool:g_AgVoteRunning;
new g_NextDifficulty = DEFAULT_DIFFICULTY;

// HUD stuff
new g_HudRGB[3]; // TODO: this should vary depending on difficulty
new g_SyncHudRoundTimeLeft;		// e.g.: "Next round in: 01:04"
new g_SyncHudRoundInfo;			// e.g.: "Hard - Round [7 / 20] - Monsters [24 / 38]"
new g_SyncHudInfoAboveScores;	// e.g.: "Nexus: 910hp (Aegis: 00:04)"
new g_SyncHudScore;				// e.g.: naz - 74084 points
new g_SyncHudAimingInfo;		// e.g.: monster_zombie - HP: 173
new g_SyncHudEnd;

// Game cvars
new pcvar_hostname;
new pcvar_sv_ag_match_running;

// Plugin cvars
new pcvar_ad_setup_time;
new pcvar_ad_base_round_time;
new pcvar_ad_round_time_multiplier;
new pcvar_ad_time_between_waves;
new pcvar_ad_max_monsters_per_round;
new pcvar_ad_nexus_health;
new pcvar_ad_max_satchels;

/////////////////////////////////////////////////////
//	MAIN AMXX HOOKS
/////////////////////////////////////////////////////

public plugin_precache()
{
	for (new i = 0; i < sizeof(g_Models); i++)
		precache_model(g_Models[i]);

	for (new i = 0; i < sizeof(g_Sounds); i++)
		precache_sound(g_Sounds[i]);

	for (new i = 0; i < sizeof(g_Sprites); i++)
		precache_model(g_Sprites[i]);

	g_Gibs = TrieCreate();
	for (new i = 0; i < sizeof(g_GibModels); i++)
	{
		new modelNumber = precache_model(g_GibModels[i]);
		new data[2];
		data[0] = modelNumber;
		data[1] = g_GibMaterials[i];
		TrieSetArray(g_Gibs, g_GibModels[i], data, sizeof(data));
	}

	//g_Waypoints = TrieCreate();
	register_forward(FM_KeyValue, "FwKeyValue");
}

public plugin_init()
{
	server_print("[%s] Initializing plugin...", PLUGIN_TAG);
	register_plugin(PLUGIN_NAME, VERSION, AUTHOR);
	register_cvar("alien_defense_version", VERSION, FCVAR_SPONLY | FCVAR_SERVER | FCVAR_UNLOGGED);

	if (!is_running("ag"))
	{
		new msg[256];
		formatex(msg, charsmax(msg), "[%s] Sorry, this plugin is based on Adrenaline Gamer Mod 6.6 features to run.", PLUGIN_TAG);
		add(msg, charsmax(msg), " It doesn't have an independent system to manage games/matches");
		add(msg, charsmax(msg), " (like agstart/agpause/agabort/agallow commands) yet, so it's unable to run in this mod at the moment.");
		server_print(msg);
		pause("ad");
		return;
	}

	new ag_gamemode[32];
	get_cvar_string("sv_ag_gamemode", ag_gamemode, charsmax(ag_gamemode));
	if (ag_gamemode[0] && !(equali(ag_gamemode, "aliendefense") || equali(ag_gamemode, "adf")))
	{
		server_print("[%s] The %s plugin can only be run in the \"adf\" gamemode.", PLUGIN_TAG, PLUGIN_NAME);
		pause("ad");
		return;
	}
	register_forward(FM_GetGameDescription, "FwGetGameDescriptionPre");

	pcvar_hostname					= get_cvar_pointer("hostname");
	pcvar_sv_ag_match_running		= get_cvar_pointer("sv_ag_match_running");

	pcvar_ad_setup_time				= register_cvar("ad_setup_time", "15.9");
	pcvar_ad_base_round_time		= register_cvar("ad_base_round_time", "30.0");

	// Here waves != rounds. A round can have several waves of monsters,
	// because they may not be able to spawn all at once, so they spawn in different waves,
	// with a much smaller interval than the interval between rounds
	pcvar_ad_time_between_waves		= register_cvar("ad_time_between_waves", "10.0");
	pcvar_ad_max_monsters_per_round	= register_cvar("ad_max_monsters_per_round", "75");
	pcvar_ad_round_time_multiplier	= register_cvar("ad_round_time_multiplier", "2.5");
	pcvar_ad_nexus_health			= register_cvar("ad_nexus_health", "4000.0");
	pcvar_ad_max_satchels			= register_cvar("ad_max_satchels", "40");

	// HL/AG messages
	new msgCountdown	= get_user_msgid("Countdown");
	new msgSettings		= get_user_msgid("Settings");
	new msgVote			= get_user_msgid("Vote");

	register_message(msgCountdown,	"FwMsgCountdown");
	register_message(msgSettings,	"FwMsgSettings");
	register_message(msgVote,		"FwMsgVote");

	configureMonsters();

	register_clcmd("ad_print_target",	"CmdPrintTarget");
	register_clcmd("ad_spawn",			"CmdSpawnMonster",	ADMIN_CFG,	"- spawns a monster by name, e.g: monster_bigmomma, monster_panther, monster_hunter, ...");
	register_clcmd("ad_testround",		"CmdTestRound",		ADMIN_CFG,	"- spawns a monster by name, e.g: monster_bigmomma, monster_panther, monster_hunter, ...");
	//register_clcmd("ad_bot",			"CmdSpawnBot",		ADMIN_CFG,	"- spawns a bot so you can do agstart"); // a fake client to agstart alone
	register_clcmd("ad_start",			"CmdStart",			_,			"- forces agstart when playing alone by spawning and then kicking a bot");
	register_clcmd("adstart",			"CmdStart",			_,			"- forces agstart when playing alone by spawning and then kicking a bot");
	register_clcmd("ad_check",			"CmdCheckGame",		ADMIN_CFG,	"- prints the current game state to console"); // TODO: review if makes sense to be admin-only
	register_clcmd("ad_remove",			"CmdRemoveMonster",	ADMIN_CFG,	"- removes a monster by id (use check_monsters to know ids)");
	register_clcmd("ad_level",			"CmdSetLevel",		ADMIN_CFG,	"- sets difficulty level");
	register_clcmd("ad_dump",			"CmdDumpEntities",	ADMIN_CFG,	"- dumps an entity list to a file in the server");
	register_clcmd("ad_rm",				"CmdRemoveGarbage");

	register_clcmd("say /ad_start",		"CmdStart",			_,			"- alias for agstart normal; that is, start a game in normal difficulty");
	register_clcmd("say ad_start", 		"CmdStart",			_,			"- alias for agstart normal; that is, start a game in normal difficulty");
	register_clcmd("say adstart",		"CmdStart",			_,			"- alias for agstart normal; that is, start a game in normal difficulty");
	register_clcmd("say /unsatchel",	"CmdUnsatchel");
	register_clcmd("say /gauss",		"CmdBuyGauss");
	register_clcmd("say /egon",			"CmdBuyEgon");
	register_clcmd("say /repair",		"CmdNexusRepair");

	register_clcmd("say /menu",			"ShowMainMenu");
	register_clcmd("say /play",			"ShowDifficultyMenu");
	register_clcmd("say /mode",			"ShowModeMenu");
	register_clcmd("say /shop",			"ShowShopMenu");
	register_clcmd("say /admin",		"ShowAdminMenu",	ADMIN_CFG,	"- shows the admin menu");
	register_clcmd("say /spawn",		"ShowSpawnMenu",	ADMIN_CFG,	"- shows the monster spawning menu");
	//register_clcmd("remove_menu",	"ShowRemoveMenu");

	g_MainMenuItemCallback		= menu_makecallback("MainMenuItemCallback");
	g_ShopMenuItemCallback		= menu_makecallback("ShopMenuItemCallback");
	g_AdminMenuItemCallback		= menu_makecallback("AdminMenuItemCallback");
	//g_SpawnMenuItemCallback	= menu_makecallback("SpawnMenuItemCallback");
	//g_RemoveMenuItemCallback	= menu_makecallback("RemoveMenuItemCallback");

	new TrieIter:it = TrieIterCreate(g_MonsterData);
	while (!TrieIterEnded(it))
	{
		new data[MONSTER_DATA];
		TrieIterGetArray(it, data, MONSTER_DATA);

		if (!data[MONSTER_IS_CUSTOM])
		{
			register_think(				data[MONSTER_ENTITY_NAME], "MonsterThink");

			RegisterHam(Ham_TakeDamage,	data[MONSTER_ENTITY_NAME], "FwMonsterTakeDamagePre");
			RegisterHam(Ham_Killed,		data[MONSTER_ENTITY_NAME], "FwMonsterKilledPost", 1);
			RegisterHam(Ham_Blocked,	data[MONSTER_ENTITY_NAME], "FwMonsterBlockedPre");
		} // otherwise the entity name is monster_generic
		TrieIterNext(it);
	}
	TrieIterDestroy(it);

	// For entities that serve to do stuff periodically
	RegisterHam(Ham_Think,					"info_target",		"FwThinkPre");

	// For the nexus
	RegisterHam(Ham_TakeDamage,				"func_breakable",	"FwBreakableTakeDamagePre");
	RegisterHam(Ham_Killed,					"func_breakable",	"FwBreakableDestroyedPre");
	RegisterHam(Ham_Killed,					"player",			"FwPlayerDeath");

	RegisterHam(Ham_Weapon_PrimaryAttack,	"weapon_satchel",	"FwThrowSatchelPre");
	RegisterHam(Ham_Weapon_SecondaryAttack,	"weapon_satchel",	"FwThrowSatchel2Pre");
	RegisterHam(Ham_Spawn,					"monster_satchel",	"FwSatchelSpawnPost", 1);

	register_forward(FM_ShouldCollide,	"FwShouldCollide");
	register_forward(FM_RemoveEntity,	"FwEntityRemovalPost", 1);

	for (new i = 0; i < sizeof(g_GarbageEntities); i++)
	{
		if (!equal(g_GarbageEntities[i], "gib")) // Ham doesn't recognize this class
			RegisterHam(Ham_Spawn, g_GarbageEntities[i], "FwGarbageSpawnPost", 1);
	}

	g_MaxPlayers = get_maxplayers();

	g_TaskEntity	= engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	g_HudEntity		= engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	g_CheckerEntity	= engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));

	set_pev(g_TaskEntity,		pev_classname, engfunc(EngFunc_AllocString, "timer_entity"));
	set_pev(g_HudEntity,		pev_classname, engfunc(EngFunc_AllocString, "hud_entity"));
	set_pev(g_CheckerEntity,	pev_classname, engfunc(EngFunc_AllocString, "checker_entity"));

	set_pev(g_TaskEntity,		pev_nextthink, get_gametime() + 1.01);
	set_pev(g_HudEntity,		pev_nextthink, get_gametime() + 1.01);
	set_pev(g_CheckerEntity,	pev_nextthink, get_gametime() + 3.01);

	g_SyncHudRoundTimeLeft		= CreateHudSyncObj();
	g_SyncHudRoundInfo			= CreateHudSyncObj();
	g_SyncHudInfoAboveScores	= CreateHudSyncObj();
	g_SyncHudScore				= CreateHudSyncObj();
	g_SyncHudAimingInfo			= CreateHudSyncObj();
	g_SyncHudEnd				= CreateHudSyncObj();

	configureServer();

	// TODO: change these colors depending on the difficulty
	g_HudRGB[0] = 255;
	g_HudRGB[1] = 160;
	g_HudRGB[2] = 0;
}

public plugin_cfg()
{
	get_mapname(g_Map, charsmax(g_Map));
	strtolower(g_Map);

	server_print("[%s] Configuring plugin...", PLUGIN_TAG);
	get_configsdir(g_ConfigsDir, charsmax(g_ConfigsDir));
	add(g_ConfigsDir, charsmax(g_ConfigsDir), PLUGIN_CONFIGS_DIR);
	if (!dir_exists(g_ConfigsDir))
		mkdir(g_ConfigsDir);

	g_MonstersAlive = ArrayCreate(1);

	initNexus();

	loadWaypoints();
	loadRounds();
	loadShop();

	// Store spawn points in an array to stress less the machine at expense of memory
	g_MonsterSpawns = ArrayCreate(WAYPOINT);
	new TrieIter:it = TrieIterCreate(g_Waypoints);
	while (!TrieIterEnded(it))
	{
		new waypoint[WAYPOINT];
		TrieIterGetArray(it, waypoint, WAYPOINT);

		if ((waypoint[WP_FLAGS] & WP_SPAWN) && ArraySize(g_MonsterSpawns) < MAX_SPAWNPOINTS)
			ArrayPushArray(g_MonsterSpawns, waypoint);

		TrieIterNext(it);
	}
	TrieIterDestroy(it);

	get_pcvar_string(pcvar_hostname, g_OriginalHostname, charsmax(g_OriginalHostname));
}

public plugin_end()
{
	TrieDestroy(g_Waypoints);
	TrieDestroy(g_ShopItems);
	TrieDestroy(g_MonsterData);
	ArrayDestroy(g_MonsterTypesPerRound);
	ArrayDestroy(g_MonstersAlive);
	ArrayDestroy(g_MonsterSpawns);
}

public client_putinserver(id)
{
	set_task(1.20, "InitPlayer", id + TASKID_INIT_PLAYER);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	g_PlayerScore[id] = 0.0;
	g_PlayerCredits[id] = 0.0;
	g_PlayerLastSatchel[id] = 0;
}

public FwKeyValue(ent, kvd)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED;

	getMapWaypoints(ent, kvd);
	return FMRES_IGNORED;
}

public InitPlayer(taskId)
{
	new id = taskId - TASKID_INIT_PLAYER;
	ShowMainMenu(id);
}

// Gets and stores waypoints that were created directly in the map (compiled with them)
// to be later output to console and be able to copy them to a waypoints.ini
getMapWaypoints(ent, kvd)
{
	new keyName[32];
	get_kvd(kvd, KV_KeyName, keyName, charsmax(keyName));

	// TODO: try to improve this code, doesn't seem rightly - to go like it
	if (equal(keyName, "wp_id"))
	{
		new value[32], Float:origin[3];
		get_kvd(kvd, KV_Value, value, charsmax(value));
		pev(ent, pev_origin, origin);

		copy(g_WaypointsArr[ent][WP_ID], 17, value);
		g_WaypointsArr[ent][WP_ORIGIN][0] = origin[0];
		g_WaypointsArr[ent][WP_ORIGIN][1] = origin[1];
		g_WaypointsArr[ent][WP_ORIGIN][2] = origin[2] - 15.0;
	}
	else if (equal(keyName, "wp_weight_nexus"))
	{
		new value[12];
		get_kvd(kvd, KV_Value, value, charsmax(value));

		g_WaypointsArr[ent][WP_WEIGHT_NEXUS] = str_to_num(value);
	}
	else if (equal(keyName, "wp_weight_take_cover"))
	{
		new value[12];
		get_kvd(kvd, KV_Value, value, charsmax(value));

		g_WaypointsArr[ent][WP_WEIGHT_TAKE_COVER] = str_to_num(value);
	}
	else if (equal(keyName, "wp_flags"))
	{
		new value[12];
		get_kvd(kvd, KV_Value, value, charsmax(value));

		g_WaypointsArr[ent][WP_FLAGS] = str_to_num(value);
	}
	else if (equal(keyName, "wp_neighbours"))
	{
		new nb[17];
		new neighbours[sizeof(nb) * MAX_WAYPOINT_NEIGHBOURS];
		get_kvd(kvd, KV_Value, neighbours, charsmax(neighbours));

		new Array:nbs = ArrayCreate(sizeof(nb), MAX_WAYPOINT_NEIGHBOURS);
		new isSplit = strtok2(neighbours, nb, charsmax(nb), neighbours, charsmax(neighbours), ',', 1); // trim just in case
		while (isSplit > -1)
		{
			ArrayPushString(nbs, nb);

			nb[0] = EOS; // clear the string just in case
			isSplit = strtok2(neighbours, nb, charsmax(nb), neighbours, charsmax(neighbours), ',', 1);
		}
		ArrayPushString(nbs, nb); // push the last neighbour waypoint into the array

		g_WaypointsArr[ent][WP_NEIGHBOURS] = nbs; // save the neighbours into the waypoint
	}
}

configureServer()
{
	server_print("[%s] Setting commands...", PLUGIN_TAG);

	server_cmd("mp_allowmonsters 1"); // necessary for the default AI of HL monsters to work, and for correct hitboxes
	//server_cmd("mp_timelimit 0"); // commented out as it won't let players do agstart if no timelimit set
	//server_cmd("mp_teamplay 131072");
	server_cmd("mp_teamplay 1");
	server_cmd("mp_forcerespawn 1");

	server_cmd("ag_gauss_fix 1");
	server_cmd("ag_rpg_fix 1");

	server_cmd("sv_ag_start_minplayers 1");
	server_cmd("sv_ag_allow_vote 1");
	server_cmd("sv_ag_vote_start 1");
}

insertMonsterData(monsterType[], monsterModel[], Float:damage, Float:health, Float:speed, bool:isCustom, bool:isAirborne)
{
	new data[MONSTER_DATA];
	copy(data[MONSTER_ENTITY_NAME], charsmax(data[MONSTER_ENTITY_NAME]), monsterType);
	copy(data[MONSTER_MODEL], charsmax(data[MONSTER_MODEL]), monsterModel);
	data[MONSTER_DAMAGE] = damage;
	data[MONSTER_HEALTH] = health;
	data[MONSTER_SPEED] = speed;
	data[MONSTER_IS_CUSTOM] = isCustom;
	data[MONSTER_IS_AIRBORNE] = isAirborne;
	TrieSetArray(g_MonsterData, data[MONSTER_ENTITY_NAME], data, sizeof(data));
}

configureMonsters()
{
	server_print("[%s] Configuring monsters...", PLUGIN_TAG);
	g_MonsterData = TrieCreate();

	/* ----- HL default monsters ----- */
	//					entity name					model path					damage	health	speed	custom 	airborne
	insertMonsterData("monster_alien_controller",	"models/controller.mdl",	30.0,	240.0,	160.0,	false, true);
	insertMonsterData("monster_alien_grunt",		"models/agrunt.mdl",		30.0,	320.0,	230.0,	false, false);
	insertMonsterData("monster_alien_slave",		"models/islave.mdl",		15.0,	120.0,	260.0,	false, false);
	insertMonsterData("monster_bigmomma",			"models/big_mom.mdl",		240.0,	3200.0,	260.0,	false, false);
	insertMonsterData("monster_bloater",			"models/floater.mdl",		25.0,	200.0,	170.0,	false, true);
	insertMonsterData("monster_bullchicken",		"models/bullsquid.mdl",		35.0,	280.0,	260.0,	false, false);
	insertMonsterData("monster_flyer_flock",		"models/boid.mdl",			15.0,	120.0,	200.0,	false, true);
	insertMonsterData("monster_gargantua",			"models/garg.mdl",			150.0,	1000.0,	200.0,	false, false);
	insertMonsterData("monster_headcrab",			"models/headcrab.mdl",		10.0,	80.0,	300.0,	false, false);
	insertMonsterData("monster_houndeye",			"models/houndeye.mdl",		15.0,	110.0,	240.0,	false, false);
	insertMonsterData("monster_nihilanth",			"models/nihilanth.mdl",		500.0,	8000.0,	80.0,	false, true);
	insertMonsterData("monster_tentacle",			"models/tentacle2.mdl",		250.0,	4000.0,	80.0,	false, false);
	insertMonsterData("monster_zombie",				"models/zombie.mdl",		20.0,	175.0,	250.0,	false, false);
	// This one is just for compatibility with checks that exist through the code, doesn't hurt to have 1 extra thing
	insertMonsterData("monster_generic",			"models/zombie.mdl",		20.0,	175.0,	250.0,	false, false);

	/* ----- Custom monsters ----- */
	insertMonsterData("monster_aflock",				"models/aflock.mdl",		20.0,	160.0,	220.0,	true, true);
	//insertMonsterData("monster_charger",			"models/charger.mdl",		15.0,	110.0,	250.0,	true, false);
	//insertMonsterData("monster_chumtoad",			"models/chumtoad.mdl",		10.0,	95.0,	240.0,	true, false);
	insertMonsterData("monster_friendly",			"models/friendly.mdl",		40.0,	450.0,	240.0,	true, false);
	//insertMonsterData("monster_gasbag",				"models/gasbag.mdl",		20.0,	280.0,	160.0,	true, true);
	insertMonsterData("monster_hunter",				"models/hunter.mdl",		40.0,	500.0,	280.0,	true, false);
	insertMonsterData("monster_kingpin",			"models/kingpin.mdl",		35.0,	320.0,	260.0,	true, false);
	insertMonsterData("monster_pantagruel",			"models/pantagruel.mdl",	180.0,	1600.0,	170.0,	true, false);
	insertMonsterData("monster_panther",			"models/panther.mdl",		25.0,	250.0,	400.0,	true, false);
	//insertMonsterData("monster_protozoa",			"models/protozoa.mdl",		10.0,	210.0,	180.0,	true, true);
	//insertMonsterData("monster_redheadcrab",		"models/redheadcrab.mdl",	10.0,	110.0,	260.0,	true, false);
	//insertMonsterData("monster_snapbug",			"models/snapbug.mdl",		15.0,	95.0,	280.0,	true, false);
	//insertMonsterData("monster_sqknest",			"models/w_sqknest.mdl",		20.0,	190.0,	190.0,	true, false);
}

loadWaypoints()
{
	for (new i = 0; i < sizeof(g_WaypointsArr); i++)
	{
		if (!g_WaypointsArr[i][WP_ID][0])
			continue;

		new buffer[604];
		formatex(buffer, charsmax(buffer), "%s %.1f %.1f %.1f %d %d %d",
			g_WaypointsArr[i][WP_ID],
			g_WaypointsArr[i][WP_ORIGIN][0], g_WaypointsArr[i][WP_ORIGIN][1], g_WaypointsArr[i][WP_ORIGIN][2],
			g_WaypointsArr[i][WP_WEIGHT_NEXUS], g_WaypointsArr[i][WP_WEIGHT_TAKE_COVER],
			g_WaypointsArr[i][WP_FLAGS]);

		if (g_WaypointsArr[i][WP_NEIGHBOURS])
		{
			add(buffer, charsmax(buffer), " ");
			for (new j = 0; j < ArraySize(g_WaypointsArr[i][WP_NEIGHBOURS]); j++)
			{
				new neighbour[17];
				ArrayGetString(g_WaypointsArr[i][WP_NEIGHBOURS], j, neighbour, charsmax(neighbour));
				add(buffer, charsmax(buffer), neighbour);

				if (j < ArraySize(g_WaypointsArr[i][WP_NEIGHBOURS]) - 1)
					add(buffer, charsmax(buffer), ",");
			}
		}
		server_print(buffer);
	}

	new waypointsFilePath[256];
	// TODO: stop hardcoding map waypoints
	if (equali(g_Map, "ag_defense_a2", 13) || equali(g_Map, "ag_defense_a3", 13))
		formatex(waypointsFilePath, charsmax(waypointsFilePath), "%s/%s", g_ConfigsDir, WAYPOINTS_FILENAME);
	else
		formatex(waypointsFilePath, charsmax(waypointsFilePath), "%s/%s", g_ConfigsDir, WAYPOINTS_A5_FILENAME);
	new file = fopen(waypointsFilePath, "rt");
	if (!file)
	{
		if (equali(g_Map, "ag_defense_a5", 13))
			server_print("[%s] Couldn't read the %s configuration file, you need to provide a correct file for this plugin to work", PLUGIN_TAG, WAYPOINTS_A5_FILENAME);
		else
			server_print("[%s] Couldn't read the %s configuration file, you need to provide a correct file for this plugin to work", PLUGIN_TAG, WAYPOINTS_FILENAME);

		pause("ad");
		return;
	}

	g_Waypoints = TrieCreate();
	new buffer[1024], waypoint[WAYPOINT];
	while (!feof(file))
	{
		fgets(file, buffer, charsmax(buffer));
		if (!strlen(buffer))
			continue;

		new id[17], originX[24], originY[24], originZ[24], weightNexus[12], weightTakeCover[12], flags[11], neighbours[256];

		parse(buffer,
			id, charsmax(id),
			originX, charsmax(originX), originY, charsmax(originY), originZ, charsmax(originZ),
			weightNexus, charsmax(weightNexus), weightTakeCover, charsmax(weightTakeCover),
			flags, charsmax(flags),
			neighbours, charsmax(neighbours));

		copy(waypoint[WP_ID], charsmax(waypoint[WP_ID]), id);
		waypoint[WP_ORIGIN][0]			= str_to_float(originX);
		waypoint[WP_ORIGIN][1]			= str_to_float(originY);
		waypoint[WP_ORIGIN][2]			= str_to_float(originZ);
		waypoint[WP_WEIGHT_NEXUS]		= str_to_num(weightNexus);
		waypoint[WP_WEIGHT_TAKE_COVER]	= str_to_num(weightTakeCover);
		waypoint[WP_FLAGS]				= str_to_num(flags);

		new Array:nbs = ArrayCreate(sizeof(id)), nb[sizeof(id)];
		new isSplit = strtok2(neighbours, nb, charsmax(nb), neighbours, charsmax(neighbours), ',', 1); // trim just in case
		while (isSplit > -1)
		{
			ArrayPushString(nbs, nb);

			nb[0] = EOS; // clear the string just in case
			isSplit = strtok2(neighbours, nb, charsmax(nb), neighbours, charsmax(neighbours), ',', 1);
		}
		ArrayPushString(nbs, nb); // push the last neighbour waypoint into the array

		waypoint[WP_NEIGHBOURS] = nbs; // save the neighbours into the waypoint

		// FIXME: avoid unnecessary redundancy, the WP_ID is now both in the key and in the value
		TrieSetArray(g_Waypoints, waypoint[WP_ID], waypoint, sizeof(waypoint));
	}
	server_print("[%s] Loaded %d waypoints from %s", PLUGIN_TAG, TrieGetSize(g_Waypoints), waypointsFilePath);
}

loadRounds()
{
	new roundsFilePath[256];
	formatex(roundsFilePath, charsmax(roundsFilePath), "%s/%s", g_ConfigsDir, ROUNDS_FILENAME);
	new file = fopen(roundsFilePath, "rt");
	if (!file)
	{
		server_print("[%s] Couldn't read the %s configuration file, you need to provide a correct file for this plugin to work", PLUGIN_TAG, ROUNDS_FILENAME);
		pause("ad");
		return;
	}

	g_MonsterTypesPerRound = ArrayCreate();

	new buffer[2048];
	new round = 0;
	while (!feof(file))
	{
		fgets(file, buffer, charsmax(buffer));
		if (!strlen(buffer))
			continue;

		if (equal(buffer, ";", 1))
			continue;

		new Array:monstersArr = ArrayCreate(32);

		new monsterType[24], fullMonsterType[32];
		new isSplit = strtok2(buffer, monsterType, charsmax(monsterType), buffer, charsmax(buffer), ',', 1);
		new j = 0; // avoid infinite loop, very annoying
		while (isSplit > -1 && j <= get_pcvar_num(pcvar_ad_max_monsters_per_round))
		{
			formatex(fullMonsterType, charsmax(fullMonsterType), "monster_%s", monsterType);
			ArrayPushString(monstersArr, fullMonsterType);

			monsterType[0] = EOS; // clear the string just in case

			isSplit = strtok2(buffer, monsterType, charsmax(monsterType), buffer, charsmax(buffer), ',', 1);
			j++;
		}
		// monsterType was written with the remaining text, which is another monster, so push it into the array
		trim(monsterType);
		formatex(fullMonsterType, charsmax(fullMonsterType), "monster_%s", monsterType);
		ArrayPushString(monstersArr, fullMonsterType);

		ArrayPushCell(g_MonsterTypesPerRound, monstersArr);
		round++;
	}
	server_print("[%s] Loaded %d rounds from %s", PLUGIN_TAG, round, roundsFilePath);
}

loadShop()
{
	g_ShopItems = TrieCreate();

	// Weapons:
	TrieSetCell(g_ShopItems, "egon", 100.0);
	TrieSetCell(g_ShopItems, "gauss", 90.0);

	// Other:
	TrieSetCell(g_ShopItems, "repair", 2500.0);
}

initNexus()
{
	g_Nexus = find_ent_by_tname(0, NEXUS_NAME);
	if (!pev_valid(g_Nexus))
	{
		server_print("[%s] There's no entity named %s in this map. Cannot run the %s mod.", PLUGIN_TAG, NEXUS_NAME, PLUGIN_NAME);
		pause("a");
		return;
	}

	new className[32];
	pev(g_Nexus, pev_classname, className, charsmax(className));
	if (!equal(className, "func_breakable"))
	{
		// TODO: review if it's really necessary to be func_breakable to be able to take damage
		server_print("[%s] There Nexus is not of type func_breakable. Cannot run the %s mod.", PLUGIN_TAG, PLUGIN_NAME);
		pause("a");
		return;
	}

	set_pev(g_Nexus, pev_takedamage, DAMAGE_NO);
	set_pev(g_Nexus, pev_max_health, 10000.0);
	set_pev(g_Nexus, pev_health, get_pcvar_float(pcvar_ad_nexus_health));

	set_pev(g_Nexus, pev_renderamt, 255);
	set_pev(g_Nexus, pev_rendermode, 0); // Normal mode
	set_pev(g_Nexus, pev_solid, SOLID_BSP);

	new Float:origin[3];
	pev(g_Nexus, pev_origin, origin);
	server_print("[%s] The Nexus is at pos{%.2f, %.2f, %.2f}", PLUGIN_TAG, origin[0], origin[1], origin[2]);
}

/////////////////////////////////////////////////////
//	FORWARDS
/////////////////////////////////////////////////////

// Called every second during the agstart countdown
public FwMsgCountdown(id, dest, ent)
{
	static count, sound, player1[32], player2[32];
	count = get_msg_arg_int(1);
	sound = get_msg_arg_int(2);
	get_msg_arg_string(3, player1, charsmax(player1));
	get_msg_arg_string(4, player2, charsmax(player2));

	if (count >= 9)
	{
		g_GameState = GAME_STARTING;

		new hostname[64], difficultyName[32];
		formatex(difficultyName, charsmax(difficultyName), g_Difficulties[g_CurrDifficulty]);
		ucfirst(difficultyName);

		formatex(hostname, charsmax(hostname), "%s | Level: %s - Starting game...",
			g_OriginalHostname, difficultyName);
		set_pcvar_string(pcvar_hostname, hostname);

		resetMenus();
	}

	server_print("[%.4f] Countdown::id=%d,dest=%d,ent=%d,c=%d,snd=%d,p1=%s,p2=%s",
		get_gametime(), id, dest, ent, count, sound, player1, player2);

	if (count != -1 || sound != 0)
		return;

	if (pev_valid(g_Bot))
		set_pev(g_Bot, pev_flags, pev(g_Bot, pev_flags) | FL_KILLME);

	initGame();
}

public FwMsgSettings(id, dest, ent)
{
	static isMatch/*, gameMode[32], timeLimit, fragLimit, friendlyFire, weaponStay, agVersion[32], wallgauss[32], headshot[32], blastRadius[32]*/;
	isMatch = get_msg_arg_int(1);
	if (!isMatch)
	{
		new oldGameState = g_GameState;
		g_GameState = GAME_IDLE;
		set_pcvar_string(pcvar_hostname, g_OriginalHostname);

		if (oldGameState != GAME_IDLE) // avoid resetting on first call at around 7 seconds after a changelevel
			resetMenus();
	}
	//else if (g_CurrMode == MODE_COMPETITIVE)
	//	prepareCompetitive();

	server_print("[%.4f] Settings::id=%d,dest=%d,ent=%d,isMatch=%d", get_gametime(), id, dest, ent, isMatch);
}

public FwMsgVote(id)
{
	static status, yes, no, undecided, setting[32], value[32], caller[32];
	status		= get_msg_arg_int(1);
	yes			= get_msg_arg_int(2);
	no			= get_msg_arg_int(3);
	undecided	= get_msg_arg_int(4);
	get_msg_arg_string(5, setting,	charsmax(setting));
	get_msg_arg_string(6, value,	charsmax(value));
	get_msg_arg_string(7, caller,	charsmax(caller));
/*
	if (status == AGVOTE_CALLED)
		g_AgVoteRunning = true;
	else
		g_AgVoteRunning = false;
*/
/*	// Not really working, only for the vote HUD
	if (containi(value, g_Modes[MODE_COMPETITIVE]) != -1 && containi(value, "full") != -1)
	{ // Remove 'full' argument
		replace(value, charsmax(value), "full", "");
		set_msg_arg_string(6, value);
	}
*/
	server_print("[%.4f] Vote::id=%d,status=%d,yes=%d,no=%d,n/a=%d,k=%s,v=%s,caller=%s",
		get_gametime(), id, status, yes, no, undecided, setting, value, caller);

	if (equali(setting, "agstart") && status == AGVOTE_ACCEPTED)
	{
		if (g_GameState == GAME_RUNNING) // new agstart without aborting the currently ongoing game
			clearGame();

		if (containi(value, g_Modes[MODE_COMPETITIVE]) != -1)
			g_CurrMode = MODE_COMPETITIVE;
		else
			g_CurrMode = MODE_FUN;

		g_IsAgstartFull = bool:(containi(value, "full") != -1);

		for (new i = 0; i < sizeof(g_Difficulties); i++)
		{
			if (containi(value, g_Difficulties[i]) != -1)
			{
				// FIXME: Hack for 'very hard' to not be matched with 'hard'
				if (equali(g_Difficulties[i], "hard") && containi(value, "very hard") != -1)
					continue; // the next one will match with the actual 'very hard', due to array order

				g_NextDifficulty = i;
				break;
			}
		}
		//g_NextAgVoteMinTime = get_gametime();
		g_CurrDifficulty = g_NextDifficulty;
		g_NextDifficulty = DEFAULT_DIFFICULTY;
		//resetAgVotes();

		new difficulty[32];
		formatex(difficulty, charsmax(difficulty), g_Difficulties[g_CurrDifficulty]);
		ucfirst(difficulty);
		client_print(0, print_chat, "[%s] Starting a %s game. Have fun!", PLUGIN_TAG, difficulty);

		server_print("[%.4f] Vote:AgStart::value=%s,difficulty=%d,mode=%d", get_gametime(), value, g_CurrDifficulty, g_CurrMode);

		if (g_CurrMode == MODE_COMPETITIVE && g_IsAgstartFull)
		{
			// Someone's trying to trick the system... we'll restart now without 'full' as we're in competitive
			server_cmd("agabort");
			server_exec();

			replace(value, charsmax(value), "full", "");
			server_cmd("agstart \"%s\"", value);
			server_exec();

			return;
		}
	}
}

public FwGetGameDescriptionPre()
{
	new ver[36];
	formatex(ver, charsmax(ver), "%s v%s", PLUGIN_NAME, VERSION);
	server_print("[%s] Changing game description to '%s'", PLUGIN_TAG, ver);
	forward_return(FMV_STRING, ver);

	return FMRES_SUPERCEDE;
}

public FwBreakableTakeDamagePre(id, attackerWeapon, attacker, Float:damage, damageType)
{
	if (id == g_Nexus)
	{
		new Float:remainingHealth, Float:realDamage = damage;
		pev(id, pev_health, remainingHealth);

		if (isPlayer(attacker))
		{
			if (get_user_weapon(attacker) == HLW_CROWBAR)
			{ // FIXME: crossbow's attack1 also has double damage...
				realDamage *= 2.0;
			}
		
			// Attacking the Nexus means a punishment, you lose x10 the damage you dealt to it
			// It won't affect player credits, those remain the same
			g_PlayerScore[attacker] -= realDamage * 20.0;

			if (realDamage >= remainingHealth || remainingHealth <= 0.0)
			{
				// TODO: change this when monsters have enough AI to attack the nexus
				new playerName[32];
				get_user_name(attacker, playerName, charsmax(playerName));
				server_print("The Nexus has been destroyed by %s", playerName);

				nexusDestroyed();
				return HAM_SUPERCEDE;
			}
		}
	}

	return HAM_HANDLED;
}

// Using Pre 'cos in Post it may be unreliable, pev_health will return the max_health if it died
public FwMonsterTakeDamagePre(id, attackerWeapon, attacker, Float:damage, damageType)
{
	//server_print("[%.4f] FwMonsterTakeDamagePre(id=%d)", get_gametime(), id);
	if (pev_valid(id))
	{
		new Float:remainingHealth;
		pev(id, pev_health, remainingHealth);

		new hs = get_pdata_int(id, 90); // head hit group (headshot)

		if (isPlayer(attacker))
		{
			if (hs == 1)
			{
				g_PlayerScore[attacker] += damage * 1.25; // +25% points reward for headshooting
				g_PlayerCredits[attacker] += damage * 1.25 * POINTS_TO_CREDITS_FACTOR;
			}
			else
			{
				g_PlayerScore[attacker] += damage;
				g_PlayerCredits[attacker] += damage * POINTS_TO_CREDITS_FACTOR;
			}
		}

		if (damage >= remainingHealth || remainingHealth <= 0.0)
		{
			if (isPlayer(attacker))
				ExecuteHam(Ham_AddPoints, attacker, 1, false);
			
			new className[32];
			pev(id, pev_classname, className, charsmax(className));
			if (equal(className, "monster_bigmomma") && !g_MonsterBeingRemoved[id])
			{
				// The fucker won't die when blocked, will stay at 0.01 hp, so this snippet fixes the issue
				g_MonsterBeingRemoved[id] = true;
				ExecuteHamB(Ham_TakeDamage, id, 0, 0, 32000.0, DMG_SLASH);
				ExecuteHamB(Ham_Killed, id, 0, 1);
			}
		}
	}
}

public FwBreakableDestroyedPre(id, attacker, shouldGib)
{
	if (id == g_Nexus)
	{
		server_print("The Nexus has been destroyed");
		nexusDestroyed();

		return HAM_SUPERCEDE;
	}
	return HAM_HANDLED;
}

public FwPlayerDeath(id, attacker, shouldGib)
{
	if (pev_valid(id) && isPlayer(id))
	{
		new Array:toRemove = ArrayCreate();

		new ent = FM_NULLENT;
		while (ent = find_ent_by_class(ent, "monster_satchel"))
		{
			new ownerId = pev(ent, pev_owner);
			if (id == ownerId)
				ArrayPushCell(toRemove, ent);
		}

		ent = FM_NULLENT;
		while (ent = find_ent_by_class(ent, "monster_satchelcharge"))
		{
			new ownerId = pev(ent, pev_owner);
			if (id == ownerId)
				ArrayPushCell(toRemove, ent);
		}

		for (new i = 0; i < ArraySize(toRemove); i++)
		{
			new entToRemove = ArrayGetCell(toRemove, i);
			if (pev_valid(entToRemove))
			{
				// Removing player satchels manually because when hooking satchel attack,
				// there must be a bug or something that makes satchels not being removed
				// by the game. For secondary attack it can be fixed returning HAM_HANDLED,
				// but if you hook the primary attack it doesn't matter what you return,
				// the game won't remove the satchels if you drop the satchels before dying
				server_print("[%s] Removing player #%d's satchel entity #%d due to death", PLUGIN_TAG, id, entToRemove);
				remove_entity(entToRemove);
			}
		}
		g_PlayerLastSatchel[id] = 0;

		resetMenu(id);
	}
}

// Satchel primary attack
public FwThrowSatchelPre(weaponId)
{
	new ent = FM_NULLENT, satchelCount = 0;
	while(ent = find_ent_by_class(ent, "monster_satchelcharge"))
		satchelCount++;

	ent = FM_NULLENT;
	while(ent = find_ent_by_class(ent, "monster_satchel"))
		satchelCount++;

	new maxSatchels = get_pcvar_num(pcvar_ad_max_satchels);
	new ownerId = pev(weaponId, pev_owner);
	new weaponModel2[32];
	pev(ownerId, pev_weaponmodel2, weaponModel2, charsmax(weaponModel2));
	if (equali(weaponModel2, "models/p_satchel.mdl"))
	{
		if (satchelCount >= maxSatchels)
		{
			client_print(ownerId, print_chat, "[%s] Sorry, can't put any more satchels because there are already %d in the map.", PLUGIN_TAG, maxSatchels);
			
			return HAM_SUPERCEDE;
		}

		if (g_NextSatchelsMsgTime <= get_gametime())
		{
			g_NextSatchelsMsgTime = get_gametime() + 0.2;

			new players[MAX_PLAYERS], playersNum;
			get_players_ex(players, playersNum, GetPlayers_ExcludeBots);
			for (new i = 0; i < playersNum; i++)
				console_print(players[i], "[%s] There are [%d/%d] satchels in the map now.", PLUGIN_TAG, satchelCount+1, maxSatchels);
		}
	}
	else if ((equali(weaponModel2, "models/p_satchel_radio.mdl")))
	{
		// Satchel radio, which upon primary attack means that all this player's satchels have exploded, so reset this
		g_PlayerLastSatchel[ownerId] = 0;
	}

	return HAM_HANDLED;
}

// Satchel secondary attack
public FwThrowSatchel2Pre(weaponId)
{
	new ent = FM_NULLENT, satchelCount = 0;
	while(ent = find_ent_by_class(ent, "monster_satchelcharge"))
		satchelCount++;

	ent = FM_NULLENT;
	while(ent = find_ent_by_class(ent, "monster_satchel"))
		satchelCount++;

	new maxSatchels = get_pcvar_num(pcvar_ad_max_satchels);
	new ownerId = pev(weaponId, pev_owner);
	if (satchelCount >= maxSatchels)
	{
		client_print(ownerId, print_chat, "[%s] Sorry, can't put any more satchels because there are already %d in the map.", PLUGIN_TAG, maxSatchels);

		// Avoid throwing the satchel
		return HAM_SUPERCEDE;
	}
	server_print("[%s] There are [%d/%d] satchels in the map now.", PLUGIN_TAG, satchelCount+1, maxSatchels);

	return HAM_HANDLED; // to avoid losing satchels placed on the map upon death
}

public FwSatchelSpawnPost(id)
{
	if (pev_valid(id))
	{
		new ownerId = pev(id, pev_owner);
		g_PlayerLastSatchel[ownerId] = id;

		if (g_CurrMode == MODE_COMPETITIVE)
			set_pev(id, pev_solid, SOLID_NOT);
		else
			set_pev(id, pev_solid, SOLID_BBOX);
	}
}

public FwGarbageSpawnPost(id)
{
	if (id && pev_valid(id))
	{
		g_GarbageSpawnTime[id] = get_gametime();
		//set_task(GARBAGE_REMOVAL_TIME, "RemoveGarbage", TASKID_GARBAGE_REMOVAL + id);
	}
}

public RemoveGarbage(taskId)
{
	new id = taskId - TASKID_GARBAGE_REMOVAL;

	if (!id || !pev_valid(id))
		return;

	new className[32], ownerClassName[32];
	pev(id, pev_classname, className, charsmax(className));
	new ownerId = pev(id, pev_owner);
	if (ownerId)
		pev(ownerId, pev_classname, ownerClassName, charsmax(ownerClassName));

	//remove_entity(id);
	set_pev(id, pev_flags, pev(id, pev_flags) | FL_KILLME);

	server_print("[%s] Removing garbage: %s #%d has been removed (owner: %s #%d)",
		PLUGIN_TAG, className, id, ownerClassName, ownerId);
}

public FwShouldCollide(id1, id2)
{
	if (id1 && id2 && pev_valid(id1) && pev_valid(id2))
	{
		new className1[32];
		pev(id1, pev_classname, className1, charsmax(className1));

		if (TrieKeyExists(g_MonsterData, className1))
		{
			new className2[32];
			pev(id2, pev_classname, className2, charsmax(className2));

			if (TrieKeyExists(g_MonsterData, className2))
			{
				//server_print("#%d %s is colliding with #%d %s", id1, className1, id2, className2);
				return FMRES_SUPERCEDE; // don't collide
			}
		}
	}
	return FMRES_IGNORED;
}

public FwEntityRemovalPost(id)
{
	if (!id || !pev_valid(id))
		return;

	new className[32];
	pev(id, pev_classname, className, charsmax(className));
	for (new i = 0; i < sizeof(g_GarbageEntities); i++)
	{
		if (equal(g_GarbageEntities[i], className))
		{
			server_print("Entity %s #%d has been removed by the game. (life=%.1fs)", className, id, get_gametime() - g_GarbageSpawnTime[i]);
			//remove_task(GARBAGE_REMOVAL_TIME + id);
			g_GarbageSpawnTime[i] = 0.0;
			return;
		}
	}
}

public FwMonsterKilledPost(id, attacker, shouldGib)
{
	//server_print("[%.4f] FwMonsterKilledPost()", get_gametime());
	set_pev(id, pev_flags, pev(id, pev_flags) | FL_KILLME);

	flushMonster(id);
	new index = ArrayFindValue(g_MonstersAlive, id);
	if (index > -1)
	{
		server_print("[%s] Removing from alive monster #%d", PLUGIN_TAG, id);
		ArrayDeleteItem(g_MonstersAlive, index);
	}
	
	new className[32];
	pev(id, pev_classname, className, charsmax(className));
	if (equal(className, "monster_bigmomma"))
		set_task(0.15, "RemoveGonarch", TASKID_GONARCH_REMOVAL + id);
 
	return HAM_HANDLED;
}

public RemoveGonarch(taskId)
{
	new id = taskId - TASKID_GONARCH_REMOVAL;
	server_print("[%s] Removing gonarch #%d", PLUGIN_TAG, id);
	remove_entity(id);
}

public FwMonsterBlockedPre(id, other)
{
	if (g_isMonsterUnstucking[id])
		return;

	new otherClassName[32];
	pev(other, pev_classname, otherClassName, charsmax(otherClassName));

	if (pev_valid(id))
	{
		if (other == 0 /*worldspawn*/ || equal(otherClassName, "monster_satchel") || equal(otherClassName, "monster_tripmine"))
			set_task(random_float(0.1, 0.8), "UnstuckEntity", TASKID_UNSTUCK_ENTITY + id);
		else // blocked with another monster probably
			set_task(random_float(1.1, 2.8), "UnstuckEntityWithMonster", TASKID_UNSTUCK_ENTITY_WITH_MONSTER + id);

		g_isMonsterUnstucking[id] = true;
	}
}

/////////////////////////////////////////////////////
//	COMMANDS
/////////////////////////////////////////////////////
/*
spawnBot()
{
	if (g_Bot)
	{
		server_cmd("kick #%d \"Another bot spawned.\"", get_user_userid(g_Bot));
		server_exec();
		g_Bot = 0;
	}

	g_Bot = engfunc(EngFunc_CreateFakeClient, "AD Bot");
	if (g_Bot)
	{
		engfunc(EngFunc_FreeEntPrivateData, g_Bot);

		new ptr[128], ip[64];
		get_cvar_string("ip", ip, charsmax(ip));
		dllfunc(DLLFunc_ClientConnect, g_Bot, "AD Bot", ip, ptr);
		dllfunc(DLLFunc_ClientPutInServer, g_Bot);
	}
	return g_Bot;
}

public CmdSpawnBot(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
		spawnBot();

	return PLUGIN_HANDLED;
}
*/
public CmdStart(id)
{
	// This has to be done after taking args, otherwise they
	// will get replaced with the args of the kick command
	if (g_Bot)
	{
		server_cmd("kick #%d \"Voting agstart.\"", get_user_userid(g_Bot));
		server_exec();
		g_Bot = 0;
	}

	client_cmd(id, "callvote \"agstart\" \"normal fun full\"");

	return PLUGIN_HANDLED;
}

public CmdUnsatchel(id)
{
	if (g_PlayerLastSatchel[id] && pev_valid(g_PlayerLastSatchel[id]))
	{
		remove_entity(g_PlayerLastSatchel[id]);
		g_PlayerLastSatchel[id] = 0;
	}
	else
		client_print(id, print_chat, "[%s] You can only remove your last placed satchel. Once removed, you can't remove one again until you place another one.", PLUGIN_TAG);

	return PLUGIN_HANDLED;
}

public CmdDumpEntities(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_CONTINUE;

	dumpEntities();

	return PLUGIN_HANDLED;
}

dumpEntities()
{
	new dumpPath[256];
	formatex(dumpPath, charsmax(dumpPath), "%s/dump_%s_%d_%d.log",
		g_ConfigsDir, g_Map, g_CurrRound, floatround((get_gametime() * 1000.0)));

	new file = fopen(dumpPath, "wt");
	if (!file)
	{
		server_print("Failed to write dump log file (\"%s\")", dumpPath);
		return;
	}

	for (new i = 0; i < MAX_ENTITIES + 1; i++)
	{
		if (pev_valid(i))
		{
			new className[32];
			pev(i, pev_classname, className, charsmax(className));

			fprintf(file, "%d %s\n", i, className);
		}
		else
			fprintf(file, "%d Invalid\n", i);
	}
	fclose(file);
}

/*
countAgVotes(voteType)
{
	new result;

	for (new i = 1; i <= g_MaxPlayers; i++)
	{
		if (g_PlayerAgVote[i] == voteType)
			result++;
	}

	return result;
}

resetAgVotes()
{
	// TODO: check that player indexes really go from 1 to 32 inclusive
	for (new i = 1; i <= g_MaxPlayers; i++)
		g_PlayerAgVote[i] = AGVOTE_UNDECIDED;
}
*/

public CmdNexusRepair(id)
{
	new Float:price;
	TrieGetCell(g_ShopItems, "repair", price);

	if (g_PlayerCredits[id] >= price)
	{
		if (repairNexus(id))
			g_PlayerCredits[id] -= price;
	}
	else
		client_print(id, print_chat, "[%s] Sorry, you need %d credits to restore %dhp of the Nexus.",
			PLUGIN_TAG, floatround(price), floatround(nexusHealthPerRepair(), floatround_floor));

	return PLUGIN_HANDLED;
}

public CmdBuyEgon(id)
{
	buyWeapon(id, "egon");
	return PLUGIN_HANDLED;
}

public CmdBuyGauss(id)
{
	buyWeapon(id, "gauss");
	return PLUGIN_HANDLED;
}

buyWeapon(id, weapon[])
{
	new Float:price;
	TrieGetCell(g_ShopItems, weapon, price);

	if (g_PlayerCredits[id] >= price)
	{
		if (giveWeapon(id, weapon))
			g_PlayerCredits[id] -= price;
	}
	else
		client_print(id, print_chat, "[%s] Sorry, you need %d credits to buy %s.", PLUGIN_TAG, floatround(price), weapon);
}

public CmdCheckGame(id)
{
	new Float:nexusHP;
	pev(g_Nexus, pev_health, nexusHP);

	console_print(id, "[%s] Current game info:", PLUGIN_TAG);
	console_print(id, " - Game state: %s",			g_GameStateString[g_GameState]);
	console_print(id, " - Round: %d / %d",			g_CurrRound, g_DifficultyStats[g_CurrDifficulty][DIFFICULTY_ROUNDS]);
	console_print(id, " - Difficulty: %d",			g_CurrDifficulty);
	console_print(id, " - Current time: %.3fs",		get_gametime());
	console_print(id, " - Round end time: %.3fs",	g_RoundEndTime);
	console_print(id, " - Nexus HP: %.2f / %.2f",	nexusHP, get_pcvar_float(pcvar_ad_nexus_health));

	new monstersAlive = ArraySize(g_MonstersAlive);
	if (monstersAlive == 0)
		console_print(id, " - Monsters: no monsters alive");
	else
	{
		console_print(id, " - Monsters: %d", monstersAlive);
		for (new i = 0; i < monstersAlive; i++)
		{
			new monster = ArrayGetCell(g_MonstersAlive, i);
			if (!pev_valid(monster))
			{
				console_print(id, " ... #%d is not valid", monster);
				continue;
			}

			new className[32], Float:origin[3], Float:velocity[3], Float:playerOrigin[3], Float:hp;
			pev(monster, pev_classname, className, charsmax(className));
			pev(monster, pev_origin, origin);
			pev(monster, pev_velocity, velocity);
			pev(monster, pev_health, hp);
			pev(id, pev_origin, playerOrigin);
			console_print(id, " ... %s #%d (%.1fhp) at pos{%.1f, %.1f, %.1f}, speed{%.1f, %.1f, %.1f}u/s... distance to you: %.1f",
				 className, monster, hp, origin[0], origin[1], origin[2], velocity[0], velocity[1], velocity[2], get_distance_f(playerOrigin, origin));
		}
	}

	new players[MAX_PLAYERS], playersNum;
	get_players_ex(players, playersNum);
	console_print(id, " - Players: %d", playersNum);
	console_print(id, " - Scores:");
	for (new i = 0; i < playersNum; i++)
	{
		new pid = players[i];
		new Float:score = g_PlayerScore[pid];
		new playerName[33];
		get_user_name(pid, playerName, charsmax(playerName));
		console_print(id, " ... - %s: %.2f points", playerName, score);
	}
	console_print(id, " - Credits:");
	for (new i = 0; i < playersNum; i++)
	{
		new pid = players[i];
		new Float:credits = g_PlayerCredits[pid];
		new playerName[33];
		get_user_name(pid, playerName, charsmax(playerName));
		console_print(id, " ... - %s: %.2f credits", playerName, credits);
	}

	new full[32];
	read_argv(1, full, charsmax(full));

	if (equali(full, "full"))
	{
		new ent = g_MaxPlayers + 1;
		while((ent = find_ent_in_sphere(ent, Float:{0.0, 0.0, 0.0}, 8192.0)))
		{
			if (pev_valid(ent))
			{
				new className[32], Float:origin[3];
				pev(ent, pev_classname, className, charsmax(className));
				console_print(id, "#%d %s at {%.1f, %.1f, %.1f}", ent, className, origin[0], origin[1], origin[2]);
			}
			else
				console_print(id, "#%d exists but is invalid", ent);
		}
	}
	return PLUGIN_HANDLED;
}

// First use CheckGameStatus to know the ids of monsters you want to remove
public CmdRemoveMonster(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		new arg[5], monsterId;
		read_argv(1, arg, charsmax(arg));
		monsterId = str_to_num(arg);

		if (!pev_valid(monsterId))
		{
			console_print(id, "[%s] Sorry, the specified monster doesn't seem to exist.", PLUGIN_TAG);
			return PLUGIN_HANDLED;
		}

		new className[32];
		pev(monsterId, pev_classname, className, charsmax(className));

		new monster = removeMonster(monsterId);
		if (monster < 0)
		{
			console_print(id, "[%s] Sorry, the specified monster couldn't be found.", PLUGIN_TAG);
			return PLUGIN_HANDLED;
		}
		server_print("[%s] %s #%d has been removed", PLUGIN_TAG, className, monsterId);
	}
	return PLUGIN_HANDLED;
}

public CmdSetLevel(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		g_NextDifficulty = DEFAULT_DIFFICULTY;

		// Check the arguments to set the difficulty
		new arg1[32], arg2[32], fullArg[64];
		read_argv(1, arg1, charsmax(arg1)); // e.g.: very
		read_argv(2, arg2, charsmax(arg2)); // e.g.: hard
		if (arg2[0])
			formatex(fullArg, charsmax(fullArg), "%s %s", arg1, arg2);
		else
			formatex(fullArg, charsmax(fullArg), arg1);

		for (new i = 0; i < sizeof(g_Difficulties); i++)
		{
			if (equali(g_Difficulties[i], fullArg))
				g_NextDifficulty = i;
		}
		g_CurrDifficulty = g_NextDifficulty;
	}
	return PLUGIN_HANDLED;
}

// Play the first round just for testing or learning purposes
public CmdTestRound(id)
{
	g_CurrRound = read_argv_int(1);

	if (g_CurrRound < 1)
		g_CurrRound = 1;

	g_CurrDifficulty = DIFFICULTY_TEST;
	new maxRound = g_DifficultyStats[g_CurrDifficulty][DIFFICULTY_ROUNDS];

	if (g_CurrRound > maxRound)
		g_CurrRound = maxRound;

	clearHUD();

	// Reset spawn points
	for (new i = 0; i < sizeof(g_MonsterSpawn) - 1; i++)
		g_MonsterSpawn[i] = 0;

	new Array:monstersArr = ArrayGetCell(g_MonsterTypesPerRound, g_CurrRound-1);
	new monstersAmt = ArraySize(monstersArr);
	if (monstersAmt)
	{
		// Spawn as many monsters as indicated for this round
		// There may not be enough spawnpoints for all the monsters in this round, so we divide them into different waves,
		// with some time between waves so they spawn and move on without blocking the spawnpoints for the next wave of monsters
		new spawnWaves = floatround(float(monstersAmt) / float(MAX_SPAWNPOINTS), floatround_ceil);
		// TODO: improve this, I don't like some many tasks being spawned at once
		for (new i = 0; i < spawnWaves; i++)
			set_task(i * get_pcvar_float(pcvar_ad_time_between_waves), "SpawnMonstersWave", TASKID_SPAWN_MONSTER_WAVE + i);
	}
	return PLUGIN_HANDLED;
}

// Prints the id of the specified monster's target (enemy)
public CmdPrintTarget(id)
{
	console_print(id, "Printing monster debug info...");
	new monster = read_argv_int(1);
	if (pev_valid(monster))
	{
		ExecuteHam(Ham_CheckEnemy, monster, 1);
		ExecuteHam(Ham_ReportAIState, monster);
		console_print(id, "Ideal state: %d", ExecuteHam(Ham_GetIdealState, monster));
		console_print(id, "BestVisibleEnemy: %d", ExecuteHam(Ham_BestVisibleEnemy, monster));
	}
	else
		console_print(id, "[%d] Sorry, the monster you're trying to check (id=%d) doesn't exist.", PLUGIN_TAG, monster);

	return PLUGIN_HANDLED;
}

public CmdSpawnMonster(id)
{
	new arg[32];
	read_argv(1, arg, charsmax(arg));

	spawnMonster(id, arg);

	return PLUGIN_HANDLED;
}

public CmdRemoveGarbage(id)
{
	new count;
	for (new i = 0; i <= MAX_ENTITIES; i++)
	{
		if (i && pev_valid(i))
		{
			new className[32];
			pev(i, pev_classname, className, charsmax(className));

			for (new j = 0; j < sizeof(g_GarbageEntities); j++)
			{
				if (equal(className, g_GarbageEntities[j]))
				{
					// TODO: refactor
					if (equal(className, "gib"))
					{
						server_print("> rm #%d %s", i, className);
						set_pev(i, pev_flags, pev(g_Bot, pev_flags) | FL_KILLME);
						g_GarbageSpawnTime[i] = 0.0;
						count++;
					}
					else
					{
						new Float:entityRemovalLifeThreshold = 120.0;
						new Float:life = get_gametime() - g_GarbageSpawnTime[i];
						if (equal(className, "env_sprite"))
							entityRemovalLifeThreshold = 360.0;

						if (life >= entityRemovalLifeThreshold)
						{
							server_print("> rm #%d %s (life=%.1fs)", i, className, life);
							set_pev(i, pev_flags, pev(g_Bot, pev_flags) | FL_KILLME);
							g_GarbageSpawnTime[i] = 0.0;
							count++;
						}
						else
							server_print("Won't remove entity #%d %s (life=%.1fs) 'cos it has less than %.1fs life",
								i, className, life, entityRemovalLifeThreshold);
					}

					break;
				}
			}
		}
	}
	console_print(id, "[%s] %d trash entities removed.", PLUGIN_TAG, count);

	return PLUGIN_HANDLED;
}

/////////////////////////////////////////////////////
//	TASKS
/////////////////////////////////////////////////////

public SpawnMonstersWave(taskId)
{
	//server_print("[%.4f] SpawnMonstersWave()", get_gametime());
	new waveNum = taskId - TASKID_SPAWN_MONSTER_WAVE;
	new fromMonster = waveNum * MAX_SPAWNPOINTS;
	new toMonster = (waveNum+1) * MAX_SPAWNPOINTS;

	new roundIndex = g_CurrRound;
	if (roundIndex > ArraySize(g_MonsterTypesPerRound))
	{
		// TODO: finish implementing Survival level... when the round is too high, I'm just taking monsters
		// from the last round that has monsters defined
		roundIndex = ArraySize(g_MonsterTypesPerRound);
	}

	new Array:monstersArr = ArrayGetCell(g_MonsterTypesPerRound, roundIndex-1);
	new monstersAmt = ArraySize(monstersArr);
	if (monstersAmt)
	{
		if (toMonster > monstersAmt)
			toMonster = monstersAmt;

		server_print("wave: %d, range: %d-%d", waveNum, fromMonster, toMonster-1);
		for (new i = fromMonster; i < toMonster; i++)
		{
			new monsterType[32];
			ArrayGetArray(monstersArr, i, monsterType);
			spawnMonster(0, monsterType);
		}
	}
}

public StartRound(taskId)
{
	//server_print("[%.4f] StartRound()", get_gametime());

	if (g_GameState != GAME_RUNNING)
		return;

	g_CurrRound++;

	//removeGarbage();

	// Spawn as many monsters as indicated for this round
	new Array:monstersArr = ArrayGetCell(g_MonsterTypesPerRound, g_CurrRound-1);
	new monstersAmt = ArraySize(monstersArr);
	if (monstersAmt)
	{
		// There may not be enough spawnpoints for all the monsters in this round, so we divide them into different waves,
		// with some time between waves so they spawn and move on without blocking the spawnpoints for the next wave of monsters
		new spawnWaves = floatround(float(monstersAmt) / float(MAX_SPAWNPOINTS), floatround_ceil);
		new Float:timeBetweenWaves = get_pcvar_float(pcvar_ad_time_between_waves);

		// TODO: improve this, I don't like that many tasks being spawned at once
		new i;
		for (i = 0; i < spawnWaves; i++)
			set_task(i * timeBetweenWaves, "SpawnMonstersWave", TASKID_SPAWN_MONSTER_WAVE + i);

		new totalRounds = g_DifficultyStats[g_CurrDifficulty][DIFFICULTY_ROUNDS];
		server_print("current round: %d", g_CurrRound);
		if (g_CurrRound < totalRounds)
		{
			new Float:baseRoundTime = get_pcvar_float(pcvar_ad_base_round_time);
			new Float:roundTimeMult = get_pcvar_float(pcvar_ad_round_time_multiplier);
			new Float:playerFactor = floatlog(EULER2 - 1.0 + float(getPlayingPlayersNum()) * 0.9, EULER2);
			if (playerFactor < 1.0)
			{
				// e.g.: when a player agstarts, then leaves and comes back for the round start,
				// that round's time would get increased! so with this check we avoid that exploit
				playerFactor = 1.0;
			}

			new Float:roundDuration = (baseRoundTime + float(g_CurrRound) * roundTimeMult) / playerFactor;
			g_RoundEndTime = get_gametime() + roundDuration;
			set_task(roundDuration, "StartRound", TASKID_START_ROUND + g_CurrRound);
		}
		else
		{
			// This time will serve to check if we are able to win the game in the last round,
			// otherwise it's an autowin when it's the last round but monster still haven't spawned (alive: 0),
			// so it the win time has to be at least later than this one, when all monsters already spawned
			g_RoundEndTime = get_gametime() + (i * timeBetweenWaves) + 1.0;
		}
	}
}

/*
removeGarbage()
{
	//server_print("[%.4f] removeGarbage()", get_gametime());
	for (new i = 0; i < MAX_ENTITIES; i++)
	{
		if (pev_valid(i))
		{
			new className[32];
			pev(i, pev_classname, className, charsmax(className));

			if (equal(className, "env_sprite")
				|| equal(className, "beam")
				|| equal(className, "weaponbox")) // TODO: make a cvar to decide whether to remove weaponbox or not
				remove_entity(i);
		}
	}
}
*/

getPlayingPlayersNum()
{
	new result = 0;

	new players[MAX_PLAYERS], playersNum;
	get_players_ex(players, playersNum, GetPlayers_ExcludeHLTV);
	for (new i = 0; i < playersNum; i++)
	{
		if (!isSpectator(players[i])) // ignore spectators
			result++; 
	}

	return result;
}

// TODO: refactor functions
public UnstuckEntity(taskId)
{
	new id = taskId - TASKID_UNSTUCK_ENTITY;

	if (!pev_valid(id))
		return;

	new Float:origin[3], Float:velocity[3];
	pev(id, pev_origin, origin);
	pev(id, pev_velocity, velocity);

	if (velocity[2] < MAX_ACCUMULATED_UNSTUCK_VELOCITY)
	{
		velocity[0] += random_float(-150.0, 150.0);
		velocity[1] += random_float(-150.0, 150.0);
		velocity[2] += random_float(100.0, 500.0);

		set_pev(id, pev_origin, origin);
		set_pev(id, pev_velocity, velocity);
		g_isMonsterUnstucking[id] = false;
	}
}

// TODO: refactor functions
public UnstuckEntityWithMonster(taskId)
{
	new id = taskId - TASKID_UNSTUCK_ENTITY_WITH_MONSTER;

	if (!pev_valid(id))
		return;

	new Float:origin[3], Float:velocity[3];
	pev(id, pev_origin, origin);
	pev(id, pev_velocity, velocity);

	if (velocity[2] < 500.0)
	{
		velocity[0] += random_float(-300.0, 300.0);
		velocity[1] += random_float(-300.0, 300.0);
		velocity[2] += random_float(100.0, 500.0);

		getNextWaypoint(g_MonsterPathPoint[id], g_MonsterNextPathPoint[id]);

		set_pev(id, pev_origin, origin);
		set_pev(id, pev_velocity, velocity);
		g_isMonsterUnstucking[id] = false;
	}
}

public ResetMonsterSpawn(taskId)
{
	// TODO: avoid using a task for this
	new idx = taskId - TASKID_RESET_MONSTER_SPAWN;
	g_MonsterSpawn[idx] = 0;
}

/////////////////////////////////////////////////////
//	THINKS (Forwards / Game logic)
/////////////////////////////////////////////////////

public FwThinkPre(id)
{
	if (id == g_HudEntity)		FwHudThinkPre(id);
	if (id == g_TaskEntity)		FwInfoThinkPre(id);
	if (id == g_CheckerEntity)	FwCheckerThinkPre(id);

	return HAM_HANDLED;
}

public FwHudThinkPre(id)
{
	set_hudmessage(80, 240, 0, _, _, 1, 2.0, 6.0, 0.1, 0.4, -1);
	if (g_GameState == GAME_RUNNING)
	{
		updateHUD();
	}
	else if (g_GameState == GAME_IDLE)
	{
		if (floatround(get_gametime(), floatround_floor) % 7 == 0) // every 7 seconds
		{
			set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.16, 2, 1.0, 5.0, 0.1, 0.4, -1);
			ShowSyncHudMsg(0, g_SyncHudRoundTimeLeft, "-- Type or say adstart to play! --");
		}
	}
	else if (g_GameState == GAME_DEFEAT || g_GameState == GAME_VICTORY)
	{
		set_pcvar_string(pcvar_hostname, g_OriginalHostname);
		endHudMessage();
	}
	set_pev(id, pev_nextthink, get_gametime() + 0.1);
	return HAM_HANDLED;
}

public FwInfoThinkPre(id)
{
	if (g_GameState == GAME_RUNNING)
	{
		if (g_Bot)
		{
			server_cmd("kick #%d \"Game started.\"", get_user_userid(g_Bot));
			g_Bot = 0;
		}

		if (!get_pcvar_num(pcvar_sv_ag_match_running))
		{
			// Game has been aborted
			server_print("Game aborted");
			server_cmd("agabort");
			server_exec();
			g_GameState = GAME_ABORTED;
			clearGame();
		}
		else
		{
			new maxRound = g_DifficultyStats[g_CurrDifficulty][DIFFICULTY_ROUNDS];
			if (g_CurrRound == maxRound && ArraySize(g_MonstersAlive) == 0 && g_RoundEndTime <= get_gametime())
			{
				gameWon();
			}
		}
	}
	set_pev(id, pev_nextthink, get_gametime() + 0.1);
	return HAM_HANDLED;
}

public FwCheckerThinkPre(id)
{
	// Checks that the monsters array has valid monsters,
	// because sometimes upon death or reaching nexus they don't get removed
	for (new i = 0; i < ArraySize(g_MonstersAlive); i++)
	{
		new className[32];
		new monster = ArrayGetCell(g_MonstersAlive, i);
		pev(monster, pev_classname, className, charsmax(className));

		if (!TrieKeyExists(g_MonsterData, className))
		{
			// It's not any of the monsters that we use in this game, so get the fuck out of here non-monster thingy
			server_print("[%s] Data integrity error: #%d %s is not an AD-registered monster", PLUGIN_TAG, monster, className);
		}
	}
	set_pev(id, pev_nextthink, get_gametime() + 3.0);
	return HAM_HANDLED;
}

// TODO: try and refactor this function
getNextWaypoint(curr[WAYPOINT], next[WAYPOINT], wpToAvoid[]="")
{
	if (!curr[WP_NEIGHBOURS])
		return;

	new smallestWeight, biggestWeight, sum4thRoots, Float: chancesSum;
	new Array:neighbours = curr[WP_NEIGHBOURS];
	new Array:neighbourWaypoints = ArrayCreate(WAYPOINT, 8);
	new Array:neighbourChances = ArrayCreate(1, 8);

	// 1. Get the smallest weight to calculate everything based on new weights starting from 1
	for (new i = 0; i < ArraySize(neighbours); i++)
	{
		// TODO: take into account land/fly when there are flying monsters and airborne waypoints
		// TODO: take into account WEIGHT_TAKE_COVER
		// TODO: check what other things are missing here
		new id[17], neighbour[WAYPOINT];
		ArrayGetString(neighbours, i, id, charsmax(id));
		if (TrieGetArray(g_Waypoints, id, neighbour, WAYPOINT))
		{
			if (neighbour[WP_FLAGS] & WP_JUMP_FROM)
				continue; // not implemented yet

			if (wpToAvoid[0] && equal(neighbour[WP_ID], wpToAvoid))
				continue; // don't retreat to the same waypoint you're coming from

			ArrayPushArray(neighbourWaypoints, neighbour);

			new weightNexus = neighbour[WP_WEIGHT_NEXUS];
			if (smallestWeight == 0 || smallestWeight > weightNexus)
				smallestWeight = weightNexus;

			if (biggestWeight == 0 || biggestWeight < weightNexus)
				biggestWeight = weightNexus;
		}
		else
			server_print("Waypoint %s has a bad neighbour (or none at all!) with id \"%s\", you may want to fix it", curr[WP_ID], id);
	}
	if (ArraySize(neighbourWaypoints) == 1)
	{
		ArrayGetArray(neighbourWaypoints, 0, next);
		return;
	}

	// 2. Get the sum of all WEIGHT_NEXUS 4th roots
	for (new i = 0; i < ArraySize(neighbourWaypoints); i++)
	{
		new neighbour[WAYPOINT];
		ArrayGetArray(neighbourWaypoints, i, neighbour);

		new weightNexus = (neighbour[WP_WEIGHT_NEXUS] - smallestWeight) + 1;
		if (neighbour[WP_WEIGHT_NEXUS] == biggestWeight)
			weightNexus += 10; // increase even more chances of getting picked, 'cos some monsters are still retreating a lot

		sum4thRoots += weightNexus * weightNexus * weightNexus * weightNexus;
	}

	// 3. Now calculate what chance each one has of being picked
	for (new i = 0; i < ArraySize(neighbourWaypoints); i++)
	{
		new neighbour[WAYPOINT];
		ArrayGetArray(neighbourWaypoints, i, neighbour);

		// TODO: refactor, DRY
		new weightNexus = (neighbour[WP_WEIGHT_NEXUS] - smallestWeight) + 1;
		if (neighbour[WP_WEIGHT_NEXUS] == biggestWeight)
			weightNexus += 10;

		new Float:chance = ((weightNexus * weightNexus * weightNexus * weightNexus) / float(sum4thRoots));
		chancesSum += chance;
		chance = chancesSum; // this is because later we will check whether a random number is less than or equal to this

		ArrayPushCell(neighbourChances, chance); // TODO: check if this has the same order as the neighbourWaypoints array
	}

	// 4. Now pick one of the neighbours based on the chance and a random number
	new Float:rand = random_float(0.00, 1.00);
	for (new i = 0; i < ArraySize(neighbourChances); i++)
	{
		new Float:chance = ArrayGetCell(neighbourChances, i);
		if (rand <= chance)
		{
			ArrayGetArray(neighbourWaypoints, i, next);
			return;
		}
	}
}

public MonsterThink(id)
{
	if (pev_valid(id))
	{
		new currWaypoint[WAYPOINT], nextWaypoint[WAYPOINT];
		TrieGetArray(g_Waypoints, g_MonsterPathPoint[id][WP_ID], currWaypoint, WAYPOINT);
		nextWaypoint = g_MonsterNextPathPoint[id];

		if (nextWaypoint[WP_ID][0])
		{
			new Float:currPos[3], Float:nextPoint[3];
			pev(id, pev_origin, currPos);
			
			currPos[2] += 2.0; // this is because when tracing to the below brush, sometimes it doesn't find anything
			xs_vec_copy(nextWaypoint[WP_ORIGIN], nextPoint);

			new Float:distanceXY = floatsqroot((currPos[0]-nextPoint[0]) * (currPos[0]-nextPoint[0]) + (currPos[1]-nextPoint[1]) * (currPos[1]-nextPoint[1]));
			if (distanceXY <= WAYPOINT_DISTANCE_THRESHOLD)
			{
				// Advanced to the next point, so we update it
				getNextWaypoint(nextWaypoint, g_MonsterNextPathPoint[id], g_MonsterPathPoint[id][WP_ID]);
				g_MonsterPathPoint[id] = nextWaypoint;

				if (nextWaypoint[WP_FLAGS] & WP_NEXUS_ATTACK_MELEE)
				{
					monsterReachedNexus(id);
					return;
				}

				// Do this function again with the updated path point
				MonsterThink(id);
				return;
			}

			new Float:belowOrigin[3], Float:belowNormal[3];
			getNormalPlaneRelativeToPlayer(id, currPos, Float:{0.0, 0.0, -9999.0}, belowOrigin, belowNormal); // direction: below player
			new Float:distanceToFloor = get_distance_f(currPos, belowOrigin);

			currPos[2] -= 2.0;

			new bool:isOnRamp = belowNormal[0] < 0.0 || belowNormal[1] < 0.0;

			new Float:aimAngles[3];
			getAnglesToTarget(id, nextPoint, aimAngles);

			new Float: oldVelocity[3], Float:velocity[3];
			xs_vec_copy(g_OldEntityState[id][ENT_VELOCITY], oldVelocity);
			xs_vec_copy(aimAngles, velocity);
			engfunc(EngFunc_MakeVectors, velocity);
			global_get(glb_v_forward, velocity);
			xs_vec_mul_scalar(velocity, getMonsterSpeed(id), velocity);
			velocity[2] = oldVelocity[2];

			new Float:prevPos[3];
			xs_vec_copy(g_OldEntityState[id][ENT_ORIGIN], prevPos);

			aimAngles[0] = 0.0;
			set_pev(id, pev_angles, aimAngles);
			xs_vec_copy(aimAngles, g_OldEntityState[id][ENT_ANGLES]);

			// Apply gravity to this monster
			new Float:currTime = get_gametime();
			if ((prevPos[2] > currPos[2] || distanceToFloor >= TOUCH_GROUND_DISTANCE))
			{
				if (!g_MonsterFallStartTime[id] || g_MonsterFallStartTime[id] == 0.0)
				{
					// We assume it started falling in the previous frame
					g_MonsterFallStartTime[id] = currTime - getFrameTime(DEFAULT_MONSTER_FRAMETIME);
				}

				// Calculate z-velocity at this point of time since the fall started
				new Float:diffTime = currTime - g_MonsterFallStartTime[id];

				new Float:gravity, Float:pGravity, Float:svGravity, Float:oldGravityVelocity;
				svGravity = get_cvar_float("sv_gravity");
				pev(id, pev_gravity, pGravity);
				gravity = pGravity * svGravity;
				oldGravityVelocity = g_OldEntityState[id][ENT_GRAVITY_VELOCITY];
				// TODO: save gravity velocity as a negative value?
				new Float:zVelocity = (gravity * diffTime);

				// Cancel previous velocity's gravity effect, and add the new effect taking into account this point in time
				velocity[2] = velocity[2] + oldGravityVelocity - zVelocity;

				g_OldEntityState[id][ENT_GRAVITY_VELOCITY] = zVelocity;

				if (g_isMonsterUnstucking[id])
					g_isMonsterUnstucking[id] = false;
				
			}
			else
			{
				g_MonsterFallStartTime[id] = 0.0;

				// Stop ignoring gravity in the next frame
				g_OldEntityState[id][ENT_GRAVITY_VELOCITY] = 0.0;

				if (velocity[2] < 0.0)
				{
					// TODO: Review this: if it stopped falling, just cancel any negative z-velocity?
					velocity[2] = 0.0;
				}

				// Some monsters need help to climb ramps
				if (isOnRamp)
				{
					new className[32];
					pev(id, pev_classname, className, charsmax(className));

					if (!g_isMonsterUnstucking[id] && equali(className, "monster_headcrab"))
					{
						set_task(random_float(0.1, 0.8), "UnstuckEntity", TASKID_UNSTUCK_ENTITY + id);
						g_isMonsterUnstucking[id] = true;
					}
				}

				// 5% chance of moving randomly and 1.5% chance of jumping in some random direction
				if (!g_isMonsterUnstucking[id])
				{
					new Float:rn = random_float(0.01, 1.00);
					if (rn <= 0.025)
					{
						velocity[0] += random_float(-200.0, 200.0);
						velocity[1] += random_float(-200.0, 200.0);
					}
					else if (rn <= 0.05)
					{
						velocity[0] += random_float(-400.0, 400.0);
						velocity[1] += random_float(-400.0, 400.0);
					}
					else if (rn <= 0.065)
					{
						velocity[0] += random_float(-200.0, 200.0);
						velocity[1] += random_float(-200.0, 200.0);
						velocity[2] += random_float( 100.0, 350.0);
					}
				}
			}

			if (!g_isMonsterUnstucking[id]
				&& get_distance_f(prevPos, currPos) < MOVEMENT_BLOCKED_THRESHOLD
				&& distanceToFloor < TOUCH_GROUND_DISTANCE)
			{
				set_task(random_float(0.1, 0.8), "UnstuckEntity", TASKID_UNSTUCK_ENTITY + id);
				g_isMonsterUnstucking[id] = true;
			}

			if (currPos[2] > -600.0)
			{
				new className[32];
				pev(id, pev_classname, className, charsmax(className));
				server_print("[%s] %s #%d is flying at {%.1f, %.1f, %.1f}u/s", PLUGIN_TAG, className, id, velocity[0], velocity[1], velocity[2]);
			}

			new flags = pev(id, pev_flags);
			set_pev(id, pev_velocity, velocity);
			xs_vec_copy(velocity, g_OldEntityState[id][ENT_VELOCITY]);

			new Float:animFrameRate = 1.0 / getWorkloadIndex();
			set_pev(id, pev_framerate, animFrameRate);

			xs_vec_copy(currPos, g_OldEntityState[id][ENT_ORIGIN]);
			g_OldEntityState[id][ENT_GAMETIME] = currTime;
			g_OldEntityState[id][ENT_FLAGS] = flags;

			if (isStuckAboveSky(currPos))
			{
				server_print("[%s] Removing monster #%d from the freaking SKY... yeah, gotta fix monsters ending up there", PLUGIN_TAG, id);
				removeMonster(id);
				return;
			}

			set_pev(id, pev_nextthink, currTime + getFrameTime(DEFAULT_MONSTER_FRAMETIME));
		}
	}
}

/////////////////////////////////////////////////////
//	GAME LOGIC
/////////////////////////////////////////////////////

initGame()
{
	g_GameState = GAME_RUNNING;

	flushGame();
	initNexus();
	set_pev(g_Nexus, pev_takedamage, DAMAGE_YES);

	//if (g_CurrMode == MODE_COMPETITIVE)
	//	prepareCompetitive();

	if (g_SyncHudEnd) 
		ClearSyncHud(0, g_SyncHudEnd);

	new Float:setupTime = get_pcvar_float(pcvar_ad_setup_time);
	g_RoundEndTime = get_gametime() + setupTime;

	new hostname[64], difficultyName[32];
	formatex(difficultyName, charsmax(difficultyName), g_Difficulties[g_CurrDifficulty]);
	ucfirst(difficultyName);

	formatex(hostname, charsmax(hostname), "%s | Level: %s - Preparing...", g_OriginalHostname, difficultyName);
	set_pcvar_string(pcvar_hostname, hostname);

	set_task(setupTime, "StartRound", TASKID_START_ROUND);
}

prepareCompetitive()
{
	new players[MAX_PLAYERS], playersNum;
	get_players(players, playersNum, "c");
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];
		if (isSpectator(id)) // TODO: check agstart with 'nolock' argument
			continue;

		new hasStripped = hl_strip_user_weapons(id);

		server_print("weapon stripped for player #%d? %d", id, hasStripped);
	}
}

resetMenus()
{
	new players[MAX_PLAYERS], playersNum;
	get_players(players, playersNum, "c");
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];
		resetMenu(id);
	}
}

resetMenu(id)
{
	new _dummy, menu;
	player_menu_info(id, _dummy, menu);
	server_print("initGame :: id=%d, menu=%d", id, menu);

	if (menu > -1)
	{
		menu_destroy(menu);
		server_print("menu destroyed, menu=%d", menu);

		// TODO: maybe show the menu that they were previously managing instead of the main menu
		ShowMainMenu(id);
	}
}

// Returns the monster id or 0 if couldn't be created
spawnMonster(id, monsterType[])
{
	new monster, data[MONSTER_DATA];
	if (TrieGetArray(g_MonsterData, monsterType, data, sizeof(data)))
	{
		if (data[MONSTER_IS_CUSTOM])
		{
			monster = create_entity("monster_generic");
			entity_set_model(monster, data[MONSTER_MODEL]);
		}
		else
			monster = create_entity(monsterType);

		flushMonster(monster);
		TrieGetArray(g_MonsterData, monsterType, g_MonsterClass[monster], sizeof(g_MonsterClass[]));
	}
	else
	{
		new msg[80];
		formatex(msg, charsmax(msg), "[%s] Couldn't spawn monster of type \"%s\"", PLUGIN_TAG, monsterType);
		if (id)
			console_print(id, msg);
		else
			server_print(msg);

		return 0;
	}

	new randomNum = random_num(0, ArraySize(g_MonsterSpawns) - 1);

	// Select a spawn point that has not been already taken
	while (g_MonsterSpawn[randomNum] != 0)
		randomNum = random_num(0, ArraySize(g_MonsterSpawns) - 1);

	set_task(2.5, "ResetMonsterSpawn", randomNum + TASKID_RESET_MONSTER_SPAWN);

	new waypoint[WAYPOINT], Float:randomSpawnPoint[3];
	ArrayGetArray(g_MonsterSpawns, randomNum, waypoint);
	xs_vec_copy(waypoint[WP_ORIGIN], randomSpawnPoint);
	engfunc(EngFunc_SetOrigin, monster, randomSpawnPoint);
	g_MonsterSpawn[randomNum] = monster;

	g_MonsterPathPoint[monster] = waypoint;
	getNextWaypoint(waypoint, g_MonsterNextPathPoint[monster]);

	ExecuteHam(Ham_Spawn, monster);

	monsterInit(monster);

	set_pev(monster, pev_nextthink, get_gametime() + getFrameTime(DEFAULT_MONSTER_FRAMETIME));

	new Float:hp;
	pev(monster, pev_health, hp);
	server_print("New monster id=%d (%s) with HP=%.0f", monster, monsterType, hp);
	ArrayPushCell(g_MonstersAlive, monster);

	return monster;
}

monsterInit(id)
{
	new Float:angles[3];
	pev(id, pev_angles, angles);

	setMonsterHealth(id);

	set_pev(id, pev_effects, 0);
	set_pev(id, pev_takedamage, DAMAGE_AIM);
	set_pev(id, pev_ideal_yaw, angles[1]);
	set_pev(id, pev_deadflag, DEAD_NO);

	new flags = pev(id, pev_flags);
	new spawnFlags = pev(id, pev_spawnflags);

	server_print("[default] flags=%d, spawnFlags=%d", flags, spawnFlags);

	// We want monsters to go through other monsters, but not through players
	//spawnFlags |= SF_MONSTER_HITMONSTERCLIP;
	//flags |= FL_MONSTERCLIP;
	spawnFlags &= ~SF_MONSTER_HITMONSTERCLIP;
	flags |= FL_MONSTER;
	flags &= ~FL_MONSTERCLIP;

	server_print("[modified] flags=%d, spawnFlags=%d", flags, spawnFlags);

	set_pev(id, pev_flags, flags);
	set_pev(id, pev_spawnflags, spawnFlags);
	set_pev(id, pev_solid, SOLID_BBOX);
	//set_pev(id, pev_solid, SOLID_TRIGGER);

	// Bone controllers
	set_pev(id, pev_controller_0, 0);
	set_pev(id, pev_controller_1, 0);
	set_pev(id, pev_controller_2, 0);
	set_pev(id, pev_controller_3, 0);

	set_pev(id, pev_gravity, 1.0);
	set_pev(id, pev_animtime, get_gametime());
	// TODO: research what are the correct sequences for each monster class
	set_pev(id, pev_sequence, ZOMBIE_WALK_SEQ);

	// The more monsters spawned, the lower framerate,
	// so player FPS when looking at monsters doesn't get affected so much
	new Float:animFrameRate = floatdiv(1.0, getWorkloadIndex());
	set_pev(id, pev_framerate, animFrameRate);
	set_pev(id, pev_movetype, MOVETYPE_STEP);
}

setMonsterHealth(id)
{
	new Float:health = g_MonsterClass[id][MONSTER_HEALTH];
	if (g_CurrDifficulty != DIFFICULTY_SURVIVAL)
		health *= g_DifficultyStats[g_CurrDifficulty][DIFFICULTY_STATS_MULTIPLIER];
	else
		health *= getSurvivalStatsMultiplier();

	//server_print("%s hp=%.2f", g_MonsterClass[id][MONSTER_ENTITY_NAME], health);

	if (health <= 0.0)
		health = g_MonsterClass[id][MONSTER_HEALTH] * g_DifficultyStats[DEFAULT_DIFFICULTY][DIFFICULTY_STATS_MULTIPLIER];

	if (health <= 0.0)
		health = DEFAULT_MONSTER_HEALTH;

	set_pev(id, pev_health, health);
	set_pev(id, pev_max_health, health);
}

Float:getSurvivalStatsMultiplier()
{
	//server_print("g_CurrRound=%d, floatlog(g_CurrRound, EULER)=%.2f", g_CurrRound, floatlog(float(g_CurrRound), EULER));
	return 0.65 + (floatlog(float(g_CurrRound), EULER) / 20.0) + 0.05 * float(g_CurrRound) / 2.0;
}

monsterReachedNexus(id)
{
	new className[32];
	pev(id, pev_classname, className, charsmax(className));

	new Float:damage = g_MonsterClass[id][MONSTER_DAMAGE];
	if (damage <= 0.0)
		damage = DEFAULT_MONSTER_DAMAGE;

	if (pev_valid(g_Nexus))
	{
		new Float:oldNexusHP, Float:newNexusHP;
		pev(g_Nexus, pev_health, oldNexusHP);
		newNexusHP = oldNexusHP - damage;

		if (newNexusHP <= 0.0)
		{
			server_print("The Nexus has been destroyed by monsters");
			nexusDestroyed();
		}
		else
			set_pev(g_Nexus, pev_health, newNexusHP);
	}
	server_print("Removing monster #%d that has reached the Nexus", id);
	removeMonster(id);
}

// TODO: improve this... in first place, why are there monsters above the sky?
isStuckAboveSky(Float:origin[3])
{
	if (equali(g_Map, "ag_defense_a", 12) || equali(g_Map, "ag_defense_01", 13))
	{ // Checking specific maps... I know, it doesn't look good
		if (origin[2] >= -256.0)
			return true;
	}
	return false;
}

flushMonster(id)
{
	// Flush monster related data
	g_MonsterPathPoint[id][WP_ID][0] = 0;
	g_MonsterFallStartTime[id] = 0.0;
	g_isMonsterUnstucking[id] = false;
	g_MonsterBeingRemoved[id] = false;
	g_MonsterClass[id][MONSTER_ENTITY_NAME][0] = EOS;
	g_MonsterClass[id][MONSTER_MODEL][0] = EOS;
	g_MonsterClass[id][MONSTER_DAMAGE] = 0.0;
	g_MonsterClass[id][MONSTER_HEALTH] = 0.0;
	g_MonsterClass[id][MONSTER_SPEED] = 0.0;
	g_MonsterClass[id][MONSTER_IS_CUSTOM] = false;
	g_MonsterClass[id][MONSTER_IS_AIRBORNE] = false;
	g_OldEntityState[id][ENT_GAMETIME] = 0.0;
	xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_OldEntityState[id][ENT_ORIGIN]);
	xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_OldEntityState[id][ENT_ANGLES]);
	xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_OldEntityState[id][ENT_VELOCITY]);
	g_OldEntityState[id][ENT_GRAVITY_VELOCITY] = 0.0;
	g_OldEntityState[id][ENT_FLAGS] = 0;
	remove_task(TASKID_UNSTUCK_ENTITY + id);
	remove_task(TASKID_UNSTUCK_ENTITY_WITH_MONSTER + id);
}

removeMonster(id, bool:removeFromAlive=true)
{
	new index;

	flushMonster(id);
	if (pev_valid(id))
	{
		if (removeFromAlive)
		{
			index = ArrayFindValue(g_MonstersAlive, id);
			if (index > -1)
			{
				server_print("Removing from alive monster #%d", id);
				ArrayDeleteItem(g_MonstersAlive, index);
			}
		}

		new className[32], aux[MONSTER_DATA];
		pev(id, pev_classname, className, charsmax(className));
		if (TrieGetArray(g_MonsterData, className, aux, sizeof(aux)))
		{
			// Finally take that bitch outta this game
			server_print("Removing monster entity #%d", id);
			remove_entity(id);
		}
	}

	return index;
}

nexusDestroyed()
{
	server_print("Defeat!!!");
	server_cmd("agabort");
	server_exec();
	g_GameState = GAME_DEFEAT;

	hideNexus();

	spawnGibs(g_Nexus, "models/metalplategibs.mdl", 50, 100, 120, 140);

	new players[MAX_PLAYERS], playersNum;
	get_players(players, playersNum, "c");
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];
		client_print(id, print_chat, "[%s] You have failed to clear the %s difficulty.", PLUGIN_TAG, g_Difficulties[g_CurrDifficulty]);
		client_print(id, print_chat, "[%s] Your score in this last game: %d points.", PLUGIN_TAG, floatround(g_PlayerScore[id]));
	}
	clearGame();
}

gameWon()
{
	server_print("Victory!!!");
	server_cmd("agabort");
	server_exec();
	g_GameState = GAME_VICTORY;

	pev(g_Nexus, pev_health, g_NexusEndHP);

	new players[MAX_PLAYERS], playersNum;
	get_players(players, playersNum, "c");
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];

		new Float:reward = DEFAULT_POINTS_REWARD;
		if (g_PlayerScore[id] >= REWARD_RECEIVAL_THRESHOLD1)
		{
			// Must have some score to earn the reward, do not just play 1 round and earn it
			reward = POINTS_REWARD1 + g_NexusEndHP * 5.0;
		}
		else if (g_PlayerScore[id] >= REWARD_RECEIVAL_THRESHOLD2)
			reward = POINTS_REWARD2 + g_NexusEndHP * 3.0;

		g_PlayerScore[id] += reward; // TODO: depend on difficulty

		if (g_PlayerScore[id] - DEFAULT_POINTS_REWARD != 0.0)
		{
			new difficulty[32];
			formatex(difficulty, charsmax(difficulty), g_Difficulties[g_CurrDifficulty]);
			ucfirst(difficulty);

			client_print(id, print_chat, "[%s] Congratulations! You have cleared the %s difficulty and earned +%d points for the victory.",
				PLUGIN_TAG, difficulty, floatround(reward));
			client_print(id, print_chat, "[%s] Your score in this last game: %d points.", PLUGIN_TAG, floatround(g_PlayerScore[id]));
		}
	}
	set_pev(g_Nexus, pev_health, get_pcvar_float(pcvar_ad_nexus_health));
	set_pev(g_Nexus, pev_takedamage, DAMAGE_NO);
	clearGame();
}

endHudMessage()
{
	new bool:isVictory = g_GameState == GAME_VICTORY;
	new players[MAX_PLAYERS], playersNum;
	get_players(players, playersNum, "c");

	new msgScores[1600], msgEnd[1792];
	getScores(players, playersNum, msgScores, charsmax(msgScores));

	new Float:totalScore;
	for (new i = 0; i < MAX_PLAYERS; i++)
		totalScore += g_PlayerScore[i];

	new Float:nexusHP;
	pev(g_Nexus, pev_health, nexusHP);

	new difficulty[32];
	formatex(difficulty, charsmax(difficulty), g_Difficulties[g_CurrDifficulty]);
	ucfirst(difficulty);

	formatex(msgEnd, charsmax(msgEnd), "%s!\nYou have %s the %s difficulty\nRound: %d | Total points: %d | Nexus HP: %d\n\n%s",
												isVictory ? "Victory!" : "Defeat!",
												isVictory ? "cleared" : "failed to clear",
												difficulty,
												g_CurrRound,
												floatround(totalScore),
												isVictory ? floatround(g_NexusEndHP, floatround_ceil) : 0,
												msgScores);

	new customRGB[3];
	if (isVictory)
	{
		customRGB[0] = 80;
		customRGB[1] = 240;
		customRGB[2] = 0;
	}
	else
	{
		customRGB[0] = 200;
		customRGB[1] = 0;
		customRGB[2] = 0;
	}
	set_hudmessage(customRGB[0], customRGB[1], customRGB[2], _, _, 1, 2.0, 8.0, 0.1, 0.5, -1);
	ShowSyncHudMsg(0, g_SyncHudEnd, msgEnd);
}

clearGame()
{
	set_pcvar_string(pcvar_hostname, g_OriginalHostname);

	remove_task(TASKID_START_ROUND + g_CurrRound);
	new maxWaves = (get_pcvar_num(pcvar_ad_max_monsters_per_round) / MAX_SPAWNPOINTS) + 1;
	for (new i = 0; i < maxWaves; i++)
		remove_task(TASKID_SPAWN_MONSTER_WAVE + i);

	clearHUD();

	for (new i = 0; i < ArraySize(g_MonstersAlive); i++)
	{
		new monster = ArrayGetCell(g_MonstersAlive, i);
		removeMonster(monster, false); // passing false 'cos we clear the whole array shortly after
	}
	ArrayClear(g_MonstersAlive);

	resetMenus();
}

flushGame()
{
	new players[MAX_PLAYERS], playersNum;
	get_players(players, playersNum, "c");
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];

		// Reset game score
		g_PlayerScore[id] = 0.0;
		g_PlayerCredits[id] = 0.0;
	}
	//g_GameState = GAME_IDLE;
	g_CurrRound = 0; // not index-based, 0 here just means non initialized
	//g_CurrDifficulty = DEFAULT_DIFFICULTY;
	g_RoundEndTime = 0.0;
	g_IsAgstartFull = false;

	clearGame();
}

hideNexus()
{
	set_pev(g_Nexus, pev_renderamt, 0);
	set_pev(g_Nexus, pev_rendermode, 2); // TransTexture mode
	set_pev(g_Nexus, pev_health, get_pcvar_float(pcvar_ad_nexus_health));
	set_pev(g_Nexus, pev_takedamage, DAMAGE_NO);
	set_pev(g_Nexus, pev_solid, SOLID_NOT);
}

bool:repairNexus(id)
{
	if (!pev_valid(g_Nexus))
	{
		client_print(id, print_chat, "[%s] Sorry, cannot repair the Nexus because it doesn't exist anymore. You can try again after restarting the map.", PLUGIN_TAG);
		return false;
	}

	new Float:hp, Float:hpExtra = nexusHealthPerRepair();
	pev(g_Nexus, pev_health, hp);
	set_pev(g_Nexus, pev_health, hp + hpExtra);

	new playerName[32];
	getColorlessName(id, playerName, charsmax(playerName));

	client_print(0, print_chat, "[%s] %s has just repaired the Nexus, restoring %dhp!",
		PLUGIN_TAG, playerName, floatround(hpExtra, floatround_floor));

	return true;
}

Float:nexusHealthPerRepair()
{
	return get_pcvar_float(pcvar_ad_nexus_health) * 0.1;
}

bool:giveWeapon(id, const weaponName[])
{
	if (isSpectator(id))
	{
		client_print(id, print_chat, "[%s] Sorry, cannot buy %s while spectating.", PLUGIN_TAG, weaponName);
		return false;
	}

	if (!is_user_alive(id))
	{
		client_print(id, print_chat, "[%s] Sorry, you must be alive to buy %s.", PLUGIN_TAG, weaponName);
		return false;
	}

	new weapon[32];
	formatex(weapon, charsmax(weapon), "weapon_%s", weaponName);
	give_item(id, weapon);

	return true;
}

clearHUD()
{
	ClearSyncHud(0, g_SyncHudRoundTimeLeft);
	ClearSyncHud(0, g_SyncHudRoundInfo);
	ClearSyncHud(0, g_SyncHudInfoAboveScores);
	ClearSyncHud(0, g_SyncHudScore);
}

updateHUD()
{
	if (g_GameState == GAME_RUNNING && pev_valid(g_Nexus))
	{
		new Float:timeLeft, min, sec, timeLeftText[50], difficultyName[32];
		timeLeft = g_RoundEndTime - get_gametime();
		min = floatround(timeLeft / 60.0, floatround_floor);
		sec = floatround(timeLeft - min * 60.0, floatround_floor);

		formatex(difficultyName, charsmax(difficultyName), g_Difficulties[g_CurrDifficulty]);
		ucfirst(difficultyName);

		new maxRound = g_DifficultyStats[g_CurrDifficulty][DIFFICULTY_ROUNDS];

		if (g_CurrRound == 0)
			formatex(timeLeftText, charsmax(timeLeftText), "Prepare and take weapons!\nGame starting in");
		else if (g_CurrRound < maxRound)
			formatex(timeLeftText, charsmax(timeLeftText), "Next round in");

		static players[MAX_PLAYERS], playersNum;
		get_players_ex(players, playersNum, GetPlayers_ExcludeBots);

		if (timeLeft >= 0.0)
		{
			// Don't update if negative time, g_RoundEndTime it may still need some milliseconds to get updated with new round
			if (g_CurrRound == 0)
				set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.12, 0, 0.0, 999999.0, 0.0, 0.0, -1);
			else
				set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.08, 0, 0.0, 999999.0, 0.0, 0.0, -1);

			if (g_CurrRound == maxRound)
				ShowSyncHudMsg(0, g_SyncHudRoundTimeLeft, "Kill all the monsters to win!");
			else
				ShowSyncHudMsg(0, g_SyncHudRoundTimeLeft, "%s: %02d:%02d", timeLeftText, min, sec);
		}

		new Float:nexusHP;
		pev(g_Nexus, pev_health, nexusHP);
		updateInfoAboveScores(players, playersNum, nexusHP);

		if (g_CurrRound > 0)
		{
			new Array:monstersArr = ArrayGetCell(g_MonsterTypesPerRound, g_CurrRound-1);
			new totalMonstersInRound = ArraySize(monstersArr);
			if (totalMonstersInRound)
			{
				new monstersAlive = ArraySize(g_MonstersAlive);
				set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.14, 0, 0.0, 999999.0, 0.0, 0.0, -1);
				if (g_CurrDifficulty != DIFFICULTY_SURVIVAL)
					ShowSyncHudMsg(0, g_SyncHudRoundInfo,
						"%s - Round [%d / %d] - Monsters [%d / %d]",
						difficultyName, g_CurrRound, maxRound, monstersAlive, totalMonstersInRound);
				else
					ShowSyncHudMsg(0, g_SyncHudRoundInfo,
						"%s - Round %d - Monsters [%d / %d]",
						difficultyName, g_CurrRound, monstersAlive, totalMonstersInRound);

				new hostname[64];
				formatex(hostname, charsmax(hostname), "%s | %s %dhp, Round %d [%d/%d]",
					g_OriginalHostname, difficultyName, floatround(nexusHP, floatround_ceil),
					g_CurrRound, monstersAlive, totalMonstersInRound);
				set_pcvar_string(pcvar_hostname, hostname);
			}
		}
		updateScoresHUD(players, playersNum);
		updateAimingHUD(players, playersNum);
	}
}

// Credits available and Nexus HP
// They're merged into a single HUD element because there is a limited amount of channels (4 HUD channels and 8 DHUD ones)
updateInfoAboveScores(players[MAX_PLAYERS], playersNum, Float:nexusHP)
{
	// The Nexus HP is the same for all the players, so prepare that text first and then copy it for everyone
	new nexusMsg[32];
	formatex(nexusMsg, charsmax(nexusMsg), "\n\nNexus HP: %d", floatround(nexusHP, floatround_ceil));

	set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], 0.03, 0.25, 0, 0.0, 999999.0, 0.0, 0.0, -1);
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];
		new Float:credits = g_PlayerCredits[id];
		ShowSyncHudMsg(id, g_SyncHudInfoAboveScores, "Your credits: %d%s", floatround(credits, floatround_ceil), nexusMsg);
	}
}

updateScoresHUD(players[MAX_PLAYERS], playersNum)
{
	new msgScores[1600];
	getScores(players, playersNum, msgScores, charsmax(msgScores));
	set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], 0.03, 0.44, 0, 0.0, 999999.0, 0.0, 0.0, -1);

	ShowSyncHudMsg(0, g_SyncHudScore, msgScores);
}

getScores(players[MAX_PLAYERS], playersNum, msgScores[], lenMsg)
{
	// This array is to sort easily the scores, so we insert the scores,
	// sort the array and then relate with the player to draw the corresponding score
	new Array:scores = ArrayCreate(1, 8); // hardly ever will there be 8 players, so allocate that much space (better than allocating 32)
	for (new i = 0; i < playersNum; i++)
	{
		new Float:score = g_PlayerScore[players[i]];
		if (score == 0.0)
			continue;

		ArrayPushCell(scores, score);
	}
	ArraySortEx(scores, "sortScoresDescending");

	for (new i = 0; i < ArraySize(scores); i++)
	{
		new Float:score = ArrayGetCell(scores, i);
		for (new j = 0; j < playersNum; j++)
		{
			// Find the player for this score
			new id2 = players[j];
			new Float:score2 = g_PlayerScore[id2];
			if (score2 == 0.0 || score != score2)
				continue; // this player has no score or is not the player we're searching, 'cos the score is not the same

			new playerName[32];
			getColorlessName(id2, playerName, charsmax(playerName));
			formatex(msgScores, lenMsg, "%s%s -- %d p\n", msgScores, playerName, floatround(score2));
		}
	}
	ArrayClear(scores);
}

// Shows info about the monster or player you're aiming
updateAimingHUD(players[MAX_PLAYERS], playersNum)
{
	for (new i = 0; i < playersNum; i++)
	{
		new id = players[i];
		new hudMsgTarget = id; // who is gonna be shown the info about the entity being aimed

		new specMode = pev(id, pev_iuser1);
		if (specMode = OBS_IN_EYE) // spectating in first person will show the aiming HUD of the player being spectated
			hudMsgTarget = pev(id, pev_iuser2);
		else if (specMode) // spectating in any other mode won't show the aiming HUD
			continue;

		new ent, unused;
		get_user_aiming(id, ent, unused, 6000);
		if (ent && pev_valid(ent))
		{
			new className[32];
			pev(ent, pev_classname, className, charsmax(className));

			if (!TrieKeyExists(g_MonsterData, className))
				continue; // we're only gonna show info about entities that are monsters registered in this plugin

			if (g_MonsterClass[ent][0])
			{
				copy(className, charsmax(className), g_MonsterClass[ent][MONSTER_ENTITY_NAME]);

				new msg[64], Float:hp;
				pev(ent, pev_health, hp);
				formatex(msg, charsmax(msg), "%s\nHP: %d", className, floatround(hp, floatround_ceil));

				set_hudmessage(g_HudRGB[0], g_HudRGB[1], g_HudRGB[2], -1.0, 0.85, 0, 0.0, 0.8, 0.0, 0.0, -1);
				ShowSyncHudMsg(hudMsgTarget, g_SyncHudAimingInfo, msg);
			}
		}
	}
}

/////////////////////////////////////////////////////
//	MENUS
/////////////////////////////////////////////////////

public ShowMainMenu(id)
{
	new menu = menu_create("Main menu:", "HandleMainMenu");

	menu_additem(menu, "Play",					"play",			_, g_MainMenuItemCallback);	// 1
	menu_additem(menu, "Advance round",			"advance",		_, g_MainMenuItemCallback);	// 2
	menu_additem(menu, "Abort game",			"abort",		_, g_MainMenuItemCallback);	// 3
	menu_additem(menu, "Change map",			"map");										// 4
	menu_additem(menu, "Shop",					"shop",			_, g_MainMenuItemCallback);	// 5
	menu_additem(menu, "Remove last satchel",	"unsatchel",	_, g_MainMenuItemCallback);	// 6
	menu_additem(menu, "Help",					"help",			_, g_MainMenuItemCallback);	// 7
	menu_additem(menu, "Admin menu",			"admin", 		ADMIN_CFG);					// 8
	menu_addblank2(menu);
	menu_additem(menu, "Exit",					"exit");									// 0

	menu_setprop(menu, MPROP_PERPAGE,	0); // no pagination, otherwise it puts the last 2 options in the next page
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER); // fixes *sometimes* appearing a second Exit option
	menu_setprop(menu, MPROP_NOCOLORS,	0);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleMainMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new itemKey[32];
	menu_item_getinfo(menu, item, _, itemKey, charsmax(itemKey));

	if (equal(itemKey, "play"))				// 1
	{
		if (g_GameState == GAME_STARTING || g_GameState == GAME_RUNNING)
			client_cmd(id, "callvote agallow");
		else
		{
			// TODO: implement a submenu to choose the difficulty
			// TODO: then remove the Switch to fun/competitive and add a second submenu to choose the mode,
			// but only when it has enough features and is polished enough for competitive to make sense

			ShowDifficultyMenu(id);
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
	}
	else if (equal(itemKey, "advance"))		// 2
	{
		// TODO: implement
		client_print(id, print_chat, "[%s] Sorry, advancing instantly to the next round is not implemented yet.", PLUGIN_TAG);
	}
	else if (equal(itemKey, "abort"))		// 3
		client_cmd(id, "callvote agabort");

	else if (equal(itemKey, "map"))			// 4
	{
		if (equali(g_Map, "ag_defense_a6"))
			client_cmd(id, "callvote agmap ag_defense_a3");
		else
			client_cmd(id, "callvote agmap ag_defense_a6");
	}
	else if (equal(itemKey, "shop"))		// 5
	{
		ShowShopMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	else if (equal(itemKey, "unsatchel"))	// 6
		CmdUnsatchel(id);

	else if (equal(itemKey, "help"))		// 7
	{
		//showHelp(id); // TODO: may have to do a submenu with different parts of the game to explain in case doesn't fit in 1500 chars
		client_print(id, print_chat, "[%s] Sorry, the help area has not been implemented yet.", PLUGIN_TAG);
	}
	else if (equal(itemKey, "admin"))		// 8
	{
		ShowAdminMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	else if (equal(itemKey, "exit"))		// 0
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	server_print("[main menu] itemKey: %s, item: %d", itemKey, item);

	ShowMainMenu(id);

	return PLUGIN_HANDLED;
}

public MainMenuItemCallback(id, menu, item)
{
	new itemKey[32];
	menu_item_getinfo(menu, item, _, itemKey, charsmax(itemKey));

	if (equal(itemKey, "advance") || equal(itemKey, "help"))
	{
		// TODO: implement; remove this afterwards
		return disableMenuItem(menu, item);
	}

	if (equal(itemKey, "unsatchel") && !(g_PlayerLastSatchel[id] && pev_valid(g_PlayerLastSatchel[id])))
		return disableMenuItem(menu, item);

	if (g_GameState != GAME_RUNNING)
	{
		if (equal(itemKey, "advance")
			|| equal(itemKey, "shop"))
		{
			return disableMenuItem(menu, item);
		}

		if (g_GameState != GAME_STARTING && equal(itemKey, "abort"))
			return disableMenuItem(menu, item);
	}

	return ITEM_IGNORE;
}

public ShowDifficultyMenu(id)
{
	new menu = menu_create("Choose a difficulty:", "HandleDifficultyMenu");

	// TODO: pretty print menu options
	for (new i = 0; i < sizeof(g_Difficulties); i++)
		menu_additem(menu, g_Difficulties[i], g_Difficulties[i]);

	menu_setprop(menu, MPROP_NOCOLORS,	0);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleDifficultyMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		ShowMainMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new itemKey[32];
	menu_item_getinfo(menu, item, _, itemKey, charsmax(itemKey));

	ShowModeMenu(id, itemKey);

	return PLUGIN_HANDLED;
}

public ShowModeMenu(id, args[])
{
	new menu = menu_create("Choose a mode:", "HandleModeMenu");

	// TODO: pretty print menu options
	for (new i = 0; i < sizeof(g_Modes); i++)
	{
		new info[32];
		if (args[0])
			formatex(info, charsmax(info), "%s %s", args, g_Modes[i]);
		else
			add(info, charsmax(info), g_Modes[i]);

		menu_additem(menu, g_Modes[i], info);
	}

	menu_setprop(menu, MPROP_NOCOLORS, 0);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleModeMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		ShowMainMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new itemKey[32];
	menu_item_getinfo(menu, item, _, itemKey, charsmax(itemKey));

	// Size 72 -> 8 for callvote, 32 for vote string (e.g.: "agstart"), 32 for value string as seen in agvote.cpp (e.g.: "hard full")
	new voteCmd[72], fullArg[6];

	if (containi(itemKey, g_Modes[MODE_FUN]) != -1)
		formatex(fullArg, charsmax(fullArg), " full");

	formatex(voteCmd, charsmax(voteCmd), "callvote \"agstart\" \"%s%s\"", itemKey, fullArg);

	server_print("HandleModeMenu :: itemKey=%s, voteCmd=%s", itemKey, voteCmd);
	
	client_cmd(id, voteCmd);

	ShowMainMenu(id);

	return PLUGIN_HANDLED;
}

public ShowShopMenu(id)
{
	new menu = menu_create("Buy items:", "HandleShopMenu");

	// TODO: improve code, could probably be less than this; e.g.: a struct with the item properties
	// and iterate a Trie contaning instances of that type to make the menu
	new Float:gaussPrice, Float:egonPrice, Float:repairPrice;
	TrieGetCell(g_ShopItems, "gauss", gaussPrice);
	TrieGetCell(g_ShopItems, "egon", egonPrice);
	TrieGetCell(g_ShopItems, "repair", repairPrice);

	// TODO: check if this should be floatround_ceil, rounding to 2 decimals or none at all;
	// maybe there are prices with decimals in the future, affected by some feature or whatever
	new gaussText[32], egonText[32], repairText[32];
	formatex(gaussText,		charsmax(gaussText),	"Gauss (%dc)",			floatround(gaussPrice));
	formatex(egonText,		charsmax(egonText),		"Egon (%dc)",			floatround(egonPrice));
	formatex(repairText,	charsmax(repairText),	"Nexus repair (%dc)",	floatround(repairPrice));

	menu_additem(menu, gaussText,	"gauss",	_, g_ShopMenuItemCallback);
	menu_additem(menu, egonText,	"egon",		_, g_ShopMenuItemCallback);
	menu_additem(menu, repairText,	"repair",	_, g_ShopMenuItemCallback);

	menu_setprop(menu, MPROP_NOCOLORS, 0);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleShopMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		ShowMainMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new itemKey[32];
	menu_item_getinfo(menu, item, _, itemKey, charsmax(itemKey));

	if (equal(itemKey, "gauss"))
		CmdBuyGauss(id);

	else if (equal(itemKey, "egon"))
		CmdBuyEgon(id);

	else if (equal(itemKey, "repair"))
		CmdNexusRepair(id);

	server_print("[shop menu] itemKey: %s, item: %d", itemKey, item);

	ShowShopMenu(id);

	return PLUGIN_HANDLED;
}

public ShopMenuItemCallback(id, menu, item)
{
	// TODO: refresh THIS menu when there are enough credits to buy some item that was disabled

	if (g_GameState != GAME_RUNNING)
		return disableMenuItem(menu, item);

	new itemKey[32], Float:price;
	menu_item_getinfo(menu, item, _, itemKey, charsmax(itemKey));
	TrieGetCell(g_ShopItems, itemKey, price);

	if (g_PlayerCredits[id] < price)
		return disableMenuItem(menu, item);

	return ITEM_IGNORE;
}

public ShowAdminMenu(id)
{
	if (get_user_flags(id) < ADMIN_CFG)
		return PLUGIN_CONTINUE;

	new menu = menu_create("Admin menu:", "HandleAdminMenu");

	menu_additem(menu, "Check game status",		"check");									// 1
	menu_additem(menu, "Spawn a monster",		"spawn");									// 2
	menu_additem(menu, "Remove a monster",		"remove",	_, g_AdminMenuItemCallback);	// 3
	menu_additem(menu, "Start a test round",	"test",		_, g_AdminMenuItemCallback);	// 4
	menu_additem(menu, "Remove garbage",		"clean");									// 5
	menu_additem(menu, "Dump entities",			"dump");									// 6

	menu_setprop(menu, MPROP_NOCOLORS, 0);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleAdminMenu(id, menu, item)
{
	// TODO: implement

	if (item == MENU_EXIT)
	{
		ShowMainMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new itemKey[32];
	menu_item_getinfo(menu, item, _, itemKey, charsmax(itemKey));

	if (equal(itemKey, "check"))
		client_cmd(id, "ad_check");

	else if (equal(itemKey, "spawn"))
	{
		// TODO: show a submenu with several pages to spawn any monster you want
		//client_print(id, print_chat, "[%s] Sorry, the monster spawning menu isn't ready yet.", PLUGIN_TAG);
		ShowSpawnMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	else if (equal(itemKey, "remove"))
	{
		// TODO: show a submenu with several pages to remove any alive monster
		client_print(id, print_chat, "[%s] Sorry, the monster removal menu isn't ready yet.", PLUGIN_TAG);
	}
	else if (equal(itemKey, "test"))
		CmdTestRound(id);

	else if (equal(itemKey, "clean"))
		CmdRemoveGarbage(id);

	else if (equal(itemKey, "dump"))
		dumpEntities();

	server_print("[admin menu] itemKey: %s, item: %d", itemKey, item);

	ShowAdminMenu(id);

	return PLUGIN_HANDLED;
}

public AdminMenuItemCallback(id, menu, item)
{
	new itemKey[32];
	menu_item_getinfo(menu, item, _, itemKey, charsmax(itemKey));

	if (equal(itemKey, "remove") && !ArraySize(g_MonstersAlive))
		return disableMenuItem(menu, item);

	else if (equal(itemKey, "test")/* && g_GameState = GAME_STARTING && g_GameState != GAME_RUNNING*/)
		return disableMenuItem(menu, item);

	return ITEM_IGNORE;
}

public ShowSpawnMenu(id)
{
	if (get_user_flags(id) < ADMIN_CFG)
		return PLUGIN_CONTINUE;

	new menu = menu_create("Monster spawning menu:", "HandleSpawnMenu");

	new TrieIter:it = TrieIterCreate(g_MonsterData);
	while (!TrieIterEnded(it))
	{
		new data[MONSTER_DATA];
		TrieIterGetArray(it, data, MONSTER_DATA);
		//new monsterType[24];
		//copy(monsterType, charsmax(monsterType), data[MONSTER_ENTITY_NAME]);

		//spawnMonster(id, monsterType);
		//spawnMonster(id, data[MONSTER_ENTITY_NAME]);
		// TODO: pretty print the monster name to show in the menu, e.g.: monster_alien_controller -> Alien Controller
		menu_additem(menu, data[MONSTER_ENTITY_NAME], data[MONSTER_ENTITY_NAME]);	
		
		TrieIterNext(it);
	}
	TrieIterDestroy(it);

	//menu_setprop(menu, MPROP_PERPAGE, 7);
	menu_setprop(menu, MPROP_NOCOLORS, 0);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public HandleSpawnMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		ShowAdminMenu(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new itemKey[32];
	menu_item_getinfo(menu, item, _, itemKey, charsmax(itemKey));

	// Check in case it's possible to change the selection data that the client sends to the server
	// and wants to spawn a non-cached monster, etc. leading to crash
	if (TrieKeyExists(g_MonsterData, itemKey))
		spawnMonster(id, itemKey);

	ShowSpawnMenu(id);

	return PLUGIN_HANDLED;
}

// A wrapper for returning ITEM_DISABLED, but greying out the menu item, as the AMXX menu system doesn't do it surprisingly
disableMenuItem(menu, item)
{
	new itemName[64];
	menu_item_getinfo(menu, item, _, _, _, itemName, charsmax(itemName));
	format(itemName, charsmax(itemName), "\\d%s\\w", itemName); // make this text grey, then continue with white
	menu_item_setname(menu, item, itemName);

	return ITEM_DISABLED;
}

/////////////////////////////////////////////////////
//	UTILS
/////////////////////////////////////////////////////

sortScoresDescending(Array:array, elem1, elem2, const data[], data_size)
{
	return elem1 > elem2 ? -1 : (elem1 < elem2 ? 1 : 0);
}

// Stores in the 'angles' parameter the angles for the entity to be looking at the target point
stock getAnglesToTarget(id, Float:target[3], Float:angles[3])
{
	static Float:vec[3];
	pev(id, pev_origin, vec);
	xs_vec_sub(target, vec, vec);
	engfunc(EngFunc_VecToAngles, vec, angles);
	//angles[0] *= -1.0;
	angles[0] = 0.0;
	angles[2] = 0.0;
}

stock getNormalPlaneRelativeToPlayer(id, Float:start[3], Float:direction[3], Float:origin[3], Float:normal[3])
{
    static Float:dest[3];

    // Make a vector that points to the given direction, and add it to the player position
    xs_vec_add(start, direction, dest);

    // Declare a handle for the traceline function and a variable to hold the distance
    // between the player and the brush at the sides of them
    static tr, Float:dist;
    tr = create_tr2();
    engfunc(EngFunc_TraceLine, start, dest, IGNORE_MONSTERS, id, tr);

    // Put the endpoint, where we hit a brush, into the variable origin
    get_tr2(tr, TR_vecEndPos, origin);

    // Get the distance between the player and the endpoint
    dist = get_distance_f(start, origin);

    origin[0] -= (origin[0] - start[0])/dist;
    origin[1] -= (origin[1] - start[1])/dist;
    origin[2] -= (origin[2] - start[2])/dist;

    // This returns the vector that is perpendicular to the surface in the given direction from the player
    get_tr2(tr, TR_vecPlaneNormal, normal);
    free_tr2(tr);
}

Float:getWorkloadIndex()
{
	new Float:workload = 1.0;
	new monstersAlive = ArraySize(g_MonstersAlive);

	if (monstersAlive >= 20)
		workload += (monstersAlive / 10) * 0.5;

	return workload;
}

Float:getFrameTime(Float:defaultFrameTime)
{
	new Float:frameTime = defaultFrameTime;
	frameTime = defaultFrameTime * (getWorkloadIndex() / 2.0);

	if (frameTime < defaultFrameTime)
		frameTime = defaultFrameTime;

	return frameTime;
}

Float:getMonsterSpeed(id)
{
	new className[32];
	pev(id, pev_classname, className, charsmax(className));

	new Float:speed = g_MonsterClass[id][MONSTER_SPEED];
	if (speed <= 0.0)
		speed = DEFAULT_MONSTER_SPEED;

	if (g_CurrMode == MODE_FUN)
		speed *= 1.4;

	return speed;
}

spawnGibs(id, model[], minSpread, maxSpread, minGibs, maxGibs)
{
	new Float:fOrigin[3];
	pev(id, pev_origin, fOrigin);

	new origin[3];
	origin[0] = floatround(fOrigin[0]);
	origin[1] = floatround(fOrigin[1]);
	origin[2] = floatround(fOrigin[2]);

	new modelData[2];
	TrieGetArray(g_Gibs, model, modelData, sizeof(modelData));

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	{
		write_byte(TE_BREAKMODEL);
		
		// Position
		write_coord(origin[0] + random_num(-16, 16));
		write_coord(origin[1] + random_num(-16, 16));
		write_coord(origin[2] + random_num(0, 16));
		server_print("spawning gibs at {%d, %d, %d}", origin[0], origin[1], origin[2]);
		
		// Size
		write_coord(32);
		write_coord(32);
		write_coord(32);
		
		// Velocity
		write_coord(random_num(-500, 500));
		write_coord(random_num(-500, 500));
		write_coord(random_num(-150, 300));
		
		write_byte(random_num(minSpread, maxSpread)); // randomization
		write_short(modelData[0]); // model id#
		write_byte(random_num(minGibs, maxGibs)); // number of shards
		write_byte(random_num(30, 120)); // duration in seconds*10 (30 = 3 seconds)
		write_byte(modelData[1]); // flags/material
	}
	message_end();
}

getColorlessName(id, name[], len)
{
	get_user_name(id, name, len);

	// Clear out color codes
	new i, j;
	new const hat[3] = "^^";
	while (name[i])
	{
		if (name[i] == hat[0] && name[i + 1] >= '0' && name[i + 1] <= '9')
		{
			i++;
		}
		else
		{
			if (j != i)
				name[j] = name[i];
			j++;
		}
		i++;
	}
	name[j] = 0;
}
