#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <xs>
#include <engine>
//#include <zombie_plague_special>

#define WEAPON_NOCLIP -1
#define Instance(%0) ((%0 == NULLENT) ? 0 : %0)
#define WEAPON_RPG7 173545
#define MAX_AMMO_SLOTS 32
#define RPG7_MAX_CLIP 1
#define ROCKET_MAX_CARRY 90
#define ROCKET_AIR_VELOCITY	1500.0
#define ROCKET_WATER_VELOCITY 500.0

const WeaponIdType:WEAPON_REFERENCE = WEAPON_AUG;

#if defined _zombie_special_new_included
const ZP_RPG7_DAMAGE = 736;
#else
const RPG7_DAMAGE = 147;
#endif

const Float:RPG7_MAX_SPEED = 250.0;
const Float:RPG7_RANGE_MODIFIER = 0.82;
const Float:RPG7_RELOAD_TIME = 2.0;
const Float:RPG7_ACCURACY_DIVISOR = 210.0;

#define RPG7_CHANGE_TIME (11 / 30.0)
#define RPG7_SHOOT_TIME (31 / 45.0)

enum _:rpg7_e
{
	RPG7_IDLE1,
	RPG7_IDLE2,
	RPG7_IDLE1_EMPTY,
	RPG7_IDLE2_EMPTY,
	RPG7_SHOOT1,
	RPG7_SHOOT2,
	RPG7_RELOAD,
	RPG7_DRAW,
	RPG7_DRAW_EMPTY,
	RPG7_CHANGE1,
	RPG7_CHANGE2,
	RPG7_CHANGE1_EMPTY,
	RPG7_CHANGE2_EMPTY
};

new const g_szClassname[] = "weapon_rpg7";
new const g_szWeaponModel[] = "models/p_rpg7.mdl";
new const g_szViewModel[] = "models/v_rpg7.mdl";
new const g_szWeaponBoxModel[] = "models/w_rpg7.mdl";
new const g_szRocketModel[] = "models/rpg7_rocket.mdl";
new const g_szShootSound[] = "weapons/rpg7-1.wav";
new const g_szRocketSound[] = "weapons/rocket1.wav";

new g_sModelIndexSmoke;
new g_sModelIndexBubbles;
new g_sModelIndexFireball2;
new g_sModelIndexFireball3;
new g_iTrail;

new gmsgWeaponList;
new g_hFM_RegUserMsg_Post;
new HookChain:g_hcRG_CSGameRules_DeathNotice_Post;

new g_iBody[MAX_PLAYERS + 1];
new Float:g_flLastEventCheck[MAX_PLAYERS + 1];

#if defined _zombie_special_new_included
new g_iItem;
#endif

public plugin_precache()
{
	precache_model(g_szWeaponModel);
	precache_model(g_szViewModel);
	precache_sounds_from_model(g_szViewModel);
	precache_model(g_szWeaponBoxModel);
	precache_model(g_szRocketModel);
	precache_sound(g_szShootSound);
	precache_sound(g_szRocketSound);

	g_sModelIndexSmoke = precache_model("sprites/steam1.spr");
	g_sModelIndexBubbles = precache_model("sprites/bubble.spr");
	g_sModelIndexFireball2 = precache_model("sprites/eexplo.spr");
	g_sModelIndexFireball3 = precache_model("sprites/fexplo.spr");
	g_iTrail = precache_model("sprites/wall_puff1.spr");

	precache_sprites_from_text(g_szClassname);

	gmsgWeaponList = get_user_msgid("WeaponList");

	if (!gmsgWeaponList)
		g_hFM_RegUserMsg_Post = register_forward(FM_RegUserMsg, "FM_RegUserMsg_Post", 1);

	register_clcmd(g_szClassname, "clcmd_SelectWeapon");
}

public FM_RegUserMsg_Post(const name[])
{
	if (strcmp(name, "WeaponList") == 0)
		gmsgWeaponList = get_orig_retval();
}

public clcmd_SelectWeapon(const this)
{
	if (!is_user_alive(this))
		return PLUGIN_HANDLED;

	new pItem = get_member(this, m_rgpPlayerItems, PRIMARY_WEAPON_SLOT);

	if (!pItem || is_nullent(pItem))
		return PLUGIN_HANDLED;

	if (rg_get_iteminfo(pItem, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(pItem, var_impulse) != WEAPON_RPG7)
		return PLUGIN_HANDLED;

	if (get_member(this, m_pActiveItem) == pItem)
		return PLUGIN_HANDLED;

	rg_switch_weapon(this, pItem);
	return PLUGIN_HANDLED;
}

public plugin_init()
{
	register_plugin("Weapon: RPG-7", "1.0", "Eclipse*");

	register_forward(FM_UpdateClientData, "FM_UpdateClientData_Post", 1);

	RegisterHookChain(RG_CBasePlayer_Observer_IsValidTarget, "RG_CBasePlayer_Observer_IsValidTarget_Post", 1);
	RegisterHookChain(RG_CWeaponBox_SetModel, "RG_CWeaponBox_SetModel_Pre", 0);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "RG_CBasePlayerWeapon_DefaultDeploy_Pre", 0);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "RG_CBasePlayerWeapon_DefaultReload_Pre", 0);
	RegisterHookChain(RG_CBasePlayerWeapon_SendWeaponAnim, "RG_CBasePlayerWeapon_SendWeaponAnim_Pre", 0);

	RegisterHookChain(RG_CSGameRules_DeathNotice, "RG_CSGameRules_DeathNotice_Pre", 0);
	DisableHookChain((g_hcRG_CSGameRules_DeathNotice_Post = RegisterHookChain(RG_CSGameRules_DeathNotice, "RG_CSGameRules_DeathNotice_Post", 1)));

	new pszName[MAX_NAME_LENGTH];
	rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_pszName, pszName, charsmax(pszName));
	RegisterHam(Ham_Item_AddToPlayer, pszName, "Ham_Item_AddToPlayer_Post", 1, true);
	RegisterHam(Ham_Weapon_PrimaryAttack, pszName, "Ham_Weapon_PrimaryAttack_Pre", 0, true);
	RegisterHam(Ham_Weapon_SecondaryAttack, pszName, "Ham_Weapon_SecondaryAttack_Pre", 0, true);
	RegisterHam(Ham_Weapon_WeaponIdle, pszName, "Ham_Weapon_WeaponIdle_Pre", 0, true);

