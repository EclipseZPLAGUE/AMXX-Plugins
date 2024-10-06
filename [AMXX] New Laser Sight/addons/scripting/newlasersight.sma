#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <xs>
//#include <zombie_plague_special>

new g_pModelNameLaser[MAX_RESOURCE_PATH_LENGTH] = "sprites/white.spr";
new g_pModelNameDot[MAX_RESOURCE_PATH_LENGTH] = "sprites/dot.spr";

new g_iLasers_Num;
new g_hFM_PlayerPostThink_Post;

new g_pCvar_Color;
new g_pCvar_Dot;
new g_pCvar_Everyone;

new g_pBeam[MAX_PLAYERS + 1];
new g_pSpot[MAX_PLAYERS + 1];
new bool:g_bLaserSight[MAX_PLAYERS + 1];
new Float:g_flDelayTime[MAX_PLAYERS + 1];

#if defined _zombie_special_new_included
new g_iItem;
#endif

public plugin_precache()
{
	precache_model(g_pModelNameLaser);
	precache_model(g_pModelNameDot);
}

public plugin_init()
{
	register_plugin("New Laser Sight", "1.0", "Eclipse*");

	g_iLasers_Num = 0;
	g_hFM_PlayerPostThink_Post = 0;

	g_pCvar_Color = register_cvar("newlasersight_color", "#FF0000");
	g_pCvar_Dot = register_cvar("newlasersight_dot", "1");
	g_pCvar_Everyone = register_cvar("newlasersight_everyone", "1");

	RegisterHam(Ham_Spawn, "player", "Ham_Spawn_Post", 1, true);
	RegisterHam(Ham_Killed, "player", "Ham_Killed_Post", 1, true);

	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_usp", "Ham_Weapon_SecondaryAttack_Pre", 0, true);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_m4a1", "Ham_Weapon_SecondaryAttack_Pre", 0, true);

#if defined _zombie_special_new_included
	g_iItem = zp_register_extra_item("Laser Sight (Mira Laser)", 15, ZP_TEAM_HUMAN);
#else
	register_clcmd("say /lasersight", "clcmd_GiveLaserSight");
	register_clcmd("say_team /lasersight", "clcmd_GiveLaserSight");
#endif
}

public client_putinserver(this)
{
	g_pBeam[this] = 0;
	g_pSpot[this] = 0;
	g_bLaserSight[this] = false;
	g_flDelayTime[this] = 0.0;
}

public client_disconnected(this)
{
	KillBeam(this);
	g_bLaserSight[this] = false;
	g_flDelayTime[this] = 0.0;
}

#if defined _zombie_special_new_included
public zp_extra_item_selected(this, itemid)
{
	if (g_iItem != itemid)
		return PLUGIN_HANDLED;

	clcmd_GiveLaserSight(this);
	return PLUGIN_HANDLED;
}
public zp_user_infected_post(this, infector, classid)
{
	KillBeam(this);
	return PLUGIN_HANDLED;
}
public zp_user_humanized_post(this, classid, attacker);
{
	KillBeam(this);
	return PLUGIN_HANDLED;
}
#endif

public clcmd_GiveLaserSight(const this)
{
	if (!is_user_alive(this))
		return PLUGIN_HANDLED;

	new Float:flTime = get_gametime();

	if (g_flDelayTime[this] > flTime)
		return PLUGIN_HANDLED;

	if (!g_bLaserSight[this])
	{
		MakeBeam(this);
		client_print_color(this, print_team_default, "^4Mira Laser foi ativada!");
		g_bLaserSight[this] = true;
	}
	else
	{
		KillBeam(this);
		client_print_color(this, print_team_default, "^3Mira Laser foi desativada!");
		g_bLaserSight[this] = false;
	}

	g_flDelayTime[this] = flTime + 5.0;
	return PLUGIN_HANDLED;
}

