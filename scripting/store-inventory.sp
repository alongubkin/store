#pragma semicolon 1

#include <sourcemod>
#include <store/store-core>
#include <store/store-backend>
#include <store/store-inventory>
#include <store/store-logging>
#include <store/store-loadout>

new bool:g_hideEmptyCategories = false;

new Handle:g_itemTypes;
new Handle:g_itemTypeNameIndex;

new Handle:categories_menu[MAXPLAYERS+1];

/**
 * Called before plugin is loaded.
 * 
 * @param myself    The plugin handle.
 * @param late      True if the plugin was loaded after map change, false on map start.
 * @param error     Error message if load failed.
 * @param err_max   Max length of the error message.
 *
 * @return          APLRes_Success for load success, APLRes_Failure or APLRes_SilentFailure otherwise.
 */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("Store_OpenInventory", Native_OpenInventory);
	CreateNative("Store_OpenInventoryCategory", Native_OpenInventoryCategory);
	
	CreateNative("Store_RegisterItemType", Native_RegisterItemType);
	CreateNative("Store_IsItemTypeRegistered", Native_IsItemTypeRegistered);
	
	CreateNative("Store_CallItemAttrsCallback", Native_CallItemAttrsCallback);
	
	RegPluginLibrary("store-inventory");	
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name        = "[Store] Inventory",
	author      = "alongub",
	description = "Inventory component for [Store]",
	version     = STORE_VERSION,
	url         = "https://github.com/alongubkin/store"
};

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
	LoadConfig();

	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	Store_AddMainMenuItem("Inventory", "Inventory Description", _, OnMainMenuInventoryClick, 4);

	RegAdminCmd("store_itemtypes", Command_PrintItemTypes, ADMFLAG_RCON, "Prints registered item types");
}

/**
 * Load plugin config.
 */
LoadConfig() 
{
	new Handle:kv = CreateKeyValues("root");
	
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/inventory.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	decl String:menuCommands[255];
	KvGetString(kv, "inventory_commands", menuCommands, sizeof(menuCommands), "!inventory /inventory !inv /inv");
	Store_RegisterChatCommands(menuCommands, ChatCommand_OpenInventory);

	g_hideEmptyCategories = bool:KvGetNum(kv, "hide_empty_categories", 0);
		
	CloseHandle(kv);
}

public OnMainMenuInventoryClick(client, const String:value[])
{
	OpenInventory(client);
}

public ChatCommand_OpenInventory(client)
{
	OpenInventory(client);
}

public Action:Command_PrintItemTypes(client, args)
{
	for (new itemTypeIndex = 0, size = GetArraySize(g_itemTypes); itemTypeIndex < size; itemTypeIndex++)
	{
		new Handle:itemType = Handle:GetArrayCell(g_itemTypes, itemTypeIndex);
		
		ResetPack(itemType);
		new Handle:plugin = Handle:ReadPackCell(itemType);

		SetPackPosition(itemType, 24);
		decl String:typeName[32];
		ReadPackString(itemType, typeName, sizeof(typeName));

		ResetPack(itemType);

		decl String:pluginName[32];
		GetPluginFilename(plugin, pluginName, sizeof(pluginName));

		ReplyToCommand(client, " \"%s\" - %s", typeName, pluginName);			
	}

	return Plugin_Handled;
}

/**
* Opens the inventory menu for a client.
*
* @param client			Client index.
*
* @noreturn
*/
OpenInventory(client)
{
	if (client <= 0 || client > MaxClients)
		return;

	if (!IsClientInGame(client))
		return;

	if (categories_menu[client] != INVALID_HANDLE) {
		return;
	}

	Store_GetCategories(GetCategoriesCallback, true, GetClientSerial(client));
}

