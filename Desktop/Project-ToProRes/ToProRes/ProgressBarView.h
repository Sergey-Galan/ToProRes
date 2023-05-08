//
//  ProgressBarView.h
//  ToProRes
//
//  Created by Sergey on 30.04.2023.
//

#import <Cocoa/Cocoa.h>

@interface ProgressBarView : NSView{
    NSDictionary *attributes;
@public
    int progress;
    NSString *text;
}
-(void)viewDidMoveToWindow;
@end

