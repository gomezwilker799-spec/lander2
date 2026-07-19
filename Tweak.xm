#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

// ---------------------------------------------------
// Variables globales para el audio
// ---------------------------------------------------
static AVAudioEngine *engine = nil;
static AVAudioUnitTimePitch *pitchNode = nil;
static AVAudioUnitDistortion *clipperNode = nil;
static AVAudioMixerNode *mixerNode = nil;

// ---------------------------------------------------
// Controlador que gestiona el botón flotante y el panel
// ---------------------------------------------------
@interface DiscordProController : NSObject
- (void)addFloatingButton;
- (void)showPanel:(id)sender;
@end

@implementation DiscordProController
- (void)addFloatingButton {
    // Obtener la ventana activa (UIWindowScene)
    UIWindow *targetWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    targetWindow = window;
                    break;
                }
            }
            if (targetWindow) break;
        }
    }
    if (!targetWindow) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(targetWindow.bounds.size.width - 80,
                              targetWindow.bounds.size.height - 150,
                              60, 60);
    button.layer.cornerRadius = 30;
    button.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.5 alpha:0.9];
    [button setTitle:@"🎤" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:28];
    [button addTarget:self action:@selector(showPanel:) forControlEvents:UIControlEventTouchUpInside];

    [targetWindow addSubview:button];
}

- (void)showPanel:(id)sender {
    // Obtener la ventana clave actual
    UIWindow *keyWin = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    keyWin = window;
                    break;
                }
            }
            if (keyWin) break;
        }
    }
    if (!keyWin) return;

    UIViewController *rootVC = keyWin.rootViewController;
    while (rootVC.presentedViewController) rootVC = rootVC.presentedViewController;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DiscordPro"
                                                                   message:@"✅ Tweak activado\nEfectos funcionando"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [rootVC presentViewController:alert animated:YES completion:nil];
}
@end

// ---------------------------------------------------
// Configuración de la cadena de audio
// ---------------------------------------------------
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

// ---------------------------------------------------
// Gancho en el micrófono
// ---------------------------------------------------
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
            static DiscordProController *controller = nil;
            if (!controller) {
                controller = [[DiscordProController alloc] init];
            }
            [controller addFloatingButton];
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
