//
//  DADisk.m
//

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

@interface DADisk ()

@property(readonly)             NSDictionary *diskDescription;

@property (readonly)            NSString *  parentMediaName;
@property (readonly)            NSString *  mediaName;
@property (readonly)            NSString *  mediaUUID;
@property (readonly)            NSString *  mediaContentUUID;
@property (readonly)            NSString *  deviceProtocol;
@property (readonly)            NSString *  mediaKind;
@property (readonly)            NSString *  volumeKind;
@property (readonly)            BOOL        isAutoFS;

@property (readonly)            DADiskRef   diskRef;

@property (readonly)            BOOL        isUSB;
@property (readonly)            BOOL        isSDCard;

@property (readonly)            BOOL        isValidRemovable;
@property (readonly)            BOOL        isValidNetwork;

@property (readonly)            NSInteger   mountFlags;

@end

////////////////////////////////////////////////////////////////////////////////

@implementation DADisk
{
    DADiskRef _diskRef;
}

@synthesize diskDescription;
@synthesize parentMediaName;
@synthesize mediaName;
@synthesize mediaUUID;
@synthesize mediaContentUUID;
@synthesize volumeUUID;
@synthesize uuid;
@synthesize volumePath;
@synthesize volumeNetworkPath;
@synthesize deviceProtocol;
@synthesize mediaKind;
@synthesize volumeKind;
@synthesize deviceMediaName;
@synthesize mountFlags;

