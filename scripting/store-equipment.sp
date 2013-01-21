#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>

#undef REQUIRE_PLUGIN
#include <ToggleEffects>
#include <zombiereloaded>

enum Equipment
{
	String:EquipmentName[32],
	String:EquipmentModelPath[PLATFORM_MAX_PATH], 
	Float:EquipmentPosition[3],
	Float:EquipmentAngles[3],
	String:EquipmentFlag[2],
	String:EquipmentAttachment[32]
}

enum EquipmentPlayerModelSettings
{
	String:EquipmentName[32],
	String:PlayerModelPath[PLATFORM_MAX_PATH],
	Float:Position[3],
	Float:Angles[3]
}

enum EquipmentEntity
{
	String:EquipmentEntityName[32],
	EquipmentEntityIndex
}

new Handle:g_hLookupAttachment = INVALID_HANDLE;

new bool:g_zombieReloaded;
new bool:g_toggleEffects;

new g_equipment[1024][Equipment];
new g_equipmentCount = 0;

new Handle:g_equipmentNameIndex = INVALID_HANDLE;
new Handle:g_loadoutSlotList = INVALID_HANDLE;

new g_playerModels[1024][EquipmentPlayerModelSettings];
new g_playerModelCount = 0;

new g_iEquipment[MAXPLAYERS+1][32];

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("ZR_IsClientHuman"); 
	MarkNativeAsOptional("ZR_IsClientZombie"); 
	
	return APLRes_Success;
}

public OnPluginStart()
{
	Store_RegisterItemType("equipment", Store_ItemUseCallback:OnEquip);
		
	LoadEquipment();
	
	g_loadoutSlotList = CreateArray(ByteCountToCells(32));
	
	g_zombieReloaded = LibraryExists("zombiereloaded");
	g_toggleEffects = LibraryExists("ToggleEffects");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	
	new Handle:hGameConf = LoadGameConfigFile("store-equipment.gamedata");
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "LookupAttachment");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hLookupAttachment = EndPrepSDKCall()	
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

public OnClientDisconnect(client)
{
	UnequipAll(client);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!g_zombieReloaded || (g_zombieReloaded && ZR_IsClientHuman(client)))
		CreateTimer(1.0, SpawnTimer, GetClientSerial(client));
	else
		UnequipAll(client);
	
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	UnequipAll(GetClientOfUserId(GetEventInt(event, "userid")));
	return Plugin_Continue;
}

public ZR_OnClientInfected(client, attacker, bool:motherInfect, bool:respawnOverride, bool:respawn)
{
	UnequipAll(client);
}

public ZR_OnClientRespawned(client, ZR_RespawnCondition:condition)
{
	UnequipAll(client);
}

public Action:SpawnTimer(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return Plugin_Continue;
	
	if (g_zombieReloaded && !ZR_IsClientHuman(client))
		return Plugin_Continue;
		
	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "equipment", Store_GetClientLoadout(client), OnGetPlayerEquipment, serial);
	
	return Plugin_Continue;
}

