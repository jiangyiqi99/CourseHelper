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
    @State private var showConfirmButton = false
    @State private var chosenSchool = ""
    @State private var capturedData = ""
    @State private var semesterInfo = ""
    @State private var reminderTime = "不提醒"
    @State private var isDemoMode = false
    let reminderOptions = ["不提醒", "15分钟", "30分钟"]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(universities, id: \.self) { university in
                    NavigationLink(
                        destination: destinationView(for: university),
                        label: {
                            Text(university)
                        }
                    )
                }
                
                Section(header: Text("提醒时间")) {
                    Picker("提醒时间", selection: $reminderTime) {
                        ForEach(reminderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // 演示模式开关
                Toggle("演示模式（Demo Mode）", isOn: $isDemoMode)
                    .onChange(of: isDemoMode) { _ in
                        // 每次切换演示模式时重置
                        showConfirmButton = false
                        chosenSchool = ""
                        capturedData = ""
                        semesterInfo = ""
                    }
            }
            .navigationBarTitle("选择学校")
            .navigationBarItems(trailing: confirmButton)
        }
    }
    
    @ViewBuilder
    private func destinationView(for university: String) -> some View {
        if isDemoMode {
            DemoLoginView(universityName: university, showConfirmButton: $showConfirmButton, capturedData: $capturedData, chosenSchool: $chosenSchool)

        } else {
            universityView(university)
        }
    }
    
    @ViewBuilder
    private func universityView(_ university: String) -> some View {
        if university == "上海海事大学" {
            ShmtuWebView(url: URL(string: "https://jwxt.shmtu.edu.cn/shmtu/courseTableForStd.action")!) { response, semeInfo in
                self.semesterInfo = semeInfo
                self.capturedData = response
                self.chosenSchool = "上海海事大学"
                self.showConfirmButton = true
            }
        } else if university == "华东师范大学（TimTNT）" {
            EcnuWebView(url: URL(string: "https://applicationnewjw.ecnu.edu.cn/eams/courseTableForStd.action")!) { response, semeInfo in
                self.capturedData = response
                self.semesterInfo = semeInfo
                self.chosenSchool = "华东师范大学"
                self.showConfirmButton = true
            }
        } else if university == "上海财经大学（Polaris）" {
            SufeWebView(url: URL(string: "https://eams.sufe.edu.cn/eams/courseTableForStd!index.action")!) { response, semeInfo in
                self.capturedData = response
                self.semesterInfo = semeInfo
                self.chosenSchool = "上海财经大学"
                self.showConfirmButton = true
            }
        } else {
            Text("未知大学")
        }
    }
    
    
    var confirmButton: some View {
        Button("导入日历") {
            print("选择的学校: \(chosenSchool)")
            if chosenSchool == "演示模式" {
                let courseDecoder=DemoDecode()
                courseDecoder.MainProcess(capturedString: self.capturedData, reminderTime: self.reminderTime)
                self.showConfirmButton = false
            }
            else if chosenSchool == "上海海事大学" {
                let courseDecoder=ShmtuDecode()
                courseDecoder.MainProcess(capturedString: self.capturedData, semesterInfo: self.semesterInfo, reminderTime: self.reminderTime)
                self.showConfirmButton = false
            }
            
            else if chosenSchool == "华东师范大学" {
                let courseDecoder=EcnuDecode()
                courseDecoder.MainProcess(capturedString: capturedData, semesterInfo: self.semesterInfo, reminderTime: self.reminderTime)
                self.showConfirmButton = false
            }
            
            else if chosenSchool == "上海财经大学" {
                let courseDecoder=SufeDecode()
                courseDecoder.MainProcess(capturedString: capturedData, semesterInfo: self.semesterInfo, reminderTime: self.reminderTime)
                self.showConfirmButton = false
            }
        }.disabled(!showConfirmButton)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
