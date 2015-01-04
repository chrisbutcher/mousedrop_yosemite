//
//  AppDelegate.swift
//  MouseDrop
//
//  Created by chris on 2014-12-09.
//  Copyright (c) 2014 chris. All rights reserved.
//

import Cocoa
import Foundation
import Alamofire

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSComboBoxDelegate {

    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var txtUserEmail: NSTextField!
    @IBOutlet weak var txtUserPassword: NSTextField!
    @IBOutlet weak var txtRemoteHost: NSTextField!
    @IBOutlet weak var txtMouseID: NSTextField!
    
    var statusBar = NSStatusBar.systemStatusBar()
    var statusBarItem : NSStatusItem = NSStatusItem()
    
    var lastLocalTimestamp = 0
    var lastLocalMD5 = ""
    var lastMD5Sent = ""
    
    var httpSessionManager:Manager?
    
    var user_email = ""
    var user_password = ""
    var remote_host = "http://localhost:3000"
    
    @IBOutlet weak var statusBarMeu: NSMenu!
    
    @IBAction func clickedQuitApp(sender: AnyObject) {
        self.quitApp()
    }
    
    @IBAction func clickedSignIn(sender: AnyObject) {
        txtUserEmail.stringValue = NSUserDefaults.standardUserDefaults().objectForKey("user_email") as String!
        txtUserPassword.stringValue = NSUserDefaults.standardUserDefaults().objectForKey("user_password") as String!
        txtRemoteHost.stringValue = NSUserDefaults.standardUserDefaults().objectForKey("remote_host") as String!
        
        txtMouseID.stringValue = getPasteURL(USBMouse.getUSBMouseID())
        
        window.makeKeyAndOrderFront(self)
        NSApp.activateIgnoringOtherApps(true)
    }
    
    @IBAction func clickedSignOut(sender: AnyObject) {
        NSUserDefaults.standardUserDefaults().removeObjectForKey("user_email")
        NSUserDefaults.standardUserDefaults().removeObjectForKey("user_password")
        NSUserDefaults.standardUserDefaults().removeObjectForKey("remote_host")
        handlePreferences()
        runSimpleModal("Signed out.")
    }

    @IBAction func clickedConfirmLogin(sender: AnyObject) {
        NSUserDefaults.standardUserDefaults().setObject(txtUserEmail.stringValue, forKey: "user_email")
        NSUserDefaults.standardUserDefaults().setObject(txtUserPassword.stringValue, forKey: "user_password")
        NSUserDefaults.standardUserDefaults().setObject(txtRemoteHost.stringValue, forKey: "remote_host")
        handlePreferences()
        signIn()
        
        window.orderOut(self)
    }
    
    @IBAction func clickedCancelLogin(sender: AnyObject) {
        window.orderOut(self)
    }
    
    func handlePreferences() {
        if let user_email = NSUserDefaults.standardUserDefaults().objectForKey("user_email") as String? {
            self.user_email = user_email
        } else {
            NSUserDefaults.standardUserDefaults().setObject("email@email.com", forKey: "user_email")
        }
        
        if let user_password = NSUserDefaults.standardUserDefaults().objectForKey("user_password") as String? {
            self.user_password = user_password
        } else {
            NSUserDefaults.standardUserDefaults().setObject("", forKey: "user_password")
        }
        
        if let remote_host = NSUserDefaults.standardUserDefaults().objectForKey("remote_host") as String? {
            self.remote_host = remote_host
        } else {
            NSUserDefaults.standardUserDefaults().setObject("http://localhost:3000", forKey: "remote_host")
        }
    }
    
    func quitApp() {
        NSApplication.sharedApplication().terminate(0)
    }
    
    override func awakeFromNib() {
        statusBarItem = statusBar.statusItemWithLength(-1)
        statusBarItem.menu = statusBarMeu
        statusBarItem.title = "DropMouse"
    }
    
    func runSimpleModal(modalText:String) {
        var alert:NSAlert = NSAlert()
        alert.messageText = modalText
        alert.runModal()
    }
    
    func getCurrentTimestamp() -> Int {
        let date = NSDate()
        let timestamp = date.timeIntervalSince1970
        return Int(timestamp)
    }
    
    func httpSignIn() ->Request {
        let parameters = [
            "user": [
                "email": self.user_email,
                "password": self.user_password
            ]
        ]
        
        httpSessionManager = Alamofire.Manager.sharedInstance
        var res = httpSessionManager!.request(.POST, "\(self.remote_host)/users/sign_in", parameters: parameters)
        
        res.task.resume() // Wait for async call to backend
        return res
    }
    
    func getStringFromClipboard () ->String {
        let pasteboardContents:[AnyObject]? =  NSPasteboard.generalPasteboard().pasteboardItems
        
        let firstItem = pasteboardContents!.first as NSPasteboardItem!
        let textContents = firstItem.dataForType("public.utf8-plain-text") as NSData!
        let decodedContents = NSString(data: textContents, encoding: NSUTF8StringEncoding) as NSString!
        
        return decodedContents
    }
    
    func setStringToClipboard (input_string: String) {
        var pasteBoard = NSPasteboard.generalPasteboard()
        
        pasteBoard.clearContents()
        pasteBoard.writeObjects([input_string])
    }
    
    func signIn() {
        var sign_in_res = httpSignIn()
        sign_in_res.responseString { (_, response, string, errors) in
            
            if response? != nil {
                println("Attempting sign in. Response code: \(response!.statusCode)")
            } else {
                self.runSimpleModal("Could not connect to remote server")
            }
        }
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        handlePreferences()
        signIn()
        
        var localTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("localTick"), userInfo: nil, repeats: true)

        var syncTimer = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: Selector("syncTick"), userInfo: nil, repeats: true)
    }
    
    func httpPostPaste(contents: String, device_uuid: String) {
        let parameters = [
            "paste": [
                "contents": contents,
                "device_uuid": device_uuid
            ]
        ]
        
        var res = httpSessionManager!.request(.POST, "\(self.remote_host)/paste.json", parameters: parameters, encoding: .JSON)
            .responseJSON { (request, response, jsonResponse, error) in
                let json = JSON(jsonResponse!)
                println("Paste accepted on remote at:")
                println(json["paste"]["timestamp"])
        }
    }
    
    func getPasteURL(device_uuid: String) ->String {
        return "\(self.remote_host)/paste.json?paste[device_uuid]=\(device_uuid)"
    }
    
    func syncClipboard(device_uuid: String) {
        httpSessionManager!.request(.GET, getPasteURL(device_uuid))
            .responseJSON { (_, response, jsonResponse, _) in
                println("Checking remote paste")
                
                if response? != nil {
                    if response!.statusCode == 200 {
                        let json = JSON(jsonResponse!)
                        
                        var lastRemoteTimestamp = -1
                        
                        if json["paste"]["contents"] != nil {
                            var remoteClipboardContents = json["paste"]["contents"].string!
                            var lastRemoteMD5 = remoteClipboardContents.MD5()
                        
                            if json["paste"]["timestamp"].string? != nil {
                                lastRemoteTimestamp = json["paste"]["timestamp"].string!.toInt()!
                            }
                        
                            if lastRemoteTimestamp > self.lastLocalTimestamp {
                                if lastRemoteMD5 != self.lastLocalMD5 {
                                    // Save remote to local
                                    println("Copying paste from remote to local")
                                    self.setStringToClipboard(remoteClipboardContents)
                                    self.lastLocalMD5 = lastRemoteMD5
                                    self.lastLocalTimestamp = lastRemoteTimestamp
                                }
                            }
                        }
                        if lastRemoteTimestamp < self.lastLocalTimestamp {
                            let localClipboardContents = self.getStringFromClipboard()
                            let localClipboardContentsMD5 = localClipboardContents.MD5()
                            
                            if self.lastMD5Sent != localClipboardContentsMD5 {
                                // Send local to remote
                                println("Copying paste from local to remote")
                                self.httpPostPaste(localClipboardContents, device_uuid: device_uuid)
                                self.lastMD5Sent = localClipboardContentsMD5
                            }
                        }
                    } else {
                        println("Not logged in")
                    }
                }
        }
    }
    
    func syncTick() {
        if self.user_password != "" {
            syncClipboard(USBMouse.getUSBMouseID())
        }
    }
    
    func localTick() {
        let localClipboardContents = getStringFromClipboard()
        let localClipboardContentsMD5 = localClipboardContents.MD5()
        
        if self.lastLocalMD5 != localClipboardContentsMD5 {
            self.lastLocalMD5 = localClipboardContentsMD5
            self.lastLocalTimestamp = getCurrentTimestamp()
        }
    }

//    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
//    }

//    func applicationDidBecomeActive(notification: NSNotification) {
//        println("Window became active")
//    }
}
