#define main AirVeilApplicationMain
#import "../main.m"
#undef main
#include <assert.h>

@interface FakeAttitude : NSObject
@property double yaw;
@end
@implementation FakeAttitude @end
@interface FakeMotion : NSObject
@property double timestamp;
@property FakeAttitude *attitude;
@property NSInteger sensorLocation;
@property CMAcceleration userAcceleration;
@end
@implementation FakeMotion @end
@interface FakeManager : NSObject
@property (copy) CMHeadphoneDeviceMotionHandler handler;
@property NSUInteger starts,stops,statusStarts,statusStops;
- (void)startConnectionStatusUpdates;
- (void)stopConnectionStatusUpdates;
- (void)startDeviceMotionUpdatesToQueue:(NSOperationQueue*)queue withHandler:(CMHeadphoneDeviceMotionHandler)handler;
- (void)stopDeviceMotionUpdates;
@end
@implementation FakeManager
- (void)startConnectionStatusUpdates {_statusStarts++;}
- (void)stopConnectionStatusUpdates {_statusStops++;}
- (void)startDeviceMotionUpdatesToQueue:(NSOperationQueue*)queue withHandler:(CMHeadphoneDeviceMotionHandler)handler {_handler=handler;_starts++;}
- (void)stopDeviceMotionUpdates {_stops++;}
@end
@interface FakeHeadphones : NSObject
@property BOOL paired,connected;
@property NSUInteger attempts;
- (BOOL)isPaired;
- (BOOL)isConnected;
- (IOReturn)openConnection:(id)target withPageTimeout:(BluetoothHCIPageTimeout)timeout authenticationRequired:(BOOL)authentication;
@end
@implementation FakeHeadphones
- (BOOL)isPaired {return _paired;}
- (BOOL)isConnected {return _connected;}
- (NSString*)addressString {return nil;}
- (IOReturn)openConnection:(id)target withPageTimeout:(BluetoothHCIPageTimeout)timeout authenticationRequired:(BOOL)authentication {assert(target);assert(authentication);_attempts++;return kIOReturnNotReady;}
@end
@interface TestDelegate : AppDelegate
@property double testTime,rendered;
@property BOOL recoveryVisible,denied;
@end
@implementation TestDelegate
- (double)now {return _testTime;}
- (void)wakeAnimation {}
- (void)configureAnimation:(BOOL)active {}
- (void)resolveReconnectDevice {}
- (void)updateRecoveryPresentation {_recoveryVisible=!self.paused&&(self.sessionRequested||self.latched)&&(self.reconnecting||self.engineFailed);}
- (void)render:(double)p full:(BOOL)full right:(BOOL)right {_rendered=p;[self updateRecoveryPresentation];}
- (BOOL)motionPermissionDenied {return _denied;}
// Motion state-machine tests isolate the separately tested screen capture gate.
- (BOOL)captureReady {return YES;}
- (void)stopScreenCapture {}
@end
static TestDelegate* fixture(void){
 TestDelegate*d=[TestDelegate new];d.testTime=100;d.motion=(id)[FakeManager new];d.calibrationYaws=[NSMutableArray new];d.calibrationTimes=[NSMutableArray new];d.peaks=[NSMutableArray new];d.radioSamples=[NSMutableArray new];d.diagnostics=[NSMutableArray new];d.received=-1000;d.comfort=10;d.turnSince=-1;
 FakeHeadphones*h=[FakeHeadphones new];h.paired=YES;d.reconnectDevice=(id)h;return d;
}
static FakeMotion* sample(double t,double yaw,NSInteger sensor){FakeMotion*m=[FakeMotion new];m.timestamp=t;m.attitude=[FakeAttitude new];m.attitude.yaw=yaw*M_PI/180;m.sensorLocation=sensor;return m;}
static void feed(TestDelegate*d,double t,double yaw,NSInteger sensor){d.testTime=t;[d receiveMotion:(id)sample(t,yaw,sensor)];[d tick:nil];[d.timer invalidate];}
static void settle(TestDelegate*d,double start,double yaw,NSInteger sensor){for(int i=0;i<26;i++)feed(d,start+i*.1,yaw,sensor);}

@interface DiscoveryDelegate : TestDelegate
@property dispatch_semaphore_t entered,lookupGate;
@property NSUInteger reads;
@end
@implementation DiscoveryDelegate
- (NSArray*)readPairedDevices {
 assert(!NSThread.isMainThread);self.reads++;
 dispatch_semaphore_signal(self.entered);
 dispatch_semaphore_wait(self.lookupGate,DISPATCH_TIME_FOREVER);
 return @[];
}
@end

