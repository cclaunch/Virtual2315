#
# Comparison program to read two Virtual 2315 Cartridge Facility
# files and compare each sector for differences. It will 
# produce a list of all the sectors that have differences,
# allowing the user to run either showsector.exe or updatesector.exe
#
#
# written by Carl V Claunch, available under MIT license

from tkinter import Tk
from tkinter import filedialog as fd
import sys
from PySide6.QtWidgets import QApplication, QTableWidget, QLineEdit, QTableWidgetItem, QStyledItemDelegate,  QVBoxLayout, QWidget, QHeaderView
from PySide6.QtGui import QRegularExpressionValidator, QBrush
from PySide6.QtCore import QRegularExpression, Qt, QEvent

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

class HexTableEditor(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("No differences found in any sectors, disks are identical - close to end application")
        self.resize(750, 500) # Wider to accommodate headers comfortably
        
        layout = QVBoxLayout(self)
        
        # 1624 sectors fit nicely in a 8x203 grid
        rows, cols = 203, 8  
        self.table = QTableWidget(rows, cols)
        
        # Generate column labels: "H0 S0", "H0 S1", ... "H1 S3"
        col_labels = ["H0 S0", "H0 S1", "H0 S2", "H0 S3",
                      "H1 S0", "H1 S1", "H1 S2", "H1 S3"]
        self.table.setHorizontalHeaderLabels(col_labels)
        
        # Generate row labels: "0", "1", ... "CA"
        row_labels = [f"{r:X}" for r in range(203)]
        self.table.setVerticalHeaderLabels(row_labels)
        
        for r in range(rows):
            for c in range(cols):                
                # Initialize item with sample data
                item = QTableWidgetItem(" ")
                # Strip out the ItemIsEditable flag using bitwise operations
                item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable) 
                self.table.setItem(r, c, item)
                
        # Style header grid columns to look balanced
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        layout.addWidget(self.table)

        self.differences = 0

        self.table.setTabKeyNavigation(False)
        
        self.table.installEventFilter(self)

    def eventFilter(self, watched_obj, event):
        # Verify the event is a keypress inside your internal table widget
        if watched_obj == self.table and event.type() == QEvent.Type.KeyPress:
            
            # Safely detect the Tab key regardless of PyQt5 or PyQt6
            is_tab = False
            try:
                is_tab = (event.key() == Qt.Key.Key_Tab)  # PyQt6
            except AttributeError:
                is_tab = (event.key() == Qt.Key_Tab)      # PyQt5

            if is_tab:
                # Pass the table object directly into our calculation loop
                if self.move_to_next_non_empty(watched_obj):
                    return True  # Fully consumes the event; blocks the default jump
                    
        return super().eventFilter(watched_obj, event)

    def move_to_next_non_empty(self, table_widget):
        # Use standard Qt Model Indexing which works on both QTableWidget and QTableView
        current_index = table_widget.currentIndex()
        if not current_index.isValid():
            return False
            
        current_row = current_index.row()
        current_col = current_index.column()
        
        # Dynamically grab grid sizes from the model
        total_rows = table_widget.model().rowCount()
        total_cols = table_widget.model().columnCount()

        start_idx = current_row * total_cols + current_col + 1
        total_cells = total_rows * total_cols

        for i in range(start_idx, total_cells):
            r = i // total_cols
            c = i % total_cols
            
            # Safely get the cell index and extract text contents
            cell_index = table_widget.model().index(r, c)
            cell_text = str(table_widget.model().data(cell_index) or '').strip()
            
            # Change condition if your 'empty' indicator is something like '00' or '..'
            if cell_text:
                # Set the focus destination safely on the view
                table_widget.setCurrentIndex(cell_index)
                return True
                
        return False

    
    def mark_sector(self, c, h, s):
        # flag the sector as different
        item = QTableWidgetItem(f"0x{c:02X} ({c})  {h}  {s}")
        brush = QBrush(Qt.yellow, Qt.SolidPattern)
        item.setBackground(brush)
        item.setTextAlignment(Qt.AlignCenter)
        self.table.setItem(c, h*2+s, item)
        self.differences += 1
        self.setWindowTitle(f"Differences found in {self.differences} sectors, tab to move to next one - close to end application")
        return ()

try:

    root = Tk()
    root.attributes('-topmost', True)
    root.iconify()
    root.update_idletasks()  # Ensure window is ready

    print('Program to compare two Virtual 2315 Cartridge Facility')
    print('files and identify which sectors have differences')
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

    print ("Header of first file verified")

    print('')

    cf = select_file()
    if (cf == None):
        print('No second input file selected, quitting')
        sys.exit(1)

    cf.seek(0, 2)
    if (cf.tell() != 1042973):
        print('Second file is ',cf.tell(),' not the correct size, quitting')
        cf.close()
        sys.exit(1)
    cf.seek(0, 0)

    header = cf.read(1)
    if (header != b'\x89'):
        print ('wrong magic word in second file', header, ', quitting')
        sf.close()
        cf.close()
        sys.exit(1)

    header = cf.read(9)
    if (header != b'2315\r\n\x1a\x00\x00'):
        print('The header we read in second file was', header, ', not the correct one, quitting')
        sf.close()
        cf.close()
        sys.exit(1)
        
    header = cf.read(4)
    if (header != b'1.3\x00'):
        print('Second file wrong version', header, ', quitting')
        sf.close()
        cf.close()
        sys.exit(1)
        
    header = cf.read(11)
    print('Cartridge number is',header.decode("utf-8").rstrip('\x00'))

    header = cf.read(200)
    print('Description in second file is',header.decode("utf-8").rstrip('\x00'))

    header = cf.read(20)
    print('Date of the second file is',header.decode("utf-8"))

    header = cf.read(100)
    print('Controller for the disk drive in second file is',header.decode("utf-8").rstrip('\x00'))

    header = cf.read(4)
    print('Bit rate in second file is',format(int.from_bytes(header, "big"), ","))

    header = cf.read(4)
    print('Number of cylinders in second file is',int.from_bytes(header, "big"))

    header = cf.read(4)
    print('Number of sectors per rotation in second file is',int.from_bytes(header, "big"))

    header = cf.read(4)
    print('Number of heads in second file is', int.from_bytes(header, "big"))

    header = cf.read(4)
    print('uSeconds in a sector in second file is', format(int.from_bytes(header, "big"), ","))

    print ("Header of second file verified")

    print('')

    app = QApplication(sys.argv)
    editor = HexTableEditor()

    for cyl in range(203):
        for head in range(2):
            for sector in range (4):
                flag = False
                for word in range(642):
                    if (sf.read(1) != cf.read(1)):
                        flag = True
                if flag:
                    editor.mark_sector(cyl, head, sector)

    editor.show()
    editor.raise_()
    editor.activateWindow()
    app.exec()
    
    cf.close()
    sf.close()
    print ('Comparison complete')
    editor.close()           
    root.destroy()
    sys.exit(0)
        
except SystemExit:
    print('Quitting')
    pass
    print('')
    sys.exit(0)
