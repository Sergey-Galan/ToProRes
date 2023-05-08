//
//  ToProResJob.m
//  ToProRes
//
//  Created by Sergey on 30.04.2023.
//

#import "ToProResJob.h"

@interface ToProResJob()
@end

@implementation ToProResJob

- (instancetype)initWithArguments:(NSArray *)args andStandardInput:(NSString *)stdinStr {
    self = [super init];
    if (self) {
        _arguments = args;
        _standardInputString = stdinStr;
    }
    return self;
}

+ (instancetype)jobWithArguments:(NSArray *)args andStandardInput:(NSString *)stdinStr {
    return [[self alloc] initWithArguments:args andStandardInput:stdinStr];
}

@end