int main(void){@autoreleasepool{
 TestDelegate*d=fixture();[d arm:nil];assert(d.sessionRequested&&d.reconnecting&&d.latched&&d.recoveryVisible);
 d.testTime=103;[d maintainConnection:d.now];assert(((FakeManager*)d.motion).starts==1);assert(((FakeHeadphones*)d.reconnectDevice).attempts==1);
 NSUInteger attempts=((FakeHeadphones*)d.reconnectDevice).attempts;[d maintainConnection:103.1];assert(((FakeHeadphones*)d.reconnectDevice).attempts==attempts);
 [d receiveMotion:(id)sample(1,30,1)];assert(!d.fresh);[d receiveMotion:(id)sample(1,30,1)];assert(!d.fresh);
 // Actual new samples calibrate, but the blur remains until stable calibration.
 feed(d,104,30,1);assert(d.calibrating&&d.latched&&!d.baselineValid);settle(d,104.1,30,1);
 assert(d.armed&&d.baselineValid&&!d.reconnecting&&!d.latched&&!d.recoveryVisible);assert(fabs(d.yawBaseline-30)<.001);
 // A return after being put in the case must use a new baseline.
 [d enterRecovery:@"Test case disconnect"];assert(d.latched&&d.recoveryVisible&&!d.baselineValid);settle(d,108,70,1);assert(d.baselineValid&&!d.reconnecting&&fabs(d.yawBaseline-70)<.001);
 // A stalled motion stream also enters recovery without a disconnect callback.
 d.testTime=112;[d tick:nil];[d.timer invalidate];assert(d.reconnecting&&d.latched&&d.recoveryVisible);
 // The emergency button overrides automatic restoration even when samples return.
 [d pauseProtection:nil];assert(d.paused&&!d.recoveryVisible&&d.rendered==0);settle(d,113,90,1);assert(d.paused&&!d.calibrating&&!d.baselineValid&&!d.recoveryVisible);
 [d togglePause:nil];settle(d,116,90,1);assert(!d.paused&&d.baselineValid&&!d.reconnecting);
 // Sensor changes cannot reuse the previous sensor's baseline.
 feed(d,119,110,2);assert(d.reconnecting&&d.calibrating&&d.latched);settle(d,119.1,110,2);assert(d.baselineValid&&d.sensor==2&&!d.reconnecting);
 // Shaking / moving cannot complete a recovery calibration.
 [d enterRecovery:@"Test unstable return"];for(int i=0;i<150;i++)feed(d,123+i*.1,i%2?50:90,2);assert(d.reconnecting&&!d.baselineValid&&d.latched&&d.calibrating);
 // A manual blur hold is never cleared by reconnection.
 [d panic:nil];[d enterRecovery:@"Test disconnect during manual hold"];settle(d,140,100,2);assert(d.manualHold&&d.latched&&!d.calibrating&&!d.baselineValid);
 // An explicit start must override that hold even if the headset is still away.
 d.testTime=145;[d tick:nil];[d.timer invalidate];[d arm:nil];assert(!d.manualHold&&d.autoArmWhenReady&&d.latched);settle(d,146,100,2);assert(d.baselineValid&&!d.latched);
 // Stop invalidates queued callbacks and prevents any further reconnect attempts.
 [d restartMotionStream];CMHeadphoneDeviceMotionHandler old=((FakeManager*)d.motion).handler;[d stop:nil];old((id)sample(145,0,1),nil);old((id)sample(146,0,1),nil);NSUInteger starts=((FakeManager*)d.motion).starts;[d maintainConnection:200];assert(!d.connected&&!d.sessionRequested&&!d.recoveryVisible&&!d.fresh&&((FakeManager*)d.motion).starts==starts);
 // Restarted streams reject callbacks from the old generation.
 d=fixture();d.connected=YES;[d restartMotionStream];old=((FakeManager*)d.motion).handler;[d restartMotionStream];old((id)sample(150,0,1),nil);old((id)sample(151,0,1),nil);assert(!d.fresh);
 d.denied=YES;starts=((FakeManager*)d.motion).starts;[d maintainConnection:200];assert(((FakeManager*)d.motion).starts==starts);
 for(int i=0;i<1000;i++)assert(veilReconnectDelay(i)>=5&&veilReconnectDelay(i)<=30);
 puts("PASS: automatic recovery, stable recalibration, stale-stream recovery, manual restore, manual hold, sensor switching, unstable samples, stop cancellation, callback generations, denied permission, bounded retries");
 // Switching away is explicit: clear immediately and make no further requests,
 // even if old motion, delegate and Bluetooth callbacks arrive afterwards.
 d=fixture();d.comfort=7;[d arm:nil];settle(d,101,35,1);assert(d.baselineValid);
 FakeManager*manager=(id)d.motion;FakeHeadphones*headphones=(id)d.reconnectDevice;
 old=manager.handler;starts=manager.starts;attempts=headphones.attempts;
 [d headphoneMotionManagerDidDisconnect:(id)manager];
 [d usePhone:nil];assert(d.phoneMode&&d.paused&&!d.connected&&!d.sessionRequested&&!d.baselineValid&&d.rendered==0&&!d.recoveryVisible);
 old((id)sample(106,60,1),nil);old((id)sample(107,60,1),nil);
 [d headphoneMotionManagerDidConnect:(id)manager];[d connectionComplete:(id)headphones status:kIOReturnSuccess];
 CFRunLoopRunInMode(kCFRunLoopDefaultMode,.001,false);
 d.testTime=300;[d tick:nil];[d.timer invalidate];[d maintainConnection:300];
 assert(d.phoneMode&&!d.fresh&&!d.latched&&manager.starts==starts&&headphones.attempts==attempts&&manager.statusStops>0&&d.comfort==7);
 // A return starts once immediately, without the 30-second retry delay. It
 // still waits for fresh, stable data instead of reusing the old orientation.
 [d backToMac:nil];assert(!d.phoneMode&&d.connected&&d.sessionRequested&&d.autoArmWhenReady&&d.latched);
 assert(manager.starts==starts+1&&headphones.attempts==attempts+1&&!d.baselineValid&&d.comfort==7);
 [d backToMac:nil];assert(manager.starts==starts+1); // double-click is harmless
 feed(d,300.1,80,1);assert(!d.fresh&&!d.baselineValid);
 feed(d,300.2,80,1);assert(d.calibrating&&!d.baselineValid&&d.latched);
 feed(d,300.3,80,1);assert(!d.baselineValid);
 settle(d,300.4,80,1);assert(d.armed&&d.baselineValid&&!d.paused&&!d.reconnecting&&fabs(d.yawBaseline-80)<.001);
 // Manual retry during an existing recovery must issue exactly one request.
 d.testTime=304;[d enterRecovery:@"Delayed automatic retry"];d.reconnectAttempt=99;d.nextReconnectAttempt=334;
 starts=manager.starts;attempts=headphones.attempts;[d backToMac:nil];
 assert(manager.starts==starts+1&&headphones.attempts==attempts+1&&d.nextReconnectAttempt==309);
 // Existing Connect / Resume / Calibrate commands can explicitly return from
 // phone mode. Stop and emergency Restore continue to override auto-resume.
 [d usePhone:nil];d.testTime=305;[d connect:nil];assert(!d.phoneMode&&d.sessionRequested&&d.connected);
 [d pauseProtection:nil];settle(d,306,95,1);assert(d.paused&&!d.calibrating);
 [d usePhone:nil];d.testTime=310;[d togglePause:nil];assert(!d.phoneMode&&d.sessionRequested);
 [d usePhone:nil];d.testTime=311;[d arm:nil];assert(!d.phoneMode&&d.sessionRequested);
 [d usePhone:nil];[d stop:nil];assert(!d.phoneMode&&!d.sessionRequested&&!d.connected);
 // Deferred disconnect events from the previous session cannot invalidate a
 // new session after leaving phone mode.
 d=fixture();[d arm:nil];[d headphoneMotionManagerDidDisconnect:d.motion];[d usePhone:nil];d.testTime=102;[d backToMac:nil];
 d.seen=YES;d.received=d.now;d.baselineValid=YES;d.reconnecting=NO;d.latched=NO;
 CFRunLoopRunInMode(kCFRunLoopDefaultMode,.001,false);assert(d.baselineValid&&!d.reconnecting);
 puts("PASS: explicit phone suspension, immediate single reconnect, repeated clicks, preserved comfort, fresh return calibration, delayed callback isolation, pause/stop priority, existing command compatibility");
 // A system service stalled during discovery cannot block the main queue or
 // Restore screen. Repeated requests share one in-flight lookup.
 DiscoveryDelegate*discovery=[DiscoveryDelegate new];
 discovery.entered=dispatch_semaphore_create(0);discovery.lookupGate=dispatch_semaphore_create(0);
 discovery.sessionRequested=YES;discovery.latched=YES;discovery.rendered=1;
 [discovery requestDeviceRefresh];[discovery requestDeviceRefresh];
 assert(discovery.deviceRefreshInFlight);
 assert(dispatch_semaphore_wait(discovery.entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0);
 __block BOOL mainQueueResponsive=NO;
 dispatch_async(dispatch_get_main_queue(),^{[discovery pauseProtection:nil];mainQueueResponsive=YES;});
 double deadline=CFAbsoluteTimeGetCurrent()+1;
 while(!mainQueueResponsive&&CFAbsoluteTimeGetCurrent()<deadline)CFRunLoopRunInMode(kCFRunLoopDefaultMode,.01,false);
 assert(mainQueueResponsive&&discovery.paused&&discovery.rendered==0&&discovery.reads==1);
 dispatch_semaphore_signal(discovery.lookupGate);
 deadline=CFAbsoluteTimeGetCurrent()+1;
 while(discovery.deviceRefreshInFlight&&CFAbsoluteTimeGetCurrent()<deadline)CFRunLoopRunInMode(kCFRunLoopDefaultMode,.01,false);
 assert(!discovery.deviceRefreshInFlight&&discovery.pairedDevicesCache!=nil&&discovery.paused&&discovery.rendered==0);
 puts("PASS: blocked Bluetooth discovery leaves the main queue and Restore screen responsive; duplicate requests do not spawn extra lookups or re-arm protection.");
}return 0;}
