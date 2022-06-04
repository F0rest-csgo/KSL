#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "F0rest"
#define PLUGIN_VERSION "beta"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include "kodinc.sp"
//#include <sdkhooks>
char uid[66][32];
int score[66];
char name[66][PLATFORM_MAX_PATH];
#pragma newdecls required
bool live;
ArrayList players;
Database g_DB;
EngineVersion g_Game;

public Plugin myinfo = 
{
	name = "KSL",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = "https://kodplay.com"
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	Database.Connect(ConnectCallback, "kodbinder");
	for (int i = 1; i <= MaxClients; i++)
	{
		uid[i] = "";
		score[i] = -1;
		name[i] = "";
	}
	ConVar maxrounds = FindConVar("mp_maxrounds");
	ConVar picktime = FindConVar("mp_force_pick_time");
	HookConVarChange(picktime, OnPickTimeChanged);
	HookConVarChange(maxrounds, OnConvarChanged);
	RegConsoleCmd("sm_lb", ShowLieBiao);
	HookEvent("player_changename", OnName);
	HookEvent( "player_spawn", SpawnEvent );
	AddCommandListener(Command_JoinTeam, "jointeam");
	HookEvent("cs_win_panel_round", RoundEnd);
	HookEvent("cs_win_panel_match", MatchEnd,EventHookMode_Pre);
	live = false;
	players = new ArrayList(PLATFORM_MAX_PATH);
}

public Action ShowLieBiao(int client,int args)
{
	PrintToChat(client,"玩家列表：");
	for (int i = 0; i < players.Length; i++)
	{
		PrintToChat(client,"%N | %d", players.Get(i), score[players.Get(i)]);
	}
}

public void OnConvarChanged(ConVar maxrounds,const char[] oldvalue,const char[] newvalue)
{
	if(!StrEqual(newvalue, "99"))
	{
		ServerCommand("mp_maxrounds 99");
	}
}

public void OnPickTimeChanged(ConVar picktime,const char[] oldvalue,const char[] newvalue)
{
	if(!StrEqual(newvalue,"999"))
	{
		picktime.SetInt(999);
	}
}

public Action MatchEnd(Handle event,const char[] nameq,bool dontBroadcast)
{
	
	return Plugin_Continue;
}


public Action RoundEnd(Handle event,const char[] nameq,bool dontBroadcast)
{
	int ctscore = CS_GetTeamScore(CS_TEAM_CT);
	int tscore = CS_GetTeamScore(CS_TEAM_T);
	if(ctscore!=16 && tscore!=16)
	{
		return Plugin_Continue;
	}
	if(tscore==16)
	{
		//T获胜
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i) && GetClientTeam(i)==CS_TEAM_T)
			{
				
				PlayerWin(i);
			}
			if(IsValidClient(i) && GetClientTeam(i)==CS_TEAM_CT)
			{
				
				PlayerLose(i);
			}
		}
	}
	else{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i) && GetClientTeam(i)==CS_TEAM_CT)
			{
				PlayerWin(i);
			}
			if(IsValidClient(i) && GetClientTeam(i)==CS_TEAM_T)
			{
				
				PlayerLose(i);
			}
		}
		
	}
	PrintToChatAll("玩家列表：");
	for (int i = 0; i < players.Length; i++)
	{
		PrintToChatAll("%N | %d", players.Get(i), score[players.Get(i)]);
	}
	live = false;
	OnMapStart();
	return Plugin_Continue;
}

public bool PlayerWin(int client)
{
	//玩家获胜，更新场数+胜场
	score[client] += 15;
	PrintToChatAll("玩家 %N 获胜，KSL分数增加15分，共%d分", client, score[client]);
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "", uid[client]);
	SQL_TQuery(g_DB, ChangciCB, query, client);
	Format(query, sizeof(query), "", uid[client]);
	SQL_TQuery(g_DB, ShengchangCB, query, client);
	return true;
}
public bool PlayerLose(int client)
{
	//玩家败北，更新场数
	score[client] -= 15;
	PrintToChatAll("玩家 %N 败北，KSL分数减少15分，共%d分", client, score[client]);
	int index = players.FindValue(client);
	players.Erase(index);
	players.Push(client);
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "", uid[client]);
	SQL_TQuery(g_DB, ChangciCB, query, client);
	return true;
}
public void ChangciCB(Handle owner, Handle hndl, const char[] error,any data)
{
	if(!StrEqual(error,""))
	{
		LogError("Database ERROR! Information:%s",error);
	}
	SQL_FetchRow(hndl);
	int client = data;
	int changci = SQL_FetchInt(hndl, 0);
	changci++;
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "", changci,uid[client]);
	
	SQL_TQuery(g_DB, SaveCB, query);
}

