// ============================================================
// Tweak.xm – lander deval hook (Versión Final Completa con Grabación)
// ============================================================
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

// ------------------------------------------------------------
// Parámetros globales
// ------------------------------------------------------------
typedef struct {
    float gain;
    BOOL  micMutedManual;
    BOOL  useBlazin, useOverMode, useExtremeClipper;
    float eqBody, eqMud, eqPresence, eqBite;
    float clipKnee, clipCeiling;
    float micPosX, micPosY, micPosZ;
    BOOL  micAutoPan; float micAutoPanSpeed;
    float micXMod, micXModSpeed, micYMod, micYModSpeed;
    float micInHeadPan;
    BOOL  micAutoInHead; float micAutoInHeadSpeed;
    BOOL  micAutoDodge, micPanToOpponent;
    float micPitch;
    BOOL  micReverb; float micReverbVol, micReverbDecay;
    float micDrive, micHaas, micWider, micQuickHaas;
    BOOL  micReverbCounter; float micReverbCounterThreshold;
    BOOL  micCombinePos, micCombineHaas, micCombineWider, micCombineInHead;
    float mp3Vol;
    BOOL  muteMicOnMp3, autoStopMp3OnMute, isMp3Playing;
    BOOL  selfMonitor; float selfMonitorVol;
    float noiseInjection;
    NSString *micPreset;
} AudioParams;

static AudioParams gParams = {
    .gain = 1.0, .micMutedManual = YES,
    .useBlazin = NO, .useOverMode = NO, .useExtremeClipper = NO,
    .eqBody = 0, .eqMud = 0, .eqPresence = 0, .eqBite = 0,
    .clipKnee = 5, .clipCeiling = 0,
    .micPosX = 0, .micPosY = 0, .micPosZ = 0,
    .micAutoPan = NO, .micAutoPanSpeed = 0.5,
    .micXMod = 0, .micXModSpeed = 0.5, .micYMod = 0, .micYModSpeed = 0.5,
    .micInHeadPan = 0, .micAutoInHead = NO, .micAutoInHeadSpeed = 5,
    .micAutoDodge = NO, .micPanToOpponent = NO,
    .micPitch = 0, .micReverb = NO, .micReverbVol = 0.6, .micReverbDecay = 0.4,
    .micDrive = 60, .micHaas = 0, .micWider = 0, .micQuickHaas = 0,
    .micReverbCounter = NO, .micReverbCounterThreshold = -30,
    .micCombinePos = NO, .micCombineHaas = NO, .micCombineWider = NO, .micCombineInHead = NO,
    .mp3Vol = 3.0, .muteMicOnMp3 = YES, .autoStopMp3OnMute = YES, .isMp3Playing = NO,
    .selfMonitor = NO, .selfMonitorVol = 1.0, .noiseInjection = 0,
    .micPreset = @"Manual"
};

// ------------------------------------------------------------
// Nodos de audio globales
// ------------------------------------------------------------
static AVAudioEngine *engine = nil;
static AVAudioInputNode *inputNode = nil;
static AVAudioMixerNode *mixer = nil;
static AVAudioUnitEQ *eqUnit = nil;
static AVAudioUnitDynamicsProcessor *compressor = nil;
static AVAudioUnitDistortion *distortion = nil;
static AVAudioUnitReverb *reverbUnit = nil;
static AVAudioUnitTimePitch *pitchUnit = nil;
static AVAudioUnitDelay *delayUnit = nil;
static AVAudioPanner3D *panner3D = nil;
static AVAudioPlayerNode *mp3Player = nil;
static AVAudioFile *mp3File = nil;
static AVAudioMixerNode *monitorMixer = nil;
static CADisplayLink *autoPanTimer = nil;
static float autoPanPhaseX = 0, autoPanPhaseY = 0;

// Grabación
static BOOL isRecording = NO;
static AVAudioFile *recordedFile = nil;
static NSURL *recordedFileURL = nil;

// Panel
static UIView *floatingPanel = nil;
static UILabel *levelLabel = nil;
static UIButton *recButton = nil;

