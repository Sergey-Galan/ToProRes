//
//  ProgressBarView.m
//  ToProRes
//
//  Created by Sergey on 30.04.2023.
//

#import "ProgressBarView.h"

@implementation ProgressBarView

- (void)viewDidMoveToWindow {
    self->progress=0;
}

    - (void)drawRect:(NSRect)dirtyRect {
        [super drawRect:dirtyRect];
        
        NSAffineTransform *tran=[NSAffineTransform transform];
        [tran translateXBy:dirtyRect.size.width/2 yBy:dirtyRect.size.height/2];
        [tran rotateByDegrees:270];
        [tran concat];
        
        NSBezierPath *path=[NSBezierPath bezierPath];
        [path setLineWidth:7];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(0, 0) radius:100 startAngle:0 endAngle:100*3.6];//360/100=3.6
        [[NSColor colorWithSRGBRed:0.8 green:0.8 blue:0.8 alpha:1] setStroke];
        [path stroke];

        path=[NSBezierPath bezierPath];
        [path setLineWidth:7];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(0, 0) radius:100 startAngle:0 endAngle:self->progress*3.6];//360/100=3.6
        [[NSColor redColor] setStroke];
        [path stroke];
        
        tran=[NSAffineTransform transform];
        [tran rotateByDegrees:90];
        [tran concat];

        if (![text isEqual: @"Drag video files"]) {
            attributes=[NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica" size:26],NSFontAttributeName,[NSColor redColor],NSForegroundColorAttributeName, nil];
            NSAttributedString *cur_text=[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d%%",progress] attributes:attributes];
            NSSize text_size=[cur_text size];
            NSRect r=NSMakeRect(0+(0-text_size.width)/2, 0+(0-text_size.height)/2, text_size.width, text_size.height);
            [cur_text drawInRect:r];
        }
        else
        {
        attributes=[NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica" size:26],NSFontAttributeName,[NSColor colorWithSRGBRed:0.6 green:0.6 blue:0.6 alpha:1],NSForegroundColorAttributeName, nil];
        NSAttributedString *cur_text=[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@",text] attributes:attributes];
        NSSize text_size=[cur_text size];
        NSRect r=NSMakeRect(0+(0-text_size.width)/2, 0+(0-text_size.height)/2, text_size.width, text_size.height);
        [cur_text drawInRect:r];
        NSLog(@"Drag video files");
    }
}

-(BOOL)isFlipped{
    return true;
}

@end
