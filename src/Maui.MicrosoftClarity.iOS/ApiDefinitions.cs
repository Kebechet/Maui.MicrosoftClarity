using System;
using Clarity;
using Foundation;
using ObjCRuntime;

namespace MicrosoftClarityiOS
{
	// @interface ClarityConfig : NSObject
	[BaseType (typeof(NSObject), Name = "_TtC7Clarity13ClarityConfig")]
	[DisableDefaultCtor]
	interface ClarityConfig
	{
		// -(instancetype _Nonnull)initWithProjectId:(NSString * _Nonnull)projectId;
		[Export ("initWithProjectId:")]
		NativeHandle Constructor (string projectId);

		// @property (copy, nonatomic) SWIFT_DEPRECATED_MSG("This property is deprecated and would be removed in a future major version. Use `ClaritySDK.setCustomUserId(_:)` instead.") NSString * userId __attribute__((deprecated("This property is deprecated and would be removed in a future major version. Use `ClaritySDK.setCustomUserId(_:)` instead.")));
		[Export ("userId")]
		string UserId { get; set; }

		// @property (nonatomic) enum ClarityLogLevel logLevel;
		[Export ("logLevel", ArgumentSemantic.Assign)]
		ClarityLogLevel LogLevel { get; set; }

		// @property (nonatomic) enum ClarityApplicationFramework applicationFramework;
		[Export ("applicationFramework", ArgumentSemantic.Assign)]
		ClarityApplicationFramework ApplicationFramework { get; set; }

		// @property (copy, nonatomic) void (^ _Nullable)(NSString * _Nonnull, NSString * _Nullable) customSignalsCallback;
		[NullAllowed, Export ("customSignalsCallback", ArgumentSemantic.Copy)]
		Action<NSString, NSString> CustomSignalsCallback { get; set; }
	}

	// @interface ClaritySDK : NSObject
	[BaseType (typeof(NSObject), Name = "_TtC7Clarity10ClaritySDK")]
	interface ClaritySDK
	{
		// +(BOOL)initializeWithConfig:(ClarityConfig * _Nonnull)config;
		[Static]
		[Export ("initializeWithConfig:")]
		bool InitializeWithConfig (ClarityConfig config);

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
		[Verify (MethodToProperty)]
		bool IsPaused { get; }

		// +(BOOL)startNewSessionWithCallback:(void (^ _Nullable)(NSString * _Nonnull))callback;
		[Static]
		[Export ("startNewSessionWithCallback:")]
		bool StartNewSessionWithCallback ([NullAllowed] Action<NSString> callback);

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

		// +(NSString * _Nullable)getCurrentSessionId __attribute__((warn_unused_result(""))) __attribute__((deprecated("This function is deprecated and will be removed in a future major version. Please use `ClaritySDK.getCurrentSessionUrl()` instead.")));
		[Static]
		[NullAllowed, Export ("getCurrentSessionId")]
		[Verify (MethodToProperty)]
		string CurrentSessionId { get; }

		// +(NSString * _Nullable)getCurrentSessionUrl __attribute__((warn_unused_result("")));
		[Static]
		[NullAllowed, Export ("getCurrentSessionUrl")]
		[Verify (MethodToProperty)]
		string CurrentSessionUrl { get; }

		// +(BOOL)setCustomTagWithKey:(NSString * _Nonnull)key value:(NSString * _Nonnull)value;
		[Static]
		[Export ("setCustomTagWithKey:value:")]
		bool SetCustomTagWithKey (string key, string value);

		// +(BOOL)setCustomTagWithKey:(NSString * _Nonnull)key values:(NSSet<NSString *> * _Nonnull)values;
		[Static]
		[Export ("setCustomTagWithKey:values:")]
		bool SetCustomTagWithKey (string key, NSSet<NSString> values);

		// +(BOOL)sendCustomEventWithValue:(NSString * _Nonnull)value;
		[Static]
		[Export ("sendCustomEventWithValue:")]
		bool SendCustomEventWithValue (string value);

		// +(BOOL)setCurrentScreenName:(NSString * _Nullable)name;
		[Static]
		[Export ("setCurrentScreenName:")]
		bool SetCurrentScreenName ([NullAllowed] string name);

		// +(BOOL)setOnSessionStartedCallback:(void (^ _Nonnull)(NSString * _Nonnull))callback;
		[Static]
		[Export ("setOnSessionStartedCallback:")]
		bool SetOnSessionStartedCallback (Action<NSString> callback);

		// +(BOOL)consentWithAnalyticsStorage:(BOOL)analyticsStorage;
		[Static]
		[Export ("consentWithAnalyticsStorage:")]
		bool ConsentWithAnalyticsStorage (bool analyticsStorage);
	}
}
