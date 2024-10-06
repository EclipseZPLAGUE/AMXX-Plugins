/***
*
*	Copyright (c) 1996-2001, Valve LLC. All rights reserved.
*	
*	This product contains software technology licensed from Id 
*	Software, Inc. ("Id Technology").  Id Technology (c) 1996 Id Software, Inc. 
*	All Rights Reserved.
*
*   Use, distribution, and modification of this source code and/or resulting
*   object code is restricted to non-commercial enhancements to products from
*   Valve LLC.  All other use, distribution, or modification is prohibited
*   without written permission from Valve LLC.
*
****/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi_beams>

#define IsValid(%0) (%0 > 0 && %0 <= MaxClients)

#define var_rgAmmo var_iuser1
#define var_pRealOwner var_iuser2
#define var_pBeam var_iuser3
#define var_pItem var_iuser4
#define var_flPowerUp var_fuser1
#define var_posOwner var_vuser3
#define var_angleOwner var_vuser4

#define C4_NAME "weapon_c4"
#define C4_AMMO_INDEX 14

#define TRIPMINE_NAME "weapon_tripmine"
#define TRIPMINE_MAX_CARRY 5
#define TRIPMINE_KEY 1181

#define MONSTER_NAME "monster_tripmine"
#define TASK_DEPLOY 1182
#define TASK_OBSERVER 1183

enum any:tripmine_e {
	TRIPMINE_IDLE1 = 0,
	TRIPMINE_IDLE2,
	TRIPMINE_ARM1,
	TRIPMINE_ARM2,
	TRIPMINE_FIDGET,
	TRIPMINE_HOLSTER,
	TRIPMINE_DRAW,
	TRIPMINE_WORLD,
	TRIPMINE_GROUND,
};

new const g_szWeaponModel[] = "models/p_tripmine.mdl";
new const g_szViewModel[] = "models/v_tripmine.mdl";
new const g_szWeaponBoxModel[] = "models/w_tripmine.mdl";
new const g_szLaserSprite[] = "sprites/laserbeam.spr";
new const g_szActivateSound[] = "weapons/mine_activate.wav";
new const g_szChargeSound[] = "weapons/mine_charge.wav";
new const g_szDeploySound[] = "weapons/mine_deploy.wav";

new g_iFireballSprite, g_iWExplosionSprite, g_iSmokeSprite, g_iBubblesSprite;
new g_iszWeaponModel, g_iszViewModel;
new g_iMsgId_WeaponList;
new g_pCvar_Ammo, g_pCvar_Health, g_pCvar_Dmg, Float:g_pCvar_DmgRadius, g_pCvar_LaserDmg, Float:g_pCvar_LaserDmgTime, g_pCvar_ProgressBar, g_pCvar_Preview, g_pCvar_FriendlyFire;
new g_iViewModelBody[MAX_PLAYERS + 1], g_pentPreview[MAX_PLAYERS + 1];
new Float:g_flDmgTime[2265];

public plugin_precache() {
	register_plugin("[ReAPI] Laser Tripmine", "1.6", "Eclipse*");

	engfunc(EngFunc_PrecacheModel, g_szWeaponModel);
	engfunc(EngFunc_PrecacheModel, g_szViewModel);
	engfunc(EngFunc_PrecacheModel, g_szWeaponBoxModel);
	engfunc(EngFunc_PrecacheModel, g_szLaserSprite);
	engfunc(EngFunc_PrecacheSound, g_szActivateSound);
	engfunc(EngFunc_PrecacheSound, g_szChargeSound);
	engfunc(EngFunc_PrecacheSound, g_szDeploySound);

	engfunc(EngFunc_PrecacheGeneric, "sprites/320hud1_3.spr");
	engfunc(EngFunc_PrecacheGeneric, "sprites/320hud2_3.spr");
	engfunc(EngFunc_PrecacheGeneric, "sprites/640hud3_3.spr");
	engfunc(EngFunc_PrecacheGeneric, "sprites/640hud6_3.spr");
	engfunc(EngFunc_PrecacheGeneric, "sprites/640hud7_3.spr");
	engfunc(EngFunc_PrecacheGeneric, "sprites/weapon_tripmine.txt");

	engfunc(EngFunc_PrecacheSound, "debris/bustglass1.wav");
	engfunc(EngFunc_PrecacheSound, "debris/bustglass2.wav");
	engfunc(EngFunc_PrecacheSound, "debris/bustglass3.wav");

	g_iFireballSprite = engfunc(EngFunc_PrecacheModel, "sprites/zerogxplode.spr");
	g_iWExplosionSprite = engfunc(EngFunc_PrecacheModel, "sprites/WXplo1.spr");
	g_iSmokeSprite = engfunc(EngFunc_PrecacheModel, "sprites/steam1.spr");
	g_iBubblesSprite = engfunc(EngFunc_PrecacheModel, "sprites/bubble.spr");

	register_clcmd(TRIPMINE_NAME, "@CTripmine__SelectItem");

	g_iszWeaponModel = engfunc(EngFunc_AllocString, g_szWeaponModel);
	g_iszViewModel = engfunc(EngFunc_AllocString, g_szViewModel);
}

@CTripmine__SelectItem(const pPlayer) {
	if (!is_user_alive(pPlayer))
		return PLUGIN_HANDLED;

	static pItem; pItem = get_member(pPlayer, m_rgpPlayerItems, C4_SLOT);

	if (is_nullent(pItem) || get_member(pItem, m_iId) != WEAPON_C4 || get_entvar(pItem, var_impulse) != TRIPMINE_KEY)
		return PLUGIN_HANDLED;

	if (get_member(pPlayer, m_pActiveItem) == pItem)
		return PLUGIN_HANDLED;

	rg_switch_weapon(pPlayer, pItem);
	return PLUGIN_HANDLED;
}

public plugin_init() {
	g_iMsgId_WeaponList = get_user_msgid("WeaponList");

	RegisterHookChain(RG_CWeaponBox_SetModel, "@CWeaponBox__SetModel", 0);
	RegisterHookChain(RG_CBasePlayer_Killed, "@CBasePlayer__Killed", 1);

	register_forward(FM_UpdateClientData, "@CBasePlayer__UpdateClientData", 1);

	RegisterHam(Ham_Item_PreFrame, "player", "@CBasePlayer__MaxSpeed", 1, true);
	RegisterHam(Ham_Spawn, C4_NAME, "@CTripmine__Spawn", 1, true);
	RegisterHam(Ham_Touch, "weaponbox", "@CTripmine__Touch", 0, true);
	RegisterHam(Ham_CS_Weapon_SendWeaponAnim, C4_NAME, "@CTripmine__SendWeaponAnim", 1, true);
	RegisterHam(Ham_Item_AddToPlayer, C4_NAME, "@CTripmine__AddToPlayer", 1, true);
	RegisterHam(Ham_Item_Deploy, C4_NAME, "@CTripmine__Deploy", 1, true);
	RegisterHam(Ham_Item_Holster, C4_NAME, "@CTripmine__Holster", 1, true);
	RegisterHam(Ham_Weapon_PrimaryAttack, C4_NAME, "@CTripmine__PrimaryAttack", 0, true);
	RegisterHam(Ham_Weapon_WeaponIdle, C4_NAME, "@CTripmine__WeaponIdle", 0, true);
	RegisterHam(Ham_TakeDamage, "func_breakable", "@CTripmineGrenade__TakeDamage", 0, true);

	bind_pcvar_num(create_cvar("tripmine_ammo", "3", FCVAR_PROTECTED, "", true, 1.0), g_pCvar_Ammo);
	bind_pcvar_num(create_cvar("tripmine_health", "100", FCVAR_PROTECTED, "", true, 1.0), g_pCvar_Health);
	bind_pcvar_num(create_cvar("tripmine_dmg", "150"), g_pCvar_Dmg);
	bind_pcvar_float(create_cvar("tripmine_dmg_radius", "250.0"), g_pCvar_DmgRadius);
	bind_pcvar_num(create_cvar("tripmine_laser_dmg", "0"), g_pCvar_LaserDmg);
	bind_pcvar_float(create_cvar("tripmine_laser_dmg_time", "0.2"), g_pCvar_LaserDmgTime);
	bind_pcvar_num(create_cvar("tripmine_progressbar", "1"), g_pCvar_ProgressBar);
	bind_pcvar_num(create_cvar("tripmine_preview", "1"), g_pCvar_Preview);
	bind_pcvar_num(get_cvar_pointer("mp_friendlyfire"), g_pCvar_FriendlyFire);

	register_clcmd("tripmine", "@CTripmine__Give");
	register_clcmd("drop", "CTripmine__Drop");
}

public client_putinserver(pPlayer) {
	g_pentPreview[pPlayer] = 0;
	g_iViewModelBody[pPlayer] = 0;
}

public client_disconnected(pPlayer) {
	if (g_pCvar_Preview && g_pentPreview[pPlayer] && !is_nullent(g_pentPreview[pPlayer])) {
		rg_remove_entity(g_pentPreview[pPlayer]);
		g_pentPreview[pPlayer] = 0;
	}

	g_iViewModelBody[pPlayer] = 0;
}

