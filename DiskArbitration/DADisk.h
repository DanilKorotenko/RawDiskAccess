//
//  DADisk.h
//

#import <Cocoa/Cocoa.h>

#import "DiskTypes.h"

@interface DADisk : NSObject

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

@property (readonly) NSInteger  offset;

- (_Nullable id)initWithDADisk:(_Nonnull DADiskRef)diskRef;

- (BOOL)isEqualToDADisk:(_Nonnull DADiskRef)aDiskRef;

@end
