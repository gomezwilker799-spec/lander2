#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

// Variables globales
static AVAudioEngine *engine = nil;
static AVAudioUnitTimePitch *pitchNode = nil;
static AVAudioUnitDistortion *clipperNode = nil;
static AVAudioMixerNode *mixerNode = nil;
static UIButton *floatingButton = nil;

// Configurar cadena de audio
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

// Añadir el botón flotante a la ventana activa de Discord
static void addFloatingButton() {
    if (floatingButton) return;

    UIWindow *targetWindow = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in scene.windows) {
                if (window.isKeyWindow) {
                    targetWindow = window;
                    break;
                }
            }
            if (targetWindow) break;
        }
    }
    if (!targetWindow) targetWindow = [UIApplication sharedApplication].windows.firstObject;
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

// Mostrar panel de confirmación (sin usar keyWindow obsoleto)
static void showPanel() {
    // Obtener la ventana clave de forma moderna
    UIWindow *keyWindow = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in scene.windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
            if (keyWindow) break;
        }
    }
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].windows.firstObject;
    if (!keyWindow) return;

    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) rootVC = rootVC.presentedViewController;

    UIAlertController *panel = [UIAlertController alertControllerWithTitle:@"DiscordPro"
                                                                   message:@"✅ Tweak activado\nEfectos funcionando"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [panel addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [rootVC presentViewController:panel animated:YES completion:nil];
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
