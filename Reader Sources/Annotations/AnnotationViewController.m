//
//  AnnotationViewController.m
//	ThatPDF v0.3.1
//
//	Created by Brett van Zuiden.
//	Copyright © 2013 Ink. All rights reserved.
//

#import "AnnotationViewController.h"
#import "drawingView.h"

NSString *const AnnotationViewControllerType_None   = @"None";
NSString *const AnnotationViewControllerType_Sign   = @"Sign";
NSString *const AnnotationViewControllerType_RedPen = @"RedPen";
NSString *const AnnotationViewControllerType_Erase  = @"Erase";
NSString *const AnnotationViewControllerType_Text   = @"Text";
NSString *const AnnotationViewControllerType_ESign  = @"ESign";
NSString *const AnnotationViewControllerType_EPen   = @"EPen";

int const ANNOTATION_IMAGE_TAG = 431;
CGFloat const TEXT_FIELD_WIDTH = 200;
CGFloat const TEXT_FIELD_HEIGHT= 30;
CGFloat const RED_LINE_WIDTH   = 2.0;
CGFloat const BLACK_LINE_WIDTH = 1.0;
CGFloat const ERASE_LINE_WIDTH = 50.0;

@interface AnnotationViewController () <UITextViewDelegate>

@end

@implementation AnnotationViewController {
    CGPoint lastPoint;
    CGPoint currentPoint;
    
    UIImageView *imageView;
    NSMutableArray *imageArray;
    UIView *pageView;
    CGColorRef annotationColor;
    CGColorRef signColor;
    CGColorRef eraseColor;
    
    NSString *_annotationType;
    AnnotationStore *annotationStore;
    
    //We need both because of the UIBezierPath nonsense
    NSMutableArray *currentPaths;
    CGMutablePathRef currPath;
    CGMutablePathRef basePath;
    
    BOOL didMove;
    CGPoint lastContactPoint1, lastContactPoint2;
    
    UITextField *textField;
    UIView *eraseView;
    UITextView *_textView;
    UIImage *_userEsign;
    UIImageView *_eSignImage;
    drawingView *_pageDrawingView;
    
    BOOL keyBoardOffset;
}
@synthesize image;
@synthesize imageArray;
@synthesize imageDictionary;
@dynamic annotationType;
@synthesize delegate;

- (id) initWithDocument:(ReaderDocument *)readerDocument
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.annotationType = AnnotationViewControllerType_None;
        self.document       = readerDocument;
        
        annotationColor = [UIColor redColor].CGColor;
        signColor       = [UIColor blackColor].CGColor;
        eraseColor      = [UIColor clearColor].CGColor;
        
        self.currentPage= 0;
        imageView       = [[UIImageView alloc] initWithImage:nil];
        imageView.frame = CGRectMake(0,0,100,100); //so we don't error out
        currentPaths    = [NSMutableArray array];
        
        annotationStore = [[AnnotationStore alloc] initWithPageCount:[readerDocument.pageCount intValue]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.userInteractionEnabled = ![self.annotationType isEqualToString:AnnotationViewControllerType_None];
    self.view.opaque = NO;
    self.view.backgroundColor = [UIColor clearColor];
    // 初始化用户的签名图片
    [self initEsignImage];
    
    imageArray = [NSMutableArray array];
    imageDictionary = [NSMutableDictionary dictionary];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observerKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observerKeyboardWasHidden:) name:UIKeyboardDidHideNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)initEsignImage{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *base64Img = [userDefaults objectForKey:kESignImage];
    
    if(base64Img.length > 0){
        NSData *signData = [[NSData alloc] initWithBase64EncodedString:base64Img options:0];
        _userEsign = [UIImage imageWithData:signData];
    }else{
        _userEsign = nil;
    }
}

- (UIImageView*) createImageView {
    UIImageView *temp = [[UIImageView alloc] initWithImage:nil];
    temp.frame = pageView.frame;
    temp.tag = ANNOTATION_IMAGE_TAG;
    return temp;
}

