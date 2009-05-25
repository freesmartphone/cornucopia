/* fsoframework-2.0.vapi generated by valac, do not modify. */

[CCode (cprefix = "FsoFramework", lower_case_cprefix = "fso_framework_")]
namespace FsoFramework {
	[CCode (cprefix = "FsoFrameworkDevice", lower_case_cprefix = "fso_framework_device_")]
	namespace Device {
		[CCode (cheader_filename = "fsoframework.h")]
		public const string AudioServiceFace;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string AudioServicePath;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string DisplayServiceFace;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string DisplayServicePath;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string InfoServiceFace;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string InfoServicePath;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string InputServiceFace;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string InputServicePath;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string LedServiceFace;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string LedServicePath;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string PowerControlServiceFace;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string PowerControlServicePath;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string PowerSupplyServiceFace;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string PowerSupplyServicePath;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string RtcServiceFace;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string RtcServicePath;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string ServiceDBusName;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string ServiceFacePrefix;
		[CCode (cheader_filename = "fsoframework.h")]
		public const string ServicePathPrefix;
	}
	[CCode (cprefix = "FsoFrameworkFileHandling", lower_case_cprefix = "fso_framework_file_handling_")]
	namespace FileHandling {
		[CCode (cheader_filename = "fsoframework.h")]
		public static bool isPresent (string filename);
		[CCode (cheader_filename = "fsoframework.h")]
		public static string read (string filename);
		[CCode (cheader_filename = "fsoframework.h")]
		public static void write (string contents, string filename);
	}
	[CCode (cprefix = "FsoFrameworkStringHandling", lower_case_cprefix = "fso_framework_string_handling_")]
	namespace StringHandling {
		[CCode (cheader_filename = "fsoframework.h")]
		public static string stringListToString (string[] list);
	}
	[CCode (cprefix = "FsoFrameworkUserGroupHandling", lower_case_cprefix = "fso_framework_user_group_handling_")]
	namespace UserGroupHandling {
		[CCode (cheader_filename = "fsoframework.h")]
		public static Posix.gid_t gidForGroup (string group);
		[CCode (cheader_filename = "fsoframework.h")]
		public static bool switchToUserAndGroup (string user, string group);
		[CCode (cheader_filename = "fsoframework.h")]
		public static Posix.uid_t uidForUser (string user);
	}
	[CCode (cprefix = "FsoFrameworkUtility", lower_case_cprefix = "fso_framework_utility_")]
	namespace Utility {
		[CCode (cheader_filename = "fsoframework.h")]
		public static string programName ();
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public abstract class AbstractLogger : FsoFramework.Logger, GLib.Object {
		protected string destination;
		protected string domain;
		protected uint level;
		protected virtual string format (string message, string level);
		public static string levelToString (GLib.LogLevelFlags level);
		public AbstractLogger (string domain);
		public static GLib.LogLevelFlags stringToLevel (string level);
		protected virtual void write (string message);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public abstract class AbstractObject : GLib.Object {
		protected FsoFramework.SmartKeyFile config;
		protected FsoFramework.Logger logger;
		public abstract string repr ();
		public string classname { get; construct; }
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public abstract class AbstractSubsystem : FsoFramework.Subsystem, GLib.Object {
		protected FsoFramework.Logger logger;
		public AbstractSubsystem (string name);
		public virtual bool registerServiceName (string servicename);
		public virtual bool registerServiceObject (string servicename, string objectname, GLib.Object obj);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class AsyncWorkerQueue<T> : FsoFramework.AbstractWorkerQueue<T>, GLib.Object {
		protected GLib.Queue<T> q;
		protected FsoFramework.AbstractWorkerQueue.WorkerFunc worker;
		protected bool _onIdle ();
		public AsyncWorkerQueue ();
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class BaseKObjectNotifier : GLib.Object {
		public static FsoFramework.BaseKObjectNotifier instance;
		protected void _addMatch (string action, string subsystem, FsoFramework.KObjectNotifierFunc callback);
		public static void addMatch (string action, string path, FsoFramework.KObjectNotifierFunc callback);
		protected void handleMessage (string[] parts);
		public BaseKObjectNotifier ();
		protected bool onActionFromSocket (GLib.IOChannel source, GLib.IOCondition condition);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class BasePlugin : FsoFramework.Plugin, GLib.TypeModule {
		public override bool load ();
		public BasePlugin (string filename, FsoFramework.Subsystem subsystem);
		public override void unload ();
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class BaseSubsystem : FsoFramework.AbstractSubsystem {
		public BaseSubsystem (string name);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class DBusSubsystem : FsoFramework.AbstractSubsystem {
		public DBusSubsystem (string name);
		public override bool registerServiceName (string servicename);
		public override bool registerServiceObject (string servicename, string objectname, GLib.Object obj);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class FileLogger : FsoFramework.AbstractLogger {
		public FileLogger (string domain);
		public void setFile (string filename, bool append = false);
		protected override void write (string message);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class NullLogger : FsoFramework.AbstractLogger {
		public NullLogger (string domain);
		protected override void write (string message);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class SmartKeyFile : GLib.Object {
		public bool boolValue (string section, string key, bool defaultvalue = false);
		public bool hasKey (string section, string key);
		public bool hasSection (string section);
		public int intValue (string section, string key, int defaultvalue = 0);
		public GLib.List<string> keysWithPrefix (string section, string? prefix = null);
		public bool loadFromFile (string filename);
		public SmartKeyFile ();
		public GLib.List<string> sectionsWithPrefix (string? prefix = null);
		public string[]? stringListValue (string section, string key, string[]? defaultvalue = null);
		public string stringValue (string section, string key, string defaultvalue = "");
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class SmartKeyFileSection : GLib.Object {
		public static FsoFramework.SmartKeyFileSection? openSection (FsoFramework.SmartKeyFile kf, string section);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public class SyslogLogger : FsoFramework.AbstractLogger {
		protected override string format (string message, string level);
		public SyslogLogger (string domain);
		protected override void write (string message);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public interface AbstractWorkerQueue<T> : GLib.Object {
		[CCode (cheader_filename = "fsoframework.h")]
		public delegate void WorkerFunc (T element);
		public abstract void enqueue (T element);
		public abstract void setDelegate (FsoFramework.AbstractWorkerQueue.WorkerFunc worker);
		public abstract void trigger ();
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public interface Logger : GLib.Object {
		public abstract void debug (string message);
		public abstract void error (string message);
		public abstract void info (string message);
		public abstract void setDestination (string destination);
		public abstract void setLevel (GLib.LogLevelFlags level);
		public abstract void setReprDelegate (ReprDelegate repr);
		public abstract void warning (string message);
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public interface Plugin : GLib.Object {
		public abstract FsoFramework.PluginInfo info ();
		public abstract void loadAndInit () throws FsoFramework.PluginError;
	}
	[CCode (cheader_filename = "fsoframework.h")]
	public interface Subsystem : GLib.Object {
		public abstract uint loadPlugins ();
		public abstract string name ();
		public abstract GLib.List<FsoFramework.PluginInfo?> pluginsInfo ();
		public abstract uint registerPlugins ();
		public abstract bool registerServiceName (string servicename);
		public abstract bool registerServiceObject (string servicename, string objectname, GLib.Object obj);
	}
	[CCode (type_id = "FSO_FRAMEWORK_TYPE_PLUGIN_INFO", cheader_filename = "fsoframework.h")]
	public struct PluginInfo {
		public string name;
		public bool loaded;
	}
	[CCode (cprefix = "FSO_FRAMEWORK_PLUGIN_ERROR_", cheader_filename = "fsoframework.h")]
	public errordomain PluginError {
		UNABLE_TO_LOAD,
		REGISTER_NOT_FOUND,
		FACTORY_NOT_FOUND,
		UNABLE_TO_INITIALIZE,
	}
	[CCode (cheader_filename = "fsoframework.h", has_target = false)]
	public delegate string FactoryFunc (FsoFramework.Subsystem subsystem);
	[CCode (cheader_filename = "fsoframework.h")]
	public delegate void KObjectNotifierFunc (GLib.HashTable<string,string> properties);
	[CCode (cheader_filename = "fsoframework.h", has_target = false)]
	public delegate void RegisterFunc (GLib.TypeModule bar);
	[CCode (cheader_filename = "fsoframework.h")]
	public const string DEFAULT_LOG_DESTINATION;
	[CCode (cheader_filename = "fsoframework.h")]
	public const string DEFAULT_LOG_LEVEL;
	[CCode (cheader_filename = "fsoframework.h")]
	public const string DEFAULT_LOG_TYPE;
	[CCode (cheader_filename = "fsoframework.h")]
	public const string ServiceDBusPrefix;
	[CCode (cheader_filename = "fsoframework.h")]
	public const string ServiceFacePrefix;
	[CCode (cheader_filename = "fsoframework.h")]
	public const string ServicePathPrefix;
	[CCode (cheader_filename = "fsoframework.h")]
	public static FsoFramework.Logger createLogger (string domain);
	[CCode (cheader_filename = "fsoframework.h")]
	public static string getPrefixForExecutable ();
	[CCode (cheader_filename = "fsoframework.h")]
	public static FsoFramework.SmartKeyFile theMasterKeyFile ();
}
[CCode (cheader_filename = "fsoframework.h")]
[DBus (name = "org.freesmartphone.DBus.Objects")]
public interface DBusObjects {
	public abstract void getNodes () throws DBus.Error;
}
[CCode (cheader_filename = "fsoframework.h")]
public delegate string ReprDelegate ();
