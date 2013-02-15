#if defined _store_core_included
#endinput
#endif
#define _store_core_included

#define STORE_VERSION "1.1-alpha"
#define STORE_PREFIX "\x04[Store] \x01"

funcenum Store_MenuItemClickCallback
{
	public(client, const String:value[])
}

/**
 * Opens the main menu for a player.
 *
 * @param client		Client Index
 *
 * @noreturn
 */
native Store_OpenMainMenu(client);

/**
 * Adds an item to the main menu. 
 *
 * @param displayName		The text of the item, as it is shown to the player.
 * @param description		A short description of the item.
 * @param value				Item information string that will be sent to the callback.
 * @param callback			Callback to the item click event.
 * @param order				Preferred position of the item in the menu.
 *
 * @noreturn
 */
native Store_AddMainMenuItem(const String:displayName[], const String:description[] = "", const String:value[] = "", Store_MenuItemClickCallback:callback, order = 32);

/**
 * Retrieve currency name as it is defined in the core condig file.
 *
 * @param currencyName		Buffer to store the currency name in.
 * @param maxLength			Maximum length of string buffer.
 *
 * @noreturn
 */
native Store_GetCurrencyName(String:currencyName[], maxLength);

public SharedPlugin:__pl_store =
{
	name = "store",
	file = "store-core.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if defined REQUIRE_PLUGIN
public __pl_store_SetNTVOptional()
{
	MarkNativeAsOptional("Store_OpenMainMenu");
	MarkNativeAsOptional("Store_AddMainMenuItem");
	MarkNativeAsOptional("Store_GetCurrencyName");
}
#endif