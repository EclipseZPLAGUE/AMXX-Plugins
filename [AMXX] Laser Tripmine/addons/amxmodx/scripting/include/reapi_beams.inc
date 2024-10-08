/* AMX Mod X
*	Beam entities include by KORD_12.7.
*
* Version 1.3 (last update: 4, may (05), 2013)
*
* http://aghl.ru/forum/ - Russian Half-Life and Adrenaline Gamer Community
*
* This file is provided as is (no warranties)
*/

#if defined _reapi_beams_included
	#endinput
#endif
#define _reapi_beams_included

#include <engine>
#include <reapi>
#include <xs>


// These functions are here to show the way beams are encoded as entities.
// Encoding beams as entities simplifies their management in the client/server architecture.


// Beam types
enum _:Beam_Types
{
	BEAM_POINTS,
	BEAM_ENTPOINT,
	BEAM_ENTS,
	BEAM_HOSE
};

// Beam flags
#define BEAM_FSINE	0x10
#define BEAM_FSOLID	0x20
#define BEAM_FSHADEIN	0x40
#define BEAM_FSHADEOUT	0x80


#define Beam_SetType(%0,%1) set_entvar(%0, var_rendermode, (get_entvar(%0, var_rendermode) & 0xF0) | %1 & 0x0F)
/* stock Beam_SetType(const iBeamEntity, const iType)
	return set_entvar(iBeamEntity, var_rendermode, (get_entvar(iBeamEntity, var_rendermode) & 0xF0) | iType & 0x0F); */
	
#define Beam_SetFlags(%0,%1) set_entvar(%0, var_rendermode, (get_entvar(%0, var_rendermode) & 0x0F) | %1 & 0xF0)
/* stock Beam_SetFlags(const iBeamEntity, const iType)
	return set_entvar(iBeamEntity, var_rendermode, (get_entvar(iBeamEntity, var_rendermode) & 0x0F) | iType & 0xF0); */	

#define Beam_SetStartPos(%0,%1) set_entvar(%0, var_origin, %1)
/* stock Beam_SetStartPos(const iBeamEntity, const Float: flVecStart[3])
	return set_entvar(iBeamEntity, var_origin, flVecStart); */

#define Beam_SetEndPos(%0,%1) set_entvar(%0, var_angles, %1)
/* stock Beam_SetEndPos(const iBeamEntity, const Float: flVecEnd[3]) 
	return set_entvar(iBeamEntity, var_angles, flVecEnd); */

#define Beam_SetStartEntity(%0,%1) \
	set_entvar(%0, var_sequence, (%1 & 0x0FFF) | ((get_entvar(%0, var_sequence) & 0xF000) << 12)); \
	set_entvar(%0, var_owner, %1) \
/* stock Beam_SetStartEntity(const iBeamEntity, const iEntityIndex) */

#define Beam_SetEndEntity(%0,%1) \
	set_entvar(%0, var_skin, (%1 & 0x0FFF) | ((get_entvar(%0, var_skin) & 0xF000) << 12)); \
	set_entvar(%0, var_aiment, %1) \
/* stock Beam_SetEndEntity(const iBeamEntity, const iEntityIndex) */

#define Beam_SetStartAttachment(%0,%1) set_entvar(%0, var_sequence, (get_entvar(%0, var_sequence) & 0x0FFF) | ((%1 & 0xF) << 12))
/* stock Beam_SetStartAttachment(const iBeamEntity, const iAttachment)
	return set_entvar(iBeamEntity, var_sequence, (get_entvar(iBeamEntity, var_sequence) & 0x0FFF) | ((iAttachment & 0xF) << 12)); */

#define Beam_SetEndAttachment(%0,%1) set_entvar(%0, var_skin, (get_entvar(%0, var_skin) & 0x0FFF) | ((%1 & 0xF) << 12))
/* stock Beam_SetEndAttachment(const iBeamEntity, const iAttachment)
	return set_entvar(iBeamEntity, var_skin, (get_entvar(iBeamEntity, var_skin) & 0x0FFF) | ((iAttachment & 0xF) << 12)); */

#define Beam_SetTexture(%0,%1) set_entvar(%0, var_modelindex, %1)
/* stock Beam_SetTexture(const iBeamEntity, const iSpriteIndex)
	return set_entvar(iBeamEntity, var_modelindex, iSpriteIndex); */

#define Beam_SetWidth(%0,%1) set_entvar(%0, var_scale, %1)
/* stock Beam_SetWidth(const iBeamEntity, const Float: flWidth)
	return set_entvar(iBeamEntity, var_scale, flWidth); */

#define Beam_SetNoise(%0,%1) set_entvar(%0, var_body, %1)
/* stock Beam_SetNoise(const iBeamEntity, const iNoise)
	return set_entvar(iBeamEntity, var_body, iNoise); */	
	