#if defined _zombie_special_new_included
	g_iItem = zp_register_extra_item("RPG-7 (Rocket Launcher)", 100, ZP_TEAM_HUMAN);
#else
	register_clcmd("give_rpg7", "clcmd_GiveRPG7");
#endif

	if (g_hFM_RegUserMsg_Post)
	{
		unregister_forward(FM_RegUserMsg, g_hFM_RegUserMsg_Post, 1);
		g_hFM_RegUserMsg_Post = 0;
	}
}

public client_putinserver(this)
{
	g_iBody[this] = 0;
	g_flLastEventCheck[this] = 0.0;
}

public client_disconnected(this)
{
	g_iBody[this] = 0;
	g_flLastEventCheck[this] = 0.0;
}

#if defined _zombie_special_new_included
public zp_extra_item_selected(this, item)
{
	if (item != g_iItem)
		return;

	clcmd_GiveRPG7(this);
}
#endif

public clcmd_GiveRPG7(const this)
{
	new pszName[32];
	rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_pszName, pszName, charsmax(pszName));
	new pItem = UTIL_GiveCustomWeapon(this, pszName, WEAPON_RPG7, RPG7_MAX_CLIP, ROCKET_MAX_CARRY);

	if (!is_nullent(pItem))
	{
		set_member(pItem, m_Weapon_iClip, RPG7_MAX_CLIP);
		set_member(this, m_rgAmmo, ROCKET_MAX_CARRY, get_member(pItem, m_Weapon_iPrimaryAmmoType));
		set_member(pItem, m_Weapon_iStateSecondaryAttack, WEAPON_SECONDARY_ATTACK_SET);
	}

	return PLUGIN_HANDLED;
}

public FM_UpdateClientData_Post(const this, sendWeapons, hCD)
{
	if (!is_user_connected(this) || !IsLocalWeapon(this))
		return FMRES_IGNORED;

	static pTarget;
	pTarget = get_entvar(this, var_iuser1) ? get_entvar(this, var_iuser2) : this;

	if (!is_user_alive(pTarget))
		return FMRES_IGNORED;

	static pActiveItem;
	pActiveItem = get_member(pTarget, m_pActiveItem);

	if (is_nullent(pActiveItem) || rg_get_iteminfo(pActiveItem, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(pActiveItem, var_impulse) != WEAPON_RPG7)
		return FMRES_IGNORED;

	static Float:flTime;
	flTime = get_gametime();

	set_cd(hCD, CD_flNextAttack, flTime + 0.1);

	static iClip;
	iClip = get_member(pActiveItem, m_Weapon_iClip);

	if (!g_flLastEventCheck[this])
	{
		if (g_iBody[this])
			set_cd(hCD, CD_WeaponAnim, RPG7_IDLE1);

		return FMRES_HANDLED;
	}

	if (g_flLastEventCheck[this] <= flTime)
	{
		if (iClip <= 0)
			SendWeaponAnim(this, RPG7_DRAW_EMPTY);
		else
			SendWeaponAnim(this, RPG7_DRAW);

		g_flLastEventCheck[this] = 0.0;
	}

	return FMRES_IGNORED;
}

public RG_CBasePlayer_Observer_IsValidTarget_Post(const this, iPlayerIndex, bool:bSameTeam)
{
	if (!is_user_connected(this) || !is_user_alive(iPlayerIndex))
		return HC_CONTINUE;

	new pActiveItem = get_member(iPlayerIndex, m_pActiveItem);

	if (is_nullent(pActiveItem) || rg_get_iteminfo(pActiveItem, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(pActiveItem, var_impulse) != WEAPON_RPG7)
		return HC_CONTINUE;

	g_iBody[this] = g_iBody[iPlayerIndex];

	if (get_member(pActiveItem, m_Weapon_iClip) <= 0)
		SendWeaponAnim(this, RPG7_IDLE1_EMPTY);
	else
		SendWeaponAnim(this, RPG7_IDLE1);

	if (IsLocalWeapon(this) && g_iBody[this])
		g_flLastEventCheck[this] = get_gametime() + 0.1;

	return HC_CONTINUE;
}

public RG_CWeaponBox_SetModel_Pre(const this, szModelName[])
{
	if (is_nullent(this))
		return HC_CONTINUE;

	static pItem;
	pItem = GetWeaponBoxItem(this);

	if (!is_nullent(pItem) && rg_get_iteminfo(pItem, ItemInfo_iId) == any:WEAPON_REFERENCE && get_entvar(pItem, var_impulse) == WEAPON_RPG7)
		SetHookChainArg(2, ATYPE_STRING, g_szWeaponBoxModel);

	return HC_CONTINUE;
}

public RG_CBasePlayerWeapon_DefaultDeploy_Pre(const this, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_RPG7)
		return HC_CONTINUE;

	new pPlayer = get_member(this, m_pPlayer);

	g_iBody[pPlayer] = get_entvar(this, var_body);

	set_member(this, m_Weapon_iWeaponState, 0);
	SetHookChainArg(2, ATYPE_STRING, g_szViewModel);
	SetHookChainArg(3, ATYPE_STRING, g_szWeaponModel);

	new iClip = get_member(this, m_Weapon_iClip);

	if (IsLocalWeapon(pPlayer) && g_iBody[pPlayer])
	{
		g_flLastEventCheck[pPlayer] = get_gametime() + 0.1;
		SetHookChainArg(4, ATYPE_INTEGER, RPG7_IDLE1);
	}
	else
	{
		if (iClip <= 0)
			SetHookChainArg(4, ATYPE_INTEGER, RPG7_DRAW_EMPTY);
		else
			SetHookChainArg(4, ATYPE_INTEGER, RPG7_DRAW);
	}

	SetHookChainArg(5, ATYPE_STRING, "carbine");
	SetHookChainArg(6, ATYPE_INTEGER, 0);
	return HC_CONTINUE;
}

public RG_CBasePlayerWeapon_DefaultReload_Pre(const this, iClipSize, iAnim, Float:fDelay)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_RPG7)
		return HC_CONTINUE;

	SetHookChainArg(2, ATYPE_INTEGER, RPG7_MAX_CLIP);
	SetHookChainArg(3, ATYPE_INTEGER, RPG7_RELOAD);
	SetHookChainArg(4, ATYPE_FLOAT, RPG7_RELOAD_TIME);
	set_member(this, m_Weapon_flNextPrimaryAttack, GetNextAttackDelay(this, RPG7_RELOAD_TIME + 0.2));
	return HC_CONTINUE;
}

