#if defined _store_logging_included
  #endinput
#endif
#define _store_logging_included

/**
 * Logging levels
 */
enum Store_LogLevel 
{
	Store_LogLevelNone = 0,  /**< Logging disabled */
	Store_LogLevelError,     /**< Log only errors */
	Store_LogLevelWarning,   /**< Log errors and warnings */
	Store_LogLevelInfo,      /**< Log errors, warnings and info messages */
	Store_LogLevelDebug,     /**< Log errors, warnings, info and debug messages */
	Store_LogLevelTrace      /**< Log errors, warnings, info, debug and trace messages */
};

/**
 * Returns the current logging level.
 *
 * @return              Current logging level
 */
native Store_LogLevel:Store_GetLogLevel();

/**
 * Logs a message to the Store log file. Depending on the log level provided, this is equivalent
 * to calling any of the logging functions below (Store_LogError(), Store_LogWarning(), etc).
 *
 * @param log_level     The severity of the message being logged.
 * @param format        A format string. See http://wiki.alliedmods.net/Format_Class_Functions_(SourceMod_Scripting)
 * @param ...           Variable number of format parameters.
 * @noreturn
 */
native Store_Log(Store_LogLevel:log_level, const String:format[] , any:...);

/**
 * Logs an error message to the Store log file. Error logs are either fatal unrecoverable errors
 * or notifications about major problems that significantly hinder a plugin's functionality. For
 * example, not being able to connect to the Store service.
 *
 * @param format        A format string. See http://wiki.alliedmods.net/Format_Class_Functions_(SourceMod_Scripting)
 * @param ...           Variable number of format parameters.
 * @noreturn
 */
native Store_LogError(const String:format[] , any:...);

/**
 * Logs a warning message to the Store log file. Warnings should notify the server operator of
 * malfunctions that are not critical to the plugin's operation but do require attention. For
 * example, too much text disaplyed in a menu (and truncated).
 *
 * @param format        A format string. See http://wiki.alliedmods.net/Format_Class_Functions_(SourceMod_Scripting)
 * @param ...           Variable number of format parameters.
 * @noreturn
 */
native Store_LogWarning(const String:format[] , any:...);

/**
 * Logs an info message to the Store log file. Info messages should enable the server operator
 * to drill in and track activity that occured on his server in details. For example, client
 * dis/connections, client billing operations, awards granted to clients, etc.
 *
 * @param format        A format string. See http://wiki.alliedmods.net/Format_Class_Functions_(SourceMod_Scripting)
 * @param ...           Variable number of format parameters.
 * @noreturn
 */
native Store_LogInfo(const String:format[] , any:...);

/**
 * Logs a debug message to the Store log file. Debug logs are low-level messages primarily used
 * by developers to debug the execution of their plugins. Debug logs typically describe the
 * parameters and outcome of some algorithmic computation, or some event that occured. Debug logs
 * may generate large volumes of data.
 *
 * @param format        A format string. See http://wiki.alliedmods.net/Format_Class_Functions_(SourceMod_Scripting)
 * @param ...           Variable number of format parameters.
 * @noreturn
 */
native Store_LogDebug(const String:format[] , any:...);

/**
 * Logs a particularly low-level trace message to the Store log file. Trace logs are low-level
 * messages primarily used by developers to trace the execution of their plugins. They typically
 * describe a position in the code and the value of surrounding parameters. Trace logs WILL generate
 * large volumes of data quickly.
 *
 * @param format        A format string. See http://wiki.alliedmods.net/Format_Class_Functions_(SourceMod_Scripting)
 * @param ...           Variable number of format parameters.
 * @noreturn
 */
native Store_LogTrace(const String:format[] , any:...);

public SharedPlugin:__pl_store_logging = 
{
	name = "store-logging",
	file = "store-logging.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if defined REQUIRE_PLUGIN
public __pl_store_logging_SetNTVOptional() 
{
	MarkNativeAsOptional("Store_GetLogLevel");
	MarkNativeAsOptional("Store_Log");
	MarkNativeAsOptional("Store_LogError");
	MarkNativeAsOptional("Store_LogWarning");
	MarkNativeAsOptional("Store_LogInfo");
	MarkNativeAsOptional("Store_LogDebug");
	MarkNativeAsOptional("Store_LogDebug2");
}
#endif
