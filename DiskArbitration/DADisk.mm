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

@property (readonly) NSDictionary *diskDescription;

@property (readonly) NSString *  parentMediaName;
@property (readonly) NSString *  mediaName;
@property (readonly) NSString *  mediaUUID;
@property (readonly) NSString *  mediaContentUUID;
@property (readonly) NSString * _Nullable volumeUUID;
@property (readonly) NSString *  deviceProtocol;
@property (readonly) NSString *  mediaKind;
@property (readonly) NSString *  volumeKind;

@property (readonly) DADiskRef   diskRef;

@property (readonly) NSInteger   mountFlags;

@property (readonly) DADisk *    parentDisk;

@property (readonly) NSString * _Nullable bsdName;
@property (readonly) NSString *  parentBsdName;

@property (readonly) NSDictionary *ioMediaProperties;
@property (readonly) NSInteger  offset;

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
@synthesize parentDisk;
@synthesize bsdName;
@synthesize parentBsdName;
@synthesize ioMediaProperties;
@synthesize offset;
@synthesize volumeSerialWin;

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

#pragma mark Public Properties

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

- (BOOL)isValidForProcessing
{
    return self.isValidRemovable || self.isValidNetwork;
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
        uuid = self.volumeSerialWin;
        if ([uuid length] == 0)
        {
            uuid = self.volumeUUID;
        }
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

/*
With FAT32 volumes, the Volume Serial Number is stored in the Boot Sector at offset 67 (0x43), and is four bytes long.
https://apple.stackexchange.com/questions/408562/how-can-i-get-the-volume-serial-number-of-a-fat-volume
https://www.digital-detective.net/documents/Volume%20Serial%20Numbers.pdf

In this method, we read root dev, and offseting to this partition. We cannot directly read from this partition device,
because it is mounted and always busy.
*/
- (NSString *)volumeSerialWin
{
    if (nil == volumeSerialWin)
    {
        NSString *parentDevPath = [NSString stringWithFormat:@"/dev/%@", self.parentBsdName];
        int fd = open(parentDevPath.UTF8String, O_RDONLY);
        if (fd < 0)
        {
            NSString *error = [NSString stringWithUTF8String:strerror(errno)];
            NSLog(@"%@", error);
            return nil;
        }

        int64_t bytesToRead = self.volumeSerialNumberLength;

        void *buffer = malloc(bytesToRead);
        if (buffer == NULL)
        {
            close(fd);
            return nil;
        }

        int64_t offset = self.offset + self.volumeSerialNumberOffset;

        if (lseek(fd, offset, SEEK_SET) == -1)
        {
            free(buffer);
            close(fd);
            return nil;
        }

        ssize_t bytesRead = read(fd, buffer, bytesToRead);
        if (bytesRead > 0)
        {
            unsigned char* hexPtr = reinterpret_cast<unsigned char*>(buffer);

            NSMutableString *serial = [NSMutableString string];

            for (int64_t i = bytesRead-1; i >= 0; i--)
            {
                [serial appendFormat:@"%02X", hexPtr[i]];
            }

            volumeSerialWin = [NSString stringWithString:serial];
        }

        free(buffer);
        close(fd);
    }
    return volumeSerialWin;
}

#pragma mark Public Methods

- (BOOL)isEqualToDADisk:(_Nonnull DADiskRef)aDiskRef
{
    return self.diskRef == aDiskRef;
}

#pragma mark Private Properties

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
        parentMediaName = self.parentDisk.mediaName;
    }
    return parentMediaName;
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

- (DADisk *)parentDisk
{
    if (nil == parentDisk)
    {
        DADiskRef parentRef = DADiskCopyWholeDisk(self.diskRef);
        if (parentRef)
        {
            parentDisk = [[DADisk alloc] initWithDADisk:parentRef];
            CFRelease(parentRef);
        }
    }
    return parentDisk;
}

- (NSString *)bsdName
{
    if (nil == bsdName)
    {
        bsdName = [NSString stringWithUTF8String:DADiskGetBSDName(self.diskRef)];
    }
    return bsdName;
}

- (NSString *)parentBsdName
{
    if (nil == parentBsdName)
    {
        parentBsdName = self.parentDisk.bsdName;
    }
    return parentBsdName;
}

- (NSDictionary *)ioMediaProperties
{
    if (nil == ioMediaProperties)
    {
        io_service_t io = DADiskCopyIOMedia(self.diskRef);
        CFMutableDictionaryRef ioDict = NULL;
        if (IORegistryEntryCreateCFProperties(io, &ioDict, kCFAllocatorDefault, 0) == kIOReturnSuccess)
        {
            ioMediaProperties = (NSDictionary *)CFBridgingRelease(ioDict);
        }
        IOObjectRelease(io);
    }
    return ioMediaProperties;
}

- (NSInteger)offset
{
    if (0 == offset)
    {
        NSNumber *offsetNum = [self.ioMediaProperties objectForKey:@"Base"];
        offset = offsetNum.integerValue;
    }
    return offset;
}

/*
https://elm-chan.org/docs/exfat_e.html
https://elm-chan.org/docs/fat_e.html
https://ntfs.com/ntfs-partition-boot-sector.htm
*/
- (NSInteger)volumeSerialNumberOffset
{
    static NSDictionary *offsets = nil;
    if (offsets == nil)
    {
        offsets = @{
            @"exfat": @100,
            @"fat32": @67, // FAT32
            @"msdos": @67, // FAT32
            @"ntfs" : @72
        };
    }
    NSNumber *offsetNum = offsets[self.volumeKind];
    return offsetNum != nil ? offsetNum.integerValue : 0; ;
}

- (NSInteger)volumeSerialNumberLength
{
    static NSDictionary *lengths = nil;
    if (lengths == nil)
    {
        lengths = @{
            @"exfat": @4,
            @"fat32": @4, // FAT32
            @"msdos": @4, // FAT32
            @"ntfs" : @8
        };
    }
    NSNumber *lengthNum = lengths[self.volumeKind];
    return lengthNum != nil ? lengthNum.integerValue : 0; ;
}

@end