public void ShengchangCB(Handle owner, Handle hndl, const char[] error,any data)
{
	if(!StrEqual(error,""))
	{
		LogError("Database ERROR! Information:%s",error);
	}
	SQL_FetchRow(hndl);
	int client = data;
	int shengchang = SQL_FetchInt(hndl, 0);
	shengchang++;
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "", shengchang,uid[client]);
	SQL_TQuery(g_DB, SaveCB, query);
}

public void OnClientDisconnect(int client)
{
	SaveClientData(client);
	int index = players.FindValue(client);
	if(index==-1)
	{
		return;
	}
	
	if(live)
	{
		
		if(index==1 || index==0)
		{
			//是比赛中的人
			if(CS_GetTeamScore(CS_TEAM_T) == 0 && CS_GetTeamScore(CS_TEAM_CT) == 0)
			{
				OnMapStart();
			}
			else{
				if(index==1)
				{
					PlayerWin(players.Get(0));
				}
				else{
					PlayerWin(players.Get(1));
				}
				PlayerLose(client);
				OnMapStart();
			}
			
		}
	}
	
	index = players.FindValue(client);
	players.Erase(index);
}

public void SaveClientData(int client)
{
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "", score[client], uid[client]);
	SQL_TQuery(g_DB, SaveCB, query, client);
	uid[client] = "";
	score[client] = -1;
	name[client] = "";
}

public Action SpawnEvent( Handle event, const char[] nameq, bool dontBroadcast )
{
	int	client_id	= GetEventInt( event, "userid" );
	int	client		= GetClientOfUserId( client_id );
	if (!IsClientInGame(client) || IsFakeClient(client)) return;
	char scorez[32];
	IntToString(score[client], scorez, 32);
	CS_SetClientClanTag(client, scorez);
	int index = GetPlayerWeaponSlot(client, 1);
	RemovePlayerItem(client, index);
	GivePlayerItem(client, "weapon_ak47");
}
public void ConnectCallback(Database db, const char[] error, any data)
{
	if (!StrEqual(error,"")) SetFailState("Database error.Infermation:%s", error);
	g_DB = db;
	SQL_SetCharset(g_DB, "utf8mb4");
}

public void OnMapStart()
{
	live = false;
	ServerCommand("mp_restartgame 1");
	ServerCommand("mp_warmup_start");
	ServerCommand("mp_warmup_pausetimer 1");
	ServerCommand("mp_freezetime 4");
	ServerCommand("mp_round_restart_delay 3");
	ServerCommand("mp_force_pick_time 999");
	ServerCommand("mp_maxrounds 99");
	ServerCommand("bot_kick");
	ServerCommand("game_mode 1");
	ServerCommand("mp_maxmoney 0");
	ServerCommand("mp_warmuptime 20");
	ServerCommand("mp_endmatch_votenextmap 0");
	ServerCommand("mp_match_end_changelevel 0");
	ServerCommand("mp_match_end_restart 1");
	ServerCommand("mp_match_restart_delay 0");
	ServerCommand("mp_free_armor 2");
	CreateTimer(1.0, Timer_CheckReady, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action Timer_CheckReady(Handle timer)
{
	if(live)
	{
		return Plugin_Continue;
	}
	ServerCommand("mp_freezetime 4");
	ServerCommand("mp_force_pick_time 999");
	ServerCommand("mp_round_restart_delay 3");
	ServerCommand("mp_maxrounds 99");
	ServerCommand("game_mode 1");
	ServerCommand("mp_maxmoney 0");
	ServerCommand("mp_warmuptime 20");
	
	int readycount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) > 1)
		{
			readycount++;
		}
	}
	if(readycount>=2)
	{
		//开始
		FakeClientCommand(players.Get(0), "jointeam %d", CS_TEAM_CT);
		FakeClientCommand(players.Get(1), "jointeam %d",CS_TEAM_T);
		for (int i = 2; i < players.Length; i++)
		{
			FakeClientCommand(players.Get(i), "jointeam %d", CS_TEAM_SPECTATOR);
		}
		
		PrintToChatAll("玩家列表：");
		for (int i = 0; i < players.Length; i++)
		{
			PrintToChatAll("%N | %d", players.Get(i), score[players.Get(i)]);
		}
		ServerCommand("mp_warmup_pausetimer 0");
		live = true;
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	char authid[32];
	GetClientAuthId(client, AuthId_Steam2, authid, sizeof(authid));
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "", authid);
	SQL_TQuery(g_DB, GetIdCB, query, client);
}

