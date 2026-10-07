#import <Cocoa/Cocoa.h>
#import <CoreMotion/CoreMotion.h>
#import <Carbon/Carbon.h>
#import <IOBluetooth/IOBluetooth.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import "PrivacyPolicy.h"
#import "ConnectionPolicy.h"

// This experiment has no access to private compositor classes.
static BOOL compositorAvailable(void) { return MTLCreateSystemDefaultDevice()!=nil; }
#import "PublicVeil.inc"

@interface VeilRecoveryPanel : NSPanel @end
@implementation VeilRecoveryPanel
- (BOOL)canBecomeKeyWindow {return YES;}
- (BOOL)canBecomeMainWindow {return NO;}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate,CMHeadphoneMotionManagerDelegate>
@property NSWindow *window;
@property BOOL capturePrepared,labPreviewRunning;
@property double captureIdleDeadline;
@property NSTextField *captureNote;
- (void)prepareCapture:(id)sender;
- (void)captureStatusChanged;
- (BOOL)captureReady;
- (void)stopScreenCapture;

@property BOOL sessionRequested,reconnecting,manualHold,streamPrimed,bluetoothBusy;
@property BOOL phoneMode;
@property double lastMacRequest;
@property NSButton *phoneButton,*macButton;
- (void)usePhone:(id)sender;
- (void)backToMac:(id)sender;
@property NSUInteger motionGeneration,reconnectAttempt;
@property double nextReconnectAttempt,streamStarted,bluetoothAttemptStarted;
@property IOBluetoothDevice *reconnectDevice;
@property NSPopUpButton *reconnectPicker;
@property NSTextField *reconnectHint;
@property NSArray<IOBluetoothDevice*> *pairedDevicesCache;
@property BOOL deviceRefreshInFlight;
@property NSMutableArray<NSPanel*> *recoveryPanels;
@property NSMutableArray<NSTextField*> *recoveryTitles,*recoveryNotes;
- (void)restartMotionStream;
- (void)receiveMotion:(CMDeviceMotion*)motion;
- (void)enterRecovery:(NSString*)reason;
- (void)maintainConnection:(double)now;
- (void)updateRecoveryPresentation;
- (void)pauseProtection:(id)sender;
- (BOOL)motionPermissionDenied;
@property NSString *screenLayoutSignature;
@property NSMutableArray<NSString*> *diagnostics;
@property BOOL previewNeedsRefresh;
@property double maxFrameGap,lastGapEvent;
- (void)recordEvent:(NSString*)event;
@property NSMutableArray<NSView*> *pages;
@property NSMutableArray<NSButton*> *navigation;
@property NSButton *pauseButton,*autoHideToggle;
@property NSSlider *comfortSlider;
@property NSTextField *comfortLabel,*shortcutNote;
@property NSMutableArray<NSNumber*> *calibrationYaws,*calibrationTimes;
@property BOOL paused,calibrating,autoArmWhenReady,baselineValid,autoHide;
@property double yawBaseline,filteredYaw,comfort,turnSince,calibrationDeadline;
@property NSInteger calibrationSensor;
@property double lastShortcutTime;
@property UInt32 lastShortcutID;
@property NSUInteger shortcutCount;
@property NSString *shortcutRegistration;
- (void)shortcutFromMenu:(NSMenuItem*)sender;
- (void)handleShortcut:(UInt32)identifier;
- (void)beginCalibration;

@property NSButton *radioToggle;
@property NSPopUpButton *radioPicker;
@property NSTextField *radioLabel;
@property IOBluetoothDevice *radioDevice;
@property NSMutableArray<NSNumber*> *radioSamples;
@property double radioBaseline,radioMedian,radioLastPoll,radioLastValid,radioWeakSince;
@property BOOL radioBusy;
@property NSStatusItem *status;
@property CMHeadphoneMotionManager *motion;

@property CMDeviceMotion *latest;
@property NSMutableArray<NSWindow*> *veils;
@property NSMutableArray<NSNumber*> *peaks;
@property NSTimer *timer;
@property CADisplayLink *animationLink;
- (void)configureAnimation:(BOOL)active;
@property NSTextField *stateLabel,*details,*previewLabel;
@property NSButton *walkToggle,*connectButton,*armButton;
@property NSView *previewSurface;
@property double displayProgress,previewProgress;
- (void)wakeAnimation;
@property BOOL desktopPreview,engineFailed;
@property NSSlider *slider;

@property BOOL connected,armed,latched,seen,previousHigh;
@property NSInteger sensor;
@property double received,lastStamp,filtered,lastPeak,started,testUntil,lastTick,lastUI;
@property NSString *reason;

