using System;
using Foundation;
using ObjCRuntime;
using UIKit;

namespace MicrosoftClarityiOS
{
    // @interface ClarityConfig : NSObject
    [BaseType(typeof(NSObject), Name = "_TtC7Clarity13ClarityConfig")]
    [DisableDefaultCtor]
    interface ClarityConfig
    {
        // -(instancetype _Nonnull)initWithProjectId:(NSString * _Nonnull)projectId;
        [Export("initWithProjectId:")]
        NativeHandle Constructor(string projectId);

        // @property (copy, nonatomic) NSString * _Nullable userId;
        [NullAllowed, Export("userId")]
        string UserId { get; set; }

        // @property (nonatomic) enum LogLevel logLevel;
        [Export("logLevel", ArgumentSemantic.Assign)]
        LogLevel LogLevel { get; set; }

        // @property (nonatomic) BOOL allowMeteredNetworkUsage;
        [Export("allowMeteredNetworkUsage")]
        bool AllowMeteredNetworkUsage { get; set; }

        // @property (nonatomic) BOOL enableWebViewCapture;
        [Export("enableWebViewCapture")]
        bool EnableWebViewCapture { get; set; }

        // @property (nonatomic) BOOL disableOnLowEndDevices;
        [Export("disableOnLowEndDevices")]
        bool DisableOnLowEndDevices { get; set; }

        // @property (nonatomic) enum ApplicationFramework applicationFramework;
        [Export("applicationFramework", ArgumentSemantic.Assign)]
        ApplicationFramework ApplicationFramework { get; set; }

        // @property (nonatomic) BOOL enableSwiftUI_Experimental;
        [Export("enableSwiftUI_Experimental")]
        bool EnableSwiftUI_Experimental { get; set; }
    }

    // @interface ClaritySDK : NSObject
    [BaseType(typeof(NSObject), Name = "_TtC7Clarity10ClaritySDK")]
    interface ClaritySDK
    {
        // +(void)initializeWithConfig:(ClarityConfig * _Nonnull)config;
        [Static]
        [Export("initializeWithConfig:")]
        void InitializeWithConfig(ClarityConfig config);

        // +(void)initializeWithConfig:(ClarityConfig * _Nonnull)config onClarityInitialized:(void (^ _Nonnull)(void))onClarityInitialized;
        [Static]
        [Export("initializeWithConfig:onClarityInitialized:")]
        void InitializeWithConfig(ClarityConfig config, Action onClarityInitialized);

        // +(void)pause;
        [Static]
        [Export("pause")]
        void Pause();

        // +(void)resume;
        [Static]
        [Export("resume")]
        void Resume();

        // +(BOOL)isPaused __attribute__((warn_unused_result("")));
        [Static]
        [Export("isPaused")]
        bool IsPaused { get; }

        // +(void)maskView:(UIView * _Nonnull)view;
        [Static]
        [Export("maskView:")]
        void MaskView(UIView view);

        // +(void)unmaskView:(UIView * _Nonnull)view;
        [Static]
        [Export("unmaskView:")]
        void UnmaskView(UIView view);

        // +(BOOL)setCustomUserId:(NSString * _Nonnull)customUserId;
        [Static]
        [Export("setCustomUserId:")]
        bool SetCustomUserId(string customUserId);

        // +(BOOL)setCustomSessionId:(NSString * _Nonnull)customSessionId;
        [Static]
        [Export("setCustomSessionId:")]
        bool SetCustomSessionId(string customSessionId);

        // +(NSString * _Nullable)getCurrentSessionId __attribute__((warn_unused_result("")));
        [Static]
        [NullAllowed, Export("getCurrentSessionId")]
        string CurrentSessionId { get; }

        // +(NSString * _Nullable)getCurrentSessionUrl __attribute__((warn_unused_result("")));
        [Static]
        [NullAllowed, Export("getCurrentSessionUrl")]
        string CurrentSessionUrl { get; }

        // +(BOOL)setCustomTagWithKey:(NSString * _Nonnull)key value:(NSString * _Nonnull)value;
        [Static]
        [Export("setCustomTagWithKey:value:")]
        bool SetCustomTagWithKey(string key, string value);

        // +(BOOL)setCurrentScreenNameWithName:(NSString * _Nullable)name;
        [Static]
        [Export("setCurrentScreenNameWithName:")]
        bool SetCurrentScreenNameWithName([NullAllowed] string name);

        // +(BOOL)setOnNewSessionStartedCallback:(void (^ _Nonnull)(NSString * _Nonnull))callback;
        [Static]
        [Export("setOnNewSessionStartedCallback:")]
        bool SetOnNewSessionStartedCallback(Action<NSString> callback);
    }
}
