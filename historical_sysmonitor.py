import sys
import os
import subprocess
import threading
import psutil
from PyQt5.QtWidgets import (QApplication, QSystemTrayIcon, QMenu, QAction, QFileDialog, QDialog, QVBoxLayout, QLabel, QLineEdit, QCheckBox, QSpinBox, QPushButton, QHBoxLayout, QMessageBox)
from PyQt5.QtGui import QIcon
from PyQt5.QtCore import QObject, QThread, pyqtSignal, QTimer, Qt, QSettings

def resource_path(relative_path):
    """ Get the absolute path to the resource, works for dev and for PyInstaller. """
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")    
    return os.path.join(base_path, relative_path)

class PowerShellWorker(QObject):
    finished = pyqtSignal()

    def __init__(self, target_dir, usageThreshold):
        super().__init__()
        self.target_dir = target_dir
        self.usageThreshold = usageThreshold

    def run_powershell_script(self):
        powershell_script = resource_path('getData.ps1')
        command = f"powershell.exe -ExecutionPolicy Unrestricted -File {powershell_script} -baseDir \"{self.target_dir}\" -usageThreshold {self.usageThreshold}"
        process = subprocess.Popen(command, creationflags=subprocess.CREATE_NO_WINDOW, shell=False)
        p = psutil.Process(process.pid)
        p.nice(psutil.REALTIME_PRIORITY_CLASS)
        process.wait()
        self.finished.emit()

class SettingsDialog(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(self.windowFlags() & ~Qt.WindowContextHelpButtonHint)
        self.initUI()
        self.interval_seconds = 15
        self.target_dir = ""
        self.usageThreshold = 0
        self.loadSettings()
        self.isThreadStarted = False

    def loadSettings(self):
        settings = QSettings("Harlax Software", "Historical SysMonitor")

        self.hourSpinBox.setValue(settings.value("hours", 0, type=int))
        self.minuteSpinBox.setValue(settings.value("minutes", 0, type=int))
        self.secondSpinBox.setValue(settings.value("seconds", 15, type=int))
        self.dirLineEdit.setText(settings.value("target_directory", "", type=str))
        self.usageSpinner.setValue(settings.value("usageThreshold", 0, type=int))
        self.logUsageCheckbox.setChecked(settings.value("logUsageChecked", False, type=bool))

    def initUI(self):
        self.setWindowTitle("Historical SysMonitor: Settings")
        icon_path = resource_path('icon_path.ico')
        self.setWindowIcon(QIcon(icon_path))
        
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
        self.secondSpinBox.setValue(15)  # Default value to 15 seconds
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

        usageLayout = QHBoxLayout()
        # Resource usage logging checkbox
        self.logUsageCheckbox = QCheckBox("Log only when resource usage is more than")
        self.logUsageCheckbox.stateChanged.connect(self.toggleUsageSpinner)
        usageLayout.addWidget(self.logUsageCheckbox)

        # Spinner for specifying the percentage
        self.usageSpinner = QSpinBox(self)
        self.usageSpinner.setRange(0, 100)
        self.usageSpinner.setEnabled(False)
        self.usageSpinner.setFixedWidth(50)
        usageLayout.addWidget(self.usageSpinner)

        # Label for displaying "%"
        percentageLabel = QLabel("%")
        usageLayout.addWidget(percentageLabel)
        layout.addLayout(usageLayout)

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

    def toggleUsageSpinner(self, state):
        if state == Qt.Checked:
            self.usageSpinner.setEnabled(True)
        else:
            self.usageSpinner.setEnabled(False)
            self.usageSpinner.setValue(0)

    def saveSettings(self):
        hours = self.hourSpinBox.value()
        minutes = self.minuteSpinBox.value()
        seconds = self.secondSpinBox.value()
        self.interval_seconds = hours * 3600 + minutes * 60 + seconds
        self.target_dir = self.dirLineEdit.text()
        self.usageThreshold = self.usageSpinner.value() if self.usageSpinner.isEnabled() else 0

        if self.isThreadStarted == False:
            self.run_powershell_in_thread()
            self.isThreadStarted = True

        settings = QSettings("Harlax Software", "Historical SysMonitor")

        settings.setValue("hours", self.hourSpinBox.value())
        settings.setValue("minutes", self.minuteSpinBox.value())
        settings.setValue("seconds", self.secondSpinBox.value())
        settings.setValue("target_directory", self.dirLineEdit.text())
        settings.setValue("usageThreshold", self.usageSpinner.value())
        settings.setValue("logUsageChecked", int(self.logUsageCheckbox.isChecked()))

        QMessageBox.information(self, "Settings Saved", "Your settings have been saved successfully.")
        self.accept()

    def resetSettings(self):
        self.hourSpinBox.setValue(0)
        self.minuteSpinBox.setValue(0)
        self.secondSpinBox.setValue(15)
        self.dirLineEdit.clear()

    def updateSecondSpinBoxRange(self):
        if self.minuteSpinBox.value() == 0 and self.hourSpinBox.value() == 0:
            self.secondSpinBox.setMinimum(15)
        else:
            self.secondSpinBox.setMinimum(0)

    def run_powershell_in_thread(self):
        self.thread = QThread()
        self.worker = PowerShellWorker(self.target_dir, self.usageThreshold)
        self.worker.moveToThread(self.thread)

        self.thread.started.connect(self.worker.run_powershell_script)
        self.worker.finished.connect(self.thread.quit)
        self.worker.finished.connect(self.worker.deleteLater)
        self.thread.finished.connect(self.thread.deleteLater)
        self.worker.finished.connect(lambda: QTimer.singleShot(self.interval_seconds * 1000, lambda: self.run_powershell_in_thread()))

        self.thread.start()

class SystemTrayApp(QSystemTrayIcon):
    def __init__(self, icon, parent):
        super(SystemTrayApp, self).__init__(icon, parent)
        self.setToolTip(f"Historical SysMonitor Tray Utility")
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
        self.settingsDialog.exec_()

def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    # Set up the system tray icon
    icon_path = resource_path('icon_path.ico')
    trayIcon = SystemTrayApp(QIcon(icon_path), app)
    trayIcon.show()
    trayIcon.showMessage("Historical SysMonitor Tray Utility", "Application started. Double-click the tray icon to open settings.")

    sys.exit(app.exec_())

if __name__ == '__main__':
    main()