// ------------------------------------------------------------
// Configuración de la cadena de audio
// ------------------------------------------------------------
static void buildAudioChain(void) {
    if (engine) return;
    engine = [[AVAudioEngine alloc] init];
    inputNode = engine.inputNode;
    mixer = [[AVAudioMixerNode alloc] init];
    [engine attachNode:mixer];

    eqUnit = [[AVAudioUnitEQ alloc] initWithNumberOfBands:4];
    [engine attachNode:eqUnit];
    compressor = [[AVAudioUnitDynamicsProcessor alloc] init];
    [engine attachNode:compressor];
    distortion = [[AVAudioUnitDistortion alloc] init];
    [engine attachNode:distortion];
    reverbUnit = [[AVAudioUnitReverb alloc] init];
    [engine attachNode:reverbUnit];
    pitchUnit = [[AVAudioUnitTimePitch alloc] init];
    [engine attachNode:pitchUnit];
    delayUnit = [[AVAudioUnitDelay alloc] init];
    [engine attachNode:delayUnit];

    if (@available(iOS 15.0, *)) {
        panner3D = [[AVAudioPanner3D alloc] init];
        [engine attachNode:panner3D];
    }

    // Cadena: input -> EQ -> comp -> dist -> reverb -> pitch -> delay -> panner -> mixer
    [engine connect:inputNode to:eqUnit format:nil];
    [engine connect:eqUnit to:compressor format:nil];
    [engine connect:compressor to:distortion format:nil];
    [engine connect:distortion to:reverbUnit format:nil];
    [engine connect:reverbUnit to:pitchUnit format:nil];
    [engine connect:pitchUnit to:delayUnit format:nil];
    if (panner3D) {
        [engine connect:delayUnit to:panner3D format:nil];
        [engine connect:panner3D to:mixer format:nil];
    } else {
        [engine connect:delayUnit to:mixer format:nil];
    }

    // Valores iniciales
    eqUnit.bands[0].filterType = AVAudioUnitEQFilterTypeLowShelf;   eqUnit.bands[0].frequency = 200;
    eqUnit.bands[1].filterType = AVAudioUnitEQFilterTypeParametric; eqUnit.bands[1].frequency = 500;
    eqUnit.bands[2].filterType = AVAudioUnitEQFilterTypeParametric; eqUnit.bands[2].frequency = 3000;
    eqUnit.bands[3].filterType = AVAudioUnitEQFilterTypeHighShelf;  eqUnit.bands[3].frequency = 8000;
    for (AVAudioUnitEQFilterParameters *band in eqUnit.bands) band.gain = 0;

    compressor.threshold = -20; compressor.headRoom = 5;
    compressor.attackTime = 0.01; compressor.releaseTime = 0.3; compressor.masterGain = 0;

    [distortion loadFactoryPreset:AVAudioUnitDistortionPresetDrumsBitBrush];
    distortion.preGain = 0; distortion.wetDryMix = 0;

    [reverbUnit loadFactoryPreset:AVAudioUnitReverbPresetMediumRoom];
    reverbUnit.wetDryMix = 0;

    pitchUnit.pitch = 0; pitchUnit.rate = 1.0;
    delayUnit.delayTime = 0.1; delayUnit.feedback = 0; delayUnit.wetDryMix = 0;

    if (panner3D) panner3D.position = AVAudioMake3DPoint(0, 0, 0);

    NSError *err;
    [engine startAndReturnError:&err];
    if (err) NSLog(@"lander deval hook: error engine %@", err);

    // Medidor de nivel + grabación en el mixer
    [mixer installTapOnBus:0 bufferSize:1024 format:nil block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        // Medidor
        float sum = 0;
        for (int i = 0; i < buffer.frameLength; i++) {
            float sample = buffer.floatChannelData[0][i];
            sum += sample * sample;
        }
        float rms = sqrtf(sum / buffer.frameLength);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (levelLabel) {
                float db = 20 * log10f(rms);
                if (isinf(db) || isnan(db)) db = -100;
                levelLabel.text = [NSString stringWithFormat:@"%.1f dB", db];
            }
        });

        // Grabación
        if (isRecording && recordedFile) {
            NSError *err;
            [recordedFile writeFromBuffer:buffer error:&err];
            if (err) NSLog(@"lander deval hook: error grabando %@", err);
        }
    }];
}

