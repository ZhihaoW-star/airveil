#define main AirVeilApplicationMain
#import "../main.m"
#undef main
#include <assert.h>
@interface GateDelegate : AppDelegate
@property NSUInteger preparationRequests;
@end
@implementation GateDelegate
- (void)wakeAnimation {}
- (void)configureAnimation:(BOOL)active {}
- (void)updateRecoveryPresentation {}
- (void)prepareCapture:(id)sender {self.preparationRequests++;}
@end
int main(void){@autoreleasepool{
    [NSApplication sharedApplication];
    GateDelegate*d=[GateDelegate new];d.veils=[NSMutableArray new];
    [d arm:nil];assert(d.preparationRequests==1&&!d.sessionRequested&&!d.armed);
    [d panic:nil];assert(d.preparationRequests==2&&!d.latched);
    [d test:nil];assert(d.preparationRequests==3&&d.testUntil==0);
    NSWindow*w=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,100,100) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];w.releasedWhenClosed=NO;
    VeilView*v=[[VeilView alloc]initWithFrame:NSMakeRect(0,0,100,100)];w.contentView=v;[d.veils addObject:w];d.capturePrepared=YES;
    assert(!d.captureReady);v.frameReady=YES;assert(d.captureReady);
    v.failure=@"denied";assert(!d.captureReady);v.failure=nil;
    [d pauseProtection:nil];assert(d.paused&&!d.capturePrepared&&!d.captureReady&&!v.captureWanted&&!w.isVisible);
    [w close];
    puts("PASS: capture permission / first-frame readiness gate blocks false arming; manual hold and preview cannot claim protection before pixels exist; Pause stops capture.");
}return 0;}
