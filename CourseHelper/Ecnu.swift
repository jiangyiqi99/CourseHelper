//
//  Ecnu.swift
//  CourseHelper
//
//  Created by 蒋翌琪 on 2024/12/23.
//

import Foundation
import EventKit
import SwiftUI
import WebKit


import SwiftUI
import WebKit

struct EcnuWebView: UIViewRepresentable {
    var url: URL
    
    /// 将原先的 (String) -> Void 改为 (String, String) -> Void，
    /// 用于同时回传 requestBody 和 responseText
    var onResponse: (String, String) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        // 配置 WKWebView 的配置对象
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // 注入 JavaScript 脚本
        // 注意：只有重写 open 和 send 才能捕获到请求体
        let js = """
        (function() {
            // 保存原本的 XHR prototype
            var originalOpen = XMLHttpRequest.prototype.open;
            var originalSend = XMLHttpRequest.prototype.send;
            
            // 重写 open，用来记录 method、url
            XMLHttpRequest.prototype.open = function(method, url, async, user, pass) {
                this._method = method;
                this._url = url;
                return originalOpen.apply(this, arguments);
            };
            
            // 重写 send，用来捕获 requestBody
            XMLHttpRequest.prototype.send = function(body) {
                this._body = body;
                
                // 如果是 POST，并且 URL 包含 'courseTableForStd!courseTable.action'
                // 则在请求完成后，把 requestBody 和 responseText 一并发送给 Swift
                if (this._method === 'POST' && this._url.includes('courseTableForStd!courseTable.action')) {
                    var selfXHR = this;
                    this.addEventListener('readystatechange', function() {
                        if (selfXHR.readyState === 4 && selfXHR.status === 200) {
                            window.webkit.messageHandlers.postHandler.postMessage({
                                requestBody: selfXHR._body || '',
                                responseText: selfXHR.responseText || ''
                            });
                        }
                    });
                }
                
                return originalSend.apply(this, arguments);
            };
        })();
        """
        
        // 创建用户脚本并添加到内容控制器
        let userScript = WKUserScript(
            source: js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(userScript)
        
        // 添加消息处理器
        userContentController.add(context.coordinator, name: "postHandler")
        
        configuration.userContentController = userContentController
        
        // 创建 WKWebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 仅在需要时加载请求，避免重复加载
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(onResponse: onResponse)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        /// 回调闭包，(requestBody, responseText)
        var onResponse: (String, String) -> Void
        
        init(onResponse: @escaping (String, String) -> Void) {
            self.onResponse = onResponse
        }
        
        // 处理导航完成
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView did finish loading")
        }
        
        // 处理导航失败
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed with error: \(error.localizedDescription)")
        }
        
        // 处理消息：只当 JS postMessage 传来 {requestBody, responseText} 时触发
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "postHandler" {
                if let dict = message.body as? [String: Any] {
                    // 只有都存在时才回传
                    let requestBody = dict["requestBody"] as? String ?? ""
                    let responseText = dict["responseText"] as? String ?? ""
                    let semesterInfo = parseSemesterId(from: requestBody)
                    
                    if(semesterInfo != "未知学期"){
                        // 弹窗显示
                        let alertController = UIAlertController(
                            title: "提示",
                            message: "获取到\(semesterInfo)的课表\n你可以选择切换学期或返回导入",
                            preferredStyle: .alert
                        )
                        alertController.addAction(
                            UIAlertAction(title: "OK", style: .default)
                        )
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            var topController = rootVC
                            while let presentedVC = topController.presentedViewController {
                                topController = presentedVC
                            }
                            topController.present(alertController, animated: true)
                        }
                        
                        //返回到主进程
                        onResponse(responseText, semesterInfo)
                        
                    } else {
                        // 弹窗显示
                        let alertController = UIAlertController(
                            title: "错误",
                            message: "未知学期\n\(requestBody)",
                            preferredStyle: .alert
                        )
                        alertController.addAction(
                            UIAlertAction(title: "OK", style: .default)
                        )
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            var topController = rootVC
                            while let presentedVC = topController.presentedViewController {
                                topController = presentedVC
                            }
                            topController.present(alertController, animated: true)
                        }
                    }
                }
            }
        }
        
        // 辅助函数用于解析请求体中的 semester.id
        func parseSemesterId(from requestBody: String) -> String {
            let pattern = "semester\\.id=(\\d+)"
            if let range = requestBody.range(of: pattern, options: .regularExpression) {
                let semesterId = requestBody[range].components(separatedBy: "=").last ?? ""
                switch semesterId {
                case "1281":
                    return "2024-2025学年1学期"
                case "1313":
                    return "2024-2025学年2学期"
                default:
                    return "未知学期"
                }
            } else {
                return "未知学期"
            }
        }
    }
}