public RG_CBasePlayerWeapon_SendWeaponAnim_Pre(const this, iAnim, skiplocal)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_RPG7)
		return HC_CONTINUE;

	SendWeaponAnim(get_member(this, m_pPlayer), iAnim);
	return HC_SUPERCEDE;
}

public RG_CSGameRules_DeathNotice_Pre(const pVictim, const pKiller, const pInflictor)
{
	if (!is_user_connected(pKiller) || pVictim == pKiller || pInflictor == pKiller)
		return HC_CONTINUE;

	if (!pInflictor || is_nullent(pInflictor))
		return HC_CONTINUE;

	/*if (!FClassnameIs(pInflictor, "rpg7_rocket"))
		return HC_CONTINUE;*/

	if (rg_get_iteminfo(pInflictor, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(pInflictor, var_impulse) != WEAPON_RPG7)
		return HC_CONTINUE;

	new szNetName[MAX_NAME_LENGTH], szName[MAX_NAME_LENGTH];
	get_entvar(pKiller, var_netname, szNetName, charsmax(szNetName));

	if (strlen(szNetName) > 16)
		formatex(szName, charsmax(szName), "%.16s (RPG-7)", szNetName);
	else
		formatex(szName, charsmax(szName), "%s (RPG-7)", szNetName);

	message_begin(MSG_ALL, SVC_UPDATEUSERINFO);
	write_byte(pKiller - 1);
	write_long(get_user_userid(pKiller));
	write_char('\');
	write_char('n');
	write_char('a');
	write_char('m');
	write_char('e');
	write_char('\');
	write_string(szName);
	for (new i = 0; i < 16; i++)
		write_byte(0);
	message_end();

	EnableHookChain(g_hcRG_CSGameRules_DeathNotice_Post);
	return HC_CONTINUE;
}

public RG_CSGameRules_DeathNotice_Post(const pVictim, const pKiller, const pInflictor)
{
	rh_update_user_info(pKiller);
	DisableHookChain(g_hcRG_CSGameRules_DeathNotice_Post);
}

public Ham_Item_AddToPlayer_Post(const this, const pPlayer)
{
	if (is_nullent(this) || rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE)
		return HAM_IGNORED;

	if (get_entvar(this, var_impulse) == WEAPON_RPG7)
	{
		MakeWeaponList(
			pPlayer, 
			g_szClassname, 
			rg_get_weapon_info(WEAPON_REFERENCE, WI_AMMO_TYPE), 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iMaxAmmo1), 
			-1, 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iMaxAmmo2), 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iSlot), 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iPosition), 
			any:WEAPON_REFERENCE, 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iFlags)
		);

		set_entvar(this, var_body, 1);
	}
	else
	{
		new pszName[32];
		rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_pszName, pszName, charsmax(pszName));

		MakeWeaponList(
			pPlayer, 
			pszName, 
			rg_get_weapon_info(WEAPON_REFERENCE, WI_AMMO_TYPE), 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iMaxAmmo1), 
			-1, 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iMaxAmmo2), 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iSlot), 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iPosition), 
			any:WEAPON_REFERENCE, 
			rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_iFlags)
		);
	}

	return HAM_IGNORED;
}