// ------------------------------------------------------------
// Aplicar parámetros
// ------------------------------------------------------------
static void applyParams(void) {
    if (!engine || !engine.isRunning) return;

    BOOL muteMic = gParams.micMutedManual || (gParams.isMp3Playing && gParams.muteMicOnMp3);
    mixer.outputVolume = muteMic ? 0.0 : gParams.gain;

    eqUnit.bands[0].gain = gParams.eqBody;
    eqUnit.bands[1].gain = gParams.eqMud;
    eqUnit.bands[2].gain = gParams.eqPresence;
    eqUnit.bands[3].gain = gParams.eqBite;

    if (gParams.useExtremeClipper) {
        distortion.wetDryMix = 100;
        distortion.preGain = gParams.micDrive * 1.05;
        [distortion loadFactoryPreset:AVAudioUnitDistortionPresetSpeechRadioTower];
    } else if (gParams.useOverMode) {
        distortion.wetDryMix = 100;
        distortion.preGain = gParams.micDrive * 0.2;
        [distortion loadFactoryPreset:AVAudioUnitDistortionPresetDrumsBitBrush];
    } else {
        distortion.wetDryMix = gParams.micDrive > 0 ? 50 : 0;
        distortion.preGain = gParams.micDrive;
    }

    reverbUnit.wetDryMix = gParams.micReverb ? gParams.micReverbVol * 100 : 0;
    pitchUnit.pitch = gParams.micPitch;

    if (gParams.micQuickHaas > 0) {
        delayUnit.wetDryMix = 100;
        delayUnit.delayTime = gParams.micQuickHaas / 1000.0;
    } else {
        delayUnit.wetDryMix = gParams.micHaas > 0 ? 50 : 0;
        delayUnit.delayTime = gParams.micHaas / 1000.0;
    }

    if (panner3D) {
        if (gParams.micAutoPan) {
            // se actualiza con timer
        } else if (gParams.micAutoDodge || gParams.micPanToOpponent) {
            static float t = 0; t += 0.1;
            float x = sinf(t * 0.5) * 5.0;
            float y = cosf(t * 0.3) * 3.0;
            panner3D.position = AVAudioMake3DPoint(x, y, gParams.micPosZ);
        } else {
            panner3D.position = AVAudioMake3DPoint(gParams.micPosX, gParams.micPosY, gParams.micPosZ);
        }
    }

    // Autoescucha
    if (gParams.selfMonitor) {
        if (!monitorMixer) {
            monitorMixer = [[AVAudioMixerNode alloc] init];
            [engine attachNode:monitorMixer];
            [engine connect:mixer to:monitorMixer format:nil];
            [engine connect:monitorMixer to:engine.mainMixerNode format:nil];
        }
        monitorMixer.outputVolume = gParams.selfMonitorVol;
    } else {
        if (monitorMixer) {
            [engine disconnectNodeInput:monitorMixer];
            [engine detachNode:monitorMixer];
            monitorMixer = nil;
        }
    }

    if (mp3Player) mp3Player.volume = gParams.mp3Vol / 10.0;
}

