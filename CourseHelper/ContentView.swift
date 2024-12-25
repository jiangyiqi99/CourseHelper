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
    
    @State private var chosenSchool = ""
    @State private var capturedData = ""
    @State private var semesterInfo = ""
    
    
    // 新增的状态变量，用于存储提醒时间的选择
    @State private var reminderTime = "不提醒"
    let reminderOptions = ["不提醒", "15分钟", "30分钟"]
    
    var body: some View {
        NavigationView {
            List {
                // 显示大学列表
                ForEach(universities, id: \.self) { university in
                    if university == "上海海事大学" {
                        NavigationLink(
                            destination: ShmtuWebView(url: URL(string: "https://jwxt.shmtu.edu.cn/shmtu/courseTableForStd.action")!) { response, semeInfo in
                                // 接收来自 WebView 的响应数据
                                self.semesterInfo = semeInfo
                                self.capturedData = response
                                self.chosenSchool = "上海海事大学"
                                self.showConfirmButton = true
                            }
                        ) {
                            Text(university)
                        }
                    } else if university == "华东师范大学" {
                        NavigationLink(
                            destination: EcnuWebView(url: URL(string: "https://sso.ecnu.edu.cn/login?service=http:%2F%2Fapplicationnewjw.ecnu.edu.cn%2Feams%2Fhome.action%3Furl%3DcourseTableForStd")!) { response, semeInfo in
                                // 接收来自 EcnuWebView 的响应数据
                                self.capturedData = response
                                self.semesterInfo = semeInfo
                                self.chosenSchool = "华东师范大学"
                                self.showConfirmButton = true
                            }
                        ) {
                            Text("华东师范大学")
                        }
                    } else {
                        Text(university)
                    }
                }
                
                // 新增的提醒时间选择项
                Section(header: Text("提醒时间")) {
                    Picker("提醒时间", selection: $reminderTime) {
                        ForEach(reminderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .navigationBarTitle("选择学校")
            .navigationBarItems(trailing: confirmButton)
        }
    }
    
    
    
    var confirmButton: some View {
        Button("导入日历") {
            print("选择的学校: \(chosenSchool)")
            if chosenSchool == "上海海事大学" {
                let shmtuCourse=ShmtuDecode()
                shmtuCourse.updateSemesterStartDate(with: semesterInfo)
                let inputString = capturedData
                
                let processedString = shmtuCourse.InsertToComplete(in: inputString)
                // print(Captured_Data)
                
                shmtuCourse.MainProcess(inputString: processedString, reminderTime: self.reminderTime)
                self.showConfirmButton = false
                
            }
            
            if chosenSchool == "华东师范大学" {
                let ecnuCourse=EcnuDecode()
                ecnuCourse.updateSemesterStartDate(with: semesterInfo)
                let inputString = capturedData
                
                let processedString = ecnuCourse.InsertToComplete(in: inputString)
                // print(Captured_Data)
                
                ecnuCourse.MainProcess(inputString: processedString, reminderTime: self.reminderTime)
                self.showConfirmButton = false
                
                
            }
        }
        .disabled(!showConfirmButton)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
