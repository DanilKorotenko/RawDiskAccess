//
//  Disk.hpp
//
//  Created by Danil Korotenko on 7/23/20.
//

#pragma once

#include "DiskTypes.h"

#ifdef __cplusplus
#include <string>
  extern "C" {
#endif

typedef struct
{
    void *_dadisk;
} Disk;

typedef Disk* DiskRef;

DiskRef DiskCreateWithDADisk(void *aDaDisk);
void DiskReleaseAndMakeNull(DiskRef *aDisk);

#pragma mark -

// Is disk already mounted?
bool DiskGetIsMounted(DiskRef aDisk);

DiskType DiskGetType(DiskRef aDisk);

#ifdef __cplusplus
  }

std::string DiskGetUUID(DiskRef aDisk);
std::string DiskGetVolumeMountPath(DiskRef aDisk);
std::string DiskGetDeviceMediaName(DiskRef aDisk);
std::string DiskGetVolumeSerialWin(DiskRef aDisk);

#endif // __cplusplus
