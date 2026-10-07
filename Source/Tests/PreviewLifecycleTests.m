#define main AirVeilApplicationMain
#import "../main.m"
#undef main
#include <assert.h>

@interface PreviewDelegate : AppDelegate
@property double testTime;
@property NSUInteger captureStops,settingsShows;
@end
@implementation PreviewDelegate
- (double)now {return _testTime;}
- (BOOL)captureReady {return self.capturePrepared;}
- (void)wakeAnimation {}
- (void)configureAnimation:(BOOL)active {}
- (void)updateRecoveryPresentation {}
- (void)render:(double)p full:(BOOL)full right:(BOOL)right {}
- (void)stopScreenCapture {self.captureStops++;[super stopScreenCapture];}
- (void)show:(id)sender {self.settingsShows++;}
@end
static PreviewDelegate* fixture(void) {
 PreviewDelegate*d=[PreviewDelegate new];d.testTime=100;d.capturePrepared=YES;
 d.pages=[NSMutableArray arrayWithObject:[NSView new]];
 d.calibrationYaws=[NSMutableArray new];d.calibrationTimes=[NSMutableArray new];
 d.slider=[NSSlider new];d.connected=YES;d.seen=YES;d.received=100;
 d.captureIdleDeadline=160;return d;
}
int main(void){@autoreleasepool{
 [NSApplication sharedApplication];
 // An explicit protection command takes ownership from the preview timer.
 PreviewDelegate*d=fixture();[d test:nil];assert(d.labPreviewRunning);
 [d arm:nil];[d tick:nil];
 assert(d.sessionRequested&&d.calibrating&&d.capturePrepared&&d.captureStops==0&&!d.labPreviewRunning&&d.settingsShows==0);
 // Manual blur must also keep capture alive after taking over a preview.
 d=fixture();[d test:nil];[d panic:nil];[d tick:nil];
 assert(d.manualHold&&d.latched&&d.capturePrepared&&d.captureStops==0&&!d.labPreviewRunning&&d.settingsShows==0);
 // A preview without a takeover still finishes and stops capture.
 d=fixture();[d test:nil];d.testTime=106;[d tick:nil];
 assert(!d.labPreviewRunning&&!d.capturePrepared&&d.captureStops==1&&d.settingsShows==1);
 // Pause cancels the preview immediately; an old deadline cannot restart it.
 d=fixture();[d test:nil];[d pauseProtection:nil];d.testTime=106;[d tick:nil];
 assert(d.paused&&!d.capturePrepared&&!d.labPreviewRunning&&d.captureStops==1&&d.settingsShows==0&&d.displayProgress==0);
 puts("PASS: protection and manual blur take ownership from preview; normal expiry stops capture; Pause cancels without late restoration.");
}return 0;}
