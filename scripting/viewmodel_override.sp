/**
 * Weapon model overrides.
 * 
 * Provides three attributes "viewmodel override", "worldmodel override",
 * and "clientmodel override".  Attribute values are full paths to models (include "models/"
 * prefix).
 * 
 * - "viewmodel override" is used exclusively for the owning player's view.
 * - "worldmodel override" is used for other players' views, dropped weapons, and attached
 * sappers.
 * - "clientmodel override" can be used in place of both if they share the same model, and will
 * take priority.
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#include <tf_custom_attributes>
#include <stocksoup/tf/entity_prop_stocks>
#include <stocksoup/tf/econ>
#include <tf_econ_data>

#include <tf2utils>

#define EF_NODRAW (1 << 5)

#define MODEL_NONE_ACTIVE    0
#define MODEL_VIEW_ACTIVE    (1 << 0)
#define MODEL_ARM_ACTIVE     (1 << 1)
#define MODEL_WORLD_ACTIVE   (1 << 2)
#define MODEL_OFFHAND_ACTIVE (1 << 3)

#define TF_ITEM_DEFINDEX_GUNSLINGER 142

int g_iLastViewmodelRef[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
int g_iLastArmModelRef[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
int g_iLastWorldModelRef[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };

int g_iLastOffHandViewmodelRef[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };

public void OnMapStart() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
	HookEvent("post_inventory_application", OnInventoryAppliedPost);
	HookEvent("player_sapped_object", OnObjectSappedPost);
}

public void OnPluginEnd() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			DetachVMs(i);
		}
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public void OnEntityCreated(int entity, const char[] className) {
	if (StrEqual(className, "tf_dropped_weapon")) {
		SDKHook(entity, SDKHook_SpawnPost, OnDroppedWeaponSpawnPost);
	}
}

/**
 * Sets the world model of a dropped weapon.
 */
void OnDroppedWeaponSpawnPost(int weapon) {
	char wm[PLATFORM_MAX_PATH];
	if (TF2CustAttr_GetString(weapon, "clientmodel override", wm, sizeof(wm))
			|| TF2CustAttr_GetString(weapon, "worldmodel override", wm, sizeof(wm))) {
		SetEntityModel(weapon, wm);
		SetWeaponWorldModel(weapon, wm);
	}
}

/**
 * Called when the player's loadout is applied.  Note that other plugins may not have finished
 * applying weapons by this time; however, they should implicitly invoke WeaponSwitchPost
 * (because of GiveNamedItem, etc.) so viewmodels should be correct.
 */
void OnInventoryAppliedPost(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client) {
		return;
	}
	int activeWeapon = TF2_GetClientActiveWeapon(client);
	if (IsValidEntity(activeWeapon)) {
		OnWeaponSwitchPost(client, activeWeapon);
	}
}

/**
 * Called on weapon switch.  Detaches any old viewmodel overrides and attaches replacements.
 */