public void SaveCB(Handle owner, Handle hndl, const char[] error,any data){
}
public void GetIdCB(Handle owner, Handle hndl, const char[] error,any data)
{
	if(!StrEqual(error,""))
	{
		LogError("Database ERROR! Information:%s",error);
	}
	int client = data;
	if (!IsClientConnected(client)) return;
	if(!SQL_FetchRow(hndl))
	{
		KickClient(client, "未获得准入资格，请加QQ群： 了解详情");
	}
	else{
		char id[PLATFORM_MAX_PATH];
		SQL_FetchString(hndl, 0, id, sizeof(id));
		Format(uid[client], 32, "%s", id);
		GetClientPLScore(client, id);
	}
}

public void GetClientPLScore(int client,const char[] id)
{
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "", id);
	SQL_TQuery(g_DB, GetScoreCB, query, client);
}

public void GetScoreCB(Handle owner, Handle hndl, const char[] error,any data)
{
	if(!StrEqual(error,""))
	{
		LogError("Database ERROR! Information:%s",error);
	}
	int client = data;
	if (!IsClientConnected(client)) return;
	if(!SQL_FetchRow(hndl))
	{
		KickClient(client, "未获得准入资格，请加QQ群： 了解详情");
		return;
	}
	else{
		score[client] = SQL_FetchInt(hndl, 0);
		if(score[client] < 1)
		{
			KickClient(client, "未获得准入资格，请加QQ群： 了解详情");
			return;
		}
		GetClientPLName(client);
		
		
	}
}

public void GetClientPLName(int client)
{
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "", uid[client]);
	SQL_TQuery(g_DB, GetNameCB, query, client);
}

public void GetNameCB(Handle owner, Handle hndl, const char[] error,any data)
{
	if(!StrEqual(error,""))
	{
		LogError("Database ERROR! Information:%s",error);
	}
	int client = data;
	if (!IsClientConnected(client)) return;
	if(!SQL_FetchRow(hndl))
	{
		KickClient(client, "未查找到比赛用名，请QQ找F0rest解决");
	}
	else{
		SQL_FetchString(hndl, 0, name[client], PLATFORM_MAX_PATH);
		
		CreateTimer(10.0, Timer_change, client);
	}
}

public Action Timer_change(Handle timer,any data)
{
	int client = data;
	SetClientName(client, name[client]);
}

public Action OnName(Event event, const char[] sname, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid", 0));
	
	CreateTimer(0.1, ChangeName, client);
}

public Action ChangeName(Handle timer,any data)
{
	int client = data;
	if (StrEqual(name[client], "")) return;
	SetClientName(client, name[client]);
}

public Action Command_JoinTeam(int client, const char[] command, int argc) {
	if (argc < 1)
	{
		return Plugin_Stop;
	}
	//玩家自发加队伍
	char arg[4];
	GetCmdArg(1, arg, sizeof(arg));
	int team_to = StringToInt(arg);
	if(team_to == CS_TEAM_NONE)
	{
		return Plugin_Stop;
	}
	if(team_to>1)
	{
		//加入t或ct
		int index = players.FindValue(client);
		if(index==-1)
		{
			players.Push(client);
		}
		if(live && GetClientTeam(client) == CS_TEAM_NONE)
		{
			FakeClientCommand(client, "jointeam 1");
			return Plugin_Stop;
		}
		if(live)
		{
			if(GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(client) == CS_TEAM_T)
			{
				//比赛中且为参赛选手
				return Plugin_Stop;
			}
			FakeClientCommand(client, "jointeam 1");
			return Plugin_Stop;
		}
		//未开始
		return Plugin_Continue;
	}
	//加入观察者
	if(live)
	{
		//比赛中
		int index = players.FindValue(client);
		if (GetTeamScore(CS_TEAM_T) == 0 && GetTeamScore(CS_TEAM_CT) == 0 && (index==0 || index==1))
		{
			
			players.Erase(index);
			OnMapStart();
			return Plugin_Continue;
		}
		if(index==0 || index==1)
		{
			//非0分去观察
			return Plugin_Stop;
		}
		//非参赛选手
		return Plugin_Continue;
	}
	return Plugin_Continue;
}