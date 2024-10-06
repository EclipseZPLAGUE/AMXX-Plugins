#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <xs>
#include <engine>
//#include <zombie_plague_special>

#define WEAPON_NOCLIP -1
#define Instance(%0) ((%0 == NULLENT) ? 0 : %0)
#define WEAPON_M134 10155
#define MAX_AMMO_SLOTS 32
#define M134_MAX_CLIP 200
#define M134_MAX_CARRY 200

#define CTEXTURESMAX		1024	// max number of textures loaded
#define CBTEXTURENAMEMAX	17	// only load first n chars of name

#define CHAR_TEX_CONCRETE	'C'	// texture types
#define CHAR_TEX_METAL		'M'
#define CHAR_TEX_DIRT		'D'
#define CHAR_TEX_VENT		'V'
#define CHAR_TEX_GRATE		'G'
#define CHAR_TEX_TILE		'T'
#define CHAR_TEX_SLOSH		'S'
#define CHAR_TEX_WOOD		'W'
#define CHAR_TEX_COMPUTER	'P'
#define CHAR_TEX_GRASS		'X'
#define CHAR_TEX_GLASS		'Y'
#define CHAR_TEX_FLESH		'F'
#define CHAR_TEX_SNOW		'N'

const WeaponIdType:WEAPON_REFERENCE = WEAPON_M249;

const M134_DAMAGE = 54;

const Float:M134_MAX_SPEED = 250.0;
const Float:M134_RANGE_MODIFER = 0.82;
const Float:M134_RELOAD_TIME = 5.0;
const Float:M134_ACCURACY_DIVISOR = 210.0;

enum _:m134_e
{
	M134_IDLE1,
	M134_SHOOT1,
	M134_SHOOT2,
	M134_RELOAD,
	M134_DRAW,
	M134_FIRE_READY,
	M134_FIRE_AFTER,
	M134_FIRE_CHANGE,
	M134_IDLE_CHANGE,
	M134_FIRE_LOOP,
};

new const g_szWeaponModel[] = "models/p_m134.mdl";
new const g_szViewModel[] = "models/v_m134.mdl";
new const g_szWeaponBoxModel[] = "models/w_m134.mdl";
new const g_szShootSound[] = "weapons/m134-1.wav";

new g_iRShell;
new g_iSmoke_WallPuff;

new g_iBody[MAX_PLAYERS + 1];
new g_iRighthand[MAX_PLAYERS + 1];

new Float:g_flLastEventCheck[MAX_PLAYERS + 1];

#if defined _zombie_special_new_included
new g_iItem;
#endif

public plugin_precache()
{
	precache_model(g_szWeaponModel);
	precache_model(g_szViewModel);
	precache_model(g_szWeaponBoxModel);

	g_iRShell = precache_model("models/rshell.mdl");
	g_iSmoke_WallPuff = precache_model("sprites/wall_puff1.spr");

	precache_sound(g_szShootSound);
}

public plugin_init()
{
	register_plugin("Weapon: M134 Minigun", "1.0", "Eclipse*");

	register_forward(FM_PlaybackEvent, "FM_PlaybackEvent_Pre", 0);
	register_forward(FM_UpdateClientData, "FM_UpdateClientData_Post", 1);

	RegisterHookChain(RG_CBasePlayer_Observer_IsValidTarget, "RG_CBasePlayer_Observer_IsValidTarget_Post", 1);
	RegisterHookChain(RG_CWeaponBox_SetModel, "RG_CWeaponBox_SetModel_Pre", 0);

	RegisterHookChain(RG_CBasePlayerWeapon_ItemPostFrame, "RG_CBasePlayerWeapon_ItemPostFrame_Pre", 0);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "RG_CBasePlayerWeapon_DefaultDeploy_Pre", 0);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "RG_CBasePlayerWeapon_DefaultDeploy_Post", 1);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "RG_CBasePlayerWeapon_DefaultReload_Pre", 0);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "RG_CBasePlayerWeapon_DefaultReload_Post", 1);
	RegisterHookChain(RG_CBasePlayerWeapon_SendWeaponAnim, "RG_CBasePlayerWeapon_SendWeaponAnim_Pre", 0);

	new pszName[MAX_NAME_LENGTH];
	rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_pszName, pszName, charsmax(pszName));
	RegisterHam(Ham_Item_AddToPlayer, pszName, "Ham_Item_AddToPlayer_Post", 1, true);
	RegisterHam(Ham_Weapon_PrimaryAttack, pszName, "Ham_Weapon_PrimaryAttack_Pre", 0, true);
	RegisterHam(Ham_Weapon_SecondaryAttack, pszName, "Ham_Weapon_SecondaryAttack_Pre", 0, true);

#if defined _zombie_special_new_included
	g_iItem = zp_register_extra_item("M134 Minigun", 50, ZP_TEAM_HUMAN);
#else
	register_clcmd("give_m134", "clcmd_GiveM134");
#endif
}

public client_putinserver(this)
{
	g_iBody[this] = 0;
	g_iRighthand[this] = 0;
	g_flLastEventCheck[this] = 0.0;

	if (is_user_connected(this) && !is_user_bot(this) && !is_user_hltv(this))
		query_client_cvar(this, "cl_righthand", "cvar_query_righthand");
}

public cvar_query_righthand(this, const cvar[], const value[], const param[])
{
	g_iRighthand[this] = str_to_num(value);
}

