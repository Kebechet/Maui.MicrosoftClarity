using System;
using Foundation;
using ObjCRuntime;
using UIKit;

namespace MicrosoftClarityiOS
{
	// @interface ClarityConfig : NSObject
	[BaseType (typeof(NSObject))]
	[DisableDefaultCtor]
	interface ClarityConfig
	{
		// -(instancetype _Nonnull)initWithProjectId:(NSString * _Nonnull)projectId userId:(NSString * _Nullable)userId logLevel:(enum LogLevel)logLevel allowMeteredNetworkUsage:(BOOL)allowMeteredNetworkUsage enableWebViewCapture:(BOOL)enableWebViewCapture disableOnLowEndDevices:(BOOL)disableOnLowEndDevices applicationFramework:(enum ApplicationFramework)applicationFramework __attribute__((objc_designated_initializer));
		[Export ("initWithProjectId:userId:logLevel:allowMeteredNetworkUsage:enableWebViewCapture:disableOnLowEndDevices:applicationFramework:")]
		[DesignatedInitializer]
		NativeHandle Constructor (string projectId, [NullAllowed] string userId, LogLevel logLevel, bool allowMeteredNetworkUsage, bool enableWebViewCapture, bool disableOnLowEndDevices, ApplicationFramework applicationFramework);
	}

	// @interface ClaritySDK : NSObject
	[BaseType (typeof(NSObject))]
	interface ClaritySDK
	{
		// +(void)initializeWithConfig:(ClarityConfig * _Nonnull)config;
		[Static]
		[Export ("initializeWithConfig:")]
		void InitializeWithConfig (ClarityConfig config);

		// +(void)initializeWithConfig:(ClarityConfig * _Nonnull)config onClarityInitialized:(void (^ _Nonnull)(void))onClarityInitialized;
		[Static]
		[Export ("initializeWithConfig:onClarityInitialized:")]
		void InitializeWithConfig (ClarityConfig config, Action onClarityInitialized);

		// +(void)pause;
		[Static]
		[Export ("pause")]
		void Pause ();

		// +(void)resume;
		[Static]
		[Export ("resume")]
		void Resume ();

		// +(BOOL)isPaused __attribute__((warn_unused_result("")));
		[Static]
		[Export ("isPaused")]
		bool IsPaused { get; }

		// +(void)maskView:(UIView * _Nonnull)view;
		[Static]
		[Export ("maskView:")]
		void MaskView (UIView view);

		// +(void)unmaskView:(UIView * _Nonnull)view;
		[Static]
		[Export ("unmaskView:")]
		void UnmaskView (UIView view);

		// +(BOOL)setCustomUserId:(NSString * _Nonnull)customUserId;
		[Static]
		[Export ("setCustomUserId:")]
		bool SetCustomUserId (string customUserId);

		// +(BOOL)setCustomSessionId:(NSString * _Nonnull)customSessionId;
		[Static]
		[Export ("setCustomSessionId:")]
		bool SetCustomSessionId (string customSessionId);

		// +(NSString * _Nullable)getCurrentSessionId __attribute__((warn_unused_result("")));
		[Static]
		[NullAllowed, Export ("getCurrentSessionId")]
		string CurrentSessionId { get; }

		// +(NSString * _Nullable)getCurrentSessionUrl __attribute__((warn_unused_result("")));
		[Static]
		[NullAllowed, Export ("getCurrentSessionUrl")]
		string CurrentSessionUrl { get; }

		// +(BOOL)setCustomTagWithKey:(NSString * _Nonnull)key value:(NSString * _Nonnull)value;
		[Static]
		[Export ("setCustomTagWithKey:value:")]
		bool SetCustomTagWithKey (string key, string value);

		// +(BOOL)setCurrentScreenNameWithName:(NSString * _Nullable)name;
		[Static]
		[Export ("setCurrentScreenNameWithName:")]
		bool SetCurrentScreenNameWithName ([NullAllowed] string name);
	}
}
