//
//  AppDelegate.swift
//  SlidePilot
//
//  Created by Pascal Braband on 23.03.20.
//  Copyright © 2020 Pascal Braband. All rights reserved.
//

import Cocoa
import PDFKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    /** Indicates, whether the timer should be started on slide change. */
    var shouldStartTimerOnSlideChange = true
    
    
    // MARK: - Menu Outlets
    @IBOutlet weak var showNavigatorItem: NSMenuItem!
    @IBOutlet weak var previewNextSlideItem: NSMenuItem!
    @IBOutlet weak var displayBlackCurtainItem: NSMenuItem!
    @IBOutlet weak var displayWhiteCurtainItem: NSMenuItem!
    @IBOutlet weak var showPointerItem: NSMenuItem!
    @IBOutlet weak var showNotesItem: NSMenuItem!
    
    @IBOutlet weak var pointerAppearanceMenu: NSMenu!
    @IBOutlet weak var pointerAppearanceCursorItem: NSMenuItem!
    @IBOutlet weak var pointerAppearanceDotItem: NSMenuItem!
    @IBOutlet weak var pointerAppearanceCircleItem: NSMenuItem!
    @IBOutlet weak var pointerAppearanceTargetItem: NSMenuItem!
    @IBOutlet weak var pointerAppearanceTargetColorItem: NSMenuItem!
    
    @IBOutlet weak var notesModeMenu: NSMenu!
    @IBOutlet weak var notesModeTextItem: NSMenuItem!
    @IBOutlet weak var notesModeSplitItem: NSMenuItem!
    
    @IBOutlet weak var notesPositionMenu: NSMenu!
    @IBOutlet weak var notesPositionNoneItem: NSMenuItem!
    @IBOutlet weak var notesPositionRightItem: NSMenuItem!
    @IBOutlet weak var notesPositionLeftItem: NSMenuItem!
    @IBOutlet weak var notesPositionBottomItem: NSMenuItem!
    @IBOutlet weak var notesPositionTopItem: NSMenuItem!
    
    @IBOutlet weak var timeModeMenu: NSMenu!
    @IBOutlet weak var stopwatchModeItem: NSMenuItem!
    @IBOutlet weak var timerModeItem: NSMenuItem!
    @IBOutlet weak var setTimerItem: NSMenuItem!
    
    
    // MARK: - Identifiers
    private let presenterWindowIdentifier = NSUserInterfaceItemIdentifier("PresenterWindowID")
    private let presentationWindowIdentifier = NSUserInterfaceItemIdentifier("PresentationWindowID")
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Disable Tabs
        if #available(OSX 10.12, *) {
            NSWindow.allowsAutomaticWindowTabbing = false
        }
        
        // Enable TouchBar
        if #available(OSX 10.12.2, *) {
            NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        }
        
        // Count app starts
        AppStartTracker.startup()
        
        // Subscribe to display changes
        DisplayController.subscribeNotesPosition(target: self, action: #selector(notesPositionDidChange(_:)))
        DisplayController.subscribeDisplayNotes(target: self, action: #selector(displayNotesDidChange(_:)))
        DisplayController.subscribeDisplayBlackCurtain(target: self, action: #selector(displayBlackCurtainDidChange(_:)))
        DisplayController.subscribeDisplayWhiteCurtain(target: self, action: #selector(displayWhiteCurtainDidChange(_:)))
        DisplayController.subscribeDisplayNavigator(target: self, action: #selector(displayNavigatorDidChange(_:)))
        DisplayController.subscribePreviewNextSlide(target: self, action: #selector(displayNextSlidePreviewDidChange(_:)))
        DisplayController.subscribeDisplayPointer(target: self, action: #selector(displayPointerDidChange(_:)))
        DisplayController.subscribePointerAppearance(target: self, action: #selector(pointerAppearanceDidChange(_:)))
        DisplayController.subscribeNotesMode(target: self, action: #selector(notesModeDidChange(_:)))
        
        // Set default display options
        DisplayController.setPointerAppearance(.cursor, sender: self)
        
        // Subscribe to notes file changes
        DocumentController.subscribeRequestOpenNotes(target: self, action: #selector(didRequestOpenNotes(_:)))
        DocumentController.subscribeRequestSaveNotes(target: self, action: #selector(didRequestSaveNotes(_:)))
        DocumentController.subscribeDidEditNotes(target: self, action: #selector(didEditNotes(_:)))
        DocumentController.subscribeDidSaveNotes(target: self, action: #selector(didSaveNotes(_:)))
        
        // Subscribe to time changes
        TimeController.subscribeTimeMode(target: self, action: #selector(timeModeDidChange(_:)))
        
        // Set default time options
        TimeController.setTimeMode(mode: .stopwatch, sender: self)
        
        startup()
    }
    

    func applicationWillTerminate(_ aNotification: Notification) {
        // Close the current notes file (implies saving it)
        DocumentController.requestCloseNotesFile(sender: self)
    }
    
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    
    @IBAction func openHelpWebsite(_ sender: Any) {
        if #available(OSX 10.15, *) {
            let openConfig = NSWorkspace.OpenConfiguration()
            openConfig.addsToRecentItems = true
            NSWorkspace.shared.open(URL(string: "http://slidepilot.gitbook.io")!, configuration: openConfig, completionHandler: nil)
        } else {
            NSWorkspace.shared.open(URL(string: "http://slidepilot.gitbook.io")!)
        }
    }

    
    
    
    // MARK: - Window Management
    
    var presenterWindowCtrl: PresenterWindowController?
    var presenterWindow: NSWindow?
    var presenterDisplay: PresenterViewController?
    
    var presentationWindowCtrl: PresentationWindowController?
    var presentationWindow: NSWindow?
    var presentationView: PresentationViewController?
    
    
    func startup() {
        presentOpenFileDialog { (fileUrl) in
            setupWindows()
            openFile(url: fileUrl)
        }
    }
    
    
    func setupWindows() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        
        guard let presenterWindowCtrl = storyboard.instantiateController(withIdentifier: .init(stringLiteral: "PresenterWindow")) as? PresenterWindowController else { return }
        guard let presenterWindow = presenterWindowCtrl.window else { return }
        guard let presenterDisplay = presenterWindowCtrl.contentViewController as? PresenterViewController else { return }
        
        guard let presentationWindowCtrl = storyboard.instantiateController(withIdentifier: .init(stringLiteral: "PresentationWindow")) as?
            PresentationWindowController else { return }
        guard let presentationWindow = presentationWindowCtrl.window else { return }
        guard let presentationView = presentationWindowCtrl.contentViewController as? PresentationViewController else { return }
        
        // Set window identifiers
        presenterWindow.identifier = presenterWindowIdentifier
        presentationWindow.identifier = presentationWindowIdentifier
        
        NSApp.activate(ignoringOtherApps: true)
        
        // Move window to second screen if possible
        if NSScreen.screens.count >= 2 {
            let secondScreen = NSScreen.screens[1]
            presentationWindow.setFrame(secondScreen.visibleFrame, display: true, animate: true)
            presentationWindow.level = .normal
        }
        
        // Setup communication between the two windows
        presenterDisplay.pointerDelegate = presentationView
        
        // Open Presentation Window in fullscreen
        presentationWindow.orderFront(self)
        presentationWindow.toggleFullScreen(self)
        
        // Open Presenter Display
        presenterWindow.makeKeyAndOrderFront(nil)
        
        // Set properties
        self.presenterWindowCtrl = presenterWindowCtrl
        self.presenterWindow = presenterWindow
        self.presenterDisplay = presenterDisplay
        
        self.presentationWindowCtrl = presentationWindowCtrl
        self.presentationWindow = presentationWindow
        self.presentationView = presentationView
    }
    
    
    
    
    // MARK: - Open File
    
    @IBAction func openDocument(_ sender: NSMenuItem) {
        presentOpenFileDialog { (fileUrl) in
            openFile(url: fileUrl)
        }
    }
    
    
    /** Presents the dialog to open a PDF document. */
    func presentOpenFileDialog(completion: (URL) -> ()) {
        let dialog = NSOpenPanel();

        dialog.title = NSLocalizedString("Choose File", comment: "Title for open file panel.");
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseFiles = true
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["pdf"]

        if (dialog.runModal() == .OK) {
            if let result = dialog.url {
                completion(result)
            }
        }
    }
    
    
    /** Opens the PDF document at the given `URL` in both presenter and presentation window. */
    func openFile(url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        guard let pdfDocument = PDFDocument(url: url) else { return }
        
        // Close the current notes file (implies saving it)
        DocumentController.requestCloseNotesFile(sender: self)
        
        // Open document
        DocumentController.setDocument(pdfDocument, sender: self)
        
        // TODO: Open the notes file if it can be found
        
        // Reset page
        PageController.selectPage(at: 0, sender: self)
        
        // Reset display options
        DisplayController.setDisplayNextSlidePreview(true, sender: self)
        DisplayController.setNotesPosition(.none, sender: self)
        DisplayController.setDisplayNotes(false, sender: self)
        DisplayController.setNotesMode(.text, sender: self)
        
        // Reset stopwatch/timer
        TimeController.resetTime(sender: self)
        
        // Reset property, that timer should start when chaning slide
        shouldStartTimerOnSlideChange = true
    }
    
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openFile(url: URL(fileURLWithPath: filename))
        return true
    }
    
    
    
    // MARK: - Menu Item Actions
    
    @IBAction func previousSlide(_ sender: NSMenuItem) {
        PageController.previousPage(sender: self)
    }
    
    
    @IBAction func nextSlide(_ sender: NSMenuItem) {
        PageController.nextPage(sender: self)
        
        // If this is the first next slide call for this document, start time automatically
        if shouldStartTimerOnSlideChange {
            shouldStartTimerOnSlideChange = false
            TimeController.setIsRunning(true, sender: self)
        }
    }
    
    
    @IBAction func selectNotesPositionNone(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.none, sender: self)
    }
    
    
    @IBAction func selectNotesPositionRight(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.right, sender: self)
    }
    
    
    @IBAction func selectNotesPositionLeft(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.left, sender: self)
    }
    
    
    @IBAction func selectNotesPositionBottom(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.bottom, sender: self)
    }
    
    
    @IBAction func selectNotesPositionTop(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.top, sender: self)
    }
    
    
    @IBAction func showNotes(_ sender: NSMenuItem) {
        DisplayController.switchDisplayNotes(sender: sender)
    }
    
    @IBAction func selectNotesModeText(_ sender: NSMenuItem) {
        DisplayController.setNotesMode(.text, sender: sender)
    }
    
    
    @IBAction func selectNotesModeSplit(_ sender: NSMenuItem) {
        DisplayController.setNotesMode(.split, sender: sender)
    }
    
    
    @IBAction func saveNotes(_ sender: NSMenuItem) {
        DocumentController.requestSaveNotes(sender: sender)
    }
    
    
    @IBAction func openNotes(_ sender: NSMenuItem) {
        DocumentController.requestOpenNotes(sender: sender)
    }
    
    
    @IBAction func displayBlackCurtain(_ sender: NSMenuItem) {
        DisplayController.switchDisplayBlackCurtain(sender: sender)
    }
    
    
    @IBAction func displayWhiteCurtain(_ sender: NSMenuItem) {
        DisplayController.switchDisplayWhiteCurtain(sender: sender)
    }
    
    
    @IBAction func showNavigator(_ sender: NSMenuItem) {
        DisplayController.switchDisplayNavigator(sender: sender)
    }
    
    @IBAction func previewNextSlide(_ sender: NSMenuItem) {
        DisplayController.switchDisplayNextSlidePreview(sender: sender)
    }
    
    
    @IBAction func showPointer(_ sender: NSMenuItem) {
        DisplayController.switchDisplayPointer(sender: sender)
    }
    
    
    @IBAction func selectPointerAppearanceCursor(_ sender: NSMenuItem) {
        DisplayController.setPointerAppearance(.cursor, sender: sender)
    }
    
    
    @IBAction func selectPointerAppearanceDot(_ sender: NSMenuItem) {
        DisplayController.setPointerAppearance(.dot, sender: sender)
    }
    
    
    @IBAction func selectPointerAppearanceCircle(_ sender: NSMenuItem) {
        DisplayController.setPointerAppearance(.circle, sender: sender)
    }
    
    
    @IBAction func selectPointerAppearanceTarget(_ sender: NSMenuItem) {
        DisplayController.setPointerAppearance(.target, sender: sender)
    }
    
    
    @IBAction func selectPointerAppearanceTargetColor(_ sender: NSMenuItem) {
        DisplayController.setPointerAppearance(.targetColor, sender: sender)
    }
    
    @IBAction func selectModeStopwatch(_ sender: NSMenuItem) {
        TimeController.setTimeMode(mode: .stopwatch, sender: self)
    }
    
    
    @IBAction func selectModeTimer(_ sender: NSMenuItem) {
        TimeController.setTimeMode(mode: .timer, sender: self)
    }
    
    
    @IBAction func setTimer(_ sender: NSMenuItem) {
        TimeController.requestSetTimerInterval(sender: self)
    }
    
    
    @IBAction func startStopTime(_ sender: NSMenuItem) {
        TimeController.switchIsRunning(sender: self)
        
        // Don't start time automatically anymore
        shouldStartTimerOnSlideChange = false
    }
    
    
    @IBAction func resetTime(_ sender: NSMenuItem) {
        TimeController.resetTime(sender: self)
    }
    
    
    
    
    // MARK: - Control Handlers
    
    @objc func notesPositionDidChange(_ notification: Notification) {
        // Turn off all items in notes position menu
        notesPositionMenu.items.forEach({ $0.state = .off })
        
        // Select correct menu item for notes position
        switch DisplayController.notesPosition {
        case .none:
            notesPositionNoneItem.state = .on
            if DisplayController.areNotesDisplayed, DisplayController.notesMode == .split {
                DisplayController.setNotesMode(.text, sender: self)
            }
        case .right:
            notesPositionRightItem.state = .on
        case .left:
            notesPositionLeftItem.state = .on
        case .bottom:
            notesPositionBottomItem.state = .on
        case .top:
            notesPositionTopItem.state = .on
        }
    }
    
    
    @objc func notesModeDidChange(_ notification: Notification) {
        // Turn off all items in notes mode menu
        notesModeMenu.items.forEach({ $0.state = .off })
        
        // Select correct menu item for notes position
        switch DisplayController.notesMode {
        case .text:
            notesModeTextItem.state = .on
            
        case .split:
            notesModeSplitItem.state = .on
            
            // Select notes position right by default when displaying notes split
            // Only if notes are displayed currently and current note position is none
            if DisplayController.areNotesDisplayed, DisplayController.notesPosition == .none , DisplayController.notesMode == .split{
                DisplayController.setNotesPosition(.right, sender: self)
            }
        }
    }
    
    
    @objc func didRequestOpenNotes(_ notification: Notification) {
        let dialog = NSOpenPanel();

        dialog.title = NSLocalizedString("Choose File", comment: "Title for open file panel.");
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseFiles = true
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["rtf"]

        if (dialog.runModal() == .OK) {
            if let result = dialog.url {
                let notesDocument = NotesDocument(contentsOf: result)
                DocumentController.didOpenNotes(document: notesDocument, sender: self)
            }
        }
    }
    
    
    @objc func didRequestSaveNotes(_ notification: Notification) {
        // TODO: Check if document has already been saved, then save it to its url
        // If not open the save panel
    }
    
    
    @objc func didEditNotes(_ notification: Notification) {
        presenterWindow?.isDocumentEdited = true
    }
    
    
    @objc func didSaveNotes(_ notification: Notification) {
        presenterWindow?.isDocumentEdited = false
    }
    
    
    @objc func displayNotesDidChange(_ notification: Notification) {
        // Set correct state for display notes menu item
        showNotesItem.state = DisplayController.areNotesDisplayed ? .on : .off
        
        
        // Select notes position right by default when displaying notes split
        // Only if notes are displayed currently and current note position is none
        if DisplayController.areNotesDisplayed, DisplayController.notesPosition == .none , DisplayController.notesMode == .split{
            DisplayController.setNotesPosition(.right, sender: self)
        }
    }
    
    
    @objc func displayBlackCurtainDidChange(_ notification: Notification) {
        // Set correct state for menu item
        displayBlackCurtainItem.state = DisplayController.isBlackCurtainDisplayed ? .on : .off
    }
    
    
    @objc func displayWhiteCurtainDidChange(_ notification: Notification) {
        // Set correct state for menu item
        displayWhiteCurtainItem.state = DisplayController.isWhiteCurtainDisplayed ? .on : .off
    }
    
    
    @objc func displayNavigatorDidChange(_ notification: Notification) {
        // Set correct state for menu item
        showNavigatorItem.state = DisplayController.isNavigatorDisplayed ? .on : .off
    }
    
    
    @objc func displayNextSlidePreviewDidChange(_ notifcation: Notification) {
        // Set correct state for menu item
        previewNextSlideItem.state = DisplayController.isNextSlidePreviewDisplayed ? .on : .off
    }
    
    
    @objc func displayPointerDidChange(_ notification: Notification) {
        // Set correct state for menu item
        showPointerItem.state = DisplayController.isPointerDisplayed ? .on : .off
    }
    
    
    @objc func pointerAppearanceDidChange(_ notification: Notification) {
        // Turn off all items in notes position menu
        pointerAppearanceMenu.items.forEach({ $0.state = .off })
        
        // Select correct menu item for notes position
        switch DisplayController.pointerAppearance {
        case .cursor:
            pointerAppearanceCursorItem.state = .on
        case .dot:
            pointerAppearanceDotItem.state = .on
        case .circle:
            pointerAppearanceCircleItem.state = .on
        case .target:
            pointerAppearanceTargetItem.state = .on
        case .targetColor:
            pointerAppearanceTargetColorItem.state = .on
        }
    }
    
    
    @objc func timeModeDidChange(_ notification: Notification) {
        // Turn off all items in mode menu
        timeModeMenu.items.forEach({ $0.state = .off })
        
        // Select correct menu item for notes position
        // Enable/Disable "Set Timer" menu item
        switch TimeController.timeMode {
        case .stopwatch:
            stopwatchModeItem.state = .on
            setTimerItem.isEnabled = false
        case .timer:
            timerModeItem.state = .on
            setTimerItem.isEnabled = true
        }
        
        TimeController.resetTime(sender: self)
    }
}
