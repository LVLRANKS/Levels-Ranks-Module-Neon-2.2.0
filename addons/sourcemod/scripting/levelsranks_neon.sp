#pragma semicolon 1
#pragma newdecls required

#include <clientprefs>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iNeonLevel,
		g_iNeonCount,
		g_iRank[MAXPLAYERS+1],
		g_iNeon[MAXPLAYERS+1],
		g_iNeonChoose[MAXPLAYERS+1],
		g_iNeonActivator[MAXPLAYERS+1];
char		g_sNeonName[64][32],
		g_sNeonColor[64][96];
Handle	g_hNeons = null;

public Plugin myinfo = {name = "[LR] Module - Neon", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS, Engine_TF2: LogMessage("[%s Neon] Запущен успешно", PLUGIN_NAME);
		default: SetFailState("[%s Neon] Плагин работает только на CS:GO, CS:S или TF2", PLUGIN_NAME);
	}
}

public void OnPluginStart()
{
	LR_ModuleCount();
	HookEvent("player_spawn", Event_Neon);
	HookEvent("player_death", Event_Neon);
	HookEvent("player_team", Event_Neon);

	g_hNeons = RegClientCookie("LR_Neons", "LR_Neons", CookieAccess_Private);
	LoadTranslations("levels_ranks_neon.phrases");
	
	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
		if(IsClientInGame(iClient))
		{
			if(AreClientCookiesCached(iClient))
			{
				OnClientCookiesCached(iClient);
			}
		}
	}
}

public void OnMapStart() 
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/neons.ini");
	KeyValues hLR_Neons = new KeyValues("LR_Neons");

	if(!hLR_Neons.ImportFromFile(sPath) || !hLR_Neons.GotoFirstSubKey())
	{
		SetFailState("[%s Neon] : фатальная ошибка - файл не найден (%s)", PLUGIN_NAME, sPath);
	}

	hLR_Neons.Rewind();

	if(hLR_Neons.JumpToKey("Settings"))
	{
		g_iNeonLevel = hLR_Neons.GetNum("rank", 0);
	}
	else SetFailState("[%s Neon] : фатальная ошибка - секция Settings не найдена", PLUGIN_NAME);

	hLR_Neons.Rewind();

	if(hLR_Neons.JumpToKey("Colors"))
	{
		g_iNeonCount = 0;
		hLR_Neons.GotoFirstSubKey();

		do
		{
			hLR_Neons.GetSectionName(g_sNeonName[g_iNeonCount], sizeof(g_sNeonName[]));
			hLR_Neons.GetString("color", g_sNeonColor[g_iNeonCount], sizeof(g_sNeonColor[]));
			g_iNeonCount++;
		}
		while(hLR_Neons.GotoNextKey());
	}
	else SetFailState("[%s Neon] : фатальная ошибка - секция Colors не найдена", PLUGIN_NAME);
	delete hLR_Neons;
}

public void Event_Neon(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	switch(sEvName[7])
	{
		case 't':
		{
			int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			if(IsValidClient(iClient)) RemoveNeon(iClient);
		}

		case 's':
		{
			int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			if(IsValidClient(iClient) && !g_iNeonActivator[iClient] && g_iRank[iClient] >= g_iNeonLevel)
			{
				g_iRank[iClient] = LR_GetClientRank(iClient);
				SetClientNeon(iClient);
			}
		}

		case 'd':
		{
			int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			if(IsValidClient(iClient)) RemoveNeon(iClient);
		}
	}
}

public void LR_OnMenuCreated(int iClient, int iRank, Menu& hMenu)
{
	if(iRank == g_iNeonLevel)
	{
		char sText[64];
		SetGlobalTransTarget(iClient);
		g_iRank[iClient] = LR_GetClientRank(iClient);
		if(g_iRank[iClient] >= g_iNeonLevel)
		{
			FormatEx(sText, sizeof(sText), "%t", "Neon_RankOpened");
			hMenu.AddItem("Neons", sText);
		}
		else
		{
			FormatEx(sText, sizeof(sText), "%t", "Neon_RankClosed", g_iNeonLevel);
			hMenu.AddItem("Neons", sText, ITEMDRAW_DISABLED);
		}
	}
}

public void LR_OnMenuItemSelected(int iClient, int iRank, const char[] sInfo)
{
	if(iRank == g_iNeonLevel)
	{
		if(strcmp(sInfo, "Neons") == 0)
		{
			NeonsMenu(iClient, 0);
		}
	}
}

