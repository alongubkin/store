#pragma semicolon 1

#include <store/store-core>
#include <store/store-logging>

#define PLUGIN_NAME_RESERVED_LENGTH 33

static Handle:g_log_file = INVALID_HANDLE;
static const String:g_log_level_names[][] = { "     ", "ERROR", "WARN ", "INFO ", "DEBUG", "TRACE" };
static Store_LogLevel:g_log_level = Store_LogLevelNone;
static Store_LogLevel:g_log_flush_level = Store_LogLevelNone;
static bool:g_log_errors_to_SM = false;
static String:g_current_date[20];

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	CreateNative("Store_GetLogLevel", Store_GetLogLevel_);
	CreateNative("Store_Log",         Store_Log_);
	CreateNative("Store_LogError",    Store_LogError_);
	CreateNative("Store_LogWarning",  Store_LogWarning_);
	CreateNative("Store_LogInfo",     Store_LogInfo_);
	CreateNative("Store_LogDebug",    Store_LogDebug_);
	CreateNative("Store_LogTrace",    Store_LogTrace_);
    
	RegPluginLibrary("store-logging");
    
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name        = "[Store] Logging",
	author      = "alongub",
	description = "Logging component for [Store]",
	version     = STORE_VERSION,
	url         = "https://github.com/alongubkin/store"
};

public OnPluginStart() 
{
	LoadConfig();
	FormatTime(g_current_date, sizeof(g_current_date), "%Y-%m-%d", GetTime());
	CreateTimer(1.0, OnCheckDate, INVALID_HANDLE, TIMER_REPEAT);
	if (g_log_level > Store_LogLevelNone)
		CreateLogFileOrTurnOffLogging();
}

LoadConfig() 
{
	new Handle:kv = CreateKeyValues("root");
    
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/store/logging.cfg");
    
	if (!FileToKeyValues(kv, path))
    {
		CloseHandle(kv);
		SetFailState("Can't read config file %s", path);
	}

	g_log_level = Store_LogLevel:KvGetNum(kv, "log_level", 2);
	g_log_flush_level = Store_LogLevel:KvGetNum(kv, "log_flush_level", 2);
	g_log_errors_to_SM = (KvGetNum(kv, "log_errors_to_SM", 1) > 0);

	CloseHandle(kv);
}

public OnPluginEnd() 
{
	if (g_log_file != INVALID_HANDLE)
		CloseLogFile();
}

public Action:OnCheckDate(Handle:timer)
{
	decl String:new_date[20];
	FormatTime(new_date, sizeof(new_date), "%Y-%m-%d", GetTime());
    
	if (g_log_level > Store_LogLevelNone && !StrEqual(new_date, g_current_date)) 
    {
		strcopy(g_current_date, sizeof(g_current_date), new_date);
        
		if (g_log_file != INVALID_HANDLE) 
        {
			WriteMessageToLog(INVALID_HANDLE, Store_LogLevelInfo, "Date changed; switching log file", true);
			CloseLogFile();
		}
        
		CreateLogFileOrTurnOffLogging();
	}
}

CloseLogFile() 
{
	WriteMessageToLog(INVALID_HANDLE, Store_LogLevelInfo, "Logging stopped");
	FlushFile(g_log_file);
	CloseHandle(g_log_file);
	g_log_file = INVALID_HANDLE;
}

bool:CreateLogFileOrTurnOffLogging()
{
	decl String:filename[128];
	new pos = BuildPath(Path_SM, filename, sizeof(filename), "logs/");
	FormatTime(filename[pos], sizeof(filename)-pos, "store_%Y-%m-%d.log", GetTime());
    
	if ((g_log_file = OpenFile(filename, "a")) == INVALID_HANDLE) 
    {
		g_log_level = Store_LogLevelNone;
		LogError("Can't create store log file");
		return false;
	}
	else 
    {
		WriteMessageToLog(INVALID_HANDLE, Store_LogLevelInfo, "Logging started", true);
		return true;
	}
}

public Store_GetLogLevel_(Handle:plugin, num_params) 
{
	return _:g_log_level;
}

