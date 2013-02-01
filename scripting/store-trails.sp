#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>
#include <smjansson>

#undef REQUIRE_PLUGIN
#include <zombiereloaded>

enum Trail
{
	String:TrailName[STORE_MAX_NAME_LENGTH],
	String:TrailMaterial[PLATFORM_MAX_PATH],
	Float:TrailLifetime,
	Float:TrailWidth,
	Float:TrailEndWidth,
	TrailFadeLength,
	TrailColor[4],
	TrailModelIndex
}

new g_trails[1024][Trail];
new g_trailCount = 0;
new bool:g_zombieReloaded;

new Handle:g_trailsNameIndex = INVALID_HANDLE;

new Handle:g_trailTimers[MAXPLAYERS+1];

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
	MarkNativeAsOptional("ZR_IsClientHuman"); 
	MarkNativeAsOptional("ZR_IsClientZombie"); 
	
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name        = "[Store] Trails",
	author      = "alongub",
	description = "Trails component for [Store]",
	version     = STORE_VERSION,
	url         = "https://github.com/alongubkin/store"
};

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	Store_RegisterItemType("trails", OnEquip, LoadItem);

	g_zombieReloaded = LibraryExists("zombiereloaded");
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_team", PlayerTeam);
	HookEvent("round_end", RoundEnd);
}

/** 
 * Called when a new API library is loaded.
 */
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "zombiereloaded"))
	{
		g_zombieReloaded = true;
	}
}

/** 
 * Called when an API library is removed.
 */
public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "zombiereloaded"))
	{
		g_zombieReloaded = false;
	}
}

/**
 * The map is ending.
 */
public OnMapEnd()
{
	for (new client = 0; client < MaxClients; client++)
	{
		if (g_trailTimers[client] != INVALID_HANDLE)
		{
			CloseHandle(g_trailTimers[client]);
			g_trailTimers[client] = INVALID_HANDLE;
		}
	}
}

public Store_OnReloadItems() 
{
	if (g_trailsNameIndex != INVALID_HANDLE)
		CloseHandle(g_trailsNameIndex);
		
	g_trailsNameIndex = CreateTrie();
	g_trailCount = 0;
}

public LoadItem(const String:itemName[], const String:attrs[])
{
	strcopy(g_trails[g_trailCount][TrailName], STORE_MAX_NAME_LENGTH, itemName);
		
	SetTrieValue(g_trailsNameIndex, g_trails[g_trailCount][TrailName], g_trailCount);
	
	new Handle:json = json_load(attrs);
	json_object_get_string(json, "material", g_trails[g_trailCount][TrailMaterial], PLATFORM_MAX_PATH);

	g_trails[g_trailCount][TrailLifetime] = json_object_get_float(json, "lifetime")
	; 
	if (g_trails[g_trailCount][TrailLifetime] == 0.0)
		g_trails[g_trailCount][TrailLifetime] = 0.6;

	g_trails[g_trailCount][TrailWidth] = json_object_get_float(json, "width");

	if (g_trails[g_trailCount][TrailWidth] == 0.0)
		g_trails[g_trailCount][TrailWidth] = 10.0;

	g_trails[g_trailCount][TrailEndWidth] = json_object_get_float(json, "endwidth"); 

	if (g_trails[g_trailCount][TrailEndWidth] == 0.0)
		g_trails[g_trailCount][TrailEndWidth] = 10.0;

	g_trails[g_trailCount][TrailFadeLength] = json_object_get_int(json, "fadelength"); 

	if (g_trails[g_trailCount][TrailFadeLength] == 0)
		g_trails[g_trailCount][TrailFadeLength] = 1;

	new Handle:color = json_object_get(json, "color");

	if (color == INVALID_HANDLE)
	{
		g_trails[g_trailCount][TrailColor] = { 255, 255, 255, 255 };
	}
	else
	{
		for (new i = 0; i < 4; i++)
			g_trails[g_trailCount][TrailColor][i] = json_array_get_int(color, i);

		CloseHandle(color);
	}

	CloseHandle(json);

	if (strcmp(g_trails[g_trailCount][TrailMaterial], "") != 0 && (FileExists(g_trails[g_trailCount][TrailMaterial]) || FileExists(g_trails[g_trailCount][TrailMaterial], true)))
	{
		decl String:_sBuffer[PLATFORM_MAX_PATH];
		strcopy(_sBuffer, sizeof(_sBuffer), g_trails[g_trailCount][TrailMaterial]);
		g_trails[g_trailCount][TrailModelIndex] = PrecacheModel(_sBuffer);
		AddFileToDownloadsTable(_sBuffer);
		ReplaceString(_sBuffer, sizeof(_sBuffer), ".vmt", ".vtf", false);
		AddFileToDownloadsTable(_sBuffer);
	}
	
	g_trailCount++;
}