- (UITextField*) createTextField {
    UITextField *temp = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, TEXT_FIELD_WIDTH, TEXT_FIELD_HEIGHT)];
    temp.font = [UIFont systemFontOfSize:10.0f];
    temp.hidden = YES;
    temp.backgroundColor = [UIColor clearColor];
    temp.borderStyle = UITextBorderStyleLine;
    
    return temp;
}

- (UITextView *) createTextView {
    UITextView *temp = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, TEXT_FIELD_WIDTH, 30)];
    temp.textColor = [UIColor blackColor];//设置textview里面的字体颜色
    temp.font = [UIFont systemFontOfSize:10.0];//设置字体名字和字体大小
    temp.backgroundColor = [UIColor clearColor];//设置它的背景颜色
    temp.returnKeyType = UIReturnKeyDefault;//返回键的类型
//    temp.keyboardType = UIKeyboardTypeDefault;//键盘类型
    temp.scrollEnabled = NO;//是否可以拖动
    temp.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    temp.hidden = YES;
    temp.delegate = self;
    return temp;
}

- (UIView *) createEraseView{
    UIView *temp = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ERASE_LINE_WIDTH, ERASE_LINE_WIDTH)];
    temp.backgroundColor = [UIColor clearColor];
    temp.hidden = YES;
    temp.layer.borderColor = [[UIColor blackColor] CGColor];
    temp.layer.cornerRadius = ERASE_LINE_WIDTH * 0.5;
    temp.layer.borderWidth = 0.0;
    return temp;
}

- (UIImageView *)createESignImageView{
//    UIImageView *eSignImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sqheSign.png"]];
    if (_userEsign) {
        UIImageView *eSignImageView = [[UIImageView alloc] initWithImage:_userEsign];
        CGRect newFrame = eSignImageView.frame;
        newFrame.size.height = 35;
        newFrame.size.width = newFrame.size.height * eSignImageView.frame.size.width / eSignImageView.frame.size.height;
        eSignImageView.frame = newFrame;
        
        eSignImageView.contentMode = UIViewContentModeScaleAspectFit;
        eSignImageView.hidden = YES;
        
        return eSignImageView;
    }else{
        return nil;
    }
}

- (drawingView *)createPageDrawingView{
    drawingView *drawView = [[drawingView alloc] initWithFrame:pageView.frame];
    return drawView;
}

- (void) moveToPage:(int)page contentView:(ReaderContentView*) view {
    if (page != self.currentPage || !pageView) {
        [self finishCurrentAnnotation];
        
        self.currentPage = page;
//        pageView = [view contentView];
        pageView = (UIView *)view.theContentPage;
//        NSLog(@"%@,%@",NSStringFromCGRect(self.view.frame),NSStringFromCGRect(pageView.frame));
        
        //Create a new one because the old one may be deallocated or have a deallocated parent
        //First, erase any contents though
//        if (imageView.superview != nil) {
//            imageView.image = nil;
//        }
//        if (textField.superview != nil) {
//            textField.hidden = YES;
//        }
//        if (_textView.superview != nil) {
//            _textView.hidden = YES;
//        }
//        if (_eSignImage.superview != nil) {
//            _eSignImage.hidden = YES;
//        }
//        if (_pageDrawingView.subviews != nil) {
//            _pageDrawingView.hidden = YES;
//        }
        imageView = nil;
        imageView = [self createImageView];
        [pageView addSubview:imageView];
        
        textField = nil;
        textField = [self createTextField];
        [pageView addSubview:textField];
        
        _textView = nil;
        _textView = [self createTextView];
        [pageView addSubview:_textView];
        
        eraseView = nil;
        eraseView = [self createEraseView];
        [pageView addSubview:eraseView];
        
        _eSignImage = nil;
        _eSignImage = [self createESignImageView];
        [pageView addSubview:_eSignImage];
        
        _pageDrawingView = nil;
        _pageDrawingView = [self createPageDrawingView];
        [pageView addSubview:_pageDrawingView];
        
        [self refreshDrawing];
    }
}

