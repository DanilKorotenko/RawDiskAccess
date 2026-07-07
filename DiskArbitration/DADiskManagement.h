//
//  DADiskManagement.h
//

#import <Cocoa/Cocoa.h>

#import "DADisk.h"
#import "DiskTypes.h"

@interface DADiskManagement : NSObject

+ (NSString *_Nullable)volumePathForDisk:(DADiskRef _Nonnull)aDisk;
+ (void)enumerateUniqueDisksWithBlock:
    (void (^_Nullable)(DADisk * _Nullable aDisk, BOOL * _Nullable aStop))anEnumerationBlock;

#pragma mark -

+ (DADisk *_Nonnull)uniqueDiskForDADisk:(DADiskRef _Nonnull)diskRef mountPath:(NSString * _Nonnull)aMountPath;
+ (DADisk *_Nullable)uniqueDiskForPath:(NSString * _Nullable)aPath;

+ (DADisk *_Nonnull)extractDiskForDADisk:(DADiskRef _Nonnull)aDiskRef;

@end
