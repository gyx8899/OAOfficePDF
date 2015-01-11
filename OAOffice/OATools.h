//
//  OATools.h
//  OAOffice
//
//  Created by admin on 15/1/10.
//  Copyright (c) 2015年 DigitalOcean. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface OATools : NSObject

// 新增日志记录
+ (void)newLogWithInfo:(NSString *)info time:(NSDate *)currentDate type:(NSString *)logType;

// 获取选择会签用户列表
+ (void)getAllUserToPlist;

@end
