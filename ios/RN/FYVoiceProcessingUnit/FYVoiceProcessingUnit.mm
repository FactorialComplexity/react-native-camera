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

#include "AUOutputBL.h"

@implementation FYVoiceProcessingUnit {
    AudioUnit _voiceUnit;
    AUOutputBL* _inputBL;
    ExtAudioFileRef _extAudioFile;
    BOOL _isRecording;
}

static OSStatus ProcessVoiceAndWriteToFile(
    void* inRefCon,
    AudioUnitRenderActionFlags* ioActionFlags,
    const AudioTimeStamp* inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList* ioData)
{
	FYVoiceProcessingUnit* self = (__bridge FYVoiceProcessingUnit*)inRefCon;
	
    self->_inputBL->Prepare(inNumberFrames);
        
    OSStatus err = AudioUnitRender(
        self->_voiceUnit,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        inNumberFrames,
        self->_inputBL->ABL()
    );
    if (err != noErr) {
        RCTLogWarn(@"inputProc: error %d", err);
        return err;
    }
    
    if (self->_isRecording) {
        err = ExtAudioFileWriteAsync(self->_extAudioFile, inNumberFrames, self->_inputBL->ABL());
        if (err != noErr) {
            RCTLogWarn(@"ExtAudioFileWriteAsync: error %d", err);
            return err;
        }
    }
	
    NSLog(@"ProcessVoiceAndWriteToFile: %d, %d", inBusNumber, inNumberFrames);
 
	return noErr;
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

- (BOOL)start {
    [self stop];

    CAStreamBasicDescription format(
        44100,
        1,
        CAStreamBasicDescription::kPCMFormatInt16,
        true
    );
    _inputBL = new AUOutputBL(format, 1024);

        AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    if (![session
        setCategory:AVAudioSessionCategoryPlayAndRecord
        mode:AVAudioSessionModeVideoChat
        options:AVAudioSessionCategoryOptionMixWithOthers
            | AVAudioSessionCategoryOptionDefaultToSpeaker
            | AVAudioSessionCategoryOptionAllowBluetooth
        error:&error
    ]) {
        RCTLogWarn(@"Error setting session category: %@", error);
    }
    
    [session setPreferredSampleRate:format.mSampleRate error:&error];
    
    if (![session setActive:YES error:&error]) {
        RCTLogWarn(@"[ERROR] AVAudioSession setActive failed");
        return NO;
    }
    
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
    UInt32 turnOff = 0;
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
        &turnOff,
        sizeof(turnOff)
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
        &format,
        sizeof(format)
    );

    err = AudioUnitSetProperty(
        _voiceUnit,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Output,
        1,
        &format,
        sizeof(format)
    );
    
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = ProcessVoiceAndWriteToFile;
    renderCallbackStruct.inputProcRefCon = (__bridge void*)self;
    err = AudioUnitSetProperty(
        _voiceUnit,
        kAudioOutputUnitProperty_SetInputCallback,
        kAudioUnitScope_Global,
        1,
        &renderCallbackStruct,
        sizeof(renderCallbackStruct)
    );
    
    err = AudioUnitInitialize(_voiceUnit);
    if (err != noErr) {
        RCTLogWarn(@"[ERROR] Unable to initialize voice processing AudioUnit");
        return NO;
    }
    
    _outputAudioFilePath = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSString
            stringWithFormat:@"%@.caf", @([[[NSDate alloc] init] timeIntervalSince1970])
        ]
    ];
    CFURLRef outputFile = CFURLCreateWithFileSystemPath(
        kCFAllocatorDefault,
        (CFStringRef)_outputAudioFilePath,
        kCFURLPOSIXPathStyle,
        false
    );
    
    AVAudioFormat* fileFormat = [[AVAudioFormat alloc]
        initWithCommonFormat:AVAudioPCMFormatInt16
        sampleRate:format.mSampleRate
        channels:AVAudioChannelCount(format.NumberChannels())
        interleaved:YES
    ];
    err = ExtAudioFileCreateWithURL(
        outputFile,
        kAudioFileCAFType,
        fileFormat.streamDescription,
        NULL,
        kAudioFileFlags_EraseFile,
        &_extAudioFile
    );
    
    if (err == noErr) {
        err = ExtAudioFileSetProperty(
            _extAudioFile,
            kExtAudioFileProperty_ClientDataFormat,
            sizeof(format),
            &format
        );
    }
    
    if (err != noErr) {
        RCTLogWarn(@"[ERROR] Unable to create output file");
        return NO;
    }
    
    err = AudioOutputUnitStart(_voiceUnit);
    if (err != noErr) {
        RCTLogWarn(@"[ERROR] Unable to start voice processing AudioUnit");
        return NO;
    }
    
    return YES;
}

- (void)stop {
    if (_extAudioFile) {
        ExtAudioFileDispose(_extAudioFile);
        _extAudioFile = NULL;
    }
    
    if (_voiceUnit) {
        AudioOutputUnitStop(_voiceUnit);
        AudioUnitUninitialize(_voiceUnit);
        _voiceUnit = NULL;
    }
    
    if (_inputBL) {
        delete _inputBL;
        _inputBL = NULL;
    }
    
    _isRecording = NO;
}

@end
