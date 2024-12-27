//
//  ContentView.swift
//  CourseHelper
//
//  Created by 蒋翌琪 on 2024/12/22.
//

import SwiftUI
import Foundation



struct ContentView: View {
    let universities = ["上海海事大学", "华东师范大学（TimTNT）", "上海财经大学（Polaris）"]
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
                    } else if university == "华东师范大学（TimTNT）" {
                        NavigationLink(
                            destination: EcnuWebView(url: URL(string: "https://applicationnewjw.ecnu.edu.cn/eams/courseTableForStd.action")!) { response, semeInfo in
                                // 接收来自 EcnuWebView 的响应数据
                                self.capturedData = response
                                self.semesterInfo = semeInfo
                                self.chosenSchool = "华东师范大学"
                                self.showConfirmButton = true
                            }
                        ) {
                            Text(university)
                        }
                    }
                    else if university == "上海财经大学（Polaris）"{
                        NavigationLink(
                            destination: SufeWebView(url: URL(string: "https://eams.sufe.edu.cn/eams/courseTableForStd!index.action")!) { response, semeInfo in
                                // 接收来自 EcnuWebView 的响应数据
                                self.capturedData = response
                                self.semesterInfo = semeInfo
                                self.chosenSchool = "上海财经大学"
                                self.showConfirmButton = true
                            }
                        ) {
                            Text(university)
                        }
                    } else {
                        Text(university)
                    }
                }
                
                // 提醒时间选择项
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
                let courseDecoder=ShmtuDecode()
                courseDecoder.MainProcess(capturedString: self.capturedData, semesterInfo: self.semesterInfo, reminderTime: self.reminderTime)
                self.showConfirmButton = false
            }
            
            if chosenSchool == "华东师范大学" {
                let courseDecoder=EcnuDecode()
                courseDecoder.MainProcess(capturedString: capturedData, semesterInfo: self.semesterInfo, reminderTime: self.reminderTime)
                self.showConfirmButton = false
            }
            
            if chosenSchool == "上海财经大学" {
                let courseDecoder=SufeDecode()
                courseDecoder.MainProcess(capturedString: capturedData, semesterInfo: self.semesterInfo, reminderTime: self.reminderTime)
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
