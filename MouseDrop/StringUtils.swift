//
//  StringUtils.swift
//  MouseDrop
//
//  Created by chris on 2015-01-03.
//  Copyright (c) 2015 chris. All rights reserved.
//

import Foundation

class StringUtils {
    class func regexMatchInString(input_string: String, pattern: String) -> String {
        let match = input_string.rangeOfString(pattern, options: .RegularExpressionSearch)
        
        let result = input_string.substringWithRange(match!)
        
        return result
    }
    
    class func MD5FromString(input_string: String) ->String {
        return input_string.MD5()
    }
}