#pragma semicolon 1

#include <sourcemod>
#include <store/store-core>
#include <store/store-logging>
#include <store/store-backend>

#include <colors>
#include <morecolors_store>

#define MAX_MENU_ITEMS 32
#define MAX_CHAT_COMMANDS 100

enum MenuItem
{
	String:MenuItemDisplayName[32],
	String:MenuItemDescription[128],
	String:MenuItemValue[64],
	Handle:MenuItemPlugin,
	Store_MenuItemClickCallback:MenuItemCallback,
	MenuItemOrder
}

enum ChatCommand
{
	String:ChatCommandName[32],
	Handle:ChatCommandPlugin,
	Store_ChatCommandCallback:ChatCommandCallback,
}

new String:g_currencyName[64];

new g_chatCommands[MAX_CHAT_COMMANDS + 1][ChatCommand];
new g_chatCommandCount = 0;

new g_menuItems[MAX_MENU_ITEMS + 1][MenuItem];
new g_menuItemCount = 0;

new g_firstConnectionCredits = 0;

new bool:g_allPluginsLoaded = false;

new Handle:g_hOnChatCommandForward;
new Handle:g_hOnChatCommandPostForward;

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
	CreateNative("Store_OpenMainMenu", Native_OpenMainMenu);
	CreateNative("Store_AddMainMenuItem", Native_AddMainMenuItem);
	CreateNative("Store_GetCurrencyName", Native_GetCurrencyName);
	CreateNative("Store_RegisterChatCommands", Native_RegisterChatCommands);

	RegPluginLibrary("store");	
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name        = "[Store] Core",
	author      = "alongub",
	description = "Core component for [Store]",
	version     = STORE_VERSION,
	url         = "https://github.com/alongubkin/store"
};

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
	CreateConVar("store_version", STORE_VERSION, "Store Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	LoadConfig();
	
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	RegAdminCmd("store_givecredits", Command_GiveCredits, ADMFLAG_ROOT, "Gives credits to a player.");

	g_hOnChatCommandForward = CreateGlobalForward("Store_OnChatCommand", ET_Event, Param_Cell, Param_String, Param_String);
	g_hOnChatCommandPostForward = CreateGlobalForward("Store_OnChatCommand_Post", ET_Ignore, Param_Cell, Param_String, Param_String);

	g_allPluginsLoaded = false;
}

/**
 * All plugins have been loaded.
 */
public OnAllPluginsLoaded()
{
	SortMainMenuItems();
	g_allPluginsLoaded = true;
}

/**
 * Called once a client is authorized and fully in-game, and 
 * after all post-connection authorizations have been performed.  
 *
 * This callback is gauranteed to occur on all clients, and always 
 * after each OnClientPutInServer() call.
 *
 * @param client		Client index.
 * @noreturn
 */
public OnClientPostAdminCheck(client)
{	
	Store_RegisterClient(client, g_firstConnectionCredits);
}

/**
 * Called when a client has typed a message to the chat.
 *
 * @param client		Client index.
 * @param command		Command name.
 * @param sArgs			Arguments. 
 *
 * @return				Action to take.
 */
