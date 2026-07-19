// Tweak.xm – solo alerta
#import <CoreFoundation/CoreFoundation.h>

__attribute__((constructor))
static void showAlert() {
    CFUserNotificationDisplayNotice(0, kCFUserNotificationNoteAlertLevel,
        NULL, NULL, NULL,
        CFSTR("DiscordPro"),
        CFSTR("✅ Dylib cargado correctamente.\nLa inyección funciona."),
        CFSTR("OK"));
}
