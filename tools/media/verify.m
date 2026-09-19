#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

int main(int argc, const char **argv) { @autoreleasepool {
    if (argc != 3) return 2;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:@(argv[1])] options:nil];
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!track) return 1;
    NSError *error=nil;
    AVAssetReader *reader=[[AVAssetReader alloc] initWithAsset:asset error:&error];
    AVAssetReaderTrackOutput *out=[[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:@{(NSString*)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
    [reader addOutput:out]; if (![reader startReading]) return 1;
    CIContext *context=[CIContext contextWithOptions:nil];
    int count=0; double last=-1; BOOL monotonic=YES;
    CMSampleBufferRef sample;
    while ((sample=[out copyNextSampleBuffer])) { @autoreleasepool {
        double t=CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample));
        if (t<=last) monotonic=NO; last=t;
        if (count==0 || count==90 || count==390 || count==525 || count==690 || count==839) {
            CIImage *image=[CIImage imageWithCVPixelBuffer:CMSampleBufferGetImageBuffer(sample)];
            CGImageRef cg=[context createCGImage:image fromRect:image.extent];
            NSString *path=[@(argv[2]) stringByAppendingPathComponent:[NSString stringWithFormat:@"decoded-%03d.png",count]];
            CGImageDestinationRef dest=CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],CFSTR("public.png"),1,NULL);
            CGImageDestinationAddImage(dest,cg,NULL); CGImageDestinationFinalize(dest); CFRelease(dest); CGImageRelease(cg);
        }
        count++; CFRelease(sample);
    }}
    NSDictionary *result=@{@"width":@(track.naturalSize.width),@"height":@(track.naturalSize.height),@"fps":@(track.nominalFrameRate),@"duration":@(CMTimeGetSeconds(asset.duration)),@"decoded_frames":@(count),@"timestamps_monotonic":@(monotonic),@"complete":@(reader.status==AVAssetReaderStatusCompleted)};
    NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
    puts([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
    return count==840 && monotonic && reader.status==AVAssetReaderStatusCompleted ? 0 : 1;
}}
