//
//  AppDelegate.swift
//  GoveeController
//
//  Created by Nitin Seshadri on 2/13/22.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        guard let controller = NSStoryboard.main?.instantiateController(withIdentifier: "ViewController") as? NSViewController else {
            fatalError("Could not instantiate initial view controller")
        }
        
        popover = NSPopover()
        popover.contentViewController = controller
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "g.circle", accessibilityDescription: "Govee Controller")
            button.action = #selector(togglePopover(sender:))
            button.target = self
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @objc func togglePopover(sender: AnyObject) {
        if (popover.isShown) {
            hidePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: AnyObject) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }
    
    func hidePopover(_ sender: AnyObject) {
        popover.performClose(sender)
    }

}