- (void) clear{
    //Setting up a blank image to start from. This displays the current drawing
    imageView.image     = nil;
    _textView.text      = @"";
    _textView.hidden    = YES;
    _eSignImage.hidden  = YES;
    currPath            = nil;
    [currentPaths removeAllObjects];
    [annotationStore empty];
}

- (NSString*) annotationType {
    return _annotationType;
}

- (void) setAnnotationType:(NSString *)annotationType {
    if (![self.annotationType isEqualToString:AnnotationViewControllerType_None]) {
        //Close current annotation
        [self finishCurrentAnnotation];
    }
    _annotationType = annotationType;
    self.view.userInteractionEnabled = ![self.annotationType isEqualToString:AnnotationViewControllerType_None];
    
    if ([self.annotationType isEqualToString:AnnotationViewControllerType_Text]) {
        _textView = [self createTextView];
        [pageView addSubview:_textView];
    }else if ([self.annotationType isEqualToString:AnnotationViewControllerType_ESign]){
        _eSignImage = [self createESignImageView];
        [pageView addSubview:_eSignImage];
    }else if ([self.annotationType isEqualToString:AnnotationViewControllerType_EPen]){
        [_pageDrawingView setHidden:NO];
    }
}

- (void) finishCurrentAnnotation {
    Annotation* annotation = [self getCurrentAnnotation];
    if (annotation) {
        [self refreshDrawing];
        [annotationStore addAnnotation:annotation toPage:(int)self.currentPage];
        
        // 保存当前签写的透明图片
//        NSString *imagekey = [NSString stringWithFormat:@"%ld",(long)self.currentPage];
//        if (imageView.image) {
//            [imageArray addObject:[NSDictionary dictionaryWithObject:imageView.image forKey:imagekey]];
//        }
        
//        UIImage *lastImage = [imageDictionary objectForKey:imagekey];
//        if (lastImage) {
//            CGSize size = CGSizeMake(imageView.frame.size.width, imageView.frame.size.height);
//            UIGraphicsBeginImageContext(size);
//            
//            [lastImage drawInRect:imageView.bounds];
//            [imageView.image drawInRect:imageView.bounds];
//            UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
//
//            UIGraphicsEndImageContext();
//            
//            [imageDictionary setObject:resultingImage forKey:imagekey];
//        }else{
//            [imageDictionary setObject:imageView.image forKey:imagekey];
//        }
        if ([self.annotationType isEqualToString:AnnotationViewControllerType_Text]) {
            [_textView removeFromSuperview];
            _textView = nil;
        }else if ([self.annotationType isEqualToString:AnnotationViewControllerType_ESign]){
            [_eSignImage removeFromSuperview];
            _eSignImage = nil;
        }else if ([self.annotationType isEqualToString:AnnotationViewControllerType_EPen]){
            [_pageDrawingView removeFromSuperview];
            _pageDrawingView = nil;
        }
    }
    
#pragma mark -TODO basePath release 待解决
    if (basePath) {
        // 释放该path
//        CGPathRelease(basePath);
//        basePath = nil;
    }
    [currentPaths removeAllObjects];
    currPath = nil;
}

- (AnnotationStore*) annotations {
    [self finishCurrentAnnotation];
    return annotationStore;
}

