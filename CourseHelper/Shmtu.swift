//
//  Shmtu.swift
//  CourseHelper
//
//  Created by 蒋翌琪 on 2024/12/23.
//

import Foundation
import EventKit
import SwiftUI
import WebKit

struct ShmtuWebView: UIViewRepresentable {
    var url: URL
    let handleResponse: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // Configure the script message handler
        webView.configuration.userContentController.add(context.coordinator, name: "jsHandler")
        
        // Inject JavaScript to capture specific XMLHttpRequests
        let scriptSource = """
        (function() {
            var originalOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url, async, user, pass) {
                var checkUrl = 'courseTableForStd!courseTable.action';
                if (url.includes(checkUrl)) {
                    this.addEventListener('load', function() {
                        if (this.readyState === 4) {
                            window.webkit.messageHandlers.jsHandler.postMessage({
                                type: 'xhr',
                                method: method,
                                url: url,
                                status: this.status,
                                responseText: this.responseText
                            });
                        }
                    });
                }
                originalOpen.call(this, method, url, async, user, pass);
            };
        })();
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: ShmtuWebView

        init(_ webView: ShmtuWebView) {
            self.parent = webView
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Optionally handle page load completion
        }

        func webView(_ webView: WKWebView, didReceive response: URLResponse, from navigation: WKNavigation!) {
            // Optionally handle HTTP responses
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Optionally handle navigation errors
        }

        // Handle messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let messageBody = message.body as? [String: Any],
               let type = messageBody["type"] as? String,
               type == "xhr" {
                if let responseText = messageBody["responseText"] as? String {
                    DispatchQueue.main.async {
                        self.parent.handleResponse(responseText)
                    }
                }
            }
        }
    }
}

struct ShmtuCourseType {
    let courseName: String
    let teacherName: String
    let classroom: String
    let startDate: Date
    let endDate: Date
}

class ShmtuDecode {
    // 定义课程信息结构体
    struct TaskActivity {
        let taskID: String
        let teacherName: String
        let courseCode: String
        let courseName: String
        let someID: String
        let classroom: String
        let schedule: String
    }

    // 定义上课时间结构体
    struct ClassSchedule {
        let dayOfWeek: Int    // 0代表星期一，1代表星期二，依此类推
        let session: Int      // 第几节课（0代表第一节，1代表第二节）
    }

    // 定义课程时间结构体
    struct CourseTime {
        let startDate: Date
        let endDate: Date
    }

    // 定义第一周的起始日期（例如，2024年2月12日是星期一）
    static let semesterStartDate: Date = {
        var dateComponents = DateComponents()
        dateComponents.year = 2024
        dateComponents.month = 9
        dateComponents.day = 9
        dateComponents.hour = 0
        dateComponents.minute = 0
        let calendar = Calendar.current
        return calendar.date(from: dateComponents) ?? Date()
    }()

    // 定义每节课的时间段
    static let classTimes: [Int: (start: String, end: String)] = [
        1: ("08:20", "09:05"),
        2: ("09:10", "09:55"),
        3: ("10:15", "11:00"),
        4: ("11:05", "11:50"),
        5: ("11:55", "12:25"),
        6: ("12:30", "13:00"),
        7: ("13:10", "13:55"),
        8: ("14:00", "14:45"),
        9: ("15:05", "15:50"),
        10: ("15:55", "16:40"),
        11: ("18:00", "18:45"),
        12: ("18:50", "19:35"),
        13: ("19:40", "20:25")
    ]

    // 解析原始数据
    static func parseScheduleData(input: String) -> (TaskActivity?, [ClassSchedule], [Int]) {
        // 修改后的正则表达式，允许字段为空
        let taskActivityPattern = #"TaskActivity\("([^"]*)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)"\);"#

        // 正则表达式匹配所有 index 行
        let indexPattern = #"index\s*=\s*(\d+)\s*\*\s*unitCount\s*\+\s*(\d+);"#

        var taskActivity: TaskActivity? = nil
        var classSchedules: [ClassSchedule] = []
        var weeks: [Int] = []

        // 匹配 TaskActivity
        let taskMatches = input.matches(for: taskActivityPattern)
        for match in taskMatches {
            if match.count == 8 {
                taskActivity = TaskActivity(
                    taskID: match[1].isEmpty ? "未知" : match[1],
                    teacherName: match[2].isEmpty ? "未知" : match[2],
                    courseCode: match[3].isEmpty ? "未知" : match[3],
                    courseName: match[4].isEmpty ? "未知" : match[4],
                    someID: match[5].isEmpty ? "未知" : match[5],
                    classroom: match[6].isEmpty ? "未知" : match[6],
                    schedule: match[7].isEmpty ? "未知" : match[7]
                )
            }
        }

        // 匹配所有 index 行
        let indexMatches = input.matches(for: indexPattern)
        for match in indexMatches {
            if match.count == 3 {
                if let day = Int(match[1]), let session = Int(match[2]) {
                    classSchedules.append(ClassSchedule(dayOfWeek: day, session: session))
                }
            }
        }

        // 解析 schedule 字符串，获取上课周次
        if let schedule = taskActivity?.schedule {
            weeks = getWeekNumbers(schedule: schedule)
        }

        return (taskActivity, classSchedules, weeks)
    }


    // 根据 schedule 字符串获取上课周次
    static func getWeekNumbers(schedule: String) -> [Int] {
        var weekNumbers: [Int] = []
        let binarySchedule = Array(schedule)
        // 从第一位实际代表的第一周开始，index从1开始
        for (index, char) in binarySchedule.enumerated() where index > 0 {
            if char == "1" {
                weekNumbers.append(index)
            }
        }
        return weekNumbers
    }

    // 计算具体的上课时间并生成 ShmtuCourseType 对象
    static func computeCourseTimes(taskActivity: TaskActivity?, classSchedules: [ClassSchedule], weeks: [Int]) -> [ShmtuCourseType] {
        var courseTypes: [ShmtuCourseType] = []

        guard let activity = taskActivity else {
            print("未找到课程信息。")
            return courseTypes
        }

        for schedule in classSchedules {
            let day = schedule.dayOfWeek // 0: 星期一, 1: 星期二, ..., 6: 星期日
            let session = schedule.session + 1 // 第几节课（1开始）

            // 获取具体的时间段
            if let classTime = classTimes[session] {
                // 计算具体的日期
                let weekOffset = weeks.map { $0 - 1 } // 周次从1开始，所以减1
                for week in weekOffset {
                    if let classDate = Calendar.current.date(byAdding: .weekOfYear, value: week, to: semesterStartDate),
                       let specificDate = Calendar.current.date(byAdding: .day, value: day, to: classDate) {

                        // 解析 classTime.start 和 classTime.end 为时间组件
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "HH:mm"

                        guard let startTime = dateFormatter.date(from: classTime.start),
                              let endTime = dateFormatter.date(from: classTime.end) else {
                            continue
                        }

                        // 获取具体日期的年、月、日
                        let calendar = Calendar.current
                        let dateComponents = calendar.dateComponents([.year, .month, .day], from: specificDate)

                        // 获取时间组件的小时和分钟
                        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

                        // 组合日期和时间
                        var startDateComponents = dateComponents
                        startDateComponents.hour = startComponents.hour
                        startDateComponents.minute = startComponents.minute

                        var endDateComponents = dateComponents
                        endDateComponents.hour = endComponents.hour
                        endDateComponents.minute = endComponents.minute

                        if let startDate = calendar.date(from: startDateComponents),
                           let endDate = calendar.date(from: endDateComponents) {
                            let courseType = ShmtuCourseType(
                                courseName: activity.courseName,
                                teacherName: activity.teacherName,
                                classroom: activity.classroom,
                                startDate: startDate,
                                endDate: endDate
                            )
                            courseTypes.append(courseType)
                        }
                    }
                }
            } else {
                print("未定义的节次: 第\(session)节课")
            }
        }

        return courseTypes
    }


    static func InsertToComplete(in inputString: String) -> String {
        let targetLine = "function containFakeCourse(fakeCourse)"
        let newLine = "            activity = new"
        
        // 查找目标行的位置
        if let range = inputString.range(of: targetLine) {
            // 获取目标行之前的部分
            var beforeTarget = inputString[..<range.lowerBound]
            
            // 查找 "beforeTarget" 末尾的最后一个分号的位置
            if let semicolonRange = beforeTarget.range(of: ";", options: .backwards) {
                // 截取分号前的部分，删除分号后面的所有字符
                beforeTarget = beforeTarget[..<semicolonRange.lowerBound]
            }
            
            // 构造新的字符串，插入新的行
            let newString = beforeTarget + "\n" + newLine + "\n"
            
            // 返回修改后的字符串
            return String(newString)
        }
        
        // 如果没有找到目标行，则返回原字符串
        return inputString
    }
}

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

class ShmtuCalendar: ObservableObject {
    private var eventStore: EKEventStore
    private var calendar: EKCalendar?
    private var eventsToAdd: [EKEvent]
    private var isCalendarReady = false

    // 存储课程类型
    private var courseTypes: [ShmtuCourseType] = []
    
    // 新增的提醒时间偏移量属性（以秒为单位）
    var reminderOffset: TimeInterval? = nil

    // 简化的初始化方法
    init() {
        self.eventStore = EKEventStore()
        self.eventsToAdd = []
    }
    
    // 添加课程类型，追加到现有数组
    func addCourses(courseTypes: [ShmtuCourseType]) {
        self.courseTypes.append(contentsOf: courseTypes)
    }

    // 清空课程类型
    func clearCourses() {
        self.courseTypes.removeAll()
    }

    // 设置和请求权限，创建日历
    func setupCalendar(completion: @escaping (Bool) -> Void) {
        // 请求访问权限
        eventStore.requestAccess(to: .event) { [weak self] (granted, error) in
            guard let self = self else { return }
            if granted {
                self.createCalendar(completion: completion)
            } else {
                print("没有获得访问日历的权限: \(error?.localizedDescription ?? "未知错误")")
                completion(false)
            }
        }
    }
 
    // 创建"上海海事大学"日历
    private func createCalendar(completion: @escaping (Bool) -> Void) {
        // 检查是否已存在名为"上海海事大学"的日历
        if let existingCalendar = eventStore.calendars(for: .event).first(where: { $0.title == "上海海事大学" }) {
            self.calendar = existingCalendar
            self.isCalendarReady = true
            print("已存在日历: \(existingCalendar.title ?? "")")
            completion(true)
            return
        }

        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "上海海事大学"
        
        // 设置日历来源，优先使用本地日历
        if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = source
        } else {
            // 如果没有本地日历源，可以选择iCloud日历源
            if let icloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
                newCalendar.source = icloudSource
            }
        }
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            self.calendar = newCalendar
            print("创建日历成功: \(newCalendar.title ?? "")")
            self.isCalendarReady = true
            completion(true)
        } catch {
            print("创建日历失败: \(error.localizedDescription)")
            completion(false)
        }
    }

    // 将事件添加到待添加事件列表
    private func appendEvent(title: String, startDate: Date, endDate: Date, location: String? = nil, notes: String? = nil) {
        guard isCalendarReady, let calendar = self.calendar else {
            print("没有找到有效的日历")
            return
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        
        if let location = location {
            event.location = location
        }
        
        if let notes = notes {
            event.notes = notes
        }
        
        // 根据 reminderOffset 设置提醒
        if let offset = reminderOffset {
            let alarm = EKAlarm(relativeOffset: offset)
            event.addAlarm(alarm)
            let minutes = abs(Int(offset) / 60)
            print("提醒已设置：提前\(minutes)分钟")
        } else {
            print("不设置提醒")
        }
        
        self.eventsToAdd.append(event)
        print("事件已添加到待保存列表: \(event.title ?? "")")
    }

    // 将所有待添加的课程转换为日历事件并保存
    func addCoursesToCalendar(completion: @escaping (Bool, String) -> Void) {
        setupCalendar { [weak self] success in
            guard let self = self else { return }
            if success {
                for course in self.courseTypes {
                    self.appendEvent(
                        title:"\(course.courseName)（\(course.teacherName)）",
                        startDate: course.startDate,
                        endDate: course.endDate,
                        location: "上海海事大学 \(course.classroom)"
                    )
                }
                self.addAllEvents()
                DispatchQueue.main.async {
                    completion(true, "课程已成功添加到您的日历")
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "无法访问日历。请检查您的权限设置。")
                }
            }
        }
    }

    // 一次性将所有待添加的事件保存到日历
    private func addAllEvents() {
        guard isCalendarReady, let calendar = self.calendar else {
            print("没有找到有效的日历")
            return
        }
        
        for event in eventsToAdd {
            do {
                try eventStore.save(event, span: .thisEvent)
                print("事件已保存: \(event.title ?? "")")
            } catch let error {
                print("保存事件失败: \(error.localizedDescription)")
            }
        }
        
        // 清空待添加的事件列表
        eventsToAdd.removeAll()
    }
}
