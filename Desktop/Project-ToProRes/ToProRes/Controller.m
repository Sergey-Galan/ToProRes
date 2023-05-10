//
//  Controller.m
//  ToProRes
//
//  Created by Sergey on 30.04.2023.
//

#import "Controller.h"
#import "ToProResJob.h"
#import "DockCircularProgressBar.h"
#import "ProgressBarView.h"

// Abbreviations. Objective-C is often tediously verbose
#define FILEMGR     [NSFileManager defaultManager]
#define DEFAULTS    [NSUserDefaults standardUserDefaults]

// Logging
#ifdef DEBUG
    #define PLog(...) NSLog(__VA_ARGS__)
#else
    #define PLog(...)
#endif

#ifdef DEBUG
#endif

@interface Controller()
{
    __weak IBOutlet ProgressBarView *pb_progress_view;
    IBOutlet NSWindow *ToProResWindow;
    IBOutlet NSButton *CancelButton;
    IBOutlet NSTextField *MessageTextFieldName;
    IBOutlet NSTextField *MessageTextFieldFPS;
    IBOutlet NSTextField *MessageTextFieldCount;
    IBOutlet NSTextField *MessageTextFieldProgress;
    IBOutlet NSTextField *MessageTextFieldSize;
    IBOutlet NSTextField *MessageTextFieldDuration;
    IBOutlet NSTextField *MessageTextFieldTime;
    IBOutlet NSTextField *MessageTextFieldSpeed;
    IBOutlet NSTextField *MessageTextFieldInfo;
    IBOutlet NSButton *FolderPicker2;
    IBOutlet NSProgressIndicator *ProgressIndicator;
    IBOutlet id FolderLabel2;
    IBOutlet id FoldernameLabel2;
    
    // Menu items
    IBOutlet NSMenuItem *openRecentMenuItem;
    IBOutlet NSMenu *windowMenu;
    IBOutlet NSMenu *fileMenu;
    
    NSTextView *outputTextView;
    
    NSTask *task;
    
    
    NSPipe *inputPipe;
    NSFileHandle *inputWriteFileHandle;
    NSPipe *outputPipe;
    NSFileHandle *outputReadFileHandle;
    
    NSMutableArray <NSString *> *arguments;
    NSArray <NSString *> *commandLineArguments;
    NSArray <NSString *> *interpreterArgs;
    NSArray <NSString *> *scriptArgs;
    NSString *stdinString;
    
    NSString *interpreterPath;
    NSString *scriptToProResPath;
    
    BOOL isDroppable;
    BOOL remainRunning;
    BOOL acceptsFiles;
    BOOL acceptsText;
    BOOL promptForFileOnLaunch;
    BOOL statusItemUsesSystemFont;
    BOOL statusItemIconIsTemplate;
    BOOL runInBackground;
    BOOL isService;
    BOOL sendsNotifications;
    
    BOOL acceptAnyDroppedItem;
    BOOL acceptDroppedFolders;
    
    NSImage *statusItemImage;
    
    BOOL isTaskRunning;
    BOOL outputEmpty;
    BOOL hasTaskRun;
    BOOL hasFinishedLaunching;
    
    NSString *remnants;
    
    NSMutableArray <ToProResJob *> *jobQueue;
}

@property (weak) IBOutlet NSTextField *percentField;
@property (weak) IBOutlet NSSlider *percentSlider;
@property (unsafe_unretained) IBOutlet NSArrayController *testArray1;
@property (nonatomic, strong) NSString *currentlySelectedPort1;
@property (retain) NSString *plistFileName;
@property (retain) NSString *Folder2;
@property (retain) NSString *ProgressString;
@end


@implementation Controller


- (instancetype)init {
    self = [super init];
    if (self) {
        arguments = [NSMutableArray array];
        outputEmpty = YES;
        jobQueue = [NSMutableArray array];
    }
    return self;
}

