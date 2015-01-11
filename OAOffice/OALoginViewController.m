//
//  OALoginViewController.m
//  OAOffice
//
//  Created by admin on 14-8-11.
//  Copyright (c) 2014年 DigitalOcean. All rights reserved.
//

#import <LocalAuthentication/LocalAuthentication.h>
#import "OALoginViewController.h"
#import "OAMasterViewController.h"
#import "OADetailViewController.h"
#import "MBProgressHUD.h"
#import "AFNetworking.h"

@interface OALoginViewController ()<UITextFieldDelegate>
{
    UITextField *_userName;
    UITextField *_password;
}
@end

@implementation OALoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    // 1.设置登录背景
    self.bgImageView = [[UIImageView alloc] init];
    
    // 2.
//    _thumbPwd = @"";
    
    // 3.设置userName
    _userName = [[UITextField alloc] init];
    _userName.borderStyle = UITextBorderStyleNone;
    // 当设定Frame，不要用autoresizingMask
//    _userField.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _userName.textAlignment = NSTextAlignmentLeft;
    _userName.font = [UIFont boldSystemFontOfSize:18.0f];
    _userName.textColor = [UIColor blackColor];
    _userName.tintColor = kThemeColor;
    _userName.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 0)];
    _userName.leftView.userInteractionEnabled = NO;
    _userName.leftViewMode = UITextFieldViewModeAlways;
    _userName.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _userName.autocorrectionType = UITextAutocorrectionTypeNo;
    _userName.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"用户名：" attributes:@{NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
    
    // 4.设置password光标位置
    _password = [[UITextField alloc] init];
    _password.borderStyle = UITextBorderStyleNone;
    _password.textAlignment = NSTextAlignmentLeft;
    _password.font = [UIFont boldSystemFontOfSize:18.0f];
    _password.textColor = [UIColor blackColor];
    _password.tintColor = kThemeColor;
    _password.secureTextEntry = YES;
    _password.delegate = self;
    _password.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 0)];
    _password.leftView.userInteractionEnabled = NO;
    _password.leftViewMode = UITextFieldViewModeAlways;
    _password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"密    码：" attributes:@{NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
    
    // 5.设置登录按钮
    self.loginBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.loginBtn addTarget:self action:@selector(loginPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    self.loginThumb = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.loginThumb addTarget:self action:@selector(loginThumbPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self rotationDevice:orientation];
    
    [self.view addSubview:self.bgImageView];
    [self.view addSubview:_userName];
    [self.view addSubview:_password];
    [self.view addSubview:self.loginBtn];
    [self.view addSubview:self.loginThumb];
    
    // 6.登录保护，次数初始化
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self thumbPrompt];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation
                                            duration:duration];
    [self rotationDevice:toInterfaceOrientation];
}

- (void)rotationDevice:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation ==UIInterfaceOrientationLandscapeRight) {   //横屏
        _userName.frame = CGRectMake(379.0, 277.0, 268.0, 40.0);
        _password.frame = CGRectMake(379.0, 326.0, 268.0, 40.0);
        self.loginBtn.frame = CGRectMake(379.0, 373.0, 268.0, 40.0);
        self.loginThumb.frame = CGRectMake(473.0, 439.0, 80.0, 100.0);
        self.bgImageView.frame = CGRectMake(0, 0, 1024, 768);
        self.bgImageView.image = [UIImage imageNamed:@"LoginBG_L.png"];
    }else{                                        //竖屏
        _userName.frame = CGRectMake(206.0, 400.0, 354.0, 56.0);
        _password.frame = CGRectMake(206.0, 479.0, 354.0, 56.0);
        self.loginBtn.frame = CGRectMake(206.0, 556.0, 354.0, 56.0);
        self.loginThumb.frame = CGRectMake(331.0, 643.0, 107.0, 133.0);
        self.bgImageView.frame = CGRectMake(0, 0, 768, 1024);
        self.bgImageView.image = [UIImage imageNamed:@"LoginBG_H.png"];
    }
}

- (IBAction)loginPressed:(id)sender
{
//    NSString *userN = @"liukefu";//_userName.text;
//    NSString *passW = @"123";//_userPwd.text;
    NSString *userN = [_userName.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *passW = [_password.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self.view endEditing:YES];
    // 初步检查用户名、密码是否为空
    if (!userN.length || !passW.length) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提醒" message:@"用户名或密码为空" delegate:self cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        [alert show];
    }else{
        [self loginWithUsername:userN Password:passW];
    }
}

