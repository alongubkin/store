#pragma semicolon 1

#include <sourcemod>
#include <store/store-core>
#include <store/store-backend>
#include <store/store-logging>
#include <store/store-inventory>
#include <colors>

new String:g_currencyName[64];
new String:g_menuCommands[32][32];

new bool:g_confirmItemPurchase = false;

new Handle:g_buyItemForward;

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
	CreateNative("Store_OpenShop", Native_OpenShop);
	CreateNative("Store_OpenShopCategory", Native_OpenShopCategory);
	
	RegPluginLibrary("store-shop");	
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name        = "[Store] Shop",
	author      = "alongub",
	description = "Shop component for [Store]",
	version     = STORE_VERSION,
	url         = "https://github.com/alongubkin/store"
};

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
	LoadConfig();

	g_buyItemForward = CreateGlobalForward("Store_OnBuyItem", ET_Event, Param_Cell, Param_Cell, Param_Cell);

	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	Store_AddMainMenuItem("Shop", "Shop Description", _, OnMainMenuShopClick, 2);
	
	RegConsoleCmd("sm_shop", Command_OpenShop);

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

/**
 * Configs just finished getting executed.
 */
public OnConfigsExecuted()
{    
	Store_GetCurrencyName(g_currencyName, sizeof(g_currencyName));
}

/**
 * Load plugin config.
 */
LoadConfig() 
{
	new Handle:kv = CreateKeyValues("root");
	
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/shop.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	decl String:menuCommands[255];
	KvGetString(kv, "shop_commands", menuCommands, sizeof(menuCommands));
	ExplodeString(menuCommands, " ", g_menuCommands, sizeof(g_menuCommands), sizeof(g_menuCommands[]));
	
	g_confirmItemPurchase = bool:KvGetNum(kv, "confirm_item_purchase", 0);

	CloseHandle(kv);
}

public OnMainMenuShopClick(client, const String:value[])
{
	OpenShop(client);
}

/**
 * Called when a client has typed a message to the chat.
 *
 * @param client		Client index.
 * @param command		Command name, lower case.
 * @param args          Argument count. 
 *
 * @return				Action to take.
 */
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

public Action:Command_OpenShop(client, args)
{
	OpenShop(client);
	return Plugin_Handled;
}

/**
 * Opens the shop menu for a client.
 *
 * @param client			Client index.
 *
 * @noreturn
 */
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
	SetMenuTitle(menu, "%T\n \n", "Shop", client);
	
	for (new category = 0; category < count; category++)
	{
		decl String:requiredPlugin[STORE_MAX_REQUIREPLUGIN_LENGTH];
		Store_GetCategoryPluginRequired(ids[category], requiredPlugin, sizeof(requiredPlugin));
		
		if (!StrEqual(requiredPlugin, "") && !Store_IsItemTypeRegistered(requiredPlugin))
			continue;
			
		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetCategoryDisplayName(ids[category], displayName, sizeof(displayName));

		decl String:description[STORE_MAX_DESCRIPTION_LENGTH];
		Store_GetCategoryDescription(ids[category], description, sizeof(description));

		decl String:itemText[sizeof(displayName) + 1 + sizeof(description)];
		Format(itemText, sizeof(itemText), "%s\n%s", displayName, description);
		
		decl String:itemValue[8];
		IntToString(ids[category], itemValue, sizeof(itemValue));
		
		AddMenuItem(menu, itemValue, itemText);
	}
	
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 0);
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

/**
 * Opens the shop menu for a client in a specific category.
 *
 * @param client			Client index.
 * @param categoryId		The category that you want to open.
 *
 * @noreturn
 */
OpenShopCategory(client, categoryId)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientSerial(client));
	WritePackCell(pack, categoryId);
	
	new Handle:filter = CreateTrie();
	SetTrieValue(filter, "is_buyable", 1);
	SetTrieValue(filter, "category_id", categoryId);

	Store_GetItems(filter, GetItemsCallback, true, pack);
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
		PrintToChat(client, "%s%t", STORE_PREFIX, "No items in this category");
		OpenShop(client);
		
		return;
	}
	
	decl String:categoryDisplayName[64];
	Store_GetCategoryDisplayName(categoryId, categoryDisplayName, sizeof(categoryDisplayName));
		
	new Handle:menu = CreateMenu(ShopCategoryMenuSelectHandle);
	SetMenuTitle(menu, "%T - %s\n \n", "Shop", client, categoryDisplayName);

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
	DisplayMenu(menu, client, 0);   
}

public ShopCategoryMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:value[12];

		if (GetMenuItem(menu, slot, value, sizeof(value)))
		{
			new itemId = StringToInt(value);
		
			if (g_confirmItemPurchase)
			{
				DisplayConfirmationMenu(client, itemId);
			}
			else
			{
				new Handle:pack = CreateDataPack();
				WritePackCell(pack, GetClientSerial(client));
				WritePackCell(pack, itemId);
				Store_BuyItem(Store_GetClientAccountID(client), itemId, OnBuyItemComplete, pack);
			}
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

DisplayConfirmationMenu(client, itemId)
{
	decl String:displayName[64];
	Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));

	new Handle:menu = CreateMenu(ConfirmationMenuSelectHandle);
	SetMenuTitle(menu, "%T", "Item Purchase Confirmation", client,  displayName);

	decl String:value[8];
	IntToString(itemId, value, sizeof(value));

	AddMenuItem(menu, value, "Yes");
	AddMenuItem(menu, "no", "No");

	SetMenuExitButton(menu, false);
	DisplayMenu(menu, client, 0);  
}

public ConfirmationMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:value[12];
		if (GetMenuItem(menu, slot, value, sizeof(value)))
		{
			if (StrEqual(value, "no"))
			{
				OpenShop(client);
			}
			else
			{
				new itemId = StringToInt(value);

				new Handle:pack = CreateDataPack();
				WritePackCell(pack, GetClientSerial(client));
				WritePackCell(pack, itemId);

				Store_BuyItem(Store_GetClientAccountID(client), itemId, OnBuyItemComplete, pack);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		OpenShop(client);
	}
	else if (action == MenuAction_DisplayItem) 
	{
		decl String:display[64];
		GetMenuItem(menu, slot, "", 0, _, display, sizeof(display));

		decl String:buffer[255];
		Format(buffer, sizeof(buffer), "%T", display, client);

		return RedrawMenuItem(buffer);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}

	return false;
}

public OnBuyItemComplete(bool:success, any:pack)
{
	ResetPack(pack);

	new client = GetClientFromSerial(ReadPackCell(pack));
	if (client == 0)
	{
		CloseHandle(pack);
		return;
	}

	new itemId = ReadPackCell(pack);

	if (success)
	{
		decl String:displayName[64];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));

		CPrintToChat(client, "%s%t", STORE_PREFIX, "Item Purchase Successful", displayName);
	}
	else
	{
		CPrintToChat(client, "%s%t", STORE_PREFIX, "Not enough credits to buy", g_currencyName);
	}

	Call_StartForward(g_buyItemForward);
	Call_PushCell(client);
	Call_PushCell(itemId);
	Call_PushCell(success);
	Call_Finish();
	
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