- (Annotation*) getCurrentAnnotation {
    //输入打字状态
    if ([self.annotationType isEqualToString:AnnotationViewControllerType_Text]) {
        [_textView resignFirstResponder];
        [_textView setHidden:YES];
        if (_textView.text.length>0 && _textView.frame.origin.x>0 && _textView.frame.origin.y>0) {
            return [TextAnnotation textAnnotationWithText:_textView.text inRect:_textView.frame withFont:_textView.font];
        }else{
            return nil;
        }
    } else if ([self.annotationType isEqualToString:AnnotationViewControllerType_ESign]) { //电子签名图片状态
        if (_eSignImage.frame.origin.x>0 && _eSignImage.frame.origin.y>10) {
            return [ImageAnnotation imageAnnotationWithImage:[_eSignImage.image CGImage] inRect:[_eSignImage frame]];
        }else{
            return nil;
        }
    } else if ([self.annotationType isEqualToString:AnnotationViewControllerType_EPen]) { //电子笔图片状态
//        if (_eSignImage.frame.origin.x>0 && _eSignImage.frame.origin.y>10) {
            return [ImageAnnotation imageAnnotationWithImage:[[_pageDrawingView glToUIImage] CGImage] inRect:[_pageDrawingView frame]];
//        }else{
//            return nil;
//        }
    } else if ([self.annotationType isEqualToString:AnnotationViewControllerType_Sign] || [self.annotationType isEqualToString:AnnotationViewControllerType_RedPen] || [self.annotationType isEqualToString:AnnotationViewControllerType_Erase]){//绘制状态（红笔、黑笔、橡皮擦除）
        if (!currPath && [currentPaths count] == 0) {
            return nil;
        }else{
            //    CGMutablePathRef basePath = CGPathCreateMutable();
            basePath = CGPathCreateMutable();
            for (UIBezierPath *bpath in currentPaths) {
                bpath.miterLimit = -10;
                CGPathAddPath(basePath, NULL, bpath.CGPath);
            }
            CGPathAddPath(basePath, NULL, currPath);
            
            if ([self.annotationType isEqualToString:AnnotationViewControllerType_RedPen]) {
                PathAnnotation *pathAnnotation = [PathAnnotation pathAnnotationWithPath:basePath color:annotationColor lineWidth:RED_LINE_WIDTH fill:NO];
                return pathAnnotation;
            }
            if ([self.annotationType isEqualToString:AnnotationViewControllerType_Sign]) {
                PathAnnotation *pathAnnotation = [PathAnnotation pathAnnotationWithPath:basePath color:signColor lineWidth:BLACK_LINE_WIDTH fill:NO];
                return pathAnnotation;
            }
            if ([self.annotationType isEqualToString:AnnotationViewControllerType_Erase]) {
                PathAnnotation *pathAnnotation = [PathAnnotation pathAnnotationWithPath:basePath color:eraseColor lineWidth:ERASE_LINE_WIDTH fill:NO];
                return pathAnnotation;
            }
            
            // 释放该path
            CGPathRelease(basePath);
            return nil;
        }
    }else{
        return nil;
    }
}

- (void) hide {
    [self.view removeFromSuperview];
}

- (void) undo {
    //Immediate path
    if (currPath != nil) {
        currPath = nil;
    } else if ([currentPaths count] > 0) {
        //if we have a current path, undo it
        [currentPaths removeLastObject];
    } else {
        //pop from store
        [annotationStore undoAnnotationOnPage:(int)self.currentPage];
    }
    
    [self refreshDrawing];
}

