#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <xs>

#define MAX_DISTANCE        192.0
#define CAMERA_FACING       4

new g_camera_model[MAX_RESOURCE_PATH_LENGTH] = "models/pshell.mdl";
new g_camera_ent[MAX_PLAYERS + 1];
new g_camera_type[MAX_PLAYERS + 1];
new Float:g_camera_distance[MAX_PLAYERS + 1];
new g_camera_num;
new g_playerpostthink_post;

public plugin_precache()
{
	precache_model(g_camera_model);
}

public plugin_init()
{
	register_plugin("Camera Base", "1.0", "Eclipse*");

	register_dictionary("camera.txt");

	register_clcmd("say /camera", "clcmd_camera");
	register_clcmd("say_team /camera", "clcmd_camera");

	register_clcmd("camera_zoom_out", "clcmd_camera_zoom_out");
	register_clcmd("camera_zoom_in", "clcmd_camera_zoom_in");

	g_camera_num = 0;
	g_playerpostthink_post = 0;
}

public client_putinserver(id)
{
	g_camera_ent[id] = 0;
	g_camera_type[id] = CAMERA_NONE;
	g_camera_distance[id] = MAX_DISTANCE;
}

public client_disconnected(id)
{
	camera_destroy(id);
	g_camera_type[id] = CAMERA_NONE;
}

public clcmd_camera(const id)
{
	if (!is_user_alive(id))
		return PLUGIN_HANDLED;

	show_camera_menu(id);
	return PLUGIN_HANDLED;
}

public clcmd_camera_zoom_out(const id)
{
	if (g_camera_distance[id] > 0.0)
		g_camera_distance[id] -= 4.0;

	return PLUGIN_HANDLED;
}

public clcmd_camera_zoom_in(const id)
{
	if (g_camera_distance[id] < MAX_DISTANCE)
		g_camera_distance[id] += 4.0;

	return PLUGIN_HANDLED;
}

