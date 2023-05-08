//
//  main.m
//  ToProRes
//
//  Created by Sergey on 30.04.2023.
//


#import <Cocoa/Cocoa.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

#ifdef DEBUG
void exceptionHandler(NSException *exception);

    void exceptionHandler(NSException *exception) {
        NSLog(@"%@", [exception reason]);
        NSLog(@"%@", [exception userInfo]);
        NSLog(@"%@", [exception callStackReturnAddresses]);
        NSLog(@"%@", [exception callStackSymbols]);
    }
#endif

io_connect_t        root_port;
IONotificationPortRef    notify;
io_object_t         anIterator;

static void callback(void * x,io_service_t y,natural_t messageType,void * messageArgument)
{
    printf("messageType %08lx, arg %08lx\n",(long unsigned int)messageType, (long unsigned int)messageArgument);
    
    switch ( messageType ) {
    case kIOMessageSystemWillSleep:
        IOAllowPowerChange(root_port,(long)messageArgument);
        printf("Going to sleep now\n");
        break;
    case kIOMessageCanSystemSleep: // we don't want to automatically go to sleep
        IOCancelPowerChange(root_port,(long)messageArgument);
        break;
    case kIOMessageSystemHasPoweredOn:
        printf("Just had a nice snooze\n");
        break;
    default:
        break;
    }
    
} /* callback */

int main(int argc, char *argv[])
{


    fprintf(stderr, "\nAttempting to register for system power notifications\n");
    root_port = IORegisterForSystemPower (0,&notify,callback,&anIterator);
    if ( root_port == MACH_PORT_NULL ) {
            fprintf(stderr, "IORegisterForSystemPower failed\n");
            return 1;
    }
        fprintf(stderr, "Registration successful\n");
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                        IONotificationPortGetRunLoopSource(notify),
                        kCFRunLoopDefaultMode);
    
    return NSApplicationMain(argc, (const char **) argv);
}

