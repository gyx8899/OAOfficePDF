//
//	ReaderViewController.m
//	Reader v2.8.1
//
//	Created by Julius Oklamcak on 2011-07-01.
//	Copyright © 2011-2014 Julius Oklamcak. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//	of the Software, and to permit persons to whom the Software is furnished to
//	do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ReaderConstants.h"
#import "ReaderViewController.h"
#import "ThumbsViewController.h"
#import "ReaderMainToolbar.h"
#import "ReaderAnnotateToolbar.h"
#import "ReaderMainPagebar.h"
#import "ReaderContentView.h"
#import "ReaderThumbCache.h"
#import "ReaderThumbQueue.h"

#import "DocumentsUpdate.h"
#import "MBProgressHUD.h"
#import "AFNetworking.h"
#import "OAUserListVC.h"

#import <MessageUI/MessageUI.h>

@interface ReaderViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate, MFMailComposeViewControllerDelegate, UIDocumentInteractionControllerDelegate,
									ReaderMainToolbarDelegate, ReaderMainPagebarDelegate, ReaderContentViewDelegate, ThumbsViewControllerDelegate,ReaderAnnotateToolbarDelegate,UIAlertViewDelegate, TextKeyboardNotificationDelegate, UserListSelectedDelegate,UIPopoverControllerDelegate>
@end

@implementation ReaderViewController
{
	ReaderDocument *document;

	UIScrollView *theScrollView;

	ReaderMainToolbar *mainToolbar;
    
    ReaderAnnotateToolbar *annotateToolbar;

	ReaderMainPagebar *mainPagebar;

	NSMutableDictionary *contentViews;

	UIUserInterfaceIdiom userInterfaceIdiom;

	NSInteger currentPage, minimumPage, maximumPage;

	UIDocumentInteractionController *documentInteraction;

	UIPrintInteractionController *printInteraction;

	CGFloat scrollViewOutset;

	CGSize lastAppearSize;

	NSDate *lastHideTime;

	BOOL ignoreDidScroll;
    
    UIPopoverController *_popover;
    
    NSString *selectedUser;
    
    NSInteger _alertSelectedIndex;
}

#pragma mark - Constants

#define STATUS_HEIGHT 20.0f

#define TOOLBAR_HEIGHT 44.0f
#define PAGEBAR_HEIGHT 48.0f

#define SCROLLVIEW_OUTSET_SMALL 4.0f
#define SCROLLVIEW_OUTSET_LARGE 8.0f

#define TAP_AREA_SIZE 48.0f

#pragma mark - Properties

@synthesize delegate;

#pragma mark - ReaderViewController methods

- (void)updateContentSize:(UIScrollView *)scrollView
{
	CGFloat contentHeight = scrollView.bounds.size.height; // Height

	CGFloat contentWidth = (scrollView.bounds.size.width * maximumPage);

	scrollView.contentSize = CGSizeMake(contentWidth, contentHeight);
}

- (void)updateContentViews:(UIScrollView *)scrollView
{
	[self updateContentSize:scrollView]; // Update content size first

	[contentViews enumerateKeysAndObjectsUsingBlock: // Enumerate content views
		^(NSNumber *key, ReaderContentView *contentView, BOOL *stop)
		{
			NSInteger page = [key integerValue]; // Page number value

			CGRect viewRect = CGRectZero; viewRect.size = scrollView.bounds.size;

			viewRect.origin.x = (viewRect.size.width * (page - 1)); // Update X

			contentView.frame = CGRectInset(viewRect, scrollViewOutset, 0.0f);
		}
	];

	NSInteger page = currentPage; // Update scroll view offset to current page

	CGPoint contentOffset = CGPointMake((scrollView.bounds.size.width * (page - 1)), 0.0f);

	if (CGPointEqualToPoint(scrollView.contentOffset, contentOffset) == false) // Update
	{
		scrollView.contentOffset = contentOffset; // Update content offset
	}

	[mainToolbar setBookmarkState:[document.bookmarks containsIndex:page]];

	[mainPagebar updatePagebar]; // Update page bar
}

- (void)addContentView:(UIScrollView *)scrollView page:(NSInteger)page
{
	CGRect viewRect = CGRectZero; viewRect.size = scrollView.bounds.size;

	viewRect.origin.x = (viewRect.size.width * (page - 1)); viewRect = CGRectInset(viewRect, scrollViewOutset, 0.0f);

	NSURL *fileURL = [NSURL fileURLWithPath:document.fileURL];
    NSString *phrase = document.password; NSString *guid = document.guid; // Document properties

//	ReaderContentView *contentView = [[ReaderContentView alloc] initWithFrame:viewRect fileURL:fileURL page:page password:phrase]; // ReaderContentView
    ReaderContentView *contentView = [[ReaderContentView alloc] initWithFrame:viewRect fileURL:fileURL page:page password:phrase annotations:[document annotations]]; // ReaderContentView

	contentView.message = self; [contentViews setObject:contentView forKey:[NSNumber numberWithInteger:page]]; [scrollView addSubview:contentView];

	[contentView showPageThumb:fileURL page:page password:phrase guid:guid]; // Request page preview thumb
}

- (void)layoutContentViews:(UIScrollView *)scrollView
{
	CGFloat viewWidth = scrollView.bounds.size.width; // View width

	CGFloat contentOffsetX = scrollView.contentOffset.x; // Content offset X

	NSInteger pageB = ((contentOffsetX + viewWidth - 1.0f) / viewWidth); // Pages

	NSInteger pageA = (contentOffsetX / viewWidth); pageB += 2; // Add extra pages

	if (pageA < minimumPage) pageA = minimumPage; if (pageB > maximumPage) pageB = maximumPage;

	NSRange pageRange = NSMakeRange(pageA, (pageB - pageA + 1)); // Make page range (A to B)

	NSMutableIndexSet *pageSet = [NSMutableIndexSet indexSetWithIndexesInRange:pageRange];

	for (NSNumber *key in [contentViews allKeys]) // Enumerate content views
	{
		NSInteger page = [key integerValue]; // Page number value

		if ([pageSet containsIndex:page] == NO) // Remove content view
		{
			ReaderContentView *contentView = [contentViews objectForKey:key];

			[contentView removeFromSuperview]; [contentViews removeObjectForKey:key];
		}
		else // Visible content view - so remove it from page set
		{
			[pageSet removeIndex:page];
		}
	}

	NSInteger pages = pageSet.count;

	if (pages > 0) // We have pages to add
	{
		NSEnumerationOptions options = 0; // Default

		if (pages == 2) // Handle case of only two content views
		{
			if ((maximumPage > 2) && ([pageSet lastIndex] == maximumPage)) options = NSEnumerationReverse;
		}
		else if (pages == 3) // Handle three content views - show the middle one first
		{
			NSMutableIndexSet *workSet = [pageSet mutableCopy]; options = NSEnumerationReverse;

			[workSet removeIndex:[pageSet firstIndex]]; [workSet removeIndex:[pageSet lastIndex]];

			NSInteger page = [workSet firstIndex]; [pageSet removeIndex:page];

			[self addContentView:scrollView page:page];
		}

		[pageSet enumerateIndexesWithOptions:options usingBlock: // Enumerate page set
			^(NSUInteger page, BOOL *stop)
			{
				[self addContentView:scrollView page:page];
			}
		];
	}
}