public void NeonsMenu(int iClient, int iList)
{
	char sID[4], sText[192];
	SetGlobalTransTarget(iClient);
	g_iRank[iClient] = LR_GetClientRank(iClient);
	Menu Mmenu = new Menu(NeonsMenuHandler);

	FormatEx(sText, sizeof(sText), "%t", "Neon_RankOpened");
	Mmenu.SetTitle("%s | %s\n ", PLUGIN_NAME, sText);

	switch(g_iNeonActivator[iClient])
	{
		case 0: FormatEx(sText, sizeof(sText), "%t\n ", "Neon_On");
		case 1: FormatEx(sText, sizeof(sText), "%t\n ", "Neon_Off");
	}

	Mmenu.AddItem("-1", sText);

	for(int i = 0; i < g_iNeonCount; i++)
	{
		IntToString(i, sID, sizeof(sID));
		FormatEx(sText, sizeof(sText), "%s", g_sNeonName[i]);
		Mmenu.AddItem(sID, sText);
	}

	Mmenu.ExitBackButton = true;
	Mmenu.ExitButton = true;
	Mmenu.DisplayAt(iClient, iList, MENU_TIME_FOREVER);
}

public int NeonsMenuHandler(Menu Mmenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel: if(iSlot == MenuCancel_ExitBack) {LR_MenuInventory(iClient);}
		case MenuAction_Select:
		{
			char sID[4];
			Mmenu.GetItem(iSlot, sID, sizeof(sID));

			if(StringToInt(sID) == -1)
			{
				switch(g_iNeonActivator[iClient])
				{
					case 0:
					{
						g_iNeonActivator[iClient] = 1;
						RemoveNeon(iClient);
						NeonsMenu(iClient, GetMenuSelectionPosition());
					}
					case 1:
					{
						g_iNeonActivator[iClient] = 0;
						if(IsPlayerAlive(iClient)) SetClientNeon(iClient);
						NeonsMenu(iClient, GetMenuSelectionPosition());
					}
				}
			}
			else
			{
				g_iNeonChoose[iClient] = StringToInt(sID);
				if(IsPlayerAlive(iClient) && !g_iNeonActivator[iClient]) SetClientNeon(iClient);
				NeonsMenu(iClient, GetMenuSelectionPosition());
			}
		}
	}
}

void SetClientNeon(int iClient)
{
	RemoveNeon(iClient);

	float fClientOrigin[3], fPos[3];
	GetClientAbsOrigin(iClient, fClientOrigin);

	fPos[0] = fClientOrigin[0];
	fPos[1] = fClientOrigin[1];
	fPos[2] = fClientOrigin[2] + 30;

	g_iNeon[iClient] = CreateEntityByName("light_dynamic");
	DispatchKeyValue(g_iNeon[iClient], "brightness", "5");

	char str_color[25]; 
	Format(str_color, 25, "%s", g_sNeonColor[g_iNeonChoose[iClient]]);
	DispatchKeyValue(g_iNeon[iClient], "_light", str_color);
	DispatchKeyValue(g_iNeon[iClient], "spotlight_radius", "75");
	DispatchKeyValue(g_iNeon[iClient], "distance", "200");
	DispatchKeyValue(g_iNeon[iClient], "style", "0");
	SetEntPropEnt(g_iNeon[iClient], Prop_Send, "m_hOwnerEntity", iClient);

	if(DispatchSpawn(g_iNeon[iClient]))
	{
		AcceptEntityInput(g_iNeon[iClient], "TurnOn");
		TeleportEntity(g_iNeon[iClient], fPos, NULL_VECTOR, NULL_VECTOR);
		SetVariantString("!activator");
		AcceptEntityInput(g_iNeon[iClient], "SetParent", iClient, g_iNeon[iClient], 0);
		SDKHook(g_iNeon[iClient], SDKHook_SetTransmit, Hook_Hide);
	}
	else
	{
		g_iNeon[iClient] = 0;
	}
}

public Action Hook_Hide(int iNeon, int iClient)
{
	int iOwner = GetEntPropEnt(iNeon, Prop_Send, "m_hOwnerEntity");
	if(iOwner != -1 && GetClientTeam(iOwner) != GetClientTeam(iClient))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void RemoveNeon(int iClient)
{
	if(g_iNeon[iClient] != 0 && IsValidEdict(g_iNeon[iClient]))
	{
		AcceptEntityInput(g_iNeon[iClient], "Kill");
	}
	g_iNeon[iClient] = 0;
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[16], sBuffer[2][8];
	
	GetClientCookie(iClient, g_hNeons, sCookie, sizeof(sCookie));
	ExplodeString(sCookie, ";", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));

	g_iNeonChoose[iClient] = StringToInt(sBuffer[0]);
	g_iNeonActivator[iClient] = StringToInt(sBuffer[1]);

	if(g_iNeonChoose[iClient] == -1)
	{
		g_iNeonChoose[iClient] = 0;
	}
} 

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[16];
		
		FormatEx(sBuffer, sizeof(sBuffer), "%i;%i;", g_iNeonChoose[iClient], g_iNeonActivator[iClient]);
		SetClientCookie(iClient, g_hNeons, sBuffer);		
	}

	RemoveNeon(iClient);
	g_iNeonChoose[iClient] = 0;
}

public void OnPluginEnd()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);
		}
	}
}