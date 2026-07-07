//
//  DiskArbitration.m
//  MacAgent
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DiskArbitrationController.h"
#import "DADisk.h"
#import "DADiskManagement.h"

////////////////////////////////////////////////////////////////////////////////

void DASetLogBlock(void (^block)(const char *aLogMessage))
{
    @autoreleasepool
    {
        [DiskArbitrationController sharedController].logBlock = block;
    }
}

void DASetDiskMountedBlock(void (^block)(DiskRef aDisk))
{
    @autoreleasepool
    {
        [DiskArbitrationController sharedController].diskMountedBlock = block;
    }
}

void DASetDiskInsertedBlock(void (^block)(DiskRef aDisk))
{
    @autoreleasepool
    {
        [DiskArbitrationController sharedController].diskInsertedBlock = block;
    }
}

void DASetDiskDisappearedBlock(void (^block)(DiskRef aDisk))
{
    @autoreleasepool
    {
        [DiskArbitrationController sharedController].diskDisappearedBlock = block;
    }
}

void DAStartListenToDiskArbitration(void)
{
    @autoreleasepool
    {
        [[DiskArbitrationController sharedController] start];
    }
}

void DAStopListenToDiskArbitration(void)
{
    @autoreleasepool
    {
        [[DiskArbitrationController sharedController] stop];
    }
}

void DAWaitUntilDiskArbitrationIsRunning(void)
{
    @autoreleasepool
    {
        [[DiskArbitrationController sharedController] waitUntilIsRunning];
    }
}

#pragma mark -

void DAEnumerateValidForProcessingDisksWithBlock(
    void (^block)(DiskRef aDisk))
{
    @autoreleasepool
    {
        [DADiskManagement enumerateUniqueDisksWithBlock:
            ^(DADisk * _Nonnull aDisk, BOOL * _Nonnull aStop)
            {
                if (aDisk.isValidForProcessing)
                {
                    void *daDisk = (__bridge void *)(aDisk);
                    DiskRef disk = DiskCreateWithDADisk(daDisk);

                    block(disk);

                    DiskReleaseAndMakeNull(&disk);
                }
            }];
    }
}

#pragma mark -

DiskRef DACopyMountPointDiskForPath(CFStringRef aPath)
{
    DiskRef result = NULL;
    @autoreleasepool
    {
        NSString *path = (__bridge NSString *)(aPath);
        if ([path length] != 0)
        {
            DADisk *disk = [DADiskManagement uniqueDiskForPath:path];
            if (disk != nil)
            {
                void *daDisk = (__bridge void *)(disk);
                result = DiskCreateWithDADisk(daDisk);
            }
        }
    }
    return result;
}

bool DAIsAnyDiskMounted(void)
{
    __block bool result = false;
    @autoreleasepool
    {
        [DADiskManagement enumerateUniqueDisksWithBlock:
            ^(DADisk * _Nonnull aDisk, BOOL * _Nonnull aStop)
            {
                if (aDisk.isValidForProcessing)
                {
                    result = true;
                    *aStop = YES;
                }
            }];
    }
    return result;
}