- (void)handleScrollViewDidEnd:(UIScrollView *)scrollView
{
	CGFloat viewWidth = scrollView.bounds.size.width; // Scroll view width

	CGFloat contentOffsetX = scrollView.contentOffset.x; // Content offset X

	NSInteger page = (contentOffsetX / viewWidth); page++; // Page number

	if (page != currentPage) // Only if on different page
	{
		currentPage = page; document.pageNumber = [NSNumber numberWithInteger:page];

		[contentViews enumerateKeysAndObjectsUsingBlock: // Enumerate content views
			^(NSNumber *key, ReaderContentView *contentView, BOOL *stop)
			{
				if ([key integerValue] != page) [contentView zoomResetAnimated:NO];
			}
		];

		[mainToolbar setBookmarkState:[document.bookmarks containsIndex:page]];

		[mainPagebar updatePagebar]; // Update page bar
	}
}

- (void)showDocumentPage:(NSInteger)page
{
	if (page != currentPage) // Only if on different page
	{
		if ((page < minimumPage) || (page > maximumPage)) return;

		currentPage = page; document.pageNumber = [NSNumber numberWithInteger:page];

		CGPoint contentOffset = CGPointMake((theScrollView.bounds.size.width * (page - 1)), 0.0f);

		if (CGPointEqualToPoint(theScrollView.contentOffset, contentOffset) == true)
			[self layoutContentViews:theScrollView];
		else
			[theScrollView setContentOffset:contentOffset];

		[contentViews enumerateKeysAndObjectsUsingBlock: // Enumerate content views
			^(NSNumber *key, ReaderContentView *contentView, BOOL *stop)
			{
				if ([key integerValue] != page) [contentView zoomResetAnimated:NO];
			}
		];

		[mainToolbar setBookmarkState:[document.bookmarks containsIndex:page]];

		[mainPagebar updatePagebar]; // Update page bar
	}
}

- (void)showDocument
{
	[self updateContentSize:theScrollView]; // Update content size first

	[self showDocumentPage:[document.pageNumber integerValue]]; // Show page

	document.lastOpen = [NSDate date]; // Update document last opened date
}

- (void)closeDocument
{
	if (printInteraction != nil) [printInteraction dismissAnimated:NO];

//	[document archiveDocumentProperties]; // Save any ReaderDocument changes
    document.password = nil;
    [document saveReaderDocument];

	[[ReaderThumbQueue sharedInstance] cancelOperationsWithGUID:document.guid];

	[[ReaderThumbCache sharedInstance] removeAllObjects]; // Empty the thumb cache

//	if ([delegate respondsToSelector:@selector(dismissReaderViewController:)] == YES)
    if ([delegate respondsToSelector:@selector(dismissReaderViewController:withDocument:withTag:)] == YES)
	{
//		[delegate dismissReaderViewController:self]; // Dismiss the ReaderViewController
        [delegate dismissReaderViewController:self withDocument:document withTag:@0]; // Dismiss the ReaderViewController
//        [self.navigationController popToRootViewControllerAnimated:YES];
	}
	else // We have a "Delegate must respond to -dismissReaderViewController:" error
	{
		NSAssert(NO, @"Delegate must respond to -dismissReaderViewController:");
	}
}

#pragma mark - UIViewController methods

