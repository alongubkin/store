#if defined _store_inventory_included
  #endinput
#endif
#define _store_inventory_included

functag Store_ItemGetAttributesCallback public(const String:itemName[], const String:attrs[]);
functag Store_ItemUseCallback bool:public(client, itemId, bool:equipped);

native Store_OpenInventory(client);
native Store_OpenInventoryCategory(client, categoryId);

native Store_RegisterItemType(const String:type[], Store_ItemUseCallback:useCallback, Store_ItemGetAttributesCallback:attrsCallback = 0);
native bool:Store_IsItemTypeRegistered(const String:type[]);

native bool:Store_CallItemAttrsCallback(const String:type[], const String:itemName[], const String:attrs[]);

public SharedPlugin:__pl_inventory_store =
{
    name = "store-inventory",
    file = "store-inventory.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if defined REQUIRE_PLUGIN
public __pl_store_inventory_SetNTVOptional()
{
	MarkNativeAsOptional("Store_OpenInventory");  
	MarkNativeAsOptional("Store_OpenInventoryCategory");  	
	
	MarkNativeAsOptional("Store_RegisterItemType"); 
	MarkNativeAsOptional("Store_IsItemTypeRegistered");
	
	MarkNativeAsOptional("Store_CallItemAttrsCallback");
}
#endif