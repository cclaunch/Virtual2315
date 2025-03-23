#
# converter program to read an IBM 1130 simulator file named 1130.dsk and convert
# it for use with the Virtual 2315 Cartridge Facility, naming the file 2315.dsk
#
# written by Carl V Claunch, available under MIT license
#
from tkinter import Tk
from tkinter import filedialog as fd
from tkinter import simpledialog
import sys
from datetime import datetime

def select_file():
    filetypes = (
        ('Disk files', '*.dsk'),
        ('All files', '*.*')
    )

    filehandle = fd.askopenfile(
        mode = 'rb',
        title='Open 1130 Simulator disk file',
        initialdir='.',
        filetypes=filetypes,
        parent=root)
    return filehandle

def save_file():
    save_file_as = fd.asksaveasfile(
        mode='wb',
        defaultextension='.dsk',
        title='Select Virtual 2315 Cartridge Facility output disk file',
        initialdir='.',
        parent=root)
    return save_file_as

def testhex(achar):
    if achar in '0123456789abcdefABCDEF':
        return True
    return False

root = Tk()
root.attributes('-topmost', True)
root.iconify()
root.update_idletasks()  # Ensure window is ready

print('Program to convert an IBM 1130 Simulator disk file')
print('to the format used by the Virtual 2315 Cartridge Facility')
print('')

getdate = datetime.today()
datetuple = getdate.utctimetuple()

datestring = f"{datetuple[0]:4d}-{datetuple[1]:02d}-{datetuple[2]:02d} {datetuple[3]:02d}:{datetuple[4]:02d}:{datetuple[5]:02d}"

sf = select_file()
if (sf == None):
    print('No input file selected, quitting')
    sys.exit(1)

sf.seek(0, 2)
if (sf.tell() != (203*8*321*2)):
    print('File is not the correct size, quitting')
    sf.close()
    sys.exit(1)
sf.seek(0, 0)

ef = save_file()
if (ef == None):
    print('No output file selected, quitting')
    sf.close()
    sys.exit(1)

#                                             magic number 10 bytes null terminated 8b string
ef.write(b'\x89')
ef.write(bytearray('2315\r\n','utf-8'))
ef.write(b'\x1A\x00\x00')
#                                             version number 4 bytes null terminated 3b string
ef.write(bytearray('1.3','utf-8'))
ef.write(b'\x00')

# get the desired cartridge number
cart = None
while (cart == None):
    cart = simpledialog.askstring("Input", "Cartridge number four characters x0001 to x7fff:",parent=root)
    if cart == None:
        continue
    if (len(cart) != 4):
        print ('must be four characters long')
        cart = None
        continue
    if (testhex(cart[0:1]) & testhex(cart[1:2]) & testhex(cart[2:3]) & testhex(cart[3:4])):
        if (cart[0:1] in '89abcdefABCDEF'):
            print ('first digit must be 0 to 7')
            cart = None
            continue
        if (cart == '0000'):
            print ('cannot be 0000');
            cart = None
            continue
        continue
    print ('invalid hex characters, try again')
    cart = None

b = bytearray()
b.extend(map(ord,cart.upper()))


#                                             cartridge ID 11 byte, 4 b null terminated
ef.write(b)
ef.write(b'\x00')
ef.write(b'\x00\x00\x00\x00\x00\x00')

desc = None
while (desc == None):
    desc = simpledialog.askstring("Input", "Description of cartridge:",parent=root)
    if cart == None:
        continue
    if len(cart) > 199:
        print ('must be less than 200 characters')
        desc = None
        continue
    b = bytearray(desc,'utf-8')
    

#                                             description 200 byte 16b null terminated
ef.write(b)
remainder = 200 - len(desc)
ef.write(b'\x00'*remainder)
#                                             date and time created 20 bytes 19b null terminated
ef.write(bytearray(datestring,'utf-8'))
ef.write(b'\x00')
#                                             controller field 100 byte 29b null terminated
ef.write(bytearray('1130 internal disk controller','utf-8'))
ef.write(b'\x00'*71)
#                                             bit rate int 4b
ef.write(b'\x00\x0a\xfc\x80')
#                                             cylinders int 4b
ef.write(b'\x00\x00\x00\xcb')
#                                             sectors per track int 4b
ef.write(b'\x00\x00\x00\x08')
#                                             heads per cylinder int 4b
ef.write(b'\x00\x00\x00\x02')
#                                             uSec per sector int 4b
ef.write(b'\x00\x00\x27\x10')

print ("header written")

for cyl in range(203):
    for head in range(2):
        for sector in range (4):
            for word in range(321):
                ef.write(sf.read(1))
                ef.write(sf.read(1))

ef.close()
sf.close()
print ('conversion complete')
print('')
print('Put the output file on a microSD card and')
print('insert it into the Virtual 2315 Cartridge Facility')