public LoadEquipment()
{	
	g_equipmentCount = 0;
	
	new String:sConfig[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfig, PLATFORM_MAX_PATH, "configs/store/items/equipment.txt");
	
	new Handle:kv = CreateKeyValues("equipment");
	FileToKeyValues(kv, sConfig);
	
	if (g_equipmentNameIndex != INVALID_HANDLE)
		CloseHandle(g_equipmentNameIndex);
		
	g_equipmentNameIndex = CreateTrie();
	
	new Float:temp[3];
		
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			KvGetSectionName(kv, g_equipment[g_equipmentCount][EquipmentName], 64);

			SetTrieValue(g_equipmentNameIndex, g_equipment[g_equipmentCount][EquipmentName], g_equipmentCount);
			
			KvGetString(kv, "model", g_equipment[g_equipmentCount][EquipmentModelPath], PLATFORM_MAX_PATH);
			KvGetString(kv, "flag", g_equipment[g_equipmentCount][EquipmentFlag], 2);
			KvGetString(kv, "attachment", g_equipment[g_equipmentCount][EquipmentAttachment], 32);
			
			KvGetVector(kv, "position", temp);
			g_equipment[g_equipmentCount][EquipmentPosition] = temp;
			
			KvGetVector(kv, "angles", temp);
			g_equipment[g_equipmentCount][EquipmentAngles] = temp;			
		
			if (strcmp(g_equipment[g_equipmentCount][EquipmentModelPath], "") != 0 && (FileExists(g_equipment[g_equipmentCount][EquipmentModelPath]) || FileExists(g_equipment[g_equipmentCount][EquipmentModelPath], true)))
			{
				PrecacheModel(g_equipment[g_equipmentCount][EquipmentModelPath], true);
			}
      		
			if (KvJumpToKey(kv, "playermodels"))
			{
				new Handle:playerModelsKv = CreateKeyValues("playermodels");
				KvCopySubkeys(kv, playerModelsKv);

				KvGotoFirstSubKey(playerModelsKv);
				
				do
				{
					KvGetSectionName(playerModelsKv, g_playerModels[g_playerModelCount][PlayerModelPath], PLATFORM_MAX_PATH);
					strcopy(g_playerModels[g_playerModelCount][EquipmentName], 64, g_equipment[g_equipmentCount][EquipmentName]);

					KvGetVector(playerModelsKv, "position", temp);
					g_playerModels[g_playerModelCount][Position] = temp;

					KvGetVector(playerModelsKv, "angles", temp);
					g_playerModels[g_playerModelCount][Angles] = temp;

					g_playerModelCount++;
				} while (KvGotoNextKey(playerModelsKv));

				KvGoBack(kv);
				CloseHandle(playerModelsKv);
      		}
      			
			g_equipmentCount++;
		} while (KvGotoNextKey(kv));
	}
	
	CloseHandle(kv);
}

public OnGetPlayerEquipment(ids[], count, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (client == 0)
		return;
		
	if (!IsClientInGame(client))
		return;
	
	if (!IsPlayerAlive(client))
		return;
		
	for (new index = 0; index < count; index++)
	{
		decl String:itemName[32];
		Store_GetItemName(ids[index], itemName, sizeof(itemName));
		
		decl String:loadoutSlot[32];
		Store_GetItemLoadoutSlot(ids[index], loadoutSlot, sizeof(loadoutSlot));
		
		new loadoutSlotIndex = FindStringInArray(g_loadoutSlotList, loadoutSlot);
		
		if (loadoutSlotIndex == -1)
			loadoutSlotIndex = PushArrayString(g_loadoutSlotList, loadoutSlot);
		
		Unequip(client, loadoutSlotIndex)
		
		if (!g_zombieReloaded || (g_zombieReloaded && ZR_IsClientHuman(client)))
			Equip(client, loadoutSlotIndex, itemName);
	}
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
	
	new loadoutSlotIndex = FindStringInArray(g_loadoutSlotList, loadoutSlot);
	
	if (loadoutSlotIndex == -1)
		loadoutSlotIndex = PushArrayString(g_loadoutSlotList, loadoutSlot);
		
	if (equipped)
	{
		if (!Unequip(client, loadoutSlotIndex))
			return false;
	
		decl String:displayName[64];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "You have unequipped the %s.", displayName);
		return true;
	}
	else
	{
		if (!Equip(client, loadoutSlotIndex, name))
			return false;
		
		decl String:displayName[64];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "You have equipped the %s.", displayName);
		return true;
	}
}