@CWeaponBox__SetModel(const pWeaponBox, const szModelName[]) {
	if (is_nullent(pWeaponBox))
		return HC_CONTINUE;

	static pItem; pItem = GetWeaponBoxItem(pWeaponBox);

	if (!is_nullent(pItem) && get_member(pItem, m_iId) == WEAPON_C4 && get_entvar(pItem, var_impulse) == TRIPMINE_KEY)
	{
		static pPlayer; pPlayer = get_entvar(pWeaponBox, var_owner);

		if (g_pCvar_Preview && g_pentPreview[pPlayer] && !is_nullent(g_pentPreview[pPlayer])) {
			rg_remove_entity(g_pentPreview[pPlayer]);
			g_pentPreview[pPlayer] = 0;
		}

		SetHookChainArg(2, ATYPE_STRING, g_szWeaponBoxModel);
	}

	return HC_CONTINUE;
}

@CBasePlayer__Killed(const pVictim, const pAttacker, const shouldGib) {
	if (is_nullent(pVictim) || is_nullent(pAttacker))
		return HC_CONTINUE;

	new pItem = get_member(pVictim, m_rgpPlayerItems, C4_SLOT);

	if (!pItem || is_nullent(pItem) || get_member(pItem, m_iId) != WEAPON_C4 || get_entvar(pItem, var_impulse) != TRIPMINE_KEY)
		return HC_CONTINUE;

	PackPlayerItem(pVictim, pItem, true);
	return HC_CONTINUE;
}

PackPlayerItem(const pPlayer, const pItem, const bool:packAmmo) {
	if (!pItem)
		return 0;

	static const szGetCSModelName[][] = {
		"", "models/w_p228.mdl", "", "models/w_scout.mdl", "models/w_hegrenade.mdl", "models/w_xm1014.mdl", 
		"models/w_c4.mdl", "models/w_mac10.mdl", "models/w_aug.mdl", "models/w_smokegrenade.mdl", "models/w_elite.mdl", 
		"models/w_fiveseven.mdl", "models/w_ump45.mdl", "models/w_sg550.mdl", "models/w_galil.mdl", "models/w_famas.mdl", 
		"models/w_usp.mdl", "models/w_glock18.mdl", "models/w_awp.mdl", "models/w_mp5.mdl", "models/w_m249.mdl", 
		"models/w_m3.mdl", "models/w_m4a1.mdl", "models/w_tmp.mdl", "models/w_g3sg1.mdl", "models/w_flashbang.mdl", 
		"models/w_deagle.mdl", "models/w_sg552.mdl", "models/w_ak47.mdl", "models/w_knife.mdl", "models/w_p90.mdl"
	};

	new iId = get_member(pItem, m_iId);

	if (szGetCSModelName[iId][0]) {
		new Float:vecOrigin[3], Float:vecAngles[3], Float:vecVelocity[3];
		get_entvar(pPlayer, var_origin, vecOrigin);
		get_entvar(pPlayer, var_angles, vecAngles);
		get_entvar(pPlayer, var_velocity, vecVelocity);
		xs_vec_mul_scalar(vecVelocity, 0.75, vecVelocity);
		return rg_create_weaponbox(
			pItem, 
			pPlayer, 
			szGetCSModelName[iId], 
			vecOrigin, 
			vecAngles, 
			vecVelocity, 
			300.0, 
			packAmmo
		);
	}

	return 0;
}

@CBasePlayer__UpdateClientData(const pPlayer, const iSendWeapons, const hCD) {
	if (is_nullent(pPlayer) || !is_user_connected(pPlayer))
		return FMRES_IGNORED;

	static pTarget; pTarget = (get_entvar(pPlayer, var_iuser1) > OBS_NONE) ? get_entvar(pPlayer, var_iuser2) : pPlayer;

	if (is_nullent(pTarget) || !is_user_connected(pTarget))
		return FMRES_IGNORED;

	static pItem, pOwner; pItem = get_member(pTarget, m_pActiveItem);

	if (!IsTripmine(pItem, pOwner))
		return FMRES_IGNORED;

	if (get_entvar(pPlayer, var_iuser1) > OBS_NONE) {
		static iObserverMode[MAX_PLAYERS + 1], pObserverTarget[MAX_PLAYERS + 1];

		if (iObserverMode[pPlayer] != get_entvar(pPlayer, var_iuser1)) {
			iObserverMode[pPlayer] = get_entvar(pPlayer, var_iuser1);
			pObserverTarget[pPlayer] = 0;
		}

		if (get_entvar(pPlayer, var_iuser1) == OBS_IN_EYE && pObserverTarget[pPlayer] != pTarget) {
			pObserverTarget[pPlayer] = pTarget;

			remove_task(pPlayer + TASK_OBSERVER);
			new aData[1]; aData[0] = g_iViewModelBody[pTarget];
			set_task(0.1, "CTripmine__Observer", pPlayer + TASK_OBSERVER, aData, 1);
		}
	}

	static Float:flGameTime; flGameTime = get_gametime();

	if (GetLocalWeapon(pTarget)) {
		static Float:flLastEventCheck; flLastEventCheck = get_member(pItem, m_flLastEventCheck);

		if (!flLastEventCheck) {
			set_cd(hCD, CD_flNextAttack, flGameTime + 0.001);
			set_cd(hCD, CD_WeaponAnim, TRIPMINE_IDLE1);
			return FMRES_HANDLED;
		}

		if (flLastEventCheck <= flGameTime) {
			SendWeaponAnim(pTarget, TRIPMINE_DRAW, g_iViewModelBody[pTarget]);
			set_member(pItem, m_flLastEventCheck, 0.0);
		}
	}
	else {
		set_cd(hCD, CD_flNextAttack, flGameTime + 0.001);
		return FMRES_HANDLED;
	}

	return FMRES_IGNORED;
}

public CTripmine__Observer(const aData[], const iTaskId) {
	new pPlayer = iTaskId - TASK_OBSERVER;

	if (!is_user_connected(pPlayer) || is_nullent(pPlayer))
		return;

	SendWeaponAnim(pPlayer, TRIPMINE_IDLE1, aData[0]);
}

@CBasePlayer__MaxSpeed(const pPlayer) {
	static pItem, pOwner; pItem = get_member(pPlayer, m_pActiveItem);

	if (!IsTripmine(pItem, pOwner) || pPlayer != pOwner)
		return;

	if (get_member(pItem, m_C4_bStartedArming))
		set_entvar(pPlayer, var_maxspeed, 1.0);
	else
		set_entvar(pPlayer, var_maxspeed, 250.0);
}

@CTripmine__SendWeaponAnim(const pItem, const iAnim, const iSkipLocal) {
	static pPlayer;

	if (!IsTripmine(pItem, pPlayer))
		return;

	SendWeaponAnim(pPlayer, iAnim, g_iViewModelBody[pPlayer]);
}

@CTripmine__Spawn(const pItem) {
	if (is_nullent(pItem))
		return;

	if (get_member(pItem, m_iId) != WEAPON_C4 || get_entvar(pItem, var_impulse) != TRIPMINE_KEY)
		return;

	rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, TRIPMINE_MAX_CARRY);
	set_member(pItem, m_Weapon_iDefaultAmmo, 1);
}

