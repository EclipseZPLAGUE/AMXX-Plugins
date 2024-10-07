#include <amxmodx>
#include <fakemeta>

#define STUDIO_LOOPING 0x0001
#define STUDIO_XR 0x0008
#define STUDIO_YR 0x0010
#define STUDIO_ZR 0x0020
#define IsPlayer(%0) (%0 >= 1 && %0 <= MaxClients)
#define IsEntity(%0) (%0 > MaxClients && %0 < 2265)
#define IsPlayerOrEntity(%0) (%0 >= 1 && %0 < 2265)

public plugin_natives()
{
	register_native("get_sequence_info", "native_get_sequence_info");
	register_native("reset_sequence_info", "native_reset_sequence_info");
	register_native("get_sequence_duration", "native_get_sequence_duration");
	register_native("get_weaponanim_duration", "native_get_weaponanim_duration");
	register_native("get_sequence_flags", "native_get_sequence_flags");
	register_native("studio_frame_advance", "native_studio_frame_advance");
	register_native("set_controller_ent", "native_set_controller_ent");
}

public plugin_precache()
{
	register_plugin("Animating Animation", "1.0", "Eclipse*");
}

public bool:native_get_sequence_info(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!IsPlayerOrEntity(this) || !pev_valid(this))
		return false;

	new iFlags, Float:flFrameRate, Float:flGroundSpeed;
	new bool:bResult = GetSequenceInfoEnt(this, iFlags, flFrameRate, flGroundSpeed);
	set_param_byref(2, iFlags);
	set_float_byref(3, flFrameRate);
	set_float_byref(4, flGroundSpeed);
	return bResult;
}

public native_reset_sequence_info(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!IsPlayerOrEntity(this) || !pev_valid(this))
		return;

	new iFlags, Float:flFrameRate, Float:flGroundSpeed;
	GetSequenceInfoEnt(this, iFlags, flFrameRate, flGroundSpeed);

	set_ent_data_float(this, "CBaseAnimating", "m_flFrameRate", flFrameRate);
	set_ent_data_float(this, "CBaseAnimating", "m_flGroundSpeed", flGroundSpeed);
	set_ent_data(this, "CBaseAnimating", "m_fSequenceLoops", ((iFlags & STUDIO_LOOPING) != 0));

	new Float:flTime;
	global_get(glb_time, flTime);

	set_pev(this, pev_animtime, flTime);
	set_pev(this, pev_framerate, 1.0);

	set_ent_data(this, "CBaseAnimating", "m_fSequenceFinished", false);
	set_ent_data_float(this, "CBaseAnimating", "m_flLastEventCheck", flTime);
}

public Float:native_get_sequence_duration(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!IsPlayerOrEntity(this) || !pev_valid(this))
		return 0.0;

	new file = GET_MODEL_PTR(this);

	if (!file)
		return 0.0;

	new numseq, seqindex;
	fseek(file, 164, SEEK_SET);
	fread(file, numseq, BLOCK_INT);
	fread(file, seqindex, BLOCK_INT);

	new sequence = pev(this, pev_sequence);

	if (sequence < 0 || sequence >= numseq)
	{
		fclose(file);
		return 0.0;
	}

	new Float:fps, numframes;
	fseek(file, seqindex + 32 + 176 * sequence, SEEK_SET);
	fread(file, _:fps, BLOCK_INT);
	fseek(file, 20, SEEK_CUR);
	fread(file, numframes, BLOCK_INT);
	fclose(file);
	return numframes / fps;
}

