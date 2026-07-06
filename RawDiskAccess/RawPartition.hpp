//
//  RawPartition.hpp
//  RawDiskAccess
//
//  Created by Danil Korotenko on 7/6/26.
//

#pragma once

#include <stdio.h>
#include <string>

bool readWindowsSerialForVolumeDev(const std::string &aVolumeDevPath, std::string &anOutSerial, std::string &anOutError);
