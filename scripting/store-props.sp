#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>
#include <smjansson>
#include <smartdm>

#undef REQUIRE_PLUGIN
#include <zombiereloaded>

enum Prop
{
	String:PropName[32],
	String:PropModelPath[PLATFORM_MAX_PATH],
	PropHeight
}

new g_props[128][Prop];
new g_propCount = 0;

new g_iPropNo[MAXPLAYERS+1];

new bool:g_zombieReloaded = false;

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
	name        = "[Store] Props",
	author      = "alongub",
	description = "Props component for [Store]",
	version     = PL_VERSION,
	url         = "https://github.com/alongubkin/store"
};

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");
	
	Store_RegisterItemType("prop", OnPropUsed, LoadItem);
	
	g_zombieReloaded = LibraryExists("zombiereloaded");
	HookEvent("round_start", Event_RoundStart);
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

public Store_OnReloadItems() 
{
	g_propCount = 0;
}

public LoadItem(const String:itemName[], const String:attrs[])
{
	strcopy(g_props[g_propCount][PropName], STORE_MAX_NAME_LENGTH, itemName);

	new Handle:json = json_load(attrs);
	json_object_get_string(json, "model", g_props[g_propCount][PropModelPath], PLATFORM_MAX_PATH);

	if (strcmp(g_props[g_propCount][PropModelPath], "") != 0 && (FileExists(g_props[g_propCount][PropModelPath]) || FileExists(g_props[g_propCount][PropModelPath], true)))
	{
		PrecacheModel(g_props[g_propCount][PropModelPath]);
		Downloader_AddFileToDownloadsTable(g_props[g_propCount][PropModelPath]);
	}

	g_props[g_propCount][PropHeight] = json_object_get_int(json, "height");

	CloseHandle(json);

	g_propCount++;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		g_iPropNo[i] = 0;
	}
}

public bool:OnPropUsed(client, itemId, bool:equipped)
{
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "%t", "Must be alive to use");
		return false;
	}

	if (g_iPropNo[client] > 2)
	{
		PrintToChat(client, "%t", "Limit item uses in a round", 2);
		return false;
	}

	decl String:currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));
	
	decl String:mapType[3];
	strcopy(mapType, 3, currentMap);

	if (StrEqual(mapType, "ze", false))
	{
		PrintToChat(client, "You can't use props in escape maps.");
		return false;
	}

	if (g_zombieReloaded && !ZR_IsClientHuman(client))
	{
		PrintToChat(client, "%t", "Must be human to use");
		return false;	
	}
	
	decl String:name[32];
	Store_GetItemName(itemId, name, sizeof(name));
	
	for (new prop = 0; prop < g_propCount; prop++)
	{
		if (StrEqual(g_props[prop][PropName], name))
		{
			decl Ent;	 
			PrecacheModel(g_props[prop][PropModelPath], true);
			Ent = CreateEntityByName("prop_physics_override"); 
			
			new String:EntName[256];
			Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", client, g_iPropNo[client]);
			
			DispatchKeyValue(Ent, "physdamagescale", "0.0");
			DispatchKeyValue(Ent, "model", g_props[prop][PropModelPath]);
			DispatchKeyValue(Ent, "targetname", EntName);
			DispatchSpawn(Ent);

			decl Float:FurnitureOrigin[3];
			decl Float:ClientOrigin[3];
			decl Float:EyeAngles[3];
			GetClientEyeAngles(client, EyeAngles);
			GetClientAbsOrigin(client, ClientOrigin);
			
			FurnitureOrigin[0] = (ClientOrigin[0] + (50 * Cosine(DegToRad(EyeAngles[1]))));
			FurnitureOrigin[1] = (ClientOrigin[1] + (50 * Sine(DegToRad(EyeAngles[1]))));
			FurnitureOrigin[2] = (ClientOrigin[2] + g_props[prop][PropHeight]);
			
			TeleportEntity(Ent, FurnitureOrigin, NULL_VECTOR, NULL_VECTOR);
			SetEntityMoveType(Ent, MOVETYPE_VPHYSICS);

			g_iPropNo[client]++;
			break;
		}
	}
	
	return true;
}