public client_disconnected(this)
{
	g_iBody[this] = 0;
	g_iRighthand[this] = 0;
	g_flLastEventCheck[this] = 0.0;
}

#if defined _zombie_special_new_included
public zp_extra_item_selected(this, item)
{
	if (item != g_iItem)
		return;

	new pszName[32];
	rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_pszName, pszName, charsmax(pszName));
	new pItem = rg_give_custom_item(this, pszName, GT_DROP_AND_REPLACE, WEAPON_M134);

	if (!is_nullent(pItem))
	{
		rg_set_iteminfo(pItem, ItemInfo_iMaxClip, M134_MAX_CLIP);
		rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, M134_MAX_CARRY);

		set_member(pItem, m_Weapon_flBaseDamage, float(M134_DAMAGE));
		set_member(pItem, m_Weapon_iClip, M134_MAX_CLIP);
		set_member(pItem, m_Weapon_iStateSecondaryAttack, WEAPON_SECONDARY_ATTACK_SET);
		set_member(this, m_rgAmmo, M134_MAX_CARRY, get_member(pItem, m_Weapon_iPrimaryAmmoType));
	}
}
#else
public clcmd_GiveM134(const this)
{
	new pszName[32];
	rg_get_global_iteminfo(WEAPON_REFERENCE, ItemInfo_pszName, pszName, charsmax(pszName));
	new pItem = rg_give_custom_item(this, pszName, GT_DROP_AND_REPLACE, WEAPON_M134);

	if (!is_nullent(pItem))
	{
		rg_set_iteminfo(pItem, ItemInfo_iMaxClip, M134_MAX_CLIP);
		rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, M134_MAX_CARRY);

		set_member(pItem, m_Weapon_iClip, M134_MAX_CLIP);
		set_member(pItem, m_Weapon_flBaseDamage, float(M134_DAMAGE));
		set_member(pItem, m_Weapon_iStateSecondaryAttack, WEAPON_SECONDARY_ATTACK_SET);
		set_member(this, m_rgAmmo, M134_MAX_CARRY, get_member(pItem, m_Weapon_iPrimaryAmmoType));
	}

	return PLUGIN_HANDLED;
}
#endif

