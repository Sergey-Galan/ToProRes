//
//  DockCircularProgressBar.h
//  ToProRes
//
//  Created by Sergey on 30.04.2023.
//

#import <Cocoa/Cocoa.h>

@interface DockCircularProgressBar : NSObject

+ (DockCircularProgressBar*)sharedDockCircularProgressBar;

- (void)updateProgressBar;

- (void)hideProgressBar;

// Indicates whether the progress indicator should be in an indeterminate state
// or not.
- (void)setIndeterminate:(BOOL)indeterminate;

// Indicates the amount of progress made of the download. Ranges from [0..1].
- (void)setProgress:(float)progress;

- (void)clear;

@end