- (void) refreshDrawing {
    UIGraphicsBeginImageContextWithOptions(pageView.frame.size, NO, 1.5f);
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    
    //Draw previous paths
    [annotationStore drawAnnotationsForPage:(int)self.currentPage inContext:currentContext];
    
//    if ([self.annotationType isEqualToString:AnnotationViewControllerType_Sign]) {
        if (_textView.text.length > 0 && (_textView.frame.origin.x>0 && _textView.frame.origin.y>0)) {
            UIGraphicsPushContext(currentContext);
            CGContextSetTextMatrix(currentContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
            CGContextSetTextDrawingMode(currentContext, kCGTextFill);
            CGContextSetFillColorWithColor(currentContext, [[UIColor blackColor] CGColor]);
            CGRect newTextFrame = _textView.frame;
            newTextFrame.origin.x += 5;
            newTextFrame.origin.y += 7;
            [_textView.text drawInRect:newTextFrame withAttributes:@{NSFontAttributeName:_textView.font}];
            UIGraphicsPopContext();
        }
//    }else if ([self.annotationType isEqualToString:AnnotationViewControllerType_ESign]){
        if (_eSignImage.frame.origin.x>0 && _eSignImage.frame.origin.y >0) {
            CGContextSaveGState(currentContext);
            CGContextTranslateCTM(currentContext, _eSignImage.frame.origin.x, _eSignImage.frame.origin.y);
            CGContextTranslateCTM(currentContext, 0, _eSignImage.frame.size.height);
            CGContextScaleCTM(currentContext, 1.0, -1.0);
            CGContextTranslateCTM(currentContext, -_eSignImage.frame.origin.x, -_eSignImage.frame.origin.y);
            CGContextDrawImage(currentContext, _eSignImage.frame, _eSignImage.image.CGImage);
            
            CGContextRestoreGState(currentContext);
            
            // Add Date
            UIGraphicsPushContext(currentContext);
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy/MM/dd"];
            NSString *dateTime = [dateFormatter stringFromDate:[NSDate date]];
            CGRect dateFrame = CGRectMake(_eSignImage.frame.origin.x + _eSignImage.frame.size.width + 5, _eSignImage.frame.origin.y + _eSignImage.frame.size.height - 20, 80, 20);
            CGContextSetRGBFillColor (currentContext,  1, 1, 1, 1.0);//设置填充颜色
            [dateTime drawInRect:dateFrame withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:10.0]}];
            UIGraphicsPopContext();
        }
//    }
//    }else{
        CGContextSetShouldAntialias(currentContext, YES);
        CGContextSetAllowsAntialiasing(currentContext, YES);
        CGContextSetLineJoin(currentContext, kCGLineJoinRound);//线条拐角
        CGContextSetLineCap(currentContext, kCGLineCapRound);//终点处理
        //set the miter limit for the joins of connected lines in a graphics context
        CGContextSetMiterLimit(currentContext, 2.0);
        
        if ([self.annotationType isEqualToString:AnnotationViewControllerType_RedPen]) {
            //Setup style
            CGContextSetBlendMode(currentContext, kCGBlendModeNormal);
            CGContextSetLineWidth(currentContext, RED_LINE_WIDTH);
            CGContextSetStrokeColorWithColor(currentContext, annotationColor);
        }
        if ([self.annotationType isEqualToString:AnnotationViewControllerType_Sign]) {
            //Setup style
            CGContextSetBlendMode(currentContext, kCGBlendModeNormal);
            CGContextSetLineWidth(currentContext, BLACK_LINE_WIDTH);
            CGContextSetStrokeColorWithColor(currentContext, signColor);
        }
        if ([self.annotationType isEqualToString:AnnotationViewControllerType_Erase]) {
            //Setup style
            CGContextSetBlendMode(currentContext, kCGBlendModeClear);
            CGContextSetLineWidth(currentContext, ERASE_LINE_WIDTH);
            //CGContextSetStrokeColorWithColor(currentContext, eraseColor);
        }
        CGContextBeginPath(currentContext);
        
        //Draw Paths
        for (UIBezierPath *path in currentPaths) {
            CGContextAddPath(currentContext, path.CGPath);
        }
        
        CGContextAddPath(currentContext, currPath);
        
        //paint a line along the current path
        CGContextStrokePath(currentContext);
