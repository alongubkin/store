#if defined _store_loadout_included
  #endinput
#endif
#define _store_loadout_included

native Store_GetClientLoadout(client);

public SharedPlugin:__pl_loadout_store =
{
    name = "store-loadout",
    file = "store-loadout.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if defined REQUIRE_PLUGIN
public __pl_store_loadout_SetNTVOptional()
{
	MarkNativeAsOptional("Store_GetClientLoadout");  
}
#endif