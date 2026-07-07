//
//  main.cpp
//  RawDiskAccess
//
//  Created by Danil Korotenko on 7/6/26.
//

#include <iostream>

#include "readWindowsSerial.hpp"

int main(int argc, const char * argv[])
{
    std::cout << "Hello, World!" << std::endl;

    std::string windowsSerial;
    std::string errorDescription;

    std::string volumeDevicePath = "/dev/disk4s2";

    bool result = readWindowsSerialForVolumeDev(volumeDevicePath, windowsSerial, errorDescription);
    if (!result)
    {
        std::cout << "Error on obtaining windows serial from volume: " << volumeDevicePath
            << " Error: " << errorDescription << std::endl;
    }

    return EXIT_SUCCESS;
}
