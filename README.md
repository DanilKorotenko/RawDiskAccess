# RawDiskAccess

This project is dedicated to solve the task to find Windows volume serial number.

MacOS uses UUID to identify volumes. At the same time, Windows, uses serial.

More info:
https://apple.stackexchange.com/questions/408562/how-can-i-get-the-volume-serial-number-of-a-fat-volume

https://www.digital-detective.net/documents/Volume%20Serial%20Numbers.pdf

For FAT32 volumes, the Volume Serial Number is stored in the Boot Sector at offset 67 (0x43), and is 4 bytes long.

So it only need to read this serial. 

But the volume is already mounted and it always busy.

So it is needed to read parent disk, which is not busy:
 - Find partition offset
 - seek to this offset
 - read 4 bytes from byte 67 