- (instancetype)initWithReaderDocument:(ReaderDocument *)object
{
	if ((self = [super initWithNibName:nil bundle:nil])) // Initialize superclass
	{
		if ((object != nil) && ([object isKindOfClass:[ReaderDocument class]])) // Valid object
		{
			userInterfaceIdiom = [UIDevice currentDevice].userInterfaceIdiom; // User interface idiom

			NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter]; // Default notification center

			[notificationCenter addObserver:self selector:@selector(applicationWillResign:) name:UIApplicationWillTerminateNotification object:nil];

			[notificationCenter addObserver:self selector:@selector(applicationWillResign:) name:UIApplicationWillResignActiveNotification object:nil];
            
            [notificationCenter addObserver:self selector:@selector(handleAnnotationModeNotification:) name:DocumentsSetAnnotationModeSignNotification object:nil];
            [notificationCenter addObserver:self selector:@selector(handleAnnotationModeNotification:) name:DocumentsSetAnnotationModeRedPenNotification object:nil];
            [notificationCenter addObserver:self selector:@selector(handleAnnotationModeNotification:) name:DocumentsSetAnnotationModeOffNotification object:nil];
            [notificationCenter addObserver:self selector:@selector(handleAnnotationModeNotification:) name:DocumentsSetAnnotationModeEsignNotification object:nil];
            [notificationCenter addObserver:self selector:@selector(handleAnnotationModeNotification:) name:DocumentsSetAnnotationModeTextNotification object:nil];
            [notificationCenter addObserver:self selector:@selector(handleAnnotationModeNotification:) name:DocumentsSetAnnotationModeEPenNotification object:nil];
            
            [notificationCenter addObserver:self selector:@selector(dismissReaderView) name:UIApplicationDidEnterBackgroundNotification object:nil];
            
			scrollViewOutset = ((userInterfaceIdiom == UIUserInterfaceIdiomPad) ? SCROLLVIEW_OUTSET_LARGE : SCROLLVIEW_OUTSET_SMALL);

//			[object updateDocumentProperties];
            [object updateObjectProperties];
            document = object; // Retain the supplied ReaderDocument object for our use

			[ReaderThumbCache touchThumbCacheWithGUID:object.guid]; // Touch the document thumb cache directory
		}
		else // Invalid ReaderDocument object
		{
			self = nil;
		}
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	assert(document != nil); // Must have a valid ReaderDocument

    self.view.backgroundColor = [UIColor whiteColor];//[UIColor grayColor]; // Neutral gray
    // （部分流程中，需要选人）初始化选择用户
    selectedUser = @"";
    _alertSelectedIndex = -1;
//    [self.navigationController setNavigationBarHidden:YES];
    
	UIView *fakeStatusBar = nil;
    CGRect viewRect = self.view.bounds; // View bounds

	if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) // iOS 7+
	{
		if ([self prefersStatusBarHidden] == NO) // Visible status bar
		{
			CGRect statusBarRect = viewRect;
            statusBarRect.size.height = STATUS_HEIGHT;
			fakeStatusBar = [[UIView alloc] initWithFrame:statusBarRect]; // UIView
			fakeStatusBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            fakeStatusBar.backgroundColor = kThemeColor;//[UIColor blackColor];
			fakeStatusBar.contentMode = UIViewContentModeRedraw;
			fakeStatusBar.userInteractionEnabled = NO;

			viewRect.origin.y    += STATUS_HEIGHT;
            viewRect.size.height -= STATUS_HEIGHT;
		}
	}

	CGRect scrollViewRect = CGRectInset(viewRect, -scrollViewOutset, 0.0f);
	theScrollView = [[UIScrollView alloc] initWithFrame:scrollViewRect]; // All
	theScrollView.autoresizesSubviews = NO; theScrollView.contentMode = UIViewContentModeRedraw;
	theScrollView.showsHorizontalScrollIndicator = NO; theScrollView.showsVerticalScrollIndicator = NO;
	theScrollView.scrollsToTop = NO; theScrollView.delaysContentTouches = NO; theScrollView.pagingEnabled = YES;
	theScrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	theScrollView.backgroundColor = [UIColor clearColor]; theScrollView.delegate = self;
	[self.view addSubview:theScrollView];

    // MainToolBar
	CGRect toolbarRect = viewRect; toolbarRect.size.height = TOOLBAR_HEIGHT;
	mainToolbar = [[ReaderMainToolbar alloc] initWithFrame:toolbarRect document:document]; // ReaderMainToolbar
    mainToolbar.autoresizesSubviews = YES;
	mainToolbar.delegate = self; // ReaderMainToolbarDelegate
    mainToolbar.backgroundColor = kThemeColor;
	[self.view addSubview:mainToolbar];
    // 签写控制，若以签写，只可以查看，不能再签；
    if (![document.fileTag isEqualToNumber:@1]) {
        mainToolbar.submitButton.enabled = NO;
        mainToolbar.annotateButton.enabled = NO;
    }else{
        mainToolbar.submitButton.enabled = YES;
        mainToolbar.annotateButton.enabled = YES;
    }
    
    // AnnotateToolBar
    annotateToolbar = [[ReaderAnnotateToolbar alloc] initWithFrame:toolbarRect]; // At top for annotating
    annotateToolbar.backgroundColor = kThemeColor;
    
    annotateToolbar.titleLabel.text = document.taskName;
    annotateToolbar.delegate = self;
    //hidden by default
    annotateToolbar.hidden = YES;
    [self.view addSubview:annotateToolbar];

    // MainPageBar
	CGRect pagebarRect = self.view.bounds; pagebarRect.size.height = PAGEBAR_HEIGHT;
	pagebarRect.origin.y = (self.view.bounds.size.height - pagebarRect.size.height);
	mainPagebar = [[ReaderMainPagebar alloc] initWithFrame:pagebarRect document:document]; // ReaderMainPagebar
	mainPagebar.delegate = self; // ReaderMainPagebarDelegate
    mainPagebar.backgroundColor = kThemeColor;
    [self.view addSubview:mainPagebar];

	if (fakeStatusBar != nil) [self.view addSubview:fakeStatusBar]; // Add status bar background view

	UITapGestureRecognizer *singleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
	singleTapOne.numberOfTouchesRequired = 1; singleTapOne.numberOfTapsRequired = 1; singleTapOne.delegate = self;
	[self.view addGestureRecognizer:singleTapOne];

	UITapGestureRecognizer *doubleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapOne.numberOfTouchesRequired = 1; doubleTapOne.numberOfTapsRequired = 2; doubleTapOne.delegate = self;
	[self.view addGestureRecognizer:doubleTapOne];

	UITapGestureRecognizer *doubleTapTwo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapTwo.numberOfTouchesRequired = 2; doubleTapTwo.numberOfTapsRequired = 2; doubleTapTwo.delegate = self;
	[self.view addGestureRecognizer:doubleTapTwo];

	[singleTapOne requireGestureRecognizerToFail:doubleTapOne]; // Single tap requires double tap to fail

    //
    self.annotationController = [[AnnotationViewController alloc] initWithDocument:document];
    self.annotationController.view.autoresizesSubviews = YES;
    self.annotationController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.annotationController.delegate = self;
    
	contentViews = [NSMutableDictionary new]; lastHideTime = [NSDate date];

	minimumPage = 1; maximumPage = [document.pageCount integerValue];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	if (CGSizeEqualToSize(lastAppearSize, CGSizeZero) == false)
	{
		if (CGSizeEqualToSize(lastAppearSize, self.view.bounds.size) == false)
		{
			[self updateContentViews:theScrollView]; // Update content views
		}

		lastAppearSize = CGSizeZero; // Reset view size tracking
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	if (CGSizeEqualToSize(theScrollView.contentSize, CGSizeZero) == true)
	{
		[self performSelector:@selector(showDocument) withObject:nil afterDelay:0.0];
	}

#if (READER_DISABLE_IDLE == TRUE) // Option

	[UIApplication sharedApplication].idleTimerDisabled = YES;

#endif // end of READER_DISABLE_IDLE Option
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];

	lastAppearSize = self.view.bounds.size; // Track view size

#if (READER_DISABLE_IDLE == TRUE) // Option

	[UIApplication sharedApplication].idleTimerDisabled = NO;

#endif // end of READER_DISABLE_IDLE Option
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (void)viewDidUnload
{
#ifdef DEBUG
	NSLog(@"%s", __FUNCTION__);
#endif

	mainToolbar = nil; mainPagebar = nil;

	theScrollView = nil; contentViews = nil; lastHideTime = nil;

	documentInteraction = nil; printInteraction = nil;

	lastAppearSize = CGSizeZero; currentPage = 0;

	[super viewDidUnload];
}

- (BOOL)prefersStatusBarHidden
{
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (userInterfaceIdiom == UIUserInterfaceIdiomPad) if (printInteraction != nil) [printInteraction dismissAnimated:NO];

	ignoreDidScroll = YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	if (CGSizeEqualToSize(theScrollView.contentSize, CGSizeZero) == false)
	{
		[self updateContentViews:theScrollView]; lastAppearSize = CGSizeZero;
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	ignoreDidScroll = NO;
}

- (void)didReceiveMemoryWarning
{
#ifdef DEBUG
	NSLog(@"%s", __FUNCTION__);
#endif

	[super didReceiveMemoryWarning];
}

#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	if (ignoreDidScroll == NO) [self layoutContentViews:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	[self handleScrollViewDidEnd:scrollView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
	[self handleScrollViewDidEnd:scrollView];
}

#pragma mark - UIGestureRecognizerDelegate methods

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch
{
	if ([touch.view isKindOfClass:[UIScrollView class]]) return YES;

	return NO;
}

#pragma mark - UIGestureRecognizer action methods

- (void)decrementPageNumber
{
	if ((maximumPage > minimumPage) && (currentPage != minimumPage))
	{
		CGPoint contentOffset = theScrollView.contentOffset; // Offset

		contentOffset.x -= theScrollView.bounds.size.width; // View X--

		[theScrollView setContentOffset:contentOffset animated:YES];
	}
}