+ (void)initialize
{
    if (self == [DADisk class])
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

            if (disk.diskRef == aDiskRef)
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

#pragma mark -

- (id)initWithDADisk:(DADiskRef)diskRef
{
    if (NULL == diskRef)
    {
        return nil;
    }

    self = [super init];
    if (self)
    {
        _diskRef = (DADiskRef)CFRetain(diskRef);
    }
    return self;
}

- (void)dealloc
{
    if (_diskRef != NULL)
    {
        CFRelease(_diskRef);
    }
}

- (NSString *)description
{
    NSDictionary *descriptionDictionary =
        @{
            @"isWholeDisk":     self.isWholeDisk ?      @"YES" : @"NO",
            @"isMounted":       self.isMounted ?        @"YES" : @"NO",
            @"isLeaf":          self.isLeaf ?           @"YES" : @"NO",
            @"isUSB":           self.isUSB ?            @"YES" : @"NO",
            @"isSDCard":        self.isSDCard ?         @"YES" : @"NO",

            @"parentMediaName": self.parentMediaName ?  self.parentMediaName : @"<empty>",
            @"mediaName":       self.mediaName ?        self.mediaName : @"<empty>",
            @"uuid":            self.uuid ?             self.uuid : @"<empty>",
            @"volumePath":      self.volumePath ?       self.volumePath : @"<empty>",
            @"deviceProtocol":  self.deviceProtocol ?   self.deviceProtocol : @"<empty>",
//            @"mountFlagsInfo":  self.mountFlagsInfo,
        };
    return [descriptionDictionary description];
}

#pragma mark -

- (BOOL)isWholeDisk
{
    BOOL value = [[self.diskDescription
        objectForKey:(NSString *)kDADiskDescriptionMediaWholeKey] boolValue];
    return value;
}

- (BOOL)isMounted
{
    BOOL isMounted = (self.volumePath.length == 0) ? NO : YES;
    return isMounted;
}

- (BOOL)isLeaf
{
    BOOL value = [[self.diskDescription
        objectForKey:(NSString *)kDADiskDescriptionMediaLeafKey] boolValue];
    return value;
}

- (BOOL)isUSB
{
    BOOL isUSB = [self.deviceProtocol isEqualToString:
        @kIOPropertyPhysicalInterconnectTypeUSB];
    return isUSB;
}

- (BOOL)isSDCard
{
    BOOL isSDCard = [self.deviceProtocol isEqualToString:
        @kIOPropertyPhysicalInterconnectTypeSecureDigital];
    return isSDCard;
}

- (BOOL)isNetwork
{
    BOOL value = [[self.diskDescription
        objectForKey:(NSString *)kDADiskDescriptionVolumeNetworkKey] boolValue];
    return value;
}

- (DiskType)type
{
    if (self.isValidNetwork)
    {
        return DiskTypeNetwork;
    }
    else if (self.isValidRemovable)
    {
        return DiskTypeRemovable;
    }
    return DiskTypeLocalDrive;
}

- (BOOL)isCDDVD
{
    return [self.mediaKind isEqualToString:@kIODVDMediaClass] ||
        [self.mediaKind isEqualToString:@kIOCDMediaClass];
}

- (BOOL)isValidRemovable
{
    return self.isLeaf &&
        (self.isUSB || self.isSDCard) &&
        self.isMounted &&
        ([self.deviceMediaName length] > 0) &&
        ([self.uuid length] > 0);
}

- (BOOL)isValidNetwork
{
    return self.isNetwork && self.isMounted && !self.isAutoFS;
}

- (BOOL)isValidForProcessing
{
    return self.isValidRemovable || self.isValidNetwork;
}

- (NSString *)mediaName
{
    if (mediaName == nil)
    {
        mediaName = [self.diskDescription objectForKey:(NSString *)kDADiskDescriptionMediaNameKey];
    }
    return mediaName;
}

- (NSString *)mediaUUID
{
    if (mediaUUID == nil)
    {
        CFUUIDRef valueRef = (__bridge CFUUIDRef)([self.diskDescription
            objectForKey:(NSString *)kDADiskDescriptionMediaUUIDKey]);
        if (valueRef != NULL)
        {
            CFStringRef uuidStringRef = CFUUIDCreateString(kCFAllocatorDefault, valueRef);
            mediaUUID = CFBridgingRelease(uuidStringRef);
        }
    }
    return mediaUUID;
}

- (NSString *)mediaContentUUID
{
    if (mediaContentUUID == nil)
    {
        NSString *uuidStr = [self.diskDescription
            objectForKey:(NSString *)kDADiskDescriptionMediaContentKey];
        if ([uuidStr length] != 0)
        {
            CFUUIDRef uuidRef = CFUUIDCreateFromString(kCFAllocatorDefault, (CFStringRef)uuidStr);
            if (uuidRef != NULL)
            {
                CFStringRef uuidStringRef = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
                if (uuidStringRef != NULL)
                {
                    mediaContentUUID = (NSString *)CFBridgingRelease(uuidStringRef);
                    if ([mediaContentUUID isEqualToString:kZeroUUID])
                    {
                        mediaContentUUID = nil;
                    }
                }
                CFRelease(uuidRef);
            }
        }
    }
    return mediaContentUUID;
}

- (NSString *)volumeUUID
{
    if (volumeUUID == nil)
    {
        CFUUIDRef valueRef = (__bridge CFUUIDRef)([self.diskDescription
            objectForKey:(NSString *)kDADiskDescriptionVolumeUUIDKey]);
        if (valueRef != NULL)
        {
            CFStringRef uuidStringRef = CFUUIDCreateString(kCFAllocatorDefault, valueRef);
            volumeUUID = CFBridgingRelease(uuidStringRef);
        }
    }
    return volumeUUID;
}

- (NSString *)uuid
{
    if (uuid == nil)
    {
        uuid = self.volumeUUID;
        if ([uuid length] == 0)
        {
            uuid = self.mediaUUID;
        }
        if ([uuid length] == 0)
        {
            uuid = self.mediaContentUUID;
        }
    }
    return uuid;
}

- (NSString *)volumePath
{
    if (volumePath == nil)
    {
        NSURL *value = [self.diskDescription objectForKey:(NSString *)kDADiskDescriptionVolumePathKey];
        volumePath = value.path;
    }
    return volumePath;
}

- (NSString *)volumeNetworkPath
{
    if (volumeNetworkPath == nil && self.isNetwork)
    {
        if (self.volumePath != nil)
        {
            NSURL *volumeURL = [NSURL fileURLWithPath:self.volumePath];

            NSURL *remount = nil;
            [volumeURL getResourceValue:&remount
                forKey:NSURLVolumeURLForRemountingKey error:NULL];
            if (remount != nil)
            {
                volumeNetworkPath = [NSString stringWithFormat:@"%@://%@%@", remount.scheme, remount.host, remount.path];
            }
        }
    }
    return volumeNetworkPath;
}

- (NSString *)deviceProtocol
{
    if (deviceProtocol == nil)
    {
        deviceProtocol = [self.diskDescription objectForKey:(NSString *)kDADiskDescriptionDeviceProtocolKey];
    }
    return deviceProtocol;
}

- (NSString *)mediaKind
{
    if (mediaKind == nil)
    {
        mediaKind = [self.diskDescription objectForKey:(NSString *)kDADiskDescriptionMediaKindKey];
    }
    return mediaKind;
}

- (NSString *)volumeKind
{
    if (volumeKind == nil)
    {
        volumeKind = [self.diskDescription objectForKey:(NSString *)kDADiskDescriptionVolumeKindKey];
    }
    return volumeKind;
}

- (BOOL)isAutoFS
{
    return [self.volumeKind isEqualToString:@"autofs"];
}

- (NSString *)deviceMediaName
{
    if (deviceMediaName == nil)
    {
        if (self.isUSB || self.isSDCard)
        {
            deviceMediaName = self.parentMediaName;
            if (nil == deviceMediaName)
            {
                deviceMediaName = self.mediaName;
            }
        }
        else if (self.isNetwork)
        {
            deviceMediaName = self.volumeNetworkPath;
        }
    }
    return deviceMediaName;
}

- (NSInteger)mountFlags
{
    if (mountFlags == 0)
    {
        struct statfs fsStat;
        int statRes = statfs(self.volumePath.UTF8String, &fsStat);
        if (statRes == 0)
        {
            mountFlags = fsStat.f_flags;
        }
    }
    return mountFlags;
}

- (NSDictionary *)mountFlagsInfo
{
    NSDictionary *descriptionDictionary =
        @{
            @"MNT_RDONLY":     (self.mountFlags & MNT_RDONLY) == MNT_RDONLY ?      @"YES" : @"NO",
            @"MNT_SYNCHRONOUS":     (self.mountFlags & MNT_SYNCHRONOUS) == MNT_SYNCHRONOUS ?      @"YES" : @"NO",
            @"MNT_NOEXEC":     (self.mountFlags & MNT_NOEXEC) == MNT_NOEXEC ?      @"YES" : @"NO",
            @"MNT_NOSUID":     (self.mountFlags & MNT_NOSUID) == MNT_NOSUID ?      @"YES" : @"NO",
            @"MNT_NODEV":     (self.mountFlags & MNT_NODEV) == MNT_NODEV ?      @"YES" : @"NO",
            @"MNT_UNION":     (self.mountFlags & MNT_UNION) == MNT_UNION ?      @"YES" : @"NO",
            @"MNT_ASYNC":     (self.mountFlags & MNT_ASYNC) == MNT_ASYNC ?      @"YES" : @"NO",
            @"MNT_CPROTECT":     (self.mountFlags & MNT_CPROTECT) == MNT_CPROTECT ?      @"YES" : @"NO",
            @"MNT_EXPORTED":     (self.mountFlags & MNT_EXPORTED) == MNT_EXPORTED ?      @"YES" : @"NO",
            @"MNT_REMOVABLE":     (self.mountFlags & MNT_REMOVABLE) == MNT_REMOVABLE ?      @"YES" : @"NO",
            @"MNT_QUARANTINE":     (self.mountFlags & MNT_QUARANTINE) == MNT_QUARANTINE ?      @"YES" : @"NO",
            @"MNT_LOCAL":     (self.mountFlags & MNT_LOCAL) == MNT_LOCAL ?      @"YES" : @"NO",
            @"MNT_QUOTA":     (self.mountFlags & MNT_QUOTA) == MNT_QUOTA ?      @"YES" : @"NO",
            @"MNT_ROOTFS":     (self.mountFlags & MNT_ROOTFS) == MNT_ROOTFS ?      @"YES" : @"NO",
            @"MNT_DOVOLFS":     (self.mountFlags & MNT_DOVOLFS) == MNT_DOVOLFS ?      @"YES" : @"NO",
            @"MNT_DONTBROWSE":     (self.mountFlags & MNT_DONTBROWSE) == MNT_DONTBROWSE ?      @"YES" : @"NO",
            @"MNT_IGNORE_OWNERSHIP":     (self.mountFlags & MNT_IGNORE_OWNERSHIP) == MNT_IGNORE_OWNERSHIP ?      @"YES" : @"NO",
            @"MNT_AUTOMOUNTED":     (self.mountFlags & MNT_AUTOMOUNTED) == MNT_AUTOMOUNTED ?      @"YES" : @"NO",
            @"MNT_JOURNALED":     (self.mountFlags & MNT_JOURNALED) == MNT_JOURNALED ?      @"YES" : @"NO",
            @"MNT_NOUSERXATTR":     (self.mountFlags & MNT_NOUSERXATTR) == MNT_NOUSERXATTR ?      @"YES" : @"NO",
            @"MNT_DEFWRITE":     (self.mountFlags & MNT_DEFWRITE) == MNT_DEFWRITE ?      @"YES" : @"NO",
            @"MNT_MULTILABEL":     (self.mountFlags & MNT_MULTILABEL) == MNT_MULTILABEL ?      @"YES" : @"NO",
            @"MNT_NOFOLLOW":     (self.mountFlags & MNT_NOFOLLOW) == MNT_NOFOLLOW ?      @"YES" : @"NO",
            @"MNT_NOATIME":     (self.mountFlags & MNT_NOATIME) == MNT_NOATIME ?      @"YES" : @"NO",
            @"MNT_SNAPSHOT":     (self.mountFlags & MNT_SNAPSHOT) == MNT_SNAPSHOT ?      @"YES" : @"NO",
            @"MNT_STRICTATIME":     (self.mountFlags & MNT_STRICTATIME) == MNT_STRICTATIME ?      @"YES" : @"NO",
            @"MNT_UPDATE":     (self.mountFlags & MNT_UPDATE) == MNT_UPDATE ?      @"YES" : @"NO",
            @"MNT_NOBLOCK":     (self.mountFlags & MNT_NOBLOCK) == MNT_NOBLOCK ?      @"YES" : @"NO",
            @"MNT_RELOAD":     (self.mountFlags & MNT_RELOAD) == MNT_RELOAD ?      @"YES" : @"NO",
            @"MNT_FORCE":     (self.mountFlags & MNT_FORCE) == MNT_FORCE ?      @"YES" : @"NO",
        };
    return descriptionDictionary;
}

#pragma mark -

- (NSDictionary *)diskDescription
{
    if (diskDescription == nil)
    {
        diskDescription = (NSDictionary *)CFBridgingRelease(DADiskCopyDescription(self.diskRef));
    }
    return diskDescription;
}

- (NSString *)parentMediaName
{
    if (self.isWholeDisk)
    {
        return nil;
    }

    if (parentMediaName == nil)
    {
        DADiskRef parentRef = DADiskCopyWholeDisk(self.diskRef);
        if (parentRef)
        {
            NSDictionary *parentDescription =
                (NSDictionary *)CFBridgingRelease(DADiskCopyDescription(parentRef));

            parentMediaName = [parentDescription objectForKey:(NSString *)kDADiskDescriptionMediaNameKey];

            CFRelease(parentRef);
        }
    }
    return parentMediaName;
}

@end
