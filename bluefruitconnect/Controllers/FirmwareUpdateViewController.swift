//
//  FirmwareUpdateViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class FirmwareUpdateViewController: NSViewController, FirmwareUpdaterDelegate, UpdateDialogViewControlerDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var firmwareCurrentVersionLabel: NSTextField!
    @IBOutlet weak var firmwareCurrentVersionWaitView: NSProgressIndicator!
    @IBOutlet weak var firmwareTableView: NSTableView!
    @IBOutlet weak var firmwareWaitView: NSProgressIndicator!
    @IBOutlet weak var separatorView: NSView!
    @IBOutlet weak var hexFileTextField: NSTextField!
    @IBOutlet weak var iniFileTextField: NSTextField!
    
    private let firmwareUpdater = FirmwareUpdater()
    
    private var boardRelease : BoardInfo?;
    private var deviceInfoData : DeviceInfoData?;
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // UI
        separatorView.wantsLayer = true
        separatorView.layer?.backgroundColor = NSColor.blackColor().colorWithAlphaComponent(0.2).CGColor
        firmwareWaitView.startAnimation(nil)
        firmwareCurrentVersionWaitView.startAnimation(nil)
        firmwareCurrentVersionLabel.stringValue = ""
        
        //
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            firmwareUpdater.checkUpdatesForPeripheral(blePeripheral.peripheral, delegate: self)
        }
    }
    
    
    @IBAction func onClickChooseInitFile(sender: AnyObject) {
        chooseFile(false)
    }
    
    @IBAction func onClickChooseHexFile(sender: AnyObject) {
        chooseFile(true)
    }
    
    func chooseFile(isHexFile : Bool) {
        let openFileDialog = NSOpenPanel()
        openFileDialog.canChooseFiles = true
        openFileDialog.canChooseDirectories = false
        openFileDialog.allowsMultipleSelection = false
        openFileDialog.canCreateDirectories = false
        
        if let window = self.view.window {
            openFileDialog.beginSheetModalForWindow(window) {[unowned self] (result) -> Void in
                if result == NSFileHandlingPanelOKButton {
                    if let url = openFileDialog.URL {
                        
                        if (isHexFile) {
                            self.hexFileTextField.stringValue = url.path!
                        }
                        else {
                            self.iniFileTextField.stringValue = url.path!
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func onClickCustomFirmwareUpdate(sender: AnyObject) {
        
        guard !deviceInfoData!.hasDefaultBootloaderVersion() else {
            onUpdateDialogError("The legacy bootloader on this device is not compatible with this application")
            return
        }

        guard !hexFileTextField.stringValue.isEmpty else {
            onUpdateDialogError("At least an Hex file should be selected")
            return
        }
        
        let hexUrl = NSURL(fileURLWithPath: hexFileTextField.stringValue)
        var iniUrl :NSURL? = nil
        
        if !iniFileTextField.stringValue.isEmpty {
            iniUrl = NSURL(fileURLWithPath: iniFileTextField.stringValue)
        }
        
        startDfuUpdateWithHexInitFiles(hexUrl, iniUrl: iniUrl)
    }
    
    
    // MARK: - FirmwareUpdaterDelegate
    func onFirmwareUpdatesAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData!, allReleases: [NSObject : AnyObject]?) {
        DLog("onFirmwareUpdatesAvailable")
        
        self.deviceInfoData = deviceInfoData
        
        if let allReleases = allReleases {
            boardRelease = allReleases[deviceInfoData.modelNumber] as? BoardInfo
        }
        else {
            DLog("Warning: no releases found for this board")
        }
        firmwareWaitView.stopAnimation(nil)
        firmwareTableView.reloadData()
        
        firmwareCurrentVersionLabel.stringValue = deviceInfoData.softwareRevision
        firmwareCurrentVersionWaitView.stopAnimation(nil)
        
        if (deviceInfoData.hasDefaultBootloaderVersion()) {
            onUpdateDialogError("The legacy bootloader on this device is not compatible with this application")
        }
        
    }
    
    func onDfuServiceNotFound() {
        onUpdateDialogError("No DFU Service found on device")
    }
    
    
    // MARK: - NSTableViewDataSource
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if (boardRelease != nil && boardRelease!.firmwareReleases != nil) {
            let firmwareReleases = boardRelease!.firmwareReleases!
            return firmwareReleases.count
        }
        else {
            return 0
        }
    }
    
    
    // MARK: NSTableViewDelegate
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let firmwareRelases = boardRelease!.firmwareReleases as NSArray as! [FirmwareInfo]
        let firmwareInfo = firmwareRelases[row]
        
        var cell = NSTableCellView()
        
        if let columnIdentifier = tableColumn?.identifier {
            switch(columnIdentifier) {
            case "VersionColumn":
                cell = tableView.makeViewWithIdentifier("FirmwareVersionCell", owner: self) as! NSTableCellView
                
                cell.textField?.stringValue = firmwareInfo.version
                
            case "TypeColumn":
                cell = tableView.makeViewWithIdentifier("FirmwareTypeCell", owner: self) as! NSTableCellView
                
                cell.textField?.stringValue = firmwareInfo.boardName
                
            default:
                cell.textField?.stringValue = ""
            }
        }
        
        
        return cell;
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        
        let selectedRow = firmwareTableView.selectedRow
        
        if (selectedRow >= 0) {
            if (deviceInfoData!.hasDefaultBootloaderVersion()) {
                onUpdateDialogError("The legacy bootloader on this device is not compatible with this application")
            }
            else {
                let firmwareRelases = boardRelease!.firmwareReleases
                let firmwareInfo = firmwareRelases[selectedRow] as! FirmwareInfo
                
                confirmDfuUpdateWithFirmware(firmwareInfo)
                firmwareTableView.deselectAll(nil)
            }
        }
    }
    
    // MARK: - DFU update
    func confirmDfuUpdateWithFirmware(firmwareInfo : FirmwareInfo) {
        let compareBootloader = deviceInfoData!.bootloaderVersion().caseInsensitiveCompare(firmwareInfo.minBootloaderVersion)
        if (compareBootloader == .OrderedDescending || compareBootloader == .OrderedSame) {        // Requeriments met
            let alert = NSAlert()
            alert.messageText = "Install firmware version \(firmwareInfo.version)?"
            alert.informativeText = "The firmware will be downloaded and updated. Please wait until the process finishes before disconnecting the peripheral"
            alert.addButtonWithTitle("Ok")
            alert.addButtonWithTitle("Cancel")
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: { [unowned self](modalResponse) -> Void in
                if (modalResponse == NSAlertFirstButtonReturn) {
                    self.startDfuUpdateWithFirmware(firmwareInfo)
                }
            })
        }
        else {      // Requeriments not met
            let alert = NSAlert()
            alert.messageText = "This firmware update is not compatible with your bootloader. You need to update your bootloader to version %@ before installing this firmware release \(firmwareInfo.version)"
            alert.addButtonWithTitle("Ok")
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
        }
    }
    
    func startDfuUpdateWithFirmware(firmwareInfo : FirmwareInfo) {
        let hexUrl = NSURL(string: firmwareInfo.hexFileUrl)!
        let iniUrl =  NSURL(string: firmwareInfo.iniFileUrl)
        startDfuUpdateWithHexInitFiles(hexUrl, iniUrl: iniUrl)
    }
    
    func startDfuUpdateWithHexInitFiles(hexUrl : NSURL, iniUrl: NSURL?) {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            
            let updateDialogViewController = self.storyboard?.instantiateControllerWithIdentifier("UpdateDialogViewController") as! UpdateDialogViewController
            updateDialogViewController.setUpdateParametrs(blePeripheral.peripheral, hexUrl: hexUrl, iniUrl:iniUrl, deviceInfoData: deviceInfoData!)
            updateDialogViewController.delegate = self
            self.presentViewControllerAsModalWindow(updateDialogViewController)
        }
        else {
            onUpdateDialogError("No peripheral conected. Abort update");
        }
    }
    
    
    // MARK: - UpdateDialogViewControlerDelegate
    
    func onUpdateDialogCancel() {
        
        BleManager.sharedInstance.restoreCentralManager()
    }
    
    func onUpdateDialogSuccess() {
        BleManager.sharedInstance.restoreCentralManager()
        
        
        let alert = NSAlert()
        alert.messageText = "Update completed successfully"
        alert.addButtonWithTitle("Ok")
        alert.alertStyle = .WarningAlertStyle
        alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
    }
    
    func onUpdateDialogError(errorMessage : String) {
        BleManager.sharedInstance.restoreCentralManager()
        
        let alert = NSAlert()
        alert.messageText = errorMessage
        alert.addButtonWithTitle("Ok")
        alert.alertStyle = .WarningAlertStyle
        alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
        
    }
    
}
