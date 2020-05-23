//
//  FYAudioMerger.h
//  react-native-camera
//
//  Created by Vitaliy Ivanov on 23.05.2020.
//

#import <Foundation/Foundation.h>

@interface FYAudioMerger : NSObject

+ (void)mergeVideoFileAtURL:(NSURL*)inputVideoURL
    withAudioFileAtPath:(NSString*)audioFilePath
    toVideoFileAtPath:(NSString*)outputVideoFilePath
    completion:(void(^)(NSError* error))completion;
    

@end
