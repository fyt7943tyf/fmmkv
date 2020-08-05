#import "MmkvPlugin.h"
#if __has_include(<mmkv/mmkv-Swift.h>)
#import <mmkv/mmkv-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "mmkv-Swift.h"
#endif

@implementation MmkvPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMmkvPlugin registerWithRegistrar:registrar];
}
@end
