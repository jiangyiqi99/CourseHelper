//
//  Ext.swift
//  CourseHelper
//
//  Created by 蒋翌琪 on 2024/12/23.
//

import Foundation


// 扩展String以支持正则表达式匹配
extension String {
    func matches(for regex: String) -> [[String]] {
        do {
            let regex = try NSRegularExpression(pattern: regex, options: [])
            let nsString = self as NSString
            let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
            return results.map { result in
                (0..<result.numberOfRanges).map { result.range(at: $0).location != NSNotFound ? nsString.substring(with: result.range(at: $0)) : "" }
            }
        } catch {
            print("无效的正则表达式: \(error.localizedDescription)")
            return []
        }
    }
}