- (void)panic:(id)sender;
@end
static OSStatus hotkeyHandler(EventHandlerCallRef c,EventRef event,void *context){EventHotKeyID identifier;OSStatus e=GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(identifier),NULL,&identifier);if(e==noErr)[(__bridge AppDelegate*)context handleShortcut:identifier.id];return noErr;}
static NSTextField *label(NSString *s,CGFloat size,NSRect r){NSTextField *v=[NSTextField wrappingLabelWithString:s];v.font=[NSFont systemFontOfSize:size];v.frame=r;v.textColor=NSColor.labelColor;return v;}
@implementation AppDelegate
- (NSButton*)button:(NSString*)title action:(SEL)action frame:(NSRect)frame {NSButton*b=[NSButton buttonWithTitle:title target:self action:action];b.frame=frame;b.bezelStyle=NSBezelStyleRounded;[_window.contentView addSubview:b];return b;}
- (NSView *)card:(NSRect)frame parent:(NSView *)parent {
 NSView*c=[[NSView alloc]initWithFrame:frame];c.wantsLayer=YES;c.layer.cornerRadius=14;c.layer.backgroundColor=[NSColor colorWithWhite:1 alpha:.9].CGColor;c.layer.borderWidth=.5;c.layer.borderColor=[NSColor colorWithWhite:0 alpha:.07].CGColor;[parent addSubview:c];return c;
}
- (NSButton *)actionButton:(NSString*)title action:(SEL)action frame:(NSRect)frame parent:(NSView*)parent {
 NSButton*b=[NSButton buttonWithTitle:title target:self action:action];b.frame=frame;b.bezelStyle=NSBezelStyleRounded;b.controlSize=NSControlSizeLarge;[parent addSubview:b];return b;
}
- (void)selectPage:(NSButton*)sender {NSInteger selection=sender.tag;for(NSUInteger i=0;i<_pages.count;i++)_pages[i].hidden=i!=selection;for(NSButton*b in _navigation)b.state=b.tag==selection?NSControlStateValueOn:NSControlStateValueOff;}
- (void)buildInterface {
 _window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,820,650) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskFullSizeContentView backing:NSBackingStoreBuffered defer:NO];_window.title=@"AirVeil";_window.titleVisibility=NSWindowTitleHidden;_window.titlebarAppearsTransparent=YES;_window.releasedWhenClosed=NO;_window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];_window.backgroundColor=[NSColor colorWithWhite:.965 alpha:1];[_window center];
 // This is the app's main window. Let Spaces and Stage Manager manage it
 // independently of the all-space protection and connection recovery surfaces.
 _window.level=NSNormalWindowLevel;
 _window.collectionBehavior=NSWindowCollectionBehaviorManaged|NSWindowCollectionBehaviorPrimary;
 NSView*root=_window.contentView;
 NSVisualEffectView*sidebar=[[NSVisualEffectView alloc]initWithFrame:NSMakeRect(0,0,184,650)];sidebar.material=NSVisualEffectMaterialSidebar;sidebar.blendingMode=NSVisualEffectBlendingModeBehindWindow;sidebar.state=NSVisualEffectStateActive;sidebar.autoresizingMask=NSViewHeightSizable;[root addSubview:sidebar];
 NSImageView*icon=[[NSImageView alloc]initWithFrame:NSMakeRect(25,524,66,66)];icon.image=[NSImage imageNamed:@"AirVeil"];[sidebar addSubview:icon];
 NSTextField*brand=label(@"AirVeil",23,NSMakeRect(28,482,138,35));brand.font=[NSFont systemFontOfSize:23 weight:NSFontWeightSemibold];[sidebar addSubview:brand];
 NSTextField*tagline=label(@"A little more privacy.",11,NSMakeRect(28,461,145,22));tagline.textColor=NSColor.secondaryLabelColor;[sidebar addSubview:tagline];
 _navigation=[NSMutableArray new];NSArray*names=@[@"Home",@"Shortcuts",@"More"];NSArray*symbols=@[@"slider.horizontal.3",@"command",@"switch.2"];
 for(int i=0;i<3;i++){NSButton*b=[NSButton buttonWithTitle:names[i] target:self action:@selector(selectPage:)];b.frame=NSMakeRect(16,394-i*43,152,35);b.bezelStyle=NSBezelStyleRecessed;[b setButtonType:NSButtonTypePushOnPushOff];b.alignment=NSTextAlignmentLeft;b.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];b.image=[NSImage imageWithSystemSymbolName:symbols[i] accessibilityDescription:names[i]];b.imagePosition=NSImageLeft;b.tag=i;[sidebar addSubview:b];[_navigation addObject:b];}
 _stateLabel=label(@"Not connected",11,NSMakeRect(28,60,144,34));_stateLabel.textColor=NSColor.secondaryLabelColor;[sidebar addSubview:_stateLabel];
 NSTextField*version=label(@"0.7.0  ·  Public beta",10,NSMakeRect(28,29,150,22));version.textColor=NSColor.tertiaryLabelColor;[sidebar addSubview:version];
 _pages=[NSMutableArray new];for(int i=0;i<3;i++){NSView*page=[[NSView alloc]initWithFrame:NSMakeRect(210,22,582,590)];[root addSubview:page];[_pages addObject:page];}
 NSView*v=_pages[0];NSTextField*heading=label(@"Look away. Blur the screen.",26,NSMakeRect(0,546,582,38));heading.font=[NSFont systemFontOfSize:26 weight:NSFontWeightSemibold];[v addSubview:heading];
 _details=label(@"Wear your AirPods. Follow the three steps below to get started.",12,NSMakeRect(0,494,582,42));_details.textColor=NSColor.secondaryLabelColor;[v addSubview:_details];
 NSView*clip=[self card:NSMakeRect(0,322,582,158) parent:v];clip.layer.masksToBounds=YES;
 NSView*demo=[[NSView alloc]initWithFrame:NSMakeRect(-40,-40,662,238)];demo.wantsLayer=YES;demo.layerUsesCoreImageFilters=YES;[clip addSubview:demo];_previewSurface=demo;
 CAGradientLayer*sky=[CAGradientLayer layer];sky.frame=demo.bounds;sky.colors=@[(id)[NSColor colorWithRed:.76 green:.82 blue:.94 alpha:1].CGColor,(id)[NSColor colorWithRed:.94 green:.89 blue:.88 alpha:1].CGColor];sky.startPoint=CGPointMake(0,1);sky.endPoint=CGPointMake(1,0);[demo.layer addSublayer:sky];
 NSView*paper=[self card:NSMakeRect(66,64,360,110) parent:demo];[paper addSubview:label(@"Your screen, softly blurred.",23,NSMakeRect(22,61,325,35))];NSTextField*sample=label(@"Turn your head to add blur.\nLook back to see clearly.",12,NSMakeRect(22,21,325,36));sample.textColor=NSColor.secondaryLabelColor;[paper addSubview:sample];
 NSImageView*ghost=[[NSImageView alloc]initWithFrame:NSMakeRect(460,70,105,105)];ghost.image=[NSImage imageNamed:@"AirVeil"];[demo addSubview:ghost];
 CIFilter*f=[CIFilter filterWithName:@"CIGaussianBlur"];f.name=@"veil";[f setValue:@0 forKey:kCIInputRadiusKey];demo.layer.filters=@[f];
 _previewLabel=label(@"Preview  ·  0°",11,NSMakeRect(0,291,180,22));_previewLabel.textColor=NSColor.secondaryLabelColor;[v addSubview:_previewLabel];
 _slider=[NSSlider sliderWithValue:0 minValue:0 maxValue:90 target:self action:@selector(simulate:)];_slider.frame=NSMakeRect(175,288,407,26);[v addSubview:_slider];
 NSTextField*steps=label(@"SET UP IN THREE STEPS",10,NSMakeRect(0,269,582,20));steps.textColor=NSColor.secondaryLabelColor;steps.font=[NSFont systemFontOfSize:10 weight:NSFontWeightSemibold];[v addSubview:steps];
 [self actionButton:@"1. Allow screen access" action:@selector(prepareCapture:) frame:NSMakeRect(-6,225,197,38) parent:v];
 _connectButton=[self actionButton:@"2. Connect AirPods" action:@selector(connect:) frame:NSMakeRect(191,225,197,38) parent:v];
 _armButton=[self actionButton:@"3. Start protection" action:@selector(arm:) frame:NSMakeRect(388,225,200,38) parent:v];_armButton.bezelColor=NSColor.controlAccentColor;
 NSView*comfort=[self card:NSMakeRect(0,97,582,112) parent:v];NSTextField*comfortTitle=label(@"Comfort zone",14,NSMakeRect(18,74,440,24));comfortTitle.font=[NSFont systemFontOfSize:14 weight:NSFontWeightMedium];[comfort addSubview:comfortTitle];
 _comfortLabel=label(@"28°",16,NSMakeRect(494,74,70,25));_comfortLabel.alignment=NSTextAlignmentRight;_comfortLabel.font=[NSFont monospacedDigitSystemFontOfSize:16 weight:NSFontWeightMedium];[comfort addSubview:_comfortLabel];
 NSTextField*comfortHint=label(@"Turn further before blur starts. Small movements stay clear.",11,NSMakeRect(18,49,546,22));comfortHint.textColor=NSColor.secondaryLabelColor;[comfort addSubview:comfortHint];
 _comfortSlider=[NSSlider sliderWithValue:_comfort minValue:5 maxValue:75 target:self action:@selector(comfortChanged:)];_comfortSlider.frame=NSMakeRect(18,22,546,25);[comfort addSubview:_comfortSlider];_comfortSlider.toolTip=@"Move right for more room to turn before blur starts.";
 NSTextField*leftHint=label(@"Blur sooner",9,NSMakeRect(18,2,200,17));leftHint.textColor=NSColor.tertiaryLabelColor;[comfort addSubview:leftHint];NSTextField*rightHint=label(@"More room to turn",9,NSMakeRect(364,2,200,17));rightHint.textColor=NSColor.tertiaryLabelColor;rightHint.alignment=NSTextAlignmentRight;[comfort addSubview:rightHint];
 _captureNote=label(@"Screen access is off. Screen images stay on your Mac and are not saved.",11,NSMakeRect(0,50,582,38));_captureNote.textColor=NSColor.secondaryLabelColor;[v addSubview:_captureNote];
 _pauseButton=[self actionButton:@"Pause" action:@selector(togglePause:) frame:NSMakeRect(-6,3,293,38) parent:v];
 [self actionButton:@"Try screen blur · 6 sec" action:@selector(test:) frame:NSMakeRect(293,3,294,38) parent:v];
 _slider.toolTip=@"This slider changes only the sample above. Try screen blur to preview the full screen.";
 v=_pages[1];NSTextField*shortTitle=label(@"Keep the window closed.",26,NSMakeRect(0,546,582,38));shortTitle.font=[NSFont systemFontOfSize:26 weight:NSFontWeightSemibold];[v addSubview:shortTitle];[v addSubview:label(@"Control AirVeil from any app with these shortcuts.",12,NSMakeRect(0,508,582,25))];
 NSArray*rows=@[@[@"Connect AirPods",@"Connect AirPods that are paired with this Mac.",@"⌃ ⌥ ⇧ ⌘ C"],@[@"Start protection",@"Face the display and stay still for 1.5 seconds.",@"⌃ ⌥ ⇧ ⌘ R"],@[@"Pause / resume",@"Clear your screen, or start protection again.",@"⌃ ⌥ ⇧ ⌘ P"],@[@"Open settings",@"Open this window.",@"⌃ ⌥ ⇧ ⌘ O"]];
 for(int i=0;i<4;i++){NSView*c=[self card:NSMakeRect(0,391-i*98,582,86) parent:v];[c addSubview:label(rows[i][0],15,NSMakeRect(18,47,367,24))];NSTextField*d=label(rows[i][1],11,NSMakeRect(18,18,373,24));d.textColor=NSColor.secondaryLabelColor;[c addSubview:d];NSTextField*keys=label(rows[i][2],16,NSMakeRect(397,32,167,28));keys.alignment=NSTextAlignmentRight;keys.font=[NSFont monospacedSystemFontOfSize:16 weight:NSFontWeightMedium];[c addSubview:keys];}
 _shortcutNote=label(@"",11,NSMakeRect(0,20,582,60));_shortcutNote.textColor=NSColor.secondaryLabelColor;[v addSubview:_shortcutNote];
 v=_pages[2];NSTextField*advancedTitle=label(@"Make it work for you.",25,NSMakeRect(0,546,582,38));advancedTitle.font=[NSFont systemFontOfSize:25 weight:NSFontWeightSemibold];[v addSubview:advancedTitle];[v addSubview:label(@"Optional settings. Most people can leave these as they are.",12,NSMakeRect(0,508,582,25))];
 _autoHideToggle=[NSButton checkboxWithTitle:@"Hide this window when protection starts" target:self action:@selector(autoHideChanged:)];_autoHideToggle.state=_autoHide?NSControlStateValueOn:NSControlStateValueOff;_autoHideToggle.frame=NSMakeRect(0,463,582,28);[v addSubview:_autoHideToggle];
 _walkToggle=[NSButton checkboxWithTitle:@"Keep blur on after repeated movement (experimental)" target:self action:@selector(walkChanged:)];_walkToggle.frame=NSMakeRect(0,303,582,28);[v addSubview:_walkToggle];
 [v addSubview:label(@"Signal strength (experimental)",15,NSMakeRect(0,255,582,27))];_radioLabel=label(@"Optional. Availability depends on your headphones and Mac.",11,NSMakeRect(0,201,582,47));_radioLabel.textColor=NSColor.secondaryLabelColor;[v addSubview:_radioLabel];
 _radioPicker=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(-5,164,442,32) pullsDown:NO];[_radioPicker addItemWithTitle:@"Choose connected AirPods"];_radioPicker.target=self;_radioPicker.action=@selector(selectRadio:);[v addSubview:_radioPicker];[self actionButton:@"Refresh" action:@selector(refreshRadio:) frame:NSMakeRect(443,164,144,32) parent:v];
 _radioToggle=[NSButton checkboxWithTitle:@"Use signal strength as a distance hint (experimental)" target:self action:@selector(radioChanged:)];_radioToggle.frame=NSMakeRect(0,127,582,27);[v addSubview:_radioToggle];
 [self actionButton:@"Disconnect & stop" action:@selector(stop:) frame:NSMakeRect(-6,75,218,34) parent:v];[self actionButton:@"Copy diagnostics" action:@selector(copyDiagnostics:) frame:NSMakeRect(227,75,200,34) parent:v];
 [v addSubview:label(@"No camera. No saved screen recordings. No uploads.\nPause clears the screen and stops screen capture.\nFor stronger privacy when away, lock your Mac.",11,NSMakeRect(0,0,582,65))];
 [self buildReconnectControls:v];[self comfortChanged:nil];[self selectPage:_navigation[0]];
}
- (void)applicationDidFinishLaunching:(NSNotification*)n {
 [NSUserDefaults.standardUserDefaults registerDefaults:@{@"comfortDegrees":@28,@"autoHideSettings":@YES}];_comfort=fmin(75,fmax(5,[NSUserDefaults.standardUserDefaults doubleForKey:@"comfortDegrees"]));_autoHide=[NSUserDefaults.standardUserDefaults boolForKey:@"autoHideSettings"];
 _diagnostics=[NSMutableArray new];[self recordEvent:@"Started AirVeil 0.7.0 beta"];_calibrationYaws=[NSMutableArray new];_calibrationTimes=[NSMutableArray new];_turnSince=-1;
 _radioSamples=[NSMutableArray new];_radioBaseline=NAN;_radioWeakSince=-1;_veils=[NSMutableArray new];_peaks=[NSMutableArray new];_motion=[CMHeadphoneMotionManager new];_motion.delegate=self;_reason=@"Wear your AirPods. Follow the three steps below to get started.";_received=-1000;
 [self buildInterface];
 NSMenu*mainMenu=[NSMenu new];NSMenuItem*root=[NSMenuItem new];[mainMenu addItem:root];NSMenu*applicationMenu=[NSMenu new];NSArray*commandNames=@[@"Connect AirPods",@"Start protection",@"Pause / Resume",@"Open Settings"];NSArray*equivalents=@[@"c",@"r",@"p",@"o"];for(int i=0;i<4;i++){NSMenuItem*item=[[NSMenuItem alloc]initWithTitle:commandNames[i] action:@selector(shortcutFromMenu:) keyEquivalent:equivalents[i]];item.keyEquivalentModifierMask=NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand|NSEventModifierFlagShift;item.target=self;item.tag=i+1;[applicationMenu addItem:item];}
 [applicationMenu addItem:NSMenuItem.separatorItem];
 [applicationMenu addItemWithTitle:@"Hide AirVeil" action:@selector(hide:) keyEquivalent:@"h"];
 [applicationMenu addItem:NSMenuItem.separatorItem];
 [applicationMenu addItemWithTitle:@"Quit AirVeil" action:@selector(terminate:) keyEquivalent:@"q"];root.submenu=applicationMenu;
 NSMenuItem*windowRoot=[[NSMenuItem alloc]initWithTitle:@"Window" action:NULL keyEquivalent:@""];[mainMenu addItem:windowRoot];NSMenu*windowMenu=[[NSMenu alloc]initWithTitle:@"Window"];
 NSMenuItem*closeItem=[windowMenu addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];closeItem.target=_window;
 NSMenuItem*minimizeItem=[windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];minimizeItem.target=_window;
 windowRoot.submenu=windowMenu;NSApp.mainMenu=mainMenu;
 _status=[[NSStatusBar systemStatusBar]statusItemWithLength:NSVariableStatusItemLength];NSImage*mark=[NSImage imageWithSystemSymbolName:@"circle.dotted" accessibilityDescription:@"AirVeil"];mark.template=YES;_status.button.image=mark;_status.button.title=@"";_status.button.toolTip=@"AirVeil";
 NSMenu*menu=[NSMenu new];for(NSArray*row in @[@[@"Open Settings  ⌃⌥⇧⌘O",NSStringFromSelector(@selector(show:))],@[@"Connect AirPods  ⌃⌥⇧⌘C",NSStringFromSelector(@selector(connect:))],@[@"Start protection  ⌃⌥⇧⌘R",NSStringFromSelector(@selector(arm:))],@[@"Pause / Resume  ⌃⌥⇧⌘P",NSStringFromSelector(@selector(togglePause:))],@[@"Use iPhone · Pause Protection",NSStringFromSelector(@selector(usePhone:))],@[@"Back to Mac · Try reconnecting",NSStringFromSelector(@selector(backToMac:))],@[@"Try Full-Screen Effect",NSStringFromSelector(@selector(test:))],@[@"Blur Now",NSStringFromSelector(@selector(panic:))],@[@"Disconnect & Stop",NSStringFromSelector(@selector(stop:))],@[@"Quit AirVeil",NSStringFromSelector(@selector(quit:))]]){NSMenuItem*item=[[NSMenuItem alloc]initWithTitle:row[0] action:NSSelectorFromString(row[1]) keyEquivalent:@""];item.target=self;[menu addItem:item];}_status.menu=menu;
 [self registerShortcuts];
 [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(screens:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
 [[[NSWorkspace sharedWorkspace]notificationCenter]addObserver:self selector:@selector(sleeping:) name:NSWorkspaceWillSleepNotification object:nil];
 [[[NSWorkspace sharedWorkspace]notificationCenter]addObserver:self selector:@selector(sleeping:) name:NSWorkspaceDidWakeNotification object:nil];
 [self screens:nil];[self wakeAnimation];[self show:nil];[self requestDeviceRefresh];
}
- (void)configureAnimation:(BOOL)active {
 if(active){
   if(_animationLink)return;
   [_timer invalidate];_timer=nil;_lastTick=self.now;
   _animationLink=[NSScreen.mainScreen displayLinkWithTarget:self selector:@selector(tick:)];
   if(_animationLink){_animationLink.preferredFrameRateRange=CAFrameRateRangeMake(60,60,60);[_animationLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];return;}
 }
 else {[_animationLink invalidate];_animationLink=nil;}
 double interval=active?1./60.:(_connected?.25:.5);
 if(!_timer||fabs(_timer.timeInterval-interval)>.001){[_timer invalidate];_timer=[NSTimer timerWithTimeInterval:interval target:self selector:@selector(tick:) userInfo:nil repeats:YES];_timer.tolerance=active?0:interval*.1;[[NSRunLoop mainRunLoop]addTimer:_timer forMode:NSRunLoopCommonModes];}
}
- (void)wakeAnimation {[self configureAnimation:YES];}
- (double)now {return NSProcessInfo.processInfo.systemUptime;}
- (void)show:(id)sender {if(_window.isMiniaturized)[_window deminiaturize:sender];[_window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];}
- (void)comfortChanged:(id)sender {_comfort=round(_comfortSlider.doubleValue);_comfortLabel.stringValue=[NSString stringWithFormat:@"±%.0f°",_comfort];[NSUserDefaults.standardUserDefaults setDouble:_comfort forKey:@"comfortDegrees"];[self wakeAnimation];}
- (void)autoHideChanged:(id)sender {_autoHide=_autoHideToggle.state==NSControlStateValueOn;[NSUserDefaults.standardUserDefaults setBool:_autoHide forKey:@"autoHideSettings"];}
#include "ConnectionRecovery.inc"
- (void)connect:(id)sender {
 if(_phoneMode){[self backToMac:sender];return;}
 [self wakeAnimation];
 if(_connected&&self.fresh){_reason=@"AirPods already connected. Press Control–Option–Shift–Command–R to calibrate.";return;}
 if(!_connected){_connected=YES;[_motion startConnectionStatusUpdates];}
 [self resolveReconnectDevice];
 if(_sessionRequested)[self enterRecovery:@"Waiting for AirPods. Reconnecting automatically."];
 else _reason=@"Waiting for AirPods. Reconnecting automatically.";
 // Explicit commands must bypass the passive reconnect backoff, including the
 // initial recovery grace period. Exactly one attempt is made here.
 _reconnectAttempt=0;_nextReconnectAttempt=self.now;
 [self maintainConnection:self.now];
}
- (BOOL)fresh {return _connected&&_seen&&self.now-_received<0.8;}
- (void)arm:(id)sender {
 [self wakeAnimation];_testUntil=0;
 if(!compositorAvailable()){_reason=@"GPU rendering is unavailable on this Mac.";return;}
 if(!self.captureReady){[self prepareCapture:nil];_reason=@"Getting screen access ready. When ready, click Start protection again.";return;}
 // Protection takes ownership of capture from a temporary preview.
 _labPreviewRunning=NO;
 _phoneMode=NO;
 _sessionRequested=YES;_paused=NO;_manualHold=NO;_latched=NO;
 if(!self.fresh){[self connect:nil];[self enterRecovery:@"Waiting for AirPods. Reconnecting automatically."];return;}
 [self beginCalibration];
}
- (void)beginCalibration {
 if(_radioToggle.state==NSControlStateValueOn&&(!isfinite(_radioBaseline)||self.now-_radioLastValid>4)){_reason=@"Finish Bluetooth baseline setup, or turn off the optional proximity setting.";return;}
 _autoArmWhenReady=NO;_calibrating=YES;_calibrationDeadline=self.now+12;[_calibrationYaws removeAllObjects];[_calibrationTimes removeAllObjects];_calibrationSensor=_latest.sensorLocation;
 if((_armed||_displayProgress>.003)&&!_paused)_latched=YES;
 _reason=@"Look at the screen and hold still for 1.5 seconds.";
}
- (void)collectCalibration:(CMDeviceMotion*)m now:(double)now {
 if(!_calibrating)return;
 if(m.sensorLocation!=_calibrationSensor){[_calibrationYaws removeAllObjects];[_calibrationTimes removeAllObjects];_calibrationSensor=m.sensorLocation;}
 [_calibrationYaws addObject:@(m.attitude.yaw*180/M_PI)];[_calibrationTimes addObject:@(now)];
 while(_calibrationTimes.count>1&&now-_calibrationTimes[1].doubleValue>=1.5){[_calibrationTimes removeObjectAtIndex:0];[_calibrationYaws removeObjectAtIndex:0];}
 if(_calibrationYaws.count<15||now-_calibrationTimes.firstObject.doubleValue<1.5)return;
 double values[256];NSUInteger count=MIN((NSUInteger)256,_calibrationYaws.count);for(NSUInteger i=0;i<count;i++)values[i]=_calibrationYaws[i].doubleValue;
 double mean=veilCircularMean(values,count),spread=veilSpread(values,count,mean);
 if(spread>3){_reason=@"Keep looking at the screen. Hold still for a moment.";return;}
 _reconnecting=NO;_reconnectAttempt=0;_sessionRequested=YES;_manualHold=NO;[self recordEvent:@"Stable calibration completed; resumed tracking"];_yawBaseline=mean;_baselineValid=YES;_sensor=m.sensorLocation;_filteredYaw=0;_calibrating=NO;_autoArmWhenReady=NO;_armed=YES;_paused=NO;_latched=NO;_turnSince=-1;[_peaks removeAllObjects];_previousHigh=NO;_reason=@"Protection is on. Turn your head to blur. Look back to clear.";
 [self updateRecoveryPresentation];if(_autoHide)[_window orderOut:nil];
}
- (void)pauseProtection:(id)sender {
 [self wakeAnimation];_paused=YES;_calibrating=NO;_autoArmWhenReady=NO;_latched=NO;_manualHold=NO;_testUntil=0;_displayProgress=0;
 [self render:0 full:NO right:NO];[self stopScreenCapture];_reason=@"Paused. Your screen stays clear until you choose Resume.";
 [self recordEvent:@"User restored clarity; automatic resume disabled until Resume"];
}
- (void)togglePause:(id)sender {
 [self wakeAnimation];
 if(_phoneMode){[self backToMac:sender];return;}
 if(!_paused&&(_capturePrepared||_sessionRequested||_armed||_latched||_calibrating||_autoArmWhenReady)){[self pauseProtection:sender];return;}
 if(_armed&&_baselineValid&&self.fresh&&self.captureReady){_paused=NO;_manualHold=NO;_turnSince=-1;_reason=@"Resumed with your existing calibration.";if(_autoHide)[_window orderOut:nil];}else [self arm:nil];
}
- (void)restore:(id)sender {[self arm:nil];}
- (void)stop:(id)sender {_phoneMode=NO;_sessionRequested=NO;_reconnecting=NO;_manualHold=NO;_motionGeneration++;_displayProgress=0;_armed=NO;_paused=NO;_calibrating=NO;_autoArmWhenReady=NO;_latched=NO;_connected=NO;_baselineValid=NO;_testUntil=0;[_motion stopDeviceMotionUpdates];[_motion stopConnectionStatusUpdates];_radioToggle.state=NSControlStateValueOff;_reason=@"Disconnected. The display is clear.";[self render:0 full:NO right:NO];[self stopScreenCapture];}
- (void)panic:(id)sender {if(!self.captureReady){[self prepareCapture:nil];_reason=@"Wait for screen access, then choose Blur Now again.";return;}[self wakeAnimation];_labPreviewRunning=NO;_manualHold=YES;_autoArmWhenReady=NO;_calibrating=NO;_paused=NO;_latched=YES;_testUntil=0;_reason=@"Holding soft focus. Use the pause shortcut to restore clarity.";if(_autoHide)[_window orderOut:nil];}
- (void)test:(id)sender {
 [self wakeAnimation];
 if((_armed&&!_paused)||_latched||_calibrating){_reason=@"Pause tracking before trying the six-second effect.";return;}
 if(!self.captureReady){[self prepareCapture:nil];_reason=@"Getting screen access ready. When ready, click Try screen blur again.";return;}
 _slider.doubleValue=0;_labPreviewRunning=YES;_testUntil=self.now+6;
 _reason=@"Six-second preview. Capture stops automatically afterwards.";
 // Excluding this app prevents recursive capture; tuck away its settings first.
 [_window orderOut:nil];
}
- (void)simulate:(id)sender {if(_armed&&!_paused)return;[self wakeAnimation];_previewLabel.stringValue=[NSString stringWithFormat:@"Preview  ·  %.0f°",_slider.doubleValue];}
- (void)walkChanged:(id)sender {[_peaks removeAllObjects];_previousHigh=NO;}
- (void)sleeping:(NSNotification*)n {if(_sessionRequested&&_connected){[self enterRecovery:@"Reconnecting after sleep. Face your screen when the headphones return."];if([n.name isEqualToString:NSWorkspaceDidWakeNotification])_nextReconnectAttempt=self.now;}}
- (void)headphoneMotionManagerDidDisconnect:(CMHeadphoneMotionManager*)manager {NSUInteger generation=_motionGeneration;dispatch_async(dispatch_get_main_queue(),^{if(!self.phoneMode&&self.connected&&manager==self.motion&&generation==self.motionGeneration)[self enterRecovery:@"Headphones disconnected. Reconnecting automatically."];});}
- (void)headphoneMotionManagerDidConnect:(CMHeadphoneMotionManager*)manager {NSUInteger generation=_motionGeneration;dispatch_async(dispatch_get_main_queue(),^{if(self.phoneMode||!self.connected||manager!=self.motion||generation!=self.motionGeneration||self.fresh||self.calibrating)return;self.reconnectAttempt=0;self.nextReconnectAttempt=self.now;[self maintainConnection:self.now];});}
- (void)shortcutFromMenu:(NSMenuItem*)sender {[self handleShortcut:(UInt32)sender.tag];}
- (void)handleShortcut:(UInt32)identifier {
 if(identifier==_lastShortcutID&&self.now-_lastShortcutTime<.15)return;
 _lastShortcutID=identifier;_lastShortcutTime=self.now;_shortcutCount++;
 NSArray*names=@[@"",@"Connect",@"Calibrate",@"Pause / resume",@"Open settings"];
 NSString*received=[NSString stringWithFormat:@"Last received: %@ · %@",identifier<names.count?names[identifier]:@"Unknown",[NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle]];
 _shortcutNote.stringValue=[NSString stringWithFormat:@"%@\n%@",_shortcutRegistration?:@"",received];
 [NSUserDefaults.standardUserDefaults setObject:received forKey:@"lastShortcutReceived"];
 [NSUserDefaults.standardUserDefaults setInteger:_shortcutCount forKey:@"shortcutReceiveCount"];
 switch(identifier){case 1:[self connect:nil];break;case 2:[self arm:nil];break;case 3:[self togglePause:nil];break;case 4:[self show:nil];break;}}
- (void)registerShortcuts {
 EventTypeSpec type={kEventClassKeyboard,kEventHotKeyPressed};OSStatus installed=InstallEventHandler(GetEventDispatcherTarget(),&hotkeyHandler,1,&type,(__bridge void*)self,NULL);
 UInt32 keys[]={kVK_ANSI_C,kVK_ANSI_R,kVK_ANSI_P,kVK_ANSI_O};NSArray*letters=@[@"C",@"R",@"P",@"O"];NSMutableArray*failed=[NSMutableArray new];
 for(int i=0;i<4;i++){EventHotKeyRef ref;EventHotKeyID identifier={'AVPL',(UInt32)(i+1)};OSStatus result=RegisterEventHotKey(keys[i],controlKey|optionKey|cmdKey|shiftKey,identifier,GetEventDispatcherTarget(),0,&ref);if(result!=noErr)[failed addObject:letters[i]];}
 _shortcutRegistration=failed.count?[NSString stringWithFormat:@"Could not register: %@. Another app may use these shortcuts. The menu commands remain available.",[failed componentsJoinedByString:@", "]]:@"All four shortcuts are registered. Last received action appears here.";
 if(installed!=noErr)_shortcutRegistration=[NSString stringWithFormat:@"Shortcut event handler failed (%d). Use the menu commands.",(int)installed];
 _shortcutNote.stringValue=_shortcutRegistration;
}
- (void)recordEvent:(NSString*)event {
 if(!_diagnostics)return;NSString*time=[NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];[_diagnostics addObject:[NSString stringWithFormat:@"%@  %@",time,event]];while(_diagnostics.count>80)[_diagnostics removeObjectAtIndex:0];
}
- (BOOL)captureReady {
 if(!_capturePrepared||!_veils.count)return NO;
 for(NSWindow*w in _veils){VeilView*v=(VeilView*)w.contentView;if(!v.frameReady||v.failure)return NO;}return YES;
}
- (void)prepareCapture:(id)sender {
 _capturePrepared=YES;_captureIdleDeadline=self.now+60;_engineFailed=NO;
 for(NSWindow*w in _veils){VeilView*v=(VeilView*)w.contentView;if(v.failure)[v stopCapture];[v startCapture];}
 [self captureStatusChanged];[self wakeAnimation];
}
- (void)captureStatusChanged {
 NSString*failure=nil;for(NSWindow*w in _veils){VeilView*v=(VeilView*)w.contentView;if(v.failure)failure=v.failure;}
 _engineFailed=failure!=nil;
 _captureNote.stringValue=failure?:(!self.capturePrepared?@"Screen access is off. Screen images stay on your Mac and are not saved.":(self.captureReady?@"Screen access is ready. Connect your AirPods, then start protection.":@"Waiting for screen access and the first frame…"));
 if(failure){_reason=failure;[self recordEvent:failure];}
 [self updateRecoveryPresentation];
}
- (void)stopScreenCapture {
 _capturePrepared=NO;_labPreviewRunning=NO;
 for(NSWindow*w in _veils)[(VeilView*)w.contentView stopCapture];
 _engineFailed=NO;[self captureStatusChanged];
}
- (void)copyDiagnostics:(id)sender {
 NSMutableString*report=[NSMutableString stringWithFormat:@"AirVeil 0.7.0 beta\nPublic ScreenCaptureKit + Core Image / Metal; sandbox enabled\nComfort: %.0f degrees; main-loop max gap: %.1f ms\nMotion active: %@; fresh: %@; capture ready: %@\n%@\n",_comfort,_maxFrameGap*1000,_motion.isDeviceMotionActive?@"yes":@"no",self.fresh?@"yes":@"no",self.captureReady?@"yes":@"no",_shortcutRegistration?:@""];
 for(NSWindow*w in _veils){VeilView*v=(VeilView*)w.contentView;[report appendFormat:@"Display %u: %lu frames; render last %.1f / max %.1f ms; error %@\n",v.displayID,(unsigned long)v.renderedFrames,v.lastRenderMilliseconds,v.maxRenderMilliseconds,v.failure?:@"none"];}
 [report appendFormat:@"Events (no pixels or raw motion):\n%@",[_diagnostics componentsJoinedByString:@"\n"]];
 [NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:report forType:NSPasteboardTypeString];
}
- (void)screens:(id)sender {
 NSMutableArray*parts=[NSMutableArray new];for(NSScreen*s in NSScreen.screens)[parts addObject:[NSString stringWithFormat:@"%@:%@:%.2f",s.deviceDescription[@"NSScreenNumber"],NSStringFromRect(s.frame),s.backingScaleFactor]];
 NSString*signature=[parts componentsJoinedByString:@"|"];if([signature isEqualToString:_screenLayoutSignature])return;BOOL changed=_screenLayoutSignature!=nil;_screenLayoutSignature=signature;
 NSArray*oldWindows=[_veils copy];_veils=[NSMutableArray new];
 for(NSScreen*s in NSScreen.screens){NSWindow*w=[[NSWindow alloc]initWithContentRect:s.frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];w.releasedWhenClosed=NO;w.opaque=NO;w.backgroundColor=NSColor.clearColor;w.hasShadow=NO;w.ignoresMouseEvents=YES;w.hidesOnDeactivate=NO;w.canHide=NO;w.animationBehavior=NSWindowAnimationBehaviorNone;w.alphaValue=1;w.level=NSStatusWindowLevel+1;w.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorCanJoinAllApplications;w.colorSpace=NSColorSpace.sRGBColorSpace;w.title=@"AirVeil effect";
 VeilView*v=[[VeilView alloc]initWithFrame:NSMakeRect(0,0,s.frame.size.width,s.frame.size.height)];v.displayID=[s.deviceDescription[@"NSScreenNumber"]unsignedIntValue];// Capture at logical display resolution to keep the experiment lightweight.
 // The first 12% of blur cross-fades in; the clear state is the real display.
 v.displayScale=1.0;
 __weak AppDelegate*weakSelf=self;v.stateChanged=^{[weakSelf captureStatusChanged];};w.contentView=v;[_veils addObject:w];}
 if(changed){for(NSPanel*panel in _recoveryPanels)[panel close];_recoveryPanels=nil;}if(changed&&_armed){_manualHold=YES;_baselineValid=NO;if(!_paused)_latched=YES;_reason=@"Display layout changed. Recalibrate when ready.";[self recordEvent:@"Display geometry changed; rebuilt overlays without clearing current blur"];}[self render:_displayProgress full:NO right:NO];for(NSWindow*w in oldWindows){[(VeilView*)w.contentView stopCapture];[w close];}if(_capturePrepared)[self prepareCapture:nil];
}
- (void)render:(double)p full:(BOOL)full right:(BOOL)right {
 BOOL failed=NO;
 for(NSWindow*w in _veils){VeilView*v=(VeilView*)w.contentView;[v showProgress:p full:NO right:NO];if(v.blurFailed)failed=YES;}
 _engineFailed=failed;[self updateRecoveryPresentation];
}
- (void)refreshRadio:(id)sender {
 if(_armed){_reason=@"Disconnect before selecting another Bluetooth device.";return;}
 if(sender)[self requestDeviceRefresh];
 [_radioPicker removeAllItems];[_radioPicker addItemWithTitle:@"Choose the AirPods you are wearing"];
 for(IOBluetoothDevice*d in _pairedDevicesCache){if(d.isConnected){[_radioPicker addItemWithTitle:d.name?:@"Unnamed device"];_radioPicker.lastItem.representedObject=d;}}
 [self selectRadio:nil];
}
- (void)selectRadio:(id)sender {
 if(_armed){if(!_paused)_latched=YES;_reason=@"Bluetooth device changed. Disconnect and calibrate again.";}
 _radioDevice=_radioPicker.selectedItem.representedObject;[_radioSamples removeAllObjects];_radioBaseline=NAN;_radioLastValid=0;_radioWeakSince=-1;
}
- (void)radioChanged:(id)sender {
 if(_armed){if(!_paused)_latched=YES;_reason=@"Bluetooth settings changed. Recalibrate when ready.";}
 [_radioSamples removeAllObjects];_radioBaseline=NAN;_radioWeakSince=-1;
 if(_radioToggle.state==NSControlStateValueOn&&!_radioDevice)[self refreshRadio:nil];
}
- (void)pollRadio:(double)now {
 if(_phoneMode)return;
 if(_radioToggle.state!=NSControlStateValueOn||!_radioDevice)return;
 if(_armed&&!_paused&&!_calibrating&&now-_radioLastValid>4){_latched=YES;_reason=@"Bluetooth readings stopped. Check the connection and recalibrate.";}
 if(_radioBusy||now-_radioLastPoll<1)return;_radioBusy=YES;_radioLastPoll=now;IOBluetoothDevice*target=_radioDevice;NSUInteger generation=_motionGeneration;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{int value=target.isConnected?target.rawRSSI:127;
 dispatch_async(dispatch_get_main_queue(),^{self.radioBusy=NO;
 if(self.phoneMode||generation!=self.motionGeneration||self.radioDevice!=target||self.radioToggle.state!=NSControlStateValueOn)return;
 // +127 is the documented unavailable sentinel. Reject all nonphysical/unsupported readings.
 if(value>=0||value<=-127)return;
 double t=self.now;self.radioLastValid=t;[self.radioSamples addObject:@(value)];if(self.radioSamples.count>10)[self.radioSamples removeObjectAtIndex:0];
 NSUInteger count=MIN(5,self.radioSamples.count);NSArray*recent=[self.radioSamples subarrayWithRange:NSMakeRange(self.radioSamples.count-count,count)];NSArray*sorted=[recent sortedArrayUsingSelector:@selector(compare:)];self.radioMedian=[sorted[count/2]doubleValue];
 if(!isfinite(self.radioBaseline)&&self.radioSamples.count==10){NSArray*all=[self.radioSamples sortedArrayUsingSelector:@selector(compare:)];self.radioBaseline=([all[4]doubleValue]+[all[5]doubleValue])/2;}
 if(self.armed&&!self.paused&&!self.calibrating&&isfinite(self.radioBaseline)){
 if(self.radioBaseline-self.radioMedian>=12){if(self.radioWeakSince<0)self.radioWeakSince=t;if(t-self.radioWeakSince>=3){self.latched=YES;self.reason=@"Bluetooth signal declined. Use the pause shortcut to restore clarity.";}}
 else if(self.radioBaseline-self.radioMedian<8)self.radioWeakSince=-1;
 }
 });});
}
- (void)tick:(id)sender {
 double now=self.now,elapsed=_lastTick?now-_lastTick:1./60.,dt=fmin(1./30.,elapsed);_lastTick=now;
 if(_armed&&!_paused&&elapsed>_maxFrameGap)_maxFrameGap=elapsed;
 if(_armed&&!_paused&&elapsed>.08&&now-_lastGapEvent>1){_lastGapEvent=now;[self recordEvent:[NSString stringWithFormat:@"Frame gap %.1f ms (animation catch-up limited)",elapsed*1000]];}
 if(_capturePrepared&&_labPreviewRunning&&now>=_testUntil&&_displayProgress<.0005){[self stopScreenCapture];[self show:nil];_reason=@"Preview finished. Screen capture is off.";}
 if(_capturePrepared&&!_labPreviewRunning&&!(_armed&&!_paused)&&!_latched&&!_calibrating&&now>_captureIdleDeadline)[self stopScreenCapture];
 if(_connected&&_seen&&!self.fresh)[self enterRecovery:@"Motion updates stopped. Reconnecting automatically."];
 if(_calibrating&&now>_calibrationDeadline){
 if(_reconnecting){[_calibrationYaws removeAllObjects];[_calibrationTimes removeAllObjects];_calibrationDeadline=now+12;_reason=@"Reconnected. Face your screen and hold still for 1.5 seconds.";}
 else {_calibrating=NO;_autoArmWhenReady=NO;_reason=@"Calibration did not finish. Face the display and try again.";}}
 [self maintainConnection:now];
 [self pollRadio:now];
 double yaw=0,p=0;
 if(_armed&&!_paused&&!_calibrating){
 if(!self.fresh){_latched=YES;_baselineValid=NO;}
 if(_baselineValid&&self.fresh){yaw=veilWrap(_latest.attitude.yaw*180/M_PI-_yawBaseline);_filteredYaw=veilWrap(_filteredYaw+veilWrap(yaw-_filteredYaw)*(1-exp(-dt/.10)));double magnitude=fabs(_filteredYaw);
 if(magnitude>_comfort){if(_turnSince<0)_turnSince=now;if(now-_turnSince>=.12)p=veilProgressForComfort(magnitude,_comfort);}else _turnSince=-1;
 }}
 BOOL holding=_latched&&!_paused;double target=holding?1:p;
 if(now<_testUntil)target=veilDemoProgress(6-(_testUntil-now));
 _displayProgress=veilFollow(_displayProgress,target,dt);if(fabs(_displayProgress-target)<.0005)_displayProgress=target;
 [self render:_displayProgress full:NO right:NO];
 double previewTarget=(_armed&&!_paused)||now<_testUntil||holding?_displayProgress:veilProgressForComfort(_slider.doubleValue,_comfort);
 BOOL visiblePreview=_window.isVisible&&!_pages[0].hidden;
 double next=veilFollow(_previewProgress,previewTarget,dt);
 if(visiblePreview&&(_previewNeedsRefresh||fabs(next-_previewProgress)>.000001||(fabs(next-previewTarget)<.0005&&_previewProgress!=previewTarget))){_previewProgress=fabs(next-previewTarget)<.0005?previewTarget:next;[CATransaction begin];[CATransaction setDisableActions:YES];[_previewSurface.layer setValue:@(80*_previewProgress) forKeyPath:@"filters.veil.inputRadius"];[CATransaction commit];_previewNeedsRefresh=NO;}
 if(!visiblePreview){_previewProgress=previewTarget;_previewNeedsRefresh=YES;}
 if(now-_lastUI>.4&&_window.isVisible){_lastUI=now;
 _phoneButton.enabled=!_phoneMode;_macButton.enabled=!_calibrating;
 _slider.enabled=!(_armed&&!_paused);_pauseButton.enabled=_capturePrepared||_sessionRequested||_armed||_paused||_latched||_calibrating||_autoArmWhenReady;_radioPicker.enabled=!_armed;_pauseButton.title=_paused?@"Resume":@"Pause";
 NSString*state=_paused?@"Paused":(_reconnecting&&!_calibrating?@"Reconnecting…":(_calibrating?@"Calibrating…":(_autoArmWhenReady?@"Connecting…":(_paused?@"Paused":(holding?@"Soft focus":(_armed?@"Protection on":(self.fresh?@"Connected":(_connected?@"Waiting for AirPods":@"Not connected"))))))));
 if(_phoneMode)state=@"Using iPhone";if(_labPreviewRunning)state=@"Preview";
 if(![_stateLabel.stringValue isEqualToString:state])_stateLabel.stringValue=state;
 NSString*reason=_reason;if([CMHeadphoneMotionManager authorizationStatus]==CMAuthorizationStatusDenied)reason=@"Motion permission is off. Allow AirVeil in System Settings, then reconnect.";
 if(![_details.stringValue isEqualToString:reason])_details.stringValue=reason;
 if(_armed&&!_paused)_previewLabel.stringValue=[NSString stringWithFormat:@"Turn  %.0f°  ·  Blur %.0f%%",fabs(yaw),100*_displayProgress];
 else if(_phoneMode)_previewLabel.stringValue=@"Paused · Using iPhone";
 else if(_paused)_previewLabel.stringValue=@"Paused · Screen clear";
 _status.button.toolTip=[NSString stringWithFormat:@"AirVeil · %@",state];
 if(_radioToggle.state!=NSControlStateValueOn)_radioLabel.stringValue=@"Optional. Uses a signal trend, not a precise distance measurement.";
 else if(!_radioDevice)_radioLabel.stringValue=@"Choose the AirPods you are wearing. Other devices are not selected automatically.";
 else if(now-_radioLastValid>4)_radioLabel.stringValue=@"Signal unavailable. Your device or Bluetooth module may not support this reading.";
 else if(!isfinite(_radioBaseline))_radioLabel.stringValue=[NSString stringWithFormat:@"Stay in your seat: collecting baseline %lu / 10",(unsigned long)_radioSamples.count];
 else _radioLabel.stringValue=[NSString stringWithFormat:@"Signal %.0f dBm · Seated baseline %.0f dBm\nSustained 12 dB decline triggers soft focus.",_radioMedian,_radioBaseline];
 }
 BOOL animating=(_armed&&!_paused&&!_reconnecting&&!_manualHold)||_calibrating||now<_testUntil||fabs(_displayProgress-target)>.001||fabs(_previewProgress-previewTarget)>.001;
 // Keep a display cadence while any overlay is visible, including a static
 // privacy hold. The renderer skips identical content/radius combinations.
 [self configureAnimation:animating||_displayProgress>.0005];
}
- (void)quit:(id)sender {[NSApp terminate:nil];}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender{return NO;}
- (BOOL)applicationShouldHandleReopen:(NSApplication*)sender hasVisibleWindows:(BOOL)flag{[self show:nil];return YES;}
- (void)applicationWillTerminate:(NSNotification*)n {[self stopScreenCapture];_connected=NO;_motionGeneration++;[_animationLink invalidate];[_timer invalidate];[_motion stopDeviceMotionUpdates];[_motion stopConnectionStatusUpdates];}
@end
int main(int argc,const char*argv[]){@autoreleasepool{NSApplication*app=NSApplication.sharedApplication;AppDelegate*delegate=[AppDelegate new];app.delegate=delegate;[app setActivationPolicy:NSApplicationActivationPolicyRegular];[app run];}return 0;}
