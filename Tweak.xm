#import <UIKit/UIKit.h>

%hook UIWindow

- (void)makeKeyAndVisible {
    // 1. Ejecutar la función original primero para que la app cargue normal
    %orig;
    
    // 2. Asegurarnos de que la alerta solo salga una vez y no cada vez que se toque una ventana
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // 3. Esperar 2 segundos a que Discord termine de renderizar su pantalla inicial
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // 4. Crear una alerta nativa de iOS (UIAlertController)
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DiscordPro"
                                                                           message:@"✅ Dylib cargado correctamente"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:ok];
            
            // 5. Buscar el controlador de vista principal (la pantalla actual) para mostrar la alerta
            UIViewController *root = self.rootViewController;
            while (root.presentedViewController) {
                root = root.presentedViewController;
            }
            
            [root presentViewController:alert animated:YES completion:nil];
        });
    });
}

%end