#define Beam_SetColor(%0,%1) set_entvar(%0, var_rendercolor, %1)
/* stock Beam_SetColor(const iBeamEntity, const Float: flColor[3])
	return set_entvar(iBeamEntity, var_rendercolor, flColor); */	
		
#define Beam_SetBrightness(%0,%1) set_entvar(%0, var_renderamt, %1)
/* stock Beam_SetBrightness(const iBeamEntity, const Float: flBrightness)
	return set_entvar(iBeamEntity, var_renderamt, flBrightness); */

#define Beam_SetFrame(%0,%1) set_entvar(%0, var_frame, %1)
/* stock Beam_SetFrame(const iBeamEntity, const Float: flFrame)
	return set_entvar(iBeamEntity, var_frame, flFrame); */

#define Beam_SetScrollRate(%0,%1) set_entvar(%0, var_animtime, %1)
/* stock Beam_SetScrollRate(const iBeamEntity, const Float: flSpeed)
	return set_entvar(iBeamEntity, var_animtime, flSpeed); */

#define Beam_GetType(%0) (get_entvar(%0, var_rendermode) & 0x0F)
/* stock Beam_GetType(const iBeamEntity)
	return get_entvar(iBeamEntity, var_rendermode) & 0x0F; */
	
#define Beam_GetFlags(%0) (get_entvar(%0, var_rendermode) & 0xF0)
/* stock Beam_GetFlags(const iBeamEntity)
	return get_entvar(iBeamEntity, var_rendermode) & 0xF0; */	

#define Beam_GetStartEntity(%0) (get_entvar(%0, var_sequence) & 0xFFF)
/* stock Beam_GetStartEntity(const iBeamEntity)
	return get_entvar(iBeamEntity, var_sequence) & 0xFFF; */

#define Beam_GetEndEntity(%0) (get_entvar(%0, var_skin) & 0xFFF)
/* stock Beam_GetEndEntity(const iBeamEntity)
	return get_entvar(iBeamEntity, var_skin) & 0xFFF; */

stock Beam_GetStartPos(const iBeamEntity, Float: vecStartPos[3])
{
	static iEntity; iEntity = Beam_GetStartEntity(iBeamEntity);
	
	if (Beam_GetType(iBeamEntity) == BEAM_ENTS && !is_nullent(iEntity))
	{
		get_entvar(iEntity, var_origin, vecStartPos);
		return;
	}
	
	get_entvar(iBeamEntity, var_origin, vecStartPos);
}

stock Beam_GetEndPos(const iBeamEntity, Float: vecEndPos[3])
{
	static iType; 
	static iEntity;
	
	iType = Beam_GetType(iBeamEntity);
	
	if (iType == BEAM_POINTS || iType == BEAM_HOSE)
	{
		get_entvar(iBeamEntity, var_angles, vecEndPos);
		return;
	}
	
	iEntity = Beam_GetEndEntity(iBeamEntity);
	
	if (!is_nullent(iEntity))
	{
		get_entvar(iEntity, var_origin, vecEndPos);
		return;
	}
	
	get_entvar(iBeamEntity, var_angles, vecEndPos);
}

#define Beam_GetTexture(%0) get_entvar(%0, var_modelindex)
/* stock Beam_GetTexture(const iBeamEntity)
	return get_entvar(iBeamEntity, var_modelindex); */
	
#define Beam_GetWidth(%0) entity_get_float(%0, EV_FL_scale)
/* stock Float: Beam_GetWidth(const iBeamEntity)
	return entity_get_float(iBeamEntity, EV_FL_scale); */

#define Beam_GetNoise(%0) get_entvar(%0, var_body)
/* stock Beam_GetNoise(const iBeamEntity)
	return get_entvar(iBeamEntity, var_body); */
	
#define Beam_GetColor(%0,%1) get_entvar(%0, var_rendercolor,%1)
/* stock Beam_GetColor(const iBeamEntity, Float: flRGB[3])
	return get_entvar(iBeamEntity, var_rendercolor, flRGB); */

#define Beam_GetBrightness(%0) entity_get_float(%0, EV_FL_renderamt)
/* stock Float: Beam_GetBrightness(const iBeamEntity)
	return entity_get_float(iBeamEntity, EV_FL_renderamt); */
	
#define Beam_GetFrame(%0) entity_get_float(%0, EV_FL_frame)
/* stock Float: Beam_GetFrame(const iBeamEntity)
	return entity_get_float(iBeamEntity, EV_FL_frame); */

#define Beam_GetScrollRate(%0) entity_get_float(%0, EV_FL_animtime)
/* stock Float: Beam_GetScrollRate(const iBeamEntity)
	return entity_get_float(iBeamEntity, EV_FL_animtime); */