struct EcnuCourseType {
    let courseName: String
    let teacherName: String
    let classroom: String
    let startDate: Date
    let endDate: Date
}



class EcnuDecode {
    
    
    private let ecnucalendarHelper = EcnuCalendar()
    
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
    private var semesterStartDate: Date = {
        var dateComponents = DateComponents()
        dateComponents.year = 2024
        dateComponents.month = 9
        dateComponents.day = 9
        dateComponents.hour = 0
        dateComponents.minute = 0
        let calendar = Calendar.current
        return calendar.date(from: dateComponents) ?? Date()
    }()
    
    // 创建一个静态函数来修改 semesterStartDate
    private func updateSemesterStartDate(with option: String) {
        var dateComponents = DateComponents()
        dateComponents.hour = 0
        dateComponents.minute = 0
        
        switch option {
        case "2024-2025学年1学期":
            dateComponents.year = 2024
            dateComponents.month = 9
            dateComponents.day = 9
        case "2024-2025学年2学期":
            dateComponents.year = 2025
            dateComponents.month = 2
            dateComponents.day = 17
        default:
            break
        }
        
        if let newDate = Calendar.current.date(from: dateComponents) {
            self.semesterStartDate = newDate
        }
    }
    
    // 定义每节课的时间段
    private let classTimes: [Int: (start: String, end: String)] = [
        1: ("08:00", "08:45"),
        2: ("08:50", "09:35"),
        3: ("09:50", "10:35"),
        4: ("10:40", "11:25"),
        5: ("11:30", "12:15"),
        6: ("13:00", "13:45"),
        7: ("13:50", "14:35"),
        8: ("14:50", "15:35"),
        9: ("15:40", "16:25"),
        10: ("16:30", "17:15"),
        11: ("18:00", "18:45"),
        12: ("18:50", "19:35"),
        13: ("19:40", "20:25"),
        14: ("20:30", "21:15")
    ]
    
