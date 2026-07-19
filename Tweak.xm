#import <UIKit/UIKit.h>

// Clase que maneja el botón
@interface DiscordProController : NSObject
- (void)buttonTapped:(id)sender;
@end

@implementation DiscordProController
- (void)buttonTapped:(id)sender {
    // Obtener la ventana activa para mostrar la alerta
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
    if (!keyWindow) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"OK"
                                                                   message:@"✅ Dylib cargado y funcionando"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}
@end

__attribute__((constructor))
static void loadMe() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // Obtener la ventana principal
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

        // Crear el botón flotante
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(targetWindow.bounds.size.width - 80,
                                  targetWindow.bounds.size.height - 150,
                                  60, 60);
        button.layer.cornerRadius = 30;
        button.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.5 alpha:0.9];
        [button setTitle:@"🎤" forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:28];

        // El target es una instancia de DiscordProController
        static DiscordProController *controller = nil;
        if (!controller) controller = [[DiscordProController alloc] init];
        [button addTarget:controller action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];

        [targetWindow addSubview:button];
    });
}
