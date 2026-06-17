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
    
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

extension Date {
    /// 格式化为中文长格式：yyyy年MM月dd日
    func formattedChinese() -> String {
        return DateFormatter.chineseDate.string(from: self)
    }
    
    /// 格式化为短格式：MM-dd
    func formattedShort() -> String {
        return DateFormatter.shortDate.string(from: self)
    }
    
    /// 格式化为时间：HH:mm
    func formattedTime() -> String {
        return DateFormatter.timeOnly.string(from: self)
    }
}