    // 解析原始数据
    private func parseScheduleData(input: String) -> (TaskActivity?, [ClassSchedule], [Int]) {
        // 修改后的正则表达式，允许字段为空
        let taskActivityPattern = #"TaskActivity\("([^"]*)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)"(?:\s*,\s*(?:"[^"]*"|null))*\);"#
        
        // 正则表达式匹配所有 index 行
        let indexPattern = #"index\s*=\s*(\d+)\s*\*\s*unitCount\s*\+\s*(\d+);"#
        
        var taskActivity: TaskActivity? = nil
        var classSchedules: [ClassSchedule] = []
        var weeks: [Int] = []
        
        // 匹配 TaskActivity
        let taskMatches = input.matches(for: taskActivityPattern)
        for match in taskMatches {
            if match.count >= 8 {
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
            weeks = self.getWeekNumbers(schedule: schedule)
        }
        
        return (taskActivity, classSchedules, weeks)
    }
    
    
    // 根据 schedule 字符串获取上课周次
    private func getWeekNumbers(schedule: String) -> [Int] {
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
    
    // 计算具体的上课时间并生成 CourseType 对象
    private func computeCourseTimes(taskActivity: TaskActivity?, classSchedules: [ClassSchedule], weeks: [Int]) -> [EcnuCourseType] {
        var courseTypes: [EcnuCourseType] = []
        
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
                            let courseType = EcnuCourseType(
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
    
    
    private func InsertToComplete(in inputString: String) -> String {
        let targetLine = "table0.marshalTable"
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
    
    func MainProcess(capturedString: String, semesterInfo: String, reminderTime: String){
        
        self.updateSemesterStartDate(with: semesterInfo)
        
        let inputString = self.InsertToComplete(in: capturedString)
        // print(Captured_Data)
        
        // 正则表达式，匹配"activity = new"之间的内容
        let pattern = "(?<=activity = new)(.*?)(?=activity = new)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
            
            // 查找所有匹配项
            let matches = regex.matches(in: inputString, options: [], range: NSRange(inputString.startIndex..., in: inputString))
            
            for match in matches {
                let range = match.range(at: 1) // 获取第一个捕获组
                if let swiftRange = Range(range, in: inputString) {
                    let matchedString = inputString[swiftRange]
                    // print("Matched content: \(matchedString)")
                    print("\n\n解析到数据")
                    let inputData = matchedString
                    
                    let (taskActivity, classSchedules, weeks) = self.parseScheduleData(input: String(inputData))
                    
                    // 计算并生成 CourseType 对象
                    let generatedCourseTypes = self.computeCourseTimes(taskActivity: taskActivity, classSchedules: classSchedules, weeks: weeks)
                    
                    // 将生成的课程类型传递给 Calendar
                    ecnucalendarHelper.addCourses(courseTypes: generatedCourseTypes)
                }
            }
            
            // 根据用户选择设置 reminderOffset
            switch reminderTime {
            case "15分钟":
                ecnucalendarHelper.reminderOffset = -900 // 15分钟 = 900秒
            case "30分钟":
                ecnucalendarHelper.reminderOffset = -1800 // 30分钟 = 1800秒
            default:
                ecnucalendarHelper.reminderOffset = nil // 不提醒
            }
            
            // 添加课程到日历
            ecnucalendarHelper.addCoursesToCalendar { success, message in
                if success {
                    
                    let alertController = UIAlertController(
                        title: "完成",
                        message: message,
                        preferredStyle: .alert
                    )
                    alertController.addAction(
                        UIAlertAction(title: "OK", style: .default)
                    )
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        var topController = rootVC
                        while let presentedVC = topController.presentedViewController {
                            topController = presentedVC
                        }
                        topController.present(alertController, animated: true)
                    }
                }
            }
            
        } catch {
            print("无效的正则表达式: \(error)")
            let alertController = UIAlertController(
                title: "出错",
                message: "解析数据时出错",
                preferredStyle: .alert
            )
            alertController.addAction(
                UIAlertAction(title: "OK", style: .default)
            )
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topController = rootVC
                while let presentedVC = topController.presentedViewController {
                    topController = presentedVC
                }
                topController.present(alertController, animated: true)
            }
        }
    }
    
}


class EcnuCalendar: ObservableObject {
    private var eventStore: EKEventStore
    private var calendar: EKCalendar?
    private var eventsToAdd: [EKEvent]
    private var isCalendarReady = false
    
    // 存储课程类型
    private var courseTypes: [EcnuCourseType] = []
    
    // 新增的提醒时间偏移量属性（以秒为单位）
    var reminderOffset: TimeInterval? = nil
    
    // 简化的初始化方法
    init() {
        self.eventStore = EKEventStore()
        self.eventsToAdd = []
    }
    
    // 添加课程类型，追加到现有数组
    func addCourses(courseTypes: [EcnuCourseType]) {
        self.courseTypes.append(contentsOf: courseTypes)
    }
    
    // 设置和请求权限，创建日历
    private func setupCalendar(completion: @escaping (Bool) -> Void) {
        // 请求访问权限
        eventStore.requestAccess(to: .event) { [self] (granted, error) in
            if granted {
                self.createCalendar(completion: completion)
            } else {
                print("没有获得访问日历的权限: \(error?.localizedDescription ?? "未知错误")")
                completion(false)
            }
        }
    }
    
    // 创建日历
    private func createCalendar(completion: @escaping (Bool) -> Void) {
        // 检查是否已存在的日历
        if let existingCalendar = eventStore.calendars(for: .event).first(where: { $0.title == "华东师范大学" }) {
            self.calendar = existingCalendar
            self.isCalendarReady = true
            print("已存在日历: \(existingCalendar.title)")
            completion(true)
            return
        }
        
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "华东师范大学"
        
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
            print("创建日历成功: \(newCalendar.title)")
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
                        location: "华师大 \(course.classroom)"
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
    }
}
