//
//  Disk.cpp
//
//  Created by Danil Korotenko on 7/23/20.
//

#include "Disk.h"

#import "DADisk.h"

#import "NSString+SafeUTF8String.h"
#include <string>

DiskRef DiskCreateWithDADisk(void *aDaDisk)
{
    DiskRef disk = (DiskRef)malloc(sizeof(Disk));
    id daDisk = (__bridge id)aDaDisk;
    disk->_dadisk = (__bridge_retained void *)daDisk;
    return disk;
}

void DiskReleaseAndMakeNull(DiskRef *aDisk)
{
    if (aDisk == NULL || *aDisk == NULL)
    {
        return;
    }

    if ((*aDisk)->_dadisk != NULL)
    {
        (void)(__bridge_transfer DADisk *)(*aDisk)->_dadisk;
        (*aDisk)->_dadisk = NULL;
    }

    free(*aDisk);
    *aDisk = NULL;
}

#pragma mark -

std::string DiskGetUUID(DiskRef aDisk)
{
    std::string result;
    @autoreleasepool
    {
        if (aDisk == NULL || aDisk->_dadisk == NULL)
        {
            return result;
        }
        DADisk *daDisk = (__bridge DADisk *)aDisk->_dadisk;
        result = GetSafeUTF8String(daDisk.uuid);
    }
    return result;
}

std::string DiskGetVolumeMountPath(DiskRef aDisk)
{
    std::string result;
    @autoreleasepool
    {
        if (aDisk == NULL || aDisk->_dadisk == NULL)
        {
            return result;
        }
        DADisk *daDisk = (__bridge DADisk *)aDisk->_dadisk;
        result = GetSafeUTF8String(daDisk.volumePath);
    }
    return result;
}

std::string DiskGetDeviceMediaName(DiskRef aDisk)
{
    std::string result;
    @autoreleasepool
    {
        if (aDisk == NULL || aDisk->_dadisk == NULL)
        {
            return result;
        }
        DADisk *daDisk = (__bridge DADisk *)aDisk->_dadisk;
        result = GetSafeUTF8String(daDisk.deviceMediaName);
    }
    return result;
}

bool DiskGetIsMounted(DiskRef aDisk)
{
    bool result = false;
    @autoreleasepool
    {
        if (aDisk == NULL || aDisk->_dadisk == NULL)
        {
            return false;
        }
        DADisk *daDisk = (__bridge DADisk *)aDisk->_dadisk;
        result = daDisk.isMounted ? true : false;
    }
    return result;
}

DiskType DiskGetType(DiskRef aDisk)
{
    DiskType result = DiskTypeLocalDrive;
    @autoreleasepool
    {
        if (aDisk == NULL || aDisk->_dadisk == NULL)
        {
            return result;
        }
        DADisk *daDisk = (__bridge DADisk *)aDisk->_dadisk;
        result = daDisk.type;
    }
    return result;
}
