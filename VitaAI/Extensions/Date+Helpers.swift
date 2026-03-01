import Foundation

extension Date {
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var shortWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE"
        return formatter.string(from: self).capitalized
    }

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: self)
    }
}
