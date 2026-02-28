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
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    let reminderOptions = ["不提醒", "15分钟", "30分钟"]
    
    var body: some View {
        navigationContainer
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
    }

    @ViewBuilder
    private var navigationContainer: some View {
        if #available(iOS 16, *) {
            NavigationStack {
                mainList
            }
        } else {
            NavigationView {
                mainList
            }
        }
    }

    private var mainList: some View {
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

            Toggle("演示模式（Demo Mode）", isOn: $isDemoMode)
                .onChange(of: isDemoMode) { _ in
                    showConfirmButton = false
                    chosenSchool = ""
                    capturedData = ""
                    semesterInfo = ""
                }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("选择学校")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                confirmButton
            }
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
            ShmtuWebView(url: URL(string: "https://jwxt.shmtu.edu.cn/shmtu/courseTableForStd.action")!, handleResponse: { response, semeInfo in
                self.semesterInfo = semeInfo
                self.capturedData = response
                self.chosenSchool = "上海海事大学"
                self.showConfirmButton = true
            }, onAlert: { title, message in
                self.alertTitle = title
                self.alertMessage = message
                self.showAlert = true
            })
        } else if university == "华东师范大学（TimTNT）" {
            EcnuWebView(url: URL(string: "https://applicationnewjw.ecnu.edu.cn/eams/courseTableForStd.action")!, onResponse: { response, semeInfo in
                self.capturedData = response
                self.semesterInfo = semeInfo
                self.chosenSchool = "华东师范大学"
                self.showConfirmButton = true
            }, onAlert: { title, message in
                self.alertTitle = title
                self.alertMessage = message
                self.showAlert = true
            })
        } else if university == "上海财经大学（Polaris）" {
            SufeWebView(url: URL(string: "https://eams.sufe.edu.cn/eams/courseTableForStd!index.action")!, onResponse: { response, semeInfo in
                self.capturedData = response
                self.semesterInfo = semeInfo
                self.chosenSchool = "上海财经大学"
                self.showConfirmButton = true
            }, onAlert: { title, message in
                self.alertTitle = title
                self.alertMessage = message
                self.showAlert = true
            })
        } else {
            Text("未知大学")
        }
    }
    
    
    var confirmButton: some View {
        Button("导入日历") {
            let alertHandler: (String, String) -> Void = { title, message in
                self.alertTitle = title
                self.alertMessage = message
                self.showAlert = true
            }
            print("选择的学校: \(chosenSchool)")
            if chosenSchool == "演示模式" {
                let courseDecoder = DemoDecode()
                courseDecoder.MainProcess(capturedString: self.capturedData, reminderTime: self.reminderTime, onAlert: alertHandler)
                self.showConfirmButton = false
            }
            else if chosenSchool == "上海海事大学" {
                let courseDecoder = ShmtuDecode()
                courseDecoder.MainProcess(capturedString: self.capturedData, semesterInfo: self.semesterInfo, reminderTime: self.reminderTime, onAlert: alertHandler)
                self.showConfirmButton = false
            }
            else if chosenSchool == "华东师范大学" {
                let courseDecoder = EcnuDecode()
                courseDecoder.MainProcess(capturedString: capturedData, semesterInfo: self.semesterInfo, reminderTime: self.reminderTime, onAlert: alertHandler)
                self.showConfirmButton = false
            }
            else if chosenSchool == "上海财经大学" {
                let courseDecoder = SufeDecode()
                courseDecoder.MainProcess(capturedString: capturedData, semesterInfo: self.semesterInfo, reminderTime: self.reminderTime, onAlert: alertHandler)
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
