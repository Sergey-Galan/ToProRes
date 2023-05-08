//
//  ToProResJob.h
//  ToProRes
//
//  Created by Sergey on 30.04.2023.
//


#import <Foundation/Foundation.h>

@interface ToProResJob : NSObject

@property (nonatomic, copy) NSArray *arguments;
@property (nonatomic, copy) NSString *standardInputString;

- (instancetype)initWithArguments:(NSArray *)args andStandardInput:(NSString *)stdinStr;
+ (instancetype)jobWithArguments:(NSArray *)args andStandardInput:(NSString *)stdinStr;

@end
