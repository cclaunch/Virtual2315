#
# utility program to read through a chosen directory (folder)
# to list all Virtual 2315 Cartridge Facility files
#
# displays filename, cartridge ID and description for each valid file
#
#
# written by Carl V Claunch, available under MIT license

from tkinter import Tk
from tkinter import filedialog as fd
import sys
import os

def select_folder():
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

def checkfile(path, fn):
    combined = path + '/' + fn
    sf = open (combined,'rb')
    sf.seek(0, 2)
    if (sf.tell() != 1042973):
        sf.close()
        return
    sf.seek(0, 0)
    header = sf.read(1)
    if (header != b'\x89'):
        sf.close()
        return
    header = sf.read(9)
    if (header != b'2315\r\n\x1a\x00\x00'):
        sf.close()
        return    
    header = sf.read(4)
    if (header != b'1.3\x00'):
        sf.close()
        return
    cartnum = sf.read(11)
    desc = sf.read(200)
    print('Cartridge number',cartnum.decode("utf-8").rstrip('\x00'),'File',fn)
    print('Description:',desc.decode("utf-8").rstrip('\x00'))
    print ('')

    sf.close()
    return

root = Tk()
root.attributes('-topmost', True)
root.iconify()
root.update_idletasks()  # Ensure window is ready

print ('Lists all Virtual 2315 Cartridge Facility files')
print('in a directory/fold you select')
print('')

folder_path = fd.askdirectory()

if folder_path:
    print("Selected folder:", folder_path)
    os.chdir(folder_path) # Change the current directory to the selected folder
else:
    print("No folder selected.")
    sys.exit(1)
print ('')

try:
    files = os.listdir(folder_path)
except FileNotFoundError:
    print("Directory not selected.")
    sys.exit(1)

print("Virtual 2315 Cartridge files:")
for file in files:
    filename, file_extension = os.path.splitext(file)
    if (file_extension != '.dsk'):
        continue
    checkfile(folder_path,file)
    
print ('')
print ('End of Listing')
sys.exit(0)
