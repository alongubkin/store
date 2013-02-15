#pragma semicolon 1

#include <sourcemod>
#include <store/store-core>
#include <store/store-backend>
#include <store/store-logging>
#include <store/store-inventory>
#include <store/store-loadout>

new String:g_currencyName[64];
new String:g_menuCommands[32][32];

new Float:g_refundPricePercentage;
new bool:g_confirmItemRefund = true;

public Plugin:myinfo =
{
	name        = "[Store] Refund",
	author      = "alongub",
	description = "Refund component for [Store]",
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

	Store_AddMainMenuItem("Refund", "Refund Description", _, OnMainMenuRefundClick, 6);
	
	RegConsoleCmd("sm_refund", Command_OpenRefund);

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
	BuildPath(Path_SM, path, sizeof(path), "configs/store/refund.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	decl String:menuCommands[255];
	KvGetString(kv, "refund_commands", menuCommands, sizeof(menuCommands));
	ExplodeString(menuCommands, " ", g_menuCommands, sizeof(g_menuCommands), sizeof(g_menuCommands[]));
	
	g_refundPricePercentage = KvGetFloat(kv, "refund_price_percentage", 0.5);
	g_confirmItemRefund = bool:KvGetNum(kv, "confirm_item_refund", 1);

	CloseHandle(kv);
}

public OnMainMenuRefundClick(client, const String:value[])
{
	OpenRefundMenu(client);
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
			OpenRefundMenu(client);
			
			if (text[0] == 0x2F)
				return Plugin_Handled;
			
			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

public Action:Command_OpenRefund(client, args)
{
	OpenRefundMenu(client);
	return Plugin_Handled;
}

/**
 * Opens the refund menu for a client.
 *
 * @param client			Client index.
 *
 * @noreturn
 */
OpenRefundMenu(client)
{
	Store_GetCategories(GetCategoriesCallback, true, GetClientSerial(client));
}

public GetCategoriesCallback(ids[], count, any:serial)
{		
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	new Handle:menu = CreateMenu(RefundMenuSelectHandle);
	SetMenuTitle(menu, "%T\n \n", "Refund", client);
	
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

public RefundMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:categoryIndex[64];
		
		if (GetMenuItem(menu, slot, categoryIndex, sizeof(categoryIndex)))
			OpenRefundCategory(client, StringToInt(categoryIndex));
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
 * Opens the refund menu for a client in a specific category.
 *
 * @param client			Client index.
 * @param categoryId		The category that you want to open.
 *
 * @noreturn
 */
OpenRefundCategory(client, categoryId, slot = 0)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientSerial(client));
	WritePackCell(pack, categoryId);
	WritePackCell(pack, slot);

	new Handle:filter = CreateTrie();
	SetTrieValue(filter, "is_refundable", 1);
	SetTrieValue(filter, "category_id", categoryId);

	Store_GetUserItems(filter, Store_GetClientAccountID(client), Store_GetClientLoadout(client), GetUserItemsCallback, pack);
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
		OpenRefundMenu(client);
		
		return;
	}
	
	decl String:categoryDisplayName[64];
	Store_GetCategoryDisplayName(categoryId, categoryDisplayName, sizeof(categoryDisplayName));
		
	new Handle:menu = CreateMenu(RefundCategoryMenuSelectHandle);
	SetMenuTitle(menu, "%T - %s\n \n", "Refund", client, categoryDisplayName);
	
	for (new item = 0; item < count; item++)
	{
		// TODO: Option to display descriptions	
		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(ids[item], displayName, sizeof(displayName));
		
		new String:text[4 + sizeof(displayName) + 6];
		Format(text, sizeof(text), "%s%s", text, displayName);
		
		if (itemCount[item] > 1)
			Format(text, sizeof(text), "%s (%d)", text, itemCount[item]);
		
		Format(text, sizeof(text), "%s - %d %s", text, RoundToZero(Store_GetItemPrice(ids[item]) * g_refundPricePercentage), g_currencyName);

		decl String:value[8];
		IntToString(ids[item], value, sizeof(value));
		
		AddMenuItem(menu, value, text);    
	}

	SetMenuExitBackButton(menu, true);
	
	if (slot == 0)
		DisplayMenu(menu, client, 0);   
	else
		DisplayMenuAtItem(menu, client, slot, 0); 
}

public RefundCategoryMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:itemId[12];
		if (GetMenuItem(menu, slot, itemId, sizeof(itemId)))
		{
			if (g_confirmItemRefund)
			{
				DisplayConfirmationMenu(client, StringToInt(itemId));
			}
			else
			{			
				Store_RemoveUserItem(Store_GetClientAccountID(client), StringToInt(itemId), OnRemoveUserItemComplete, GetClientSerial(client));
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		OpenRefundMenu(client);
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
	SetMenuTitle(menu, "%T", "Item Refund Confirmation", client, displayName, RoundToZero(Store_GetItemPrice(itemId) * g_refundPricePercentage), g_currencyName);

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
		new String:itemId[12];
		if (GetMenuItem(menu, slot, itemId, sizeof(itemId)))
		{
			if (StrEqual(itemId, "no"))
			{
				OpenRefundMenu(client);
			}
			else
			{
				Store_RemoveUserItem(Store_GetClientAccountID(client), StringToInt(itemId), OnRemoveUserItemComplete, GetClientSerial(client));
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		OpenRefundMenu(client);
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

public OnRemoveUserItemComplete(accountId, itemId, any:serial)
{
	new client = GetClientFromSerial(serial);

	if (client == 0)
		return;

	new credits = RoundToZero(Store_GetItemPrice(itemId) * g_refundPricePercentage);

	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientSerial(client));
	WritePackCell(pack, credits);
	WritePackCell(pack, itemId);

	Store_GiveCredits(accountId, credits, OnGiveCreditsComplete, pack);
}

public OnGiveCreditsComplete(accountId, any:pack)
{
	ResetPack(pack);

	new serial = ReadPackCell(pack);
	new credits = ReadPackCell(pack);
	new itemId = ReadPackCell(pack);

	CloseHandle(pack);

	new client = GetClientFromSerial(serial);
	if (client == 0)
		return;

	decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
	PrintToChat(client, "%s%t", STORE_PREFIX, "Refund Message", displayName, credits, g_currencyName);

	OpenRefundMenu(client);
}