MakeBeam(const this)
{
	new Float:endPosition[3], szHEX[8], vecColor[3];
	GetAimOrigin(this, endPosition);
	get_pcvar_string(g_pCvar_Color, szHEX, charsmax(szHEX));
	parseHEXColor(szHEX, vecColor);

	if (!g_pBeam[this] || is_nullent(g_pBeam[this]))
	{
		g_pBeam[this] = CreateBeam(this, 1, endPosition, g_pModelNameLaser, 0, 0, 3, 0, vecColor, 255, 0);

		if (g_pBeam[this] && !is_nullent(g_pBeam[this]))
		{
			if (!get_pcvar_num(g_pCvar_Everyone))
				set_entvar(g_pBeam[this], var_effects, get_entvar(g_pBeam[this], var_effects) | EF_OWNER_VISIBILITY);

			set_entvar(g_pBeam[this], var_classname, "laser_trail");
			g_iLasers_Num++;
		}
	}

	if (get_pcvar_num(g_pCvar_Dot) && (!g_pSpot[this] || is_nullent(g_pSpot[this])))
	{
		g_pSpot[this] = CreateSpot(this, endPosition, g_pModelNameDot, vecColor, 255, 0.1);

		if (g_pSpot[this] && !is_nullent(g_pSpot[this]))
		{
			if (!get_pcvar_num(g_pCvar_Everyone))
				set_entvar(g_pSpot[this], var_effects, get_entvar(g_pSpot[this], var_effects) | EF_OWNER_VISIBILITY);

			set_entvar(g_pSpot[this], var_classname, "laser_spot");
		}
	}

	if (g_iLasers_Num && !g_hFM_PlayerPostThink_Post)
		g_hFM_PlayerPostThink_Post = register_forward(FM_PlayerPostThink, "FM_PlayerPostThink_Post", 1);
}

public FM_PlayerPostThink_Post(const this)
{
	if (!is_user_alive(this))
		return FMRES_IGNORED;

	static pActiveItem;
	pActiveItem = get_member(this, m_pActiveItem);

	if (pActiveItem && !is_nullent(pActiveItem))
		ItemPostFrame(pActiveItem);

	return FMRES_IGNORED;
}

ItemPostFrame(const this)
{
	static pPlayer;
	pPlayer = get_member(this, m_pPlayer);

	if (!g_pBeam[pPlayer] || is_nullent(g_pBeam[pPlayer]))
		return;

	static Float:endPosition[3], bool:bVisibility;
	GetAimOrigin(pPlayer, endPosition);
	set_entvar(g_pBeam[pPlayer], var_origin, endPosition);
	RelinkBeam(g_pBeam[pPlayer]);
	bVisibility = IsWeaponCanLaser(this);

	if (bVisibility)
		set_entvar(g_pBeam[pPlayer], var_effects, get_entvar(g_pBeam[pPlayer], var_effects) & ~EF_NODRAW);
	else
		set_entvar(g_pBeam[pPlayer], var_effects, get_entvar(g_pBeam[pPlayer], var_effects) | EF_NODRAW);

	if (g_pSpot[pPlayer] && !is_nullent(g_pSpot[pPlayer]))
	{
		set_entvar(g_pSpot[pPlayer], var_origin, endPosition);
		UTIL_SetOrigin(g_pSpot[pPlayer], endPosition);

		if (bVisibility)
			set_entvar(g_pSpot[pPlayer], var_effects, get_entvar(g_pSpot[pPlayer], var_effects) & ~EF_NODRAW);
		else
			set_entvar(g_pSpot[pPlayer], var_effects, get_entvar(g_pSpot[pPlayer], var_effects) | EF_NODRAW);
	}
}

KillBeam(const this)
{
	if (g_pBeam[this] && !is_nullent(g_pBeam[this]))
	{
		rg_remove_entity(g_pBeam[this]);
		g_pBeam[this] = 0;
		g_iLasers_Num--;
	}

	if (g_pSpot[this] && !is_nullent(g_pSpot[this]))
	{
		rg_remove_entity(g_pSpot[this]);
		g_pSpot[this] = 0;
	}

	if (!g_iLasers_Num && g_hFM_PlayerPostThink_Post)
	{
		unregister_forward(FM_PlayerPostThink, g_hFM_PlayerPostThink_Post, 1);
		g_hFM_PlayerPostThink_Post = 0;
	}
}

