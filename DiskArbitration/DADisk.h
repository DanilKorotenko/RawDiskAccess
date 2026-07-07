//
//  DADisk.h
//

#import <Cocoa/Cocoa.h>

#import "DiskTypes.h"

@interface DADisk : NSObject

+ (NSString *_Nullable)volumePathForDisk:(DADiskRef _Nonnull)aDisk;
+ (void)enumerateUniqueDisksWithBlock:
    (void (^_Nullable)(DADisk * _Nullable aDisk, BOOL * _Nullable aStop))anEnumerationBlock;

#pragma mark -

+ (DADisk *_Nonnull)uniqueDiskForDADisk:(DADiskRef _Nonnull)diskRef mountPath:(NSString * _Nonnull)aMountPath;
+ (DADisk *_Nullable)uniqueDiskForPath:(NSString * _Nullable)aPath;

+ (DADisk *_Nonnull)extractDiskForDADisk:(DADiskRef _Nonnull)aDiskRef;

#pragma mark -

@property (readonly) BOOL isWholeDisk;
@property (readonly) BOOL isMounted;
@property (readonly) BOOL isLeaf;

@property (readonly) DiskType type;

@property (readonly) BOOL isValidForProcessing;

@property (readonly) NSString * _Nullable volumeUUID;

// The custom property that returns volume UUID by default.
// But if volume UUID is empty, and this volume is NTFS,
// the property returns media UUID.
@property (readonly) NSString * _Nullable uuid;

@property (readonly) NSString * _Nullable volumePath;
@property (readonly) NSString * _Nullable volumeNetworkPath; // Only avaliable if type is DiskTypeNetwork

@property (readonly) NSString * _Nullable deviceMediaName;

@end
