import Foundation

extension DateFormatter {
    static let chineseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

extension Date {
    func formattedChinese() -> String {
        return DateFormatter.chineseDate.string(from: self)
    }
    
    func formattedShort() -> String {
        return DateFormatter.shortDate.string(from: self)
    }
}
