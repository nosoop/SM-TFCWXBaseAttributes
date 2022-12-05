#pragma semicolon 1
#include <sourcemod>

#pragma newdecls required

#include <tf_custom_attributes>
#include <stocksoup/var_strings>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

int g_iTheWeaponSlotIWasLastHitBy[MAXPLAYERS + 1] = {-1, ...};

public void OnMapStart() {	
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
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

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	int iKiller = GetClientOfUserId(event.GetInt("attacker"));
	
	if (!IsValidClient(iKiller))
    {
        return Plugin_Continue;
    }
	
	int weapon = GetPlayerWeaponSlot(iKiller, g_iTheWeaponSlotIWasLastHitBy[client]);

	if (IsValidEntity(weapon))
	{
		char WeaponLogClassname[64];
		TF2CustAttr_GetString(weapon, "custom weapon logname", WeaponLogClassname, sizeof(WeaponLogClassname));
		if (TF2CustAttr_GetString(weapon, "custom weapon logname", WeaponLogClassname, sizeof(WeaponLogClassname)))
		{
			SetEventString(event, "weapon_logclassname", WeaponLogClassname);
		}
	}

	if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER) return Plugin_Continue;

	g_iTheWeaponSlotIWasLastHitBy[client] = -1;

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