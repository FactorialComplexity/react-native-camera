//
//  FYVoiceProcessingUnit.h
//  react-native-camera
//
//  Created by Vitaliy Ivanov on 06.05.2020.
//

#import <Foundation/Foundation.h>

@interface FYVoiceProcessingUnit : NSObject

- (BOOL)start;
- (void)stop;

+ (FYVoiceProcessingUnit*)sharedInstance;

@end
