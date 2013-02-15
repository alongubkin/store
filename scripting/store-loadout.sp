#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <store/store-core>
#include <store/store-logging>
#include <store/store-backend>
#undef REQUIRE_EXTENSIONS
#include <tf2_stocks>

stock const String:TF2_ClassName[TFClassType][] = {"", "scout", "sniper", "soldier", "demoman", "medic",
                                                    "heavy", "pyro", "spy", "engineer" };

new Handle:g_clientLoadoutChangedForward;
new String:g_menuCommands[32][32];

new String:g_game[STORE_MAX_LOADOUTGAME_LENGTH];

new g_clientLoadout[MAXPLAYERS+1];
new Handle:g_lastClientLoadout;

new bool:g_databaseInitialized = false;

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
	CreateNative("Store_OpenLoadoutMenu", Native_OpenLoadoutMenu);
	CreateNative("Store_GetClientLoadout", Native_GetClientLoadout);
	
	RegPluginLibrary("store-loadout");	
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name        = "[Store] Loadout",
	author      = "alongub",
	description = "Loadout component for [Store]",
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

	Store_AddMainMenuItem("Loadout", "Loadout Description", _, OnMainMenuLoadoutClick);
	
	g_clientLoadoutChangedForward = CreateGlobalForward("Store_OnClientLoadoutChanged", ET_Event, Param_Cell);
	g_lastClientLoadout = RegClientCookie("lastClientLoadout", "Client loadout", CookieAccess_Protected);
	
	GetGameFolderName(g_game, sizeof(g_game));
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	RegConsoleCmd("sm_loadout", Command_OpenLoadout);

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

/**
 * The map is starting.
 */
public OnMapStart()
{
	if (g_databaseInitialized)
	{
		Store_GetLoadouts(INVALID_HANDLE, Store_GetItemsCallback:INVALID_HANDLE, false);
	}
}

/**
 * The database is ready to use.
 */
public Store_OnDatabaseInitialized()
{
	g_databaseInitialized = true;
	Store_GetLoadouts(INVALID_HANDLE, Store_GetItemsCallback:INVALID_HANDLE, false);
}

/**
 * Called once a client's saved cookies have been loaded from the database.
 */
public OnClientCookiesCached(client)
{
	decl String:buffer[12];
	GetClientCookie(client, g_lastClientLoadout, buffer, sizeof(buffer));
	
	g_clientLoadout[client] = StringToInt(buffer);
}

/**
 * Load plugin config.
 */
LoadConfig() 
{
	new Handle:kv = CreateKeyValues("root");
	
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/loadout.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	decl String:menuCommands[255];
	KvGetString(kv, "loadout_commands", menuCommands, sizeof(menuCommands));

	ExplodeString(menuCommands, " ", g_menuCommands, sizeof(g_menuCommands), sizeof(g_menuCommands[]));
	
	CloseHandle(kv);
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
			OpenLoadoutMenu(client);
			
			if (text[0] == 0x2F)
				return Plugin_Handled;
			
			return Plugin_Continue;
		}        
	}
	
	return Plugin_Continue;
}

public Action:Command_OpenLoadout(client, args)
{
	OpenLoadoutMenu(client);
	return Plugin_Handled;
}

public OnMainMenuLoadoutClick(client, const String:value[])
{
	OpenLoadoutMenu(client);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_clientLoadout[client] == 0 || !IsLoadoutAvailableFor(client, g_clientLoadout[client]))
		FindOptimalLoadoutFor(client);
}

/**
 * Opens the loadout menu for a client.
 *
 * @param client			Client index.
 *
 * @noreturn
 */
OpenLoadoutMenu(client)
{
	new Handle:filter = CreateTrie();
	SetTrieString(filter, "game", g_game);
	SetTrieValue(filter, "team", GetClientTeam(client));
	
	if (StrEqual(g_game, "tf"))
	{
		decl String:className[10];
		TF2_GetClassName(TF2_GetPlayerClass(client), className, sizeof(className));
		
		SetTrieString(filter, "class", className);
	}
	
	Store_GetLoadouts(filter, GetLoadoutsCallback, true, client);
}

