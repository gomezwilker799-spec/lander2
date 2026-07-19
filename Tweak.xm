#import <AVFoundation/AVFoundation.h>

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
    });
}
%end

%ctor {
    NSLog(@"DiscordPro cargado");
}
