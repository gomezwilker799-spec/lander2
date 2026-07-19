#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

// Variables globales para el audio
static AVAudioEngine *engine = nil;
static AVAudioUnitTimePitch *pitchNode = nil;
static AVAudioUnitDistortion *clipperNode = nil;
static AVAudioMixerNode *mixerNode = nil;
static UIButton *floatingButton = nil;   // Guardamos el botón para no crearlo dos veces

// Configurar la cadena de audio (se llama una sola vez)
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

    pitchNode.pitch = 3.0;      // +3 semitonos
    pitchNode.rate = 1.0;
    [clipperNode loadFactoryPreset:AVAudioUnitDistortionPresetSpeechRadioTower];
    clipperNode.preGain = 40;
    clipperNode.wetDryMix = 100;

    NSError *err;
    [engine startAndReturnError:&err];
}

// Crear y añadir el botón flotante a la ventana principal de Discord
static void addFloatingButton() {
    if (floatingButton) return;   // ya existe

    // Obtener la ventana principal de Discord
    UIWindow *targetWindow = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            targetWindow = scene.windows.firstObject;
            break;
        }
    }
    if (!targetWindow) targetWindow = [UIApplication sharedApplication].windows.firstObject;
    if (!targetWindow) return;

    // Crear el botón redondo
    floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingButton.frame = CGRectMake(targetWindow.bounds.size.width - 80,
                                      targetWindow.bounds.size.height - 150,
                                      60, 60);
    floatingButton.layer.cornerRadius = 30;
    floatingButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.5 alpha:0.9];
    [floatingButton setTitle:@"🎤" forState:UIControlStateNormal];
    floatingButton.titleLabel.font = [UIFont systemFontOfSize:28];
    [floatingButton addTarget:floatingButton action:@selector(showControls) forControlEvents:UIControlEventTouchUpInside];

    [targetWindow addSubview:floatingButton];
}

// Mostrar un pequeño panel de control al tocar el botón
static void showControls() {
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DiscordPro"
                                                                   message:@"Pitch y Clipper activos"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cerrar" style:UIAlertActionStyleCancel handler:nil]];
    [topVC presentViewController:alert animated:YES completion:nil];
}

// Gancho en el micrófono (se ejecuta al entrar a un canal de voz)
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
            addFloatingButton();      // Añadir el botón justo al configurar el audio
        });
    });

    // Redirigir el tap al mixer
    if (mixerNode) {
        [mixerNode installTapOnBus:0 bufferSize:bufferSize format:format block:block];
    }
}
%end

%ctor {
    NSLog(@"DiscordPro cargado");
}
