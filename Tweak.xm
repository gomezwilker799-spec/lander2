#include <CoreFoundation/CoreFoundation.h>

__attribute__((constructor))
static void showAlert() {
    CFUserNotificationDisplayNotice(
        0,
        kCFUserNotificationNoteAlertLevel,
        NULL,
        NULL,
        NULL,
        CFSTR("DYLIB TEST"),
        CFSTR("✅ Dylib cargado correctamente."),
        CFSTR("OK")
    );
}