public Ham_Spawn_Post(const this)
{
	if (!is_user_alive(this) || !g_bLaserSight[this])
		return HAM_IGNORED;

	MakeBeam(this);
	return HAM_IGNORED;
}

public Ham_Killed_Post(const this, const pevAttacker, const shouldGib)
{
	if (is_user_alive(this))
		return HAM_IGNORED;

	KillBeam(this);
	return HAM_IGNORED;
}

public Ham_Weapon_SecondaryAttack_Pre(const this)
{
	if (get_entvar(this, var_impulse))
		return HAM_IGNORED;

	new pPlayer = get_member(this, m_pPlayer);

	switch (any:rg_get_iteminfo(this, ItemInfo_iId))
	{
		case WEAPON_USP:
			set_member(pPlayer, m_flNextAttack, 3.13);
		case WEAPON_M4A1:
			set_member(pPlayer, m_flNextAttack, 2.0);
	}

	return HAM_IGNORED;
}

stock bool:IsWeaponCanLaser(const this)
{
	switch (rg_get_iteminfo(this, ItemInfo_iId))
	{
		case WEAPON_NONE, WEAPON_GLOCK, WEAPON_HEGRENADE, WEAPON_C4, WEAPON_SMOKEGRENADE, WEAPON_FLASHBANG, WEAPON_KNIFE:
			return false;
	}

	if (get_entvar(this, var_impulse) || get_member(get_member(this, m_pPlayer), m_flNextAttack) > 0.0)
		return false;

	return true;
}

stock GetAimOrigin(const this, Float:endPosition[3])
{
	new Float:v_angle[3], Float:vecSrc[3], Float:v_forward[3], Float:vecEnd[3];
	get_entvar(this, var_v_angle, v_angle);
	engfunc(EngFunc_MakeVectors, v_angle);
	GetGunPosition(this, vecSrc);
	global_get(glb_v_forward, v_forward);
	xs_vec_add_scaled(vecSrc, v_forward, 8192.0, vecEnd);
	engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, this, 0);
	get_tr2(0, TR_vecEndPos, endPosition);
}

stock GetGunPosition(const this, Float:vecSrc[3])
{
	new Float:origin[3], Float:view_ofs[3];
	get_entvar(this, var_origin, origin);
	get_entvar(this, var_view_ofs, view_ofs);
	xs_vec_add(origin, view_ofs, vecSrc);
}

// CreateBeamEntPoint
stock CreateBeam(
	const this, 
	const attachment, 
	const Float:endPosition[3], 
	const spriteName[], 
	const frame, 
	const framerate, 
	const width, 
	const amplitude, 
	const rgb[3], 
	const brightness, 
	const speed
)
{
	static maxEntities;

	if (!maxEntities)
		maxEntities = global_get(glb_maxEntities);

	if (maxEntities - engfunc(EngFunc_NumberOfEntities) <= 100)
		return 0;

	new pEntity = rg_create_entity("beam");

	if (!pEntity || is_nullent(pEntity))
		return 0;

	new Float:vecColor[3];
	vecColor[0] = float(rgb[0]);
	vecColor[1] = float(rgb[1]);
	vecColor[2] = float(rgb[2]);
	set_entvar(pEntity, var_flags, get_entvar(pEntity, var_flags) | FL_CUSTOMENTITY);
	set_entvar(pEntity, var_rendercolor, vecColor);
	set_entvar(pEntity, var_renderamt, float(brightness));
	set_entvar(pEntity, var_body, amplitude);
	set_entvar(pEntity, var_frame, float(frame));
	set_entvar(pEntity, var_animtime, float(speed));
	set_entvar(pEntity, var_scale, float(width));
	set_entvar(pEntity, var_framerate, float(framerate));
	engfunc(EngFunc_SetModel, pEntity, spriteName);
	set_entvar(pEntity, var_rendermode, 0);
	set_entvar(pEntity, var_sequence, 0);
	set_entvar(pEntity, var_skin, 0);
	set_entvar(pEntity, var_rendermode, (get_entvar(pEntity, var_rendermode) & 0xF0) | (1 & 0x0F));
	set_entvar(pEntity, var_origin, endPosition);
	set_entvar(pEntity, var_skin, (this & 0x0FFF) | ((get_entvar(pEntity, var_skin) & 0xF000) << 12));
	set_entvar(pEntity, var_aiment, this);
	set_entvar(pEntity, var_sequence, (get_entvar(pEntity, var_sequence) & 0x0FFF) | ((0 & 0xF) << 12));
	set_entvar(pEntity, var_skin, (get_entvar(pEntity, var_skin) & 0x0FFF) | ((attachment & 0xF) << 12));
	set_entvar(pEntity, var_owner, this);
	RelinkBeam(pEntity);
	return pEntity;
}

