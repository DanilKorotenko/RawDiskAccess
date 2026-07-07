//
//  DiskArbitrationController.h
//
//  Created by Danil Korotenko on 6/2/20.
//

#import <Foundation/Foundation.h>

#import "Disk.h"
#import "DADisk.h"

NS_ASSUME_NONNULL_BEGIN

@interface DiskArbitrationController : NSObject

// singleton instance
+ (DiskArbitrationController *)sharedController;

@property (strong) void (^logBlock)(const char *aLogMessage);
@property (strong) void (^diskMountedBlock)(DiskRef aDisk);
@property (strong) void (^diskInsertedBlock)(DiskRef aDisk);
@property (strong) void (^diskDisappearedBlock)(DiskRef aDisk);

- (void)start;
- (void)stop;
- (void)waitUntilIsRunning;

@end

NS_ASSUME_NONNULL_END