public FM_PlaybackEvent_Pre(flags, entid, eventid, Float:delay, Float:Origin[3], Float:Angles[3], Float:fparam1, Float:fparam2, iparam1, iparam2, bparam1, bparam2)
{
	if (!(entid >= 1 && entid <= MaxClients) || !is_user_connected(entid) || !is_user_alive(entid))
		return FMRES_IGNORED;

	new pActiveItem = get_member(entid, m_pActiveItem);

	if (is_nullent(pActiveItem) || rg_get_iteminfo(pActiveItem, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(pActiveItem, var_impulse) != WEAPON_M134)
		return FMRES_IGNORED;

	return FMRES_SUPERCEDE;
}

public FM_UpdateClientData_Post(const this, sendWeapons, hCD)
{
	if (!is_user_connected(this) || !GetLocalWeapon(this))
		return FMRES_IGNORED;

	static pTarget;
	pTarget = get_entvar(this, var_iuser1) ? get_entvar(this, var_iuser2) : this;

	if (!is_user_alive(pTarget))
		return FMRES_IGNORED;

	static pActiveItem;
	pActiveItem = get_member(pTarget, m_pActiveItem);

	if (is_nullent(pActiveItem) || rg_get_iteminfo(pActiveItem, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(pActiveItem, var_impulse) != WEAPON_M134)
		return FMRES_IGNORED;

	static Float:flTime;
	flTime = get_gametime();

	set_cd(hCD, CD_flNextAttack, flTime + 0.1);

	if (!g_flLastEventCheck[this])
	{
		if (g_iBody[this])
			set_cd(hCD, CD_WeaponAnim, M134_IDLE1);

		return FMRES_HANDLED;
	}

	if (g_flLastEventCheck[this] <= flTime)
	{
		SendWeaponAnim(this, M134_DRAW);
		g_flLastEventCheck[this] = 0.0;
	}

	return FMRES_IGNORED;
}

public pfn_playbackevent(flags, entid, eventid, Float:delay, Float:Origin[3], Float:Angles[3], Float:fparam1, Float:fparam2, iparam1, iparam2, bparam1, bparam2)
{
	if (!(entid >= 1 && entid <= MaxClients) || !is_user_connected(entid) || !is_user_alive(entid))
		return PLUGIN_CONTINUE;

	static pActiveItem;
	pActiveItem = get_member(entid, m_pActiveItem);

	if (is_nullent(pActiveItem) || rg_get_iteminfo(pActiveItem, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(pActiveItem, var_impulse) != WEAPON_M134)
		return PLUGIN_CONTINUE;

	if (is_user_connected(entid) && !is_user_bot(entid) && !is_user_hltv(entid))
		query_client_cvar(entid, "cl_righthand", "cvar_query_righthand");

	EV_FireM134(entid, Origin, Angles, fparam1, fparam2, iparam1, iparam2);
	return PLUGIN_HANDLED;
}

EV_FireM134(const this, Float:Origin[3], Float:Angles[3], Float:fparam1, Float:fparam2, iparam1, iparam2)
{
	get_entvar(this, var_origin, Origin);
	get_entvar(this, var_v_angle, Angles);

	Angles[0] = (float(iparam1) / 100.0) + Angles[0];
	Angles[1] = (float(iparam2) / 100.0) + Angles[1];

	new Float:v_forward[3], Float:v_right[3], Float:v_up[3];
	engfunc(EngFunc_AngleVectors, Angles, v_forward, v_right, v_up);

	new Float:velocity[3];
	get_entvar(this, var_velocity, velocity);

	new Float:ShellVelocity[3], Float:ShellOrigin[3];

	if (!g_iRighthand[this])
		EV_GetDefaultShellInfo(this, Origin, velocity, ShellVelocity, ShellOrigin, v_forward, v_right, v_up, 20.0, -10.0, -13.0, false);
	else
		EV_GetDefaultShellInfo(this, Origin, velocity, ShellVelocity, ShellOrigin, v_forward, v_right, v_up, 20.0, -10.0, 13.0, false);

	EV_EjectBrass(ShellOrigin, ShellVelocity, Angles[1], g_iRShell, TE_BOUNCE_SHELL);
	SendWeaponAnim(this, random_num(M134_SHOOT1, M134_SHOOT2));
	emit_sound(this, CHAN_WEAPON, g_szShootSound, VOL_NORM, ATTN_NORM, 0, 94 + random_num(0, 15));

	new Float:vecSrc[3];
	EV_GetGunPosition(this, vecSrc, Origin);

	new Float:vecAiming[3];
	xs_vec_copy(v_forward, vecAiming);

	new Float:vSpread[3];
	vSpread[0] = fparam1;
	vSpread[1] = fparam2;
	vSpread[2] = 0.0;

	EV_HLDM_FireBullets(this, v_right, v_up, 1, vecSrc, vecAiming, vSpread, 8192.0, any:BULLET_PLAYER_556MM, 2);
}

public RG_CBasePlayer_Observer_IsValidTarget_Post(const this, iPlayerIndex, bool:bSameTeam)
{
	if (!is_user_connected(this) || !is_user_alive(iPlayerIndex))
		return HC_CONTINUE;

	new pActiveItem = get_member(iPlayerIndex, m_pActiveItem);

	if (is_nullent(pActiveItem) || rg_get_iteminfo(pActiveItem, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(pActiveItem, var_impulse) != WEAPON_M134)
		return HC_CONTINUE;

	g_iBody[this] = g_iBody[iPlayerIndex];
	SendWeaponAnim(this, M134_IDLE1);

	if (GetLocalWeapon(this) && g_iBody[this])
		g_flLastEventCheck[this] = get_gametime() + 0.1;

	return HC_CONTINUE;
}

public RG_CWeaponBox_SetModel_Pre(const this, szModelName[])
{
	if (is_nullent(this))
		return HC_CONTINUE;

	static pItem;
	pItem = GetWeaponBoxItem(this);

	if (!is_nullent(pItem) && rg_get_iteminfo(pItem, ItemInfo_iId) == any:WEAPON_REFERENCE && get_entvar(pItem, var_impulse) == WEAPON_M134)
		SetHookChainArg(2, ATYPE_STRING, g_szWeaponBoxModel);

	return HC_CONTINUE;
}

public RG_CBasePlayerWeapon_DefaultDeploy_Pre(const this, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_M134)
		return HC_CONTINUE;

	new pPlayer = get_member(this, m_pPlayer);

	g_iBody[pPlayer] = get_entvar(this, var_body);

	SetHookChainArg(2, ATYPE_STRING, g_szViewModel);
	SetHookChainArg(3, ATYPE_STRING, g_szWeaponModel);

	if (GetLocalWeapon(pPlayer) && g_iBody[pPlayer])
	{
		g_flLastEventCheck[pPlayer] = get_gametime() + 0.1;
		SetHookChainArg(4, ATYPE_INTEGER, M134_IDLE1);
	}
	else
		SetHookChainArg(4, ATYPE_INTEGER, M134_DRAW);

	SetHookChainArg(5, ATYPE_STRING, "m249");
	SetHookChainArg(6, ATYPE_INTEGER, 0);
	return HC_CONTINUE;
}

public RG_CBasePlayerWeapon_DefaultDeploy_Post(const this, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal)
{
	new pPlayer = get_member(this, m_pPlayer);

	set_member(pPlayer, m_flNextAttack, 1.25);
	set_member(this, m_Weapon_iWeaponState, 0);
}

public RG_CBasePlayerWeapon_DefaultReload_Pre(const this, iClipSize, iAnim, Float:fDelay)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_M134)
		return HC_CONTINUE;

	SetHookChainArg(2, ATYPE_INTEGER, M134_MAX_CLIP);
	SetHookChainArg(3, ATYPE_INTEGER, M134_RELOAD);
	SetHookChainArg(4, ATYPE_FLOAT, M134_RELOAD_TIME);
	return HC_CONTINUE;
}

public RG_CBasePlayerWeapon_DefaultReload_Post(const this, iClipSize, iAnim, Float:fDelay)
{
	set_member(this, m_Weapon_iWeaponState, 0);
}

public RG_CBasePlayerWeapon_SendWeaponAnim_Pre(const this, iAnim, skiplocal)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_M134)
		return HC_CONTINUE;

	SendWeaponAnim(get_member(this, m_pPlayer), iAnim);
	return HC_SUPERCEDE;
}

