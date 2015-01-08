//
//  OAAnnotationVC.h
//  OAOffice
//
//  Created by admin on 14/12/8.
//  Copyright (c) 2014年 DigitalOcean. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ReaderDocument.h"
#import "ReaderContentView.h"
#import "GLKit/GLKView.h"
#import "drawingView.h"
#import <WacomDevice/WacomDeviceFramework.h>

@interface OAAnnotationVC : UIViewController <UIPopoverControllerDelegate, WacomDiscoveryCallback, WacomStylusEventCallback>

@property (strong, nonatomic) UISegmentedControl *toolBar;
- (IBAction)SegControlPerformAction:(id)sender;
- (IBAction)showPrivacyMessage:(UIButton *)sender;
@property (strong, nonatomic) UISegmentedControl *HandednessControl;
@property (strong, nonatomic) UILabel *versionLabel;

//@property (retain, nonatomic) IBOutlet GLKView *glview;

@property (strong, nonatomic) IBOutlet drawingView *dV;

@property (strong, nonatomic) ReaderDocument *document;
@property NSInteger currentPage;

- (id)initWithDocument:(ReaderDocument *)document;
- (void)moveToPage:(int)page contentView:(ReaderContentView *) view;
- (void) hide;
- (void) clear;
- (void) undo;


//WacomDiscoveryCallback

///notification method for when a device is connected.
- (void) deviceConnected:(WacomDevice *)device;

///notification method for when a device is disconnected.
- (void) deviceDisconnected:(WacomDevice *)device;

///notification method for when a device is discovered.
- (void) deviceDiscovered:(WacomDevice *)device;


///notification method for when device discovery is not possible because bluetooth is powered off.
///this allows one to pop up a warning dialog to let the user know to turn on bluetooth.
- (void) discoveryStatePoweredOff;

//WacomStylusEventCallback
///notification method for when a new stylus event is ready.
-(void)stylusEvent:(WacomStylusEvent *)stylusEvent;

@end