stock Beam_Create(const szSpriteName[], const Float: flWidth)
{
	static iBeamEntity;
	iBeamEntity = rg_create_entity("beam", false);
	
	if (is_nullent(iBeamEntity))
	{
		return NULLENT;
	}
	
	Beam_Init(iBeamEntity, szSpriteName, flWidth);
	return iBeamEntity;
}

stock Beam_Init(const iBeamEntity, const szSpriteName[], const Float: flWidth)
{
	set_entvar(iBeamEntity, var_flags, get_entvar(iBeamEntity, var_flags) | FL_CUSTOMENTITY);
	
	Beam_SetColor(iBeamEntity, Float: {255.0, 255.0, 255.0});
	Beam_SetBrightness(iBeamEntity, 255.0);
	Beam_SetNoise(iBeamEntity, 0);
	Beam_SetFrame(iBeamEntity, 0.0);
	Beam_SetScrollRate(iBeamEntity, 0.0);
	Beam_SetWidth(iBeamEntity, flWidth);
	
	engfunc(EngFunc_SetModel, iBeamEntity, szSpriteName);
	
	set_entvar(iBeamEntity, var_skin, 0);
	set_entvar(iBeamEntity, var_sequence, 0);
	set_entvar(iBeamEntity, var_rendermode, 0);
}

stock Beam_PointsInit(const iBeamEntity, const Float: flVecStart[3], const Float: flVecEnd[3])
{
	Beam_SetType(iBeamEntity, BEAM_POINTS);
	Beam_SetStartPos(iBeamEntity, flVecStart);
	Beam_SetEndPos(iBeamEntity, flVecEnd);
	Beam_SetStartAttachment(iBeamEntity, 0);
	Beam_SetEndAttachment(iBeamEntity, 0);
	Beam_RelinkBeam(iBeamEntity);
}

stock Beam_HoseInit(const iBeamEntity, const Float: flVecStart[3], const Float: flVecDirection[3])
{
	Beam_SetType(iBeamEntity, BEAM_HOSE);
	Beam_SetStartPos(iBeamEntity, flVecStart);
	Beam_SetEndPos(iBeamEntity, flVecDirection);
	Beam_SetStartAttachment(iBeamEntity, 0);
	Beam_SetEndAttachment(iBeamEntity, 0);
	Beam_RelinkBeam(iBeamEntity);
}

stock Beam_PointEntInit(const iBeamEntity, const Float: flVecStart[3], const iEndIndex)
{
	Beam_SetType(iBeamEntity, BEAM_ENTPOINT);
	Beam_SetStartPos(iBeamEntity, flVecStart);
	Beam_SetEndEntity(iBeamEntity, iEndIndex);
	Beam_SetStartAttachment(iBeamEntity, 0);
	Beam_SetEndAttachment(iBeamEntity, 0);
	Beam_RelinkBeam(iBeamEntity);
}

stock Beam_EntsInit(const iBeamEntity, const iStartIndex, const iEndIndex)
{
	Beam_SetType(iBeamEntity, BEAM_ENTS);
	Beam_SetStartEntity(iBeamEntity, iStartIndex);
	Beam_SetEndEntity(iBeamEntity, iEndIndex);
	Beam_SetStartAttachment(iBeamEntity, 0);
	Beam_SetEndAttachment(iBeamEntity, 0);
	Beam_RelinkBeam(iBeamEntity);
}

stock Beam_RelinkBeam(const iBeamEntity)
{
	static Float:vecMins[3];
	static Float:vecMaxs[3];
	
	static Float:vecOrigin[3];
	static Float:vecEndPos[3];
	static Float:vecStartPos[3];
	
	get_entvar(iBeamEntity, var_origin, vecOrigin);
	
	Beam_GetStartPos(iBeamEntity, vecStartPos);
	Beam_GetEndPos(iBeamEntity, vecEndPos);
	
	vecMins[0] = floatmin(vecStartPos[0], vecEndPos[0]);
	vecMins[1] = floatmin(vecStartPos[1], vecEndPos[1]);
	vecMins[2] = floatmin(vecStartPos[2], vecEndPos[2]);
	
	vecMaxs[0] = floatmax(vecStartPos[0], vecEndPos[0]);
	vecMaxs[1] = floatmax(vecStartPos[1], vecEndPos[1]);
	vecMaxs[2] = floatmax(vecStartPos[2], vecEndPos[2]);
	
	xs_vec_sub(vecMins, vecOrigin, vecMins);
	xs_vec_sub(vecMaxs, vecOrigin, vecMaxs);
	
	set_entvar(iBeamEntity, var_mins, vecMins);
	set_entvar(iBeamEntity, var_maxs, vecMaxs);
	
	engfunc(EngFunc_SetSize, iBeamEntity, vecMins, vecMaxs);
	engfunc(EngFunc_SetOrigin, iBeamEntity, vecOrigin);
}