//    }

    //Saving
    imageView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    lastPoint = [touch locationInView:pageView];
    
    lastContactPoint1 = [touch previousLocationInView:pageView];
    lastContactPoint2 = [touch previousLocationInView:pageView];
    
    if ([self.annotationType isEqualToString:AnnotationViewControllerType_Text]) {
        if (_textView.hidden) {
            _textView.layer.borderWidth = 1;
            _textView.hidden = NO;
            [_textView becomeFirstResponder];
        }
        if ([_textView pointInside:[touch locationInView:_textView] withEvent:nil]) {
            [_textView becomeFirstResponder];
            
        } else {
//            _textView.alpha = 1.0;
            _textView.center = lastPoint;
        }
//        NSLog(@"touch.y:%f,  height:%f,   keyOffset:%d, pageview.view.frame:%@",[touch locationInView:self.view].y,_textView.frame.size.height,!keyBoardOffset,NSStringFromCGRect(pageView.frame));
        if ([touch locationInView:self.view].y + _textView.frame.size.height + 216 + 94 > self.view.frame.size.height && !keyBoardOffset) {
            [self.delegate keyboardWillShow:216 + 94];
            keyBoardOffset = YES;
        }
        
    }else if ([self.annotationType isEqualToString:AnnotationViewControllerType_ESign]) {
        _eSignImage.alpha = 1.0;
        _eSignImage.hidden = NO;
        _eSignImage.center = lastPoint;
    }else {
        if ([self.annotationType isEqualToString:AnnotationViewControllerType_Erase]) {
            eraseView.center = CGPointMake(lastPoint.x, lastPoint.y);
            eraseView.hidden = NO;
            [UIView animateWithDuration:1.0 animations:^{
                eraseView.layer.borderWidth = 2.0;
            } completion:^(BOOL finished) {
            }];
        }
        if (currPath) {
            [currentPaths addObject:[UIBezierPath bezierPathWithCGPath:currPath]];
        }
        currPath = CGPathCreateMutable();
        CGPathMoveToPoint(currPath, NULL, lastPoint.x, lastPoint.y);
    }
    
    didMove = NO;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    didMove = YES;
    UITouch *touch = [touches anyObject];
    //save previous contact locations
    lastContactPoint2 = lastContactPoint1;
    lastContactPoint1 = [touch previousLocationInView:pageView];
    
    //save current location
    currentPoint = [touch locationInView:pageView];
    
    if ([self.annotationType isEqualToString:AnnotationViewControllerType_Text]) {
//        textField.center = lastContactPoint1;
        _textView.center = lastContactPoint1;
//        NSLog(@"center.y:%f,  height:%f,   keyOffset:%d, pageview.view.frame:%@",[touch locationInView:self.view].y,_textView.frame.size.height,!keyBoardOffset,NSStringFromCGRect(pageView.frame));
        // keyboard 弹出，视图上移
        if ([_textView isFirstResponder] && ([touch locationInView:self.view].y + _textView.frame.size.height + 216 + 94 > self.view.frame.size.height) && !keyBoardOffset) {
            [self.delegate keyboardWillShow:216 + 94];
            keyBoardOffset = YES;
        }else{
            if ( ([touch locationInView:self.view].y + _textView.frame.size.height + 216 + 94 < self.view.frame.size.height) && keyBoardOffset) {
                [self.delegate keyboardDidHidden:216 + 94];
                keyBoardOffset = NO;
            }
        }
    } else if ([self.annotationType isEqualToString:AnnotationViewControllerType_ESign]) {
        _eSignImage.center = lastContactPoint1;
    }else{
        if ([self.annotationType isEqualToString:AnnotationViewControllerType_Erase]) {
            eraseView.center = CGPointMake(currentPoint.x, currentPoint.y);
        }
        
        //find mid points to be used for quadratic bezier curve
        CGPoint midPoint1 = [self midPoint:lastContactPoint1 withPoint:lastContactPoint2];
        CGPoint midPoint2 = [self midPoint:currentPoint withPoint:lastContactPoint1];
        
        //Update path
        //begin a new new subpath at this point
        CGPathAddLineToPoint(currPath, NULL, midPoint1.x, midPoint1.y);
        CGPathAddQuadCurveToPoint(currPath, NULL, lastContactPoint1.x, lastContactPoint1.y, midPoint2.x, midPoint2.y);
        [self refreshDrawing];
    }
    
    lastPoint = currentPoint;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    if ([self.annotationType isEqualToString:AnnotationViewControllerType_Text]) {
        if (_textView.frame.origin.x <0) {
            _textView.hidden = YES;
        }
        [self refreshDrawing];
        return;
    }
    if ([self.annotationType isEqualToString:AnnotationViewControllerType_ESign]) {
        _eSignImage.alpha = 0.0;
        [self refreshDrawing];
        return;
    }
    if ([self.annotationType isEqualToString:AnnotationViewControllerType_Erase]) {
        [UIView animateWithDuration:1.0 animations:^{
            eraseView.layer.borderWidth = 0.1;
        } completion:^(BOOL finished) {
            eraseView.hidden = YES;
        }];
    }

    if (!didMove) {
        currentPoint = [touch locationInView:pageView];
        CGFloat penSize = [self.annotationType isEqualToString:AnnotationViewControllerType_Sign] ? BLACK_LINE_WIDTH : RED_LINE_WIDTH ;
        // One/Single point touch
        CGPathAddEllipseInRect(currPath, NULL, CGRectMake(currentPoint.x - penSize * 0.5, currentPoint.y - penSize * 0.5, penSize, penSize));
        [self refreshDrawing];
    }
    didMove = NO;
}

