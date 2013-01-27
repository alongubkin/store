#pragma semicolon 1

#include <sourcemod>
#include <store>

/**
 * Called when all plugins are loaded.
 */
public OnAllPluginsLoaded() 
{
	CreateTimer(180.0, ForgivePoints, _, TIMER_REPEAT);
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

	Store_GiveCreditsToUsers(accountIds, count, 3);
}