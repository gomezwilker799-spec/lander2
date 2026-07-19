#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Variable para el botón
static UIButton *floatingButton = nil;

// Función para mostrar el botón en la ventana principal
static void addFloatingButton() {
    if (floatingButton) return;

    // Obtener la ventana activa
    UIWindow *targetWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        targetWindow = window;
                        break;
                    }
                }
                if (targetWindow) break;
            }
        }
    }
    if (!targetWindow) return;

    floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingButton.frame = CGRectMake(targetWindow.bounds.size.width - 80,
                                      targetWindow.bounds.size.height - 150,
                                      60, 60);
    floatingButton.layer.cornerRadius = 30;
    floatingButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.5 alpha:0.9];
    [floatingButton setTitle:@"🎤" forState:UIControlStateNormal];
    floatingButton.titleLabel.font = [UIFont systemFontOfSize:28];
    [floatingButton addTarget:floatingButton action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
    [targetWindow addSubview:floatingButton];
}

// Acción del botón
static void buttonTapped() {
    // Aquí puedes poner cualquier cosa, por ejemplo mostrar una alerta
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"OK" message:@"Funciona" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    UIWindow *keyWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = windowScene.keyWindow;
                break;
            }
        }
    }
    if (keyWindow) {
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

// Constructor que se ejecuta al cargar el dylib
__attribute__((constructor))
static void loadMe() {
    // Esperamos 1 segundo para que Discord termine de cargar
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        addFloatingButton();
    });
}
