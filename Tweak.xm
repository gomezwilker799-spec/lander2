#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

// Variables globales
static AVAudioEngine *engine = nil;
static AVAudioUnitTimePitch *pitchNode = nil;
static AVAudioUnitDistortion *clipperNode = nil;
static AVAudioMixerNode *mixerNode = nil;
static UIButton *floatingButton = nil;

// Configurar la cadena de audio
static void setupAudio(id inputNode) {
    if (engine) return;
    engine = [inputNode valueForKey:@"engine"];
    if (!engine) return;

    pitchNode = [[AVAudioUnitTimePitch alloc] init];
    clipperNode = [[AVAudioUnitDistortion alloc] init];
    mixerNode = [[AVAudioMixerNode alloc] init];

    [engine attachNode:pitchNode];
    [engine attachNode:clipperNode];
    [engine attachNode:mixerNode];

    [engine connect:inputNode to:pitchNode format:nil];
    [engine connect:pitchNode to:clipperNode format:nil];
    [engine connect:clipperNode to:mixerNode format:nil];

    pitchNode.pitch = 3.0;
    pitchNode.rate = 1.0;
    [clipperNode loadFactoryPreset:AVAudioUnitDistortionPresetSpeechRadioTower];
    clipperNode.preGain = 40;
    clipperNode.wetDryMix = 100;

    NSError *err;
    [engine startAndReturnError:&err];
}

// Obtener la ventana clave exclusivamente con UIWindowScene (sin fallback obsoleto)
static UIWindow *keyWindow(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }
    return nil;
}

// Añadir el botón flotante a la ventana clave
static void addFloatingButton() {
    if (floatingButton) return;

    UIWindow *targetWindow = keyWindow();
    if (!targetWindow) return;

    floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingButton.frame = CGRectMake(targetWindow.bounds.size.width - 80,
                                      targetWindow.bounds.size.height - 150,
                                      60, 60);
    floatingButton.layer.cornerRadius = 30;
    floatingButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.5 alpha:0.9];
    [floatingButton setTitle:@"🎤" forState:UIControlStateNormal];
    floatingButton.titleLabel.font = [UIFont systemFontOfSize:28];
    [floatingButton addTarget:floatingButton action:@selector(showPanel) forControlEvents:UIControlEventTouchUpInside];

    [targetWindow addSubview:floatingButton];
}

// Mostrar el panel de confirmación
static void showPanel() {
    UIWindow *targetKeyWindow = keyWindow();
    if (!targetKeyWindow) return;

    UIViewController *rootVC = targetKeyWindow.rootViewController;
    while (rootVC.presentedViewController) rootVC = rootVC.presentedViewController;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DiscordPro"
                                                                   message:@"✅ Tweak activado\nEfectos funcionando"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [rootVC presentViewController:alert animated:YES completion:nil];
}

// ---- Gancho en el micrófono ----
%hook AVAudioInputNode
- (void)installTapOnBus:(AVAudioNodeBus)bus
             bufferSize:(AVAudioFrameCount)bufferSize
                 format:(AVAudioFormat *)format
                  block:(AVAudioNodeTapBlock)block {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setupAudio(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            addFloatingButton();
        });
    });

    if (mixerNode) {
        [mixerNode installTapOnBus:0 bufferSize:bufferSize format:format block:block];
    }
}
%end

%ctor {
    NSLog(@"DiscordPro cargado");
}
