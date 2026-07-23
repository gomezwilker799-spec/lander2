#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreImage/CoreImage.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <QuartzCore/QuartzCore.h>
#import <Accelerate/Accelerate.h>

// ============================================================
// CADENA DE AUDIO (se activa al entrar a un canal de voz)
// ============================================================
static AVAudioEngine *engine = nil;
static AVAudioUnitTimePitch *pitchNode = nil;
static AVAudioUnitDistortion *clipperNode = nil;
static AVAudioMixerNode *mixerNode = nil;
static bool audioChainBuilt = NO;

static void buildAudioChain(id inputNode, AVAudioFormat *format) {
    if (audioChainBuilt) return;
    engine = [inputNode valueForKey:@"engine"];
    if (!engine) return;

    pitchNode = [[AVAudioUnitTimePitch alloc] init];
    clipperNode = [[AVAudioUnitDistortion alloc] init];
    mixerNode = [[AVAudioMixerNode alloc] init];

    [engine attachNode:pitchNode];
    [engine attachNode:clipperNode];
    [engine attachNode:mixerNode];

    [engine connect:inputNode to:pitchNode format:format];
    [engine connect:pitchNode to:clipperNode format:format];
    [engine connect:clipperNode to:mixerNode format:format];

    pitchNode.pitch = 0.0;
    pitchNode.rate = 1.0;
    [clipperNode loadFactoryPreset:AVAudioUnitDistortionPresetSpeechRadioTower];
    clipperNode.preGain = 20;
    clipperNode.wetDryMix = 50;

    NSError *err;
    [engine startAndReturnError:&err];
    audioChainBuilt = YES;
}

// ============================================================
// INTERFAZ FLOTANTE (aparece al entrar a un canal de voz)
// ============================================================
@interface AudioPanelController : NSObject
- (void)showPanel;
@end

@implementation AudioPanelController
- (void)showPanel {
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

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(targetWindow.bounds.size.width - 80,
                              targetWindow.bounds.size.height - 150,
                              60, 60);
    button.layer.cornerRadius = 30;
    button.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.5 alpha:0.9];
    [button setTitle:@"🎤" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:28];
    [button addTarget:self action:@selector(openControls) forControlEvents:UIControlEventTouchUpInside];
    [targetWindow addSubview:button];
}

- (void)openControls {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Tweak Completo"
                                                                   message:@"✅ Botón y audio activos"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    
    UIWindow *keyWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
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
    }
    [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}
@end

// ============================================================
// GANCHO: se ejecuta cuando Discord configura el micrófono
// ============================================================
%hook AVAudioInputNode
- (void)installTapOnBus:(AVAudioNodeBus)bus
             bufferSize:(AVAudioFrameCount)bufferSize
                 format:(AVAudioFormat *)format
                  block:(AVAudioNodeTapBlock)block {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        buildAudioChain(self, format);
        dispatch_async(dispatch_get_main_queue(), ^{
            static AudioPanelController *panel = nil;
            if (!panel) panel = [[AudioPanelController alloc] init];
            [panel showPanel];
        });
    });
    if (mixerNode) {
        [mixerNode installTapOnBus:0 bufferSize:bufferSize format:format block:block];
    }
}
%end

%ctor {
    NSLog(@"Tweak cargado con todos los frameworks");
}