public Float:native_get_weaponanim_duration(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!IsPlayer(this) || !pev_valid(this))
		return 0.0;

	new filename[128];
	pev(this, pev_viewmodel2, filename, charsmax(filename));

	if (!file_exists(filename))
		return 0.0;

	new file = fopen(filename, "rb");

	if (!file)
		return 0.0;

	new numseq, seqindex;
	fseek(file, 164, SEEK_SET);
	fread(file, numseq, BLOCK_INT);
	fread(file, seqindex, BLOCK_INT);
	new weaponanim = pev(this, pev_weaponanim);

	if (weaponanim < 0 || weaponanim >= numseq)
	{
		fclose(file);
		return 0.0;
	}

	new Float:fps, numframes;
	fseek(file, seqindex + 32 + 176 * weaponanim, SEEK_SET);
	fread(file, _:fps, BLOCK_INT);
	fseek(file, 20, SEEK_CUR);
	fread(file, numframes, BLOCK_INT);
	fclose(file);
	return numframes / fps;
}

public native_get_sequence_flags(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!IsPlayerOrEntity(this) || !pev_valid(this))
		return 0;

	new file = GET_MODEL_PTR(this);

	if (!file)
		return 0;

	new numseq, seqindex;
	fseek(file, 164, SEEK_SET);
	fread(file, numseq, BLOCK_INT);
	fread(file, seqindex, BLOCK_INT);
	new sequence = pev(this, pev_sequence);

	if (sequence < 0 || sequence >= numseq)
	{
		fclose(file);
		return 0;
	}

	new flags;
	fseek(file, seqindex + 36 + 176 * sequence, SEEK_SET);
	fread(file, flags, BLOCK_INT);
	fclose(file);
	return flags;
}

public native_studio_frame_advance(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!IsPlayerOrEntity(this) || !pev_valid(this))
		return;

	new Float:animtime, Float:flTime;
	pev(this, pev_animtime, animtime);
	global_get(glb_time, flTime);
	new Float:flInterval = flTime - animtime;

	if (flInterval <= 0.001)
	{
		set_pev(this, pev_animtime, flTime);
		return;
	}

	if (animtime == 0.0)
		flInterval = 0.0;

	new file = GET_MODEL_PTR(this);

	if (!file)
		return;

	new numseq, seqindex;
	fseek(file, 164, SEEK_SET);
	fread(file, numseq, BLOCK_INT);
	fread(file, seqindex, BLOCK_INT);
	new sequence = pev(this, pev_sequence);

	if (sequence < 0 || sequence >= numseq)
	{
		fclose(file);
		return;
	}

	new Float:flFrameRate = 256.0;
	new Float:fps, flags, numframes, Float:frame, Float:framerate;
	fseek(file, seqindex + 32 + 176 * sequence, SEEK_SET);
	fread(file, _:fps, BLOCK_INT);
	fread(file, flags, BLOCK_INT);
	fseek(file, 16, SEEK_CUR);
	fread(file, numframes, BLOCK_INT);
	fclose(file);
	pev(this, pev_frame, frame);
	pev(this, pev_framerate, framerate);

	if (numframes > 1)
		flFrameRate = fps * 256.0 / (numframes - 1);

	frame += flInterval * flFrameRate * framerate;
	set_pev(this, pev_animtime, flTime);

	if (frame < 0.0 || frame >= 256.0)
	{
		if (flags & STUDIO_LOOPING)
			frame -= floatround(frame / 256.0) * 256.0;
		else
			frame = (frame < 0.0) ? 0.0 : 255.0;
	}

	set_pev(this, pev_frame, frame);
}

