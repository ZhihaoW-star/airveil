// Public macOS APIs only. Pixels remain in memory; there is no recording writer.
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <Metal/Metal.h>
#import <CoreImage/CoreImage.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>

static double publicVeilOpacity(double p) {
    double t=fmax(0,fmin(1,p/.12)); return t*t*(3-2*t);
}
static CIImage *publicVeilImage(CIImage *source,double progress,double scale) {
    if (!source || !isfinite(progress) || !isfinite(scale) || scale<=0) return nil;
    double radius=80*fmax(0,fmin(1,progress))*scale;
    return [[[source imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:radius]
        imageByCroppingToRect:source.extent];
}

@interface VeilView : NSView <SCStreamOutput,SCStreamDelegate>
@property CIContext *context;
@property dispatch_queue_t captureQueue,renderQueue;
@property SCStream *stream;
@property CIImage *latestImage;
@property CIImage *lastRenderedSource;
@property double lastRenderedProgress;
@property NSString *failure;
@property BOOL blurFailed,starting,captureWanted,renderBusy,deliveryPending,frameReady;
@property BOOL warming;
@property NSUInteger generation,renderedFrames;
@property double lastProgress,lastRenderTime,lastRenderMilliseconds,maxRenderMilliseconds;
@property double displayScale;
@property CGDirectDisplayID displayID;
@property (copy) void (^stateChanged)(void);
- (void)startCapture;
- (void)stopCapture;
- (void)showProgress:(double)p full:(BOOL)full right:(BOOL)right;
- (void)renderLatest;
- (void)warmFirstFrame;
- (void)fail:(NSString *)message;
@end

@implementation VeilView
- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self=[super initWithFrame:frame])) return nil;
    self.wantsLayer=YES; self.layer.backgroundColor=NSColor.clearColor.CGColor;
    self.layer.contentsGravity=kCAGravityResize;
    _displayScale=1; _lastProgress=0;
    _captureQueue=dispatch_queue_create("local.airveil.public.capture",DISPATCH_QUEUE_SERIAL);
    _renderQueue=dispatch_queue_create("local.airveil.public.render",DISPATCH_QUEUE_SERIAL);
    id<MTLDevice> device=MTLCreateSystemDefaultDevice();
    if (device) _context=[CIContext contextWithMTLDevice:device options:@{kCIContextCacheIntermediates:@NO}];
    else { _failure=@"GPU rendering is unavailable on this Mac."; _blurFailed=YES; }
    return self;
}
- (void)notifyState { if (_stateChanged) _stateChanged(); }
- (void)fail:(NSString *)message {
    self.failure=message; self.blurFailed=YES; self.starting=NO;
    // Keep an already presented frame. The recovery panel offers explicit restore.
    [self notifyState];
}
- (void)startCapture {
    if (_captureWanted || !_context) return;
    _captureWanted=YES; _starting=YES; _failure=nil; _blurFailed=NO;
    NSUInteger generation=++_generation;
    __weak VeilView *weakSelf=self;
    [SCShareableContent getShareableContentExcludingDesktopWindows:NO onScreenWindowsOnly:NO
        completionHandler:^(SCShareableContent *content,NSError *error) {
        dispatch_async(dispatch_get_main_queue(),^{
            VeilView *self=weakSelf;
            if (!self || generation!=self.generation || !self.captureWanted) return;
            if (error) { [self fail:@"Screen access is unavailable. Allow AirVeil in System Settings, then retry."]; return; }
            SCDisplay *target=nil;
            for (SCDisplay *display in content.displays) if (display.displayID==self.displayID) target=display;
            if (!target) { [self fail:@"This display is unavailable. Retry screen access."]; return; }
            NSMutableArray *excluded=[NSMutableArray new];
            for (SCRunningApplication *app in content.applications)
                if (app.processID==NSProcessInfo.processInfo.processIdentifier) [excluded addObject:app];
            // Exclude all of this process, including future recovery windows. Never
            // feed the displayed blur back into the next captured frame.
            if (!excluded.count) { [self fail:@"Could not exclude the experiment from capture. Retry screen access."]; return; }
            SCContentFilter *filter=[[SCContentFilter alloc]initWithDisplay:target excludingApplications:excluded exceptingWindows:@[]];
            SCStreamConfiguration *config=[SCStreamConfiguration new];
            config.width=(size_t)llround(self.bounds.size.width*self.displayScale);
            config.height=(size_t)llround(self.bounds.size.height*self.displayScale);
            config.minimumFrameInterval=CMTimeMake(1,60); config.queueDepth=3;
            config.pixelFormat=kCVPixelFormatType_32BGRA; config.showsCursor=NO;
            config.capturesAudio=NO; config.colorSpaceName=kCGColorSpaceSRGB;
            SCStream *stream=[[SCStream alloc]initWithFilter:filter configuration:config delegate:self];
            self.stream=stream;
            NSError *outputError=nil;
            if (![stream addStreamOutput:self type:SCStreamOutputTypeScreen sampleHandlerQueue:self.captureQueue error:&outputError]) {
                self.stream=nil; [self fail:@"Could not prepare screen frames. Retry screen access."]; return;
            }
            [stream startCaptureWithCompletionHandler:^(NSError *startError) {
                dispatch_async(dispatch_get_main_queue(),^{
                    VeilView *self=weakSelf;
                    if (!self || generation!=self.generation) { [stream stopCaptureWithCompletionHandler:nil]; return; }
                    self.starting=NO;
                    if (startError) [self fail:@"Screen capture could not start. Check screen access and retry."];
                    else [self notifyState];
                });
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC),dispatch_get_main_queue(),^{
                VeilView *self=weakSelf;
                if (self && generation==self.generation && self.captureWanted && !self.latestImage && !self.failure)
                    [self fail:@"No screen frames arrived. Check screen access and retry."];
            });
        });
    }];
    [self notifyState];
}
- (void)stopCapture {
    ++_generation; _captureWanted=NO; _starting=NO;
    SCStream *old=_stream;
    @synchronized(self) { self.stream=nil; self.latestImage=nil; }
    [old stopCaptureWithCompletionHandler:nil];
    _frameReady=NO; _warming=NO; _lastProgress=0; _lastRenderedSource=nil;
    [self.window orderOut:nil];
    [CATransaction begin]; [CATransaction setDisableActions:YES]; self.layer.contents=nil; [CATransaction commit];
    _failure=nil; _blurFailed=NO;
}
- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(),^{
        if (stream==self.stream && self.captureWanted) [self fail:@"Screen capture stopped. Restore the screen or retry access."];
    });
}
- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)buffer ofType:(SCStreamOutputType)type {
    if (type!=SCStreamOutputTypeScreen || !CMSampleBufferIsValid(buffer) || stream!=self.stream) return;
    NSArray *attachments=(__bridge NSArray *)CMSampleBufferGetSampleAttachmentsArray(buffer,NO);
    NSNumber *status=attachments.firstObject[SCStreamFrameInfoStatus];
    if (!status || status.integerValue!=SCFrameStatusComplete) return;
    CVPixelBufferRef pixels=CMSampleBufferGetImageBuffer(buffer); if (!pixels) return;
    CIImage *image=[CIImage imageWithCVPixelBuffer:pixels];
    @synchronized(self) {
        if (stream!=self.stream) return;
        self.latestImage=image;
        if (self.deliveryPending) return;
        self.deliveryPending=YES;
    }
    dispatch_async(dispatch_get_main_queue(),^{
        @synchronized(self) { self.deliveryPending=NO; }
        if (stream!=self.stream) return;
        if (!self.frameReady) [self warmFirstFrame];
        // The display-linked animation clock consumes the latest source. Do not
        // let capture callbacks race that clock with the previous head angle.
    });
}
- (void)showProgress:(double)p full:(BOOL)full right:(BOOL)right {
    if (!isfinite(p)) { [self fail:@"Invalid effect value. Restore the screen."]; return; }
    _lastProgress=fmax(0,fmin(1,p));
    if (!veilShouldPresent(_lastProgress,self.window.isVisible)) {
        [self.window orderOut:nil]; return;
    }
    [self renderLatest];
}
- (void)warmFirstFrame {
    if (_warming || _frameReady || !_captureWanted || _failure) return;
    CIImage *source=self.latestImage; if (!source) return;
    _warming=YES;
    NSUInteger generation=_generation; double scale=_displayScale;
    CIContext *context=_context; __weak VeilView *weakSelf=self;
    dispatch_async(_renderQueue,^{ @autoreleasepool {
        CGColorSpaceRef cs=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGImageRef image=[context createCGImage:publicVeilImage(source,.2,scale) fromRect:source.extent format:kCIFormatRGBA8 colorSpace:cs];
        BOOL success=image!=nil;
        if(image)CGImageRelease(image);CGColorSpaceRelease(cs);
        dispatch_async(dispatch_get_main_queue(),^{
            VeilView *self=weakSelf;if(!self||generation!=self.generation)return;
            self.warming=NO;
            if(success){self.frameReady=YES;[self notifyState];[self renderLatest];}
            else [self fail:@"Could not prepare the GPU effect. Retry screen access."];
        });
    }});
}
- (void)renderLatest {
    NSAssert(NSThread.isMainThread,@"Presentation must run on the main thread");
    double now=NSProcessInfo.processInfo.systemUptime;
    if (_renderBusy || !_captureWanted || !_frameReady || _failure || now-_lastRenderTime<1./65. ||
        !veilShouldPresent(_lastProgress,self.window.isVisible)) return;
    CIImage *source=self.latestImage; if (!source) return;
    if(source==_lastRenderedSource && fabs(_lastProgress-_lastRenderedProgress)<.000001 && self.window.isVisible) return;
    _renderBusy=YES; _lastRenderTime=now;
    NSUInteger generation=_generation; double progress=_lastProgress,scale=_displayScale;
    CIContext *context=_context; __weak VeilView *weakSelf=self;
    dispatch_async(_renderQueue,^{ @autoreleasepool {
        double start=NSProcessInfo.processInfo.systemUptime;
        CIImage *blurred=publicVeilImage(source,progress,scale);
        CGColorSpaceRef colorSpace=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGImageRef rendered=[context createCGImage:blurred fromRect:source.extent format:kCIFormatRGBA8 colorSpace:colorSpace deferred:NO];
        CGColorSpaceRelease(colorSpace);
        double milliseconds=(NSProcessInfo.processInfo.systemUptime-start)*1000;
        dispatch_async(dispatch_get_main_queue(),^{
            VeilView *self=weakSelf;
            if (self) self.renderBusy=NO;
            if (self && generation==self.generation && self.captureWanted) {
                self.lastRenderMilliseconds=milliseconds; self.maxRenderMilliseconds=fmax(self.maxRenderMilliseconds,milliseconds);
                if (!rendered) [self fail:@"The GPU could not render this frame. Restore the screen."];
                else if (veilShouldPresent(self.lastProgress,self.window.isVisible)) {
                    // A window is never made visible without a complete pixel image.
                    // Image replacement and opacity commit together; no empty backing
                    // surface or system material is exposed at the clear boundary.
                    [CATransaction begin]; [CATransaction setDisableActions:YES];
                    self.layer.contents=(__bridge id)rendered;
                    self.layer.contentsScale=self.displayScale;
                    self.window.alphaValue=publicVeilOpacity(progress);
                    [CATransaction commit];
                    if (!self.window.isVisible) [self.window orderFrontRegardless];
                    self.lastRenderedSource=source;self.lastRenderedProgress=progress;
                    self.renderedFrames++;
                }
            }
            if (rendered) CGImageRelease(rendered);
        });
    }});
}
@end
