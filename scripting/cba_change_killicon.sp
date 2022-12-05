#pragma semicolon 1
#include <sourcemod>

#pragma newdecls required

#include <tf_custom_attributes>
#include <stocksoup/var_strings>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

int g_iTheWeaponSlotIWasLastHitBy[MAXPLAYERS + 1] = {-1, ...};

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("object_destroyed", Event_ObjectDestroy, EventHookMode_Pre);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (0 < attacker && attacker <= MaxClients)
	{
		g_iTheWeaponSlotIWasLastHitBy[victim] = GetSlotFromPlayerWeapon(attacker, weapon);
	}
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}
    
    int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
    if(!IsValidClient(killer))
	{
		return Plugin_Continue;
	}
    
    int weapon = GetPlayerWeaponSlot(killer, g_iTheWeaponSlotIWasLastHitBy[client]);
    if (IsValidEntity(weapon))
	{
        char attr[64];
        if (TF2CustAttr_GetString(weapon, "change killicon", attr, sizeof(attr)))
        {
            event.SetString("weapon", attr);
		}
    }
    
    return Plugin_Continue;
}

public Action Event_ObjectDestroy(Event event, const char[] name, bool dontBroadcast)
{
    int killer=GetClientOfUserId(event.GetInt("attacker"));
    if(!IsValidClient(killer))
    {
        return Plugin_Continue;
    }

    int weapon = event.GetInt("weaponid");
    if (IsValidEntity(weapon))
	{
        char attr[64];
        if (TF2CustAttr_GetString(weapon, "change killicon", attr, sizeof(attr)))
        {
            event.SetString("weapon", attr);
		}
    }
    
    return Plugin_Continue;
}

stock int GetSlotFromPlayerWeapon(int client, int weapon)
{
	if(!IsValidClient(client)) return -1;
	
	for (int i = 0; i <= 5; i++)
	{
		if (weapon == GetPlayerWeaponSlot(client, i))
		{
			return i;
		}
	}
	return -1;
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}