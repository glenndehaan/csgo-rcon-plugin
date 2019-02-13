#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <ripext>

new Handle:g_Terrorist = INVALID_HANDLE;
new Handle:g_CTerrorist = INVALID_HANDLE;
new Handle:g_hCvarTeamName1 = INVALID_HANDLE;
new Handle:g_hCvarTeamName2 = INVALID_HANDLE;

HTTPClient httpClient;
char url[128];
char path[128];

bool halfTime = false;

/**
 * Defines the default plugin info
 */
public Plugin myinfo =
{
	name = "CSGO Remote Utils",
	author = "Glenn de Haan",
	description = "A plugin used for the CSGO Remote package",
	version = "3.0",
	url = "https://github.com/glenndehaan/csgo-rcon-plugin"
}

/**
 * Function runs when plugin is mounted
 *
 * @see https://sm.alliedmods.net/new-api/sourcemod/OnPluginStart
 */
public void OnPluginStart()
{
	PrintToServer("[CSGO Remote] Loaded: CSGO Remote Utils!");
	RegServerCmd("sm_csgo_remote", Command_CSGO_Remote, "Check to check if this plugin is available");
	RegServerCmd("sm_csgo_remote_url", Command_CSGO_Remote_URL, "Set's the CURL Url for API offloading");

	httpClient = new HTTPClient("http://127.0.0.1:3542");

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("announce_phase_end", Event_HalfTime);
	HookEvent("cs_intermission", Event_MatchEnd);

	g_Terrorist = CreateConVar("sm_teamname_t", "", "Sets your Terrorist team name", 0);
	g_CTerrorist = CreateConVar("sm_teamname_ct", "", "Sets your Counter-Terrorist team name", 0);

	HookConVarChange(g_Terrorist, OnConVarChange);
	HookConVarChange(g_CTerrorist, OnConVarChange);

	g_hCvarTeamName1 = FindConVar("mp_teamname_1");
	g_hCvarTeamName2 = FindConVar("mp_teamname_2");
}

/**
 * Function runs when map is started
 */
public OnMapStart()
{
	decl String:sBuffer[32];
	GetConVarString(g_Terrorist, sBuffer, sizeof(sBuffer));
	SetConVarString(g_hCvarTeamName2, sBuffer);
	GetConVarString(g_CTerrorist, sBuffer, sizeof(sBuffer));
	SetConVarString(g_hCvarTeamName1, sBuffer);
}

/**
 * Function runs when Convar changes
 *
 * @param client
 * @param args
 */
public OnConVarChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	decl String:sBuffer[32];
	GetConVarString(hCvar, sBuffer, sizeof(sBuffer));

	if(hCvar == g_Terrorist)
		SetConVarString(g_hCvarTeamName2, sBuffer);
	else if(hCvar == g_CTerrorist)
		SetConVarString(g_hCvarTeamName1, sBuffer);
}

/**
 * Function runs when sm_csgo_remote is triggered
 *
 * @param args
 */
public Action Command_CSGO_Remote(int args)
{
	ReplyToCommand(0, "{\"status\":\"OK\",\"enabled\":true}");
	return Plugin_Handled;
}

/**
 * Function runs when sm_csgo_remote_url is triggered
 *
 * @param args
 */
public Action Command_CSGO_Remote_URL(int args)
{
	GetCmdArg(1, url, 128);
	GetCmdArg(2, path, 128);

	httpClient = new HTTPClient(url);

	ReplyToCommand(0, "{\"status\":\"OK\",\"url\":\"%s\",\"path\":\"%s\"}", url, path);
	return Plugin_Handled;
}

/**
 * Event hook for half_time
 *
 * @param event
 * @param name
 */
public void Event_HalfTime(Handle event, const char[] name, bool dontBroadcast)
{
	PrintToServer("[CSGO Remote] Half Time!");

	halfTime = true;
}

