import Foundation

private let shortWeekdayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "pt_BR")
    f.dateFormat = "EEE"
    return f
}()

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
        shortWeekdayFormatter.string(from: self).capitalized
    }

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: self)
    }
}