public Ham_Weapon_PrimaryAttack_Pre(const this)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_RPG7)
		return HAM_IGNORED;

	new iClip = get_member(this, m_Weapon_iClip);

	if (iClip <= 0)
		return HAM_IGNORED;

	new iShotsFired = get_member(this, m_Weapon_iShotsFired);

	if (iShotsFired)
		return HAM_SUPERCEDE;

	set_member(this, m_Weapon_iShotsFired, ++iShotsFired);

	new pPlayer = get_member(this, m_pPlayer);

	set_member(pPlayer, m_iWeaponVolume, LOUD_GUN_VOLUME);
	set_member(pPlayer, m_iWeaponFlash, BRIGHT_GUN_FLASH);
	set_member(this, m_Weapon_iClip, --iClip);
	rg_set_animation(pPlayer, PLAYER_ATTACK1);

	new Float:v_angle[3], Float:punchangle[3], Float:rgflVec[3], Float:v_forward[3], Float:v_right[3], Float:v_up[3], Float:vecSrc[3], Float:vecDir[3];
	get_entvar(pPlayer, var_v_angle, v_angle);
	get_entvar(pPlayer, var_punchangle, punchangle);
	xs_vec_add(v_angle, punchangle, rgflVec);
	engfunc(EngFunc_AngleVectors, rgflVec, v_forward, v_right, v_up);

	rgflVec[0] = -rgflVec[0];
	rgflVec[2] = random_float(0.0, 360.0);

	GetGunPosition(pPlayer, vecSrc);
	xs_vec_add(vecSrc, v_forward, vecDir);
	xs_vec_add_scaled(vecSrc, v_forward, 10.0, vecSrc);
	xs_vec_add_scaled(vecSrc, v_right, 0.0, vecSrc);
	xs_vec_add_scaled(vecSrc, v_up, -13.0, vecSrc);
	MakeExplosion(vecSrc, 0.0, g_iTrail, 1, 50, TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOSOUND|TE_EXPLFLAG_NOPARTICLES);

	new pRocket = RocketCreate(this);

	if (pRocket && !is_nullent(pRocket))
	{
		new Float:velocity[3], Float:avelocity[3];
		get_entvar(pRocket, var_velocity, velocity);
		get_entvar(pRocket, var_avelocity, avelocity);
		set_entvar(pRocket, var_origin, vecDir);
		set_entvar(pRocket, var_angles, rgflVec);

		if (get_entvar(pPlayer, var_waterlevel) == 3)
		{
			xs_vec_mul_scalar(v_forward, ROCKET_WATER_VELOCITY, velocity);
			set_entvar(pRocket, var_velocity, velocity);
			set_entvar(pRocket, var_speed, ROCKET_WATER_VELOCITY);
		}
		else
		{
			xs_vec_mul_scalar(v_forward, ROCKET_AIR_VELOCITY, velocity);
			set_entvar(pRocket, var_velocity, velocity);
			set_entvar(pRocket, var_speed, ROCKET_AIR_VELOCITY);
		}

		avelocity[2] = 10.0;
		set_entvar(pRocket, var_avelocity, avelocity);
	}

	set_entvar(pPlayer, var_effects, get_entvar(pPlayer, var_effects) & ~EF_MUZZLEFLASH);
	set_entvar(this, var_effects, get_entvar(this, var_effects) & ~EF_MUZZLEFLASH);

	if (get_member(this, m_Weapon_iWeaponState))
	{
		SendWeaponAnim(pPlayer, RPG7_SHOOT2);
		set_member(this, m_Weapon_iWeaponState, 0);
	}
	else
		SendWeaponAnim(pPlayer, RPG7_SHOOT1);

	emit_sound(pPlayer, CHAN_WEAPON, g_szShootSound, VOL_NORM, ATTN_NORM, 0, 94 + random_num(0, 15));
	set_member(this, m_Weapon_flNextSecondaryAttack, UTIL_WeaponTimeBase(this) + RPG7_SHOOT_TIME);
	set_member(this, m_Weapon_flNextPrimaryAttack, GetNextAttackDelay(this, RPG7_SHOOT_TIME));
	set_member(this, m_Weapon_flTimeWeaponIdle, UTIL_WeaponTimeBase(this) + 2.0);

	punchangle[0] -= 3.0;

	set_entvar(pPlayer, var_punchangle, punchangle);
	return HAM_SUPERCEDE;
}

public Ham_Weapon_SecondaryAttack_Pre(const this)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_RPG7)
		return HAM_IGNORED;

	new pPlayer = get_member(this, m_pPlayer);
	new iClip = get_member(this, m_Weapon_iClip);

	if (get_member(this, m_Weapon_iWeaponState))
	{
		if (iClip <= 0)
			SendWeaponAnim(pPlayer, RPG7_CHANGE2_EMPTY);
		else
			SendWeaponAnim(pPlayer, RPG7_CHANGE2);

		set_member(this, m_Weapon_iWeaponState, 0);
	}
	else
	{
		if (iClip <= 0)
			SendWeaponAnim(pPlayer, RPG7_CHANGE1_EMPTY);
		else
			SendWeaponAnim(pPlayer, RPG7_CHANGE1);

		set_member(this, m_Weapon_iWeaponState, 1);
	}

	set_member(this, m_Weapon_flNextSecondaryAttack, UTIL_WeaponTimeBase(this) + RPG7_CHANGE_TIME);
	set_member(this, m_Weapon_flTimeWeaponIdle, UTIL_WeaponTimeBase(this) + RPG7_CHANGE_TIME);
	return HAM_SUPERCEDE;
}

public Ham_Weapon_WeaponIdle_Pre(const this)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_RPG7)
		return HAM_IGNORED;

	if (get_member(this, m_Weapon_flTimeWeaponIdle) > UTIL_WeaponTimeBase(this))
		return HAM_SUPERCEDE;

	new pPlayer = get_member(this, m_pPlayer);
	new iClip = get_member(this, m_Weapon_iClip);

	if (get_member(this, m_Weapon_iWeaponState))
	{
		if (iClip <= 0)
			SendWeaponAnim(pPlayer, RPG7_IDLE2_EMPTY);
		else
			SendWeaponAnim(pPlayer, RPG7_IDLE2);
	}
	else
	{
		if (iClip <= 0)
			SendWeaponAnim(pPlayer, RPG7_IDLE1_EMPTY);
		else
			SendWeaponAnim(pPlayer, RPG7_IDLE1);
	}

	set_member(this, m_Weapon_flTimeWeaponIdle, UTIL_WeaponTimeBase(this) + 20.0);
	return HAM_SUPERCEDE;
}

