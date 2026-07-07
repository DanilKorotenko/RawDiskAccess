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

//    DASetLogBlock(
//        ^(const char *aLogMessage)
//        {
//            std::cout << aLogMessage << std::endl;
//        });

    DASetDiskMountedBlock(
        ^(DiskRef aDisk)
        {
            std::string uuid = DiskGetUUID(aDisk);
            std::cout << uuid << std::endl;

            std::string volumeSerialWin = DiskGetVolumeSerialWin(aDisk);

            std::cout << volumeSerialWin << std::endl;
        });

    DAStartListenToDiskArbitration();

    dispatch_main();

    return EXIT_SUCCESS;
}