public show_camera_menu(const id)
{
	SetGlobalTransTarget(id);

	new menu = menu_create(fmt("%l", "Cstrike_Camera_Menu", g_camera_distance[id]), "menu_camera");

	menu_additem(menu, fmt("%l", "Cstrike_Camera_ThirdPerson"), fmt("%i", CAMERA_3RDPERSON));
	menu_additem(menu, fmt("%l", "Cstrike_Camera_UpLeft"), fmt("%i", CAMERA_UPLEFT));
	menu_additem(menu, fmt("%l", "Cstrike_Camera_TopDown"), fmt("%i", CAMERA_TOPDOWN));
	menu_additem(menu, fmt("%l", "Cstrike_Camera_Facing"), fmt("%i", CAMERA_FACING));
	menu_additem(menu, fmt("%l", "Cstrike_Camera_None"), fmt("%i", CAMERA_NONE));

	menu_addblank2(menu);
	menu_addblank2(menu);

	menu_additem(menu, fmt("%l", "Cstrike_Camera_ZoomOut"), "-");
	menu_additem(menu, fmt("%l", "Cstrike_Camera_ZoomIn"), "+");

	menu_setprop(menu, MPROP_PERPAGE, 0);
	menu_setprop(menu, MPROP_EXITNAME, fmt("%l", "Cstrike_Camera_MenuExit"));
	menu_setprop(menu, MPROP_EXIT, MEXIT_FORCE);
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\w");
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public menu_camera(const id, const menu, const item)
{
	if (item == MENU_EXIT || !is_user_alive(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new info[2];
	menu_item_getinfo(menu, item, _, info, charsmax(info));

	switch (info[0])
	{
		case '-':
		{
			if (g_camera_distance[id] > 0.0)
				g_camera_distance[id] -= 4.0;

			menu_destroy(menu);
			show_camera_menu(id);
			return PLUGIN_HANDLED;
		}
		case '+':
		{
			if (g_camera_distance[id] < MAX_DISTANCE)
				g_camera_distance[id] += 4.0;

			menu_destroy(menu);
			show_camera_menu(id);
			return PLUGIN_HANDLED;
		}
	}

	g_camera_type[id] = str_to_num(info);
	camera_create(id);
	menu_destroy(menu);
	show_camera_menu(id);
	return PLUGIN_HANDLED;
}

camera_create(const id)
{
	if (g_camera_ent[id] && is_valid_ent(g_camera_ent[id]))
		return;

	g_camera_ent[id] = create_entity("info_null");

	if (!g_camera_ent[id] || !is_valid_ent(g_camera_ent[id]))
		return;

	entity_set_string(g_camera_ent[id], EV_SZ_classname, "VexdCam");
	entity_set_model(g_camera_ent[id], g_camera_model);
	entity_set_size(g_camera_ent[id], Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});
	entity_set_int(g_camera_ent[id], EV_INT_movetype, MOVETYPE_NOCLIP);
	entity_set_int(g_camera_ent[id], EV_INT_solid, SOLID_NOT);
	entity_set_float(g_camera_ent[id], EV_FL_takedamage, DAMAGE_NO);
	entity_set_float(g_camera_ent[id], EV_FL_gravity, 0.0);
	entity_set_edict(g_camera_ent[id], EV_ENT_owner, id);
	entity_set_int(g_camera_ent[id], EV_INT_rendermode, kRenderTransColor);
	entity_set_float(g_camera_ent[id], EV_FL_renderamt, 0.0);
	entity_set_int(g_camera_ent[id], EV_INT_renderfx, kRenderFxNone);
	g_camera_num++;

	if (g_camera_num && !g_playerpostthink_post)
		g_playerpostthink_post = register_forward(FM_PlayerPostThink, "FM_PlayerPostThink_Post", 1);
}

camera_destroy(const id)
{
	if (!g_camera_ent[id] || !is_valid_ent(g_camera_ent[id]))
		return;

	remove_entity(g_camera_ent[id]);
	g_camera_ent[id] = 0;
	g_camera_num--;

	if (!g_camera_num && g_playerpostthink_post)
	{
		unregister_forward(FM_PlayerPostThink, g_playerpostthink_post, 1);
		g_playerpostthink_post = 0;
	}
}

public FM_PlayerPostThink_Post(const id)
{
	if (!is_user_connected(id) || !is_user_alive(id) || !g_camera_ent[id] || !is_valid_ent(g_camera_ent[id]))
		return FMRES_IGNORED;

	new tr = create_tr2();
	new Float:v_angle[3], Float:punchangle[3], Float:v_angles[3], Float:origin[3], Float:view_ofs[3], Float:src[3], Float:aiming[3], Float:dest[3], Float:endpos[3];
	pev(id, pev_v_angle, v_angle);
	pev(id, pev_punchangle, punchangle);
	xs_vec_add(v_angle, punchangle, v_angles);
	engfunc(EngFunc_MakeVectors, v_angles);
	pev(id, pev_origin, origin);
	pev(id, pev_view_ofs, view_ofs);
	xs_vec_add(origin, view_ofs, src);
	global_get(glb_v_forward, aiming);

	switch (g_camera_type[id])
	{
		case CAMERA_3RDPERSON:
		{
			xs_vec_sub_scaled(src, aiming, g_camera_distance[id], dest);
			engfunc(EngFunc_TraceLine, src, dest, IGNORE_MONSTERS, id, tr);
			get_tr2(tr, TR_vecEndPos, endpos);
			entity_set_origin(g_camera_ent[id], endpos);
			entity_set_vector(g_camera_ent[id], EV_VEC_angles, v_angle);
			attach_view(id, g_camera_ent[id]);
		}
		case CAMERA_UPLEFT:
		{
			new Float:v_right[3], Float:v_up[3];
			global_get(glb_v_right, v_right);
			global_get(glb_v_up, v_up);

			for (new i; i < 3; i++)
				dest[i] = src[i] - ((aiming[i] * 32.0) - ((v_right[i] * 15.0) + (v_up[i] * 15.0)));

			engfunc(EngFunc_TraceLine, src, dest, IGNORE_MONSTERS, id, tr);
			get_tr2(tr, TR_vecEndPos, endpos);
			entity_set_origin(g_camera_ent[id], endpos);
			entity_set_vector(g_camera_ent[id], EV_VEC_angles, v_angle);
			attach_view(id, g_camera_ent[id]);
		}
		case CAMERA_TOPDOWN:
		{
			new Float:v_top[3];
			xs_vec_set(v_top, 0.0, 0.0, g_camera_distance[id]);
			xs_vec_add(src, v_top, dest);
			engfunc(EngFunc_TraceLine, src, dest, IGNORE_MONSTERS, id, tr);
			get_tr2(tr, TR_vecEndPos, endpos);

			v_angle[0] = 90.0;

			entity_set_origin(g_camera_ent[id], endpos);
			entity_set_vector(g_camera_ent[id], EV_VEC_angles, v_angle);
			attach_view(id, g_camera_ent[id]);
		}
		case CAMERA_FACING:
		{
			xs_vec_add_scaled(src, aiming, g_camera_distance[id], dest);
			engfunc(EngFunc_TraceLine, src, dest, IGNORE_MONSTERS, id, tr);
			get_tr2(tr, TR_vecEndPos, endpos);

			v_angle[0] = -v_angle[0];
			v_angle[1] = v_angle[1] + 180.0;

			entity_set_origin(g_camera_ent[id], endpos);
			entity_set_vector(g_camera_ent[id], EV_VEC_angles, v_angle);
			attach_view(id, g_camera_ent[id]);
		}
		default:
		{
			attach_view(id, id);
			camera_destroy(id);
		}
	}

	free_tr2(tr);
	return FMRES_IGNORED;
}

stock GetGunPosition(const this, Float:vecSrc[3])
{
	new Float:origin[3], Float:view_ofs[3];
	get_entvar(this, var_origin, origin);
	get_entvar(this, var_view_ofs, view_ofs);
	xs_vec_add(origin, view_ofs, vecSrc);
}