RocketCreate(const this)
{
	if (is_nullent(this))
		return 0;

	static maxEntities;

	if (!maxEntities)
		maxEntities = global_get(glb_maxEntities);

	if (maxEntities - engfunc(EngFunc_NumberOfEntities) <= 100)
		return 0;

	new pEntity = rg_create_entity("info_target", false);

	if (!pEntity || is_nullent(pEntity))
		return 0;

	new pPlayer = get_member(this, m_pPlayer);

	set_entvar(pEntity, var_classname, "rpg7_rocket");
	set_entvar(pEntity, var_owner, pPlayer);
	set_entvar(pEntity, var_iuser2, this);
	set_entvar(pEntity, var_iuser3, get_member(this, m_Weapon_iWeaponState));
	set_entvar(pEntity, var_movetype, MOVETYPE_FLY);
	set_entvar(pEntity, var_solid, SOLID_BBOX);
	set_entvar(pEntity, var_gravity, 0.01);

#if defined _zombie_special_new_included
	set_entvar(pEntity, var_dmg, float(ZP_RPG7_DAMAGE));
#else
	set_entvar(pEntity, var_dmg, float(RPG7_DAMAGE));
#endif

	engfunc(EngFunc_SetModel, pEntity, g_szRocketModel);
	engfunc(EngFunc_SetSize, pEntity, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});

	new Float:origin[3];
	get_entvar(pPlayer, var_origin, origin);
	engfunc(EngFunc_SetOrigin, pEntity, origin);

	SetTouch(pEntity, "ExplodeTouch");
	SetThink(pEntity, "RocketThink");
	set_entvar(pEntity, var_nextthink, get_gametime() + 0.2);
	return pEntity;
}

public RocketThink(const this)
{
	if (is_nullent(this))
		return;

	set_entvar(this, var_nextthink, get_gametime() + 0.05);

	if (get_entvar(this, var_waterlevel) == 0)
	{
		if (!get_entvar(this, var_iuser3))
		{
			new Float:velocity[3];
			get_entvar(this, var_velocity, velocity);

			velocity[2] += 50.0;

			set_entvar(this, var_velocity, velocity);
		}

		emit_sound(this, CHAN_VOICE, g_szRocketSound, 0.5, ATTN_NORM, 0, PITCH_NORM);

		new Float:origin[3];
		get_entvar(this, var_origin, origin);

		message_begin_f(MSG_PAS, SVC_TEMPENTITY, origin);
		write_byte(TE_EXPLOSION);
		write_coord_f(origin[0]);
		write_coord_f(origin[1]);
		write_coord_f(origin[2] - 10.0);
		write_short(g_iTrail);
		write_byte(5);
		write_byte(50);
		write_byte(TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOSOUND|TE_EXPLFLAG_NOPARTICLES);
		message_end();
		return;
	}

	new Float:origin[3], Float:velocity[3], Float:vecEnd[3];
	get_entvar(this, var_origin, origin);
	get_entvar(this, var_velocity, velocity);
	xs_vec_sub_scaled(origin, velocity, 0.1, vecEnd);
	UTIL_BubbleTrail(vecEnd, origin, 1);
}

public ExplodeTouch(const this, const pOther)
{
	if (is_nullent(this))
		return;

	SetThink(this, "");

	new Float:velocity[3], Float:origin[3], Float:vecSpot[3], Float:vecDest[3];
	get_entvar(this, var_velocity, velocity);
	xs_vec_normalize(velocity, velocity);
	get_entvar(this, var_origin, origin);

	if (engfunc(EngFunc_PointContents, origin) == CONTENTS_SKY)
	{
		rg_remove_entity(this);
		return;
	}

	xs_vec_sub_scaled(origin, velocity, 32.0, vecSpot);
	xs_vec_add_scaled(vecSpot, velocity, 64.0, vecDest);

	if (pOther)
		set_entvar(this, var_enemy, pOther);

	new tr = create_tr2();
	engfunc(EngFunc_TraceLine, vecSpot, vecDest, IGNORE_MONSTERS, this, tr);
	Explode3(this, tr, DMG_ALWAYSGIB);
	free_tr2(tr);
}