bool:Equip(client, loadoutSlot, const String:name[])
{
	Unequip(client, loadoutSlot);
		
	new equipment = -1;
	if (!GetTrieValue(g_equipmentNameIndex, name, equipment))
	{
		PrintToChat(client, "No equipment attributes found.");
		return false;
	}
	
	if (!LookupAttachment(client, g_equipment[equipment][EquipmentAttachment])) 
	{
		PrintToChat(client, "You player model doesn't support equipment. %s", g_equipment[equipment][EquipmentAttachment]);
		return false;
	}
	
	new Float:or[3];
	new Float:ang[3];
	new Float:fForward[3];
	new Float:fRight[3];
	new Float:fUp[3];
	
	GetClientAbsOrigin(client,or);
	GetClientAbsAngles(client,ang);

	new String:clientModel[PLATFORM_MAX_PATH];
	GetClientModel(client, clientModel, sizeof(clientModel));

	new playerModel = -1;
	for (new j = 0; j < g_playerModelCount; j++)
	{
		if (StrEqual(g_equipment[equipment][EquipmentName], g_playerModels[j][EquipmentName]) && StrEqual(clientModel, g_playerModels[j][PlayerModelPath], false))
		{
			playerModel = j;
			break;
		}
	}

	if (playerModel == -1)
	{
		ang[0] += g_equipment[equipment][EquipmentAngles][0];
		ang[1] += g_equipment[equipment][EquipmentAngles][1];
		ang[2] += g_equipment[equipment][EquipmentAngles][2];
	}
	else
	{
		ang[0] += g_playerModels[playerModel][Angles][0];
		ang[1] += g_playerModels[playerModel][Angles][1];
		ang[2] += g_playerModels[playerModel][Angles][2];		
	}

	new Float:fOffset[3];

	if (playerModel == -1)
	{
		fOffset[0] = g_equipment[equipment][EquipmentPosition][0];
		fOffset[1] = g_equipment[equipment][EquipmentPosition][1];
		fOffset[2] = g_equipment[equipment][EquipmentPosition][2];	
	}
	else
	{
		fOffset[0] = g_playerModels[playerModel][Position][0];
		fOffset[1] = g_playerModels[playerModel][Position][1];
		fOffset[2] = g_playerModels[playerModel][Position][2];		
	}
		
	GetAngleVectors(ang, fForward, fRight, fUp);

	or[0] += fRight[0]*fOffset[0]+fForward[0]*fOffset[1]+fUp[0]*fOffset[2];
	or[1] += fRight[1]*fOffset[0]+fForward[1]*fOffset[1]+fUp[1]*fOffset[2];
	or[2] += fRight[2]*fOffset[0]+fForward[2]*fOffset[1]+fUp[2]*fOffset[2];

	new ent = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(ent, "model", g_equipment[equipment][EquipmentModelPath]);
	DispatchKeyValue(ent, "spawnflags", "256");
	DispatchKeyValue(ent, "solid", "0");
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	
	DispatchSpawn(ent);	
	AcceptEntityInput(ent, "TurnOn", ent, ent, 0);
	
	g_iEquipment[client][loadoutSlot] = ent;
	
	SDKHook(ent, SDKHook_SetTransmit, ShouldHide);
	
	TeleportEntity(ent, or, ang, NULL_VECTOR); 
	
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client, ent, 0);
	
	SetVariantString(g_equipment[equipment][EquipmentAttachment]);
	AcceptEntityInput(ent, "SetParentAttachmentMaintainOffset", ent, ent, 0);
	
	return true;
}

bool:Unequip(client, loadoutSlot)
{      
	if (g_iEquipment[client][loadoutSlot] != 0 && IsValidEdict(g_iEquipment[client][loadoutSlot]))
	{
		SDKUnhook(g_iEquipment[client][loadoutSlot], SDKHook_SetTransmit, ShouldHide);
		AcceptEntityInput(g_iEquipment[client][loadoutSlot], "Kill");
	}
	
	g_iEquipment[client][loadoutSlot] = 0;
	return true;
}

UnequipAll(client)
{
	for (new index = 0, size = GetArraySize(g_loadoutSlotList); index < size; index++)
		Unequip(client, index);
}

public Action:ShouldHide(ent, client)
{
	if (g_toggleEffects)
		if (!ShowClientEffects(client))
			return Plugin_Handled;
			
	for (new index = 0, size = GetArraySize(g_loadoutSlotList); index < size; index++)
	{
		if (ent == g_iEquipment[client][index])
			return Plugin_Handled;
	}
	
	if (IsClientInGame(client) && GetEntProp(client, Prop_Send, "m_iObserverMode") == 4 && GetEntPropEnt(client, Prop_Send, "m_hObserverTarget") >= 0)
	{
		for (new index = 0, size = GetArraySize(g_loadoutSlotList); index < size; index++)
		{
			if(ent == g_iEquipment[GetEntPropEnt(client, Prop_Send, "m_hObserverTarget")][index])
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

stock bool:LookupAttachment(client, String:point[])
{
	if (g_hLookupAttachment == INVALID_HANDLE)
		return false;

	if (client <= 0 || !IsClientInGame(client)) 
		return false;
	
	return SDKCall(g_hLookupAttachment, client, point);
}