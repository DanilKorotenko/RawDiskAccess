//
//  RawPartition.cpp
//  RawDiskAccess
//
//  Created by Danil Korotenko on 7/6/26.
//

#include "readWindowsSerial.hpp"

#include <DiskArbitration/DADisk.h>

bool readWindowsSerialForVolumeDev(const std::string &aVolumeDevPath, std::string &anOutSerial, std::string &anOutError)
{
    bool result = false;

    DASessionRef session = NULL;
    DADiskRef disk = NULL;
    CFDictionaryRef descDict = NULL;

    do
    {
        session = DASessionCreate(kCFAllocatorDefault);
        if (NULL == session)
        {
            anOutError = "Unable to dreate DA session.";
            result =  false;
            break;
        }

        disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, aVolumeDevPath.c_str());
        if (NULL == disk)
        {
            anOutError = "Unable to create DA disk";
            result = false;
            break;
        }

        descDict = DADiskCopyDescription(disk);
        if (NULL == descDict)
        {
            anOutError = "Unable to get DA disk description";
            result = false;
            break;
        }


    }
    while (false);

    if (NULL != descDict)
    {
        CFRelease(descDict);
    }

    if (NULL != disk)
    {
        CFRelease(disk);
    }

    if (NULL != session)
    {
        CFRelease(session);
    }

    return result;
}