public RG_CBasePlayerWeapon_ItemPostFrame_Pre(const this)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_M134)
		return HC_CONTINUE;

	static pPlayer;
	pPlayer = get_member(this, m_pPlayer);

	if ((get_entvar(pPlayer, var_button) & IN_ATTACK2) && get_member(this, m_Weapon_flNextSecondaryAttack) <= UTIL_WeaponTimeBase(this) && !get_member(pPlayer, m_bIsDefusing))
	{
		new pszAmmo2[32];
		rg_get_iteminfo(this, ItemInfo_pszAmmo2, pszAmmo2, charsmax(pszAmmo2));

		if (pszAmmo2[0] && !get_member(pPlayer, m_rgAmmo, get_member(this, m_Weapon_iSecondaryAmmoType)))
			set_member(this, m_Weapon_fFireOnEmpty, true);
	}
	else if ((get_entvar(pPlayer, var_button) & IN_ATTACK) && get_member(this, m_Weapon_flNextPrimaryAttack) <= UTIL_WeaponTimeBase(this))
	{
		if (get_member(this, m_Weapon_iClip) <= 0 || (get_member(this, m_Weapon_iClip) && (!get_member(pPlayer, m_bCanShoot) || get_member_game(m_bFreezePeriod) || get_member(pPlayer, m_bIsDefusing) 
		|| get_entvar(pPlayer, var_waterlevel) == 3 && (rg_get_iteminfo(this, ItemInfo_iFlags) & ITEM_FLAG_NOFIREUNDERWATER))))
		{
			if (get_member(this, m_Weapon_iWeaponState) && get_entvar(pPlayer, var_weaponanim) != M134_IDLE_CHANGE)
			{
				set_member(this, m_Weapon_iWeaponState, 0);
				SendWeaponAnim(pPlayer, M134_IDLE_CHANGE);
				set_member(this, m_Weapon_flTimeWeaponIdle, UTIL_WeaponTimeBase(this) + 1.3);
				set_member(this, m_Weapon_flNextSecondaryAttack, UTIL_WeaponTimeBase(this) + 1.3);
				set_member(this, m_Weapon_flNextPrimaryAttack, GetNextAttackDelay(this, 1.3));
			}
		}
	}
	else if ((get_entvar(pPlayer, var_button) & IN_RELOAD) 
	&& rg_get_iteminfo(this, ItemInfo_iMaxClip) != WEAPON_NOCLIP 
	&& !get_member(this, m_Weapon_fInReload) && get_member(this, m_Weapon_flNextPrimaryAttack) < UTIL_WeaponTimeBase(this))
	{
		/*if (get_member(this, m_Weapon_flFamasShoot) == 0.0 && get_member(this, m_Weapon_flGlock18Shoot) == 0.0)
		{
			if (!(get_member(this, m_Weapon_iWeaponState) & WPNSTATE_SHIELD_DRAWN))
				ExecuteHamB(Ham_Weapon_Reload, this);
		}*/
	}
	else if (!(get_entvar(pPlayer, var_button) & (IN_ATTACK | IN_ATTACK2)))
	{
		if (get_member(this, m_Weapon_iWeaponState) && get_entvar(pPlayer, var_weaponanim) != M134_IDLE_CHANGE)
		{
			set_member(this, m_Weapon_iWeaponState, 0);
			SendWeaponAnim(pPlayer, M134_IDLE_CHANGE);
			set_member(this, m_Weapon_flTimeWeaponIdle, UTIL_WeaponTimeBase(this) + 1.3);
			set_member(this, m_Weapon_flNextSecondaryAttack, UTIL_WeaponTimeBase(this) + 1.3);
			set_member(this, m_Weapon_flNextPrimaryAttack, GetNextAttackDelay(this, 1.3));
		}
	}

	return HC_CONTINUE;
}

public Ham_Item_AddToPlayer_Post(const this, const pPlayer)
{
	set_entvar(this, var_body, 1);
}

