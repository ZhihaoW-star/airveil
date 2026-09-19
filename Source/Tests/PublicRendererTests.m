#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#import "../PrivacyPolicy.h"
#import "../PublicVeil.inc"
#include <assert.h>

static CIImage *pattern(int width,int height) {
    NSMutableData *pixels=[NSMutableData dataWithLength:width*height*4];
    uint8_t *p=pixels.mutableBytes;
    for(int y=0;y<height;y++)for(int x=0;x<width;x++) {
        int k=4*(y*width+x);uint8_t value=((x/8+y/8)%2)?64:192;
        p[k]=value;p[k+1]=value;p[k+2]=value;p[k+3]=255;
    }
    CGColorSpaceRef cs=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CIImage *result=[CIImage imageWithBitmapData:pixels bytesPerRow:width*4 size:CGSizeMake(width,height) format:kCIFormatRGBA8 colorSpace:cs];
    CGColorSpaceRelease(cs);return result;
}
static void stats(CIContext *context,CIImage *image,double *mean,double *variation) {
    CGRect bounds=image.extent;int w=bounds.size.width,h=bounds.size.height;
    NSMutableData *data=[NSMutableData dataWithLength:w*h*4];
    CGColorSpaceRef cs=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    [context render:image toBitmap:data.mutableBytes rowBytes:w*4 bounds:bounds format:kCIFormatRGBA8 colorSpace:cs];
    CGColorSpaceRelease(cs);
    uint8_t *p=data.mutableBytes;double sum=0,sq=0;int n=0;
    for(int y=32;y<h-32;y++)for(int x=32;x<w-32;x++) {
        double v=p[4*(y*w+x)];sum+=v;sq+=v*v;n++;
        assert(p[4*(y*w+x)+3]==255); // no empty/transparent pixels
    }
    *mean=sum/n;*variation=sq/n-(*mean)*(*mean);
}
static void spin(double seconds) {
    NSDate *until=[NSDate dateWithTimeIntervalSinceNow:seconds];
    while(until.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
}
int main(void){@autoreleasepool{
    [NSApplication sharedApplication];
    CIContext *context=[CIContext contextWithMTLDevice:MTLCreateSystemDefaultDevice() options:@{kCIContextCacheIntermediates:@NO}];assert(context);
    CIImage *source=pattern(512,320);double baseline,var0,mean,var;
    stats(context,publicVeilImage(source,0,1),&baseline,&var0);assert(var0>3000);
    for(NSNumber *step in @[@.001,@.05,@.15,@.4,@1.0]) {
        stats(context,publicVeilImage(source,step.doubleValue,1),&mean,&var);
        assert(mean>100&&mean<190); // cannot turn uniformly white or black
        assert(var<=var0+1); // actual smoothing, not an opaque colored cover
    }
    stats(context,publicVeilImage(source,1,1),&mean,&var);assert(var<var0*.01);
    assert(!publicVeilImage(source,NAN,1));
    assert(publicVeilOpacity(0)==0&&publicVeilOpacity(1)==1);
    puts("PASS: GPU-rendered pixels preserve content brightness and opacity; full blur reduces checkerboard variance >99%; non-finite input rejected.");

    NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,512,320) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO;
    VeilView *view=[[VeilView alloc]initWithFrame:NSMakeRect(0,0,512,320)];window.contentView=view;
    view.captureWanted=YES;
    [view showProgress:1 full:NO right:NO];assert(!window.isVisible); // no source => never show blank
    view.latestImage=source;view.frameReady=YES;
    // Render completion is asynchronous. Pause must invalidate a frame already in flight.
    [view showProgress:1 full:NO right:NO];assert(view.renderBusy);[view stopCapture];spin(.5);
    assert(!window.isVisible&&!view.latestImage&&!view.layer.contents&&!view.renderBusy);
    // Clearing just the progress while a render is pending must also avoid late presentation.
    view.captureWanted=YES;view.latestImage=source;view.frameReady=YES;view.lastRenderTime=0;
    [view showProgress:.8 full:NO right:NO];[view showProgress:0 full:NO right:NO];spin(.3);
    assert(!window.isVisible&&!view.layer.contents);
    [view stopCapture];[window close];
    puts("PASS: no first-frame blank overlay; pause cancels pending presentation and releases source pixels; a late GPU result cannot reopen a clear overlay.");

    CIImage *full=pattern(1710,1107);CGColorSpaceRef cs=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    double total=0,max=0,warm=0;
    for(int i=0;i<12;i++){@autoreleasepool{
        double t=NSProcessInfo.processInfo.systemUptime;
        CGImageRef frame=[context createCGImage:publicVeilImage(full,(i+1)/12.,1) fromRect:full.extent format:kCIFormatRGBA8 colorSpace:cs];assert(frame);CGImageRelease(frame);
        double ms=(NSProcessInfo.processInfo.systemUptime-t)*1000;if(i==0)warm=ms;else {total+=ms;max=fmax(max,ms);}
    }}
    CGColorSpaceRelease(cs);
    printf("Balanced 1710x1107 GPU render + image handoff: warm-up %.2f ms; subsequent average %.2f ms, max %.2f ms (12 frames; not a battery measurement).\n",warm,total/11,max);
}return 0;}