- (void)didReceiveMemoryWarning
{
#ifdef DEBUG
	NSLog(@"%s", __FUNCTION__);
#endif
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIImage *)getImageFromAnnotationsWithPage:(int)page
{
    UIGraphicsBeginImageContextWithOptions(pageView.frame.size, NO, 1.5f);
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    
    //Draw previous paths
    [annotationStore drawAnnotationsForPage:page inContext:currentContext];
    
    //Saving
    UIImage *annotationImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return annotationImage;
}

//calculate midpoint between two points
- (CGPoint) midPoint:(CGPoint )p0 withPoint: (CGPoint) p1 {
    return (CGPoint) {
        (p0.x + p1.x) / 2.0,
        (p0.y + p1.y) / 2.0
    };
}

#pragma mark - UITextView Delegate
- (void)textViewDidChange:(UITextView *)textView
{
    // 获取原来的 frame
    CGRect tmpRect = _textView.frame;
    NSString *content = textView.text;
    NSArray *lineArray = [content componentsSeparatedByString:@"\n"];
    tmpRect.size.height = TEXT_FIELD_HEIGHT + _textView.font.pointSize*([lineArray count]-1);
    CGFloat maxWidth = TEXT_FIELD_WIDTH;
    for (NSString *str in lineArray) {
        CGFloat strWidth = [str sizeWithAttributes:@{NSFontAttributeName:textView.font}].width + 10;
        if (strWidth > maxWidth) {
            maxWidth = strWidth;
        }
    }
    if (maxWidth > TEXT_FIELD_WIDTH) {
        tmpRect.size.width = maxWidth;
    }
    if (maxWidth + tmpRect.origin.x > self.view.frame.size.width) {
        tmpRect.size.width = self.view.frame.size.width - tmpRect.origin.x - 100;
    }
    _textView.frame = tmpRect;
}

#pragma mark - TextView frame with keyboard


#pragma mark - Keyboard will show with Text
- (void)observerKeyboardWillShow:(NSNotification *)notification
{
//    NSDictionary *info = [notification userInfo];
//    NSValue *value = [info objectForKey:UIKeyboardFrameBeginUserInfoKey];
//    CGSize keyboardSize = [value CGRectValue].size;
//    
//    CGFloat keyboardOffset = self.view.frame.size.height - _textView.frame.origin.y - _textView.frame.size.height - keyboardSize.height;
//    NSLog(@"keyBoard:%f,y:%f,height:%f,offset:%f", keyboardSize.height,_textView.frame.origin.y,_textView.frame.size.height,keyboardOffset);  //216
//    if (keyboardOffset > 0) {
//        [self.delegate keyboardWillShow: keyboardOffset];
//    }
}

- (void)observerKeyboardWasHidden:(NSNotification *)notification
{
    if (keyBoardOffset) {
        [self.delegate keyboardDidHidden: 216+94];
        keyBoardOffset = NO;
    }
}

@end