// ------------------------------------------------------------
// Auto‑pan timer
// ------------------------------------------------------------
static void startAutoPanTimer(void) {
    if (autoPanTimer) return;
    autoPanTimer = [CADisplayLink displayLinkWithTarget:[NSObject class] selector:@selector(updateAutoPan)];
    [autoPanTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

+ (void)updateAutoPan {
    if (!panner3D || !gParams.micAutoPan) return;
    float dt = autoPanTimer.duration;
    autoPanPhaseX += gParams.micXModSpeed * dt * 2 * M_PI;
    autoPanPhaseY += gParams.micYModSpeed * dt * 2 * M_PI;
    float x = sinf(autoPanPhaseX) * gParams.micXMod * 5.0;
    float y = cosf(autoPanPhaseY) * gParams.micYMod * 5.0;
    panner3D.position = AVAudioMake3DPoint(x, y, gParams.micPosZ);
}

// ------------------------------------------------------------
// Interfaz de usuario
// ------------------------------------------------------------
@interface AudioPanelController : NSObject <UIDocumentPickerDelegate>
- (void)showPanel;
@end

@implementation AudioPanelController

- (void)showPanel {
    if (floatingPanel) return;

    UIWindow *targetWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) { targetWindow = window; break; }
                }
                if (targetWindow) break;
            }
        }
    }
    if (!targetWindow) return;

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(10, 60, 320, 480)];
    scrollView.contentSize = CGSizeMake(320, 1450);
    scrollView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    scrollView.layer.cornerRadius = 12;
    scrollView.clipsToBounds = YES;
    floatingPanel = scrollView;

    float y = 10, left = 10, width = 300;

    // Título con tu marca
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(left, y, width, 30)];
    title.text = @"lander deval hook"; 
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:16];
    [scrollView addSubview:title]; y += 40;

    // Cerrar
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(width-40, 10, 30, 30);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:closeBtn];

    // ===== Grabación =====
    [self addLabel:@"Grabación" atY:y inView:scrollView]; y += 20;
    recButton = [UIButton buttonWithType:UIButtonTypeSystem];
    recButton.frame = CGRectMake(left, y, 280, 30);
    [recButton setTitle:@"🔴 REC" forState:UIControlStateNormal];
    [recButton addTarget:self action:@selector(toggleRecording) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:recButton];
    y += 35;

    // ===== MP3 =====
    [self addLabel:@"Reproductor MP3" atY:y inView:scrollView]; y += 20;
    UIButton *loadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    loadBtn.frame = CGRectMake(left, y, 130, 30);
    [loadBtn setTitle:@"Cargar MP3" forState:UIControlStateNormal];
    [loadBtn addTarget:self action:@selector(loadMP3) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:loadBtn];

    UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    playBtn.frame = CGRectMake(150, y, 50, 30);
    [playBtn setTitle:@"▶️" forState:UIControlStateNormal];
    [playBtn addTarget:self action:@selector(toggleMP3) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:playBtn];

    UIButton *stopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    stopBtn.frame = CGRectMake(210, y, 50, 30);
    [stopBtn setTitle:@"⏹️" forState:UIControlStateNormal];
    [stopBtn addTarget:self action:@selector(stopMP3) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:stopBtn];
    y += 35;

    UISlider *mp3VolSlider = [self sliderAtY:y label:@"Vol MP3" min:0 max:10 value:gParams.mp3Vol action:@selector(mp3VolChanged:) inView:scrollView];
    y += 30;

    // ===== Globales =====
    [self addLabel:@"Controles Globales" atY:y inView:scrollView]; y += 20;
    UISlider *gainSlider = [self sliderAtY:y label:@"Gain" min:0 max:10 value:gParams.gain action:@selector(gainChanged:) inView:scrollView]; y += 30;

    // ===== Ecualizador =====
    [self addLabel:@"Ecualizador" atY:y inView:scrollView]; y += 20;
    UISlider *bodySlider = [self sliderAtY:y label:@"Body (200Hz)" min:-20 max:20 value:gParams.eqBody action:@selector(eqBodyChanged:) inView:scrollView]; y += 30;
    UISlider *mudSlider  = [self sliderAtY:y label:@"Mud (500Hz)" min:-20 max:20 value:gParams.eqMud action:@selector(eqMudChanged:) inView:scrollView]; y += 30;
    UISlider *presSlider = [self sliderAtY:y label:@"Pres (3kHz)" min:-20 max:20 value:gParams.eqPresence action:@selector(eqPresChanged:) inView:scrollView]; y += 30;
    UISlider *biteSlider = [self sliderAtY:y label:@"Bite (7.5kHz)" min:-20 max:20 value:gParams.eqBite action:@selector(eqBiteChanged:) inView:scrollView]; y += 30;

    // ===== Efectos =====
    [self addLabel:@"Efectos" atY:y inView:scrollView]; y += 20;
    UISlider *pitchSlider = [self sliderAtY:y label:@"Pitch (semit)" min:-12 max:12 value:gParams.micPitch action:@selector(pitchChanged:) inView:scrollView]; y += 30;
    UISlider *driveSlider = [self sliderAtY:y label:@"Drive" min:1 max:400 value:gParams.micDrive action:@selector(driveChanged:) inView:scrollView]; y += 30;
    UISlider *reverbSlider = [self sliderAtY:y label:@"Reverb Vol" min:0 max:3 value:gParams.micReverbVol action:@selector(reverbVolChanged:) inView:scrollView]; y += 30;
    UISlider *haasSlider = [self sliderAtY:y label:@"Haas (ms)" min:0 max:35 value:gParams.micHaas action:@selector(haasChanged:) inView:scrollView]; y += 30;
    UISlider *widerSlider = [self sliderAtY:y label:@"Wider" min:0 max:1 value:gParams.micWider action:@selector(widerChanged:) inView:scrollView]; y += 30;
    UISlider *quickHaasSlider = [self sliderAtY:y label:@"Quick Haas (ms)" min:0 max:40 value:gParams.micQuickHaas action:@selector(quickHaasChanged:) inView:scrollView]; y += 30;

    // ===== Clipper =====
    [self addLabel:@"Clipper Avanzado" atY:y inView:scrollView]; y += 20;
    UISlider *kneeSlider = [self sliderAtY:y label:@"Knee" min:0 max:40 value:gParams.clipKnee action:@selector(clipKneeChanged:) inView:scrollView]; y += 30;
    UISlider *ceilSlider = [self sliderAtY:y label:@"Ceiling (dB)" min:-30 max:10 value:gParams.clipCeiling action:@selector(clipCeilingChanged:) inView:scrollView]; y += 30;

    // ===== Espacio 3D =====
    [self addLabel:@"Espacio 3D" atY:y inView:scrollView]; y += 20;
    UISlider *posXSlider = [self sliderAtY:y label:@"Pos X" min:-10 max:10 value:gParams.micPosX action:@selector(posXChanged:) inView:scrollView]; y += 30;
    UISlider *posYSlider = [self sliderAtY:y label:@"Pos Y" min:-10 max:10 value:gParams.micPosY action:@selector(posYChanged:) inView:scrollView]; y += 30;
    UISlider *posZSlider = [self sliderAtY:y label:@"Pos Z" min:-10 max:10 value:gParams.micPosZ action:@selector(posZChanged:) inView:scrollView]; y += 30;

    // Auto‑pan switch
    UISwitch *autoPanSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(left, y, 50, 30)];
    [autoPanSwitch addTarget:self action:@selector(autoPanToggled:) forControlEvents:UIControlEventValueChanged];
    autoPanSwitch.on = gParams.micAutoPan;
    [scrollView addSubview:autoPanSwitch];
    UILabel *autoPanLbl = [[UILabel alloc] initWithFrame:CGRectMake(70, y, 150, 30)];
    autoPanLbl.text = @"Auto Pan"; autoPanLbl.textColor = [UIColor whiteColor]; autoPanLbl.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:autoPanLbl];
    y += 35;

    UISlider *autoPanSpeedSlider = [self sliderAtY:y label:@"Vel. Pan" min:0.1 max:10 value:gParams.micAutoPanSpeed action:@selector(autoPanSpeedChanged:) inView:scrollView]; y += 30;

    // In‑Head switch
    UISwitch *inHeadSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(left, y, 50, 30)];
    [inHeadSwitch addTarget:self action:@selector(inHeadToggled:) forControlEvents:UIControlEventValueChanged];
    inHeadSwitch.on = gParams.micAutoInHead;
    [scrollView addSubview:inHeadSwitch];
    UILabel *inHeadLbl = [[UILabel alloc] initWithFrame:CGRectMake(70, y, 150, 30)];
    inHeadLbl.text = @"Auto In‑Head"; inHeadLbl.textColor = [UIColor whiteColor]; inHeadLbl.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:inHeadLbl];
    y += 35;

    // ===== Modos =====
    [self addLabel:@"Modos" atY:y inView:scrollView]; y += 20;
    UISwitch *blazinSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(left, y, 50, 30)];
    [blazinSwitch addTarget:self action:@selector(blazinToggled:) forControlEvents:UIControlEventValueChanged];
    blazinSwitch.on = gParams.useBlazin;
    [scrollView addSubview:blazinSwitch];
    UILabel *blazinLbl = [[UILabel alloc] initWithFrame:CGRectMake(70, y, 200, 30)];
    blazinLbl.text = @"Blazin (EQ+Haas)"; blazinLbl.textColor = [UIColor whiteColor]; blazinLbl.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:blazinLbl];
    y += 35;

    UISwitch *overSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(left, y, 50, 30)];
    [overSwitch addTarget:self action:@selector(overToggled:) forControlEvents:UIControlEventValueChanged];
    overSwitch.on = gParams.useOverMode;
    [scrollView addSubview:overSwitch];
    UILabel *overLbl = [[UILabel alloc] initWithFrame:CGRectMake(70, y, 200, 30)];
    overLbl.text = @"Modo OVER (Brickwall)"; overLbl.textColor = [UIColor whiteColor]; overLbl.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:overLbl];
    y += 35;

    UISwitch *extremeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(left, y, 50, 30)];
    [extremeSwitch addTarget:self action:@selector(extremeToggled:) forControlEvents:UIControlEventValueChanged];
    extremeSwitch.on = gParams.useExtremeClipper;
    [scrollView addSubview:extremeSwitch];
    UILabel *extremeLbl = [[UILabel alloc] initWithFrame:CGRectMake(70, y, 200, 30)];
    extremeLbl.text = @"Clipper Extremo"; extremeLbl.textColor = [UIColor whiteColor]; extremeLbl.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:extremeLbl];
    y += 35;

    // Self‑monitor switch
    UISwitch *selfMonSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(left, y, 50, 30)];
    [selfMonSwitch addTarget:self action:@selector(selfMonitorToggled:) forControlEvents:UIControlEventValueChanged];
    selfMonSwitch.on = gParams.selfMonitor;
    [scrollView addSubview:selfMonSwitch];
    UILabel *selfMonLbl = [[UILabel alloc] initWithFrame:CGRectMake(70, y, 200, 30)];
    selfMonLbl.text = @"Autoescucha"; selfMonLbl.textColor = [UIColor whiteColor]; selfMonLbl.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:selfMonLbl];
    y += 35;

    UISlider *selfMonVolSlider = [self sliderAtY:y label:@"Vol Autoescucha" min:0 max:2 value:gParams.selfMonitorVol action:@selector(selfMonitorVolChanged:) inView:scrollView]; y += 30;

    // Preset
    UIButton *presetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    presetBtn.frame = CGRectMake(left, y, 280, 30);
    [presetBtn setTitle:[NSString stringWithFormat:@"Preset: %@", gParams.micPreset] forState:UIControlStateNormal];
    [presetBtn addTarget:self action:@selector(choosePreset) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:presetBtn]; y += 35;

    // Medidor de nivel
    levelLabel = [[UILabel alloc] initWithFrame:CGRectMake(left, y, 280, 20)];
    levelLabel.text = @"-∞ dB"; levelLabel.textColor = [UIColor greenColor]; levelLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:levelLabel];
    y += 25;

    [targetWindow addSubview:scrollView];

    if (gParams.micAutoPan) startAutoPanTimer();
}