public Explode3(const this, pTrace, bitsDamageType)
{
	if (is_nullent(this))
		return;

	SetTouch(this, "");
	set_entvar(this, var_model, NULL_STRING);
	set_entvar(this, var_solid, SOLID_NOT);
	set_entvar(this, var_takedamage, DAMAGE_NO);

	new Float:flFraction, Float:vecEndPos[3], Float:vecPlaneNormal[3], Float:origin[3];
	get_tr2(pTrace, TR_flFraction, flFraction);
	get_tr2(pTrace, TR_vecEndPos, vecEndPos);
	get_tr2(pTrace, TR_vecPlaneNormal, vecPlaneNormal);
	get_entvar(this, var_origin, origin);

	if (flFraction != 1.0)
	{
		for (new i = 0; i < 3; i++)
			origin[i] = vecEndPos[i] + (vecPlaneNormal[i] * (100.0 - 24.0) * 0.6);
	}

	MakeExplosion(
		origin, 
		.height = 20.0, 
		.spriteindex = g_sModelIndexFireball3, 
		.scale = 25, 
		.framerate = 30, 
		.flags = TE_EXPLFLAG_NONE
	);

	new Float:rand[3];
	rand[0] = origin[0] + random_float(-64.0, 64.0);
	rand[1] = origin[1] + random_float(-64.0, 64.0);
	rand[2] = origin[2] + random_float(30.0, 35.0);

	MakeExplosion(
		rand, 
		.height = 0.0, 
		.spriteindex = g_sModelIndexFireball2, 
		.scale = 30, 
		.framerate = 30, 
		.flags = TE_EXPLFLAG_NONE
	);

	new pevOwner = get_entvar(this, var_owner);
	new pevWeapon = get_entvar(this, var_iuser2);

	set_entvar(this, var_owner, 0);

	new Float:flDmg;
	get_entvar(this, var_dmg, flDmg);

	if (!is_nullent(pevWeapon))
		rg_dmg_radius(origin, pevWeapon, pevOwner, flDmg, 350.0, CLASS_NONE, bitsDamageType);
	else
		rg_dmg_radius(origin, this, pevOwner, flDmg, 350.0, CLASS_NONE, bitsDamageType);

	new pVictim = 0;

	while ((pVictim = engfunc(EngFunc_FindEntityInSphere, pVictim, origin, 350.0)) > 0)
	{
		if (rg_is_player_can_takedamage(pVictim, pevOwner))
			Knockback(this, 300.0, pVictim, 1.0, true);
	}

	if (random_float(0.0, 1.0) < 0.5)
		rg_decal_trace(pTrace, DECAL_SCORCH1);
	else
		rg_decal_trace(pTrace, DECAL_SCORCH2);

	switch (random_num(0, 2))
	{
		case 0:
			emit_sound(this, CHAN_VOICE, "weapons/debris1.wav", 0.55, ATTN_NORM, 0, PITCH_NORM);
		case 1:
			emit_sound(this, CHAN_VOICE, "weapons/debris2.wav", 0.55, ATTN_NORM, 0, PITCH_NORM);
		case 2:
			emit_sound(this, CHAN_VOICE, "weapons/debris3.wav", 0.55, ATTN_NORM, 0, PITCH_NORM);
	}

	set_entvar(this, var_effects, get_entvar(this, var_effects) | EF_NODRAW);
	SetThink(this, "Smoke3_C");
	set_entvar(this, var_velocity, NULL_VECTOR);
	set_entvar(this, var_nextthink, get_gametime() + 0.55);

	new sparkCount = random_num(0, 3);
	for (new i = 0; i < sparkCount; i++)
		Create("spark_shower", origin, vecPlaneNormal, 0);
}

public Smoke3_C(const this)
{
	new Float:origin[3];
	get_entvar(this, var_origin, origin);

	if (engfunc(EngFunc_PointContents, origin) == CONTENTS_WATER)
	{
		new Float:size[3], Float:mins[3], Float:maxs[3];
		xs_vec_set(size, 64.0, 64.0, 64.0);
		xs_vec_sub(origin, size, mins);
		xs_vec_add(origin, size, maxs);
		UTIL_Bubbles(mins, maxs, 100);
	}
	else
	{
		message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin);
		write_byte(TE_SMOKE);
		write_coord_f(origin[0]);
		write_coord_f(origin[1]);
		write_coord_f(origin[2] - 5.0);
		write_short(g_sModelIndexSmoke);
		write_byte(35 + random_num(0, 10));
		write_byte(5);
		message_end();
	}

	rg_remove_entity(this);
}

stock UTIL_Bubbles(Float:mins[3], Float:maxs[3], count)
{
	new Float:mid[3];
	xs_vec_add_scaled(mins, maxs, 0.5, mid);

	new Float:flHeight = UTIL_WaterLevel(mid, mid[2], mid[2] + 1024.0) - mins[2];

	message_begin_f(MSG_PAS, SVC_TEMPENTITY, mid);
	write_byte(TE_BUBBLES);
	write_coord_f(mins[0]);
	write_coord_f(mins[1]);
	write_coord_f(mins[2]);
	write_coord_f(maxs[0]);
	write_coord_f(maxs[1]);
	write_coord_f(maxs[2]);
	write_coord_f(flHeight);
	write_short(g_sModelIndexBubbles);
	write_byte(count);
	write_coord_f(8.0);
	message_end();
}

stock UTIL_BubbleTrail(Float:from[3], Float:to[3], count)
{
	new Float:flHeight = UTIL_WaterLevel(from, from[2], from[2] + 256.0) - from[2];

	if (flHeight < 8.0)
	{
		flHeight = UTIL_WaterLevel(to, to[2], to[2] + 256.0) - to[2];

		if (flHeight < 8.0)
			return;

		flHeight = flHeight + to[2] - from[2];
	}

	if (count > 255)
		count = 255;

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BUBBLETRAIL);
	write_coord_f(from[0]);
	write_coord_f(from[1]);
	write_coord_f(from[2]);
	write_coord_f(to[0]);
	write_coord_f(to[1]);
	write_coord_f(to[2]);
	write_coord_f(flHeight);
	write_short(g_sModelIndexBubbles);
	write_byte(count);
	write_coord_f(8.0);
	message_end();
}

stock Float:UTIL_WaterLevel(const Float:position[3], Float:minz, Float:maxz)
{
	new Float:midUp[3], Float:diff;
	xs_vec_copy(position, midUp);

	midUp[2] = minz;

	if (engfunc(EngFunc_PointContents, midUp) != CONTENTS_WATER)
		return minz;

	midUp[2] = maxz;

	if (engfunc(EngFunc_PointContents, midUp) == CONTENTS_WATER)
		return maxz;

	diff = maxz - minz;

	while (diff > 1.0)
	{
		midUp[2] = minz + diff / 2.0;

		if (engfunc(EngFunc_PointContents, midUp) == CONTENTS_WATER)
			minz = midUp[2];
		else
			maxz = midUp[2];

		diff = maxz - minz;
	}

	return midUp[2];
}