- (void)incrementPageNumber
{
	if ((maximumPage > minimumPage) && (currentPage != maximumPage))
	{
		CGPoint contentOffset = theScrollView.contentOffset; // Offset

		contentOffset.x += theScrollView.bounds.size.width; // View X++

		[theScrollView setContentOffset:contentOffset animated:YES];
	}
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer
{
	if (recognizer.state == UIGestureRecognizerStateRecognized)
	{
		CGRect viewRect = recognizer.view.bounds; // View bounds

		CGPoint point = [recognizer locationInView:recognizer.view]; // Point

		CGRect areaRect = CGRectInset(viewRect, TAP_AREA_SIZE, 0.0f); // Area rect

		if (CGRectContainsPoint(areaRect, point) == true) // Single tap is inside area
		{
			NSNumber *key = [NSNumber numberWithInteger:currentPage]; // Page number key

			ReaderContentView *targetView = [contentViews objectForKey:key]; // View

			id target = [targetView processSingleTap:recognizer]; // Target object

			if (target != nil) // Handle the returned target object
			{
				if ([target isKindOfClass:[NSURL class]]) // Open a URL
				{
					NSURL *url = (NSURL *)target; // Cast to a NSURL object

					if (url.scheme == nil) // Handle a missing URL scheme
					{
						NSString *www = url.absoluteString; // Get URL string

						if ([www hasPrefix:@"www"] == YES) // Check for 'www' prefix
						{
							NSString *http = [[NSString alloc] initWithFormat:@"http://%@", www];

							url = [NSURL URLWithString:http]; // Proper http-based URL
						}
					}

					if ([[UIApplication sharedApplication] openURL:url] == NO)
					{
						#ifdef DEBUG
							NSLog(@"%s '%@'", __FUNCTION__, url); // Bad or unknown URL
						#endif
					}
				}
				else // Not a URL, so check for another possible object type
				{
					if ([target isKindOfClass:[NSNumber class]]) // Goto page
					{
						NSInteger number = [target integerValue]; // Number

						[self showDocumentPage:number]; // Show the page
					}
				}
			}
			else // Nothing active tapped in the target content view
			{
				if ([lastHideTime timeIntervalSinceNow] < -0.75) // Delay since hide
				{
					if ((mainToolbar.alpha < 1.0f) || (mainPagebar.alpha < 1.0f)) // Hidden
					{
						[mainToolbar showToolbar]; [mainPagebar showPagebar]; // Show
					}
				}
			}

			return;
		}

		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);

		if (CGRectContainsPoint(nextPageRect, point) == true) // page++
		{
			[self incrementPageNumber]; return;
		}

		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;

		if (CGRectContainsPoint(prevPageRect, point) == true) // page--
		{
			[self decrementPageNumber]; return;
		}
	}
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer
{
	if (recognizer.state == UIGestureRecognizerStateRecognized)
	{
		CGRect viewRect = recognizer.view.bounds; // View bounds

		CGPoint point = [recognizer locationInView:recognizer.view]; // Point

		CGRect zoomArea = CGRectInset(viewRect, TAP_AREA_SIZE, TAP_AREA_SIZE); // Area

		if (CGRectContainsPoint(zoomArea, point) == true) // Double tap is inside zoom area
		{
			NSNumber *key = [NSNumber numberWithInteger:currentPage]; // Page number key

			ReaderContentView *targetView = [contentViews objectForKey:key]; // View

			switch (recognizer.numberOfTouchesRequired) // Touches count
			{
				case 1: // One finger double tap: zoom++
				{
					[targetView zoomIncrement:recognizer]; break;
				}

				case 2: // Two finger double tap: zoom--
				{
					[targetView zoomDecrement:recognizer]; break;
				}
			}

			return;
		}

		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);

		if (CGRectContainsPoint(nextPageRect, point) == true) // page++
		{
			[self incrementPageNumber]; return;
		}

		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;

		if (CGRectContainsPoint(prevPageRect, point) == true) // page--
		{
			[self decrementPageNumber]; return;
		}
	}
}

#pragma mark - ReaderContentViewDelegate methods

- (void)contentView:(ReaderContentView *)contentView touchesBegan:(NSSet *)touches
{
	if ((mainToolbar.alpha > 0.0f) || (mainPagebar.alpha > 0.0f))
	{
		if (touches.count == 1) // Single touches only
		{
			UITouch *touch = [touches anyObject]; // Touch info

			CGPoint point = [touch locationInView:self.view]; // Touch location

			CGRect areaRect = CGRectInset(self.view.bounds, TAP_AREA_SIZE, TAP_AREA_SIZE);

			if (CGRectContainsPoint(areaRect, point) == false) return;
		}

		[mainToolbar hideToolbar]; [mainPagebar hidePagebar]; // Hide

		lastHideTime = [NSDate date]; // Set last hide time
	}
}

