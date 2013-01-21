#include <sourcemod>
#include <store/store-core>
#include <store/store-database>
#include <store/store-logging>
#include <store/store-loadout>

new String:g_menuCommands[32][32];

new Handle:g_itemTypes;
new Handle:g_itemTypeNameIndex;

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

public OnPluginStart()
{
	LoadConfig();
	Store_AddMainMenuItem("Inventory", _, _, OnMainMenuInventoryClick, 4);
	
	/*g_itemTypes = CreateArray();
	g_itemTypeNameIndex = CreateTrie();*/
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

LoadConfig() 
{
	new Handle:kv = CreateKeyValues("root");
	
	decl String:path[100];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/inventory.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	decl String:menuCommands[255];
	KvGetString(kv, "inventory_commands", menuCommands, sizeof(menuCommands));
	
	ExplodeString(menuCommands, " ", g_menuCommands, sizeof(g_menuCommands), sizeof(g_menuCommands[]));
		
	CloseHandle(kv);
}

public OnMainMenuInventoryClick(client, const String:value[])
{
	OpenInventory(client);
}

public Action:Command_Say(client, const String:command[], args)
{
	if (0 < client <= MaxClients && !IsClientInGame(client)) 
		return Plugin_Continue;   
	
	decl String:text[256];
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	
	for (new index = 0; index < sizeof(g_menuCommands); index++) 
	{
		if (StrEqual(g_menuCommands[index], text))
		{
			OpenInventory(client);
			
			if (text[0] == 0x2F)
				return Plugin_Handled;
			
			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

OpenInventory(client)
{
	Store_GetCategories(GetCategoriesCallback, true, GetClientSerial(client));
}

public GetCategoriesCallback(ids[], count, any:serial)
{	
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
	
	new Handle:menu = CreateMenu(InventoryMenuSelectHandle);
	SetMenuTitle(menu, "Inventory\n \n");
		
	for (new category = 0; category < count; category++)
	{
		decl String:requiredPlugin[32];
		Store_GetCategoryPluginRequired(ids[category], requiredPlugin, sizeof(requiredPlugin));
		
		new typeIndex;
		if (!GetTrieValue(g_itemTypeNameIndex, requiredPlugin, typeIndex))
			continue;
		
		decl String:displayName[64];
		Store_GetCategoryDisplayName(ids[category], displayName, sizeof(displayName));

		decl String:description[128];
		Store_GetCategoryDescription(ids[category], description, sizeof(description));
		
		decl String:itemText[sizeof(displayName) + 1 + sizeof(description)];
		Format(itemText, sizeof(itemText), "%s\n%s", displayName, description);
		
		decl String:itemValue[8];
		IntToString(ids[category], itemValue, sizeof(itemValue));
		
		AddMenuItem(menu, itemValue, itemText);
	}
	
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 30);
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

OpenInventoryCategory(client, categoryId, slot = 0)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientSerial(client));
	WritePackCell(pack, categoryId);
	WritePackCell(pack, slot);
	
	Store_GetUserItems(Store_GetClientAccountID(client), categoryId, Store_GetClientLoadout(client), GetUserItemsCallback, pack);
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
		PrintToChat(client, "You don't have any items in this category.");
		OpenInventory(client);
		
		return;
	}
	
	decl String:categoryDisplayName[64];
	Store_GetCategoryDisplayName(categoryId, categoryDisplayName, sizeof(categoryDisplayName));
		
	new Handle:menu = CreateMenu(InventoryCategoryMenuSelectHandle);
	SetMenuTitle(menu, "Inventory - %s\n \n", categoryDisplayName);
	
	for (new item = 0; item < count; item++)
	{
		// TODO: Option to display descriptions	
		decl String:displayName[64];
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
		DisplayMenu(menu, client, 30);   
	else
		DisplayMenuAtItem(menu, client, slot, 30);
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
			
			decl String:name[32];
			Store_GetItemName(id, name, sizeof(name));
			
			decl String:type[32];
			Store_GetItemType(id, type, sizeof(type));
			
			decl String:loadoutSlot[32];
			Store_GetItemLoadoutSlot(id, loadoutSlot, sizeof(loadoutSlot));
			
			new itemTypeIndex = -1;
			GetTrieValue(g_itemTypeNameIndex, type, itemTypeIndex);
			
			if (itemTypeIndex == -1)
			{
				PrintToChat(client, "The item type '%s' wasn't registered by any plugin.", type);
				Store_LogWarning("The item type '%s' wasn't registered by any plugin.", type);
				
				OpenInventoryCategory(client, Store_GetItemCategory(id));
				
				return;
			}
			
			new bool:callbackValue = false;
			
			new Handle:itemType = GetArrayCell(g_itemTypes, itemTypeIndex);
			ResetPack(itemType);
			
			new Handle:plugin = Handle:ReadPackCell(itemType);
			new callback = ReadPackCell(itemType);
		
			Call_StartFunction(plugin, Function:callback);
			Call_PushCell(client);
			Call_PushCell(id);
			Call_PushCell(equipped);
			Call_Finish(callbackValue);
			
			if (callbackValue)
			{
				new auth = Store_GetClientAccountID(client);
				
				new Handle:pack = CreateDataPack();
				WritePackCell(pack, GetClientSerial(client));
				WritePackCell(pack, slot);
				
				if (StrEqual(loadoutSlot, ""))
				{
					Store_UseItem(auth, id, UseItemCallback, pack);
				}
				else
				{
					if (equipped)
						Store_UnequipItem(auth, id, Store_GetClientLoadout(client), EquipItemCallback, pack);
					else
						Store_EquipItem(auth, id, Store_GetClientLoadout(client), EquipItemCallback, pack);
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

RegisterItemType(const String:type[], Handle:plugin, Store_ItemUseCallback:useCallback, Store_ItemGetAttributesCallback:attrsCallback = 0)
{
	if (g_itemTypes == INVALID_HANDLE)
	{
		g_itemTypes = CreateArray();
	}
	
	if (g_itemTypeNameIndex == INVALID_HANDLE)
		g_itemTypeNameIndex = CreateTrie();
		
	new Handle:itemType = CreateDataPack();
	WritePackCell(itemType, _:plugin);
	WritePackCell(itemType, _:useCallback);
	WritePackCell(itemType, _:attrsCallback);

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
	decl String:type[32];
	GetNativeString(1, type, sizeof(type));
	
	RegisterItemType(type, plugin, Store_ItemUseCallback:GetNativeCell(2), Store_ItemGetAttributesCallback:GetNativeCell(3));
}

public Native_IsItemTypeRegistered(Handle:plugin, params)
{
	decl String:type[32];
	GetNativeString(1, type, sizeof(type));
	
	new typeIndex;
	return GetTrieValue(g_itemTypeNameIndex, type, typeIndex);
}

public Native_CallItemAttrsCallback(Handle:plugin, params)
{       
	if (g_itemTypeNameIndex == INVALID_HANDLE)
		return false;
		
	decl String:type[32];
	GetNativeString(1, type, sizeof(type));
	
	new typeIndex;
	if (!GetTrieValue(g_itemTypeNameIndex, type, typeIndex))
		return false;
	
	decl String:name[32];
	GetNativeString(2, name, sizeof(name));
	
	decl String:attrs[1024];
	GetNativeString(3, attrs, sizeof(attrs));		

	new Handle:pack = GetArrayCell(g_itemTypes, typeIndex);
	ResetPack(pack);
	
	new Handle:callbackPlugin = Handle:ReadPackCell(pack);
	ReadPackCell(pack);
	
	new callback = ReadPackCell(pack);

	if (callback == 0)
		return false;

	Call_StartFunction(callbackPlugin, Function:callback);
	Call_PushString(name);
	Call_PushString(attrs);
	Call_Finish();	
	
	return true;
}
