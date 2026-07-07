//
//  main.cpp
//  RawDiskAccess
//
//  Created by Danil Korotenko on 7/6/26.
//

#include <iostream>

#include "../DiskArbitration/DiskArbitration.h"

#include <dispatch/dispatch.h>

int main(int argc, const char * argv[])
{
    std::cout << "Hello, World!" << std::endl;

    DASetLogBlock(
        ^(const char *aLogMessage)
        {
            std::cout << aLogMessage << std::endl;
        });

    DASetDiskMountedBlock(
        ^(DiskRef aDisk)
        {
            std::string uuid = DiskGetUUID(aDisk);
            std::cout << uuid << std::endl;
        });

    DAStartListenToDiskArbitration();

//    std::string windowsSerial;
//    std::string errorDescription;
//
//    std::string volumeDevicePath = "/dev/disk4s2";
//
//    bool result = readWindowsSerialForVolumeDev(volumeDevicePath, windowsSerial, errorDescription);
//    if (!result)
//    {
//        std::cout << "Error on obtaining windows serial from volume: " << volumeDevicePath
//            << " Error: " << errorDescription << std::endl;
//    }

    dispatch_main();

    return EXIT_SUCCESS;
}