public GetCategoriesCallback(ids[], count, any:serial)
{	
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
	
	categories_menu[client] = CreateMenu(InventoryMenuSelectHandle);
	SetMenuTitle(categories_menu[client], "%T\n \n", "Inventory", client);
		
	for (new category = 0; category < count; category++)
	{
		decl String:requiredPlugin[STORE_MAX_REQUIREPLUGIN_LENGTH];
		Store_GetCategoryPluginRequired(ids[category], requiredPlugin, sizeof(requiredPlugin));
		
		new typeIndex;
		if (!StrEqual(requiredPlugin, "") && !GetTrieValue(g_itemTypeNameIndex, requiredPlugin, typeIndex))
			continue;

		new Handle:pack = CreateDataPack();
		WritePackCell(pack, GetClientSerial(client));
		WritePackCell(pack, ids[category]);
		WritePackCell(pack, count - category - 1);
		
		new Handle:filter = CreateTrie();
		SetTrieValue(filter, "category_id", ids[category]);
		SetTrieValue(filter, "flags", GetUserFlagBits(client));

		Store_GetUserItems(filter, GetSteamAccountID(client), Store_GetClientLoadout(client), GetItemsForCategoryCallback, pack);
	}
}

public GetItemsForCategoryCallback(ids[], bool:equipped[], itemCount[], count, loadoutId, any:pack)
{
	ResetPack(pack);
	
	new serial = ReadPackCell(pack);
	new categoryId = ReadPackCell(pack);
	new left = ReadPackCell(pack);
	
	CloseHandle(pack);
	
	new client = GetClientFromSerial(serial);
	
	if (client <= 0)
		return;

	if (g_hideEmptyCategories && count <= 0)
	{
		if (left == 0)
		{
			SetMenuExitBackButton(categories_menu[client], true);
			DisplayMenu(categories_menu[client], client, 0);
			categories_menu[client] = INVALID_HANDLE;
		}
		return;
	}

	decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	Store_GetCategoryDisplayName(categoryId, displayName, sizeof(displayName));

	//PrintToChatAll("%s %i %i %i", displayName, g_hideEmptyCategories, count, left);

	//decl String:description[STORE_MAX_DESCRIPTION_LENGTH];
	//Store_GetCategoryDescription(categoryId, description, sizeof(description));

	//decl String:itemText[sizeof(displayName) + 1 + sizeof(description)];
	//Format(itemText, sizeof(itemText), "%s\n%s", displayName, description);
	
	decl String:itemValue[8];
	IntToString(categoryId, itemValue, sizeof(itemValue));
	
	AddMenuItem(categories_menu[client], itemValue, displayName);

	if (left == 0)
	{
		SetMenuExitBackButton(categories_menu[client], true);
		DisplayMenu(categories_menu[client], client, 0);
		categories_menu[client] = INVALID_HANDLE;
	}
}

public InventoryMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:categoryIndex[64];
		
		if (GetMenuItem(menu, slot, categoryIndex, sizeof(categoryIndex)))
			OpenInventoryCategory(client, StringToInt(categoryIndex));
	}
	else if (action == MenuAction_Cancel)
	{
		if (slot == MenuCancel_ExitBack)
		{
			Store_OpenMainMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

/**
* Opens the inventory menu for a client in a specific category.
*
* @param client			Client index.
* @param categoryId		The category that you want to open.
*
* @noreturn
*/
OpenInventoryCategory(client, categoryId, slot = 0)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientSerial(client));
	WritePackCell(pack, categoryId);
	WritePackCell(pack, slot);
	
	new Handle:filter = CreateTrie();
	SetTrieValue(filter, "category_id", categoryId);
	SetTrieValue(filter, "flags", GetUserFlagBits(client));

	Store_GetUserItems(filter, GetSteamAccountID(client), Store_GetClientLoadout(client), GetUserItemsCallback, pack);
}