// Helper para labels
- (void)addLabel:(NSString *)text atY:(float)y inView:(UIView *)view {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10, y, 300, 20)];
    lbl.text = text; lbl.textColor = [UIColor magentaColor]; lbl.font = [UIFont boldSystemFontOfSize:12];
    [view addSubview:lbl];
}

// Helper para sliders
- (UISlider *)sliderAtY:(float)y label:(NSString *)label min:(float)min max:(float)max value:(float)value action:(SEL)action inView:(UIView *)view {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10, y, 120, 20)];
    lbl.text = label; lbl.textColor = [UIColor whiteColor]; lbl.font = [UIFont systemFontOfSize:10];
    [view addSubview:lbl];

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(130, y, 170, 30)];
    slider.minimumValue = min; slider.maximumValue = max; slider.value = value;
    [slider addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [view addSubview:slider];
    return slider;
}

// Acciones de sliders
- (void)mp3VolChanged:(UISlider *)s { gParams.mp3Vol = s.value; applyParams(); }
- (void)gainChanged:(UISlider *)s { gParams.gain = s.value; applyParams(); }
- (void)eqBodyChanged:(UISlider *)s { gParams.eqBody = s.value; applyParams(); }
- (void)eqMudChanged:(UISlider *)s { gParams.eqMud = s.value; applyParams(); }
- (void)eqPresChanged:(UISlider *)s { gParams.eqPresence = s.value; applyParams(); }
- (void)eqBiteChanged:(UISlider *)s { gParams.eqBite = s.value; applyParams(); }
- (void)pitchChanged:(UISlider *)s { gParams.micPitch = s.value; applyParams(); }
- (void)driveChanged:(UISlider *)s { gParams.micDrive = s.value; applyParams(); }
- (void)reverbVolChanged:(UISlider *)s { gParams.micReverbVol = s.value; applyParams(); }
- (void)haasChanged:(UISlider *)s { gParams.micHaas = s.value; applyParams(); }
- (void)widerChanged:(UISlider *)s { gParams.micWider = s.value; applyParams(); }
- (void)quickHaasChanged:(UISlider *)s { gParams.micQuickHaas = s.value; applyParams(); }
- (void)clipKneeChanged:(UISlider *)s { gParams.clipKnee = s.value; applyParams(); }
- (void)clipCeilingChanged:(UISlider *)s { gParams.clipCeiling = s.value; applyParams(); }
- (void)posXChanged:(UISlider *)s { gParams.micPosX = s.value; applyParams(); }
- (void)posYChanged:(UISlider *)s { gParams.micPosY = s.value; applyParams(); }
- (void)posZChanged:(UISlider *)s { gParams.micPosZ = s.value; applyParams(); }
- (void)autoPanSpeedChanged:(UISlider *)s { gParams.micAutoPanSpeed = s.value; }
- (void)selfMonitorVolChanged:(UISlider *)s { gParams.selfMonitorVol = s.value; applyParams(); }

