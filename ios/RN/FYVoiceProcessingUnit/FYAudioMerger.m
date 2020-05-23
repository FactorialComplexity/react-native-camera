//
//  FYAudioMerger.m
//  react-native-camera
//
//  Created by Vitaliy Ivanov on 23.05.2020.
//

#import "FYAudioMerger.h"

#import <AVFoundation/AVFoundation.h>

@implementation FYAudioMerger

+ (void)mergeVideoFileAtURL:(NSURL*)inputVideoURL
    withAudioFileAtPath:(NSString*)audioFilePath
    toVideoFileAtPath:(NSString*)outputVideoFilePath
    completion:(void(^)(NSError* error))completion
{
    NSError* error;
    AVMutableComposition* mixComposition = [AVMutableComposition new];
    NSMutableArray<AVMutableCompositionTrack*>* mutableCompositionVideoTrack = [NSMutableArray new];
    NSMutableArray<AVMutableCompositionTrack*>* mutableCompositionAudioTrack = [NSMutableArray new];
    AVMutableVideoCompositionInstruction* totalVideoCompositionInstruction = [AVMutableVideoCompositionInstruction new];
    
    AVAsset* aVideoAsset = [AVAsset assetWithURL:inputVideoURL];
    AVAsset* aAudioAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:audioFilePath]];
    
    [mutableCompositionVideoTrack addObject:[mixComposition
        addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid
    ]];
    [mutableCompositionAudioTrack addObject:[mixComposition
        addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid
    ]];
    
    AVAssetTrack* aVideoAssetTrack = [aVideoAsset tracksWithMediaType:AVMediaTypeVideo][0];
    AVAssetTrack* aAudioAssetTrack = [aAudioAsset tracksWithMediaType:AVMediaTypeAudio][0];
    
    [mutableCompositionVideoTrack[0]
        insertTimeRange:CMTimeRangeMake(kCMTimeZero, aVideoAssetTrack.timeRange.duration)
        ofTrack:aVideoAssetTrack
        atTime:kCMTimeZero
        error:&error
    ];
    mutableCompositionVideoTrack[0].preferredTransform = aVideoAssetTrack.preferredTransform;
    
    if (error) {
        completion(error);
        return;
    }
    
    [mutableCompositionAudioTrack[0]
        insertTimeRange:CMTimeRangeMake(kCMTimeZero, aVideoAssetTrack.timeRange.duration)
        ofTrack:aAudioAssetTrack
        atTime: kCMTimeZero
        error:&error
    ];
    
    if (error) {
        completion(error);
        return;
    }

    totalVideoCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero,aVideoAssetTrack.timeRange.duration);

    AVMutableVideoComposition* mutableVideoComposition = [AVMutableVideoComposition new];
    mutableVideoComposition.frameDuration = aVideoAssetTrack.minFrameDuration;
    mutableVideoComposition.renderSize = aVideoAssetTrack.naturalSize;

    AVAssetExportSession* assetExport = [[AVAssetExportSession alloc]
        initWithAsset:mixComposition
        presetName:AVAssetExportPresetHighestQuality
    ];
    assetExport.outputFileType = AVFileTypeMPEG4;
    assetExport.outputURL = [NSURL fileURLWithPath:outputVideoFilePath];
    assetExport.shouldOptimizeForNetworkUse = YES;
    
    [assetExport exportAsynchronouslyWithCompletionHandler:^{
        if (assetExport.status == AVAssetExportSessionStatusCompleted) {
            completion(nil);
        } else if (
            assetExport.status == AVAssetExportSessionStatusFailed ||
            assetExport.status == AVAssetExportSessionStatusCancelled
        ) {
            completion(assetExport.error);
        }
    }];
}

@end
