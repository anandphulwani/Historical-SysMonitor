import sys
from PyQt5.QtWidgets import (QApplication, QSystemTrayIcon, QMenu, QAction, QFileDialog, QDialog, QVBoxLayout, QLabel, QLineEdit, QSpinBox, QPushButton, QHBoxLayout, QMessageBox)
from PyQt5.QtGui import QIcon
from PyQt5.QtCore import QTimer
import os

class SettingsDialog(QDialog):
    def __init__(self):
        super().__init__()
        self.initUI()

    def initUI(self):
        self.setWindowTitle("Settings")
        layout = QVBoxLayout()

        # Interval layout with hours, minutes, and seconds
        intervalLayout = QHBoxLayout()

        # Hours spinner
        self.hourLabel = QLabel("Hours:")
        self.hourSpinBox = QSpinBox(self)
        self.hourSpinBox.setRange(0, 999)  # Allowing up to 999 hours
        intervalLayout.addWidget(self.hourLabel)
        intervalLayout.addWidget(self.hourSpinBox)

        # Minutes spinner
        self.minuteLabel = QLabel("Minutes:")
        self.minuteSpinBox = QSpinBox(self)
        self.minuteSpinBox.setRange(0, 59)  # 0 to 59 minutes
        intervalLayout.addWidget(self.minuteLabel)
        intervalLayout.addWidget(self.minuteSpinBox)

        # Seconds spinner
        self.secondLabel = QLabel("Seconds:")
        self.secondSpinBox = QSpinBox(self)
        self.secondSpinBox.setRange(0, 59)  # 0 to 59 seconds
        self.secondSpinBox.setValue(5)  # Default value to 5 seconds
        intervalLayout.addWidget(self.secondLabel)
        intervalLayout.addWidget(self.secondSpinBox)

        # Connect spinBox valueChanged signals to a slot to enforce custom validation
        self.minuteSpinBox.valueChanged.connect(self.updateSecondSpinBoxRange)
        self.hourSpinBox.valueChanged.connect(self.updateSecondSpinBoxRange)

        layout.addLayout(intervalLayout)

        # Target directory
        dirLayout = QHBoxLayout()
        self.dirLineEdit = QLineEdit(self)
        self.dirLineEdit.setPlaceholderText("Select target directory")
        self.browseButton = QPushButton("Browse")
        self.browseButton.clicked.connect(self.browseDirectory)
        dirLayout.addWidget(self.dirLineEdit)
        dirLayout.addWidget(self.browseButton)
        layout.addLayout(dirLayout)

        # Buttons layout
        buttonsLayout = QHBoxLayout()
        self.saveButton = QPushButton("Save")
        self.saveButton.clicked.connect(self.saveSettings)
        buttonsLayout.addWidget(self.saveButton)
        self.resetButton = QPushButton("Reset")
        self.resetButton.clicked.connect(self.resetSettings)
        buttonsLayout.addWidget(self.resetButton)
        layout.addLayout(buttonsLayout)

        self.setLayout(layout)

    def browseDirectory(self):
        dir = QFileDialog.getExistingDirectory(self, "Select Directory")
        if dir:
            self.dirLineEdit.setText(dir)

    def saveSettings(self):
        QMessageBox.information(self, "Settings Saved", "Your settings have been saved successfully.")
        self.accept()

    def resetSettings(self):
        self.hourSpinBox.setValue(0)
        self.minuteSpinBox.setValue(0)
        self.secondSpinBox.setValue(5)
        self.dirLineEdit.clear()

    def updateSecondSpinBoxRange(self):
        if self.minuteSpinBox.value() == 0 and self.hourSpinBox.value() == 0:
            self.secondSpinBox.setMinimum(5)
        else:
            self.secondSpinBox.setMinimum(0)

class SystemTrayApp(QSystemTrayIcon):
    def __init__(self, icon, parent):
        super(SystemTrayApp, self).__init__(icon, parent)
        self.setToolTip(f"System Tray Utility")
        self.menu = QMenu()
        
        exitAction = QAction("Exit", self.menu)
        exitAction.triggered.connect(parent.quit)
        self.menu.addAction(exitAction)
        
        self.setContextMenu(self.menu)
        self.activated.connect(self.onTrayIconActivated)
        self.settingsDialog = SettingsDialog()

    def onTrayIconActivated(self, reason):
        if reason == QSystemTrayIcon.Trigger:  # On double click
            self.showSettingsDialog()

    def showSettingsDialog(self):
        if self.settingsDialog.exec_() == QDialog.Accepted:
            # Here you can handle the accepted settings, e.g., start a timer based on the user input
            pass

def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    # Set up the system tray icon
    trayIcon = SystemTrayApp(QIcon("icon_path.ico"), app)
    trayIcon.show()
    trayIcon.showMessage("System Tray Utility", "Application started. Double-click the tray icon to open settings.")

    sys.exit(app.exec_())

if __name__ == '__main__':
    main()

