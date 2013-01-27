#pragma semicolon 1

#include <sourcemod>
#include <store>
#include <scp>
#include <smjansson>

enum Title
{
	String:TitleName[32],
	String:TitleText[64],
	String:TitleColor[10]
}

new g_titles[1024][Title];
new g_titleCount = 0;

new g_clientTitles[MAXPLAYERS+1];

new Handle:g_titlesNameIndex = INVALID_HANDLE;

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
	Store_RegisterItemType("title", Store_ItemUseCallback:OnEquip, Store_ItemGetAttributesCallback:LoadItem);
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
	g_clientTitles[client] = -1;
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "title", Store_GetClientLoadout(client), OnGetPlayerTitle, GetClientSerial(client));
}

public Store_OnClientLoadoutChanged(client)
{
	g_clientTitles[client] = -1;
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "title", Store_GetClientLoadout(client), OnGetPlayerTitle, GetClientSerial(client));
}

public Store_OnReloadItems() 
{
	if (g_titlesNameIndex != INVALID_HANDLE)
		CloseHandle(g_titlesNameIndex);
		
	g_titlesNameIndex = CreateTrie();
	g_titleCount = 0;
}

public OnGetPlayerTitle(titles[], count, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	for (new index = 0; index < count; index++)
	{
		decl String:itemName[32];
		Store_GetItemName(titles[index], itemName, sizeof(itemName));
		
		new title = -1;
		if (!GetTrieValue(g_titlesNameIndex, itemName, title))
		{
			PrintToChat(client, "No title attributes found.");
			continue;
		}
		
		g_clientTitles[client] = title;
		break;
	}
}

public LoadItem(const String:itemName[], const String:attrs[])
{
	strcopy(g_titles[g_titleCount][TitleName], 32, itemName);
		
	SetTrieValue(g_titlesNameIndex, g_titles[g_titleCount][TitleName], g_titleCount);
	
	new Handle:json = json_load(attrs);
	json_object_get_string(json, "text", g_titles[g_titleCount][TitleText], 64);
	json_object_get_string(json, "color", g_titles[g_titleCount][TitleColor], 10);	

	CloseHandle(json);

	g_titleCount++;
}

public bool:OnEquip(client, itemId, bool:equipped)
{
	decl String:name[32];
	Store_GetItemName(itemId, name, sizeof(name));

	if (equipped)
	{
		g_clientTitles[client] = -1;
		
		decl String:displayName[64];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "You have unequipped %s.", displayName);
	}
	else
	{
		new title = -1;
		if (!GetTrieValue(g_titlesNameIndex, name, title))
		{
			PrintToChat(client, "No title attributes found.");
			return false;
		}
		
		g_clientTitles[client] = title;
		
		decl String:displayName[64];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "You have equipped %s.", displayName);	
	}
	
	return true;
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	if (g_clientTitles[author] != -1)
	{		
		Format(name, MAXLENGTH_NAME, "\x08%s%s\x03 %s", g_titles[g_clientTitles[author]][TitleColor], g_titles[g_clientTitles[author]][TitleText], name);		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}