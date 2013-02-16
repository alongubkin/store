#pragma semicolon 1

#include <sourcemod>
#include <adminmenu>
#include <store>
#include <colors>

#define MAX_CREDIT_CHOICES 100

enum GiftType
{
	GiftType_Credits,
	GiftType_Item
}

enum GiftRequest
{
	bool:GiftRequestActive,
	GiftRequestSender,
	GiftType:GiftRequestType,
	GiftRequestValue
}

new String:g_currencyName[64];
new String:g_menuCommands[32][32];

new g_creditChoices[MAX_CREDIT_CHOICES];
new g_giftRequests[MAXPLAYERS+1][GiftRequest];

public Plugin:myinfo =
{
	name        = "[Store] Gifting",
	author      = "alongub",
	description = "Gifting component for [Store]",
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

	Store_AddMainMenuItem("Gift", "Gift Description", _, OnMainMenuGiftClick, 5);
	
	RegConsoleCmd("sm_gift", Command_OpenGifting);
	RegConsoleCmd("sm_accept", Command_Accept);

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	HookEvent("player_disconnect", Event_PlayerDisconnect);
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
	BuildPath(Path_SM, path, sizeof(path), "configs/store/gifting.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	decl String:menuCommands[255];
	KvGetString(kv, "gifting_commands", menuCommands, sizeof(menuCommands));
	ExplodeString(menuCommands, " ", g_menuCommands, sizeof(g_menuCommands), sizeof(g_menuCommands[]));
	
	new String:creditChoices[MAX_CREDIT_CHOICES][10];

	decl String:creditChoicesString[255];
	KvGetString(kv, "credits_choices", creditChoicesString, sizeof(creditChoicesString));

	new choices = ExplodeString(creditChoicesString, " ", creditChoices, sizeof(creditChoices), sizeof(creditChoices[]));
	for (new choice = 0; choice < choices; choice++)
		g_creditChoices[choice] = StringToInt(creditChoices[choice]);

	CloseHandle(kv);
}

public OnMainMenuGiftClick(client, const String:value[])
{
	OpenGiftingMenu(client);
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast) 
{ 
	g_giftRequests[GetClientOfUserId(GetEventInt(event, "userid"))][GiftRequestActive] = false;
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
			OpenGiftingMenu(client);
			
			if (text[0] == 0x2F)
				return Plugin_Handled;
			
			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

public Action:Command_OpenGifting(client, args)
{
	OpenGiftingMenu(client);
	return Plugin_Handled;
}

/**
 * Opens the gifting menu for a client.
 *
 * @param client			Client index.
 *
 * @noreturn
 */
OpenGiftingMenu(client)
{
	new Handle:menu = CreateMenu(GiftTypeMenuSelectHandle);
	SetMenuTitle(menu, "%T", "Gift Type Menu Title", client);

	decl String:item[32];
	Format(item, sizeof(item), "%T", "Item", client);

	AddMenuItem(menu, "credits", g_currencyName);
	AddMenuItem(menu, "item", item);

	DisplayMenu(menu, client, 0);
}

public GiftTypeMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:giftType[10];
		
		if (GetMenuItem(menu, slot, giftType, sizeof(giftType)))
		{
			if (StrEqual(giftType, "credits"))
			{
				OpenChoosePlayerMenu(client, GiftType_Credits);
			}
			else if (StrEqual(giftType, "item"))
			{
				OpenChoosePlayerMenu(client, GiftType_Item);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (slot == MenuCancel_Exit)
		{
			Store_OpenMainMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

OpenChoosePlayerMenu(client, GiftType:giftType)
{
	new Handle:menu;

	if (giftType == GiftType_Credits)
		menu = CreateMenu(ChoosePlayerCreditsMenuSelectHandle);
	else if (giftType == GiftType_Item)
		menu = CreateMenu(ChoosePlayerItemMenuSelectHandle);
	else
		return;

	SetMenuTitle(menu, "Select Player:\n \n");

	AddTargetsToMenu2(menu, 0, COMMAND_FILTER_NO_BOTS);

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);	
}

public ChoosePlayerCreditsMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:userid[10];
		if (GetMenuItem(menu, slot, userid, sizeof(userid)))
			OpenSelectCreditsMenu(client, GetClientOfUserId(StringToInt(userid)));
	}
	else if (action == MenuAction_Cancel)
	{
		if (slot == MenuCancel_ExitBack)
		{
			OpenGiftingMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public ChoosePlayerItemMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:userid[10];
		if (GetMenuItem(menu, slot, userid, sizeof(userid)))
			OpenSelectItemMenu(client, GetClientOfUserId(StringToInt(userid)));
	}
	else if (action == MenuAction_Cancel)
	{
		if (slot == MenuCancel_ExitBack)
		{
			OpenGiftingMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

OpenSelectCreditsMenu(client, giftTo)
{
	new Handle:menu = CreateMenu(CreditsMenuSelectItem);

	SetMenuTitle(menu, "Select %s:", g_currencyName);

	for (new choice = 0; choice < sizeof(g_creditChoices); choice++)
	{
		if (g_creditChoices[choice] == 0)
			continue;

		decl String:text[48];
		IntToString(g_creditChoices[choice], text, sizeof(text));

		decl String:value[32];
		Format(value, sizeof(value), "%d,%d", giftTo, g_creditChoices[choice]);

		AddMenuItem(menu, value, text);
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public CreditsMenuSelectItem(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:value[32];
		if (GetMenuItem(menu, slot, value, sizeof(value)))
		{
			new String:values[2][16];
			ExplodeString(value, ",", values, sizeof(values), sizeof(values[]));

			new giftTo = StringToInt(values[0]);
			new credits = StringToInt(values[1]);

			new Handle:pack = CreateDataPack();
			WritePackCell(pack, client);
			WritePackCell(pack, giftTo);
			WritePackCell(pack, credits);

			Store_GetCredits(Store_GetClientAccountID(client), GetCreditsCallback, pack);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (slot == MenuCancel_ExitBack)
		{
			OpenChoosePlayerMenu(client, GiftType_Credits);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public GetCreditsCallback(credits, any:pack)
{
	ResetPack(pack);

	new client = ReadPackCell(pack);
	new giftTo = ReadPackCell(pack);
	new giftCredits = ReadPackCell(pack);

	CloseHandle(pack);

	if (giftCredits > credits)
	{
		PrintToChat(client, "%s%t", STORE_PREFIX, "Not enough credits", g_currencyName);
	}
	else
	{
		OpenGiveCreditsConfirmMenu(client, giftTo, giftCredits);
	}
}

OpenGiveCreditsConfirmMenu(client, giftTo, credits)
{
	decl String:name[32];
	GetClientName(giftTo, name, sizeof(name));

	new Handle:menu = CreateMenu(CreditsConfirmMenuSelectItem);
	SetMenuTitle(menu, "%T", "Gift Credit Confirmation", client, name, credits, g_currencyName);

	decl String:value[32];
	Format(value, sizeof(value), "%d,%d", giftTo, credits);

	AddMenuItem(menu, value, "Yes");
	AddMenuItem(menu, "", "No");

	SetMenuExitButton(menu, false);
	DisplayMenu(menu, client, 0);  
}

public CreditsConfirmMenuSelectItem(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:value[32];
		if (GetMenuItem(menu, slot, value, sizeof(value)))
		{
			if (!StrEqual(value, ""))
			{
				new String:values[2][16];
				ExplodeString(value, ",", values, sizeof(values), sizeof(values[]));

				new giftTo = StringToInt(values[0]);
				new credits = StringToInt(values[1]);

				AskForPermission(client, giftTo, GiftType_Credits, credits);
			}
		}
	}
	else if (action == MenuAction_DisplayItem) 
	{
		decl String:display[64];
		GetMenuItem(menu, slot, "", 0, _, display, sizeof(display));

		decl String:buffer[255];
		Format(buffer, sizeof(buffer), "%T", display, client);

		return RedrawMenuItem(buffer);
	}	
	else if (action == MenuAction_Cancel)
	{
		if (slot == MenuCancel_ExitBack)
		{
			OpenChoosePlayerMenu(client, GiftType_Credits);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}

	return false;
}

OpenSelectItemMenu(client, giftTo)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientSerial(client));
	WritePackCell(pack, giftTo);

	new Handle:filter = CreateTrie();
	SetTrieValue(filter, "is_tradeable", 1);

	Store_GetUserItems(filter, Store_GetClientAccountID(client), Store_GetClientLoadout(client), GetUserItemsCallback, pack);
}

public GetUserItemsCallback(ids[], bool:equipped[], itemCount[], count, loadoutId, any:pack)
{		
	ResetPack(pack);
	
	new serial = ReadPackCell(pack);
	new giftTo = ReadPackCell(pack);
	
	CloseHandle(pack);
	
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	if (count == 0)
	{
		PrintToChat(client, "%s%t", STORE_PREFIX, "No items");	
		return;
	}
	
	new Handle:menu = CreateMenu(ItemMenuSelectHandle);
	SetMenuTitle(menu, "Select item:\n \n");
	
	for (new item = 0; item < count; item++)
	{
		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(ids[item], displayName, sizeof(displayName));
		
		new String:text[4 + sizeof(displayName) + 6];
		Format(text, sizeof(text), "%s%s", text, displayName);
		
		if (itemCount[item] > 1)
			Format(text, sizeof(text), "%s (%d)", text, itemCount[item]);
		
		decl String:value[32];
		Format(value, sizeof(value), "%d,%d", giftTo, ids[item]);
		
		AddMenuItem(menu, value, text);    
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 0);
}

public ItemMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:value[32];
		if (GetMenuItem(menu, slot, value, sizeof(value)))
		{
			OpenGiveItemConfirmMenu(client, value);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		OpenChoosePlayerMenu(client, GiftType_Item);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

OpenGiveItemConfirmMenu(client, const String:value[])
{
	new String:values[2][16];
	ExplodeString(value, ",", values, sizeof(values), sizeof(values[]));

	new giftTo = StringToInt(values[0]);
	new itemId = StringToInt(values[1]);

	decl String:name[32];
	GetClientName(giftTo, name, sizeof(name));

	decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));

	new Handle:menu = CreateMenu(ItemConfirmMenuSelectItem);
	SetMenuTitle(menu, "%T", "Gift Item Confirmation", client, name, displayName);

	AddMenuItem(menu, value, "Yes");
	AddMenuItem(menu, "", "No");

	SetMenuExitButton(menu, false);
	DisplayMenu(menu, client, 0);  
}

public ItemConfirmMenuSelectItem(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:value[32];
		if (GetMenuItem(menu, slot, value, sizeof(value)))
		{
			if (!StrEqual(value, ""))
			{
				new String:values[2][16];
				ExplodeString(value, ",", values, sizeof(values), sizeof(values[]));

				new giftTo = StringToInt(values[0]);
				new itemId = StringToInt(values[1]);

				AskForPermission(client, giftTo, GiftType_Item, itemId);
			}
		}
	}
	else if (action == MenuAction_DisplayItem) 
	{
		decl String:display[64];
		GetMenuItem(menu, slot, "", 0, _, display, sizeof(display));

		decl String:buffer[255];
		Format(buffer, sizeof(buffer), "%T", display, client);

		return RedrawMenuItem(buffer);
	}	
	else if (action == MenuAction_Cancel)
	{
		if (slot == MenuCancel_ExitBack)
		{
			OpenChoosePlayerMenu(client, GiftType_Credits);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}

	return false;
}

AskForPermission(client, giftTo, GiftType:giftType, value)
{
	decl String:giftToName[32];
	GetClientName(giftTo, giftToName, sizeof(giftToName));

	CPrintToChatEx(client, giftTo, "%s%T", STORE_PREFIX, "Gift Waiting to accept", client, giftToName);

	decl String:clientName[32];
	GetClientName(client, clientName, sizeof(clientName));	

	new String:what[64];

	if (giftType == GiftType_Credits)
		Format(what, sizeof(what), "%d %s", value, g_currencyName);
	else if (giftType == GiftType_Item)
		Store_GetItemDisplayName(value, what, sizeof(what));	

	CPrintToChatEx(giftTo, client, "%s%T", STORE_PREFIX, "Gift Request Accept", client, clientName, what);

	g_giftRequests[giftTo][GiftRequestActive] = true;
	g_giftRequests[giftTo][GiftRequestSender] = client;
	g_giftRequests[giftTo][GiftRequestType] = giftType;
	g_giftRequests[giftTo][GiftRequestValue] = value;
}

public Action:Command_Accept(client, args)
{
	if (!g_giftRequests[client][GiftRequestActive])
		return Plugin_Continue;

	if (g_giftRequests[client][GiftRequestType] == GiftType_Credits)
		GiftCredits(g_giftRequests[client][GiftRequestSender], client, g_giftRequests[client][GiftRequestValue]);
	else
		GiftItem(g_giftRequests[client][GiftRequestSender], client, g_giftRequests[client][GiftRequestValue]);

	g_giftRequests[client][GiftRequestActive] = false;
	return Plugin_Handled;
}

GiftCredits(from, to, amount)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, from); // 0
	WritePackCell(pack, to); // 8
	WritePackCell(pack, amount);

	Store_GiveCredits(Store_GetClientAccountID(from), -amount, TakeCreditsCallback, pack);
}

public TakeCreditsCallback(accountId, any:pack)
{
	SetPackPosition(pack, 8);

	new to = ReadPackCell(pack);
	new amount = ReadPackCell(pack);

	Store_GiveCredits(Store_GetClientAccountID(to), amount, GiveCreditsCallback, pack);
}

public GiveCreditsCallback(accountId, any:pack)
{
	ResetPack(pack);

	new from = ReadPackCell(pack);
	new to = ReadPackCell(pack);

	CloseHandle(pack);

	decl String:receiverName[32];
	GetClientName(to, receiverName, sizeof(receiverName));	

	CPrintToChatEx(from, to, "%s%t", STORE_PREFIX, "Gift accepted - sender", receiverName);

	decl String:senderName[32];
	GetClientName(from, senderName, sizeof(senderName));

	CPrintToChatEx(to, from, "%s%t", STORE_PREFIX, "Gift accepted - receiver", senderName);
}

GiftItem(from, to, itemId)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, from); // 0
	WritePackCell(pack, to); // 8
	WritePackCell(pack, itemId);

	Store_RemoveUserItem(Store_GetClientAccountID(from), itemId, RemoveUserItemCallback, pack);
}

public RemoveUserItemCallback(accountId, itemId, any:pack)
{
	SetPackPosition(pack, 8);

	new to = ReadPackCell(pack);

	Store_GiveItem(Store_GetClientAccountID(to), itemId, Store_Gift, GiveCreditsCallback, pack);
}