#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>

#undef REQUIRE_PLUGIN
#include <zombiereloaded>

enum Pet
{
	String:PetName[32],
	String:PetModelPath[PLATFORM_MAX_PATH],
	Float:PetScale
}

new g_offsCollisionGroup;
new g_LeaderOffset;
new g_clientsPet[MAXPLAYERS+1][2];
new bool:g_zombieReloaded;

new g_pets[1024][Pet];
new g_petCount = 0;

new Handle:g_petNameIndex = INVALID_HANDLE;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("ZR_IsClientHuman"); 
	MarkNativeAsOptional("ZR_IsClientZombie"); 
	
	return APLRes_Success;
}

public OnPluginStart()
{
	Store_RegisterItemType("pet", Store_ItemUseCallback:OnEquip);
	
	g_zombieReloaded = LibraryExists("zombiereloaded");
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_team", PlayerTeam);
	
	HookEvent("hostage_follows", Event_HostageFollows, EventHookMode_Pre);
	HookEvent("hostage_stops_following", Event_HostageFollows, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart);
	
	g_offsCollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
	g_LeaderOffset = FindSendPropOffs("CHostage", "m_leader");	
	
	CreateTimer(0.1, Timer_TeleportPets, _, TIMER_REPEAT)
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "zombiereloaded"))
	{
		g_zombieReloaded = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "zombiereloaded"))
	{
		g_zombieReloaded = false;
	}
}

public Action:Timer_TeleportPets(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && g_clientsPet[client][0] > 0 && IsValidEdict(g_clientsPet[client][0]))
		{
			new Float:clientOrigin[3];
			GetClientAbsOrigin(client, clientOrigin);
			
			new Float:clientAngles[3];
			GetClientAbsAngles(client, clientAngles);
			
			new Float:petPosition[3];
			GetEntPropVector(g_clientsPet[client][0], Prop_Send, "m_vecOrigin", petPosition);
			
			if (GetVectorDistance(clientOrigin, petPosition) >= 500.0)
			{
				TeleportEntity(g_clientsPet[client][0], clientOrigin, clientAngles, NULL_VECTOR);
			}
		}
	}
}

public OnMapStart()
{
	LoadPets();
}

LoadPets()
{	
	g_petCount = 0;
	
	new String:sConfig[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfig, PLATFORM_MAX_PATH, "configs/store/items/pets.txt");
	
	new Handle:kv = CreateKeyValues("pets");
	FileToKeyValues(kv, sConfig);
	
	if (g_petNameIndex != INVALID_HANDLE)
		CloseHandle(g_petNameIndex);
		
	g_petNameIndex = CreateTrie();
			
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			KvGetSectionName(kv, g_pets[g_petCount][PetName], 64);
			SetTrieValue(g_petNameIndex, g_pets[g_petCount][PetName], g_petCount);
			
			KvGetString(kv, "model", g_pets[g_petCount][PetModelPath], PLATFORM_MAX_PATH);	
			g_pets[g_petCount][PetScale] = KvGetFloat(kv, "scale", 0.5);

			if (strcmp(g_pets[g_petCount][PetModelPath], "") != 0 && (FileExists(g_pets[g_petCount][PetModelPath]) || FileExists(g_pets[g_petCount][PetModelPath], true)))
				PrecacheModel(g_pets[g_petCount][PetModelPath], true);
      			
			g_petCount++;
		} while (KvGotoNextKey(kv));
	}
	
	CloseHandle(kv);
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
		
	if (equipped)
	{
		RemoveClientPet(client);
	
		decl String:displayName[64];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "You have unequipped the %s.", displayName);
		return true;
	}
	else
	{
		new pet = -1;
		if (!GetTrieValue(g_petNameIndex, name, pet))
		{
			PrintToChat(client, "No pet attributes found.");
			return false;
		}

		RemoveClientPet(client);
		
		if (!AddClientPet(client, pet))
			return false;
		
		decl String:displayName[64];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "You have equipped the %s.", displayName);
		return true;
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (g_clientsPet[client][0] > 0)
			AddClientPet(client, g_clientsPet[client][1]);
	}
}
	
public Action:Event_HostageFollows(Handle:event, const String:name[], bool:dontBroadcast)
{
	new hostageEntity = GetEventInt(event, "hostage");
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (g_clientsPet[client][0] == hostageEntity)
		{
			SetEntDataEnt2(g_clientsPet[client][0], g_LeaderOffset, client);			
			return Plugin_Changed;
		}
	}
	
	return Plugin_Changed;
}

AddClientPet(target, petId)
{
	if (!IsClientInGame(target))
		return false;
		
	if (!IsPlayerAlive(target))
		return false;
		
	new Float:c_origin[3];
	new entity = CreateEntityByName("hostage_entity");
	g_clientsPet[target][0] = entity;
	g_clientsPet[target][1] = petId;
	GetClientEyePosition(target, c_origin);
	DispatchKeyValueVector(entity, "Origin", c_origin);
	DispatchSpawn(entity);
	SetEntityModel(entity, g_pets[petId][PetModelPath]);
	SetEntProp(entity, Prop_Data, "m_takedamage", 0);
	SetEntData(entity, g_offsCollisionGroup, 2, 4, true);
	SetEntDataEnt2(entity, g_LeaderOffset, target);
	SetEntProp(entity, Prop_Send, "m_isRescued", 0);
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", g_pets[petId][PetScale]);
	
	return true;
}

RemoveClientPet(target)
{
	if (g_clientsPet[target][0] > 0 && IsValidEdict(g_clientsPet[target][0]))
		AcceptEntityInput(g_clientsPet[target][0], "Kill");
		
	g_clientsPet[target][0] = 0;
}

public Action:PlayerSpawn(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsClientInGame(client) && IsPlayerAlive(client)) 
	{
		RemoveClientPet(client);
		CreateTimer(1.0, SpawnPet, client);
	}
}

public Action:SpawnPet(Handle:timer, any:client)
{
	if (!IsPlayerAlive(client))
		return;
	
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "pet", Store_GetClientLoadout(client), OnGetPlayerPet, GetClientSerial(client));
}

public OnGetPlayerPet(ids[], count, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
	
	if (g_zombieReloaded && !ZR_IsClientHuman(client))
		return;

	RemoveClientPet(client);
	
	for (new index = 0; index < count; index++)
	{
		decl String:itemName[32];
		Store_GetItemName(ids[index], itemName, sizeof(itemName));
		
		new pet = -1;
		if (!GetTrieValue(g_petNameIndex, itemName, pet))
		{
			PrintToChat(client, "No pet attributes found.");
			continue;
		}		
		
		AddClientPet(client, pet);
	}
}

public PlayerTeam(Handle:Spawn_Event, const String:Death_Name[], bool:Death_Broadcast )
{
	new client = GetClientOfUserId( GetEventInt(Spawn_Event,"userid") );
	new team = GetEventInt(Spawn_Event, "team");
	
	if (team == 1)
	{
		RemoveClientPet(client);
	}
}

public Action:PlayerDeath(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	RemoveClientPet(client);
}

public ZR_OnClientInfected(client, attacker, bool:motherInfect, bool:respawnOverride, bool:respawn)
{
	RemoveClientPet(client);
}