// Toggles
- (void)autoPanToggled:(UISwitch *)sw {
    gParams.micAutoPan = sw.on;
    if (sw.on) startAutoPanTimer(); else { [autoPanTimer invalidate]; autoPanTimer = nil; }
    applyParams();
}
- (void)inHeadToggled:(UISwitch *)sw { gParams.micAutoInHead = sw.on; applyParams(); }
- (void)blazinToggled:(UISwitch *)sw { gParams.useBlazin = sw.on; applyParams(); }
- (void)overToggled:(UISwitch *)sw { gParams.useOverMode = sw.on; applyParams(); }
- (void)extremeToggled:(UISwitch *)sw { gParams.useExtremeClipper = sw.on; applyParams(); }
- (void)selfMonitorToggled:(UISwitch *)sw { gParams.selfMonitor = sw.on; applyParams(); }

// Grabación
- (void)toggleRecording {
    if (isRecording) {
        // Detener grabación
        isRecording = NO;
        [recButton setTitle:@"🔴 REC" forState:UIControlStateNormal];
        if (recordedFile) {
            recordedFile = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"lander deval hook"
                                                                               message:@"✅ Audio grabado correctamente.\nSe ha cargado para reproducir."
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    // Cargar el archivo grabado como MP3 para reproducir
                    mp3File = [[AVAudioFile alloc] initForReading:recordedFileURL error:nil];
                    if (mp3File) {
                        mp3Player = [[AVAudioPlayerNode alloc] init];
                        [engine attachNode:mp3Player];
                        [engine connect:mp3Player to:mixer format:nil];
                        [mp3Player scheduleFile:mp3File atTime:nil completionHandler:nil];
                        [mp3Player play];
                        gParams.isMp3Playing = YES;
                        applyParams();
                    }
                }]];
                UIWindow *keyWindow = nil;
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        keyWindow = ((UIWindowScene *)scene).keyWindow;
                        break;
                    }
                }
                [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            });
        }
    } else {
        // Iniciar grabación
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        recordedFileURL = [NSURL fileURLWithPath:[docPath stringByAppendingPathComponent:@"recording.m4a"]];
        NSError *err;
        // Usamos el mismo formato que el mixer (estéreo 48kHz)
        AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:48000 channels:2 interleaved:NO];
        recordedFile = [[AVAudioFile alloc] initForWriting:recordedFileURL settings:format.settings error:&err];
        if (!recordedFile || err) {
            NSLog(@"lander deval hook: error al crear archivo de grabación %@", err);
            return;
        }
        isRecording = YES;
        [recButton setTitle:@"⏹️ STOP" forState:UIControlStateNormal];
    }
}