public GetUserItemsCallback(ids[], bool:equipped[], itemCount[], count, loadoutId, any:pack)
{
	ResetPack(pack);
	
	new serial = ReadPackCell(pack);
	new categoryId = ReadPackCell(pack);
	new slot = ReadPackCell(pack);
	
	CloseHandle(pack);
	
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	if (count == 0)
	{
		PrintToChat(client, "%s%t", STORE_PREFIX, "No items in this category");
		OpenInventory(client);
		
		return;
	}
	
	decl String:categoryDisplayName[64];
	Store_GetCategoryDisplayName(categoryId, categoryDisplayName, sizeof(categoryDisplayName));
		
	new Handle:menu = CreateMenu(InventoryCategoryMenuSelectHandle);
	SetMenuTitle(menu, "%T - %s\n \n", "Inventory", client, categoryDisplayName);
	
	for (new item = 0; item < count; item++)
	{
		// TODO: Option to display descriptions	
		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(ids[item], displayName, sizeof(displayName));
		
		new String:text[4 + sizeof(displayName) + 6];
		
		if (equipped[item])
			strcopy(text, sizeof(text), "[E] ");
		
		Format(text, sizeof(text), "%s%s", text, displayName);
		
		if (itemCount[item] > 1)
			Format(text, sizeof(text), "%s (%d)", text, itemCount[item]);
			
		decl String:value[16];
		Format(value, sizeof(value), "%b,%d", equipped[item], ids[item]);
		
		AddMenuItem(menu, value, text);
	}

	SetMenuExitBackButton(menu, true);
	
	if (slot == 0)
		DisplayMenu(menu, client, 0);   
	else
		DisplayMenuAtItem(menu, client, slot, 0);

	categories_menu[client] = INVALID_HANDLE;
}

public InventoryCategoryMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:value[16];

		if (GetMenuItem(menu, slot, value, sizeof(value)))
		{
			decl String:buffers[2][16];
			ExplodeString(value, ",", buffers, sizeof(buffers), sizeof(buffers[]));
			
			new bool:equipped = bool:StringToInt(buffers[0]);
			new id = StringToInt(buffers[1]);
			
			decl String:name[STORE_MAX_NAME_LENGTH];
			Store_GetItemName(id, name, sizeof(name));
			
			decl String:type[STORE_MAX_TYPE_LENGTH];
			Store_GetItemType(id, type, sizeof(type));
			
			decl String:loadoutSlot[STORE_MAX_LOADOUTSLOT_LENGTH];
			Store_GetItemLoadoutSlot(id, loadoutSlot, sizeof(loadoutSlot));
			
			new itemTypeIndex = -1;
			GetTrieValue(g_itemTypeNameIndex, type, itemTypeIndex);
			
			if (itemTypeIndex == -1)
			{
				PrintToChat(client, "%s%t", STORE_PREFIX, "Item type not registered", type);
				Store_LogWarning("The item type '%s' wasn't registered by any plugin.", type);
				
				OpenInventoryCategory(client, Store_GetItemCategory(id));
				
				return;
			}
			
			new Store_ItemUseAction:callbackValue = Store_DoNothing;
			
			new Handle:itemType = GetArrayCell(g_itemTypes, itemTypeIndex);
			ResetPack(itemType);
			
			new Handle:plugin = Handle:ReadPackCell(itemType);
			new callback = ReadPackCell(itemType);
		
			Call_StartFunction(plugin, Function:callback);
			Call_PushCell(client);
			Call_PushCell(id);
			Call_PushCell(equipped);
			Call_Finish(callbackValue);
			
			if (callbackValue != Store_DoNothing)
			{
				new auth = GetSteamAccountID(client);
					
				new Handle:pack = CreateDataPack();
				WritePackCell(pack, GetClientSerial(client));
				WritePackCell(pack, slot);

				if (callbackValue == Store_EquipItem)
				{
					if (StrEqual(loadoutSlot, ""))
					{
						Store_LogWarning("A user tried to equip an item that doesn't have a loadout slot.");
					}
					else
					{
						Store_SetItemEquippedState(auth, id, Store_GetClientLoadout(client), true, EquipItemCallback, pack);
					}
				}
				else if (callbackValue == Store_UnequipItem)
				{
					if (StrEqual(loadoutSlot, ""))
					{
						Store_LogWarning("A user tried to unequip an item that doesn't have a loadout slot.");
					}
					else
					{				
						Store_SetItemEquippedState(auth, id, Store_GetClientLoadout(client), false, EquipItemCallback, pack);
					}
				}
				else if (callbackValue == Store_DeleteItem)
				{
					Store_RemoveUserItem(auth, id, UseItemCallback, pack);
				}
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		OpenInventory(client);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public EquipItemCallback(accountId, itemId, loadoutId, any:pack)
{
	ResetPack(pack);
	
	new serial = ReadPackCell(pack);
	// new slot = ReadPackCell(pack);
	
	CloseHandle(pack);
	
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	OpenInventoryCategory(client, Store_GetItemCategory(itemId));
}

public UseItemCallback(accountId, itemId, any:pack)
{
	ResetPack(pack);
	
	new serial = ReadPackCell(pack);
	// new slot = ReadPackCell(pack);
	
	CloseHandle(pack);
	
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	OpenInventoryCategory(client, Store_GetItemCategory(itemId));
}

/**
* Registers an item type. 
*
* A type of an item defines its behaviour. Once you register a type, 
* the store will provide two callbacks for you:
* 	- Use callback: called when a player selects your item in his inventory.
*	- Attributes callback: called when the store loads the attributes of your item (optional).
*
* It is recommended that each plugin registers *one* item type. 
*
* @param type			Item type unique identifer - maximum 32 characters, no whitespaces, lower case only.
* @param plugin			The plugin owner of the callback(s).
* @param useCallback	Called when a player selects your item in his inventory.
* @param attrsCallback	Called when the store loads the attributes of your item.
*
* @noreturn
*/
RegisterItemType(const String:type[], Handle:plugin, Store_ItemUseCallback:useCallback, Store_ItemGetAttributesCallback:attrsCallback = Store_ItemGetAttributesCallback:0)
{
	if (g_itemTypes == INVALID_HANDLE)
		g_itemTypes = CreateArray();
	
	if (g_itemTypeNameIndex == INVALID_HANDLE)
	{
		g_itemTypeNameIndex = CreateTrie();
	}
	else
	{
		new itemType;
		if (GetTrieValue(g_itemTypeNameIndex, type, itemType))
		{
			CloseHandle(Handle:GetArrayCell(g_itemTypes, itemType));
		}
	}

	new Handle:itemType = CreateDataPack();
	WritePackCell(itemType, _:plugin); // 0
	WritePackCell(itemType, _:useCallback); // 8
	WritePackCell(itemType, _:attrsCallback); // 16
	WritePackString(itemType, type); // 24

	new index = PushArrayCell(g_itemTypes, itemType);
	SetTrieValue(g_itemTypeNameIndex, type, index);
}

public Native_OpenInventory(Handle:plugin, params)
{       
	OpenInventory(GetNativeCell(1));
}

public Native_OpenInventoryCategory(Handle:plugin, params)
{       
	OpenInventoryCategory(GetNativeCell(1), GetNativeCell(2));
}

public Native_RegisterItemType(Handle:plugin, params)
{
	decl String:type[STORE_MAX_TYPE_LENGTH];
	GetNativeString(1, type, sizeof(type));
	
	RegisterItemType(type, plugin, Store_ItemUseCallback:GetNativeCell(2), Store_ItemGetAttributesCallback:GetNativeCell(3));
}

public Native_IsItemTypeRegistered(Handle:plugin, params)
{
	decl String:type[STORE_MAX_TYPE_LENGTH];
	GetNativeString(1, type, sizeof(type));
	
	new typeIndex;
	return GetTrieValue(g_itemTypeNameIndex, type, typeIndex);
}

public Native_CallItemAttrsCallback(Handle:plugin, params)
{
	if (g_itemTypeNameIndex == INVALID_HANDLE)
		return false;
		
	decl String:type[STORE_MAX_TYPE_LENGTH];
	GetNativeString(1, type, sizeof(type));

	new typeIndex;
	if (!GetTrieValue(g_itemTypeNameIndex, type, typeIndex))
		return false;

	decl String:name[STORE_MAX_NAME_LENGTH];
	GetNativeString(2, name, sizeof(name));

	decl String:attrs[STORE_MAX_ATTRIBUTES_LENGTH];
	GetNativeString(3, attrs, sizeof(attrs));		

	new Handle:pack = GetArrayCell(g_itemTypes, typeIndex);
	ResetPack(pack);

	new Handle:callbackPlugin = Handle:ReadPackCell(pack);
	
	SetPackPosition(pack, 16);

	new callback = ReadPackCell(pack);

	if (callback == 0)
		return false;

	Call_StartFunction(callbackPlugin, Function:callback);
	Call_PushString(name);
	Call_PushString(attrs);
	Call_Finish();	
	
	return true;
}
