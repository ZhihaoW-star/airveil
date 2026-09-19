// AppDelegate implementation. Connection intent is independent of pause state:
// reconnect may continue after Restore screen, but it must never re-arm it.
- (void)usePhone:(id)sender {
 // Explicit user intent, not an inferred disconnect cause. Suspend both sensor
 // streaming and retry requests; the system still controls the audio route.
 [self wakeAnimation];_phoneMode=YES;_motionGeneration++;_connected=NO;
 _sessionRequested=NO;_reconnecting=NO;_armed=NO;_baselineValid=NO;
 _seen=NO;_latest=nil;_streamPrimed=NO;_received=-1000;_nextReconnectAttempt=INFINITY;
 _lastMacRequest=0;
 [_motion stopDeviceMotionUpdates];[_motion stopConnectionStatusUpdates];
 [_radioSamples removeAllObjects];_radioBaseline=NAN;_radioLastValid=0;_radioWeakSince=-1;
 [self pauseProtection:nil];
 _reason=@"Using iPhone. Protection and reconnect attempts are paused. Choose Back to Mac when ready.";
 [self recordEvent:@"User selected iPhone; cleared screen, stopped motion and reconnect requests"];
}
- (void)backToMac:(id)sender {
 if(!_phoneMode&&_calibrating&&self.fresh)return;
 if(!_phoneMode&&_lastMacRequest>0&&self.now-_lastMacRequest<1)return;
 _lastMacRequest=self.now;
 // Explicitly resume protection using the existing preferences, but obtain a
 // fresh baseline. Never reuse an orientation from another device session.
 [self arm:sender];
 if(_phoneMode||!_sessionRequested)return;
 [self recordEvent:@"Back to Mac requested; bypassed automatic reconnect backoff"];
 if(self.fresh||_calibrating)return;
 if(![self motionPermissionDenied])_reason=@"Connecting to this Mac now. If AirPods stay on iPhone, select them in the Mac Bluetooth menu.";
}
- (BOOL)motionPermissionDenied {return [CMHeadphoneMotionManager authorizationStatus]==CMAuthorizationStatusDenied||[CMHeadphoneMotionManager authorizationStatus]==CMAuthorizationStatusRestricted;}
- (NSArray<IOBluetoothDevice*>*)readPairedDevices {return IOBluetoothDevice.pairedDevices?:@[];}
- (void)requestDeviceRefresh {
 // The first IOBluetooth lookup can synchronously wait for CoreBluetooth.
 // Never block drawing or emergency restoration on this system service.
 if(_deviceRefreshInFlight)return;
 _deviceRefreshInFlight=YES;
 if(!_pairedDevicesCache)_reconnectHint.stringValue=@"Loading paired headphones…";
 __weak AppDelegate*weakSelf=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
   AppDelegate*self=weakSelf;if(!self)return;
   NSArray*devices=nil;NSString*failure=nil;
   @try {devices=[[self readPairedDevices] copy];}
   @catch(NSException*e){failure=e.reason?:@"Bluetooth discovery failed";}
   dispatch_async(dispatch_get_main_queue(),^{
     self.deviceRefreshInFlight=NO;
     if(failure){[self recordEvent:failure];self.reconnectHint.stringValue=@"Could not load paired headphones. Choose Refresh to retry.";return;}
     self.pairedDevicesCache=devices?:@[];
     [self refreshReconnectDevices:nil];
     if(!self.armed&&!self.radioDevice)[self refreshRadio:nil];
     [self recordEvent:@"Paired device list loaded without blocking the display"];
   });
 });
}
- (NSArray<IOBluetoothDevice*>*)pairedHeadphones {
 NSMutableArray*devices=[NSMutableArray new];
 for(IOBluetoothDevice*d in _pairedDevicesCache){
 BOOL namedAirPods=[d.name rangeOfString:@"AirPods" options:NSCaseInsensitiveSearch].location!=NSNotFound&&d.name.length;
 BOOL headphone=d.deviceClassMajor==kBluetoothDeviceClassMajorAudio&&(d.deviceClassMinor==kBluetoothDeviceClassMinorAudioHeadphones||d.deviceClassMinor==kBluetoothDeviceClassMinorAudioHeadset||d.deviceClassMinor==kBluetoothDeviceClassMinorAudioHandsFree);
 if(d.isPaired&&(namedAirPods||headphone))[devices addObject:d];
 }return devices;
}
- (void)buildReconnectControls:(NSView*)parent {
 [parent addSubview:label(@"Automatic reconnect",15,NSMakeRect(0,418,582,27))];
 _reconnectPicker=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(-5,379,442,32) pullsDown:NO];_reconnectPicker.target=self;_reconnectPicker.action=@selector(selectReconnectDevice:);[parent addSubview:_reconnectPicker];
 [self actionButton:@"Refresh" action:@selector(refreshReconnectDevices:) frame:NSMakeRect(443,379,144,32) parent:parent];
 _reconnectHint=label(@"",11,NSMakeRect(0,337,582,37));_reconnectHint.textColor=NSColor.secondaryLabelColor;[parent addSubview:_reconnectHint];
 [self refreshReconnectDevices:nil];
}
- (void)refreshReconnectDevices:(id)sender {
 if(sender)[self requestDeviceRefresh];
 [_reconnectPicker removeAllItems];[_reconnectPicker addItemWithTitle:@"Automatic · current AirPods"];
 NSString*explicitAddress=[NSUserDefaults.standardUserDefaults stringForKey:@"reconnectDeviceAddress"];
 for(IOBluetoothDevice*d in [self pairedHeadphones]){[_reconnectPicker addItemWithTitle:d.name?:@"Paired headphones"];_reconnectPicker.lastItem.representedObject=d;if([d.addressString isEqualToString:explicitAddress])[_reconnectPicker selectItem:_reconnectPicker.lastItem];}
 [self resolveReconnectDevice];
}
- (void)resolveReconnectDevice {
 NSArray<IOBluetoothDevice*>*devices=[self pairedHeadphones];NSString*explicitAddress=[NSUserDefaults.standardUserDefaults stringForKey:@"reconnectDeviceAddress"];
 NSString*remembered=[NSUserDefaults.standardUserDefaults stringForKey:@"lastMotionHeadphonesAddress"];
 IOBluetoothDevice*selected=nil;NSMutableArray*connectedAirPods=[NSMutableArray new];NSMutableArray*airPods=[NSMutableArray new];
 for(IOBluetoothDevice*d in devices){
 if(explicitAddress.length&&[d.addressString isEqualToString:explicitAddress])selected=d;
 if([d.name rangeOfString:@"AirPods" options:NSCaseInsensitiveSearch].location!=NSNotFound&&d.name.length){[airPods addObject:d];if(d.isConnected)[connectedAirPods addObject:d];}
 }
 if(!explicitAddress.length){
 if(connectedAirPods.count==1)selected=connectedAirPods.firstObject;
 if(!selected)for(IOBluetoothDevice*d in devices)if([d.addressString isEqualToString:remembered])selected=d;
 if(!selected&&airPods.count==1)selected=airPods.firstObject;
 }
 _reconnectDevice=selected;
 _reconnectHint.stringValue=selected?[NSString stringWithFormat:@"Reconnect to %@. Retries slow down while away.",selected.name?:@"your headphones"]:@"Select your paired headphones if they were renamed or several pairs are available.";
}
- (void)selectReconnectDevice:(id)sender {
 IOBluetoothDevice*d=_reconnectPicker.selectedItem.representedObject;
 if(d.addressString)[NSUserDefaults.standardUserDefaults setObject:d.addressString forKey:@"reconnectDeviceAddress"];else [NSUserDefaults.standardUserDefaults removeObjectForKey:@"reconnectDeviceAddress"];
 [self resolveReconnectDevice];
 if(_connected){_motionGeneration++;[_motion stopDeviceMotionUpdates];[self enterRecovery:@"Headphones changed. Waiting for fresh motion data."];_nextReconnectAttempt=self.now;}
}
- (void)restartMotionStream {
 if(_phoneMode||!_connected)return;_motionGeneration++;NSUInteger generation=_motionGeneration;
 [_motion stopDeviceMotionUpdates];_streamPrimed=NO;_seen=NO;_latest=nil;_received=-1000;_streamStarted=self.now;
 __weak AppDelegate*weakSelf=self;
 [_motion startDeviceMotionUpdatesToQueue:NSOperationQueue.mainQueue withHandler:^(CMDeviceMotion*m,NSError*error){
 AppDelegate*self=weakSelf;if(!self||!self.connected||self.motionGeneration!=generation)return;
 if(error){[self enterRecovery:@"Motion connection interrupted. Reconnecting automatically."];return;}
 if(m)[self receiveMotion:m];
 }];
}
- (void)receiveMotion:(CMDeviceMotion*)m {
 if(_phoneMode||!_connected||!isfinite(m.attitude.yaw)||!isfinite(m.timestamp))return;
 // Discard the first callback after each restart. Require advancing samples,
 // so a cached attitude cannot resume protection or complete calibration.
 if(!_streamPrimed){_streamPrimed=YES;_lastStamp=m.timestamp;return;}
 if(m.timestamp<=_lastStamp)return;
 if(_armed&&_baselineValid&&m.sensorLocation!=_sensor)[self enterRecovery:@"Active earbud changed. Recalibrating when stable."];
 double now=self.now;BOOL first=!_seen;_latest=m;_lastStamp=m.timestamp;_received=now;_seen=YES;_streamPrimed=YES;
 if(first){_reconnectAttempt=0;_nextReconnectAttempt=now+5;[self recordEvent:@"Fresh advancing motion samples received"];
 if(_reconnectDevice.isConnected&&_reconnectDevice.addressString)[NSUserDefaults.standardUserDefaults setObject:_reconnectDevice.addressString forKey:@"lastMotionHeadphonesAddress"];
 if(!_sessionRequested)_reason=@"AirPods connected. Sit naturally and calibrate when ready.";
 }
 if(_autoArmWhenReady&&_sessionRequested&&!_paused&&!_manualHold)[self beginCalibration];
 [self collectCalibration:m now:now];
 if(_armed&&!_paused&&!_calibrating&&!_reconnecting&&_walkToggle.state==NSControlStateValueOn){CMAcceleration a=m.userAcceleration;double power=sqrt(a.x*a.x+a.y*a.y+a.z*a.z);BOOL high=power>.16;if(high&&!_previousHigh&&now-_lastPeak>.24){[_peaks addObject:@(now)];_lastPeak=now;}_previousHigh=high;while(_peaks.count&&now-_peaks.firstObject.doubleValue>2.5)[_peaks removeObjectAtIndex:0];if(_peaks.count>=4){_manualHold=YES;_latched=YES;_reason=@"Repeated movement detected. Press the pause shortcut to restore clarity.";}}
}
- (void)enterRecovery:(NSString*)reason {
 if(_phoneMode||!_connected)return;
 BOOL first=!_reconnecting;BOOL interrupted=_seen||_calibrating;
 // A manual/proximity hold must not be silently released by a reconnect.
 if(_latched&&!_reconnecting&&!_calibrating)_manualHold=YES;
 _reconnecting=YES;_baselineValid=NO;_calibrating=NO;_seen=NO;_latest=nil;_received=-1000;_streamPrimed=NO;
 _autoArmWhenReady=_sessionRequested&&!_paused&&!_manualHold;
 if(_sessionRequested&&!_paused)_latched=YES;
 if(first||interrupted){_reason=reason;_reconnectAttempt=0;_nextReconnectAttempt=self.now+2;[self recordEvent:reason];
 if(_radioToggle.state==NSControlStateValueOn){[_radioSamples removeAllObjects];_radioBaseline=NAN;_radioLastValid=self.now;_radioWeakSince=-1;}}
 [self wakeAnimation];[self updateRecoveryPresentation];
}
- (void)maintainConnection:(double)now {
 if(_phoneMode||!_connected||self.fresh||_calibrating||now<_nextReconnectAttempt)return;
 if([self motionPermissionDenied]){_reason=@"Motion permission is off. Restore the screen and check System Settings.";return;}
 _nextReconnectAttempt=now+veilReconnectDelay(_reconnectAttempt++);
 [self restartMotionStream];[self resolveReconnectDevice];
 if(_bluetoothBusy&&now-_bluetoothAttemptStarted>10)_bluetoothBusy=NO;
 if(_reconnectDevice.isPaired&&!_reconnectDevice.isConnected&&!_bluetoothBusy){
 _bluetoothBusy=YES;_bluetoothAttemptStarted=now;
 // Async baseband attempt, only to an already paired chosen headset. A live
 // Bluetooth link alone is never treated as a recovered motion connection.
 IOReturn status=[_reconnectDevice openConnection:self withPageTimeout:0x1F40 authenticationRequired:YES];
 if(status!=kIOReturnSuccess){_bluetoothBusy=NO;[self recordEvent:[NSString stringWithFormat:@"Bluetooth reconnect request returned %d; retry scheduled",(int)status]];}
 }
 [self recordEvent:[NSString stringWithFormat:@"Motion reconnect attempt %lu; next in %.0f seconds",(unsigned long)_reconnectAttempt,_nextReconnectAttempt-now]];
}
- (void)connectionComplete:(IOBluetoothDevice*)device status:(IOReturn)status {
 dispatch_async(dispatch_get_main_queue(),^{
 if(device!=self.reconnectDevice)return;self.bluetoothBusy=NO;if(self.phoneMode||!self.connected)return;
 [self recordEvent:device.isConnected?@"Bluetooth connected; waiting for fresh motion":@"Bluetooth still unavailable; retry remains scheduled"];
 if(device.isConnected&&!self.fresh&&!self.calibrating&&self.now-self.streamStarted>1)self.nextReconnectAttempt=self.now;
 });
}
- (void)createRecoveryPanels {
 _recoveryPanels=[NSMutableArray new];_recoveryTitles=[NSMutableArray new];_recoveryNotes=[NSMutableArray new];
 for(NSScreen*screen in NSScreen.screens){
 NSRect visible=screen.visibleFrame;CGFloat width=MIN(360,visible.size.width-32);NSRect frame=NSMakeRect(NSMidX(visible)-width/2,NSMinY(visible)+48,width,214);
 NSPanel*panel=[[VeilRecoveryPanel alloc]initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
 panel.title=@"Connection recovery";panel.releasedWhenClosed=NO;panel.opaque=NO;panel.backgroundColor=NSColor.clearColor;panel.hasShadow=YES;panel.hidesOnDeactivate=NO;panel.canHide=NO;panel.animationBehavior=NSWindowAnimationBehaviorNone;panel.level=NSStatusWindowLevel+2;panel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorCanJoinAllApplications;panel.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];
 NSView*card=panel.contentView;card.wantsLayer=YES;card.layer.cornerRadius=18;card.layer.masksToBounds=YES;card.layer.backgroundColor=[NSColor colorWithWhite:.97 alpha:.98].CGColor;card.layer.borderWidth=.5;card.layer.borderColor=[NSColor colorWithWhite:0 alpha:.08].CGColor;
 NSTextField*title=label(@"Disconnected",16,NSMakeRect(22,165,width-44,24));title.font=[NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];[card addSubview:title];[_recoveryTitles addObject:title];
 NSTextField*note=label(@"Reconnecting automatically.\nUse iPhone pauses protection and retries.",12,NSMakeRect(22,113,width-44,42));note.textColor=NSColor.secondaryLabelColor;[card addSubview:note];[_recoveryNotes addObject:note];
 NSButton*restore=[self actionButton:@"Restore screen" action:@selector(pauseProtection:) frame:NSMakeRect(16,63,width-32,34) parent:card];restore.toolTip=@"Keep the screen clear until you explicitly resume protection.";
 CGFloat half=(width-40)/2;
 NSButton*phone=[self actionButton:@"Use iPhone" action:@selector(usePhone:) frame:NSMakeRect(16,18,half,34) parent:card];phone.toolTip=@"Clear the screen and stop AirVeil reconnect attempts.";
 NSButton*retry=[self actionButton:@"Back to Mac" action:@selector(backToMac:) frame:NSMakeRect(24+half,18,half,34) parent:card];retry.toolTip=@"Try connecting now, then recalibrate and resume protection.";
 [_recoveryPanels addObject:panel];
 }
}
- (void)updateRecoveryPresentation {
 BOOL needed=!_paused&&(_sessionRequested||_latched)&&(_reconnecting||_engineFailed);
 if(!needed){for(NSPanel*panel in _recoveryPanels)if(panel.isVisible)[panel orderOut:nil];return;}
 if(!_recoveryPanels.count)[self createRecoveryPanels];
 NSString*title=@"Disconnected";NSString*note=@"Reconnecting automatically.\nUse iPhone pauses protection and retries.";
 if(_engineFailed){title=@"Display effect unavailable";note=@"Restore the screen to pause the effect.\nYou can resume from the menu later.";}
 else if([self motionPermissionDenied]){title=@"Motion access unavailable";note=@"Restore the screen, then allow motion access\nin System Settings.";}
 else if(self.fresh){title=@"Reconnected";note=_manualHold?@"Your screen is still in soft focus.\nRestore it whenever you are ready.":@"Face your screen and stay still.\nCalibration finishes after 1.5 steady seconds.";}
 BOOL justAppeared=NO;for(NSUInteger i=0;i<_recoveryPanels.count;i++){
 if(![_recoveryTitles[i].stringValue isEqualToString:title])_recoveryTitles[i].stringValue=title;
 if(![_recoveryNotes[i].stringValue isEqualToString:note])_recoveryNotes[i].stringValue=note;
 if(!_recoveryPanels[i].isVisible){[_recoveryPanels[i] orderFrontRegardless];justAppeared=YES;}
 }
 if(justAppeared)[_recoveryPanels.firstObject makeKeyWindow];
}
