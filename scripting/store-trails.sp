#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>
#include <cstrike>
#include <smjansson>

#undef REQUIRE_PLUGIN
#include <zombiereloaded>

enum Trail
{
    String:Description[64],
	String:Name[64],
	String:Color[32],
    String:Material[256],
    StartingWidth
}

new g_trails[1024][Trail];
new g_trailCount = 0;
new g_SpriteModel[MAXPLAYERS + 1];
new bool:g_zombieReloaded;

new Handle:g_trailsNameIndex = INVALID_HANDLE;

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

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
	Store_RegisterItemType("trails", Store_ItemUseCallback:OnEquip, Store_ItemGetAttributesCallback:LoadItem);

	g_zombieReloaded = LibraryExists("zombiereloaded");
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_team", PlayerTeam);
	HookEvent("round_end", RoundEnd);

	for (new index = 0; index < MaxClients; index++)
	{
		g_SpriteModel[index] = -1;
	}
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
		if (IsValidEntity(g_SpriteModel[client]))
			RemoveEdict(g_SpriteModel[client]);
		
		g_SpriteModel[client] = -1;
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
	strcopy(g_trails[g_trailCount][Name], 32, itemName);
		
	SetTrieValue(g_trailsNameIndex, g_trails[g_trailCount][Name], g_trailCount);
	
	new Handle:json = json_load(attrs);
	json_object_get_string(json, "material", g_trails[g_trailCount][Material], 256);
	json_object_get_string(json, "color", g_trails[g_trailCount][Color], 256);	
	g_trails[g_trailCount][StartingWidth] = json_object_get_int(json, "startingwidth"); 
	
	CloseHandle(json);

	if (strcmp(g_trails[g_trailCount][Material], "") != 0 && (FileExists(g_trails[g_trailCount][Material]) || FileExists(g_trails[g_trailCount][Material], true)))
	{
		decl String:_sBuffer[PLATFORM_MAX_PATH];
		strcopy(_sBuffer, sizeof(_sBuffer), g_trails[g_trailCount][Material]);
		PrecacheModel(_sBuffer);
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
		PrintToChat(client, "You must be alive to equip this item.");
		return false;
	}
	
	if (g_zombieReloaded && !ZR_IsClientHuman(client))
	{
		PrintToChat(client, "You must be a human to equip this item.");	
		return false;
	}
	
	decl String:name[32];
	Store_GetItemName(itemId, name, sizeof(name));
	
	decl String:loadoutSlot[32];
	Store_GetItemLoadoutSlot(itemId, loadoutSlot, sizeof(loadoutSlot));
			
	if (equipped)
	{
		KillTrail(client);
		
		decl String:displayName[64];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "You have unequipped the %s.", displayName);
	}
	else
	{
		KillTrail(client);
		
		if (!Equip(client, name))
			return false;
			
		decl String:displayName[64];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "You have equipped the %s.", displayName);	
	}
	
	return true;
}

public OnClientDisconnect(client)
{
	if (IsValidEntity(g_SpriteModel[client]))
	{
		RemoveEdict(g_SpriteModel[client]);
	}
	g_SpriteModel[client] = -1;
}

public Action:PlayerSpawn(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsClientInGame(client) && IsPlayerAlive(client)) 
	{
		if (g_SpriteModel[client] != -1 || IsValidEntity(g_SpriteModel[client]))
			KillTrail(client);
        
		CreateTimer(1.0, GiveTrail, client);
	}
}

public PlayerTeam(Handle:Spawn_Event, const String:Death_Name[], bool:Death_Broadcast )
{
	new client = GetClientOfUserId( GetEventInt(Spawn_Event,"userid") );
	new team = GetEventInt(Spawn_Event, "team");
	
	if (team == 1)
	{
		if (IsValidEntity(g_SpriteModel[client]))
		{
			RemoveEdict(g_SpriteModel[client]);
		}
		g_SpriteModel[client] = -1;
	}
}

public Action:PlayerDeath(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidEntity(g_SpriteModel[client]))
	{
		RemoveEdict(g_SpriteModel[client]);
	}
	g_SpriteModel[client] = -1;
}

public Action:RoundEnd(Handle:event,const String:name[],bool:dontBroadcast)
{
	for (new index = 0; index < MaxClients; index++)
	{
		g_SpriteModel[index] = -1;
	}
}

public Action:GiveTrail(Handle:timer, any:client)
{
	if (!IsPlayerAlive(client))
		return Plugin_Continue;
		
	if (g_zombieReloaded && !ZR_IsClientHuman(client))
		return Plugin_Continue;
		
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "trails", Store_GetClientLoadout(client), OnGetPlayerTrail, GetClientSerial(client));
	return Plugin_Handled;
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
	new trail = -1;
	if (!GetTrieValue(g_trailsNameIndex, name, trail))
	{
		PrintToChat(client, "No trail attributes found.");
		return false;
	}
	
	g_SpriteModel[client] = CreateEntityByName("env_spritetrail");
	
	if (!IsValidEntity(g_SpriteModel[client])) 
		return false;
		
	new String:strTargetName[MAX_NAME_LENGTH];
	GetClientName(client, strTargetName, sizeof(strTargetName));
	
	DispatchKeyValue(client, "targetname", strTargetName);
	DispatchKeyValue(g_SpriteModel[client], "parentname", strTargetName);
	DispatchKeyValue(g_SpriteModel[client], "lifetime", "1.0");
	DispatchKeyValue(g_SpriteModel[client], "endwidth", "6.0");
	DispatchKeyValue(g_SpriteModel[client], "startwidth","10");
	DispatchKeyValue(g_SpriteModel[client], "spritename", g_trails[trail][Material]);
	DispatchKeyValue(g_SpriteModel[client], "renderamt", "255");
	DispatchKeyValue(g_SpriteModel[client], "rendercolor", g_trails[trail][Color]);
	DispatchKeyValue(g_SpriteModel[client], "rendermode", "1");
	
	DispatchSpawn(g_SpriteModel[client]);
	
	new Float:Client_Origin[3];
	GetClientAbsOrigin(client,Client_Origin);
	Client_Origin[2] += 10.0; //Beam clips into the floor without this
	
	TeleportEntity(g_SpriteModel[client], Client_Origin, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString(strTargetName);
	AcceptEntityInput(g_SpriteModel[client], "SetParent"); 
	SetEntPropFloat(g_SpriteModel[client], Prop_Send, "m_flTextureRes", 0.05);

	return true;
}

KillTrail(client)
{
    if (g_SpriteModel[client] > 0 && IsValidEntity(g_SpriteModel[client]))
        RemoveEdict(g_SpriteModel[client]);
    
    g_SpriteModel[client] = -1;
}

public ZR_OnClientInfected(client, attacker, bool:motherInfect, bool:respawnOverride, bool:respawn)
{
	KillTrail(client);
}