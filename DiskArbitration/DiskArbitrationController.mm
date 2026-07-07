//
//  DiskArbitrationController.m
//
//  Created by Danil Korotenko on 6/2/20.
//

#import "DiskArbitrationController.h"

#import <DiskArbitration/DiskArbitration.h>
#import <os/log.h>
#import <sys/mount.h>

#import "DADisk.h"
#import "DADiskManagement.h"

////////////////////////////////////////////////////////////////////////////////

@interface DiskArbitrationController ()

@property(atomic) BOOL shouldStop;
@property(atomic) BOOL isRunning;

@end

@implementation DiskArbitrationController
{
    DASessionRef            _session;
    dispatch_queue_t        _disk_arbitration_queue;
}

// singleton implementation
+ (DiskArbitrationController *)sharedController
{
    static DiskArbitrationController *sharedController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
    ^{
        sharedController = [[DiskArbitrationController alloc] init];
    });
    return sharedController;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _session = DASessionCreate(kCFAllocatorDefault);
        _disk_arbitration_queue =
            dispatch_queue_create("disk_arbitration_queue", NULL);

        self.shouldStop = NO;
        self.isRunning = NO;
    }
    return self;
}

#pragma mark -

- (void)diskMounted:(DADisk *)disk
{
    [self logOutside:@"Disk Mounted function: %@", [disk description]];

    if (disk.isValidForProcessing)
    {
        [self notifyDiskInserted:disk];
        [self notifyDiskDidMount:disk];
    }
}

void DiskAppearedCallback(DADiskRef diskRef, void *context)
{
    @autoreleasepool
    {
        NSString *volumePath = [DADiskManagement volumePathForDisk:diskRef];
        if (0 != volumePath.length)
        {
            DiskArbitrationController *controller =
                (__bridge DiskArbitrationController *)(context);
            DADisk *disk = [DADiskManagement uniqueDiskForDADisk:diskRef mountPath:volumePath];
            [controller diskMounted:disk];
        }
    }
}

void DiskDisappearedCallback(DADiskRef aDiskRef, void *context)
{
    @autoreleasepool
    {
        DADisk *disk = [DADiskManagement extractDiskForDADisk:aDiskRef];
        if (disk != nil)
        {
            DiskArbitrationController *controller =
                (__bridge DiskArbitrationController *)(context);

            [controller logOutside:[NSString stringWithFormat:@"Disk Disappeared: %@",
                [disk description]]];

            [controller notifyDiskDidDisappear:disk];
        }
    }
}

void DiskDescriptionChangedCallback(DADiskRef diskRef, CFArrayRef aKeys, void *context)
{
    @autoreleasepool
    {
        NSArray *keys = (__bridge NSArray*)aKeys;

        if ([keys containsObject:(NSString *)kDADiskDescriptionVolumePathKey])
        {
            NSString *volumePath = [DADiskManagement volumePathForDisk:diskRef];
            if (volumePath.length != 0)
            {
                // VolumePath appeared or changed
                DiskAppearedCallback(diskRef, context);
            }
            else
            {
                // volume path dissappeared
                DiskDisappearedCallback(diskRef, context);
            }
        }
    }
}

#pragma mark -

- (void)stop
{
    self.shouldStop = YES;
    do
    {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, FALSE);
    }
    while (self.isRunning);
}

- (void)waitUntilIsRunning
{
    do
    {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, FALSE);
    }
    while (!self.isRunning);
}

#pragma mark -

- (void)notifyDiskDidMount:(DADisk *)aDisk
{
    if (self.diskMountedBlock)
    {
        void *daDisk = (__bridge void *)(aDisk);
        DiskRef disk = DiskCreateWithDADisk(daDisk);

        self.diskMountedBlock(disk);

        DiskReleaseAndMakeNull(&disk);
    }
}

- (void)notifyDiskInserted:(DADisk *)aDisk
{
    if (self.diskInsertedBlock)
    {
        void *daDisk = (__bridge void *)(aDisk);
        DiskRef disk = DiskCreateWithDADisk(daDisk);

        self.diskInsertedBlock(disk);

        DiskReleaseAndMakeNull(&disk);
    }
}

- (void)notifyDiskDidDisappear:(DADisk *)aDisk
{
    if (self.diskDisappearedBlock)
    {
        void *daDisk = (__bridge void *)(aDisk);
        DiskRef disk = DiskCreateWithDADisk(daDisk);

        self.diskDisappearedBlock(disk);

        DiskReleaseAndMakeNull(&disk);
    }
}

#pragma mark -

- (void)start
{
    dispatch_async(_disk_arbitration_queue,
    ^{
        CFMutableDictionaryRef matching = CFDictionaryCreateMutable(
            kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks);

        DARegisterDiskAppearedCallback(self->_session, matching,
            DiskAppearedCallback, (__bridge void *)self);
        DARegisterDiskDisappearedCallback(self->_session, matching,
            DiskDisappearedCallback, (__bridge void *)self);
        DARegisterDiskDescriptionChangedCallback(self->_session, matching, NULL,
            DiskDescriptionChangedCallback, (__bridge void *)self);

        CFRelease(matching);

        DASessionScheduleWithRunLoop(self->_session, CFRunLoopGetCurrent(),
            kCFRunLoopCommonModes);

        self.isRunning = YES;

        do
        {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, FALSE);
        }
        while (!self.shouldStop);

        DASessionUnscheduleFromRunLoop(self->_session, CFRunLoopGetCurrent(),
            kCFRunLoopCommonModes);

        self.isRunning = NO;
    });
}

#pragma mark -

- (void)logOutside:(NSString *)aLogMessage, ...
{
    if (self.logBlock)
    {
        NSString *message = nil;
        va_list args;
        va_start(args, aLogMessage);
        message = [[NSString alloc] initWithFormat:aLogMessage arguments:args];
        va_end(args);
        self.logBlock([message UTF8String]);
    }
}

@end
