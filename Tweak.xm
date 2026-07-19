#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

@interface TestLoader : NSObject
@end

@implementation TestLoader
+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        CFUserNotificationDisplayNotice(0, kCFUserNotificationNoteAlertLevel,
            NULL, NULL, NULL,
            CFSTR("DYLIB OK"),
            CFSTR("Dylib cargado correctamente"),
            CFSTR("OK"));
    });
}
@end