public Store_Log_(Handle:plugin, num_params) 
{
	new Store_LogLevel:log_level = Store_LogLevel:GetNativeCell(1);
	if (g_log_level >= log_level) 
    {
		decl String:message[10000], written;
		FormatNativeString(0, 2, 3, sizeof(message), written, message);
        
		if (g_log_file != INVALID_HANDLE)
			WriteMessageToLog(plugin, log_level, message);
            
		if (log_level == Store_LogLevelError && g_log_errors_to_SM) 
        {
			ReplaceString(message, sizeof(message), "%", "%%");
			LogError(message);
		}
	}
}

public Store_LogError_(Handle:plugin, num_params) 
{
	if (g_log_level >= Store_LogLevelError) 
    {
		decl String:message[10000], written;
		FormatNativeString(0, 1, 2, sizeof(message), written, message);
        
		if (g_log_file != INVALID_HANDLE)
        {
			WriteMessageToLog(plugin, Store_LogLevelError, message);
        }
         
		if (g_log_errors_to_SM) 
        {
			ReplaceString(message, sizeof(message), "%", "%%");
			LogError(message);
		}
	}
}

public Store_LogWarning_(Handle:plugin, num_params) 
{
	if (g_log_level >= Store_LogLevelWarning && g_log_file != INVALID_HANDLE) 
    {
		decl String:message[10000], written;
		FormatNativeString(0, 1, 2, sizeof(message), written, message);
		WriteMessageToLog(plugin, Store_LogLevelWarning, message);
	}
}

public Store_LogInfo_(Handle:plugin, num_params) 
{
	if (g_log_level >= Store_LogLevelInfo && g_log_file != INVALID_HANDLE) 
    {
		decl String:message[10000], written;
		FormatNativeString(0, 1, 2, sizeof(message), written, message);
		WriteMessageToLog(plugin, Store_LogLevelInfo, message);
	}
}

public Store_LogDebug_(Handle:plugin, num_params) 
{
	if (g_log_level >= Store_LogLevelDebug && g_log_file != INVALID_HANDLE) 
    {
		decl String:message[10000], written;
		FormatNativeString(0, 1, 2, sizeof(message), written, message);
		WriteMessageToLog(plugin, Store_LogLevelDebug, message);
	}
}

public Store_LogTrace_(Handle:plugin, num_params) 
{
	if (g_log_level >= Store_LogLevelTrace && g_log_file != INVALID_HANDLE) 
    {
		decl String:message[10000], written;
		FormatNativeString(0, 1, 2, sizeof(message), written, message);
		WriteMessageToLog(plugin, Store_LogLevelTrace, message);
	}
}

WriteMessageToLog(Handle:plugin, Store_LogLevel:log_level, const String:message[], bool:force_flush=false) 
{
	decl String:log_line[10000];
	PrepareLogLine(plugin, log_level, message, log_line);
	WriteFileString(g_log_file, log_line, false);
    
	if (log_level <= g_log_flush_level || force_flush)
		FlushFile(g_log_file);
}

PrepareLogLine(Handle:plugin, Store_LogLevel:log_level, const String:message[], String:log_line[10000]) 
{
	decl String:plugin_name[100];
	GetPluginFilename(plugin, plugin_name, sizeof(plugin_name)-1);
	// Make windows consistent with unix
	ReplaceString(plugin_name, sizeof(plugin_name), "\\", "/");
	new name_end = strlen(plugin_name);
	plugin_name[name_end++] = ']';
	for (new end=PLUGIN_NAME_RESERVED_LENGTH-1; name_end<end; ++name_end)
		plugin_name[name_end] = ' ';
	plugin_name[name_end++] = 0;
	FormatTime(log_line, sizeof(log_line), "%Y-%m-%d %H:%M:%S [", GetTime());
	new pos = strlen(log_line);
	pos += strcopy(log_line[pos], sizeof(log_line)-pos, plugin_name);
	log_line[pos++] = ' ';
	pos += strcopy(log_line[pos], sizeof(log_line)-pos-5, g_log_level_names[log_level]);
	log_line[pos++] = ' ';
	log_line[pos++] = '|';
	log_line[pos++] = ' ';
	pos += strcopy(log_line[pos], sizeof(log_line)-pos-2, message);
	log_line[pos++] = '\n';
	log_line[pos++] = 0;
}