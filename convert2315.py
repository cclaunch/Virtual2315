#
# converter program to read a Virtual 2315 Cartridge Facilityfile
# and convert it for use with the IBM 1130 simulator. The files
# have an extension of .dsk and are chosen by file dialogs.
#
#
# written by Carl V Claunch, available under MIT license

from tkinter import Tk
from tkinter import filedialog as fd
import sys

def select_file():
    filetypes = (
        ('Disk files', '*.dsk'),
        ('All files', '*.*')
    )

    root = Tk()
    root.attributes('-topmost', True)
    root.iconify()
    filehandle = fd.askopenfile(
        mode = 'rb',
        title='Open Virtual 2315 Cartridge Facility disk file',
        initialdir='.',
        filetypes=filetypes,
        parent=root)
    root.destroy()
    return filehandle

def save_file():
    root = Tk()
    root.attributes('-topmost', True)
    root.iconify()
    save_file_as = fd.asksaveasfile(
        mode='wb',
        defaultextension='.dsk',
        title='Select new 1130 Simulator disk file',
        initialdir='.',
        parent=root)
    root.destroy()
    return save_file_as

print('Program to convert a Virtual 2315 Cartridge Facility file')
print('to the format used by the IBM 1130 Simulator')
print('')
    
sf = select_file()
if (sf == None):
    print('No input file selected, quitting')
    sys.exit(1)

sf.seek(0, 2)
if (sf.tell() != 1042973):
    print('File is ',sf.tell(),' not the correct size, quitting')
    sf.close()
    sys.exit(1)
sf.seek(0, 0)

ef = save_file()
if (ef == None):
    print('No output file selected, quitting')
    sf.close()
    sys.exit(1)

header = sf.read(1)
if (header != b'\x89'):
    print ('wrong magic word in file', header, ', quitting')
    sf.close()
    ef.close()
    sys.exit(1)

header = sf.read(9)
if (header != b'2315\r\n\x1a\x00\x00'):
    print('The header we read was', header, ', not the correct one, quitting')
    sf.close()
    ef.close()
    sys.exit(1)
    
header = sf.read(4)
if (header != b'1.3\x00'):
    print('wrong version', header, ', quitting')
    sf.close()
    ef.close()
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

print('')

print ("Header verified")

for cyl in range(203):
    for head in range(2):
        for sector in range (4):
            for word in range(321):
                ef.write(sf.read(1))
                ef.write(sf.read(1))

ef.close()
sf.close()
print ('Conversion complete')
print('')
print('Put the output file on a microSD card and')
print('insert it into the Virtual 2315 Cartridge Facility')
