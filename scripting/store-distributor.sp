#pragma semicolon 1

#include <sourcemod>
#include <store>

new Float:g_timeInSeconds;
new g_creditsPerTick;

public Plugin:myinfo =
{
	name        = "[Store] Distributor",
	author      = "alongub",
	description = "Distributor component for [Store]",
	version     = PL_VERSION,
	url         = "https://github.com/alongubkin/store"
};

/**
 * Plugin is loading.
 */
public OnPluginStart() 
{
	LoadConfig();
	CreateTimer(g_timeInSeconds, ForgivePoints, _, TIMER_REPEAT);
}

/**
 * Load plugin config.
 */
LoadConfig() 
{
	new Handle:kv = CreateKeyValues("root");
	
	decl String:path[100];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/distributor.cfg");
	
	if (!FileToKeyValues(kv, path)) 
	{
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	g_timeInSeconds = KvGetFloat(kv, "time_in_seconds", 180.0);
	g_creditsPerTick = KvGetNum(kv, "credits_per_tick", 3);

	CloseHandle(kv);
}


public Action:ForgivePoints(Handle:timer)
{
	new accountIds[MaxClients];
	new count = 0;
	
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && !IsClientObserver(i))
		{
			accountIds[count] = Store_GetClientAccountID(i);
			count++;
		}
	}

	Store_GiveCreditsToUsers(accountIds, count, g_creditsPerTick);
}