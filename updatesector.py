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
from PySide6.QtWidgets import QApplication, QTableWidget, QLineEdit, QTableWidgetItem, QStyledItemDelegate,  QVBoxLayout, QWidget, QHeaderView
from PySide6.QtGui import QRegularExpressionValidator
from PySide6.QtCore import QRegularExpression, Qt

def select_file():
    filetypes = (
        ('Disk files', '*.dsk'),
        ('All files', '*.*')
    )

    filehandle = fd.askopenfile(
        mode = 'r+b',
        title='Open Virtual 2315 Cartridge Facility disk file',
        initialdir='.',
        filetypes=filetypes,
        parent=root)
    return filehandle

def validateword(astring):
    legit = ["0", "1", "2", "3", "4", "5", "6", "7", \
             "8", "9", "a", "b", "c", "d", "e", "f", \
             "A", "B", "C", "D", "E", "F"]
    if len(astring) != 4:
        return ""
    if not (astring[0:1] in legit):
        return ""
    if not (astring[1:2] in legit):
        return ""
    if not (astring[2:3] in legit):
        return ""
    if not (astring[3:] in legit):
        return ""
    cstring.encode('utf-8').hex()
    return cstring

class HexCellDelegate(QStyledItemDelegate):
    def __init__(self, validator, parent=None):
        super().__init__(parent)
        self.validator = validator

    def createEditor(self, parent, option, index):
        editor = QLineEdit(parent)
        
        editor.setValidator(self.validator) 
        return editor


class HexTableEditor(QWidget):
    def __init__(self, old_sector_data, cyl, head, sector):
        super().__init__()
        self.setWindowTitle(f"Sector Editor - Cylinder {cyl:X} ({cyl})  Head {head}  Sector {sector} - close to update disk file")
        self.resize(750, 500) # Wider to accommodate headers comfortably
        
        layout = QVBoxLayout(self)
        
        # 321 fields fit nicely in a 20x16 or 21x16 grid
        rows, cols = 21, 16  # 21 * 16 = 336 available cells
        self.table = QTableWidget(rows, cols)
        
        # Generate column labels: "0", "1", ... "9", "A", ... "F"
        col_labels = [f"{c:X}" for c in range(cols)]
        self.table.setHorizontalHeaderLabels(col_labels)
        
        # Generate row labels: "0", "1", ... "20"
        row_labels = [f"{r:X}" for r in range(rows)]
        self.table.setVerticalHeaderLabels(row_labels)

        # Strict validation: exactly 4 hexadecimal characters
        hex_regex = QRegularExpression(r"^[0-9A-Fa-f]{4}$")
        self.validator = QRegularExpressionValidator(hex_regex)
        self.delegate = HexCellDelegate(self.validator, self)
        self.table.setItemDelegate(self.delegate)
        
        total_fields = 0
        for r in range(rows):
            for c in range(cols):
                if total_fields >= 321:
                    # Disable trailing unused cells in the grid cleanly
                    item = QTableWidgetItem("")
    
                    # Strip out the ItemIsEditable flag using bitwise operations
                    item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable) 
    
                    self.table.setItem(r, c, item)
                    continue
                
                # Initialize item with sample data
                item = QTableWidgetItem(old_sector_data[r*cols+c])
                self.table.setItem(r, c, item)
                total_fields += 1
                
        # Style header grid columns to look balanced
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        layout.addWidget(self.table)

    @property
    def data(self):
        """Extracts and returns the 321 hex fields as a list of strings."""
        rows = self.table.rowCount()
        cols = self.table.columnCount()
        
        return [
            self.table.item(r, c).text() 
            for r in range(rows) 
            for c in range(cols) 
            if (r * cols) + c < 321
        ]
    
    def grab_updated_sector(self):
        # send the updated values out
        return (self.data)