- (void)awakeFromNib {
    // Load settings from AppSettings.plist in app bundle
    [self loadAppSettings];
    
    // Prepare UI
    [self initialiseInterface];
    
    // Listen for terminate notification
    NSString *notificationName = NSTaskDidTerminateNotification;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(taskFinished:)
                                                 name:notificationName
                                               object:nil];
    
    // Register as text handling service
    if (isService) {
        [NSApp setServicesProvider:self];
        NSMutableArray *sendTypes = [NSMutableArray array];
        if (acceptsFiles) {
            [sendTypes addObject:NSFilenamesPboardType];
        }
        [NSApp registerServicesMenuSendTypes:sendTypes returnTypes:@[]];
    }
    
    // User Notification Center
    if (sendsNotifications) {
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
}

#pragma mark - App Settings

// Load configuration from AppSettings.plist and Info.plist, sanitize values, etc.
- (void)loadAppSettings {
    // Application bundle
    NSBundle *bundle = [NSBundle mainBundle];
    
    // Check if /scripts/scriptToProRes file exists
    scriptToProResPath = [bundle pathForResource:@"/scripts/scriptToProRes" ofType:nil];
    if ([FILEMGR fileExistsAtPath:scriptToProResPath] == NO) {
        NSLog(@"/scripts/scriptToProRes missing from application bundle.");
    }

    // Make sure scripts is executable and readable
    NSNumber *permissions = [NSNumber numberWithUnsignedLong:493];
    NSDictionary *attributes = @{ NSFilePosixPermissions:permissions };
    [FILEMGR setAttributes:attributes ofItemAtPath:scriptToProResPath error:nil];
    if ([FILEMGR isReadableFileAtPath:scriptToProResPath] == NO || [FILEMGR isExecutableFileAtPath:scriptToProResPath] == NO) {
        NSLog(@"scriptToProRes file is not readable/executable.");
    }

    interpreterPath = @"/bin/sh";
    remainRunning = YES;
    isDroppable = NO;
    promptForFileOnLaunch = NO;

    //  for drop
    acceptsFiles = YES;
    if (acceptsFiles) {
        acceptAnyDroppedItem = YES;
        isDroppable = TRUE;
        acceptDroppedFolders = YES;
    }
}


- (NSString *) pathForDatafolderDefault1
{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSMoviesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
           NSString *dataPath = [path stringByAppendingPathComponent:@"/ToProRes output"];
           NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath]){
        [[NSFileManager defaultManager] createDirectoryAtPath:dataPath withIntermediateDirectories:NO attributes:nil error:&error]; //Create folder
    }

    return dataPath;
}

