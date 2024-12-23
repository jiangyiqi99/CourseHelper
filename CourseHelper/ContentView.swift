//
//  ContentView.swift
//  CourseHelper
//
//  Created by 蒋翌琪 on 2024/12/22.
//

import SwiftUI
import Foundation

struct ContentView: View {
    let universities = ["上海海事大学", "华东师范大学"]
    @State private var showConfirmButton = false  // 控制确认按钮显示的状态变量
    @State private var shouldNavigate = false  // 控制是否显示详细视图的状态变量
    
    @State private var Chosen_School = ""
    @State private var Captured_Data = ""
    
    @State private var showAlert = false // 控制提示框显示
    @State private var alertMessage = "" // 提示框信息
    
    // 创建 ShmtuCalendar 的实例
    @StateObject private var calendarHelper = ShmtuCalendar()
    
    var body: some View {
        NavigationView {
            List(universities, id: \.self) { university in
                if university == "上海海事大学" {
                    NavigationLink(destination: ShmtuWebView(url: URL(string: "https://jwxt.shmtu.edu.cn/")!) { response in
                        //print("Received response: \(response)")
                        self.Captured_Data = response
                        self.Chosen_School = "上海海事大学"
                        self.showConfirmButton = true
                        self.shouldNavigate = false  // 更新状态，影响视图返回
                    }, isActive: $shouldNavigate) {
                        Text(university)
                    }
                } else {
                    Text(university)
                }
            }
            .navigationBarTitle("选择学校")
            .navigationBarItems(trailing: confirmButton)
            .onAppear {
                self.shouldNavigate = false  // 确保进入时直接停留在主界面
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
            }
        }
    }
    
    var confirmButton: some View {
        Button("导入日历") {
            print(Chosen_School)
            if Chosen_School == "上海海事大学"{
                
                var inputString = Captured_Data
                inputString=ShmtuDecode.InsertToComplete(in: inputString)
                //print(Captured_Data)
                
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
                            //print("Matched content: \(matchedString)")
                            print("\n\n解析到数据")
                            let inputData = matchedString
                            
                            let (taskActivity, classSchedules, weeks) = ShmtuDecode.parseScheduleData(input: String(inputData))
                            
                            
                            if let activity = taskActivity {
                                // 打印课程详细信息
                                
                                print("课程ID: \(activity.taskID)")
                                print("老师: \(activity.teacherName)")
                                print("课程名: \(activity.courseName)")
                                print("教室: \(activity.classroom)")
                                print("上课周次: \(activity.schedule)")
                                 
                            } else {
                                print("未找到课程信息。")
                            }
                             
                            
                            // 计算并生成 ShmtuCourseType 对象
                            let generatedCourseTypes = ShmtuDecode.computeCourseTimes(taskActivity: taskActivity, classSchedules: classSchedules, weeks: weeks)
                            
                            // 将生成的课程类型传递给 ShmtuCalendar
                            self.calendarHelper.addCourses(courseTypes: generatedCourseTypes)
                        }
                    }
                    
                    
                    
                    // 添加课程到日历
                    self.calendarHelper.addCoursesToCalendar { success, message in
                        self.alertMessage = message
                        self.showAlert = true
                        
                        if success {
                            // 添加成功后清空课程类型数组
                            self.calendarHelper.clearCourses()
                        }
                    }
                    self.showConfirmButton = false
                } catch {
                    print("Invalid regular expression: \(error)")
                    self.alertMessage = "解析数据时出错。"
                    self.showAlert = true
                }
                
            }
        }.disabled(!showConfirmButton)
    }
}