stock GetGunFullPosition(const this, const Float:flForward = 40.0, const Float:flRight = 0.0, const Float:flUp = 0.0, Float:vecOut[3])
{
	new Float:v_angle[3], Float:punchangle[3], Float:rgflVec[3], Float:v_forward[3], Float:v_right[3], Float:v_up[3], Float:vecSrc[3];
	get_entvar(this, var_v_angle, v_angle);
	get_entvar(this, var_punchangle, punchangle);
	xs_vec_add(v_angle, punchangle, rgflVec);
	engfunc(EngFunc_AngleVectors, rgflVec, v_forward, v_right, v_up);
	GetGunPosition(this, vecSrc);
	xs_vec_add_scaled(vecSrc, v_forward, flForward, vecSrc);
	xs_vec_add_scaled(vecSrc, v_right, flRight, vecSrc);
	xs_vec_add_scaled(vecSrc, v_up, flUp, vecSrc);
	xs_vec_copy(vecSrc, vecOut);
}

stock GetGunPosition(const this, Float:vecSrc[3])
{
	new Float:origin[3], Float:view_ofs[3];
	get_entvar(this, var_origin, origin);
	get_entvar(this, var_view_ofs, view_ofs);
	xs_vec_add(origin, view_ofs, vecSrc);
}

stock Float:GetNextAttackDelay(const this, const Float:delay)
{
	new Float:flNextAttack = UTIL_WeaponTimeBase(this) + delay;
	set_member(this, m_Weapon_flLastFireTime, get_gametime());
	set_member(this, m_Weapon_flPrevPrimaryAttack, flNextAttack - UTIL_WeaponTimeBase(this));
	return flNextAttack;
}

stock Float:UTIL_WeaponTimeBase(const this)
{
	#pragma unused this

	return 0.0;
}

stock GetWeaponBoxItem(const this)
{
	for (new iSlot, pItem; iSlot < MAX_ITEM_TYPES; iSlot++)
	{
		if (!is_nullent((pItem = get_member(this, m_WeaponBox_rgpPlayerItems, iSlot))))
			return pItem;
	}

	return NULLENT;
}

stock SendWeaponAnim(const this, const iAnim)
{
	static iAnimEx, iBody;
	iAnimEx = iAnim;
	iBody = g_iBody[this];

	set_entvar(this, var_weaponanim, iAnimEx);
	emessage_begin(MSG_ONE, SVC_WEAPONANIM, {0,0,0}, this);
	ewrite_byte(iAnimEx);
	ewrite_byte(iBody);
	emessage_end();

	if (get_entvar(this, var_iuser1))
		return;

	static aPlayers[MAX_PLAYERS], iNum, i, iSpec;
	get_players(aPlayers, iNum, "bh");

	for (i = 0; i < iNum; i++)
	{
		iSpec = aPlayers[i];

		if (get_entvar(iSpec, var_iuser1) != OBS_IN_EYE || get_entvar(iSpec, var_iuser2) != this)
			continue;

		set_entvar(iSpec, var_weaponanim, iAnimEx);
		emessage_begin(MSG_ONE, SVC_WEAPONANIM, {0,0,0}, iSpec);
		ewrite_byte(iAnimEx);
		ewrite_byte(iBody);
		emessage_end();
	}
}

stock bool:IsLocalWeapon(const this)
{
	new szValue[4];

	if (!get_user_info(this, "cl_lw", szValue, charsmax(szValue)))
		return false;

	if (str_to_num(szValue) <= 0)
		return false;

	return true;
}

stock UTIL_SetOrigin(const this, const Float:origin[3])
{
	new Float:mins[3], Float:maxs[3];
	get_entvar(this, var_mins, mins);
	get_entvar(this, var_maxs, maxs);
	engfunc(EngFunc_SetSize, this, mins, maxs);
	engfunc(EngFunc_SetOrigin, this, origin);
}

stock Create(const szName[], const Float:vecOrigin[3], const Float:vecAngles[3], const pentOwner)
{
	if (!szName[0])
		return 0;

	static maxEntities;

	if (!maxEntities)
		maxEntities = global_get(glb_maxEntities);

	if (maxEntities - engfunc(EngFunc_NumberOfEntities) <= 100)
	{
		engfunc(EngFunc_AlertMessage, at_console, "Exceeded the limit!^n");
		return 0;
	}

	new pEntity = rg_create_entity(szName);

	if (!pEntity || is_nullent(pEntity))
	{
		engfunc(EngFunc_AlertMessage, at_console, "NULL Ent in Create!^n");
		return 0;
	}

	set_entvar(pEntity, var_origin, vecOrigin);
	set_entvar(pEntity, var_angles, vecAngles);
	set_entvar(pEntity, var_owner, pentOwner);
	dllfunc(DLLFunc_Spawn, pEntity);
	return pEntity;
}