- (NSString *) pathForDatafolder2
{
    BOOL isDir;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *folder = self.Folder2;
    folder = [folder stringByExpandingTildeInPath];
    if(![fileManager fileExistsAtPath:folder isDirectory:&isDir]) {
        if(![fileManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL])
            NSLog(@"Error: Create folder failed %@",folder);
    }
     return folder;
}
#pragma mark - App Delegate handlers

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [rootPath stringByAppendingPathComponent:@"/Preferences/org.SerhiiHalan.SettingsToProRes.plist"];
    self.plistFileName = plistPath;
    NSLog(@"plist file path: %@", plistPath);
    
    //Если плиста нет - создаётся дефолтный
    NSData *plistTest = [NSData dataWithContentsOfFile:self.plistFileName];
    if (!plistTest)
    {
        NSMutableDictionary *root = [NSMutableDictionary dictionary];
        [root setObject:@"422" forKey:@"Profile"];
        [root setObject:self.pathForDatafolderDefault1 forKey:@"DestinationFolder"];
        NSLog(@"Default settings saving data:\n%@", root);
        NSError *error = nil;
        NSData *representation = [NSPropertyListSerialization dataWithPropertyList:root format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
        [representation writeToFile:self.plistFileName atomically:YES];
        [self pathForDatafolderDefault1];
    }
    
    //Get the keys from the plist
    NSData *plistData = [NSData dataWithContentsOfFile:self.plistFileName];
    if (!plistData)
    {
        NSLog(@"error reading from file: %@", self.plistFileName);
    }
    NSPropertyListFormat format;
    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListMutableContainersAndLeaves format:&format error:&error];
    if (!error)
    {
        NSMutableDictionary *root = plist;
        NSLog(@"loaded data:\n%@", root);
    }
    else
    {
        NSLog(@"error: %@", error);
    }
    
    _currentlySelectedPort1 = ((void)(@"%@"), [plist objectForKey:@"Profile"]);
    [self.testArray1 addObject:@{ @"name" : @"422 Proxy" }];
    [self.testArray1 addObject:@{ @"name" : @"422 LT" }];
    [self.testArray1 addObject:@{ @"name" : @"422" }];
    [self.testArray1 addObject:@{ @"name" : @"422 HQ" }];
    [self.testArray1 addObject:@{ @"name" : @"4444" }];
    [self.testArray1 addObject:@{ @"name" : @"4444 XQ" }];
    
    _Folder2 = ((void)(@"%@"), [plist objectForKey:@"DestinationFolder"]);
    self.Folder2 = _Folder2;
    
    [self pathForDatafolder2];
    
    pb_progress_view->text=@"Drag video files";
    [pb_progress_view setNeedsDisplay:true];
    
    PLog(@"Application did finish launching");
    hasFinishedLaunching = YES;
}


//Save the plist by adding a key
- (IBAction)savePlist:(id)sender
{
    [ProgressIndicator setHidden:NO];
    [ProgressIndicator startAnimation:self];
        dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(backgroundQueue, ^{
            for (NSUInteger i = 0; i < 1; i++) {
                [NSThread sleepForTimeInterval:0.8f];
            dispatch_async(dispatch_get_main_queue(), ^{
                [ProgressIndicator stopAnimation:self];
                [ProgressIndicator setHidden:YES];
            });
          }
      });
    
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    NSString* percentString =
       [formatter stringFromNumber: [NSNumber numberWithInt:
           [[self percentSlider] intValue]]];

    [[self percentField] setStringValue:percentString];
    NSMutableDictionary *root = [[NSMutableDictionary alloc] initWithContentsOfFile:self.plistFileName];
    [root setObject:_currentlySelectedPort1 forKey:@"Profile"];
    NSLog(@"saving data:\n%@", root);
    NSError *error = nil;
    NSData *representation = [NSPropertyListSerialization dataWithPropertyList:root format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (!error)
    {
        BOOL ok = [representation writeToFile:self.plistFileName atomically:YES];
        if (ok)
        {
            NSLog(@"ok!");
        }
        else
        {
            NSLog(@"error writing to file: %@", self.plistFileName);
        }
    }
    else
    {
        NSLog(@"error: %@", error);
    }
}
        

- (IBAction)FolderPicker2:(id)sender{
    NSString *path = NSTemporaryDirectory();
    NSArray *directoryContents = [NSFileManager.defaultManager subpathsOfDirectoryAtPath:path error:nil];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setTitle:@"Choose a Folder"];
    [openPanel setAllowedFileTypes:directoryContents];
    [openPanel setCanChooseDirectories:YES];
    if ([openPanel runModal] == NSModalResponseOK){
        NSString *FolderPath = [[openPanel URLs][0] path];
        [FoldernameLabel2 setStringValue:FolderPath];
        NSMutableDictionary *root = [[NSMutableDictionary alloc] initWithContentsOfFile:self.plistFileName];
        self.Folder2 = [FoldernameLabel2 stringValue];
        [root setObject:self.Folder2 forKey:@"DestinationFolder"];
        NSLog(@"saving data:\n%@", root);
        NSError *error = nil;
        NSData *representation = [NSPropertyListSerialization dataWithPropertyList:root format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
        if (!error)
        {
            BOOL ok = [representation writeToFile:self.plistFileName atomically:YES];
            if (ok)
            {
                NSLog(@"ok!");
            }
            else
            {
                NSLog(@"error writing to file: %@", self.plistFileName);
            }
        }
        else
        {
            NSLog(@"error: %@", error);
        }
    }
}


- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return sendsNotifications;
}

- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames {
    PLog(@"Received openFiles event for files: %@", [filenames description]);
    
    if (hasTaskRun == FALSE && commandLineArguments != nil) {
        for (NSString *filePath in filenames) {
            if ([commandLineArguments containsObject:filePath]) {
                return;
            }
        }
    }
    
    // Add the dropped files as a job for processing
    BOOL success = [self addDroppedFilesJob:filenames];
    [NSApp replyToOpenOrPrint:success ? NSApplicationDelegateReplySuccess : NSApplicationDelegateReplyFailure];
    
    // If no other job is running, we execute
    if (success && !isTaskRunning && hasFinishedLaunching) {
        [self executeScript];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Terminate task
    if (task != nil) {
        if ([task isRunning]) {
            [task terminate];
        }
        task = nil;
    }
    return NSTerminateNow;
}

#pragma mark - Interface manipulation

// Set up any menu items, windows, controls at application launch
- (void)initialiseInterface {
    [openRecentMenuItem setEnabled:acceptsFiles];
    if (!acceptsFiles) {
        [fileMenu removeItemAtIndex:0]; // Open
        [fileMenu removeItemAtIndex:0]; // Open Recent..
        [fileMenu removeItemAtIndex:0]; // Separator
    }

    // Script output will be dumped in outputTextView
    // By default this is the Text Window text view

    if (runInBackground == TRUE) {
        // Old Carbon way
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    }
    
                if (isDroppable) {
                    [ToProResWindow registerForDraggedTypes:@[NSFilenamesPboardType, NSStringPboardType]];
                }
                [ToProResWindow makeKeyAndOrderFront:self];
}

// Prepare all the controls, windows, etc prior to executing script
- (void)prepareInterfaceForExecution {
    [outputTextView setString:@""];
    // Yes, yes, this is a nasty hack. But styling in NSTextViews
    // doesn't get applied when appending text unless there is already
    // some text in the view. The alternative is to make very expensive
    // calls to [textStorage setAttributes:] for all appended output,
    // which freezes up the app when lots of text is dumped by the script
    [outputTextView setString:@"\u200B"]; // zero-width space character
    pb_progress_view->text=@"";
    [CancelButton setTitle:@"Cancel"];
    [FolderPicker2 setEnabled:NO];
    [[DockCircularProgressBar sharedDockCircularProgressBar] clear];
}

// Adjust controls, windows, etc. once script is done executing
- (void)cleanupInterface {
    
    [CancelButton setTitle:@"Quit"];
    [CancelButton setEnabled:YES];
    [FolderPicker2 setEnabled:YES];
}

#pragma mark - Task

// Construct arguments list etc. before actually running the script

- (void)prepareForExecution {
    
    // Clear arguments list and reconstruct it
    [arguments removeAllObjects];
    
    // First, add all specified arguments for interpreter
    [arguments addObjectsFromArray:interpreterArgs];
    
    // Add script as argument to interpreter, if it exists
    if (![FILEMGR fileExistsAtPath:scriptToProResPath]) {
        NSLog(@"Script missing at execution path %@", scriptToProResPath);
    }
    [arguments addObject:scriptToProResPath];
    
    // Add arguments for script
    [arguments addObjectsFromArray:scriptArgs];
    
    // If initial run of app, add any arguments passed in via the command line (argv)
    // Q: Why CLI args for GUI app typically launched from Finder?
    // A: Apparently helpful for certain use cases such as Firefox protocol handlers etc.
    if (commandLineArguments && [commandLineArguments count]) {
        [arguments addObjectsFromArray:commandLineArguments];
        commandLineArguments = nil;
    }
    
    // Finally, dequeue job and add arguments
    if ([jobQueue count] > 0) {
        ToProResJob *job = jobQueue[0];

        // We have files in the queue, to append as arguments
        // We take the first job's arguments and put them into the arg list
        if ([job arguments]) {
            [arguments addObjectsFromArray:[job arguments]];
        }
        stdinString = [[job standardInputString] copy];
        
        [jobQueue removeObjectAtIndex:0];
    }
}


- (void)executeScript {
    hasTaskRun = YES;
    
    // Never execute script if there is one running
    if (isTaskRunning) {
        return;
    }
    outputEmpty = NO;
    
    [self prepareForExecution];
    [self prepareInterfaceForExecution];
    
    isTaskRunning = YES;
    
    // Run the task
        [self executeScriptWithoutPrivileges];
}


// Launch regular user-privileged process using NSTask
- (void)executeScriptWithoutPrivileges {

    // Create task and apply settings
    task = [[NSTask alloc] init];
    [task setLaunchPath:interpreterPath];
    [task setCurrentDirectoryPath:[[NSBundle mainBundle] resourcePath]];
    [task setArguments:arguments];
    
    // Direct output to file handle and start monitoring it if script provides feedback
    outputPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [task setStandardError:outputPipe];
    outputReadFileHandle = [outputPipe fileHandleForReading];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gotOutputData:) name:NSFileHandleReadCompletionNotification object:outputReadFileHandle];
    [outputReadFileHandle readInBackgroundAndNotify];
    
    // Set up stdin for writing
    inputPipe = [NSPipe pipe];
    [task setStandardInput:inputPipe];
    inputWriteFileHandle = [[task standardInput] fileHandleForWriting];
    
    // Set it off
    //PLog(@"Running task\n%@", [task humanDescription]);
    [task launch];
    
    // Write input, if any, to stdin, and then close
    if (stdinString) {
        [inputWriteFileHandle writeData:[stdinString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [inputWriteFileHandle closeFile];
    stdinString = nil;    
}


#pragma mark - Task completion

// OK, called when we receive notification that task is finished
// Some cleaning up to do, controls need to be adjusted, etc.
- (void)taskFinished:(NSNotification *)aNotification {
    isTaskRunning = NO;
    PLog(@"Task finished");
    
    // Did we receive all the data?
    // If no data left, we do clean up
    if (outputEmpty) {
        [self cleanup];
    }
    
    // If there are more jobs waiting for us, execute
    if ([jobQueue count] > 0 /*&& remainRunning*/) {
        [self executeScript];
    }
}

- (void)cleanup {
    if (isTaskRunning) {
        return;
    }
    // Stop observing the filehandle for data since task is done
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSFileHandleReadCompletionNotification
                                                  object:outputReadFileHandle];
    
    // We make sure to clear the filehandle of any remaining data
    if (outputReadFileHandle != nil) {
        NSData *data;
        while ((data = [outputReadFileHandle availableData]) && [data length]) {
            [self parseOutput:data];
        }
    }
    
    // Now, reset all controls etc., general cleanup since task is done
    [self cleanupInterface];
}

#pragma mark - Output

// Read from the file handle and append it to the text window
- (void)gotOutputData:(NSNotification *)aNotification {
    // Get the data from notification
    NSData *data = [aNotification userInfo][NSFileHandleNotificationDataItem];
    
    // Make sure there's actual data
    if ([data length]) {
        outputEmpty = NO;
        
        // Append the output to the text field
        [self parseOutput:data];
        
        // We schedule the file handle to go and read more data in the background again.
        [[aNotification object] readInBackgroundAndNotify];
    }
    else {
        PLog(@"Output empty");
        outputEmpty = YES;
        if (!isTaskRunning) {
            [self cleanup];
        }
        if (!remainRunning) {
            [[NSApplication sharedApplication] terminate:self];
        }
    }
}


- (void)parseOutput:(NSData *)data {
    // Create string from output data
    NSMutableString *outputString = [[NSMutableString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (outputString == nil) {
        PLog(@"Warning: Output string is nil");
        return;
    }
    
    PLog(@"Output:%@", outputString);
    
    if (remnants) {
        [outputString insertString:remnants atIndex:0];
    }
    
    // Parse line by line
    NSMutableArray *lines = [[outputString componentsSeparatedByString:@"\n"] mutableCopy];
    
    // If the string did not end with a newline, it wasn't a complete line of output
    // Thus, we store this last non-newline-terminated string
    // It'll be prepended next time we get output
    if ([[lines lastObject] length] > 0) { // Output didn't end with a newline
        remnants = [lines lastObject];
    } else {
        remnants = nil;
    }
    
    [lines removeLastObject];
    
    // Parse output looking for commands; if none, append line to output text field
    for (NSString *theLine in lines) {
        
        
        //        if ([theLine length] == 0) {
        //            [self appendString:@""];
        //            continue;
        //        }
        
        
        if ([theLine hasPrefix:@"NOTIFICATION:"]) {
            NSString *notificationString = [theLine substringFromIndex:13];
            [self showNotification:notificationString];
            continue;
        }
        
        
        if ([theLine hasPrefix:@"Name:"]) {
            NSString *NameString = [theLine substringFromIndex:5];
            if ([NameString hasSuffix:@"%"]) {
                NameString = [NameString substringToIndex:[NameString length]-1];
            }
            [MessageTextFieldName setStringValue:NameString];
            continue;
        }
        
        
        if ([theLine hasPrefix:@"FPS:"]) {
            NSString *FPSString = [theLine substringFromIndex:4];
            if ([FPSString hasSuffix:@"%"]) {
                FPSString = [FPSString substringToIndex:[FPSString length]-1];
            }
            [MessageTextFieldFPS setStringValue:FPSString];
            continue;
        }
        
        
        if ([theLine hasPrefix:@"Size:"]) {
            NSString *SizeString = [theLine substringFromIndex:5];
            if ([SizeString hasSuffix:@"%"]) {
                SizeString = [SizeString substringToIndex:[SizeString length]-1];
            }
            [MessageTextFieldSize setStringValue:SizeString];
            continue;
        }
        
        
        if ([theLine hasPrefix:@"Duration:"]) {
            NSString *DurationString = [theLine substringFromIndex:9];
            if ([DurationString hasSuffix:@"%"]) {
                DurationString = [DurationString substringToIndex:[DurationString length]-1];
            }
            [MessageTextFieldDuration setStringValue:DurationString];
            continue;
        }
        
        
        if ([theLine hasPrefix:@"Time:"]) {
            NSString *TimeString = [theLine substringFromIndex:5];
            if ([TimeString hasSuffix:@"%"]) {
                TimeString = [TimeString substringToIndex:[TimeString length]-1];
            }
            [MessageTextFieldTime setStringValue:TimeString];
            continue;
        }
        
        
        if ([theLine hasPrefix:@"Speed:"]) {
            NSString *SpeedString = [theLine substringFromIndex:6];
            if ([SpeedString hasSuffix:@"%"]) {
                SpeedString = [SpeedString substringToIndex:[SpeedString length]-1];
            }
            [MessageTextFieldSpeed setStringValue:SpeedString];
            continue;
        }
        
        
        if ([theLine hasPrefix:@"Info:"]) {
            NSString *InfoString = [theLine substringFromIndex:5];
            if ([InfoString hasSuffix:@"%"]) {
                InfoString = [InfoString substringToIndex:[InfoString length]-1];
            }
            [MessageTextFieldInfo setStringValue:InfoString];
            continue;
        }
        
        
        if ([theLine hasPrefix:@"Count:"]) {
            NSString *CountString = [theLine substringFromIndex:6];
            if ([CountString hasSuffix:@"%"]) {
                CountString = [CountString substringToIndex:[CountString length]-1];
            }
            [MessageTextFieldCount setStringValue:CountString];
            continue;
        }
        
        
        if ([theLine hasPrefix:@"Progress:"]) {
            NSString *ProgressString = [theLine substringFromIndex:9];
            if ([ProgressString hasSuffix:@"%"]) {
                ProgressString = [ProgressString substringToIndex:[ProgressString length]-1];
            }
            [MessageTextFieldProgress setStringValue:ProgressString];
            self.ProgressString = ProgressString;
            Float64 Percent = [ProgressString floatValue];
            if (![ProgressString  isEqual: @""]) {
                double progress = [ProgressString intValue]/100.0;
                // Make sure the previous ProgressBar is clear before update.
                [[DockCircularProgressBar sharedDockCircularProgressBar]
                 setProgress:(float)progress];
                [[DockCircularProgressBar sharedDockCircularProgressBar] updateProgressBar];
                pb_progress_view->text=@"";
                pb_progress_view->progress=(int)Percent;
                [pb_progress_view setNeedsDisplay:true];
            } else {
                [[DockCircularProgressBar sharedDockCircularProgressBar] hideProgressBar];
                pb_progress_view->text=@"Drag video files";
                pb_progress_view->progress=0;
                [pb_progress_view setNeedsDisplay:true];
                continue;
            }
        }
    }
}

- (void)clearOutputBuffer {
    NSTextStorage *textStorage = [outputTextView textStorage];
    NSRange range = NSMakeRange(0, [textStorage length]-1);
    [textStorage beginEditing];
    [textStorage replaceCharactersInRange:range withString:@""];
    [textStorage endEditing];
}

#pragma mark - Interface actions

// Run open panel, made available to apps that accept files
- (IBAction)openFiles:(id)sender {
    
    // Create open panel
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:acceptDroppedFolders];
    
    if ([oPanel runModal] == NSModalResponseOK) {
        // Convert URLs to paths
        NSMutableArray *filePaths = [NSMutableArray array];        
        for (NSURL *url in [oPanel URLs]) {
            [filePaths addObject:[url path]];
        }
        
        BOOL success = [self addDroppedFilesJob:filePaths];
        
        if (!isTaskRunning && success) {
            [self executeScript];
        }
        
    } else {
        // Canceled in open file dialog
        if (!remainRunning) {
            [[NSApplication sharedApplication] terminate:self];
        }
    }
}


- (BOOL)validateMenuItem:(NSMenuItem *)anItem {

    SEL selector = [anItem action];
    // Open should only work if it's a droppable app that accepts files
    if (acceptsFiles && selector == @selector(openFiles:)) {
        return YES;
    }

    if ([anItem action] == @selector(savePlist:)) {
        return YES;
    }
    
    if ([anItem action] == @selector(buttonDonations:)) {
        return YES;
    }
    
    if ([anItem action] == @selector(menuItemSelected:)) {
        return YES;
    }
    
    return NO;
}

- (IBAction)cancel:(id)sender {
    if (task != nil && [task isRunning]) {
        PLog(@"Task cancelled");
        [task terminate];
        jobQueue = [NSMutableArray array];
    }

    if ([[sender title] isEqualToString:@"Quit"]) {
        [[NSApplication sharedApplication] terminate:self];
    }
}



#pragma mark - Service handling

- (void)dropService:(NSPasteboard *)pb userData:(NSString *)userData error:(NSString **)err {
    PLog(@"Received drop service data");
    NSArray *types = [pb types];
    BOOL ret = 0;
    id data = nil;
    
    if (acceptsFiles && [types containsObject:NSFilenamesPboardType] && (data = [pb propertyListForType:NSFilenamesPboardType])) {
        ret = [self addDroppedFilesJob:data];  // Files
    } else {
        // Unknown
        *err = @"Data type in pasteboard cannot be handled by this application.";
        return;
    }
    
    if (isTaskRunning == NO && ret) {
        [self executeScript];
    }
}

#pragma mark - Add job to queue

// Processing dropped files
- (BOOL)addDroppedFilesJob:(NSArray <NSString *> *)files {
    if (!acceptsFiles) {
        return NO;
    }
    
    // We only accept the drag if at least one of the files meets the required types
    NSMutableArray *acceptedFiles = [NSMutableArray array];
    for (NSString *file in files) {
        if ([self isAcceptableFileType:file]) {
            [acceptedFiles addObject:file];
        }
    }
    if ([acceptedFiles count] == 0) {
        return NO;
    }
    
    // We create a job and add the files as arguments
    ToProResJob *job = [ToProResJob jobWithArguments:acceptedFiles andStandardInput:nil];
    [jobQueue addObject:job];
    
    // Add to Open Recent menu
    for (NSString *path in acceptedFiles) {
        [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
    }
    
    return YES;
}

- (BOOL)addMenuItemSelectedJob:(NSString *)menuItemTitle {
    ToProResJob *job = [ToProResJob jobWithArguments:@[menuItemTitle] andStandardInput:nil];
    [jobQueue addObject:job];
    return YES;
}


- (BOOL)isAcceptableFileType:(NSString *)file {
    
    // Check if it's a folder. If so, we only accept it if folders are accepted
    BOOL isDir;
    BOOL exists = [FILEMGR fileExistsAtPath:file isDirectory:&isDir];
    if (!exists) {
        return NO;
    }
    if (isDir) {
        return acceptDroppedFolders;
    }
    
    if (acceptAnyDroppedItem) {
        return YES;
    }
    return NO;
}

#pragma mark - Drag and drop handling

// Check file types against acceptable drop types here before accepting them
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    // Prevent dragging from NSOpenPanels
    // draggingSource returns nil if the source is not in the same application
    // as the destination. We decline any drags from within the app.
    if ([sender draggingSource]) {
        return NSDragOperationNone;
    }
    
    BOOL acceptDrag = NO;
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    // String dragged
    if ([[pboard types] containsObject:NSStringPboardType] && acceptsText) {
        acceptDrag = YES;
    }
    // File dragged
    else if ([[pboard types] containsObject:NSFilenamesPboardType] && acceptsFiles) {
        // Loop through files, see if any of the dragged files are acceptable
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        
        for (NSString *file in files) {
            if ([self isAcceptableFileType:file]) {
                acceptDrag = YES;
                break;
            }
        }
    }
    
    if (acceptDrag) {
        PLog(@"Dragged items accepted");
        return NSDragOperationLink;
    }
    
    PLog(@"Dragged items refused");
    return NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    // Determine drag data type and dispatch to job queue
    if ([[pboard types] containsObject:NSFilenamesPboardType]) {
        return [self addDroppedFilesJob:[pboard propertyListForType:NSFilenamesPboardType]];
    }
    return NO;
}

// Once the drag is over, we immediately execute w. files as arguments if not already processing
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {

    // Fire off the job queue if nothing is running
    if (!isTaskRunning && [jobQueue count] > 0) {
        [NSTimer scheduledTimerWithTimeInterval:0.0f target:self selector:@selector(executeScript) userInfo:nil repeats:NO];
    }
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    // This is needed to keep link instead of the green plus sign on web view
    // and also required to reject non-acceptable dragged items.
    return [self draggingEntered:sender];
}

- (IBAction)menuItemSelected:(id)sender {
    [self addMenuItemSelectedJob:[sender title]];
    if (!isTaskRunning && [jobQueue count] > 0) {
        [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(executeScript) userInfo:nil repeats:NO];
    }
}

#pragma mark - Utility methods

- (void)showNotification:(NSString *)notificationText {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    [notification setInformativeText:notificationText];
    [notification setSoundName:NSUserNotificationDefaultSoundName];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

// Donations
- (IBAction)buttonDonations:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=2BREZMHRLQNZ4&source=url"]];
}


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

@end