void OnWeaponSwitchPost(int client, int weapon) {
	DetachVMs(client);
	
	int bitsActiveModels = MODEL_NONE_ACTIVE;
	
	char cm[PLATFORM_MAX_PATH];
	TF2CustAttr_GetString(weapon, "clientmodel override", cm, sizeof(cm));
	
	char vm[PLATFORM_MAX_PATH];
	strcopy(vm, sizeof(vm), cm);
	if ((strlen(vm) || TF2CustAttr_GetString(weapon, "viewmodel override", vm, sizeof(vm)))
			&& FileExists(vm, true)) {
		// override viewmodel by attaching arm and weapon viewmodels
		PrecacheModel(vm);
		
		int weaponvm = TF2_SpawnWearableViewmodel();
		
		SetEntityModel(weaponvm, vm);
		TF2Util_EquipPlayerWearable(client, weaponvm);
		
		g_iLastViewmodelRef[client] = EntIndexToEntRef(weaponvm);
		bitsActiveModels |= MODEL_VIEW_ACTIVE;
	}
	
	char wm[PLATFORM_MAX_PATH];
	strcopy(wm, sizeof(wm), cm);
	if (strlen(wm) || TF2CustAttr_GetString(weapon, "worldmodel override", wm, sizeof(wm))) {
		// this allows other players to see the given weapon with the correct model
		SetWeaponWorldModel(weapon, wm);
		
		// the following shows the weapon in third-person, as m_nModelIndexOverrides is messy
		int weaponwm = TF2_SpawnWearable();
		SetEntityModel(weaponwm, wm);
		
		TF2Util_EquipPlayerWearable(client, weaponwm);
		g_iLastWorldModelRef[client] = EntIndexToEntRef(weaponwm);
		
		SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
		SetEntityRenderColor(weapon, 0, 0, 0, 0);
		
		bitsActiveModels |= MODEL_WORLD_ACTIVE;
	}
	
	if (TF2_GetPlayerClass(client) == TFClass_DemoMan && TF2Util_IsEntityWeapon(weapon)
			&& TF2Util_GetWeaponSlot(weapon) == TFWeaponSlot_Melee) {
		// display shield if player has their melee weapon out on demoman
		int shield = TF2Util_GetPlayerLoadoutEntity(client, 1);
		char ohvm[PLATFORM_MAX_PATH];
		if (TF2CustAttr_GetString(shield, "clientmodel override", ohvm, sizeof(ohvm))
				&& FileExists(ohvm, true)) {
			PrecacheModel(ohvm);
			
			int offhandwearable = TF2_SpawnWearableViewmodel();
			
			SetEntityModel(offhandwearable, ohvm);
			TF2Util_EquipPlayerWearable(client, offhandwearable);
			
			g_iLastOffHandViewmodelRef[client] = EntIndexToEntRef(offhandwearable);
			
			SetEntityModel(shield, ohvm);
			
			bitsActiveModels |= MODEL_OFFHAND_ACTIVE;
		}
	}
	
	if (bitsActiveModels & (MODEL_VIEW_ACTIVE | MODEL_OFFHAND_ACTIVE) == 0) {
		// we need to attach arm viewmodels if we render a new weapon viewmodel
		// or if we have something attached to our offhand
		return;
	}
	
	char armvmPath[PLATFORM_MAX_PATH];
	if (GetArmViewModel(client, armvmPath, sizeof(armvmPath))) {
		// armvmPath might not be precached on the server
		// mainly an issue with the gunslinger variation of the arm model
		PrecacheModel(armvmPath);
		
		int armvm = TF2_SpawnWearableViewmodel();
		
		SetEntityModel(armvm, armvmPath);
		TF2Util_EquipPlayerWearable(client, armvm);
		
		g_iLastArmModelRef[client] = EntIndexToEntRef(armvm);
		
		int clientView = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
		SetEntProp(clientView, Prop_Send, "m_fEffects", EF_NODRAW);
		
		bitsActiveModels |= MODEL_ARM_ACTIVE;
		
		if (bitsActiveModels & MODEL_VIEW_ACTIVE == 0) {
			// we didn't create a custom weapon viewmodel, so we need to render the original one
			// for that weapon
			int itemdef = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			
			if (!TF2Econ_GetItemDefinitionString(itemdef, "model_player", vm, sizeof(vm))) {
				return;
			}
			
			PrecacheModel(vm);
			
			int weaponvm = TF2_SpawnWearableViewmodel();
			
			SetEntityModel(weaponvm, vm);
			TF2Util_EquipPlayerWearable(client, weaponvm);
			
			g_iLastViewmodelRef[client] = EntIndexToEntRef(weaponvm);
			
			bitsActiveModels |= MODEL_VIEW_ACTIVE;
		}
	}
}

/**
 * Allows the use of custom models on sappers attached to buildings.
 */
void OnObjectSappedPost(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidEntity(client)) {
		return;
	}
	
	int sapper = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if (!IsValidEntity(sapper)) {
		return;
	}
	
	char wm[PLATFORM_MAX_PATH];
	if (TF2CustAttr_GetString(sapper, "clientmodel override", wm, sizeof(wm))
			|| TF2CustAttr_GetString(sapper, "worldmodel override", wm, sizeof(wm))) {
		int attachedSapper = event.GetInt("sapperid");
		SetAttachedSapperModel(attachedSapper, wm);
	}
}