/**
 * Event hook for round_end
 *
 * @param event
 * @param name
 */
public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	PrintToServer("[CSGO Remote] Round End!");

	JSONObject data = new JSONObject();
	JSONObject match = new JSONObject();
	JSONArray players = new JSONArray();

	match.SetInt("CT", CS_GetTeamScore(CS_TEAM_CT));
	match.SetInt("T", CS_GetTeamScore(CS_TEAM_T));

	new MaxPlayers = GetMaxClients();
	new item;
	for(item = 1; item < MaxPlayers; item++)
	{
		if(IsClientInGame(item) && !IsFakeClient(item))
		{
			char player_name[50];
			GetClientName(item, player_name, 50);
			JSONObject player = new JSONObject();

			player.SetInt("id", GetClientUserId(item));
			player.SetString("name", player_name);
			player.SetInt("team", GetClientTeam(item));
			player.SetInt("kills", GetClientFrags(item));
			player.SetInt("assists", CS_GetClientAssists(item));
			player.SetInt("deaths", GetClientDeaths(item));

			players.Push(player);
			delete player;
		}
	}

	data.SetString("status", "round_end");
	data.SetBool("locked", false);
	data.SetBool("half_time", halfTime);
	data.Set("match", match);
	data.Set("players", players);

	decl String:ct_name[32];
	GetConVarString(g_hCvarTeamName1, ct_name, sizeof(ct_name));
	decl String:t_name[32];
	GetConVarString(g_hCvarTeamName2, t_name, sizeof(t_name));

	data.SetString("ct_name", ct_name);
	data.SetString("t_name", t_name);

	PrintToServer("[CSGO Remote] REST Path: %s", path);
	httpClient.Post(path, data, OnRESTCall);
	delete match;
	delete data;
}

/**
 * Event hook for match_end
 *
 * @param response
 * @param value
 */
public void Event_MatchEnd(Handle event, const char[] name, bool dontBroadcast)
{
	PrintToServer("[CSGO Remote] Match End!");

	JSONObject data = new JSONObject();
	JSONObject match = new JSONObject();
	JSONArray players = new JSONArray();

	match.SetInt("CT", CS_GetTeamScore(CS_TEAM_CT));
	match.SetInt("T", CS_GetTeamScore(CS_TEAM_T));

	new MaxPlayers = GetMaxClients();
	new item;
	for(item = 1; item < MaxPlayers; item++)
	{
		if(IsClientInGame(item) && !IsFakeClient(item))
		{
			char player_name[50];
			GetClientName(item, player_name, 50);
			JSONObject player = new JSONObject();

			player.SetInt("id", GetClientUserId(item));
			player.SetString("name", player_name);
			player.SetInt("team", GetClientTeam(item));
			player.SetInt("kills", GetClientFrags(item));
			player.SetInt("assists", CS_GetClientAssists(item));
			player.SetInt("deaths", GetClientDeaths(item));

			players.Push(player);
			delete player;
		}
	}

	data.SetString("status", "match_end");
	data.SetBool("locked", true);
	data.SetBool("half_time", halfTime);
	data.Set("match", match);
	data.Set("players", players);

	decl String:ct_name[32];
	GetConVarString(g_hCvarTeamName1, ct_name, sizeof(ct_name));
	decl String:t_name[32];
	GetConVarString(g_hCvarTeamName2, t_name, sizeof(t_name));

	data.SetString("ct_name", ct_name);
	data.SetString("t_name", t_name);

	PrintToServer("[CSGO Remote] REST Path: %s", path);
	httpClient.Post(path, data, OnRESTCall);
	delete match;
	delete data;
}

/**
 * General callback for HTTP Requests
 *
 * @param response
 * @param value
 */
public void OnRESTCall(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_OK) {
        PrintToServer("[CSGO Remote] REST Failed!");
        return;
    }

    PrintToServer("[CSGO Remote] REST Success!");
}
