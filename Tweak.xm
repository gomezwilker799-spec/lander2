#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

%hook AVAudioInputNode
- (void)installTapOnBus:(AVAudioNodeBus)bus
             bufferSize:(AVAudioFrameCount)bufferSize
                 format:(AVAudioFormat *)format
                  block:(AVAudioNodeTapBlock)block {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AVAudioEngine *engine = self.engine;
        AVAudioUnitTimePitch *pitch = [[AVAudioUnitTimePitch alloc] init];
        AVAudioUnitDistortion *clipper = [[AVAudioUnitDistortion alloc] init];
        AVAudioMixerNode *mixer = [[AVAudioMixerNode alloc] init];

        [engine attachNode:pitch];
        [engine attachNode:clipper];
        [engine attachNode:mixer];

        [engine connect:self to:pitch format:format];
        [engine connect:pitch to:clipper format:format];
        [engine connect:clipper to:mixer format:format];

        pitch.pitch = 3.0;
        pitch.rate = 1.0;
        [clipper loadFactoryPreset:AVAudioUnitDistortionPresetSpeechRadioTower];
        clipper.preGain = 40;
        clipper.wetDryMix = 100;

        NSError *err;
        [engine startAndReturnError:&err];

        // Mostrar alerta de confirmación (forma moderna, sin keyWindow obsoleto)
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"DiscordPro"
                message:@"✅ Tweak activado correctamente.\nPitch + Clipper extremo funcionando."
                preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

            // Obtener la ventana clave de la escena activa
            UIWindow *keyWindow = nil;
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (keyWindow) break;
                }
            }

            UIViewController *rootVC = keyWindow.rootViewController;
            [rootVC presentViewController:alert animated:YES completion:nil];
        });
    });
}
%end

%ctor {
    NSLog(@"DiscordPro cargado");
}
