//
//  FYVoiceProcessingUnit.m
//  react-native-camera
//
//  Created by Vitaliy Ivanov on 06.05.2020.
//

#import "FYVoiceProcessingUnit.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <React/RCTLog.h>

AudioUnit _voiceUnit;

@implementation FYVoiceProcessingUnit

+ (void)start {
    [self stop];

    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    if (![session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
        NSLog(@"Error setting session category: %@", error);
    }

    if (![session setMode:AVAudioSessionModeVideoChat error:&error]) {
        NSLog(@"Error setting session mode: %@", error);
    }

    OSStatus err;
    AudioComponent comp;
    AudioComponentDescription desc;

    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    comp = AudioComponentFindNext(nil, &desc);
    if (!comp) {
        RCTLogWarn(@"[ERROR] Unable to find Voice Processing I/O AudioUnit");
        return;
    }
    
    err = AudioComponentInstanceNew(comp, &_voiceUnit);
    if (err != noErr) {
        RCTLogWarn(@"[ERROR] Unable to instantiate new AudioUnit");
        return;
    }
    
    // UInt32 turnOn = 0;
    UInt32 turnOff = 0;
    err = AudioUnitSetProperty(
        _voiceUnit,
        kAUVoiceIOProperty_BypassVoiceProcessing,
        kAudioUnitScope_Global,
        1,
        &turnOff,
        sizeof(turnOff)
    );
    
    err = AudioUnitSetProperty(
        _voiceUnit,
        kAUVoiceIOProperty_VoiceProcessingEnableAGC,
        kAudioUnitScope_Global,
        0,
        &turnOff,
        sizeof(turnOff)
    );
    
    err = AudioUnitInitialize(_voiceUnit);
    if (err != noErr) {
        RCTLogWarn(@"[ERROR] Unable to initialize voice processing AudioUnit");
        return;
    }
    
    err = AudioOutputUnitStart(_voiceUnit);
    if (err != noErr) {
        RCTLogWarn(@"[ERROR] Unable to start voice processing AudioUnit");
        return;
    }
}

+ (void)stop {
    if (_voiceUnit) {
        AudioOutputUnitStop(_voiceUnit);
        AudioUnitUninitialize(_voiceUnit);
        _voiceUnit = NULL;
    }
}

@end
