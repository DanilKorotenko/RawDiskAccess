//
//  DADisk.m
//

#import "DADiskManagement.h"
#import "DADisk.h"

#import <DiskArbitration/DiskArbitration.h>
#import <IOKit/storage/IOStorageProtocolCharacteristics.h>
#import <IOKit/storage/IODVDMedia.h>
#import <IOKit/storage/IOCDMedia.h>
#import <os/log.h>

#include <sys/mount.h>

////////////////////////////////////////////////////////////////////////////////
static NSString *const kZeroUUID = @"00000000-0000-0000-0000-000000000000";
static NSMutableDictionary *uniqueDisks = nil;

////////////////////////////////////////////////////////////////////////////////

@implementation DADiskManagement

+ (void)initialize
{
    if (self == [DADiskManagement class])
    {
        uniqueDisks = [NSMutableDictionary dictionary];
    }
}

#pragma mark -

+ (NSString *_Nullable)volumePathForDisk:(DADiskRef)aDisk
{
    NSString *volumePath = nil;

    CFDictionaryRef descDict = DADiskCopyDescription(aDisk);
    if (descDict)
    {
        NSDictionary *diskDescription = (__bridge NSDictionary *)(descDict);

        NSURL *value = [diskDescription
            objectForKey:(NSString *)kDADiskDescriptionVolumePathKey];
        volumePath = value.path;

        CFRelease(descDict);
    }

    return volumePath;
}

+ (void)enumerateUniqueDisksWithBlock:
    (void (^)(DADisk * _Nonnull aDisk, BOOL * _Nonnull aStop))anEnumerationBlock
{
    @synchronized (uniqueDisks)
    {
        [uniqueDisks enumerateKeysAndObjectsUsingBlock:^(
            id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop)
        {
            DADisk *disk = obj;
            anEnumerationBlock(disk, stop);
        }];
    }
}

#pragma mark -

+ (DADisk *)extractDiskForDADisk:(DADiskRef)aDiskRef
{
    __block DADisk *result = nil;

    @synchronized (uniqueDisks)
    {
        __block NSString *mountPath = nil;

        [uniqueDisks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop)
        {
            DADisk *disk = obj;

            if ([disk isEqualToDADisk:aDiskRef])
            {
                mountPath = (NSString *)key;
                result = disk;
                *stop = YES;
            }
        }];

        if (mountPath != nil)
        {
            [uniqueDisks removeObjectForKey:mountPath];
        }
    }

    return result;
}

+ (DADisk * _Nullable)uniqueDiskForPath:(NSString * _Nullable)aPath
{
    if (aPath == nil || aPath.length == 0)
    {
        return nil;
    }
    __block DADisk *result = nil;
    @synchronized (uniqueDisks)
    {
        for (NSString *mountPath in [uniqueDisks allKeys])
        {
            if (![mountPath isEqualTo:@"/"])
            {
                if ([aPath hasPrefix:mountPath])
                {
                    result = [uniqueDisks objectForKey:mountPath];
                }
            }
        }
    }
    return result;
}

+ (DADisk *)uniqueDiskForDADisk:(DADiskRef)diskRef
    mountPath:(NSString * _Nonnull)aMountPath
{
    DADisk *result = nil;

    @synchronized (uniqueDisks)
    {
        result = [uniqueDisks objectForKey:aMountPath];
        if (result == nil)
        {
            result = [[DADisk alloc] initWithDADisk:diskRef];
            [uniqueDisks setObject:result forKey:aMountPath];
        }
    }

    return result;
}

@end
