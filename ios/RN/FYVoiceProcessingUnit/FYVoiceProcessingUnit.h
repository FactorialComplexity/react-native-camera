//
//  FYVoiceProcessingUnit.h
//  react-native-camera
//
//  Created by Vitaliy Ivanov on 06.05.2020.
//

#import <Foundation/Foundation.h>

@interface FYVoiceProcessingUnit : NSObject

@property (readonly) NSString* outputAudioFilePath;
@property (readwrite) BOOL isRecording;

- (BOOL)start;
- (void)stop;

+ (FYVoiceProcessingUnit*)sharedInstance;

@end
