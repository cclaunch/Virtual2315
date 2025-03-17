This project allows an IBM 1130 to protect the rare disk heads and physical 2315 disk cartridges from crashes, while still making use of the disk drive and experiencing the sounds and vibrations associated with the drive.

A file with the contents of a 2315 disk cartridge is stored on a microSD card inside a holder that looks like a miniature 2315. The project loads the content of the file into RAM when the cartridge is 'loaded', writing back the contents of RAM to the file when unloaded.

A switch and small physical modification to the drive allows it to be switched between real and virtual mode, where the drive spins a dummy cartridge and operates in conjuction with this project or the drive is left off for pure virtual mode.

Disk heads remain above the surface in either mode and our facility generates the bit stream that would come from the head during a read and grabbing new data that is sent to the drive during a write, updating the RAM contents and eventually the file. 