- (void)loginWithUsername:(NSString *)userN Password:(NSString *)passW
{
    // 检查网络连接状态
    if([AFNetworkReachabilityManager sharedManager].reachable)
    {
        NSString *loginURL = [NSString stringWithFormat:@"%@api/pad/login",kBaseURL];
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
        manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        [manager.requestSerializer setTimeoutInterval:kTimeout];
        
        // 设置网络参数：用户名／密码
        NSDictionary *para = @{@"username": userN, @"password" : passW};
        // 添加网络指示器
        [MBProgressHUD showHUDAddedTo:self.view bgColor:kThemeColor tintColor:[UIColor whiteColor] labelText:@"登录中..." animated:YES];
        
        // 在状态栏显示有网络请求的提示器
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        
        // 网络访问是异步的,回调是主线程的,因此程序员不用管在主线程更新UI的事情
        [manager POST:loginURL parameters:para success:^(AFHTTPRequestOperation *operation, id responseObject) {
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            // 在状态栏关闭有网络请求的提示器
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            
            // 3 解析返回的Data数据
            NSDictionary *resultDic = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:nil];
            
            if ([resultDic count] > 0) {
                // 将用户名和密码等数据全部存储到NSUserDefaults中
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                NSString *lastUserName = [userDefaults objectForKey:kUserName];
                if (!lastUserName ||![lastUserName isEqualToString:userN]) {
                    NSLog(@"Old User:%@,New user:%@",lastUserName,userN);
                    [userDefaults setObject:@"YES" forKey:kNewUser];
                    [userDefaults setObject:userN forKey:kUserName];
                    
                    NSString *info = [NSString stringWithFormat:@"OK:客户端新用户:%@,老户名:%@",userN,lastUserName];
                    [OATools newLogWithInfo:info time:[NSDate date] type:kLogInfoType];
                }
                [userDefaults setObject:[self getAuthorizationWithUserName:userN password:passW] forKey:kAuthorizationHeader];
                [userDefaults setObject:[resultDic objectForKey:kName] forKey:kName];
                
                [userDefaults removeObjectForKey:kESignImage];
                NSString *signImg = [resultDic objectForKey:kESignImage];
                if (![[resultDic objectForKey:kESignImage] isEqual:[NSNull null]]) {
                    [userDefaults setObject:signImg forKey:kESignImage];
                }
                
                // 这里建议同步存储到磁盘中，但是不是必须的
                [userDefaults synchronize];
                
                NSString *info = [NSString stringWithFormat:@"OK:登录成功,用户名:%@",userN];
                [OATools newLogWithInfo:info time:[NSDate date] type:kLogInfoType];
                
                // 跳转到OADetailViewController，并刷新数据
                [self.delegate dismissOALoginViewController:self];
            }else{
                NSString *info = [NSString stringWithFormat:@"Error:登录失败,用户名或密码错误.%@,result:%@",userN,(NSString *)responseObject];
                [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
                
                // AlertView 失败提示
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"登录失败" message:@"用户名或密码错误" delegate:self cancelButtonTitle:@"重新登录" otherButtonTitles:nil, nil];
                [alert show];
            }
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            
            // 在状态栏关闭有网络请求的提示器
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            // 日志记录
            NSString *info = [NSString stringWithFormat:@"Error:登录失败.%@",error.description];
            [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
            
//            NSLog(@"%@", error.description);
            // AlertView 失败提示
            NSString *message = [[error userInfo] objectForKey:@"NSLocalizedDescription"];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"登录失败" message:message delegate:self cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
            [alert show];
        }];
    }else{
        NSString *info = [NSString stringWithFormat:@"Error:网络中断,登录失败.%@",userN];
        [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"网络中断" message:@"请检查网络是否打开" delegate:self cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        [alert show];
    }
}

- (NSString *)getAuthorizationWithUserName:(NSString *)userName password:(NSString *)pwd
{
    NSData *data = [[NSString stringWithFormat:@"%@:%@",userName,pwd] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *result = [NSString stringWithFormat:@"Basic %@",[data base64EncodedStringWithOptions:0]];
    return result;
}

- (void)thumbPrompt
{
    // 7.Init _userName
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *name = [userDefaults stringForKey:kUserName];
    NSString *authorHeader = [userDefaults stringForKey:kAuthorizationHeader];
    if (name && authorHeader) {
        _userName.text = name;
        [self loginThumbPressed:nil];
    }
}

- (void)addBecomeActiveObserver
{
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(thumbPrompt) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (IBAction)loginThumbPressed:(id)sender
{
    LAContext *context = [LAContext new];
    NSError *error;
    context.localizedFallbackTitle = @"密码登录";
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error])
    {
        NSLog(@"Touch ID is available.");
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *authorizationHeader = [userDefaults objectForKey:kAuthorizationHeader];
        if (!authorizationHeader) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"用户验证信息已过期" message:@"" delegate:self cancelButtonTitle:@"重新登录" otherButtonTitles:nil, nil];
            [alert show];
        }else{
            [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                    localizedReason:NSLocalizedString(@"使用指纹登录", @"Use Touch ID to log in.")
                              reply:^(BOOL success, NSError *error) {
                                  if (success) {
                                      [self.delegate dismissOALoginViewController:self];
                                  }else{
                                      if (error.code == kLAErrorUserFallback) {
                                          NSLog(@"Authenticated using Touch ID.");
                                      } else if (error.code == kLAErrorUserCancel) {
                                          NSLog(@"用户取消指纹登录");
                                      } else {
                                          NSLog(@"认证失败");
                                      }
                                  }
                              }];
        }
    }else{
        // 如果sender非空，即点击“指纹登录”，则提示；
        if (sender) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"本设备不支持指纹识别" message:@"" delegate:self cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
            [alert show];
        }
    }
}

#pragma mark - UITextField Delegate
//当文本输入框的return key被点击的时候就会调用
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self loginPressed:self.loginBtn];
    return YES;
}

@end