public Float:native_set_controller_ent(const plugin_id, const params_num)
{
	new this = get_param(1);
	new iController = get_param(2);
	new Float:flValue = get_param_f(3);

	if (!IsPlayerOrEntity(this) || !pev_valid(this))
		return flValue;

	new file = GET_MODEL_PTR(this);

	if (!file)
		return flValue;

	new numbonecontrollers, bonecontrollerindex, i, type, Float:start, Float:end, index;
	fseek(file, 148, SEEK_SET);
	fread(file, numbonecontrollers, BLOCK_INT);
	fread(file, bonecontrollerindex, BLOCK_INT);

	for (i = 0; i < numbonecontrollers; i++)
	{
		fseek(file, bonecontrollerindex + 4 + 24 * i, SEEK_SET);
		fread(file, type, BLOCK_INT);
		fread(file, _:start, BLOCK_INT);
		fread(file, _:end, BLOCK_INT);
		fseek(file, 4, SEEK_CUR);
		fread(file, index, BLOCK_INT);

		if (index == iController)
			break;
	}

	fclose(file);

	if (i >= numbonecontrollers)
		return flValue;

	if (type & (STUDIO_XR | STUDIO_YR | STUDIO_ZR))
	{
		if (end < start)
			flValue = -flValue;

		if (end > start + 359.0)
		{
			if (flValue > 360.0)
				flValue = flValue - floatround(flValue / 360.0) * 360.0;
			else if (flValue < 0.0)
				flValue = flValue + floatround((flValue / -360.0) + 1) * 360.0;
		}
		else
		{
			if (flValue > ((start + end) / 2) + 180)
				flValue -= 360;
			if (flValue < ((start + end) / 2) - 180)
				flValue += 360;
		}
	}

	new setting = floatround(255.0 * (flValue - start) / (end - start));
	setting = clamp(setting, 0, 255);

	switch (iController)
	{
		case 1:
			set_pev(this, pev_controller_1, setting);
		case 2:
			set_pev(this, pev_controller_2, setting);
		case 3:
			set_pev(this, pev_controller_3, setting);
		default:
			set_pev(this, pev_controller_0, setting);
	}

	return setting * (1.0 / 255.0) * (end - start) + start;
}

bool:GetSequenceInfoEnt(const this, &piFlags, &Float:pflFrameRate, &Float:pflGroundSpeed)
{
	new file = GET_MODEL_PTR(this);

	if (!file)
		return false;

	new numseq, seqindex;
	fseek(file, 164, SEEK_SET);
	fread(file, numseq, BLOCK_INT);
	fread(file, seqindex, BLOCK_INT);
	new sequence = pev(this, pev_sequence);

	if (sequence < 0 || sequence >= numseq)
	{
		fclose(file);
		piFlags = 0;
		pflFrameRate = 0.0;
		pflGroundSpeed = 0.0;
		return false;
	}

	new Float:fps, numframes;
	fseek(file, seqindex + 32 + 176 * sequence, SEEK_SET);
	fread(file, _:fps, BLOCK_INT);
	fread(file, piFlags, BLOCK_INT);
	fseek(file, 16, SEEK_CUR);
	fread(file, numframes, BLOCK_INT);

	if (numframes <= 1)
	{
		fclose(file);
		pflFrameRate = 256.0;
		pflGroundSpeed = 0.0;
		return false;
	}

	new Float:linearmovement[3];
	fseek(file, 16, SEEK_CUR);
	fread(file, _:linearmovement[0], BLOCK_INT);
	fread(file, _:linearmovement[1], BLOCK_INT);
	fread(file, _:linearmovement[2], BLOCK_INT);
	fclose(file);
	pflFrameRate = fps * 256.0 / (numframes - 1);
	pflGroundSpeed = floatsqroot(linearmovement[0] * linearmovement[0] + linearmovement[1] * linearmovement[1] + linearmovement[2] * linearmovement[2]);
	pflGroundSpeed = pflGroundSpeed * fps / (numframes - 1);
	return true;
}

GET_MODEL_PTR(const this)
{
	new filename[128];

	if (IsPlayer(this))
	{
		new model[32];
		get_user_info(this, "model", model, charsmax(model));
		formatex(filename, charsmax(filename), "models/player/%s/%s.mdl", model, model);
	}
	else if (IsEntity(this))
		pev(this, pev_model, filename, charsmax(filename));

	if (!file_exists(filename))
		return 0;

	new file = fopen(filename, "rb");

	if (!file)
		return 0;

	return file;
}