// Presets
- (void)choosePreset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Preset de Micrófono" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *presets = @[@"Manual", @"Upfront Letal", @"Arriba (Head)", @"Abajo (Lower)", @"Atras (Behind)",
                         @"Deep Left", @"Deep Right", @"In-Head Wide", @"Overtalk Derecha", @"Overtalk Izquierda",
                         @"🔥 Combinado Letal", @"Desactivado"];
    for (NSString *preset in presets) {
        [alert addAction:[UIAlertAction actionWithTitle:preset style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            gParams.micPreset = preset;
            [self applyPreset:preset];
            for (UIView *sub in [floatingPanel subviews]) {
                if ([sub isKindOfClass:[UIButton class]] && [((UIButton *)sub).currentTitle hasPrefix:@"Preset:"]) {
                    [(UIButton *)sub setTitle:[NSString stringWithFormat:@"Preset: %@", preset] forState:UIControlStateNormal];
                    break;
                }
            }
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    UIWindow *keyWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            keyWindow = ((UIWindowScene *)scene).keyWindow;
            break;
        }
    }
    [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)applyPreset:(NSString *)preset {
    gParams.micCombinePos = gParams.micCombineHaas = gParams.micCombineWider = gParams.micCombineInHead = NO;
    if ([preset isEqualToString:@"Desactivado"]) {
        gParams.micPosX = gParams.micPosY = gParams.micPosZ = 0;
        gParams.micQuickHaas = gParams.micWider = gParams.micInHeadPan = 0;
        gParams.micAutoPan = gParams.micAutoDodge = NO;
    } else if ([preset isEqualToString:@"Manual"]) {
        // no change
    } else if ([preset isEqualToString:@"Upfront Letal"]) {
        gParams.micPosZ = -4.0; gParams.micQuickHaas = 0.5;
    } else if ([preset isEqualToString:@"Arriba (Head)"]) {
        gParams.micPosY = 5.0; gParams.micPosZ = -1.0;
    } else if ([preset isEqualToString:@"Abajo (Lower)"]) {
        gParams.micPosY = -5.0; gParams.micPosZ = -1.0;
    } else if ([preset isEqualToString:@"Atras (Behind)"]) {
        gParams.micPosZ = 5.0; gParams.micWider = 0.5;
    } else if ([preset isEqualToString:@"Deep Left"]) {
        gParams.micPosX = -5.0; gParams.micPosZ = 2.0; gParams.micQuickHaas = 5.0; gParams.micInHeadPan = -0.5;
    } else if ([preset isEqualToString:@"Deep Right"]) {
        gParams.micPosX = 5.0; gParams.micPosZ = 2.0; gParams.micQuickHaas = 5.0; gParams.micInHeadPan = 0.5;
    } else if ([preset isEqualToString:@"In-Head Wide"]) {
        gParams.micWider = 1.0; gParams.micQuickHaas = 0.2;
    } else if ([preset isEqualToString:@"Overtalk Derecha"]) {
        gParams.micQuickHaas = 0.9; gParams.micInHeadPan = 0.8; gParams.micPosX = 2.0;
    } else if ([preset isEqualToString:@"Overtalk Izquierda"]) {
        gParams.micQuickHaas = 0.9; gParams.micInHeadPan = -0.8; gParams.micPosX = -2.0;
    } else if ([preset isEqualToString:@"🔥 Combinado Letal"]) {
        gParams.micPosX = 3.0; gParams.micPosY = 2.0; gParams.micPosZ = -5.0;
        gParams.micQuickHaas = 3.0; gParams.micWider = 0.9; gParams.micInHeadPan = 0.4;
        gParams.micCombinePos = gParams.micCombineHaas = gParams.micCombineWider = gParams.micCombineInHead = YES;
    }
    applyParams();
}

// MP3
- (void)loadMP3 {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.mp3"] inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    UIWindow *keyWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            keyWindow = ((UIWindowScene *)scene).keyWindow;
            break;
        }
    }
    [keyWindow.rootViewController presentViewController:picker animated:YES completion:nil];
}

