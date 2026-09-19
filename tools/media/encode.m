#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <stdio.h>
#include <unistd.h>

// Stream packed BGRA frames from stdin into an H.264 MP4, without a frame cache.
int main(int argc, const char **argv) { @autoreleasepool {
    if (argc != 5) { fprintf(stderr, "Usage: encode output.mp4 width height fps\n"); return 2; }
    int width = atoi(argv[2]), height = atoi(argv[3]), fps = atoi(argv[4]);
    NSURL *url = [NSURL fileURLWithPath:@(argv[1])];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    NSError *error = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&error];
    NSDictionary *settings = @{AVVideoCodecKey:AVVideoCodecTypeH264, AVVideoWidthKey:@(width), AVVideoHeightKey:@(height),
        AVVideoCompressionPropertiesKey:@{AVVideoAverageBitRateKey:@8000000, AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel}};
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:
        @{(NSString*)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA), (NSString*)kCVPixelBufferWidthKey:@(width), (NSString*)kCVPixelBufferHeightKey:@(height), (NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}}];
    if (!writer || ![writer canAddInput:input]) { fprintf(stderr,"Cannot create encoder\n"); return 1; }
    [writer addInput:input]; writer.shouldOptimizeForNetworkUse = YES;
    if (![writer startWriting]) { fprintf(stderr,"%s\n",writer.error.description.UTF8String); return 1; }
    [writer startSessionAtSourceTime:kCMTimeZero];
    size_t frameBytes = (size_t)width * height * 4;
    unsigned char *data = malloc(frameBytes); int frame = 0;
    while (fread(data, 1, frameBytes, stdin) == frameBytes) { @autoreleasepool {
        while (!input.readyForMoreMediaData && writer.status == AVAssetWriterStatusWriting) usleep(1000);
        if (writer.status != AVAssetWriterStatusWriting) { fprintf(stderr,"Encoder stopped\n"); return 1; }
        CVPixelBufferRef buffer = NULL;
        if (CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &buffer) != kCVReturnSuccess) return 1;
        CVPixelBufferLockBaseAddress(buffer, 0);
        unsigned char *dest = CVPixelBufferGetBaseAddress(buffer); size_t stride = CVPixelBufferGetBytesPerRow(buffer);
        for (int y = 0; y < height; y++) memcpy(dest+y*stride, data+(size_t)y*width*4, width*4);
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        BOOL ok = [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame++, fps)];
        CVPixelBufferRelease(buffer);
        if (!ok) { fprintf(stderr,"%s\n",writer.error.description.UTF8String); return 1; }
    }}
    free(data); [input markAsFinished];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 60*NSEC_PER_SEC)) || writer.status != AVAssetWriterStatusCompleted) return 1;
    fprintf(stderr,"Encoded %d frames at %d fps\n",frame,fps); return 0;
}}