@CTripmine__Touch(const pWeaponBox, const pPlayer) {
	if (!(get_entvar(pWeaponBox, var_flags) & FL_ONGROUND) || !IsValid(pPlayer) || !IsAlive(pPlayer))
		return HAM_IGNORED;

	if (get_member(pPlayer, m_bIsVIP) || get_member(pPlayer, m_bShieldDrawn))
		return HAM_IGNORED;

	const boxAmmoSlot = 1;
	new givenItem = 0;
	static pItem, playerGrenades, iAmmo, rgiszAmmo[16];
	pItem = get_member(pWeaponBox, m_WeaponBox_rgpPlayerItems, C4_SLOT);

	if (!pItem || is_nullent(pItem))
		return HAM_IGNORED;

	if (get_member(pItem, m_iId) != WEAPON_C4 || get_entvar(pItem, var_impulse) != TRIPMINE_KEY)
		return HAM_IGNORED;

	if (pItem && ExecuteHamB(Ham_CS_Item_IsWeapon, pItem))
	{
		playerGrenades = get_member(pPlayer, m_rgAmmo, get_member(pItem, m_Weapon_iPrimaryAmmoType));

		if (playerGrenades < rg_get_iteminfo(pItem, ItemInfo_iMaxAmmo1))
		{
			iAmmo = get_member(pWeaponBox, m_WeaponBox_rgAmmo, boxAmmoSlot);

			if (iAmmo > 1 && playerGrenades > 0)
			{
				get_member(pWeaponBox, m_WeaponBox_rgiszAmmo, rgiszAmmo, charsmax(rgiszAmmo), boxAmmoSlot);

				if (rgiszAmmo[0] && ExecuteHamB(Ham_GiveAmmo, pPlayer, 1, rgiszAmmo, rg_get_iteminfo(pItem, ItemInfo_iMaxAmmo1)) != -1)
				{
					set_member(pWeaponBox, m_WeaponBox_rgAmmo, --iAmmo, boxAmmoSlot);
					emit_sound(pPlayer, CHAN_ITEM, "items/9mmclip1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
				}
			}
			else
			{
				if (ExecuteHamB(Ham_AddPlayerItem, pPlayer, pItem))
				{
					ExecuteHamB(Ham_Item_AttachToPlayer, pItem, pPlayer);
					givenItem = pItem;
				}

				// unlink this weapon from the box
				set_member(pWeaponBox, m_WeaponBox_rgpPlayerItems, pItem, C4_SLOT);
			}
		}
	}

	// dole out ammo
	//for (new n = 0; n < 32; n++)
	//{
	get_member(pWeaponBox, m_WeaponBox_rgiszAmmo, rgiszAmmo, charsmax(rgiszAmmo), boxAmmoSlot);
	iAmmo = get_member(pWeaponBox, m_WeaponBox_rgAmmo, boxAmmoSlot);

	if (rgiszAmmo[0])
	{
		// there's some ammo of this type.
		ExecuteHamB(Ham_GiveAmmo, pPlayer, iAmmo, rgiszAmmo, iAmmo);

		// now empty the ammo from the weaponbox since we just gave it to the player
		set_member(pWeaponBox, m_WeaponBox_rgiszAmmo, NULL_STRING, boxAmmoSlot);
		set_member(pWeaponBox, m_WeaponBox_rgAmmo, 0, boxAmmoSlot);
	}
	//}

	if (givenItem)
	{
		emit_sound(pPlayer, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

		// BUGBUG: weaponbox links gun to player, then ammo is given
		// so FShouldSwitchWeapon's CanHolster (which checks ammo) check inside AddPlayerItem
		// return FALSE, causing an unarmed player to not deploy any weaponbox grenade
		if (get_member(pPlayer, m_pActiveItem) != givenItem && FShouldSwitchWeapon(pPlayer, givenItem))
		{
			// This re-check is done after ammo is given 
			// so it ensures player properly deploys grenade from floor
			rg_switch_weapon(pPlayer, givenItem);
		}
	}

	SetTouch(pWeaponBox, "");
	rg_remove_entity(pWeaponBox);
	return HAM_SUPERCEDE;
}

@CTripmine__AddToPlayer(const pItem, const pPlayer) {
	if (get_member(pItem, m_iId) != WEAPON_C4)
		return HAM_IGNORED;

	if (get_entvar(pItem, var_impulse) == TRIPMINE_KEY)
		SendWeaponList(pPlayer, TRIPMINE_NAME, rg_get_weapon_info(WEAPON_C4, WI_AMMO_TYPE), TRIPMINE_MAX_CARRY, -1, -1, 4, 3, WEAPON_C4, (ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE));
	else
		SendWeaponList(pPlayer, C4_NAME, rg_get_weapon_info(WEAPON_C4, WI_AMMO_TYPE), 1, -1, -1, 4, 3, WEAPON_C4, (ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE));

	return HAM_IGNORED;
}

@CTripmine__Deploy(const pItem) {
	static pPlayer;

	if (!IsTripmine(pItem, pPlayer))
		return HAM_IGNORED;

	set_pev(pPlayer, pev_weaponmodel2, "");
	set_pev(pPlayer, pev_viewmodel2, "");

	if (GetLocalWeapon(pPlayer)) {
		remove_task(pPlayer + TASK_DEPLOY);
		static aData[1]; aData[0] = pItem;
		set_task(0.1, "CTripmine__NewDeploy", pPlayer + TASK_DEPLOY, aData, 1);
	}
	else
		@CTripmine__DefaultDeploy(pItem, pPlayer);

	set_member(pPlayer, m_szAnimExtention, "c4");
	return HAM_IGNORED;
}

@CTripmine__Holster(const pItem) {
	static pPlayer;

	if (!IsTripmine(pItem, pPlayer))
		return HAM_IGNORED;

	if (get_member(pPlayer, m_rgAmmo, get_member(pItem, m_Weapon_iPrimaryAmmoType))) {
		if (g_pCvar_Preview && g_pentPreview[pPlayer] && !is_nullent(g_pentPreview[pPlayer]))
			set_entvar(g_pentPreview[pPlayer], var_effects, get_entvar(g_pentPreview[pPlayer], var_effects) | EF_NODRAW);
	}

	return HAM_IGNORED;
}

@CTripmine__DefaultDeploy(const pItem, const pPlayer) {
	static pOwner;

	if (!IsTripmine(pItem, pOwner) || pPlayer != pOwner)
		return;

	set_pev(pPlayer, pev_weaponmodel, g_iszWeaponModel);
	set_pev(pPlayer, pev_viewmodel, g_iszViewModel);
	SendWeaponAnim(pPlayer, TRIPMINE_DRAW, g_iViewModelBody[pPlayer]);
}

public CTripmine__NewDeploy(const aData[], const iTaskId) {
	new pPlayer = iTaskId - TASK_DEPLOY, pItem = aData[0], pOwner;

	if (!is_user_connected(pPlayer) || !IsTripmine(pItem, pOwner) || pPlayer != pOwner)
		return;

	set_pev(pPlayer, pev_weaponmodel, g_iszWeaponModel);
	set_pev(pPlayer, pev_viewmodel, g_iszViewModel);
	set_member(pItem, m_flLastEventCheck, get_gametime() + 0.001);
	SendWeaponAnim(pPlayer, TRIPMINE_IDLE1, g_iViewModelBody[pPlayer]);
}

@CTripmine__PrimaryAttack(const pItem) {
	static pPlayer;

	if (!IsTripmine(pItem, pPlayer))
		return HAM_IGNORED;

	static iAmmoType; iAmmoType = get_member(pItem, m_Weapon_iPrimaryAmmoType);
	static iAmmo; iAmmo = get_member(pPlayer, m_rgAmmo, iAmmoType);

	if (get_member(pItem, m_Weapon_flNextPrimaryAttack) > 0.0 || iAmmo <= 0 
	|| g_pCvar_Preview && (!g_pentPreview[pPlayer] || is_nullent(g_pentPreview[pPlayer]) || get_entvar(g_pentPreview[pPlayer], var_effects) & EF_NODRAW))
		return HAM_SUPERCEDE;

	static bool:bOnGround; bOnGround = (get_entvar(pPlayer, var_flags) & FL_ONGROUND) ? true : false;

	if (!bOnGround) {
		static pTr; pTr = create_tr2();
		static Float:vecOrigin[3]; get_entvar(pPlayer, var_origin, vecOrigin);
		static Float:vecStart[3]; vecStart[2] = -8192.0;
		static Float:vecEnd[3]; xs_vec_add(vecOrigin, vecStart, vecEnd);
		engfunc(EngFunc_TraceLine, vecOrigin, vecEnd, IGNORE_MONSTERS, pPlayer, pTr);
		static Float:flFraction; get_tr2(pTr, TR_flFraction, flFraction);
		free_tr2(pTr);
		static Float:vecVelocity[3]; get_entvar(pPlayer, var_velocity, vecVelocity);
		bOnGround = (flFraction != 1.0 && vecVelocity[2] == 0.0) ? true : false;
	}

	static bool:bCanPlace, Float:vecNewOrigin[3], Float:vecNewAngles[3];
	bCanPlace = CanPlace(pPlayer, vecNewOrigin, vecNewAngles);
	static bool:bPlaceMine; bPlaceMine = (bOnGround) ? true : false;

	if (g_pCvar_ProgressBar) {
		if (!get_member(pItem, m_C4_bStartedArming)) {
			if (!bCanPlace) {
				client_print(pPlayer, print_center, "Tripmine must be planted at a wall!");
				set_member(pItem, m_Weapon_flNextPrimaryAttack, 1.0);
				return HAM_SUPERCEDE;
			}

			if (!bOnGround) {
				engclient_print(pPlayer, engprint_center, "You must be standing on^nthe ground to plant the Tripmine!");
				set_member(pItem, m_Weapon_flNextPrimaryAttack, 1.0);
				return HAM_SUPERCEDE;
			}

			SendWeaponAnim(pPlayer, TRIPMINE_ARM1, g_iViewModelBody[pPlayer]);
			SetAnimation(pPlayer, PLAYER_ATTACK1);
			SetProgressBarTime(pPlayer, 1);
			set_member(pItem, m_C4_bStartedArming, true);
			ExecuteHamB(Ham_Item_PreFrame, pPlayer);
			set_member(pItem, m_Weapon_flNextPrimaryAttack, 1.02);
			set_member(pItem, m_Weapon_flTimeWeaponIdle, 1.02);
			return HAM_SUPERCEDE;
		}

		if (bPlaceMine) {
			set_member(pItem, m_C4_bStartedArming, false);
			SendWeaponAnim(pPlayer, TRIPMINE_ARM2, g_iViewModelBody[pPlayer]);
			SetAnimation(pPlayer, PLAYER_HOLDBOMB);
			ExecuteHamB(Ham_Item_PreFrame, pPlayer);
			set_member(pPlayer, m_rgAmmo,  --iAmmo, iAmmoType);
			@CTripmineGrenade__Setting(pItem);

			if (iAmmo <= 0) {
				ExecuteHamB(Ham_Weapon_RetireWeapon, pItem);
				return HAM_SUPERCEDE;
			}

			set_member(pItem, m_Weapon_flNextPrimaryAttack, 0.5);
			set_member(pItem, m_Weapon_flTimeWeaponIdle, 0.5);
		}
		else {
			if (bCanPlace)
				engclient_print(pPlayer, engprint_center, "You must be standing on^nthe ground to plant the Tripmine!");
			else
				engclient_print(pPlayer, engprint_center, "Arming Sequence Canceled.^nTripmine can only be placed at a Wall.");

			SetAnimation(pPlayer, PLAYER_HOLDBOMB);
			SetProgressBarTime(pPlayer, 0);
			set_member(pItem, m_C4_bStartedArming, false);
			ExecuteHamB(Ham_Item_PreFrame, pPlayer);
		}
	}
	else {
		if (!bCanPlace) {
			client_print(pPlayer, print_center, "Tripmine must be planted at a wall!");
			set_member(pItem, m_Weapon_flNextPrimaryAttack, 1.0);
			return HAM_SUPERCEDE;
		}

		if (!bOnGround) {
			engclient_print(pPlayer, engprint_center, "You must be standing on^nthe ground to plant the Tripmine!");
			set_member(pItem, m_Weapon_flNextPrimaryAttack, 1.0);
			return HAM_SUPERCEDE;
		}

		SendWeaponAnim(pPlayer, TRIPMINE_HOLSTER, g_iViewModelBody[pPlayer]);
		SetAnimation(pPlayer, PLAYER_ATTACK1);
		set_member(pPlayer, m_rgAmmo, --iAmmo, iAmmoType);
		@CTripmineGrenade__Setting(pItem);

		if (iAmmo <= 0) {
			ExecuteHamB(Ham_Weapon_RetireWeapon, pItem);
			return HAM_SUPERCEDE;
		}

		set_member(pItem, m_Weapon_flNextPrimaryAttack, 0.5);
		set_member(pItem, m_Weapon_flTimeWeaponIdle, 0.5);
	}

	return HAM_SUPERCEDE;
}

@CTripmine__WeaponIdle(const pItem) {
	static pPlayer;

	if (!IsTripmine(pItem, pPlayer))
		return HAM_IGNORED;

	if (g_pCvar_ProgressBar && get_member(pItem, m_C4_bStartedArming)) {
		SetProgressBarTime(pPlayer, 0);
		set_member(pItem, m_C4_bStartedArming, false);
		ExecuteHamB(Ham_Item_PreFrame, pPlayer);
	}

	static iAmmo; iAmmo = get_member(pPlayer, m_rgAmmo, get_member(pItem, m_Weapon_iPrimaryAmmoType));

	if (g_pCvar_Preview && iAmmo && !(get_member(pPlayer, m_afButtonPressed) & IN_ATTACK)) {
		static bool:bCanPlace, Float:vecNewOrigin[3], Float:vecNewAngles[3];
		bCanPlace = CanPlace(pPlayer, vecNewOrigin, vecNewAngles);

		if (g_pentPreview[pPlayer] && !is_nullent(g_pentPreview[pPlayer])) {
			set_entvar(g_pentPreview[pPlayer], var_origin, vecNewOrigin);
			UTIL_SetOrigin(g_pentPreview[pPlayer], vecNewOrigin);
			set_entvar(g_pentPreview[pPlayer], var_angles, vecNewAngles);
		}
		else
			g_pentPreview[pPlayer] = @CTripmineGrenade__Spawn(pPlayer, vecNewOrigin, vecNewAngles);

		if (bCanPlace)
			set_entvar(g_pentPreview[pPlayer], var_effects, get_entvar(g_pentPreview[pPlayer], var_effects) & ~EF_NODRAW);
		else
			set_entvar(g_pentPreview[pPlayer], var_effects, get_entvar(g_pentPreview[pPlayer], var_effects) | EF_NODRAW);
	}

	if (get_member(pItem, m_Weapon_flTimeWeaponIdle) <= 0.0) {
		if (iAmmo <= 0) {
			ExecuteHamB(Ham_Weapon_RetireWeapon, pItem);
			return HAM_SUPERCEDE;
		}
		else
			SendWeaponAnim(pPlayer, TRIPMINE_DRAW, g_iViewModelBody[pPlayer]);

		static Float:flRand; flRand = random_float(0.0, 1.0);

		if (flRand <= 0.25) {
			SendWeaponAnim(pPlayer, TRIPMINE_IDLE1, g_iViewModelBody[pPlayer]);
			set_member(pItem, m_Weapon_flTimeWeaponIdle, 3.03);
		}
		else if (flRand <= 0.75) {
			SendWeaponAnim(pPlayer, TRIPMINE_IDLE2, g_iViewModelBody[pPlayer]);
			set_member(pItem, m_Weapon_flTimeWeaponIdle, 2.03);
		}
		else {
			SendWeaponAnim(pPlayer, TRIPMINE_FIDGET, g_iViewModelBody[pPlayer]);
			set_member(pItem, m_Weapon_flTimeWeaponIdle, 3.37);
		}
	}

	return HAM_SUPERCEDE;
}

stock UTIL_SetOrigin(const this, const Float:origin[3])
{
	new Float:mins[3], Float:maxs[3];
	get_entvar(this, var_mins, mins);
	get_entvar(this, var_maxs, maxs);
	engfunc(EngFunc_SetSize, this, mins, maxs);
	engfunc(EngFunc_SetOrigin, this, origin);
}

@CTripmineGrenade__Spawn(const pPlayer, const Float:vecOrigin[3], const Float:vecAngles[3]) {
	static maxEntities; if (!maxEntities) maxEntities = global_get(glb_maxEntities);

	if (maxEntities - engfunc(EngFunc_NumberOfEntities) <= 100)
		return NULLENT;

	new pGrenade = rg_create_entity("func_breakable");

	if (is_nullent(pGrenade)) {
		engfunc(EngFunc_AlertMessage, at_console, "NULL Ent in Create!\n");
		return NULLENT;
	}

	set_entvar(pGrenade, var_classname, MONSTER_NAME);
	engfunc(EngFunc_SetModel, pGrenade, g_szWeaponBoxModel);
	set_entvar(pGrenade, var_movetype, MOVETYPE_FLY);
	set_entvar(pGrenade, var_solid, SOLID_NOT);
	set_entvar(pGrenade, var_frame, 0.0);
	set_entvar(pGrenade, var_body, 0);
	set_entvar(pGrenade, var_sequence, 1);
	set_entvar(pGrenade, var_framerate, 0.0);
	engfunc(EngFunc_SetSize, pGrenade, Float:{-8.0, -8.0, -8.0}, Float:{8.0, 8.0, 8.0});
	engfunc(EngFunc_SetOrigin, pGrenade, vecOrigin);
	set_entvar(pGrenade, var_angles, vecAngles);
	set_entvar(pGrenade, var_rendermode, kRenderTransAdd);
	set_entvar(pGrenade, var_rendercolor, Float:{255.0, 255.0, 255.0});
	set_entvar(pGrenade, var_renderamt, 255.0);
	set_entvar(pGrenade, var_pRealOwner, pPlayer);
	return pGrenade;
}

@CTripmineGrenade__Setting(const pItem) {
	new pPlayer = get_member(pItem, m_pPlayer);
	new pGrenade;

	if (!g_pCvar_Preview) {
		new Float:vecNewOrigin[3], Float:vecNewAngles[3];
		CanPlace(pPlayer, vecNewOrigin, vecNewAngles);
		pGrenade = @CTripmineGrenade__Spawn(pPlayer, vecNewOrigin, vecNewAngles);
	}
	else {
		pGrenade = g_pentPreview[pPlayer];

		g_pentPreview[pPlayer] = 0;
	}

	if (!is_nullent(pGrenade)) {
		set_entvar(pGrenade, var_pItem, pItem);
		new Float:flGameTime = get_gametime();
		set_entvar(pGrenade, var_flPowerUp, flGameTime + 2.5);
		SetThink(pGrenade, "@CTripmineGrenade__PowerupThink");
		set_entvar(pGrenade, var_nextthink, flGameTime + 0.2);
		set_entvar(pGrenade, var_takedamage, DAMAGE_YES);
		set_entvar(pGrenade, var_dmg, float(g_pCvar_Dmg));
		set_entvar(pGrenade, var_health, float(g_pCvar_Health)); // don't let die normally
		engfunc(EngFunc_EmitSound, pGrenade, CHAN_VOICE, "weapons/mine_deploy.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
		engfunc(EngFunc_EmitSound, pGrenade, CHAN_BODY, "weapons/mine_charge.wav", 0.2, ATTN_NORM, 0, PITCH_NORM); // chargeup
		new Float:vecAngles[3]; get_entvar(pGrenade, var_angles, vecAngles);
		set_entvar(pGrenade, var_angleOwner, vecAngles);
		new Float:vecOrigin[3]; get_entvar(pGrenade, var_origin, vecOrigin);
		set_entvar(pGrenade, var_posOwner, vecOrigin);
		set_entvar(pGrenade, var_rendermode, kRenderNormal);
		set_entvar(pGrenade, var_effects, get_entvar(pGrenade, var_effects) & ~EF_NODRAW);
	}
}

@CTripmineGrenade__PowerupThink(const pGrenade) {
	if (is_nullent(pGrenade))
		return;

	static Float:posOwner[3]; get_entvar(pGrenade, var_posOwner, posOwner);
	static Float:angleOwner[3]; get_entvar(pGrenade, var_angleOwner, angleOwner);
	static Float:vecOrigin[3]; get_entvar(pGrenade, var_origin, vecOrigin);
	static Float:vecAngles[3]; get_entvar(pGrenade, var_angles, vecAngles);
	UTIL_MakeAimVectors(vecAngles);
	static Float:vecDir[3]; global_get(glb_v_forward, vecDir);
	static Float:flGameTime; flGameTime = get_gametime();

	if (!UTIL_FindWallBackward(pGrenade) || !xs_vec_equal(posOwner, vecOrigin) || !xs_vec_equal(angleOwner, vecAngles)) {
		engfunc(EngFunc_EmitSound, pGrenade, CHAN_VOICE, "weapons/mine_deploy.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
		engfunc(EngFunc_EmitSound, pGrenade, CHAN_BODY, "weapons/mine_charge.wav", 0.2, ATTN_NORM, 0, PITCH_NORM);
		new Float:vecForward[3]; xs_vec_add_scaled(vecOrigin, vecDir, 24.0, vecForward);
		new Float:vecVelocity[3]; xs_vec_mul_scalar(vecDir, 0.75, vecVelocity);
		CreateWeaponBox(vecForward, vecAngles, vecVelocity);
		SetThink(pGrenade, "@CTripmineGrenade__SUB_Remove");
		@CTripmineGrenade__KillBeam(pGrenade);
		set_entvar(pGrenade, var_nextthink, flGameTime + 0.1);
		return;
	}

	static Float:flPowerUp; get_entvar(pGrenade, var_flPowerUp, flPowerUp);

	if (flGameTime > flPowerUp) {
		set_entvar(pGrenade, var_solid, SOLID_BBOX);
		SetThink(pGrenade, "@CTripmineGrenade__BeamBreakThink");
		engfunc(EngFunc_EmitSound, pGrenade, CHAN_VOICE, "weapons/mine_activate.wav", 0.5, ATTN_NORM, 0, PITCH_NORM);
	}

	set_entvar(pGrenade, var_nextthink, flGameTime + 0.1);
}

@CTripmineGrenade__SUB_Remove(const pGrenade) {
	if (is_nullent(pGrenade))
		return;

	new Float:health;
	get_entvar(pGrenade, var_health, health);

	if (floatround(health) > 0)
	{
		set_entvar(pGrenade, var_health, 0.0);
		engfunc(EngFunc_AlertMessage, at_aiconsole, "SUB_Remove called on entity with health > 0^n");
	}

	rg_remove_entity(pGrenade);
}

@CTripmineGrenade__KillBeam(const pGrenade) {
	if (is_nullent(pGrenade))
		return;

	new pBeam = get_entvar(pGrenade, var_pBeam);

	if (!is_nullent(pBeam)) {
		rg_remove_entity(pBeam);
		set_entvar(pGrenade, var_pBeam, 0);
	}
}

@CTripmineGrenade__MakeBeam(const pGrenade) {
	if (is_nullent(pGrenade))
		return;

	new pTr = create_tr2();
	new Float:vecOrigin[3]; get_entvar(pGrenade, var_origin, vecOrigin);
	new Float:vecAngles[3]; get_entvar(pGrenade, var_angles, vecAngles);
	UTIL_MakeAimVectors(vecAngles);
	new Float:vecDir[3]; global_get(glb_v_forward, vecDir);
	xs_vec_add_scaled(vecOrigin, vecDir, 8192.0, vecDir);
	engfunc(EngFunc_TraceLine, vecOrigin, vecDir, IGNORE_MONSTERS, pGrenade, pTr);
	new Float:vecEndPos[3]; get_tr2(pTr, TR_vecEndPos, vecEndPos);
	free_tr2(pTr);

	SetThink(pGrenade, "@CTripmineGrenade__BeamBreakThink");
	set_entvar(pGrenade, var_nextthink, get_gametime() + 0.1);

	new pBeam = Beam_Create(g_szLaserSprite, 10.0);
	//set_entvar(pBeam, var_spawnflags, get_entvar(pBeam, var_spawnflags) | SF_BEAM_TEMPORARY);
	Beam_PointsInit(pBeam, vecOrigin, vecEndPos);
	Beam_SetColor(pBeam, Float:{0.0, 214.0, 198.0});
	Beam_SetScrollRate(pBeam, 255.0);
	Beam_SetBrightness(pBeam, 64.0);
	Beam_RelinkBeam(pBeam);
	set_entvar(pGrenade, var_pBeam, pBeam);
}

@CTripmineGrenade__BeamBreakThink(const pGrenade) {
	if (is_nullent(pGrenade) || !IsAlive(pGrenade))
		return;

	new pTr = create_tr2();
	static Float:vecOrigin[3]; get_entvar(pGrenade, var_origin, vecOrigin);
	static Float:vecAngles[3]; get_entvar(pGrenade, var_angles, vecAngles);
	UTIL_MakeAimVectors(vecAngles);
	static Float:v_forward[3]; global_get(glb_v_forward, v_forward);
	static Float:vecEnd[3]; xs_vec_add_scaled(vecOrigin, v_forward, 8192.0, vecEnd);
	engfunc(EngFunc_TraceLine, vecOrigin, vecEnd, DONT_IGNORE_MONSTERS, pGrenade, pTr);
	static Float:flFraction; get_tr2(pTr, TR_flFraction, flFraction);
	static pVictim; pVictim = Instance(get_tr2(pTr, TR_pHit));
	static Float:posOwner[3]; get_entvar(pGrenade, var_posOwner, posOwner);
	static Float:angleOwner[3]; get_entvar(pGrenade, var_angleOwner, angleOwner);
	static pBeam; pBeam = get_entvar(pGrenade, var_pBeam);

	if (is_nullent(pBeam)) {
		@CTripmineGrenade__MakeBeam(pGrenade);
	}
	else {
		static Float:vecEndPos[3]; get_tr2(pTr, TR_vecEndPos, vecEndPos);
		set_entvar(pBeam, var_angles, vecEndPos);
		Beam_RelinkBeam(pBeam);
	}

	if (!UTIL_FindWallBackward(pGrenade) || !xs_vec_equal(posOwner, vecOrigin) || !xs_vec_equal(angleOwner, vecAngles)) {
		set_entvar(pGrenade, var_health, 0.0);
		@CTripmineGrenade__Killed(pGrenade, 0);
		return;
	}

	free_tr2(pTr);
	static Float:flGameTime; flGameTime = get_gametime();

	if (g_pCvar_LaserDmg > 0) {
		static pAttacker; pAttacker = get_entvar(pGrenade, var_pRealOwner);

		if (IsValid(pAttacker) && !is_nullent(pVictim) && IsAlive(pVictim) && g_flDmgTime[pVictim] < flGameTime)
		{
			rg_multidmg_clear();
			rg_multidmg_add(pGrenade, pVictim, float(g_pCvar_LaserDmg), DMG_BULLET | DMG_NEVERGIB);
			rg_multidmg_apply(pGrenade, pAttacker);
			g_flDmgTime[pVictim] = flGameTime + g_pCvar_LaserDmgTime;
		}
	}
	else {
		if (flFraction < 1.0 && !is_nullent(pVictim) && IsValid(pVictim) && is_user_alive(pVictim)) {
			set_entvar(pGrenade, var_health, 0.0);
			@CTripmineGrenade__Killed(pGrenade, pVictim);
			return;
		}
	}

	set_entvar(pGrenade, var_nextthink, flGameTime + 0.033);
}

@CTripmineGrenade__TakeDamage(const pGrenade, const pInflictor, const pAttacker, const Float:flDamage, const bitsDamageType) {
	if (!pGrenade || is_nullent(pGrenade) || !FClassnameIs(pGrenade, MONSTER_NAME) || !pAttacker || is_nullent(pAttacker))
		return HAM_IGNORED;

	static pRealOwner; pRealOwner = get_entvar(pGrenade, var_pRealOwner);

	if (!pRealOwner || is_nullent(pRealOwner) || !rg_is_player_can_takedamage(pRealOwner, pAttacker))
		return HAM_IGNORED;

	static Float:flHealth; get_entvar(pGrenade, var_health, flHealth);

	if (floatround(flHealth, floatround_round) - floatround(flDamage, floatround_round) > 0)
		return HAM_IGNORED;

	@CTripmineGrenade__Killed(pGrenade, pAttacker);
	return HAM_SUPERCEDE;
}

@CTripmineGrenade__Killed(const pGrenade, const pAttacker) {
	if (is_nullent(pGrenade))
		return;

	set_entvar(pGrenade, var_takedamage, DAMAGE_NO);

	if (pAttacker) {
		new szNameA[32]; get_user_name(pAttacker, szNameA, charsmax(szNameA));
		new szNameB[32]; get_user_name(get_entvar(pGrenade, var_pRealOwner), szNameB, charsmax(szNameB));
		client_print_color(0, print_team_default, "^4[CSO]^1 O jogador^3 %s^1 destruiu o tripmine do jogador^3 %s", szNameA, szNameB);
	}

	@CTripmineGrenade__KillBeam(pGrenade);
	SetThink(pGrenade, "@CTripmineGrenade__DelayDeathThink");
	set_entvar(pGrenade, var_nextthink, get_gametime() + random_float(0.1, 0.3));
	emit_sound(pGrenade, CHAN_BODY, "common/null.wav", 0.5, ATTN_NORM, 0, PITCH_NORM); // shut off chargeup
}

@CTripmineGrenade__DelayDeathThink(const pGrenade) {
	if (is_nullent(pGrenade))
		return;

	new pTr = create_tr2();
	new Float:vecOrigin[3]; get_entvar(pGrenade, var_origin, vecOrigin);
	new Float:vecDir[3]; global_get(glb_v_forward, vecDir);
	new Float:vStart[3]; xs_vec_add_scaled(vecOrigin, vecDir, 8.0, vStart);
	new Float:vEnd[3]; xs_vec_sub_scaled(vecOrigin, vecDir, 64.0, vEnd);
	engfunc(EngFunc_TraceLine, vStart, vEnd, DONT_IGNORE_MONSTERS, pGrenade, pTr);
	Explode(pGrenade, pTr, DMG_ALWAYSGIB);
	free_tr2(pTr);
}

Explode(const pGrenade, const pTr, const bitsDamageType) {
	if (is_nullent(pGrenade))
		return;

	set_entvar(pGrenade, var_model, ""); // invisible
	set_entvar(pGrenade, var_solid, SOLID_NOT);   // intangible
	set_entvar(pGrenade, var_takedamage, DAMAGE_NO);

	new Float:flFraction; get_tr2(pTr, TR_flFraction, flFraction);
	new Float:vecEndPos[3]; get_tr2(pTr, TR_vecEndPos, vecEndPos);
	new Float:vecPlaneNormal[3]; get_tr2(pTr, TR_vecPlaneNormal, vecPlaneNormal);
	new Float:vecOrigin[3]; get_entvar(pGrenade, var_origin, vecOrigin);
	new Float:flDmg; get_entvar(pGrenade, var_dmg, flDmg);

	if (flFraction != 1.0) {
		vecOrigin[0] = vecEndPos[0] + (vecPlaneNormal[0] * (flDmg - 24.0) * 0.6);
		vecOrigin[1] = vecEndPos[1] + (vecPlaneNormal[1] * (flDmg - 24.0) * 0.6);
		vecOrigin[2] = vecEndPos[2] + (vecPlaneNormal[2] * (flDmg - 24.0) * 0.6);
	}

	new iContents = engfunc(EngFunc_PointContents, vecOrigin);

	message_begin_f(MSG_PAS, SVC_TEMPENTITY, vecOrigin);
	write_byte(TE_EXPLOSION);	// This makes a dynamic light and the explosion sprites/sound
	write_coord_f(vecOrigin[0]); // Send to PAS because of the sound
	write_coord_f(vecOrigin[1]);
	write_coord_f(vecOrigin[2] + 20.0);
	if (iContents != CONTENTS_WATER)
		write_short(g_iFireballSprite);
	else
		write_short(g_iWExplosionSprite);
	write_byte(25); // scale * 10
	write_byte(15);					   // framerate
	write_byte(TE_EXPLFLAG_NONE);
	message_end();

	new pOwner = get_entvar(pGrenade, var_pRealOwner);

	rg_dmg_radius(vecOrigin, pGrenade, pOwner, flDmg, g_pCvar_DmgRadius, CLASS_NONE, bitsDamageType);

	new pVictim = -1;

	while ((pVictim = engfunc(EngFunc_FindEntityInSphere, pVictim, vecOrigin, g_pCvar_DmgRadius)) != 0)
	{
		if (is_nullent(pVictim) || !IsValid(pVictim) || !IsValid(pOwner) || !rg_is_player_can_takedamage(pVictim, pOwner))
			continue;

		Knockback(pGrenade, 600.0, pVictim);
	}

	set_entvar(pGrenade, var_pRealOwner, 0);

	switch (random_num(0, 2)) {
		case 0:
			engfunc(EngFunc_EmitSound, pGrenade, CHAN_VOICE, "weapons/debris1.wav", 0.55, ATTN_NORM, 0, PITCH_NORM);
		case 1:
			engfunc(EngFunc_EmitSound, pGrenade, CHAN_VOICE, "weapons/debris2.wav", 0.55, ATTN_NORM, 0, PITCH_NORM);
		case 2:
			engfunc(EngFunc_EmitSound, pGrenade, CHAN_VOICE, "weapons/debris3.wav", 0.55, ATTN_NORM, 0, PITCH_NORM);
	}

	set_entvar(pGrenade, var_effects, (get_entvar(pGrenade, var_effects) | EF_NODRAW));
	SetThink(pGrenade, "@CGrenade__Smoke");
	set_entvar(pGrenade, var_velocity, NULL_VECTOR);
	set_entvar(pGrenade, var_nextthink, get_gametime() + 0.3);

	if (iContents != CONTENTS_WATER) {
		new sparkCount = random_num(0, 3);

		for (new i = 0; i < sparkCount; i++)
			Create("spark_shower", vecOrigin, vecPlaneNormal, 0);
	}
}

@CGrenade__Smoke(const pGrenade) {
	if (is_nullent(pGrenade))
		return;

	new Float:vecOrigin[3]; get_entvar(pGrenade, var_origin, vecOrigin);
	new Float:flDmg; get_entvar(pGrenade, var_dmg, flDmg);

	if (engfunc(EngFunc_PointContents, vecOrigin) == CONTENTS_WATER) {
		new Float:vecStart[3];

		vecStart[0] = vecOrigin[0] - 64.0;
		vecStart[1] = vecOrigin[1] - 64.0;
		vecStart[2] = vecOrigin[2] - 64.0;

		new Float:vecEnd[3];

		vecEnd[0] = vecOrigin[0] + 64.0;
		vecEnd[1] = vecOrigin[1] + 64.0;
		vecEnd[2] = vecOrigin[2] + 64.0;

		UTIL_Bubbles(vecStart, vecEnd, 100);
	}
	else {
		message_begin_f(MSG_PVS, SVC_TEMPENTITY, vecOrigin);
		write_byte(TE_SMOKE);
		write_coord_f(vecOrigin[0]);
		write_coord_f(vecOrigin[1]);
		write_coord_f(vecOrigin[2]);
		write_short(g_iSmokeSprite);
		write_byte(35 + random_num(0, 10)); // scale * 10
		write_byte(12); // framerate
		message_end();
	}

	//engfunc(EngFunc_RemoveEntity, pGrenade);
	rg_remove_entity(pGrenade);
}

stock UTIL_Bubbles(const Float:vecMins[3], const Float:vecMaxs[3], const iCount) {
	new Float:vecMid[3];

	vecMid[0] = (vecMins[0] + vecMaxs[0]) * 0.5;
	vecMid[1] = (vecMins[1] + vecMaxs[1]) * 0.5;
	vecMid[2] = (vecMins[2] + vecMaxs[2]) * 0.5;

	new Float:flHeight = UTIL_WaterLevel(vecMid, vecMid[2], vecMid[2] + 1024.0) - vecMins[2];

	message_begin_f(MSG_PAS, SVC_TEMPENTITY, vecMid);
	write_byte(TE_BUBBLES);
	write_coord_f(vecMins[0]);
	write_coord_f(vecMins[1]);
	write_coord_f(vecMins[2]);
	write_coord_f(vecMaxs[0]);
	write_coord_f(vecMaxs[1]);
	write_coord_f(vecMaxs[2]);
	write_coord_f(flHeight);
	write_short(g_iBubblesSprite);
	write_byte(iCount);
	write_coord_f(8.0);
	message_end();
}

stock Float:UTIL_WaterLevel(const Float:vecPosition[3], Float:flMinZ, Float:flMaxZ) {
	new Float:vecMidUp[3]; xs_vec_copy(vecPosition, vecMidUp);

	vecMidUp[2] = flMinZ;

	if (engfunc(EngFunc_PointContents, vecMidUp) != CONTENTS_WATER)
		return flMinZ;

	vecMidUp[2] = flMaxZ;

	if (engfunc(EngFunc_PointContents, vecMidUp) == CONTENTS_WATER)
		return flMaxZ;

	new Float:flDiff = flMaxZ - flMinZ;

	while (flDiff > 1.0) {
		vecMidUp[2] = flMinZ + flDiff / 2;

		if (engfunc(EngFunc_PointContents, vecMidUp) == CONTENTS_WATER)
			flMinZ = vecMidUp[2];
		else
			flMaxZ = vecMidUp[2];

		flDiff = flMaxZ - flMinZ;
	}

	return vecMidUp[2];
}

public CTripmine__Drop(const pPlayer)
{
	if (!is_user_alive(pPlayer))
		return PLUGIN_CONTINUE;

	new pActiveItem = get_member(pPlayer, m_pActiveItem);

	if (!pActiveItem || is_nullent(pActiveItem))
		return PLUGIN_CONTINUE;

	if (rg_get_iteminfo(pActiveItem, ItemInfo_iId) != any:WEAPON_C4 || get_entvar(pActiveItem, var_impulse) != TRIPMINE_KEY)
		return PLUGIN_CONTINUE;

	DropPlayerItem(pPlayer, pActiveItem);
	return PLUGIN_HANDLED;
}

DropPlayerItem(const pPlayer, const pWeapon)
{
	if (get_member(pPlayer, m_bIsVIP))
	{
		client_print(pPlayer, print_center, "#Weapon_Cannot_Be_Dropped");
		return 0;
	}

	if (pWeapon)
	{
		if (!ExecuteHamB(Ham_CS_Item_CanDrop, pWeapon))
		{
			client_print(pPlayer, print_center, "#Weapon_Cannot_Be_Dropped");
			return 0;
		}

		new iId = get_member(pWeapon, m_iId);
		set_entvar(pPlayer, var_weapons, get_entvar(pPlayer, var_weapons) & ~(1<<iId));

		// No more weapon
		if ((get_entvar(pPlayer, var_weapons) & ~(1<<31)) == 0)
			set_member(pPlayer, m_iHideHUD, get_member(pPlayer, m_iHideHUD) | HIDEHUD_WEAPONS);

		rg_switch_best_weapon(pPlayer, pWeapon);

		new Float:angles[3];
		get_entvar(pPlayer, var_angles, angles);
		engfunc(EngFunc_MakeVectors, angles);

		static const szGetCSModelName[][] =
		{
			"", "models/w_p228.mdl", "", "models/w_scout.mdl", "models/w_hegrenade.mdl", "models/w_xm1014.mdl", 
			"models/w_c4.mdl", "models/w_mac10.mdl", "models/w_aug.mdl", "models/w_smokegrenade.mdl", "models/w_elite.mdl", 
			"models/w_fiveseven.mdl", "models/w_ump45.mdl", "models/w_sg550.mdl", "models/w_galil.mdl", "models/w_famas.mdl", 
			"models/w_usp.mdl", "models/w_glock18.mdl", "models/w_awp.mdl", "models/w_mp5.mdl", "models/w_m249.mdl", 
			"models/w_m3.mdl", "models/w_m4a1.mdl", "models/w_tmp.mdl", "models/w_g3sg1.mdl", "models/w_flashbang.mdl", 
			"models/w_deagle.mdl", "models/w_sg552.mdl", "models/w_ak47.mdl", "models/w_knife.mdl", "models/w_p90.mdl"
		};

		new Float:vecOrigin[3], Float:v_forward[3], Float:vecAngles[3], Float:vecVelocity[3];
		get_entvar(pPlayer, var_origin, vecOrigin);
		global_get(glb_v_forward, v_forward);
		xs_vec_add_scaled(vecOrigin, v_forward, 10.0, vecOrigin);
		get_entvar(pPlayer, var_angles, vecAngles);
		get_entvar(pPlayer, var_velocity, vecVelocity);

		for (new i = 0; i < 3; i++)
			vecVelocity[i] = v_forward[i] * 300.0 + v_forward[i] * 100.0;

		new bool:bPackAmmo = false;

		if (get_cvar_num("mp_ammodrop") >= 2)
			bPackAmmo = true;

		new pWeaponBox = rg_create_weaponbox(
			pWeapon, 
			pPlayer, 
			szGetCSModelName[iId], 
			vecOrigin, 
			vecAngles, 
			vecVelocity, 
			float(get_cvar_num("mp_item_staytime")), 
			bPackAmmo
		);

		if (!pWeaponBox)
			return 0;

		return pWeaponBox;
	}

	return 0;
}

@CTripmine__Give(const pPlayer) {
	g_iViewModelBody[pPlayer] = 0;

	static maxEntities; if (!maxEntities) maxEntities = global_get(glb_maxEntities);

	if (maxEntities - engfunc(EngFunc_NumberOfEntities) <= 100)
		return PLUGIN_HANDLED;

	rg_drop_item(pPlayer, C4_NAME);

	new pWeapon = rg_create_entity(C4_NAME);

	if (is_nullent(pWeapon)) {
		engfunc(EngFunc_AlertMessage, at_console, "NULL Ent in Create!\n");
		return PLUGIN_HANDLED;
	}

	new Float:origin[3];
	get_entvar(pPlayer, var_origin, origin);
	set_entvar(pWeapon, var_origin, origin);
	set_entvar(pWeapon, var_spawnflags, get_entvar(pWeapon, var_spawnflags) | SF_NORESPAWN);
	set_entvar(pWeapon, var_impulse, TRIPMINE_KEY);

	dllfunc(DLLFunc_Spawn, pWeapon);
	set_member(pPlayer, m_rgAmmo, g_pCvar_Ammo, get_member(pWeapon, m_Weapon_iPrimaryAmmoType));
	dllfunc(DLLFunc_Touch, pWeapon, pPlayer);

	if (get_entvar(pWeapon, var_owner) != pPlayer)
	{
		set_entvar(pWeapon, var_flags, get_entvar(pWeapon, var_flags) | FL_KILLME);
		dllfunc(DLLFunc_Think, pWeapon);
	}

	return PLUGIN_HANDLED;
}

stock CreateWeaponBox(const Float:vecOrigin[3], const Float:vecAngles[3], const Float:vecVelocity[3]) {
	static maxEntities; if (!maxEntities) maxEntities = global_get(glb_maxEntities);

	if (maxEntities - engfunc(EngFunc_NumberOfEntities) <= 100)
		return NULLENT;

	new pWeaponBox = rg_create_entity(C4_NAME);

	if (is_nullent(pWeaponBox)) {
		engfunc(EngFunc_AlertMessage, at_console, "NULL Ent in Create!\n");
		return NULLENT;
	}

	set_entvar(pWeaponBox, var_origin, vecOrigin);
	set_entvar(pWeaponBox, var_angles, vecAngles);
	set_entvar(pWeaponBox, var_velocity, vecVelocity);
	set_entvar(pWeaponBox, var_spawnflags, get_entvar(pWeaponBox, var_spawnflags) | SF_NORESPAWN);
	set_entvar(pWeaponBox, var_impulse, TRIPMINE_KEY);
	set_entvar(pWeaponBox, var_owner, 0);

	dllfunc(DLLFunc_Spawn, pWeaponBox);

	set_entvar(pWeaponBox, var_movetype, MOVETYPE_TOSS);
	set_entvar(pWeaponBox, var_solid, SOLID_TRIGGER);
	engfunc(EngFunc_SetModel, pWeaponBox, g_szWeaponBoxModel);
	set_entvar(pWeaponBox, var_nextthink, get_gametime() + float(get_cvar_num("mp_item_staytime")));
	engfunc(EngFunc_SetSize, pWeaponBox, Float:{-16.0, -16.0, 0.0}, Float:{16.0, 16.0, 28.0});

	new Float:origin[3];
	get_entvar(pWeaponBox, var_origin, origin);
	engfunc(EngFunc_SetOrigin, pWeaponBox, origin);
	return pWeaponBox;
}

stock Create(const szName[], const Float:vecOrigin[3] = {0.0, 0.0, 0.0}, const Float:vecAngles[3] = {0.0, 0.0, 0.0}, const pentOwner = 0) {
	static maxEntities; if (!maxEntities) maxEntities = global_get(glb_maxEntities);

	if (maxEntities - engfunc(EngFunc_NumberOfEntities) <= 100)
		return NULLENT;

	new pEntity = rg_create_entity(szName);

	if (is_nullent(pEntity)) {
		engfunc(EngFunc_AlertMessage, at_console, "NULL Ent in Create!\n");
		return NULLENT;
	}

	set_entvar(pEntity, var_owner, pentOwner);
	set_entvar(pEntity, var_origin, vecOrigin);
	set_entvar(pEntity, var_angles, vecAngles);
	dllfunc(DLLFunc_Spawn, pEntity);
	return pEntity;
}

stock UTIL_Remove(const pEntity) {
	if (is_nullent(pEntity) || !(get_entvar(pEntity, var_flags) & FL_SPECTATOR) || (get_entvar(pEntity, var_flags) & FL_KILLME))
		return;

	set_entvar(pEntity, var_solid, SOLID_NOT);
	set_entvar(pEntity, var_flags, FL_KILLME);
	set_entvar(pEntity, var_targetname, 0);
	set_entvar(pEntity, var_nextthink, get_gametime());
}

stock IsAlive(const this)
{
	if (this >= 1 && this <= MaxClients)
	{
		if (!is_user_alive(this))
			return 0;
	}
	else if (this > MaxClients && this < 2265)
	{
		if (get_entvar(this, var_takedamage) == DAMAGE_NO)
			return 0;

		new Float:health;
		get_entvar(this, var_health, health);

		if (floatround(health) <= 0)
			return 0;
	}

	return 1;
}

stock SendWeaponAnim(const pPlayer, const iAnim, const iBody, const bool:bObserver = true) {
	set_entvar(pPlayer, var_weaponanim, iAnim);

	message_begin(MSG_ONE, SVC_WEAPONANIM, {0,0,0}, pPlayer);
	write_byte(iAnim);
	write_byte(iBody);
	message_end();

	if (get_entvar(pPlayer, var_iuser1) || !bObserver)
		return;

	new aPlayers[MAX_PLAYERS], iNum, i, pTarget;
	get_players(aPlayers, iNum, "bch");

	for (i = 0; i < iNum; i++) {
		pTarget = aPlayers[i];

		if (get_entvar(pTarget, var_iuser1) != OBS_IN_EYE || get_entvar(pTarget, var_iuser2) != pPlayer)
			continue;

		set_entvar(pTarget, var_weaponanim, iAnim);

		message_begin(MSG_ONE, SVC_WEAPONANIM, {0,0,0}, pTarget);
		write_byte(iAnim);
		write_byte(iBody);
		message_end();
	}
}

stock bool:GetLocalWeapon(const pPlayer) {
	new szInfo[2]; get_user_info(pPlayer, "cl_lw", szInfo, charsmax(szInfo));
	new iValue = str_to_num(szInfo);

	if (iValue < 1)
		return false;

	return true;
}

stock bool:IsTripmine(const pItem, &pPlayer) {
	if (is_nullent(pItem) || get_member(pItem, m_iId) != WEAPON_C4 || get_entvar(pItem, var_impulse) != TRIPMINE_KEY)
		return false;

	pPlayer = get_member(pItem, m_pPlayer);

	if (is_nullent(pPlayer) || !IsValid(pPlayer))
		return false;

	return true;
}

stock SendWeaponList(const pPlayer, const szName[], const iAmmo1, const iMaxAmmo1, const iAmmo2, const iMaxAmmo2, const iSlot, const iPosition, const any:iId, const iFlags) {
	message_begin(MSG_ONE, g_iMsgId_WeaponList, {0,0,0}, pPlayer);
	write_string(szName);
	write_byte(iAmmo1);
	write_byte(iMaxAmmo1);
	write_byte(iAmmo2);
	write_byte(iMaxAmmo2);
	write_byte(iSlot);
	write_byte(iPosition);
	write_byte(iId);
	write_byte(iFlags);
	message_end();
}

stock UTIL_MakeAimVectors(const Float:vecAngles[3]) {
	new Float:rgflVec[3]; xs_vec_copy(vecAngles, rgflVec);
	rgflVec[0] = -rgflVec[0];
	engfunc(EngFunc_MakeVectors, rgflVec);
}

stock SetAnimation(const pPlayer, const any:iAnim) {
	rg_set_animation(pPlayer, iAnim);
}

stock SetProgressBarTime(const pPlayer, const iDuration) {
	rg_send_bartime(pPlayer, iDuration, true);
}

stock bool:CanPlace(const pPlayer, Float:vecNewOrigin[3], Float:vecNewAngles[3]) {
	static Float:vecOrigin[3]; get_entvar(pPlayer, var_origin, vecOrigin);
	static Float:vecViewOfs[3]; get_entvar(pPlayer, var_view_ofs, vecViewOfs);
	static Float:vecSrc[3]; xs_vec_add(vecOrigin, vecViewOfs, vecSrc);
	static Float:vecVAngle[3]; get_entvar(pPlayer, var_v_angle, vecVAngle);
	static Float:vecPunchAngle[3]; get_entvar(pPlayer, var_punchangle, vecPunchAngle);
	xs_vec_add(vecVAngle, vecPunchAngle, vecVAngle);
	engfunc(EngFunc_MakeVectors, vecVAngle);
	static Float:vecAiming[3]; global_get(glb_v_forward, vecAiming);
	xs_vec_add_scaled(vecSrc, vecAiming, 128.0, vecAiming);
	engfunc(EngFunc_TraceLine, vecSrc, vecAiming, DONT_IGNORE_MONSTERS, pPlayer, 0);
	static Float:flFraction; get_tr2(0, TR_flFraction, flFraction);
	static Float:vecEndPos[3]; get_tr2(0, TR_vecEndPos, vecEndPos);
	static Float:vecPlaneNormal[3]; get_tr2(0, TR_vecPlaneNormal, vecPlaneNormal);

	if (flFraction == 1.0 || get_distance_f(vecOrigin, vecEndPos) < 50.0)
		return false;

	xs_vec_add_scaled(vecEndPos, vecPlaneNormal, 8.0, vecNewOrigin);
	engfunc(EngFunc_VecToAngles, vecPlaneNormal, vecNewAngles);
	return true;
}

stock Instance(const pEntity) {
	return (pEntity == NULLENT) ? 0 : pEntity;
}

stock GetWeaponBoxItem(const pWeaponBox) {
	new i, pItem;

	for (i = 0; i < MAX_ITEM_TYPES; i++) {
		pItem = get_member(pWeaponBox, m_WeaponBox_rgpPlayerItems, i);

		if (!is_nullent(pItem))
			return pItem;
	}

	return 0;
}

stock HasPlayerItem(const pPlayer, const pCheckItem) {
	if (is_nullent(pPlayer))
		return NULLENT;

	new pItem = get_member(pPlayer, m_rgpPlayerItems, ExecuteHamB(Ham_Item_ItemSlot, pCheckItem));
	new szClassname[32]; get_entvar(pCheckItem, var_classname, szClassname, charsmax(szClassname));

	while (!is_nullent(pItem)) {
		if (FClassnameIs(pItem, szClassname))
			return pItem;

		pItem = get_member(pItem, m_pNext);
	}

	return NULLENT;
}

stock bool:UTIL_FindWallBackward(const pEntity) {
	static Float:vecOrigin[3]; get_entvar(pEntity, var_origin, vecOrigin);
	static Float:vecAngles[3]; get_entvar(pEntity, var_angles, vecAngles);
	UTIL_MakeAimVectors(vecAngles);
	static Float:vecAiming[3]; global_get(glb_v_forward, vecAiming);
	xs_vec_sub_scaled(vecOrigin, vecAiming, 8.1, vecAiming);
	static pTr; pTr = create_tr2();
	engfunc(EngFunc_TraceLine, vecOrigin, vecAiming, DONT_IGNORE_MONSTERS, pEntity, pTr);
	static Float:flFraction; get_tr2(pTr, TR_flFraction, flFraction);
	free_tr2(pTr);

	if (flFraction == 1.0)
		return false;

	return true;
}

stock UTIL_FindEntityForward(const pEntity, Float:vecEndPos[3]) {
	static Float:vecOrigin[3]; get_entvar(pEntity, var_origin, vecOrigin);
	static Float:vecAngles[3]; get_entvar(pEntity, var_angles, vecAngles);
	UTIL_MakeAimVectors(vecAngles);
	static Float:vecAiming[3]; global_get(glb_v_forward, vecAiming);
	xs_vec_add_scaled(vecOrigin, vecAiming, 8192.0, vecAiming);
	static pTr; pTr = create_tr2();
	engfunc(EngFunc_TraceLine, vecOrigin, vecAiming, DONT_IGNORE_MONSTERS, pEntity, pTr);
	static Float:flFraction; get_tr2(pTr, TR_flFraction, flFraction);
	static pHit; pHit = get_tr2(pTr, TR_pHit);
	get_tr2(pTr, TR_vecEndPos, vecEndPos);
	free_tr2(pTr);
	return (flFraction < 1.0 && pHit) ? pHit : -1;
}

stock Knockback(const pAttacker, const Float:flForce, const pVictim, const Float:modvel = 1.0, const bool:zvel = true, const bool:noimpact = false)
{
	if (noimpact)
	{
		set_member(pVictim, m_flVelocityModifier, 1.0);
		return;
	}

	new Float:velocity[3], Float:velocity_z, Float:origin[3], Float:atkPos[3], Float:vecDir[3];
	get_entvar(pVictim, var_velocity, velocity);
	velocity_z = velocity[2];
	get_entvar(pVictim, var_origin, origin);
	get_entvar(pAttacker, var_origin, atkPos);
	xs_vec_sub(origin, atkPos, vecDir);
	xs_vec_normalize(vecDir, vecDir);
	xs_vec_mul_scalar(vecDir, flForce, vecDir);
	xs_vec_add(velocity, vecDir, velocity);

	if (!zvel)
		velocity[2] = velocity_z;

	set_entvar(pVictim, var_velocity, velocity);
	set_member(pVictim, m_flVelocityModifier, modvel);
}

stock bool:FShouldSwitchWeapon(const pPlayer, const pWeapon)
{
	if (!ExecuteHamB(Ham_Item_CanDeploy, pWeapon))
		return false;

	new pActiveItem = get_member(pPlayer, m_pActiveItem);

	if (!pActiveItem)
		return true;

	if (get_member(pPlayer, m_iAutoWepSwitch) == 0)
		return false;

	if (get_member(pPlayer, m_iAutoWepSwitch) == 2 && (get_member(pPlayer, m_afButtonLast) & (IN_ATTACK | IN_ATTACK2)))
		return false;

	if (!ExecuteHamB(Ham_Item_CanHolster, pActiveItem))
		return false;

	if (get_entvar(pPlayer, var_waterlevel) == 3)
	{
		if (rg_get_iteminfo(pWeapon, ItemInfo_iFlags) & ITEM_FLAG_NOFIREUNDERWATER)
			return false;

		if (rg_get_iteminfo(pActiveItem, ItemInfo_iFlags) & ITEM_FLAG_NOFIREUNDERWATER)
			return true;
	}

	if (rg_get_iteminfo(pWeapon, ItemInfo_iWeight) > rg_get_iteminfo(pActiveItem, ItemInfo_iWeight))
		return true;

	return false;
}
