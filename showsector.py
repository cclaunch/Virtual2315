#
# utility program to read a Virtual 2315 Cartridge Facility file
# and display a chosen sector
#
#
# written by Carl V Claunch, available under MIT license

from tkinter import Tk
from tkinter import filedialog as fd
from tkinter import simpledialog
import sys

def select_file():
    filetypes = (
        ('Disk files', '*.dsk'),
        ('All files', '*.*')
    )

    filehandle = fd.askopenfile(
        mode = 'rb',
        title='Open Virtual 2315 Cartridge Facility disk file',
        initialdir='.',
        filetypes=filetypes,
        parent=root)
    return filehandle

try:

    root = Tk()
    root.attributes('-topmost', True)
    root.iconify()
    root.update_idletasks()  # Ensure window is ready

    print('Program to display a sector from a file in the')
    print('format used by the Virtual 2315 Cartridge Facility')
    print('')
        
    sf = select_file()
    if (sf == None):
        print('No input file selected, quitting')
        sys.exit(1)

    sf.seek(0, 2)
    if (sf.tell() != (1042973)):
        print('File is not the correct size, quitting')
        sf.close()
        sys.exit(1)
    sf.seek(0, 0)

    header = sf.read(1)
    if (header != b'\x89'):
        print ('wrong magic word in file', header, ', quitting')
        sf.close()
        sys.exit(1)

    header = sf.read(9)
    if (header != b'2315\r\n\x1a\x00\x00'):
        print('The header we read was', header, ', not the correct one, quitting')
        sf.close()
        sys.exit(1)
        
    header = sf.read(4)
    if (header != b'1.3\x00'):
        print('wrong version', header, ', quitting')
        sf.close()
        sys.exit(1)
        
    header = sf.read(11)
    print('Cartridge number is',header.decode("utf-8").rstrip('\x00'))

    header = sf.read(200)
    print('Description is',header.decode("utf-8").rstrip('\x00'))

    header = sf.read(20)
    print('Date of the file is',header.decode("utf-8"))

    header = sf.read(100)
    print('Controller for the disk drive is',header.decode("utf-8").rstrip('\x00'))

    header = sf.read(4)
    print('Bit rate is',format(int.from_bytes(header, "big"), ","))

    header = sf.read(4)
    print('Number of cylinders is',int.from_bytes(header, "big"))

    header = sf.read(4)
    print('Number of sectors per rotation is',int.from_bytes(header, "big"))

    header = sf.read(4)
    print('Number of heads is', int.from_bytes(header, "big"))

    header = sf.read(4)
    print('uSeconds in a sector is', format(int.from_bytes(header, "big"), ","))

    print ("Header verified")

    cyl = -999
    while (cyl == -999):
        cyl = simpledialog.askinteger("Input", "Cylinder number:",parent=root)

    head = -999
    while (head == -999):
        head = simpledialog.askinteger("Input", "Head number:",parent=root)

    sector = -999
    while (sector == -999):
        sector = simpledialog.askinteger("Input", "Sector number:",parent=root)

    root.destroy()

    if (sector < 0 or sector > 3):
        print('Invalid sector number (0 to 3)')
        sf.close()
        sys.exit(1)

    if (head < 0 or head > 1):
        print('Invalid head number (0 or 1)')
        sf.close()
        sys.exit(1)

    if (cyl < 0 or cyl > 202):
        print('Invalid cylinder number (0 to 202)')
        sf.close()
        sys.exit(1)

    skip = (cyl*8) + (head*4) + sector

    sf.seek((skip*642),1)

    print ("Displaying sector at","cylinder",cyl,"- hex",f"{cyl:#0{6}X}".replace("X","x"),"-","head",head,"sector",sector)

    for addr in range(321):
        if (addr == 0):
            print(f"{addr:#0{6}X}".replace("X","x")," ",f"{(int.from_bytes(sf.read(2), "little")):#0{6}X}".replace("X","x"))
        elif (addr == 320):
            print(f"{addr:#0{6}X}".replace("X","x")," ",f"{(int.from_bytes(sf.read(2), "little")):#0{6}X}".replace("X","x"))        
        elif (addr % 4 == 0):
            print(f"{addr:#0{6}X}".replace("X","x")," ",f"{(int.from_bytes(sf.read(2), "little")):#0{6}X}".replace("X","x")," ",f"{(int.from_bytes(sf.read(2), "little")):#0{6}X}".replace("X","x")," ",f"{(int.from_bytes(sf.read(2), "little")):#0{6}X}".replace("X","x")," ",f"{(int.from_bytes(sf.read(2), "little")):#0{6}X}".replace("X","x"))
            
    sf.close()

except SystemExit:
    print('Quitting with error')
    pass