public Ham_Weapon_PrimaryAttack_Pre(const this)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_M134)
		return HAM_IGNORED;

	if (get_member(this, m_Weapon_iClip) <= 0)
		return HAM_IGNORED;

	new pPlayer = get_member(this, m_pPlayer);

	if (!get_member(this, m_Weapon_iWeaponState))
	{
		set_member(this, m_Weapon_iWeaponState, 1);
		SendWeaponAnim(pPlayer, M134_FIRE_READY);
		set_member(this, m_Weapon_flNextSecondaryAttack, UTIL_WeaponTimeBase(this) + 1.5);
		set_member(this, m_Weapon_flNextPrimaryAttack, GetNextAttackDelay(this, 1.5));
		set_member(this, m_Weapon_flTimeWeaponIdle, UTIL_WeaponTimeBase(this) + 1.5);
		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public Ham_Weapon_SecondaryAttack_Pre(const this)
{
	if (rg_get_iteminfo(this, ItemInfo_iId) != any:WEAPON_REFERENCE || get_entvar(this, var_impulse) != WEAPON_M134)
		return HAM_IGNORED;

	new pPlayer = get_member(this, m_pPlayer);

	if (!get_member(this, m_Weapon_iWeaponState))
	{
		set_member(this, m_Weapon_iWeaponState, 1);
		SendWeaponAnim(pPlayer, M134_FIRE_READY);
		set_member(this, m_Weapon_flTimeWeaponIdle, UTIL_WeaponTimeBase(this) + 1.5);
		set_member(this, m_Weapon_flNextSecondaryAttack, UTIL_WeaponTimeBase(this) + 1.5);
		set_member(this, m_Weapon_flNextPrimaryAttack, GetNextAttackDelay(this, 1.5));
		return HAM_SUPERCEDE;
	}

	SendWeaponAnim(pPlayer, M134_FIRE_LOOP);
	set_member(this, m_Weapon_flTimeWeaponIdle, UTIL_WeaponTimeBase(this) + 0.5);
	set_member(this, m_Weapon_flNextSecondaryAttack, UTIL_WeaponTimeBase(this) + 0.5);
	return HAM_IGNORED;
}

stock EV_GetGunPosition(const this, Float:vecSrc[3], const Float:origin[3])
{
	new Float:view_ofs[3];
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

SendWeaponAnim(const this, const iAnim)
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

stock bool:GetLocalWeapon(const this)
{
	new szValue[4];

	if (!get_user_info(this, "cl_lw", szValue, charsmax(szValue)))
		return false;

	if (str_to_num(szValue) <= 0)
		return false;

	return true;
}

EV_GetDefaultShellInfo(
	const this, 
	const Float:origin[3], 
	const Float:velocity[3], 
	Float:ShellVelocity[3], 
	Float:ShellOrigin[3], 
	const Float:v_forward[3], 
	const Float:v_right[3], 
	const Float:v_up[3], 
	const Float:forwardScale, 
	const Float:upScale, 
	const Float:rightScale, 
	const bool:bReverseDirection
)
{
	new Float:view_ofs[3];
	get_entvar(this, var_view_ofs, view_ofs);

	new Float:fR = random_float(50.0, 70.0);
	new Float:fU = random_float(75.0, 175.0);
	new Float:fF = random_float(25.0, 250.0);
	new Float:fDirection = rightScale > 0.0 ? -1.0 : 1.0;

	for (new i = 0; i < 3; i++)
	{
		if (bReverseDirection)
			ShellVelocity[i] = velocity[i] * 0.5 - v_right[i] * fR * fDirection + v_up[i] * fU + v_forward[i] * fF;
		else
			ShellVelocity[i] = velocity[i] * 0.5 + v_right[i] * fR * fDirection + v_up[i] * fU + v_forward[i] * fF;

		ShellOrigin[i] = velocity[i] * 0.1 + origin[i] + view_ofs[i] + upScale * v_up[i] + forwardScale * v_forward[i] + rightScale * v_right[i];
	}
}

EV_EjectBrass(const Float:origin[3], const Float:velocity[3], const Float:rotation, const model, const soundtype)
{
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_MODEL);
	write_coord_f(origin[0]);
	write_coord_f(origin[1]);
	write_coord_f(origin[2]);
	write_coord_f(velocity[0]);
	write_coord_f(velocity[1]);
	write_coord_f(velocity[2]);
	write_angle_f(rotation);
	write_short(model);
	write_byte(soundtype);
	write_byte(25);
	message_end();
}

EV_HLDM_FireBullets(
	const this, 
	const Float:v_right[3], 
	const Float:v_up[3], 
	const cShots, 
	const Float:vecSrc[3], 
	const Float:vecDirShooting[3], 
	const Float:vecSpread[3], 
	Float:flDistance, 
	const iBulletType, 
	const iPenetration
)
{
	static iPenetrationPower, Float:flPenetrationDistance;
	EV_DescribeBulletTypeParameters(iBulletType, iPenetrationPower, flPenetrationDistance);

	static Float:vecShotSrc[3];
	xs_vec_copy(vecSrc, vecShotSrc);

	static Float:x, Float:y, Float:z, Float:flCurrentDistance, Float:flFraction;
	static Float:vecDir[3], Float:vecEnd[3], Float:vecEndPos[3], Float:vecPlaneNormal[3];
	static i, cTextureType[1];
	cTextureType[0] = 0;
	static bool:bSparks, bool:isSky;
	static iShotPenetration; iShotPenetration = iPenetration;
	static tr; tr = create_tr2();

	for (new iShot = 1; iShot <= cShots; iShot++)
	{
		if (iBulletType == any:BULLET_PLAYER_BUCKSHOT)
		{
			do
			{
				x = random_float(-0.5, 0.5) + random_float(-0.5, 0.5);
				y = random_float(-0.5, 0.5) + random_float(-0.5, 0.5);
				z = x * x + y * y;
			}
			while (z > 1.0);

			for (i = 0; i < 3; i++)
			{
				vecDir[i] = vecDirShooting[i] + x * vecSpread[0] * v_right[i] + y * vecSpread[1] * v_up[i];
				vecEnd[i] = vecShotSrc[i] + flDistance * vecDir[i];
			}
		}
		else
		{
			for (i = 0; i < 3; i++)
			{
				vecDir[i] = vecDirShooting[i] + vecSpread[0] * v_right[i] + vecSpread[1] * v_up[i];
				vecEnd[i] = vecShotSrc[i] + flDistance * vecDir[i];
			}
		}

		while (iShotPenetration != 0)
		{
			engfunc(EngFunc_TraceLine, vecShotSrc, vecEnd, DONT_IGNORE_MONSTERS, this, tr);
			flFraction = get_pmtrace(tr, pmt_fraction);
			flCurrentDistance = flFraction * flDistance;

			if (flCurrentDistance == 0.0)
				break;

			cTextureType[0] = EV_HLDM_PlayTextureSound(tr, vecShotSrc, vecEnd, isSky);
			bSparks = true;

			switch (cTextureType[0])
			{
				case CHAR_TEX_METAL:
					iPenetrationPower *= 0.15;
				case CHAR_TEX_CONCRETE:
					iPenetrationPower *= 0.25;
				case CHAR_TEX_VENT, CHAR_TEX_GRATE:
					iPenetrationPower *= 0.5;
				case CHAR_TEX_TILE:
					iPenetrationPower *= 0.65;
				case CHAR_TEX_COMPUTER:
					iPenetrationPower *= 0.4;
				case CHAR_TEX_WOOD:
					bSparks = false;
			}

			get_pmtrace(tr, pmt_endpos, vecEndPos);
			get_tr2(tr, TR_vecPlaneNormal, vecPlaneNormal);

			EV_HLDM_DecalGunshot(tr, bSparks, cTextureType, isSky);

			flDistance = (flDistance - flCurrentDistance) * 0.5;

			VectorMA(vecEndPos, float(iPenetration), vecDir, vecShotSrc);
			VectorMA(vecShotSrc, flDistance, vecDir, vecEnd);

			new trOriginal = create_tr2();

			engfunc(EngFunc_TraceLine, vecShotSrc, vecSrc, DONT_IGNORE_MONSTERS, this, trOriginal);

			EV_HLDM_DecalGunshot(trOriginal, bSparks, cTextureType, isSky);

			free_tr2(trOriginal);

			if (flCurrentDistance > flPenetrationDistance)
				iShotPenetration = 0;
			else
				iShotPenetration--;
		}
	}

	free_tr2(tr);
}

EV_DescribeBulletTypeParameters(const iBulletType, &iPenetrationPower, &Float:flPenetrationDistance)
{
	switch (iBulletType)
	{
		case BULLET_PLAYER_9MM:
		{
			iPenetrationPower = 21;
			flPenetrationDistance = 800.0;
		}
		case BULLET_PLAYER_45ACP:
		{
			iPenetrationPower = 15;
			flPenetrationDistance = 500.0;
		}
		case BULLET_PLAYER_50AE:
		{
			iPenetrationPower = 30;
			flPenetrationDistance = 1000.0;
		}
		case BULLET_PLAYER_762MM:
		{
			iPenetrationPower = 39;
			flPenetrationDistance = 5000.0;
		}
		case BULLET_PLAYER_556MM:
		{
			iPenetrationPower = 35;
			flPenetrationDistance = 4000.0;
		}
		case BULLET_PLAYER_338MAG:
		{
			iPenetrationPower = 45;
			flPenetrationDistance = 8000.0;
		}
		case BULLET_PLAYER_57MM:
		{
			iPenetrationPower = 30;
			flPenetrationDistance = 2000.0;
		}
		case BULLET_PLAYER_357SIG:
		{
			iPenetrationPower = 25;
			flPenetrationDistance = 800.0;
		}
		default:
		{
			iPenetrationPower = 0;
			flPenetrationDistance = 0.0;
		}
	}
}

EV_HLDM_PlayTextureSound(const ptr, const Float:vecSrc[3], const Float:vecEnd[3], &bool:isSky)
{
	isSky = false;

	new entity = Instance(get_tr2(ptr, TR_pHit));
	new pTextureName[64], texname[64], szbuffer[64];
	new chTextureType[1]; chTextureType[0] = CHAR_TEX_CONCRETE;
	new Float:fvol, rgsz[4][64], cnt;
	new Float:fattn = ATTN_NORM;

	if (entity >= 1 && entity <= MaxClients)
	{
		chTextureType[0] = CHAR_TEX_FLESH;
	}
	else if (entity == 0)
	{
		engfunc(EngFunc_TraceTexture, entity, vecSrc, vecEnd, pTextureName, charsmax(pTextureName));

		if (pTextureName[0])
		{
			copy(texname, sizeof(texname), pTextureName);
			texname[sizeof(texname) - 1] = 0;
			copy(pTextureName, charsmax(pTextureName), texname);

			if (!strcmp(pTextureName, "sky"))
				isSky = true;
			else if (pTextureName[0] == '-' || pTextureName[0] == '+')
				pTextureName[0] += 2;
			else if (pTextureName[0] == '{' || pTextureName[0] == '!' || pTextureName[0] == '~' || pTextureName[0] == ' ')
				pTextureName[0]++;

			copy(szbuffer, sizeof(szbuffer), pTextureName);
			szbuffer[CBTEXTURENAMEMAX - 1] = 0;

			chTextureType[0] = dllfunc(DLLFunc_PM_FindTextureType, szbuffer);
		}
	}

	switch (chTextureType[0])
	{
		case CHAR_TEX_CONCRETE:
		{
			fvol = 0.9;
			copy(rgsz[0], charsmax(rgsz[]), "player/pl_step1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "player/pl_step2.wav");
			cnt = 2;
		}
		case CHAR_TEX_METAL:
		{
			fvol = 0.9;
			copy(rgsz[0], charsmax(rgsz[]), "player/pl_metal1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "player/pl_metal2.wav");
			cnt = 2;
		}
		case CHAR_TEX_DIRT:
		{
			fvol = 0.9;
			copy(rgsz[0], charsmax(rgsz[]), "player/pl_dirt1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "player/pl_dirt2.wav");
			copy(rgsz[2], charsmax(rgsz[]), "player/pl_dirt3.wav");
			cnt = 3;
		}
		case CHAR_TEX_VENT:
		{
			fvol = 0.5;
			copy(rgsz[0], charsmax(rgsz[]), "player/pl_duct1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "player/pl_duct1.wav");
			cnt = 2;
		}
		case CHAR_TEX_GRATE:
		{
			fvol = 0.9;
			copy(rgsz[0], charsmax(rgsz[]), "player/pl_grate1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "player/pl_grate4.wav");
			cnt = 2;
		}
		case CHAR_TEX_TILE:
		{
			fvol = 0.8;
			copy(rgsz[0], charsmax(rgsz[]), "player/pl_tile1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "player/pl_tile3.wav");
			copy(rgsz[2], charsmax(rgsz[]), "player/pl_tile2.wav");
			copy(rgsz[3], charsmax(rgsz[]), "player/pl_tile4.wav");
			cnt = 4;
		}
		case CHAR_TEX_SLOSH:
		{
			fvol = 0.9;
			copy(rgsz[0], charsmax(rgsz[]), "player/pl_slosh1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "player/pl_slosh3.wav");
			copy(rgsz[2], charsmax(rgsz[]), "player/pl_slosh2.wav");
			copy(rgsz[3], charsmax(rgsz[]), "player/pl_slosh4.wav");
			cnt = 4;
		}
		case CHAR_TEX_SNOW:
		{
			fvol = 0.7;
			copy(rgsz[0], charsmax(rgsz[]), "debris/pl_snow1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "debris/pl_snow2.wav");
			copy(rgsz[2], charsmax(rgsz[]), "debris/pl_snow3.wav");
			copy(rgsz[3], charsmax(rgsz[]), "debris/pl_snow4.wav");
			cnt = 4;
		}
		case CHAR_TEX_WOOD:
		{
			fvol = 0.9;
			copy(rgsz[0], charsmax(rgsz[]), "debris/wood1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "debris/wood2.wav");
			copy(rgsz[2], charsmax(rgsz[]), "debris/wood3.wav");
			cnt = 3;
		}
		case CHAR_TEX_GLASS, CHAR_TEX_COMPUTER:
		{
			fvol = 0.8;
			copy(rgsz[0], charsmax(rgsz[]), "debris/glass1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "debris/glass2.wav");
			copy(rgsz[2], charsmax(rgsz[]), "debris/glass3.wav");
			cnt = 3;
		}
		case CHAR_TEX_FLESH:
		{
			fvol = 1.0;
			copy(rgsz[0], charsmax(rgsz[]), "weapons/bullet_hit1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "weapons/bullet_hit2.wav");
			fattn = 1.0;
			cnt = 2;
		}
		default:
		{
			fvol = 0.9;
			copy(rgsz[0], charsmax(rgsz[]), "player/pl_step1.wav");
			copy(rgsz[1], charsmax(rgsz[]), "player/pl_step2.wav");
			cnt = 2;
		}
	}

	new Float:vecEndPos[3];
	get_pmtrace(ptr, pmt_endpos, vecEndPos);

	new iRand = random_num(0, cnt - 1);

	if (rgsz[iRand][0])
		rh_emit_sound2(0, 0, CHAN_STATIC, rgsz[iRand], fvol, fattn, 0, 96 + random_num(0, 0xf), 0, vecEndPos);

	return chTextureType[0];
}

EV_HLDM_DecalGunshot(const pTrace, const bool:bCreateSparks, const cTextureType[], const bool:isSky)
{
	if (isSky)
		return;

	new Float:flFraction = get_pmtrace(pTrace, pmt_fraction);

	if (flFraction == 1.0)
		return;

	new pHit = Instance(get_tr2(pTrace, TR_pHit));

	if ((pHit == 0 || pHit > MaxClients) && get_entvar(pHit, var_solid) == SOLID_BSP)
	{
		EV_HLDM_GunshotDecalTrace(pTrace, EV_HLDM_DamageDecal(pHit), cTextureType);

		new Float:vecEndPos[3];
		get_tr2(pTrace, TR_vecEndPos, vecEndPos);

		new Float:vecPlaneNormal[3];
		get_tr2(pTrace, TR_vecPlaneNormal, vecPlaneNormal);

		if (bCreateSparks)
		{
			new Float:dir[3];
			xs_vec_copy(vecPlaneNormal, dir);

			dir[0] = dir[0] * dir[0] * random_float(4.0, 12.0);
			dir[1] = dir[1] * dir[1] * random_float(4.0, 12.0);
			dir[2] = dir[2] * dir[2] * random_float(4.0, 12.0);

			MakeStreakSplash(vecEndPos, dir, 4, random_num(5, 7), floatround(dir[2]), random_num(-75, 75));
		}

		new Float:vecDest[3];
		xs_vec_add_scaled(vecEndPos, vecPlaneNormal, 2.5, vecDest);
		MakeSmokeWallPuff(vecDest, g_iSmoke_WallPuff, 3, 50, (TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOSOUND|TE_EXPLFLAG_NOPARTICLES));
	}
}

EV_HLDM_DamageDecal(const pe)
{
	new rendermode = get_entvar(pe, var_rendermode);

	if (rendermode == kRenderTransAlpha)
		return -1;

	if (rendermode != kRenderNormal)
		return engfunc(EngFunc_DecalIndex, "{bproof1");

	new idx = random_num(0, 4);

	return engfunc(EngFunc_DecalIndex, fmt("{shot%i", idx + 1));
}

EV_HLDM_GunshotDecalTrace(const pTrace, const decalId, const chTextureType[])
{
	new iRand = random_num(0, 0x7FFF);
	new Float:vecEndPos[3];
	get_tr2(pTrace, TR_vecEndPos, vecEndPos);

	if (iRand < (0x7fff / 2))
	{
		if (chTextureType[0] == CHAR_TEX_VENT || chTextureType[0] == CHAR_TEX_METAL)
		{
			switch ((iRand % 2))
			{
				case 0:
					rh_emit_sound2(0, 0, CHAN_STATIC, "weapons/ric_metal-1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecEndPos);
				case 1:
					rh_emit_sound2(0, 0, CHAN_STATIC, "weapons/ric_metal-2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecEndPos);
			}
		}
		else
		{
			switch ((iRand % 7))
			{
				case 0:
					rh_emit_sound2(0, 0, CHAN_STATIC, "weapons/ric1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecEndPos);
				case 1:
					rh_emit_sound2(0, 0, CHAN_STATIC, "weapons/ric2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecEndPos);
				case 2:
					rh_emit_sound2(0, 0, CHAN_STATIC, "weapons/ric3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecEndPos);
				case 3:
					rh_emit_sound2(0, 0, CHAN_STATIC, "weapons/ric4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecEndPos);
				case 4:
					rh_emit_sound2(0, 0, CHAN_STATIC, "weapons/ric5.wav", 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecEndPos);
				case 5:
					rh_emit_sound2(0, 0, CHAN_STATIC, "weapons/ric_conc-1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecEndPos);
				case 6:
					rh_emit_sound2(0, 0, CHAN_STATIC, "weapons/ric_conc-1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM, 0, vecEndPos);
			}
		}
	}

	new pHit = Instance(get_tr2(pTrace, TR_pHit));

	if (decalId >= 0 && (pHit == 0 || pHit > MaxClients) && (get_entvar(pHit, var_solid) == SOLID_BSP || get_entvar(pHit, var_movetype) == MOVETYPE_PUSHSTEP))
		MakeGunshotDecal(vecEndPos, decalId, pHit);
}

stock VectorMA(const Float:vecIn1[3], const Float:scale, const Float:vecIn2[3], Float:vecOut[3])
{
	vecOut[0] = vecIn1[0] + scale * vecIn2[0];
	vecOut[1] = vecIn1[1] + scale * vecIn2[1];
	vecOut[2] = vecIn1[2] + scale * vecIn2[2];
}

stock MakeBeamEntPoint(
	const this, 
	const Float:vecEndPos[3], 
	const iSpriteId, 
	const iStartingFrame, 
	const iFramerate, 
	const iLife, 
	const iLineWidth, 
	const iNoiseAmplitude, 
	const iRed, 
	const iGreen, 
	const iBlue, 
	const iBrightness, 
	const iScrollSpeed
)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMENTPOINT);
	write_short(this);
	write_coord_f(vecEndPos[0]);
	write_coord_f(vecEndPos[1]);
	write_coord_f(vecEndPos[2]);
	write_short(iSpriteId);
	write_byte(iStartingFrame);
	write_byte(iFramerate);
	write_byte(iLife);
	write_byte(iLineWidth);
	write_byte(iNoiseAmplitude);
	write_byte(iRed);
	write_byte(iGreen);
	write_byte(iBlue);
	write_byte(iBrightness);
	write_byte(iScrollSpeed);
	message_end();
}

stock MakeSmokeWallPuff(const Float:vecOrigin[3], const iSpriteId, const iScale, const iFramerate, const iFlags)
{
	message_begin_f(MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
	write_byte(TE_EXPLOSION);
	write_coord_f(vecOrigin[0]);
	write_coord_f(vecOrigin[1]);
	write_coord_f(vecOrigin[2] - 10.0);
	write_short(iSpriteId);
	write_byte(iScale);
	write_byte(iFramerate);
	write_byte(iFlags);
	message_end();
}

stock MakeStreakSplash(const Float:vecEndPos[3], const Float:rgflVector[3], const iColor, const iCount, const iBaseSpeed, const iRandomVelocity)
{
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vecEndPos, 0);
	write_byte(TE_STREAK_SPLASH);
	write_coord_f(vecEndPos[0]);
	write_coord_f(vecEndPos[1]);
	write_coord_f(vecEndPos[2]);
	write_coord_f(rgflVector[0]);
	write_coord_f(rgflVector[1]);
	write_coord_f(rgflVector[2]);
	write_byte(iColor);
	write_short(iCount);
	write_short(iBaseSpeed);
	write_short(iRandomVelocity);
	message_end();
}

stock MakeGunshotDecal(const Float:vecEndPos[3], const iDecalId, const pHit)
{
	message_begin_f(MSG_PAS, SVC_TEMPENTITY, vecEndPos, 0);
	write_byte(TE_GUNSHOTDECAL);
	write_coord_f(vecEndPos[0]);
	write_coord_f(vecEndPos[1]);
	write_coord_f(vecEndPos[2]);
	write_short(pHit);
	write_byte(iDecalId);
	message_end();
}