bool SetWeaponWorldModel(int weapon, const char[] worldmodel) {
	if (!FileExists(worldmodel, true)) {
		return false;
	}
	
	int model = PrecacheModel(worldmodel);
	if (HasEntProp(weapon, Prop_Send, "m_iWorldModelIndex")) {
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", model);
	}
	
	/**
	 * setting m_nModelIndexOverrides causes firing animations to break, but prevents the
	 * weapon from showing up with the overwritten model in taunts
	 * 
	 * to display the overwritten world model on dropped items see OnDroppedWeaponSpawnPost
	 */
	for (int i = 1; i < GetEntPropArraySize(weapon, Prop_Send, "m_nModelIndexOverrides"); i++) {
		// SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", model, .element = i);
	}
	return true;
}

/**
 * Sets the model on the given building-attached sapper.
 */
bool SetAttachedSapperModel(int sapper, const char[] worldmodel) {
	if (!FileExists(worldmodel, true)) {
		return false;
	}
	SetEntityModel(sapper, worldmodel);
	return true;
}

/**
 * Detaches any custom viewmodels on the client and displays the original viewmodel.
 */
void DetachVMs(int client) {
	MaybeRemoveWearable(client, g_iLastViewmodelRef[client]);
	MaybeRemoveWearable(client, g_iLastArmModelRef[client]);
	
	if (MaybeRemoveWearable(client, g_iLastWorldModelRef[client])) {
		int activeWeapon = TF2_GetClientActiveWeapon(client);
		if (IsValidEntity(activeWeapon)) {
			SetEntityRenderMode(activeWeapon, RENDER_NORMAL);
		}
	}
	
	MaybeRemoveWearable(client, g_iLastOffHandViewmodelRef[client]);
	
	int clientView = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if (IsValidEntity(clientView)) {
		SetEntProp(clientView, Prop_Send, "m_fEffects", 0);
	}
}

/**
 * Returns the arm viewmodel appropriate for the given player.
 */
int GetArmViewModel(int client, char[] buffer, int maxlen) {
	static char armModels[TFClassType][] = {
		"",
		"models/weapons/c_models/c_scout_arms.mdl",
		"models/weapons/c_models/c_sniper_arms.mdl",
		"models/weapons/c_models/c_soldier_arms.mdl",
		"models/weapons/c_models/c_demo_arms.mdl",
		"models/weapons/c_models/c_medic_arms.mdl",
		"models/weapons/c_models/c_heavy_arms.mdl",
		"models/weapons/c_models/c_pyro_arms.mdl",
		"models/weapons/c_models/c_spy_arms.mdl",
		"models/weapons/c_models/c_engineer_arms.mdl"
	};
	
	TFClassType playerClass = TF2_GetPlayerClass(client);
	
	// special case kludge: use gunslinger vm if gunslinger is active on engineer
	if (playerClass == TFClass_Engineer) {
		int meleeWeapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if (IsValidEntity(meleeWeapon)
				&& TF2_GetItemDefinitionIndex(meleeWeapon) == TF_ITEM_DEFINDEX_GUNSLINGER) {
			return strcopy(buffer, maxlen, "models/weapons/c_models/c_engineer_gunslinger.mdl");
		}
	}
	
	return strcopy(buffer, maxlen, armModels[ view_as<int>(playerClass) ]);
}

bool MaybeRemoveWearable(int client, int wearable) {
	if (IsValidEntity(wearable)) {
		// the below function does not take entrefs.
		TF2_RemoveWearable(client, EntRefToEntIndex(wearable));
		return true;
	}
	return false;
}

/**
 * Creates a wearable viewmodel.
 * This sets EF_BONEMERGE | EF_BONEMERGE_FASTCULL when equipped.
 */
stock int TF2_SpawnWearableViewmodel() {
	int wearable = CreateEntityByName("tf_wearable_vm");
	
	if (IsValidEntity(wearable)) {
		SetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex", DEFINDEX_UNDEFINED);
		DispatchSpawn(wearable);
	}
	return wearable;
}
