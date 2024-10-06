#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <newentitydata>

#define MAX_ENTITIES 2265

#define IsPlayer(%0) (%0 >= 1 && %0 <= MaxClients)
#define IsEntity(%0) (%0 > MaxClients && %0 <= MAX_ENTITIES)

new const Float:g_flCoordinates[][] =
{
	{ -1.0, 0.375 }, 
	{ 0.575, 0.4 }, 
	{ 0.6, -1.0 }, 
	{ 0.575, 0.575 }, 
	{ -1.0, 0.6 }, 
	{ 0.4, 0.575 }, 
	{ 0.375, -1.0 }, 
	{ 0.4, 0.4 }
}

new g_iPos[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("New Bullet Damage", "1.0", "Eclipse*");

	//RegisterHookChain(RG_CBasePlayer_Spawn, "RG_CBasePlayer_Spawn_Post", 1);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "RG_CBasePlayer_TakeDamage_Post", 1);

	RegisterHam(Ham_TakeDamage, "hostage_entity", "Ham_TakeDamage_Post", 1, true);
	RegisterHam(Ham_TakeDamage, "func_breakable", "Ham_TakeDamage_Post", 1, true);
	RegisterHam(Ham_TakeDamage, "info_target", "Ham_TakeDamage_Post", 1, true);
}

public client_putinserver(this)
{
	g_iPos[this] = 0;
}

public client_disconnected(this)
{
	g_iPos[this] = 0;
}

/*public RG_CBasePlayer_Spawn_Post(const this)
{
	if (!is_user_alive(this))
		return;

	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(this, authid, charsmax(authid));

	if (!strcmp(authid, "STEAM_0:0:97473523"))
	{
		set_entvar(this, var_max_health, 10000.0);
		set_entvar(this, var_health, 10000.0);
		set_entvar(this, var_gravity, 0.5);
	}
	else
	{
		set_entvar(this, var_max_health, 3000.0);
		set_entvar(this, var_health, 3000.0);
	}
}*/

public RG_CBasePlayer_TakeDamage_Post(const this, const pevInflictor, const pevAttacker, const Float:flDamage, const bitsDamageType)
{
	if (is_nullent(this) || is_nullent(pevAttacker) || !is_user_connected(this) || !is_user_connected(pevAttacker))
		return;

	if (!rg_is_player_can_takedamage(this, pevAttacker))
		return;

	displayDamage(pevAttacker, floatround(flDamage));

	//new authid[MAX_AUTHID_LENGTH];
	//get_user_authid(this, authid, charsmax(authid));

	/*if (!strcmp(authid, "STEAM_0:0:97473523"))
		set_member(this, m_flVelocityModifier, 1.0);*/
}

public Ham_TakeDamage_Post(const this, const pevInflictor, const pevAttacker, const Float:flDamage, const bitsDamageType)
{
	if (is_nullent(this) || !IsEntity(this))
		return;

	if (!IsPlayer(pevAttacker) || !is_user_connected(pevAttacker))
		return;

	displayDamage(pevAttacker, floatround(flDamage));
}

stock displayDamage(const this, const iDamage)
{
	if (g_iPos[this] >= sizeof g_flCoordinates)
		g_iPos[this] = 0;

	set_hudmessage(
		0, 
		200, 
		240, 
		g_flCoordinates[g_iPos[this]][0], 
		g_flCoordinates[g_iPos[this]][1], 
		1, 
		1.5, 
		3.0, 
		0.01, 
		0.01, 
		-1, 
		0, 
		{255, 255, 250, 0}
	);
	show_hudmessage(this, "%i", iDamage);
	g_iPos[this]++;
}
