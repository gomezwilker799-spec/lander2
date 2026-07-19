#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

// ---- Variables globales para el audio ----
static AVAudioEngine *engine = nil;
static AVAudioUnitTimePitch *pitchNode = nil;
static AVAudioUnitDistortion *clipperNode = nil;
static AVAudioMixerNode *mixerNode = nil;

// ---- Función para configurar el audio (se ejecuta una sola vez) ----
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

// ---- Gancho en el micrófono para activar el audio y redirigir el tap ----
%hook AVAudioInputNode
- (void)installTapOnBus:(AVAudioNodeBus)bus
             bufferSize:(AVAudioFrameCount)bufferSize
                 format:(AVAudioFormat *)format
                  block:(AVAudioNodeTapBlock)block {
    // Llamar al original (Discord instala su tap, que ahora será redirigido al mixer)
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setupAudio(self);
    });

    // Redirigir el tap al mixer (audio procesado) si ya está listo
    if (mixerNode) {
        [mixerNode installTapOnBus:0 bufferSize:bufferSize format:format block:block];
    }
}
%end

// ---- Ventana flotante con el botón ----
@interface FloatingButtonWindow : UIWindow
@end

@implementation FloatingButtonWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.windowLevel = UIWindowLevelAlert + 1;
        self.rootViewController = [UIViewController new];
        self.rootViewController.view.backgroundColor = [UIColor clearColor];

        // Crear el botón redondo
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0, 0, 60, 60);
        button.center = CGPointMake(frame.size.width/2, frame.size.height/2);
        button.layer.cornerRadius = 30;
        button.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.5 alpha:0.9];
        [button setTitle:@"🎤" forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:28];
        [button addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];

        [self.rootViewController.view addSubview:button];
    }
    return self;
}

- (void)buttonTapped {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"DiscordPro"
        message:@"✅ Tweak activado.\nPitch + Clipper funcionando."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end

// ---- Constructor (se ejecuta al cargar el dylib) ----
__attribute__((constructor))
static void showFloatingButton() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat buttonSize = 60;
        // Posición: esquina inferior derecha
        CGRect frame = CGRectMake(screen.size.width - buttonSize - 20,
                                  screen.size.height - buttonSize - 100,
                                  buttonSize, buttonSize);
        FloatingButtonWindow *btnWin = [[FloatingButtonWindow alloc] initWithFrame:frame];
        btnWin.hidden = NO;
        // Mantener una referencia fuerte para que no se libere
        static FloatingButtonWindow *sharedButton = nil;
        sharedButton = btnWin;
    });
}
