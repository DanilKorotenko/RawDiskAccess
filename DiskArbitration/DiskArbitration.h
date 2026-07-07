//
//  DiskArbitration.h
//

#pragma once

#import <CoreFoundation/CoreFoundation.h>

#import "Disk.h"

////////////////////////////////////////////////////////////////////////////////

#ifdef __cplusplus
  extern "C" {
#endif

void DASetLogBlock(void (^block)(const char *aLogMessage));
void DASetDiskMountedBlock(void (^block)(DiskRef aDisk));
void DASetDiskInsertedBlock(void (^block)(DiskRef aDisk));
void DASetDiskDisappearedBlock(void (^block)(DiskRef aDisk));

void DAStartListenToDiskArbitration();
void DAStopListenToDiskArbitration();

void DAWaitUntilDiskArbitrationIsRunning();

#pragma mark -

void DAEnumerateValidForProcessingDisksWithBlock(void (^block)(DiskRef aDisk));

#pragma mark -

DiskRef DACopyMountPointDiskForPath(CFStringRef aPath);

#pragma mark -

bool DAIsAnyDiskMounted();

#ifdef __cplusplus
  }
#endif
