#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>

#undef REQUIRE_PLUGIN
#include <zombiereloaded>

new bool:g_zombieReloaded = false;

new g_clientsJetpackEnabled[MAXPLAYERS+1];
new bool:Delay[MAXPLAYERS+1], i_jumps[MAXPLAYERS+1];
new g_LastButtons[MAXPLAYERS+1];
new jetpackused[MAXPLAYERS+1];

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
	name        = "[Store] Jetpack",
	author      = "alongub",
	description = "Jetpack component for [Store]",
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

	Store_RegisterItemType("jetpack", OnJetpackUsed);
	
	g_zombieReloaded = LibraryExists("zombiereloaded");
	HookEvent("round_start", Event_RoundStart);
}

public Action:Event_RoundStart(Handle:event, const String:weaponName[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		jetpackused[i] = 0;
		g_clientsJetpackEnabled[i] = false;
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

public bool:OnJetpackUsed(client, itemId, bool:equipped)
{
	decl String:currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));
	
	decl String:mapType[3];
	strcopy(mapType, 3, currentMap);

 	// Really shouldn't be hardcoded.
	if (jetpackused[client] > 2) 
	{
        PrintToChat(client, "%t", "Limit item uses in a round", 2);
        return false;
	}
    
	if (StrEqual(mapType, "ze", false))
	{
		PrintToChat(client, "You can't use the jetpack in escape maps.");
		return false;
	}
	
	if (g_zombieReloaded && !ZR_IsClientHuman(client))
	{
		PrintToChat(client, "%t", "Must be human to use");
		return false;
	}
	
	g_clientsJetpackEnabled[client] = true;
	i_jumps[client] = 0;
	Delay[client] = false;
	jetpackused[client]++;
    
	return true;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!IsPlayerAlive(client))
		return Plugin_Continue;

	if (g_clientsJetpackEnabled[client] && g_zombieReloaded && ZR_IsClientHuman(client) && !Delay[client])
	{
		if (buttons & IN_JUMP && buttons & IN_DUCK)
		{
			if (0 <= i_jumps[client] <= 23)
			{
				i_jumps[client]++;
		
				new Float:ClientEyeAngle[3];
				new Float:ClientAbsOrigin[3];
				new Float:Velocity[3];
				
				GetClientEyeAngles(client, ClientEyeAngle);
				GetClientAbsOrigin(client, ClientAbsOrigin);
				
				ClientEyeAngle[0] = -40.0;
				GetAngleVectors(ClientEyeAngle, Velocity, NULL_VECTOR, NULL_VECTOR);
				
				ScaleVector(Velocity, 500.0);
				
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Velocity);
				
				Delay[client] = true;
				CreateTimer(0.1, DelayOff, client);
				
				CreateEffect(client, ClientAbsOrigin, ClientEyeAngle);
			}
			else
			{
				g_clientsJetpackEnabled[client] = false;
			}
		}
	}
	
	g_LastButtons[client] = buttons;
	
	return Plugin_Continue;
}

CreateEffect(client, Float:vecorigin[3], Float:vecangle[3])
{
	vecangle[0] = 110.0;
	vecorigin[2] += 25.0;
	
	new String:tName[128];
	Format(tName, sizeof(tName), "target%i", client);
	DispatchKeyValue(client, "targetname", tName);
	
	// Create the fire
	new String:fire_name[128];
	Format(fire_name, sizeof(fire_name), "fire%i", client);
	new fire = CreateEntityByName("env_steam");
	DispatchKeyValue(fire,"targetname", fire_name);
	DispatchKeyValue(fire, "parentname", tName);
	DispatchKeyValue(fire,"SpawnFlags", "1");
	DispatchKeyValue(fire,"Type", "0");
	DispatchKeyValue(fire,"InitialState", "1");
	DispatchKeyValue(fire,"Spreadspeed", "10");
	DispatchKeyValue(fire,"Speed", "400");
	DispatchKeyValue(fire,"Startsize", "20");
	DispatchKeyValue(fire,"EndSize", "600");
	DispatchKeyValue(fire,"Rate", "30");
	DispatchKeyValue(fire,"JetLength", "200");
	DispatchKeyValue(fire,"RenderColor", "255 100 30");
	DispatchKeyValue(fire,"RenderAmt", "180");
	DispatchSpawn(fire);
	
	TeleportEntity(fire, vecorigin, vecangle, NULL_VECTOR);
	SetVariantString(tName);
	AcceptEntityInput(fire, "SetParent", fire, fire, 0);
	
	AcceptEntityInput(fire, "TurnOn");
	
	new String:fire_name2[128];
	Format(fire_name2, sizeof(fire_name2), "fire2%i", client);
	new fire2 = CreateEntityByName("env_steam");
	DispatchKeyValue(fire2,"targetname", fire_name2);
	DispatchKeyValue(fire2, "parentname", tName);
	DispatchKeyValue(fire2,"SpawnFlags", "1");
	DispatchKeyValue(fire2,"Type", "1");
	DispatchKeyValue(fire2,"InitialState", "1");
	DispatchKeyValue(fire2,"Spreadspeed", "10");
	DispatchKeyValue(fire2,"Speed", "400");
	DispatchKeyValue(fire2,"Startsize", "20");
	DispatchKeyValue(fire2,"EndSize", "600");
	DispatchKeyValue(fire2,"Rate", "10");
	DispatchKeyValue(fire2,"JetLength", "200");
	DispatchSpawn(fire2);
	TeleportEntity(fire2, vecorigin, vecangle, NULL_VECTOR);
	SetVariantString(tName);
	AcceptEntityInput(fire2, "SetParent", fire2, fire2, 0);
	AcceptEntityInput(fire2, "TurnOn");
			
	new Handle:firedata = CreateDataPack();
	WritePackCell(firedata, fire);
	WritePackCell(firedata, fire2);
	CreateTimer(0.5, Killfire, firedata);
}

public Action:Killfire(Handle:timer, Handle:firedata)
{
	
	ResetPack(firedata);
	new ent1 = ReadPackCell(firedata);
	new ent2 = ReadPackCell(firedata);
	CloseHandle(firedata);
	
	new String:classname[256];
	
	if (IsValidEntity(ent1))
	{
		AcceptEntityInput(ent1, "TurnOff");
		GetEdictClassname(ent1, classname, sizeof(classname));
	
		if (!strcmp(classname, "env_steam", false))
			AcceptEntityInput(ent1, "kill");
	}
	
	if (IsValidEntity(ent2))
		{
		AcceptEntityInput(ent2, "TurnOff");
		GetEdictClassname(ent2, classname, sizeof(classname));
		if (StrEqual(classname, "env_steam", false))
						AcceptEntityInput(ent2, "kill");
		}
}
	
public Action:DelayOff(Handle:timer, any:client)
{
	Delay[client] = false;
}