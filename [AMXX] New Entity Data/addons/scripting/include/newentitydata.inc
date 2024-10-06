#if defined _newentitydata_included
	#endinput
#endif
#define _newentitydata_included

/**
 * Checks the validity of an entity data.
 *
 * @param this			The entity id to check.
 * @param key			The key name to check.
 *
 * @return 				true if entity data is valid, false otherwise
 */
native bool:is_valid_edata(const this, const key[]);

/**
 * Returns a integer from an entity's data.
 *
 * @param this			Entity index.
 * @param key			Key to search.
 *
 * @return				An integer value is returned.
 */
native get_edata_int(const this, const key[]);

/**
 * Sets an integer to an entity's data.
 *
 * @param this			Entity index.
 * @param key			Key to search.
 * @param value			Value to set.
 *
 * @noreturn
 */
native set_edata_int(const this, const key[], const value);

/**
 * Returns a float from an entity's.
 *
 * @param this			Entity index.
 * @param key			Key to search.
 *
 * @return				An integer value is returned.
 */
native Float:get_edata_float(const this, const key[]);

/**
 * Sets an float to an entity's data.
 *
 * @param this			Entity index.
 * @param key			Key to search.
 * @param value			Value to set.
 *
 * @noreturn
 */
native set_edata_float(const this, const key[], const Float:value);

/**
 * Returns a vector from an entity's.
 *
 * @param this			Entity index.
 * @param key			Key to search.
 * @param value			Value to get.
 *
 * @noreturn
 */
native get_edata_vector(const this, const key[], Float:value[3]);

/**
 * Sets an float to an entity's data.
 *
 * @param this			Entity index.
 * @param key			Key to search.
 * @param value			Value to set.
 *
 * @noreturn
 */
native set_edata_vector(const this, const key[], const Float:value[3]);

/**
 * Returns a string from an entity's.
 *
 * @param this			Entity index.
 * @param key			Key to search.
 * @param value			Buffer to copy value.
 * @param maxlen		Maximum length of buffer.
 *
 * @noreturn
 */
native get_edata_string(const this, const key[], value[], maxlen);

/**
 * Sets an string to an entity's data.
 *
 * @param this			Entity index.
 * @param key			Key to search.
 * @param value			Value to set.
 *
 * @noreturn
 */
native set_edata_string(const this, const key[], const value[]);

/**
 * Removes an entity data from the world.
 *
 * @param this			The entity id to search.
 * @param key			Key to search.
 *
 * @noreturn
 */
native remove_edata(const this, const key[]);

/**
 * Removes all an entity data from the world.
 *
 * @param this			The entity id to search.
 *
 * @noreturn
 */
native remove_all_edata(const this);