def validatecyl(astring):
    legit = ["0", "1", "2", "3", "4", "5", "6", "7", \
             "8", "9", "a", "b", "c", "d", "e", "f", \
             "A", "B", "C", "D", "E", "F"]
    decimal = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,10,11,12,13,14,15]
    if len(astring) == 0 or len(astring) >2:
        return ""
    cstring = []
    for x in range(2-len(astring)):
        cstring.append("0")
    cstring.append(astring)
    rstring = "".join(cstring)
    if not (rstring[0:1] in legit):
        return -999
    if not (rstring[1:] in legit):
        return -999
    pos = legit.index(rstring[0:1])
    cyl = pos*16
    pos = legit.index(rstring[1:])
    cyl += pos
    return cyl

try:

    root = Tk()
    root.attributes('-topmost', True)
    root.iconify()
    root.update_idletasks()  # Ensure window is ready

    print('Program to update a sector of a file in the')
    print('format used by the Virtual 2315 Cartridge Facility')
    print('')
        
    sf = select_file()
    if (sf == None):
        print('No input file selected, quitting')
        input("enter to exit")
        sys.exit(1)

    sf.seek(0, 2)
    if (sf.tell() != (1042973)):
        print('File is not the correct size, quitting')
        sf.close()
        input("enter to exit")
        sys.exit(1)
    sf.seek(0, 0)

    header = sf.read(1)
    if (header != b'\x89'):
        print ('wrong magic word in file', header, ', quitting')
        sf.close()
        input("enter to exit")
        sys.exit(1)

    header = sf.read(9)
    if (header != b'2315\r\n\x1a\x00\x00'):
        print('The header we read was', header, ', not the correct one, quitting')
        sf.close()
        input("enter to exit")
        sys.exit(1)
        
    header = sf.read(4)
    if (header != b'1.3\x00'):
        print('wrong version', header, ', quitting')
        sf.close()
        input("enter to exit")
        sys.exit(1)
        
    header = sf.read(11)
    print('Cartridge number is',header.decode("utf-8").rstrip('\x00'))

    header = sf.read(200)
    print('Description is',header.decode("utf-8").rstrip('\x00'))

    header = sf.read(20)

    header = sf.read(100)

    header = sf.read(4)

    header = sf.read(4)

    header = sf.read(4)

    header = sf.read(4)

    header = sf.read(4)

    rewind_point = sf.tell()

    while True:

        cyl = -999
        while (cyl == -999):
            stringcyl = simpledialog.askstring("Input", "Cylinder number in hex:",parent=root)
            cyl = validatecyl(stringcyl)

        head = -999
        while (head == -999):
            head = simpledialog.askinteger("Input", "Head number:",parent=root)

        sector = -999
        while (sector == -999):
            sector = simpledialog.askinteger("Input", "Sector number:",parent=root)

        if (sector < 0 or sector > 3):
            print('Invalid sector number (0 to 3)')
            sf.close()
            input("enter to exit")
            sys.exit(1)

        if (head < 0 or head > 1):
            print('Invalid head number (0 or 1)')
            sf.close()
            input("enter to exit")
            sys.exit(1)

        if (cyl < 0 or cyl > 202):
            print('Invalid cylinder number (0 to 202)')
            sf.close()
            input("enter to exit")
            sys.exit(1)

        skip = (cyl*8) + (head*4) + sector

        sf.seek(rewind_point,0)
        sf.seek((skip*642),1)

        olddata = []
        for addr in range (321):
            olddata.append(f"{(int.from_bytes(sf.read(2), "little")):04X}")

        print ("Updating sector at","decimal cylinder",cyl,"- hex cylinder",f"{cyl:#0{5}X}".replace("X","x"),"-","head",head,"sector",sector)

        app = QApplication(sys.argv)
        editor = HexTableEditor(olddata, cyl, head, sector)
        editor.show()
        app.exec()
        
        replacement = editor.grab_updated_sector()

        full_hex_stream = "".join(replacement)

        binary_payload = bytes.fromhex(full_hex_stream)

        sf.seek(rewind_point,0)
        sf.seek((skip*642),1)

        for ptr in range(321):
            sf.write(binary_payload[ptr*2+1 : ptr*2+2])
            sf.write(binary_payload[ptr*2 : ptr*2+1])

        print(f"Successfully wrote 321 words of the updated sector to disk!")
        
        editor.close()
               
        root.destroy()
        sf.close()
        sys.exit(0)
        
except SystemExit:
    print('Quitting')
    pass