public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	if (client <= 0 || client > MaxClients)
		return Plugin_Continue;
		
	if (!IsClientInGame(client))
		return Plugin_Continue;

	decl String:sArgsTrimmed[256];
	new sArgsLen = strlen(sArgs);

	if (sArgsLen >= 2 && sArgs[0] == '"' && sArgs[sArgsLen - 1] == '"')
	{
		// If the arguments are enclosed in "", trim them
		strcopy(sArgsTrimmed, sArgsLen - 1, sArgs[1]);
	}
	else
	{
		// If there are not quotes, just copy the whole string
		strcopy(sArgsTrimmed, sizeof(sArgsTrimmed), sArgs);
	}

	static String:cmds[2][256];
	ExplodeString(sArgsTrimmed, " ", cmds, sizeof(cmds), sizeof(cmds[]), true);

	if (strlen(cmds[0]) <= 0)
		return Plugin_Continue;

	for (new i = 0; i < g_chatCommandCount; i++)
	{
		if (StrEqual(cmds[0], g_chatCommands[i][ChatCommandName], false))
		{
			new Action:result = Plugin_Continue;
			Call_StartForward(g_hOnChatCommandForward);
			Call_PushCell(client);
			Call_PushString(cmds[0]);
			Call_PushString(cmds[1]);
			Call_Finish(_:result);

			if (result == Plugin_Handled || result == Plugin_Stop)
				return Plugin_Continue;

			Call_StartFunction(g_chatCommands[i][ChatCommandPlugin], Function:g_chatCommands[i][ChatCommandCallback]);
			Call_PushCell(client);
			Call_PushString(cmds[0]);
			Call_PushString(cmds[1]);
			Call_Finish();

			Call_StartForward(g_hOnChatCommandPostForward);
			Call_PushCell(client);
			Call_PushString(cmds[0]);
			Call_PushString(cmds[1]);
			Call_Finish();

			if (cmds[0][0] == 0x2F)
				return Plugin_Handled;
			else
				return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}

public ChatCommand_OpenMainMenu(client)
{
	OpenMainMenu(client);
}

public ChatCommand_Credits(client)
{
	Store_GetCredits(GetSteamAccountID(client), OnCommandGetCredits, client);
}

public OnCommandGetCredits(credits, any:client)
{
	PrintToChat(client, "%s%t", STORE_PREFIX, "Store Menu Title", credits, g_currencyName);
}

public Action:Command_GiveCredits(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "%sUsage: store_givecredits <name> <credits>", STORE_PREFIX);
		return Plugin_Handled;
	}
    
	decl String:target[65];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl target_count;
	decl bool:tn_is_ml;
    
	GetCmdArg(1, target, sizeof(target));
    
	new String:money[32];
	GetCmdArg(2, money, sizeof(money));
    
	new imoney = StringToInt(money);
 
	if ((target_count = ProcessTargetString(
			target,
			0,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}


	new accountIds[target_count];
	new count = 0;

	for (new i = 0; i < target_count; i++)
	{
		if (IsClientInGame(target_list[i]) && !IsFakeClient(target_list[i]))
		{
			accountIds[count] = GetSteamAccountID(target_list[i]);
			count++;

			PrintToChat(target_list[i], "%s%t", STORE_PREFIX, "Received Credits", imoney, g_currencyName);
		}
	}

	Store_GiveCreditsToUsers(accountIds, count, imoney);
	return Plugin_Handled;
}

/**
 * Load plugin config.
 */
LoadConfig() 
{
	new Handle:kv = CreateKeyValues("root");
	
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/core.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	KvGetString(kv, "currency_name", g_currencyName, sizeof(g_currencyName), "Credits");

	decl String:buffer[256];

	KvGetString(kv, "mainmenu_commands", buffer, sizeof(buffer), "!store /store");
	Store_RegisterChatCommands(buffer, ChatCommand_OpenMainMenu);

	KvGetString(kv, "credits_commands", buffer, sizeof(buffer), "!credits /credits");
	Store_RegisterChatCommands(buffer, ChatCommand_Credits);

	g_firstConnectionCredits = KvGetNum(kv, "first_connection_credits");

	CloseHandle(kv);
}

/**
 * Adds an item to the main menu. 
 *
 * @param displayName		The text of the item, as it is shown to the player.
 * @param description		A short description of the item.
 * @param value				Item information string that will be sent to the callback.
 * @param plugin			The plugin owner of the callback.
 * @param callback			Callback to the item click event.
 * @param order				Preferred position of the item in the menu.
 *
 * @noreturn
 */ 
AddMainMenuItem(const String:displayName[], const String:description[] = "", const String:value[] = "", Handle:plugin = INVALID_HANDLE, Store_MenuItemClickCallback:callback, order = 32)
{
	new item;
	
	for (; item <= g_menuItemCount; item++)
	{
		if (item == g_menuItemCount || StrEqual(g_menuItems[item][MenuItemDisplayName], displayName))
			break;
	}
	
	strcopy(g_menuItems[item][MenuItemDisplayName], 32, displayName);
	strcopy(g_menuItems[item][MenuItemDescription], 128, description);
	strcopy(g_menuItems[item][MenuItemValue], 64, value);   
	g_menuItems[item][MenuItemPlugin] = plugin;
	g_menuItems[item][MenuItemCallback] = callback;
	g_menuItems[item][MenuItemOrder] = order;

	if (item == g_menuItemCount)
		g_menuItemCount++;
	
	if (g_allPluginsLoaded)
		SortMainMenuItems();
}

/**
 * Sort menu items by their preffered order.
 *
 * @noreturn
 */ 
SortMainMenuItems()
{
	new sortIndex = sizeof(g_menuItems) - 1;
	
	for (new x = 0; x < g_menuItemCount; x++) 
	{
		for (new y = 0; y < g_menuItemCount; y++) 
		{
			if (g_menuItems[x][MenuItemOrder] < g_menuItems[y][MenuItemOrder])
			{
				g_menuItems[sortIndex] = g_menuItems[x];
				g_menuItems[x] = g_menuItems[y];
				g_menuItems[y] = g_menuItems[sortIndex];
			}
		}
	}
}

/**
 * Opens the main menu for a player.
 *
 * @param client		Client Index
 *
 * @noreturn
 */
OpenMainMenu(client)
{	
	Store_GetCredits(GetSteamAccountID(client), OnGetCreditsComplete, GetClientSerial(client));
}

public OnGetCreditsComplete(credits, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	new Handle:menu = CreateMenu(MainMenuSelectHandle);
	SetMenuTitle(menu, "%T\n \n", "Store Menu Title", client, credits, g_currencyName);
	
	for (new item = 0; item < g_menuItemCount; item++)
	{
		decl String:text[255];  
		Format(text, sizeof(text), "%T\n%T", g_menuItems[item][MenuItemDisplayName], client, g_menuItems[item][MenuItemDescription], client);
				
		AddMenuItem(menu, g_menuItems[item][MenuItemValue], text);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 0);
}

public MainMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			Call_StartFunction(g_menuItems[slot][MenuItemPlugin], Function:g_menuItems[slot][MenuItemCallback]);
			Call_PushCell(client);
			Call_PushString(g_menuItems[slot][MenuItemValue]);
			Call_Finish();
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public Native_OpenMainMenu(Handle:plugin, params)
{       
	OpenMainMenu(GetNativeCell(1));
}

public Native_AddMainMenuItem(Handle:plugin, params)
{
	decl String:displayName[32];
	GetNativeString(1, displayName, sizeof(displayName));
	
	decl String:description[128];
	GetNativeString(2, description, sizeof(description));
	
	decl String:value[64];
	GetNativeString(3, value, sizeof(value));
	
	AddMainMenuItem(displayName, description, value, plugin, Store_MenuItemClickCallback:GetNativeCell(4), GetNativeCell(5));
}

public Native_GetCurrencyName(Handle:plugin, params)
{       
	SetNativeString(1, g_currencyName, GetNativeCell(2));
}

/**
 * Registers a chat command
 *
 * @param plugin		The calling plugin for the callback.
 * @param commands		Space seperated list of commands to register, eg "!credits /credits"
 * @param callback		The callback for when the command is said in chat.
 *
 * @return Returns true if command was registered successfully.
 */ 
bool:RegisterCommands(Handle:plugin, const String:commands[], Store_ChatCommandCallback:callback)
{
	if (g_chatCommandCount >= MAX_CHAT_COMMANDS)
		return false;

	decl String:splitcommands[32][32];
	new count;

	count = ExplodeString(commands, " ", splitcommands, sizeof(splitcommands), sizeof(splitcommands[]));

	if (count <= 0) // shouldn't happen?
		return false;

	if (g_chatCommandCount + count >= MAX_CHAT_COMMANDS)
		return false;

	for (new i = 0; i < g_chatCommandCount; i++)
		for (new n = 0; n < count; n++)
			if (StrEqual(splitcommands[n], g_chatCommands[i][ChatCommandName], false))
				return false;

	for (new i = 0; i < count; i++)
	{
		strcopy(g_chatCommands[g_chatCommandCount][ChatCommandName], 32, splitcommands[i]);
		g_chatCommands[g_chatCommandCount][ChatCommandPlugin] = plugin;
		g_chatCommands[g_chatCommandCount][ChatCommandCallback] = callback;
		
		g_chatCommandCount++;
	}

	return true;
}

public Native_RegisterChatCommands(Handle:plugin, params)
{
	decl String:command[32];
	GetNativeString(1, command, sizeof(command));

	return RegisterCommands(plugin, command, Store_ChatCommandCallback:GetNativeCell(2));
}