stock UTIL_GiveCustomWeapon(const this, const pszName[], const uId = 0, const iClipSize = 0, const iMaxAmmo1 = 0)
{
	if (!equal(pszName, "weapon_", 7))
		return NULLENT;

	new pWeapon = UTIL_HasWeapon(this, pszName);

	if (pWeapon && !is_nullent(pWeapon))
		rg_drop_item(this, pszName);

	new pCustomWeapon = rg_create_entity(pszName);

	if (!pCustomWeapon || is_nullent(pCustomWeapon))
		return NULLENT;

	new Float:origin[3];
	get_entvar(this, var_origin, origin);
	set_entvar(pCustomWeapon, var_origin, origin);
	set_entvar(pCustomWeapon, var_spawnflags, get_entvar(pCustomWeapon, var_spawnflags) | SF_NORESPAWN);
	set_entvar(pCustomWeapon, var_impulse, uId);
	dllfunc(DLLFunc_Spawn, pCustomWeapon);

	if (iClipSize)
		rg_set_iteminfo(pCustomWeapon, ItemInfo_iMaxClip, iClipSize);

	if (iMaxAmmo1)
		rg_set_iteminfo(pCustomWeapon, ItemInfo_iMaxAmmo1, iMaxAmmo1);

	dllfunc(DLLFunc_Touch, pCustomWeapon, this);

	if (get_entvar(pCustomWeapon, var_owner) != this)
	{
		set_entvar(pCustomWeapon, var_flags, FL_KILLME);
		return NULLENT;
	}

	return pCustomWeapon;
}

stock UTIL_HasWeapon(const this, const pszName[])
{
	new pWeapon;

	for (new iSlot = any:PRIMARY_WEAPON_SLOT, pWeapons; iSlot <= any:C4_SLOT; iSlot++)
	{
		pWeapons = get_member(this, m_rgpPlayerItems, iSlot);

		if (!pWeapons || is_nullent(pWeapons))
			continue;

		if (FClassnameIs(pWeapons, pszName))
			pWeapon = pWeapons;
	}

	return pWeapon;
}

stock precache_sounds_from_model(const name[])
{
	if (file_exists(name))
	{
		new file = fopen(name, "rb");

		if (file)
		{
			new seqNum, seqIndex, eventsNum, eventIndex, event;
			new filename[256];

			fseek(file, 164, SEEK_SET);
			fread(file, seqNum, BLOCK_INT);
			fread(file, seqIndex, BLOCK_INT);

			for (new k, i = 0; i < seqNum; i++)
			{
				fseek(file, seqIndex + 48 + 176 * i, SEEK_SET);
				fread(file, eventsNum, BLOCK_INT);
				fread(file, eventIndex, BLOCK_INT);
				fseek(file, eventIndex + 176 * i, SEEK_SET);

				for (k = 0; k < eventsNum; k++)
				{
					fseek(file, eventIndex + 4 + 76 * k, SEEK_SET);
					fread(file, event, BLOCK_INT);
					fseek(file, 4, SEEK_CUR);

					if (event != 5004)
						continue;

					fread_blocks(file, filename, 64, BLOCK_CHAR);

					if (strlen(filename))
					{
						strtolower(filename);
						precache_sound(filename);
					}
				}
			}

			fclose(file);
		}
	}
}

stock precache_sprites_from_text(const name[])
{
	new filedir[256];
	formatex(filedir, charsmax(filedir), "sprites/%s.txt", name);

	if (file_exists(filedir))
	{
		precache_generic(filedir);

		new file = fopen(filedir, "rb");

		if (file)
		{
			new pos;
			new data[256], filedata[256], filename[256];

			while (!feof(file))
			{
				fgets(file, data, charsmax(data));
				trim(data);

				if (!strlen(data))
					continue;

				pos = containi(data, "640");

				if (pos == -1)
					continue;

				formatex(filedata, charsmax(filedata), "%s", data[pos + 3]);
				trim(filedata);

				strtok(filedata, filename, charsmax(filename), filedata, charsmax(filedata), ' ', 1);
				trim(filename);

				formatex(filedir, charsmax(filedir), "sprites/%s.spr", filename);
				precache_generic(filedir);
			}

			fclose(file);
		}
	}
}

stock MakeWeaponList(
	const this, 
	const pszName[], 
	const ammo1, 
	const maxammo1, 
	const ammo2, 
	const maxammo2, 
	const slot, 
	const position, 
	const id, 
	const flags
)
{
	message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, this);
	write_string(pszName);
	write_byte(ammo1);
	write_byte(maxammo1);
	write_byte(ammo2);
	write_byte(maxammo2);
	write_byte(slot);
	write_byte(position);
	write_byte(id);
	write_byte(flags);
	message_end();
}

stock MakeExplosion(const Float:origin[3], const Float:height, const spriteindex, const scale, const framerate, const flags)
{
	message_begin_f(MSG_PAS, SVC_TEMPENTITY, origin);
	write_byte(TE_EXPLOSION);
	write_coord_f(origin[0]);
	write_coord_f(origin[1]);
	if (height > 0.0)
		write_coord_f(origin[2] + height);
	else
		write_coord_f(origin[2]);
	write_short(spriteindex);
	write_byte(scale);
	write_byte(framerate);
	write_byte(flags);
	message_end();
}

stock Knockback(const pAttacker, const Float:flForce, const pVictim, const Float:modvel = 1.0, const bool:zvel = true, const bool:noimpact = false)
{
	if (noimpact)
	{
		set_member(pVictim, m_flVelocityModifier, 1.0);
		return;
	}

	new Float:velocity[3], Float:velocityz, Float:origin[3], Float:atkPos[3], Float:vecDir[3];
	get_entvar(pVictim, var_velocity, velocity);
	velocityz = velocity[2];
	get_entvar(pVictim, var_origin, origin);
	get_entvar(pAttacker, var_origin, atkPos);
	xs_vec_sub(origin, atkPos, vecDir);
	xs_vec_normalize(vecDir, vecDir);
	xs_vec_mul_scalar(vecDir, flForce, vecDir);
	xs_vec_add(velocity, vecDir, velocity);

	if (!zvel)
		velocity[2] = velocityz;

	set_entvar(pVictim, var_velocity, velocity);
	set_member(pVictim, m_flVelocityModifier, modvel);
}
