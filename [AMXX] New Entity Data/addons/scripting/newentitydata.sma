#include <amxmodx>

#define is_valid_entity(%0) (%0 >= 1 && %0 <= 2265)

new Trie:g_entitydata;

public plugin_natives()
{
	g_entitydata = TrieCreate();

	register_native("is_valid_edata", "native_is_valid_edata");
	register_native("get_edata_int", "native_get_edata_int");
	register_native("set_edata_int", "native_set_edata_int");
	register_native("get_edata_float", "native_get_edata_float");
	register_native("set_edata_float", "native_set_edata_float");
	register_native("get_edata_vector", "native_get_edata_vector");
	register_native("set_edata_vector", "native_set_edata_vector");
	register_native("get_edata_string", "native_get_edata_string");
	register_native("set_edata_string", "native_set_edata_string");
	register_native("remove_edata", "native_remove_edata");
	register_native("remove_all_edata", "native_remove_all_edata");
}

public plugin_precache()
{
	register_plugin("New Entity Data", "1.0", "Eclipse*");
}

public bool:native_is_valid_edata(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return false;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return false;

	new keyt[64 + 8];
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);
	return TrieKeyExists(g_entitydata, keyt);
}

public native_get_edata_int(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return 0;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return 0;

	new keyt[64 + 8], value;
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);
	TrieGetCell(g_entitydata, keyt, value);
	return value;
}

public native_set_edata_int(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return;

	new keyt[64 + 8];
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);
	TrieSetCell(g_entitydata, keyt, get_param(3));
}

public Float:native_get_edata_float(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return 0.0;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return 0.0;

	new keyt[64 + 8], Float:value[1];
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);
	TrieGetArray(g_entitydata, keyt, value, sizeof(value));
	return value[0];
}

public native_set_edata_float(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return;

	new keyt[64 + 8], Float:value[1];
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);
	value[0] = get_param_f(3);
	TrieSetArray(g_entitydata, keyt, value, sizeof(value));
}

public native_get_edata_vector(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return;

	new keyt[64 + 8], Float:value[3];
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);
	TrieGetArray(g_entitydata, keyt, value, sizeof(value));
	set_array_f(3, value, sizeof(value));
}

public native_set_edata_vector(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return;

	new keyt[64 + 8], Float:value[3];
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);
	get_array_f(3, value, sizeof(value));
	TrieSetArray(g_entitydata, keyt, value, sizeof(value));
}

public native_get_edata_string(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return 0;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return 0;

	new keyt[64 + 8], value[128];
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);
	TrieGetString(g_entitydata, keyt, value, charsmax(value));
	return set_string(3, value, get_param(4));
}

public native_set_edata_string(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return;

	new keyt[64 + 8], value[128];
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);
	get_string(3, value, charsmax(value));
	TrieSetString(g_entitydata, keyt, value);
}

public native_remove_edata(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return false;

	new key[64];

	if (!get_string(2, key, charsmax(key)))
		return false;

	new keyt[64 + 8];
	formatex(keyt, charsmax(keyt), "%i:%s", this, key);

	if (!TrieKeyExists(g_entitydata, keyt))
		return false;

	TrieDeleteKey(g_entitydata, keyt);
	return true;
}

public native_remove_all_edata(const plugin_id, const params_num)
{
	new this = get_param(1);

	if (!is_valid_entity(this))
		return 0;

	new Snapshot:keys = TrieSnapshotCreate(g_entitydata);
	new keyt[64 + 8], entity[8], key[64];
	new count = 0;

	for (new i = 0; i < TrieSnapshotLength(keys); i++)
	{
		TrieSnapshotGetKey(keys, i, keyt, charsmax(keyt));
		strtok2(keyt, entity, charsmax(entity), key, charsmax(key), ':');

		if (str_to_num(entity) != this)
			continue;

		TrieDeleteKey(g_entitydata, keyt);
		count++;
	}

	TrieSnapshotDestroy(keys);
	return count;
}

#if AMXX_VERSION_NUM < 183
public plugin_end()
{
	TrieDestroy(g_entitydata);
}
#endif