- (void)toggleMP3 {
    if (!mp3Player || !mp3File) return;
    if (gParams.isMp3Playing) {
        [mp3Player pause];
        gParams.isMp3Playing = NO;
    } else {
        [mp3Player play];
        gParams.isMp3Playing = YES;
    }
    applyParams();
}

- (void)stopMP3 {
    if (mp3Player) { [mp3Player stop]; mp3Player = nil; }
    mp3File = nil;
    gParams.isMp3Playing = NO;
    applyParams();
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    NSError *error;
    mp3File = [[AVAudioFile alloc] initForReading:url error:&error];
    if (error) return;
    mp3Player = [[AVAudioPlayerNode alloc] init];
    [engine attachNode:mp3Player];
    [engine connect:mp3Player to:mixer format:nil];
    [mp3Player scheduleFile:mp3File atTime:nil completionHandler:nil];
    [mp3Player play];
    gParams.isMp3Playing = YES;
    applyParams();
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)closePanel {
    [floatingPanel removeFromSuperview];
    floatingPanel = nil;
}

@end

// ------------------------------------------------------------
// Gancho
// ------------------------------------------------------------
%hook AVAudioInputNode
- (void)installTapOnBus:(AVAudioNodeBus)bus
             bufferSize:(AVAudioFrameCount)bufferSize
                 format:(AVAudioFormat *)format
                  block:(AVAudioNodeTapBlock)block {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        buildAudioChain();
        applyParams();
        dispatch_async(dispatch_get_main_queue(), ^{
            static AudioPanelController *panel = nil;
            if (!panel) panel = [[AudioPanelController alloc] init];
            [panel showPanel];
        });
    });
    if (mixer) {
        [mixer installTapOnBus:0 bufferSize:bufferSize format:format block:block];
    }
}
%end

%ctor {
    NSLog(@"lander deval hook cargado con éxito");
}
