#import <CoreFoundation/CoreFoundation.h>

static void mostrarAlerta() {
    CFUserNotificationDisplayNotice(0, kCFUserNotificationNoteAlertLevel,
        NULL, NULL, NULL,
        CFSTR("DiscordPro"),
        CFSTR("✅ Dylib cargado correctamente.\nLa inyección funciona."),
        CFSTR("OK"));
}

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        mostrarAlerta();
    });
}
