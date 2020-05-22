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

@implementation FYVoiceProcessingUnit {
    AudioUnit _voiceUnit;
    AudioStreamBasicDescription _format;
}

- (void)dealloc {
    [self stop];
}

static FYVoiceProcessingUnit* g_FYVoiceProcessingUnit = nil;
+ (FYVoiceProcessingUnit*)sharedInstance {
    if (!g_FYVoiceProcessingUnit) {
        g_FYVoiceProcessingUnit = [[FYVoiceProcessingUnit alloc] init];
    }
    return g_FYVoiceProcessingUnit;
}

- (id)init {
    if (self = [super init]) {
        _format.mSampleRate = 8000;
        _format.mFormatID = kAudioFormatLinearPCM;
        _format.mFormatFlags = 12;
        _format.mBytesPerPacket = 2;
        _format.mFramesPerPacket = 1;
        _format.mBytesPerFrame = 2;
        _format.mChannelsPerFrame = 1;
        _format.mBitsPerChannel = 16;
        _format.mReserved = 0;
    }
    return self;
}

- (BOOL)start {
    [self stop];

    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    if (![session
        setCategory:AVAudioSessionCategoryPlayAndRecord
        mode:AVAudioSessionModeDefault
        options:AVAudioSessionCategoryOptionDefaultToSpeaker
        error:&error
    ]) {
        RCTLogWarn(@"Error setting session category: %@", error);
    }
    
    [session setPreferredSampleRate:_format.mSampleRate error:&error];
    
//    if (![session setMode:AVAudioSessionModeDefault error:&error]) {
//        RCTLogWarn(@"Error setting session mode: %@", error);
//    }
//
//    if (![session setPreferredSampleRate:format.mSampleRate error:&error]) {
//        RCTLogWarn(@"Error setting session preferred sample rate: %@", error);
//    }
    
//    BOOL setActive = [session setActive:YES error:&error];
    
    OSStatus err;
    AudioComponent comp;
    AudioComponentDescription desc;

    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    comp = AudioComponentFindNext(NULL, &desc);
    if (!comp) {
        RCTLogWarn(@"[ERROR] Unable to find Voice Processing I/O AudioUnit");
        return NO;
    }
    
    err = AudioComponentInstanceNew(comp, &_voiceUnit);
    if (err != noErr) {
        RCTLogWarn(@"[ERROR] Unable to instantiate new AudioUnit");
        return NO;
    }
    
    UInt32 turnOn = 1;
//    UInt32 turnOff = 0;
//    err = AudioUnitSetProperty(
//        _voiceUnit,
//        kAUVoiceIOProperty_BypassVoiceProcessing,
//        kAudioUnitScope_Global,
//        1,
//        &turnOff,
//        sizeof(turnOff)
//    );

    err = AudioUnitSetProperty(
        _voiceUnit,
        kAUVoiceIOProperty_VoiceProcessingEnableAGC,
        kAudioUnitScope_Global,
        0,
        &turnOn,
        sizeof(turnOn)
    );

    err = AudioUnitSetProperty(
        _voiceUnit,
        kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Input,
        1,
        &turnOn,
        sizeof(turnOn)
    );

    err = AudioUnitSetProperty(
        _voiceUnit,
        kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Output,
        0,
        &turnOn,
        sizeof(turnOn)
    );
    
    err = AudioUnitSetProperty(
        _voiceUnit,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        0,
        &_format,
        sizeof(_format)
    );

    err = AudioUnitSetProperty(
        _voiceUnit,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Output,
        1,
        &_format,
        sizeof(_format)
    );
    
    err = AudioUnitInitialize(_voiceUnit);
    if (err != noErr) {
        RCTLogWarn(@"[ERROR] Unable to initialize voice processing AudioUnit");
        return NO;
    }
    
    if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        RCTLogWarn(@"[ERROR] AVAudioSession setActive failed");
        return NO;
    }
    
    err = AudioOutputUnitStart(_voiceUnit);
    if (err != noErr) {
        RCTLogWarn(@"[ERROR] Unable to start voice processing AudioUnit");
        return NO;
    }
    
    NSLog(@"FYVoiceProcessingUnit STARTED");
    return YES;
}

- (void)stop {
    if (_voiceUnit) {
        AudioOutputUnitStop(_voiceUnit);
        AudioUnitUninitialize(_voiceUnit);
        _voiceUnit = NULL;
    }
}

@end
