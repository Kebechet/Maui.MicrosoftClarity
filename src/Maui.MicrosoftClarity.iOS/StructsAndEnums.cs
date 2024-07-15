using ObjCRuntime;

namespace Binding
{
	[Native]
	public enum ApplicationFramework : long
	{
		Native = 0,
		Cordova = 1,
		ReactNative = 2,
		Ionic = 3
	}

	[Native]
	public enum LogLevel : long
	{
		Verbose = 0,
		Debug = 1,
		Info = 2,
		Warning = 3,
		Error = 4,
		None = 5
	}
}
