//
//  AnnotationViewController.h
//	ThatPDF v0.3.1
//
//	Created by Brett van Zuiden.
//	Copyright © 2013 Ink. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ReaderDocument.h"
#import "Annotation.h"
#import "ReaderContentView.h"
#import <WacomDevice/WacomDeviceFramework.h>

extern NSString *const AnnotationViewControllerType_None;
extern NSString *const AnnotationViewControllerType_Sign;
extern NSString *const AnnotationViewControllerType_RedPen;
extern NSString *const AnnotationViewControllerType_Text;
extern NSString *const AnnotationViewControllerType_Erase;
extern NSString *const AnnotationViewControllerType_ESign;
extern NSString *const AnnotationViewControllerType_EPen;

@protocol TextKeyboardNotificationDelegate <NSObject>

@required
- (void)keyboardWillShow:(CGFloat )offset;
- (void)keyboardDidHidden:(CGFloat )offset;

@end

@interface AnnotationViewController : UIViewController<UIGestureRecognizerDelegate, UIPopoverControllerDelegate, WacomDiscoveryCallback, WacomStylusEventCallback>

@property UIImageView *image;
@property NSMutableArray *imageArray;
@property NSMutableDictionary *imageDictionary;

@property NSString *annotationType;
@property ReaderDocument *document;
@property NSInteger currentPage;
@property (nonatomic, assign) id<TextKeyboardNotificationDelegate> delegate;

- (id)initWithDocument:(ReaderDocument *)document;
- (BOOL)moveToPage:(int)page contentView:(ReaderContentView*) view;
- (void) hide;
- (void) clear;
- (void) undo;

- (AnnotationStore*) annotations;

- (UIImage *)getImageFromAnnotationsWithPage:(int)page;

//Draw View Segment Control
- (void)SegControlPerformAction:(id)sender;
- (void)showPrivacyMessage:(UIButton *)sender;

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