public GetLoadoutsCallback(ids[], count, any:client)
{
	new Handle:menu = CreateMenu(LoadoutMenuSelectHandle);
	SetMenuTitle(menu, "Loadout\n \n");
		
	for (new loadout = 0; loadout < count; loadout++)
	{
		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetLoadoutDisplayName(ids[loadout], displayName, sizeof(displayName));
		
		new String:itemText[sizeof(displayName) + 3];
		
		if (g_clientLoadout[client] == ids[loadout])
			strcopy(itemText, sizeof(itemText), "[L] ");
			
		Format(itemText, sizeof(itemText), "%s%s", itemText, displayName);
		
		decl String:itemValue[8];
		IntToString(ids[loadout], itemValue, sizeof(itemValue));
		
		AddMenuItem(menu, itemValue, itemText);
	}
	
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 0);
}

public LoadoutMenuSelectHandle(Handle:menu, MenuAction:action, client, slot)
{
	if (action == MenuAction_Select)
	{
		new String:loadoutId[12];
		
		if (GetMenuItem(menu, slot, loadoutId, sizeof(loadoutId)))
		{
			g_clientLoadout[client] = StringToInt(loadoutId);			
			SetClientCookie(client, g_lastClientLoadout, loadoutId);
			
			Call_StartForward(g_clientLoadoutChangedForward);
			Call_PushCell(client);
			Call_Finish();
		}
		
		OpenLoadoutMenu(client);
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

bool:IsLoadoutAvailableFor(client, loadout)
{
	decl String:game[STORE_MAX_LOADOUTGAME_LENGTH];
	Store_GetLoadoutGame(loadout, game, sizeof(game));
	
	if (!StrEqual(game, "") && !StrEqual(game, g_game))
		return false;
	
	if (StrEqual(g_game, "tf"))
	{
		decl String:loadoutClass[STORE_MAX_LOADOUTCLASS_LENGTH];
		Store_GetLoadoutClass(loadout, loadoutClass, sizeof(loadoutClass));
		
		decl String:className[10];
		TF2_GetClassName(TF2_GetPlayerClass(client), className, sizeof(className));
		
		if (!StrEqual(loadoutClass, "") && !StrEqual(loadoutClass, className))
			return false;		
	}
	
	new loadoutTeam = Store_GetLoadoutTeam(loadout);
	if (loadoutTeam != -1 && GetClientTeam(client) != loadoutTeam)
		return false;
		
	return true;
}

FindOptimalLoadoutFor(client)
{
	if (!g_databaseInitialized)
		return;
		
	new Handle:filter = CreateTrie();
	SetTrieString(filter, "game", g_game);
	SetTrieValue(filter, "team", GetClientTeam(client));
	
	if (StrEqual(g_game, "tf"))
	{
		decl String:className[10];
		TF2_GetClassName(TF2_GetPlayerClass(client), className, sizeof(className));
		
		SetTrieString(filter, "class", className);
	}
	
	Store_GetLoadouts(filter, FindOptimalLoadoutCallback, true, GetClientSerial(client));
}

public FindOptimalLoadoutCallback(ids[], count, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
	
	if (count > 0)
	{
		g_clientLoadout[client] = ids[0];
		
		decl String:buffer[12];
		IntToString(g_clientLoadout[client], buffer, sizeof(buffer));
		
		SetClientCookie(client, g_lastClientLoadout, buffer);
		
		Call_StartForward(g_clientLoadoutChangedForward);
		Call_PushCell(client);
		Call_Finish();
	}
	else
	{
		Store_LogWarning("No loadout found.");
	}	
}

public Native_OpenLoadoutMenu(Handle:plugin, params)
{       
	OpenLoadoutMenu(GetNativeCell(1));
}

public Native_GetClientLoadout(Handle:plugin, params)
{       
	return g_clientLoadout[GetNativeCell(1)];
}

stock TF2_GetClassName(TFClassType:classType, String:buffer[], maxlength)
{
	strcopy(buffer, maxlength, TF2_ClassName[classType]);
}