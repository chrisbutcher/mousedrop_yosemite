//
//  USBMouse.swift
//  MouseDrop
//
//  Created by chris on 2015-01-03.
//  Copyright (c) 2015 chris. All rights reserved.
//

import Foundation

class USBMouse {
    class func getUSBMouseBlock() ->String {
        var task:NSTask = NSTask()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-Src", "IOUSBDevice", "-lw 0"]
        
        let pipe = NSPipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let ioregOutput: String = NSString(data: data, encoding: NSUTF8StringEncoding)!
        
        let outputWithoutNewlines = ioregOutput.stringByReplacingOccurrencesOfString("\n", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        
        let result = StringUtils.regexMatchInString(outputWithoutNewlines,
            pattern: "\\+\\-o IOHIDPointing(.+?)\\+\\-o")
        
        return result
    }
    
    class func valueFromIoRegOutput(input_string: String, key: String, valueIsNumber: Bool) -> String {
        var pattern = "\"\(key)\" = "
        let patternPrefixLength = (pattern as NSString).length
        
        if valueIsNumber {
            pattern += "\\d+"
        }
        else
        {
            pattern += "\"(.+?)\""
        }
        
        let result = StringUtils.regexMatchInString(input_string, pattern: pattern)
        
        return result
    }
    
    class func getUSBMouseID () ->String {
        let usbMouseBlock = getUSBMouseBlock()
        
        let manufacturer = valueFromIoRegOutput(usbMouseBlock, key: "Manufacturer", valueIsNumber: false)
        let vendorID = valueFromIoRegOutput(usbMouseBlock, key: "VendorID", valueIsNumber: true)
        let productID = valueFromIoRegOutput(usbMouseBlock, key: "ProductID", valueIsNumber: true)
        let product = valueFromIoRegOutput(usbMouseBlock, key: "Product", valueIsNumber: false)
        let versionNumber = valueFromIoRegOutput(usbMouseBlock, key: "VersionNumber", valueIsNumber: true)
        
        let joinedValues = ",".join([manufacturer, vendorID, productID, product, versionNumber])
        let result = StringUtils.MD5FromString(joinedValues)
        return result
    }
}