public bool:OnEquip(client, itemId, bool:equipped)
{
	if (!IsClientInGame(client))
	{
		return false;
	}
	
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "%t", "Must be alive to equip");
		return false;
	}
	
	if (g_zombieReloaded && !ZR_IsClientHuman(client))
	{
		PrintToChat(client, "%t", "Must be human to equip");	
		return false;
	}
	
	decl String:name[STORE_MAX_NAME_LENGTH];
	Store_GetItemName(itemId, name, sizeof(name));
	
	decl String:loadoutSlot[STORE_MAX_LOADOUTSLOT_LENGTH];
	Store_GetItemLoadoutSlot(itemId, loadoutSlot, sizeof(loadoutSlot));
			
	if (equipped)
	{
		KillTrail(client);
		
		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%t", "Unequipped item", displayName);
	}
	else
	{
		KillTrail(client);
		
		if (!Equip(client, name))
			return false;
			
		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%t", "Equipped item", displayName);
	}
	
	return true;
}

public OnClientDisconnect(client)
{
	if (g_trailTimers[client] != INVALID_HANDLE)
	{
		CloseHandle(g_trailTimers[client]);
		g_trailTimers[client] = INVALID_HANDLE;
	}
}

public Action:PlayerSpawn(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsClientInGame(client) && IsPlayerAlive(client)) 
	{
		KillTrail(client);
		CreateTimer(1.0, GiveTrail, GetClientSerial(client));
	}
}

public PlayerTeam(Handle:Spawn_Event, const String:Death_Name[], bool:Death_Broadcast )
{
	new client = GetClientOfUserId(GetEventInt(Spawn_Event,"userid") );
	new team = GetEventInt(Spawn_Event, "team");
	
	if (team == 1)
	{
		KillTrail(client);
	}
}

public Action:PlayerDeath(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	KillTrail(client);
}

public Action:RoundEnd(Handle:event,const String:name[],bool:dontBroadcast)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		KillTrail(client);
	}
}

public Action:GiveTrail(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	if (client == 0)
		return Plugin_Handled;

	if (!IsPlayerAlive(client))
		return Plugin_Continue;
		
	if (g_zombieReloaded && !ZR_IsClientHuman(client))
		return Plugin_Continue;
		
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "trails", Store_GetClientLoadout(client), OnGetPlayerTrail, GetClientSerial(client));
	return Plugin_Handled;
}

public Store_OnClientLoadoutChanged(client)
{
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "trails", Store_GetClientLoadout(client), OnGetPlayerTrail, GetClientSerial(client));
}

public OnGetPlayerTrail(ids[], count, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	if (g_zombieReloaded && !ZR_IsClientHuman(client))
		return;
		
	KillTrail(client);
	
	for (new index = 0; index < count; index++)
	{
		decl String:itemName[32];
		Store_GetItemName(ids[index], itemName, sizeof(itemName));
		
		Equip(client, itemName);
	}
}

bool:Equip(client, const String:name[])
{	
	KillTrail(client);

	new trail = -1;
	if (!GetTrieValue(g_trailsNameIndex, name, trail))
	{
		PrintToChat(client, "%t", "No item attributes");
		return false;
	}

	new Handle:pack;
	g_trailTimers[client] = CreateDataTimer(2.0, Timer_RenderBeam, pack, TIMER_REPEAT);

	WritePackCell(pack, GetClientSerial(client));
	WritePackCell(pack, trail);

	return true;
}

KillTrail(client)
{
	if (g_trailTimers[client] != INVALID_HANDLE)
	{
		CloseHandle(g_trailTimers[client]);
		g_trailTimers[client] = INVALID_HANDLE;
	}
}

public ZR_OnClientInfected(client, attacker, bool:motherInfect, bool:respawnOverride, bool:respawn)
{
	KillTrail(client);
}

public Action:Timer_RenderBeam(Handle:timer, Handle:pack)
{
	ResetPack(pack);

	new client = GetClientFromSerial(ReadPackCell(pack));

	if (client == 0)
		return Plugin_Stop;

	new trail = ReadPackCell(pack);
	
	new entityToFollow = GetPlayerWeaponSlot(client, 2);
	if (entityToFollow == -1)
		entityToFollow = client;

	new color[4];
	Array_Copy(g_trails[client][TrailColor], color, sizeof(color));

	TE_SetupBeamFollow(entityToFollow, 
						g_trails[trail][TrailModelIndex], 
						0, 
						g_trails[trail][TrailLifetime], 
						g_trails[trail][TrailWidth], 
						g_trails[trail][TrailEndWidth], 
						g_trails[trail][TrailFadeLength], 
						color);
	TE_SendToAll();

	return Plugin_Continue;
}


/**
 * Copies a 1 dimensional static array.
 *
 * @param array			Static Array to copy from.
 * @param newArray		New Array to copy to.
 * @param size			Size of the array (or number of cells to copy)
 * @noreturn
 */
stock Array_Copy(const any:array[], any:newArray[], size)
{
	for (new i=0; i < size; i++) 
	{
		newArray[i] = array[i];
	}
}