// RelinkBeamEntPoint
stock RelinkBeam(const this)
{
	new endEnt = (get_entvar(this, var_skin) & 0xFFF);

	if (!endEnt || is_nullent(endEnt))
		return;

	new Float:startPos[3], Float:endPos[3], Float:mins[3], Float:maxs[3], index;
	get_entvar(this, var_origin, startPos);
	get_entvar(endEnt, var_origin, endPos);

	for (index = 0; index < 3; index++)
	{
		mins[index] = floatmin(startPos[index], endPos[index]);
		maxs[index] = floatmax(startPos[index], endPos[index]);
		mins[index] = mins[index] - startPos[index];
		maxs[index] = maxs[index] - startPos[index];
	}

	set_entvar(this, var_mins, mins);
	set_entvar(this, var_maxs, maxs);
	engfunc(EngFunc_SetSize, this, mins, maxs);
	engfunc(EngFunc_SetOrigin, this, startPos);
}

stock CreateSpot(const this, const Float:endPosition[3], const spriteName[], const rgb[3], const brightness, const Float:size)
{
	static maxEntities;

	if (!maxEntities)
		maxEntities = global_get(glb_maxEntities);

	if (maxEntities - engfunc(EngFunc_NumberOfEntities) <= 100)
		return 0;

	new pEntity = rg_create_entity("cycler_sprite");

	if (!pEntity || is_nullent(pEntity))
		return 0;

	new Float:vecColor[3];
	vecColor[0] = float(rgb[0]);
	vecColor[1] = float(rgb[1]);
	vecColor[2] = float(rgb[2]);
	set_entvar(pEntity, var_movetype, MOVETYPE_NONE);
	set_entvar(pEntity, var_solid, SOLID_NOT);
	engfunc(EngFunc_SetModel, pEntity, spriteName);
	set_entvar(pEntity, var_rendermode, kRenderGlow);
	set_entvar(pEntity, var_rendercolor, vecColor);
	set_entvar(pEntity, var_renderfx, kRenderFxNoDissipation);
	set_entvar(pEntity, var_renderamt, float(brightness));
	engfunc(EngFunc_SetSize, pEntity, NULL_VECTOR, NULL_VECTOR);
	engfunc(EngFunc_SetOrigin, pEntity, endPosition);
	set_entvar(pEntity, var_scale, size);
	set_entvar(pEntity, var_owner, this);
	return pEntity;
}

stock UTIL_SetOrigin(const this, const Float:origin[3])
{
	new Float:mins[3], Float:maxs[3];
	get_entvar(this, var_mins, mins);
	get_entvar(this, var_maxs, maxs);
	engfunc(EngFunc_SetSize, this, mins, maxs);
	engfunc(EngFunc_SetOrigin, this, origin);
}

stock parseHEXColor(const code[], rgb[3])
{
	if (code[0] != '#' || strlen(code) != 7)
		return;

	rgb[0] = parse16bit(code[1], code[2]);
	rgb[1] = parse16bit(code[3], code[4]);
	rgb[2] = parse16bit(code[5], code[6]);
}

stock parse16bit(const c1, const c2)
{
	return (parseHEX(c1) * 16 + parseHEX(c2));
}

stock parseHEX(const c)
{
	switch (c)
	{
		case '0'..'9':
			return (c - '0');
		case 'a'..'f':
			return (10 + c - 'a');
		case 'A'..'F':
			return (10 + c - 'A');
	}

	return 0;
}