#pragma mark - ReaderMainToolbarDelegate methods
- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar libraryButton:(UIButton *)button
{
#if (READER_STANDALONE == FALSE) // Option
    
    dispatch_queue_t defaultQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(defaultQueue, ^{
        [document saveReaderDocumentWithAnnotations]; // Save any ReaderDocument object changes
        document.password = nil; // Clear out any document password
        
    });
    
    [[ReaderThumbQueue sharedInstance] cancelOperationsWithGUID:document.guid];
    
    //[[ReaderThumbCache sharedInstance] removeAllObjects]; // Empty the thumb cache
    
    if ([delegate respondsToSelector:@selector(dismissReaderViewController:withDocument:withTag:)] == YES)
    {
        [delegate dismissReaderViewController:self withDocument:document withTag:@0]; // Dismiss the ReaderViewController
//        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    else // We have a "Delegate must respond to -dismissReaderViewController: error"
    {
        NSAssert(NO, @"Delegate must respond to -dismissReaderViewController:");
    }
    
    
#endif // end of READER_STANDALONE Option
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar doneButton:(UIButton *)button
{
#if (READER_STANDALONE == FALSE) // Option

	[self closeDocument]; // Close ReaderViewController

#endif // end of READER_STANDALONE Option
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar thumbsButton:(UIButton *)button
{
#if (READER_ENABLE_THUMBS == TRUE) // Option

	if (printInteraction != nil) [printInteraction dismissAnimated:NO];

	ThumbsViewController *thumbsViewController = [[ThumbsViewController alloc] initWithReaderDocument:document];

	thumbsViewController.title = [document.fileName stringByDeletingPathExtension];
    thumbsViewController.delegate = self; // ThumbsViewControllerDelegate

	thumbsViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	thumbsViewController.modalPresentationStyle = UIModalPresentationFullScreen;

//	[self presentViewController:thumbsViewController animated:NO completion:NULL];
    [self presentViewController:thumbsViewController animated:NO completion:^{
        [thumbsViewController refreshThumbsView];
    }];

#endif // end of READER_ENABLE_THUMBS Option
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar exportButton:(UIButton *)button
{
	if (printInteraction != nil) [printInteraction dismissAnimated:YES];

	NSURL *fileURL = [NSURL fileURLWithPath:document.fileURL]; // Document file URL

	documentInteraction = [UIDocumentInteractionController interactionControllerWithURL:fileURL];

	documentInteraction.delegate = self; // UIDocumentInteractionControllerDelegate

	[documentInteraction presentOpenInMenuFromRect:button.bounds inView:button animated:YES];
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar printButton:(UIButton *)button
{
	if ([UIPrintInteractionController isPrintingAvailable] == YES)
	{
		NSURL *fileURL = [NSURL fileURLWithPath:document.fileURL]; // Document file URL

		if ([UIPrintInteractionController canPrintURL:fileURL] == YES)
		{
			printInteraction = [UIPrintInteractionController sharedPrintController];

			UIPrintInfo *printInfo = [UIPrintInfo printInfo];
			printInfo.duplex = UIPrintInfoDuplexLongEdge;
			printInfo.outputType = UIPrintInfoOutputGeneral;
			printInfo.jobName = document.fileName;

			printInteraction.printInfo = printInfo;
			printInteraction.printingItem = fileURL;
			printInteraction.showsPageRange = YES;

			if (userInterfaceIdiom == UIUserInterfaceIdiomPad) // Large device printing
			{
				[printInteraction presentFromRect:button.bounds inView:button animated:YES completionHandler:
					^(UIPrintInteractionController *pic, BOOL completed, NSError *error)
					{
						#ifdef DEBUG
							if ((completed == NO) && (error != nil)) NSLog(@"%s %@", __FUNCTION__, error);
						#endif
					}
				];
			}
			else // Handle printing on small device
			{
				[printInteraction presentAnimated:YES completionHandler:
					^(UIPrintInteractionController *pic, BOOL completed, NSError *error)
					{
						#ifdef DEBUG
							if ((completed == NO) && (error != nil)) NSLog(@"%s %@", __FUNCTION__, error);
						#endif
					}
				];
			}
		}
	}
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar emailButton:(UIButton *)button
{
	if ([MFMailComposeViewController canSendMail] == NO) return;

	if (printInteraction != nil) [printInteraction dismissAnimated:YES];

	unsigned long long fileSize = [document.fileSize unsignedLongLongValue];

	if (fileSize < 15728640ull) // Check attachment size limit (15MB)
	{
		NSURL *fileURL = [NSURL fileURLWithPath:document.fileURL];
        NSString *fileName = document.fileName;

		NSData *attachment = [NSData dataWithContentsOfURL:fileURL options:(NSDataReadingMapped|NSDataReadingUncached) error:nil];

		if (attachment != nil) // Ensure that we have valid document file attachment data available
		{
			MFMailComposeViewController *mailComposer = [MFMailComposeViewController new];

			[mailComposer addAttachmentData:attachment mimeType:@"application/pdf" fileName:fileName];

			[mailComposer setSubject:fileName]; // Use the document file name for the subject

			mailComposer.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
			mailComposer.modalPresentationStyle = UIModalPresentationFormSheet;

			mailComposer.mailComposeDelegate = self; // MFMailComposeViewControllerDelegate

			[self presentViewController:mailComposer animated:YES completion:NULL];
		}
	}
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar markButton:(UIButton *)button
{
#if (READER_BOOKMARKS == TRUE) // Option

	if (printInteraction != nil) [printInteraction dismissAnimated:YES];

	if ([document.bookmarks containsIndex:currentPage]) // Remove bookmark
	{
		[document.bookmarks removeIndex:currentPage]; [mainToolbar setBookmarkState:NO];
	}
	else // Add the bookmarked page number to the bookmark index set
	{
		[document.bookmarks addIndex:currentPage]; [mainToolbar setBookmarkState:YES];
	}

#endif // end of READER_BOOKMARKS Option
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar submitButton:(UIButton *)button
{
    [self nextTaskSelect];
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar annotateButton:(UIButton *)button
{
//    [self setAnnotationMode:AnnotationViewControllerType_EPen];
    [self setAnnotationMode:AnnotationViewControllerType_None];
    [self startAnnotation];
}

#pragma mark ReaderAnnotateToolbarDelegate methods


- (void) setAnnotationMode:(NSString*)mode {
    [annotateToolbar setSignButtonState:NO];
    [annotateToolbar setRedPenButtonState:NO];
    [annotateToolbar setTextButtonState:NO];
    [annotateToolbar setEraseButtonState:NO];
    [annotateToolbar setESignButtonState:NO];
    [annotateToolbar setEPenButtonState:NO];
    
    if ([mode isEqualToString:AnnotationViewControllerType_Sign]) {
        [annotateToolbar setSignButtonState:YES];
    } else if ([mode isEqualToString:AnnotationViewControllerType_RedPen]) {
        [annotateToolbar setRedPenButtonState:YES];
    } else if ([mode isEqualToString:AnnotationViewControllerType_Erase]) {
        [annotateToolbar setEraseButtonState:YES];
    } else if ([mode isEqualToString:AnnotationViewControllerType_Text]) {
        [annotateToolbar setTextButtonState:YES];
    } else if ([mode isEqualToString:AnnotationViewControllerType_ESign]) {
        [annotateToolbar setESignButtonState:YES];
    } else if ([mode isEqualToString:AnnotationViewControllerType_EPen]) {
        [annotateToolbar setEPenButtonState:YES];
    }
    self.annotationController.annotationType = mode;
}

- (void)tappedInAnnotateToolbar:(ReaderAnnotateToolbar *)toolbar signButton:(UIButton *)button
{
    if ([self.annotationController.annotationType isEqualToString:AnnotationViewControllerType_Sign]) {
        [self setAnnotationMode:AnnotationViewControllerType_None];
    } else {
        [self movePage];
        [self setAnnotationMode:AnnotationViewControllerType_Sign];
    }
}

- (void)tappedInAnnotateToolbar:(ReaderAnnotateToolbar *)toolbar redPenButton:(UIButton *)button
{
    if ([self.annotationController.annotationType isEqualToString:AnnotationViewControllerType_RedPen]) {
        [self setAnnotationMode:AnnotationViewControllerType_None];
    } else {
        [self movePage];
        [self setAnnotationMode:AnnotationViewControllerType_RedPen];
    }
}

- (void)tappedInAnnotateToolbar:(ReaderAnnotateToolbar *)toolbar eraseButton:(UIButton *)button
{
    if ([self.annotationController.annotationType isEqualToString:AnnotationViewControllerType_Erase]) {
        [self setAnnotationMode:AnnotationViewControllerType_None];
    } else {
        [self movePage];
        [self setAnnotationMode:AnnotationViewControllerType_Erase];
    }
}

- (void)tappedInAnnotateToolbar:(ReaderAnnotateToolbar *)toolbar textButton:(UIButton *)button
{
    if ([self.annotationController.annotationType isEqualToString:AnnotationViewControllerType_Text]) {
        [self setAnnotationMode:AnnotationViewControllerType_None];
    } else {
        [self movePage];
        [self setAnnotationMode:AnnotationViewControllerType_Text];
    }
}

- (void)tappedInAnnotateToolbar:(ReaderAnnotateToolbar *)toolbar ePenButton:(UIButton *)button
{
    if ([self.annotationController.annotationType isEqualToString:AnnotationViewControllerType_EPen]) {
        [self setAnnotationMode:AnnotationViewControllerType_None];
    } else {
        [self movePage];
        [self setAnnotationMode:AnnotationViewControllerType_EPen];
    }
}

- (void)tappedInAnnotateToolbar:(ReaderAnnotateToolbar *)toolbar eSignButton:(UIButton *)button
{
    if ([self.annotationController.annotationType isEqualToString:AnnotationViewControllerType_ESign]) {
        [self setAnnotationMode:AnnotationViewControllerType_None];
    } else {
//        [self startAnnotation];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *base64Img = [userDefaults objectForKey:kESignImage];
        if (!base64Img||[base64Img length]==0) {
            [self showAlertTitle:@"电子签名未录入" message:@"通知相关人员录入或放大使用画笔签名"];
        }else{
            [self setAnnotationMode:AnnotationViewControllerType_ESign];
        }
    }
}

- (void) tappedInAnnotateToolbar:(ReaderAnnotateToolbar *)toolbar cancelButton:(UIButton *)button {
    [self cancelAnnotation];
    document.password = nil; // Clear out any document password
    [[ReaderThumbQueue sharedInstance] cancelOperationsWithGUID:document.guid];
    [self.view endEditing:YES];
}

- (void) tappedInAnnotateToolbar:(ReaderAnnotateToolbar *)toolbar doneButton:(UIButton *)button {
    // 添加网络指示器
    [self finishAnnotation];
    
    [[ReaderThumbQueue sharedInstance] cancelOperationsWithGUID:document.guid];
    [document saveReaderDocumentWithAnnotations]; // Save any ReaderDocument object changes
    document.password = nil; // Clear out any document password
}

- (void)tappedInAnnotateToolbar:(ReaderAnnotateToolbar *)toolbar undoButton:(UIButton *)button {
    // 撤销一步
    [self.annotationController undo];
    // 重签（撤销全部当前签写的内容）
    //    [self.annotationController clear];
}

#pragma mark Annotation Flow

- (void) startAnnotation {
    [annotateToolbar showToolbar];
    [mainToolbar hideToolbar];
    
    ReaderContentView *view = [contentViews objectForKey:document.pageNumber];
    [self.annotationController moveToPage:[document.pageNumber intValue] contentView:view];
    
    [self.view insertSubview:self.annotationController.view belowSubview:annotateToolbar];
}

- (void) movePage {
    ReaderContentView *view = [contentViews objectForKey:document.pageNumber];
    if ([self.annotationController moveToPage:[document.pageNumber intValue] contentView:view]) {
        [self.view insertSubview:self.annotationController.view belowSubview:annotateToolbar];
    }
}

- (void) cancelAnnotation {
    [annotateToolbar hideToolbar];
    [mainToolbar showToolbar];
    
    [self.annotationController clear];
    [self.annotationController hide];
}

- (void) finishAnnotation {
    [annotateToolbar hideToolbar];
    [mainToolbar showToolbar];
    
    AnnotationStore *annotations = [self.annotationController annotations];
    [document.annotations addAnnotations:annotations];
    [self saveAnotationImageForPage:(int)currentPage];
    
    ReaderContentView *view = [contentViews objectForKey:document.pageNumber];
//    [[view contentView] setNeedsDisplay];
    [(UIView *)view.theContentPage setNeedsDisplay];
    
    [self.annotationController clear];
    [self.annotationController hide];
}

- (void)saveAnotationImageForPage:(int)pageNumber
{
    if ([[document.annotations annotationsForPage:pageNumber] count] > 0) {
        UIImage *annotationImage = [self.annotationController getImageFromAnnotationsWithPage:pageNumber];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = [paths objectAtIndex:0]; //Get the docs directory
        //    NSString *signPngName = [NSString stringWithFormat:@"%@sign%@.png",[document.fileName stringByDeletingPathExtension],key];
//        NSDictionary *taskInfoDic = [NSJSONSerialization JSONObjectWithData:document.taskInfo options:NSJSONReadingMutableLeaves error:nil];
        NSString *signPngName = [NSString stringWithFormat:@"%@.png",document.fileId];
        NSString *filePath = [documentsPath stringByAppendingPathComponent:signPngName]; //Add the file name
        UIImage *lastImage = [UIImage imageWithContentsOfFile:filePath];
        if (lastImage) {
            UIImageView *lastImageView = [[UIImageView alloc] initWithImage:lastImage];
            CGSize size = CGSizeMake(lastImageView.frame.size.width, lastImageView.frame.size.height);
            UIGraphicsBeginImageContext(size);
            
            [lastImage drawInRect:lastImageView.bounds];
            [annotationImage drawInRect:lastImageView.bounds];
            annotationImage = UIGraphicsGetImageFromCurrentImageContext();
            
            UIGraphicsEndImageContext();
        }
        
        NSData *pngData = UIImagePNGRepresentation(annotationImage);
        [pngData writeToFile:filePath atomically:YES]; //Write the file
    }
}

- (void)handleAnnotationModeNotification:(NSNotification *)notification
{
    if ([notification.name isEqualToString:DocumentsSetAnnotationModeSignNotification]) {
        [self startAnnotation];
        [self setAnnotationMode:AnnotationViewControllerType_Sign];
    }
    if ([notification.name isEqualToString:DocumentsSetAnnotationModeRedPenNotification]) {
        [self startAnnotation];
        [self setAnnotationMode:AnnotationViewControllerType_RedPen];
    }
    if ([notification.name isEqualToString:DocumentsSetAnnotationModeOffNotification]) {
        [self cancelAnnotation];
        [self setAnnotationMode:AnnotationViewControllerType_None];
    }
    if ([notification.name isEqualToString:DocumentsSetAnnotationModeEsignNotification]) {
        [self startAnnotation];
        [self setAnnotationMode:AnnotationViewControllerType_ESign];
    }
    if ([notification.name isEqualToString:DocumentsSetAnnotationModeTextNotification]) {
        [self startAnnotation];
        [self setAnnotationMode:AnnotationViewControllerType_Text];
    }
    if ([notification.name isEqualToString:DocumentsSetAnnotationModeEPenNotification]) {
        [self startAnnotation];
        [self setAnnotationMode:AnnotationViewControllerType_EPen];
    }
}

#pragma mark - MFMailComposeViewControllerDelegate methods

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
#ifdef DEBUG
	if ((result == MFMailComposeResultFailed) && (error != NULL)) NSLog(@"%@", error);
#endif

	[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UIDocumentInteractionControllerDelegate methods

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
	documentInteraction = nil;
}

#pragma mark - ThumbsViewControllerDelegate methods

- (void)thumbsViewController:(ThumbsViewController *)viewController gotoPage:(NSInteger)page
{
#if (READER_ENABLE_THUMBS == TRUE) // Option

	[self showDocumentPage:page];

#endif // end of READER_ENABLE_THUMBS Option
}

- (void)updateToolbarBookmarkIcon
{
    NSInteger page = [document.pageNumber integerValue];
    
    BOOL bookmarked = [document.bookmarks containsIndex:page];
    
    [mainToolbar setBookmarkState:bookmarked]; // Update
}

- (void)dismissThumbsViewController:(ThumbsViewController *)viewController
{
#if (READER_ENABLE_THUMBS == TRUE) // Option
    [self updateToolbarBookmarkIcon];
	[self dismissViewControllerAnimated:NO completion:NULL];

#endif // end of READER_ENABLE_THUMBS Option
}

#pragma mark - ReaderMainPagebarDelegate methods

- (void)pagebar:(ReaderMainPagebar *)pagebar gotoPage:(NSInteger)page
{
	[self showDocumentPage:page];
}

#pragma mark - UIApplication notification methods

- (void)applicationWillResign:(NSNotification *)notification
{
//	[document archiveDocumentProperties]; // Save any ReaderDocument changes
    [document saveReaderDocument];
    
	if (userInterfaceIdiom == UIUserInterfaceIdiomPad)
        if (printInteraction != nil)
            [printInteraction dismissAnimated:NO];
}

#pragma mark -  UIApplicationDidEnterBackgroundNotification
- (void)dismissReaderView
{
    // 退出文档
    [delegate dismissReaderViewController:self withDocument:document withTag:@2]; // Dismiss the ReaderViewController
//    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark UIAlertViewDelegate methods
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0://取消
            break;
        default:
        {
            NSDictionary *taskInfoDic = [NSJSONSerialization JSONObjectWithData:document.taskInfo options:NSJSONReadingMutableLeaves error:nil];
            NSArray *taskArray = [taskInfoDic objectForKey:@"taskOperate"];
            NSString *taskValue = [taskArray[buttonIndex-1] objectForKey:@"value"];
            
            //[[taskInfoDic objectForKey:@"isPadSelectUser"] isEqualToString:@"yes"]
            if ([taskValue isEqualToString:@"CouSign"]) {
                _alertSelectedIndex = buttonIndex;
                [self showUserListPopover];
            }else{
                [self continueTaskWithSelectIndex:buttonIndex];
            }
        }
            break;
    }
}

#pragma mark - nextTaskSelect
- (void)nextTaskSelect
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"完成批示（批阅）"message:@"文件下一步" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:nil];
    
    NSDictionary *taskInfoDic = [NSJSONSerialization JSONObjectWithData:document.taskInfo options:NSJSONReadingMutableLeaves error:nil];
    NSArray *taskOperation = [taskInfoDic objectForKey:@"taskOperate"];
    for (NSDictionary *nextTaskInfo in taskOperation) {
        [alertView addButtonWithTitle:[nextTaskInfo objectForKey:@"text"]];
    }
    [alertView show];
}

#pragma mark - UIAlertView with timer
- (void)timerFireMethod:(NSTimer*)theTimer
{
    UIAlertView *promptAlert = (UIAlertView *)[theTimer userInfo];
    [promptAlert dismissWithClickedButtonIndex:0 animated:NO];
    promptAlert = NULL;
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)message
{
    UIAlertView *promptAlert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [NSTimer scheduledTimerWithTimeInterval:2.5f
                                     target:self
                                   selector:@selector(timerFireMethod:)
                                   userInfo:promptAlert
                                    repeats:YES];
    [promptAlert show];
}

#pragma mark - TextKeyboardNotificationDelegate
- (void)keyboardWillShow:(CGFloat )offset
{
    [UIView animateWithDuration:0.3 animations:^{
        
        CGRect newAnnoFrame = self.annotationController.view.frame;
        newAnnoFrame.origin.y = newAnnoFrame.origin.y - offset;
        self.annotationController.view.frame = newAnnoFrame;
        
        CGRect newStrollFrame = theScrollView.frame;
        newStrollFrame.origin.y = newStrollFrame.origin.y - offset;
        theScrollView.frame = newStrollFrame;
        
        CGRect newPageBarFrame = mainPagebar.frame;
        newPageBarFrame.origin.y = newPageBarFrame.origin.y - offset;
        mainPagebar.frame = newPageBarFrame;
    }];
}

- (void)keyboardDidHidden:(CGFloat )offset
{
    [UIView animateWithDuration:0.2 animations:^{
        
        CGRect newAnnoFrame = self.annotationController.view.frame;
        newAnnoFrame.origin.y = newAnnoFrame.origin.y + offset;
        self.annotationController.view.frame = newAnnoFrame;
        
        CGRect newStrollFrame = theScrollView.frame;
        newStrollFrame.origin.y = newStrollFrame.origin.y + offset;
        theScrollView.frame = newStrollFrame;
        
        CGRect newPageBarFrame = mainPagebar.frame;
        newPageBarFrame.origin.y = newPageBarFrame.origin.y + offset;
        mainPagebar.frame = newPageBarFrame;
    }];
}

#pragma mark - showUsers
- (void)showUserListPopover
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *plistPath = [userDefaults objectForKey:kUserPlist];
    NSMutableArray *docPlist = [[NSMutableArray alloc] initWithContentsOfFile:plistPath];
    if ([docPlist count] == 0) {
        [OATools getAllUserToPlist];
    }
    if ([docPlist count]>0) {
        OAUserListVC *userList = [[OAUserListVC alloc] init];
        userList.delegate = self;
        
        UINavigationController *OANavC = [[UINavigationController alloc] initWithRootViewController:userList];
        _popover = [[UIPopoverController alloc] initWithContentViewController:OANavC];
        _popover.popoverContentSize = CGSizeMake(320, 480);
        _popover.delegate = self;
        [self showPopover];
        
        // 监听屏幕旋转的通知
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenRotate) name:UIDeviceOrientationDidChangeNotification object:nil];
    }else{
        NSString *info = [NSString stringWithFormat:@"Error:用户组人员获取失败,重试."];
        [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
        [self showAlertTitle:@"用户组人员获取失败" message:@"再试一次"];
    }
}

- (void)screenRotate
{
    if (_popover.popoverVisible) {
        // 1.关闭之前的
        [_popover dismissPopoverAnimated:NO];
        
        // 2.0.5秒后创建新的
        [self performSelector:@selector(showPopover) withObject:nil afterDelay:0.5];
    }
}

#pragma mark -显示popover
- (void)showPopover
{
    [_popover presentPopoverFromRect:mainToolbar.submitButton.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    // popover被销毁的时候，移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

#pragma mark - UserListSelectedDelegate
- (void)selectUser:(NSString *)userName
{
    selectedUser = userName;
    [self continueTaskWithSelectIndex:_alertSelectedIndex];
    if (_alertSelectedIndex >= 0) {
        _alertSelectedIndex = -1;
    }
    selectedUser = @"";
}

- (void)continueTaskWithSelectIndex:(NSInteger )btnIndex
{
    NSDictionary *taskInfoDic   = [NSJSONSerialization JSONObjectWithData:document.taskInfo options:NSJSONReadingMutableLeaves error:nil];
    NSArray *taskArray          = [taskInfoDic objectForKey:@"taskOperate"];
    NSString *taskValue         = [taskArray[btnIndex-1] objectForKey:@"value"];
    
    // Sign png的文件路径filePath
    NSString *cacheDirectory    = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *signPngName       = [NSString stringWithFormat:@"%@.png",document.fileId];
    NSString *filePath          = [cacheDirectory stringByAppendingPathComponent:signPngName];
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:filePath]) {
        [self uploadPNG:taskValue path:filePath];
    }else{
        [self finishCurrentTask:taskValue];
    }
}

#pragma mark - Network
- (BOOL)reachToNetwork:(NSURL *)baseURL
{
    __block BOOL reach = YES;
    AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseURL];
    NSOperationQueue *operationQueue = manager.operationQueue;
    //    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        //        NSLog(@"Reachability: %@", AFStringFromNetworkReachabilityStatus(status));
        switch (status) {
            case AFNetworkReachabilityStatusReachableViaWWAN:
            case AFNetworkReachabilityStatusReachableViaWiFi:
                [operationQueue setSuspended:NO];
                reach = YES;
                break;
            case AFNetworkReachabilityStatusNotReachable:
            default:
                [operationQueue setSuspended:YES];
                reach = NO;
                break;
        }
    }];
    return reach;
}

#pragma mark - Upload Sign Png

- (void)uploadPNG:(NSString *)taskValue path:(NSString *)filePath
{
    // 网络状态良好，再上传
    if ([self reachToNetwork:[NSURL URLWithString:kBaseURL]]) {
        //    NSString *signPngName = [NSString stringWithFormat:@"%@sign%@.png",[document.fileName stringByDeletingPathExtension],@"1"];
        NSDictionary *taskInfoDic = [NSJSONSerialization JSONObjectWithData:document.taskInfo options:NSJSONReadingMutableLeaves error:nil];
        NSString *signPngName = [NSString stringWithFormat:@"%@.png",document.fileId];
        NSData *image = UIImagePNGRepresentation([UIImage imageWithContentsOfFile:filePath]);
        NSString *taskId        = [taskInfoDic objectForKey:@"id"];
        NSString *instanceId    = [taskInfoDic objectForKey:@"processInstanceId"];
        NSString *missiveType   = [taskInfoDic objectForKey:@"missiveType"];
        NSString *processDeID   = [taskInfoDic objectForKey:@"processDefinitionId"];
        NSString *missiveVersion= [taskInfoDic objectForKey:@"missiveVersion"];
        NSString *serverURL     = [NSString stringWithFormat:@"%@upload/img/%@/%@/%@/%@/%@",kBaseURL,missiveType,processDeID,instanceId,missiveVersion,taskId];
        
        [MBProgressHUD showHUDAddedTo:self.view bgColor:kThemeColor tintColor:[UIColor whiteColor] labelText:@"提交中..." animated:YES];
        
        // 本地上传给服务器时,没有确定的URL,不好用MD5的方式处理
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        [manager.requestSerializer setValue:[[NSUserDefaults standardUserDefaults] objectForKey:kAuthorizationHeader] forHTTPHeaderField:@"Authorization"];
        [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"content-type"];
        [manager POST:serverURL parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            [formData appendPartWithFileData:image name:@"files" fileName:signPngName mimeType:@"image/png"];
            
        } success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSString *result = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            NSString *info = [NSString stringWithFormat:@"OK:图片上传成功.%@",result];
            [OATools newLogWithInfo:info time:[NSDate date] type:kLogInfoType];
            
            // 上传签写PNG OK后，结束本文件Task
            [self finishCurrentTask:taskValue];
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            
            NSLog(@"Upload error:%@",error);
            NSString *info = [NSString stringWithFormat:@"Error:图片上传失败，.%@",error.description];
            [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
            
            [self showAlertTitle:@"提醒：" message:@"签发失败，请重新点击“签发”！"];
        }];
    }else{
        NSString *info = [NSString stringWithFormat:@"Error:网络中断,上传签写图片失败."];
        [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
        
        [self showAlertTitle:@"服务器" message:@"连接中断，请检查网络！"];
    }
}

- (void)finishCurrentTask:(NSString *)taskValue
{
    NSDictionary *taskInfoDic = [NSJSONSerialization JSONObjectWithData:document.taskInfo options:NSJSONReadingMutableLeaves error:nil];
    NSString *taskId = [taskInfoDic objectForKey:@"id"];
    NSString *instanceId = [taskInfoDic objectForKey:@"processInstanceId"];
    NSString *definitionId = [taskInfoDic objectForKey:@"processDefinitionId"];
    
    NSString *finishURL = [NSString stringWithFormat:@"%@api/ipad/commitTask/%@/%@/%@?instanceId=%@&taskId=%@",kBaseURL,definitionId,instanceId,taskId,instanceId,taskId];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
    manager.requestSerializer  = [AFHTTPRequestSerializer serializer];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    // 设置网络参数：taskValue
    NSMutableDictionary *para = [NSMutableDictionary dictionary];
    [para setObject:taskValue forKey:@"taskValue"];
    [para setObject:[taskInfoDic objectForKey:@"missiveType"] forKey:@"missiveType"];
    [para setObject:selectedUser forKey:@"userName"];
    
    [MBProgressHUD hideAllHUDsForView:self.view animated:NO];
    [MBProgressHUD showHUDAddedTo:self.view bgColor:kThemeColor tintColor:[UIColor whiteColor] labelText:@"签发中..." animated:YES];
    
    // 在状态栏显示有网络请求的提示器
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    // 网络访问是异步的,回调是主线程的,因此程序员不用管在主线程更新UI的事情
    [manager POST:finishURL parameters:para success:^(AFHTTPRequestOperation *operation, id responseObject) {
        // 关闭网络指示器
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        // 在状态栏显示有网络请求的提示器
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        if ([responseObject length] < 3) {
            NSString *messageOK = [NSString stringWithFormat:@"公文：%@",document.fileName];
            [self showAlertTitle:@"签发成功" message:messageOK];
            
            // 阅办成功，标示改为2
            document.fileTag = @2;
            document.thumbImage = UIImagePNGRepresentation([self imageFromPDFWithDocumentRef:document.fileURL]);
            
            // 日志记录
            NSString *info = [NSString stringWithFormat:@"OK:签发文件-%@-成功.",document.fileName];
            [OATools newLogWithInfo:info time:[NSDate date] type:kLogInfoType];
            
            // 签发成功，退出文档
            [delegate dismissReaderViewController:self withDocument:document withTag:@1]; // Dismiss the ReaderViewController
//            [self.navigationController popToRootViewControllerAnimated:YES];
        }else
        {
            // 日志记录
            NSString *info = [NSString stringWithFormat:@"Error:签发文件-%@-失败.%@",document.fileName,responseObject];
            [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
            
            [self showAlertTitle:@"签发失败" message:@"web程序异常"];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        // 关闭网络指示器
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        // 在状态栏显示有网络请求的提示器
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        
        NSLog(@"%@", error.description);
        
        NSString *info = [NSString stringWithFormat:@"Error:签发文件-%@-失败.%@",document.fileName,error.description];
        [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
        // AlertView 失败提示
        NSString *message = [[error userInfo] objectForKey:@"NSLocalizedDescription"];
        [self showAlertTitle:@"签发失败" message:message];
    }];
}

#pragma mark - PDF thumbView
// Get pdf thumb view
- (UIImage *)imageFromPDFWithDocumentRef:(NSString *)fileURL {
    NSURL *url = [NSURL fileURLWithPath:fileURL];
    CFURLRef docURLRef = (__bridge CFURLRef)url; // File URL
    CGPDFDocumentRef documentRef = CGPDFDocumentCreateWithURL(docURLRef);
    
    CGPDFPageRef pageRef = CGPDFDocumentGetPage(documentRef, 1);
    CGRect pageRect = CGPDFPageGetBoxRect(pageRef, kCGPDFCropBox);
    
    UIGraphicsBeginImageContextWithOptions(pageRect.size, NO, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);// White
    CGContextFillRect(context, CGContextGetClipBoundingBox(context)); // Fill
    
    CGContextTranslateCTM(context, CGRectGetMinX(pageRect),CGRectGetMaxY(pageRect));
    CGContextScaleCTM(context, 1.0f, -1.0f);
    
    CGContextTranslateCTM(context, -(pageRect.origin.x), -(pageRect.origin.y));
    CGContextDrawPDFPage(context, pageRef);
    
    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGPDFDocumentRelease(documentRef);
    
//  CGFloat height = kOAPDFCellHeight - 40;
//  CGFloat width = (pageRect.size.width/pageRect.size.height) * height;
//  finalImage = [self OriginImage:finalImage scaleToSize:CGSizeMake(width * 2, height * 2)];//*2 两倍清晰度
    return finalImage;
}

@end
