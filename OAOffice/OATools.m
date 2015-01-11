//
//  OATools.m
//  OAOffice
//
//  Created by admin on 15/1/10.
//  Copyright (c) 2015年 DigitalOcean. All rights reserved.
//

#import "OATools.h"

@implementation OATools

#pragma mark - Add log info to plist
+ (void)newLogWithInfo:(NSString *)info time:(NSDate *)currentDate type:(NSString *)logType
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *userName   = [userDefaults objectForKey:kUserName];
        NSString *deviceUUID = [userDefaults objectForKey:kDeviceInfo];
        NSString *plistPath  = [userDefaults objectForKey:kPlistPath];
        NSDictionary *logDic = [NSDictionary dictionaryWithObjectsAndKeys:userName,kUserName,deviceUUID,kDeviceInfo,currentDate,kLogTime,info,kLogInfo,logType,kLogType, nil];
        NSMutableDictionary *docPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
        if (!docPlist) {
            docPlist = [NSMutableDictionary dictionary];
        }
        [docPlist setObject:logDic forKey:[NSString stringWithFormat:@"%@",currentDate]];
        //写入文件
        [docPlist writeToFile:plistPath atomically:YES];
    });
}

#pragma mark - AllUserList
+ (void)getAllUserToPlist
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *plistPath = [userDefaults objectForKey:kUserPlist];
        __block NSMutableArray *docPlist = [[NSMutableArray alloc] initWithContentsOfFile:plistPath];
        if (!docPlist) {
            docPlist = [NSMutableArray array];
            
            NSString *authorizationHeader = [userDefaults objectForKey:kAuthorizationHeader];
            NSString *serverURL = [[NSString stringWithFormat:@"%@",kUserURL] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];//转码成UTF-8  否则可能会出现错
            AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
            [manager.requestSerializer setValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
            [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"content-type"];
            manager.responseSerializer = [AFJSONResponseSerializer serializer];
            
            [manager GET:serverURL parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
                //解析返回的JSON数据
                NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseObject options:NSJSONWritingPrettyPrinted error:nil];
                NSArray *result = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:nil];
                docPlist = [NSMutableArray arrayWithArray:result];
                //写入文件
                [docPlist writeToFile:plistPath atomically:YES];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSString *info = [NSString stringWithFormat:@"Error:获取最新用户组人员信息失败错误.%@",error.description];
                [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
            }];
        }
    });
}

@end
