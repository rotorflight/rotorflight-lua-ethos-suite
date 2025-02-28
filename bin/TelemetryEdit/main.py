import os
import re
import sys
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QTableWidget, QTableWidgetItem, QVBoxLayout, QWidget,
    QPushButton, QComboBox, QHBoxLayout, QLabel, QSpacerItem, QSizePolicy
)
from PyQt6.QtCore import Qt, QTimer

class LuaFileEditor(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("RF Suite Sensor Editor")
        self.setGeometry(100, 100, 800, 400)
        self.resize(560, 560)

        # Determine folder path: CLI arg > Environment variable > Fallback default
        if len(sys.argv) > 1:
            self.folder_path = sys.argv[1]
        elif os.getenv("RFSUITE_TELEMETRY_EDIT_PATH"):
            self.folder_path = os.getenv("RFSUITE_TELEMETRY_EDIT_PATH")
        else:
            self.folder_path = "C:/Program Files (x86)/FrSky/Ethos/X20S/scripts/rfsuite.simtelemetry"

        self.folder_path = os.path.normpath(self.folder_path)

        self.entries = []

        self.table = QTableWidget(0, 5)
        self.table.setHorizontalHeaderLabels(["File", "Type", "Value", "Min", "Max"])

        self.save_button = QPushButton("Save Changes")
        self.save_button.clicked.connect(self.save_changes)

        self.status_label = QLabel("")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignLeft)

        # Layout setup
        layout = QVBoxLayout()
        layout.addWidget(self.table)

        button_layout = QHBoxLayout()
        button_layout.addWidget(self.status_label)

        # Add a spacer to push "Save Changes" to the right
        button_layout.addStretch(1)
        button_layout.addWidget(self.save_button)

        layout.addLayout(button_layout)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

        # Auto-load files on startup
        self.load_files()

    def load_files(self):
        self.entries.clear()
        self.table.setRowCount(0)

        if not os.path.exists(self.folder_path):
            self.status_label.setText(f"❌ Folder not found: {self.folder_path}")
            return

        files = [f for f in os.listdir(self.folder_path) if f.endswith(".lua")]
        if not files:
            self.status_label.setText("⚠️ No .lua files found.")
            return

        for file in files:
            file_path = os.path.join(self.folder_path, file)

            with open(file_path, "r") as f:
                content = f.read()
                return_line = re.search(r'return\s+(.*)', content)

                if return_line:
                    return_value = return_line.group(1).strip()
                    numbers = list(map(int, re.findall(r'\d+', return_value)))

                    file_entry = {
                        "file": file,
                        "path": file_path,
                        "type": "Fixed",
                        "value": "",
                        "min": "",
                        "max": ""
                    }

                    if len(numbers) == 1:
                        file_entry["type"] = "Fixed"
                        file_entry["value"] = str(numbers[0])
                    elif len(numbers) == 2:
                        file_entry["type"] = "Random"
                        file_entry["min"] = str(numbers[0])
                        file_entry["max"] = str(numbers[1])

                    self.entries.append(file_entry)

        self.populate_table()
        self.status_label.setText(f"✅ Loaded {len(files)} files.")

    def populate_table(self):
        self.table.setRowCount(len(self.entries))

        for row, entry in enumerate(self.entries):
            self.table.setItem(row, 0, QTableWidgetItem(entry["file"]))

            type_combo = QComboBox()
            type_combo.addItems(["Fixed", "Random"])
            type_combo.setCurrentText(entry["type"])
            type_combo.currentTextChanged.connect(lambda text, r=row: self.type_changed(r, text))
            self.table.setCellWidget(row, 1, type_combo)

            self.table.setItem(row, 2, QTableWidgetItem(entry["value"]))
            self.table.setItem(row, 3, QTableWidgetItem(entry["min"]))
            self.table.setItem(row, 4, QTableWidgetItem(entry["max"]))

            self.toggle_row_widgets(row, entry["type"])

    def type_changed(self, row, new_type):
        self.entries[row]["type"] = new_type
        self.toggle_row_widgets(row, new_type)

    def toggle_row_widgets(self, row, entry_type):
        if entry_type == "Fixed":
            self.table.item(row, 2).setFlags(self.table.item(row, 2).flags() | Qt.ItemFlag.ItemIsEditable)
            self.table.item(row, 3).setFlags(self.table.item(row, 3).flags() & ~Qt.ItemFlag.ItemIsEditable)
            self.table.item(row, 4).setFlags(self.table.item(row, 4).flags() & ~Qt.ItemFlag.ItemIsEditable)
        else:
            self.table.item(row, 2).setFlags(self.table.item(row, 2).flags() & ~Qt.ItemFlag.ItemIsEditable)
            self.table.item(row, 3).setFlags(self.table.item(row, 3).flags() | Qt.ItemFlag.ItemIsEditable)
            self.table.item(row, 4).setFlags(self.table.item(row, 4).flags() | Qt.ItemFlag.ItemIsEditable)

    def save_changes(self):
        for row, entry in enumerate(self.entries):
            entry["type"] = self.table.cellWidget(row, 1).currentText()
            entry["value"] = self.table.item(row, 2).text() if self.table.item(row, 2) else ""
            entry["min"] = self.table.item(row, 3).text() if self.table.item(row, 3) else ""
            entry["max"] = self.table.item(row, 4).text() if self.table.item(row, 4) else ""

            if entry["type"] == "Fixed":
                new_content = f"return {entry['value']}"
            else:
                new_content = f"return math.random({entry['min']}, {entry['max']})"

            with open(entry["path"], "w") as f:
                f.write(new_content)

        self.show_status("✅ Changes saved!")

    def show_status(self, message):
        self.status_label.setText(message)
        # Auto clear the message after 3 seconds
        QTimer.singleShot(3000, lambda: self.status_label.setText(""))

if __name__ == "__main__":
    app = QApplication(sys.argv)
    editor = LuaFileEditor()
    editor.show()
    sys.exit(app.exec())
