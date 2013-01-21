#include <sourcemod>
#include <store/store-core>
#include <store/store-database>
#include <store/store-logging>
#include <store/store-inventory>

new String:g_currencyName[64];
new String:g_menuCommands[32][32];

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("Store_OpenShop", Native_OpenShop);
	CreateNative("Store_OpenShopCategory", Native_OpenShopCategory);
	
	RegPluginLibrary("store-shop");	
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadConfig();
	Store_AddMainMenuItem("Shop", _, _, OnMainMenuShopClick, 2);
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

public OnConfigsExecuted()
{    
	Store_GetCurrencyName(g_currencyName, sizeof(g_currencyName));
}

LoadConfig() 
{
	new Handle:kv = CreateKeyValues("root");
	
	decl String:path[100];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/shop.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	decl String:menuCommands[255];
	KvGetString(kv, "shop_commands", menuCommands, sizeof(menuCommands));
	
	ExplodeString(menuCommands, " ", g_menuCommands, sizeof(g_menuCommands), sizeof(g_menuCommands[]));
	
	CloseHandle(kv);
}

public OnMainMenuShopClick(client, const String:value[])
{
	OpenShop(client);
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
			OpenShop(client);
			
			if (text[0] == 0x2F)
				return Plugin_Handled;
			
			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

OpenShop(client)
{
	Store_GetCategories(GetCategoriesCallback, true, GetClientSerial(client));
}

public GetCategoriesCallback(ids[], count, any:serial)
{		
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	new Handle:menu = CreateMenu(ShopMenuSelectHandle);
	SetMenuTitle(menu, "Shop\n \n");
	
	for (new category = 0; category < count; category++)
	{
		decl String:requiredPlugin[32];
		Store_GetCategoryPluginRequired(ids[category], requiredPlugin, sizeof(requiredPlugin));
		
		new typeIndex;
		if (!Store_IsItemTypeRegistered(requiredPlugin))
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

public ShopMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:categoryIndex[64];
		
		if (GetMenuItem(menu, slot, categoryIndex, sizeof(categoryIndex)))
			OpenShopCategory(client, StringToInt(categoryIndex));
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

OpenShopCategory(client, categoryId)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientSerial(client));
	WritePackCell(pack, categoryId);
	
	Store_GetItems(GetItemsCallback, categoryId, true, pack);
}

public GetItemsCallback(ids[], count, any:pack)
{	
	ResetPack(pack);
	
	new serial = ReadPackCell(pack);
	new categoryId = ReadPackCell(pack);
	
	CloseHandle(pack);
	
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
	
	if (count == 0)
	{
		PrintToChat(client, "There are no items in this category.");
		OpenShop(client);
		
		return;
	}
	
	decl String:categoryDisplayName[64];
	Store_GetCategoryDisplayName(categoryId, categoryDisplayName, sizeof(categoryDisplayName));
		
	new Handle:menu = CreateMenu(ShopCategoryMenuSelectHandle);
	SetMenuTitle(menu, "Shop - %s\n \n", categoryDisplayName);

	for (new item = 0; item < count; item++)
	{		
		decl String:displayName[64];
		Store_GetItemDisplayName(ids[item], displayName, sizeof(displayName));
		
		decl String:description[128];
		Store_GetItemDescription(ids[item], description, sizeof(description));
	
		decl String:text[sizeof(displayName) + sizeof(description) + 5];
		Format(text, sizeof(text), "%s [%d %s]\n%s", displayName, Store_GetItemPrice(ids[item]), g_currencyName, description);
		
		decl String:value[8];
		IntToString(ids[item], value, sizeof(value));
		
		AddMenuItem(menu, value, text);    
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 30);   
}

public ShopCategoryMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:itemId[12];

		if (GetMenuItem(menu, slot, itemId, sizeof(itemId)))
		{
			Store_BuyItem(Store_GetClientAccountID(client), StringToInt(itemId), OnBuyItemComplete, GetClientSerial(client));
		}
	}
	else if (action == MenuAction_Cancel)
	{
		OpenShop(client);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public OnBuyItemComplete(bool:success, any:serial)
{
	// TODO: Colored errors here.
	// PrintToChat(client, message);
	
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
	
	if (!success)
	{
		PrintToChat(client, "You don't have enough credits to buy this item.");
	}
	
	OpenShop(client);
}

public Native_OpenShop(Handle:plugin, params)
{       
	OpenShop(GetNativeCell(1));
}

public Native_OpenShopCategory(Handle:plugin, params)
{       
	OpenShopCategory(GetNativeCell(1), GetNativeCell(2));
}
