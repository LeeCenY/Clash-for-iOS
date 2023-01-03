import SwiftUI

struct CFISubscribeListView: View {
        
    @EnvironmentObject private var packetTunnelManager: CFIPacketTunnelManager
    @EnvironmentObject private var subscribeManager: CFISubscribeManager
    
    @StateObject private var loadingVM = CFILoadingViewModel()
            
    let current: Binding<String>
    
    @State private var isDownloadAlertPresented: Bool = false
    @State private var subscribeURLString: String = ""
        
    @State private var isRenameAlertPresented = false
    @State private var subscribe: CFISubscribe?
    @State private var subscribeName: String = ""
    
    var body: some View {
        NavigationStack {
            List(subscribeManager.subscribes) { subscribe in
                Button {
                    guard current.wrappedValue != subscribe.id else {
                        return
                    }
                    current.wrappedValue = subscribe.id
                } label: {
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subscribe.extend.alias)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            Text(subscribe.extend.leastUpdated.formatted(.relative(presentation: .named)))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .font(.callout)
                                .fontWeight(.light)
                        }
                        Spacer()
                        if current.wrappedValue == subscribe.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                                .fontWeight(.medium)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("删除", role: .destructive) {
                        do {
                            try subscribeManager.delete(subscribe: subscribe)
                            if subscribe.id == current.wrappedValue {
                                current.wrappedValue = ""
                            }
                        } catch {
                            debugPrint(error.localizedDescription)
                        }
                    }
                    Button("重命名") {
                        self.subscribeName = subscribe.extend.alias
                        self.subscribe = subscribe
                        self.isRenameAlertPresented.toggle()
                    }
                    .tint(.yellow)
                    Button("更新") {
                        loadingVM.loading(message: "正在更新订阅...")
                        Task(priority: .userInitiated) {
                            do {
                                try await subscribeManager.update(subscribe: subscribe)
                                loadingVM.success(message: "更新订阅成功")
                                if current.wrappedValue == subscribe.id {
                                    packetTunnelManager.set(subscribe: subscribe.id)
                                }
                            } catch {
                                loadingVM.failure(message: error.localizedDescription)
                            }
                        }
                    }
                    .tint(.green)
                }
            }
            .navigationTitle(Text("订阅管理"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    subscribeURLString = ""
                    isDownloadAlertPresented.toggle()
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                }
            }
            .alert("重命名", isPresented: $isRenameAlertPresented, presenting: subscribe) { subscribe in
                TextField("请输入订阅名称", text: $subscribeName)
                Button("确定") {
                    let name = subscribeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !(name == subscribe.extend.alias || name.isEmpty) else {
                        return
                    }
                    do {
                        try subscribeManager.rename(subscribe: subscribe, name: name)
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .alert("订阅", isPresented: $isDownloadAlertPresented) {
                TextField("请输入订阅地址", text: $subscribeURLString)
                Button("确定") {
                    guard let source = URL(string: subscribeURLString) else {
                        return loadingVM.failure(message: "不支持的URL")
                    }
                    loadingVM.loading(message: "正在下载订阅...")
                    Task(priority: .high) {
                        do {
                            try await subscribeManager.download(source: source)
                            await MainActor.run {
                                loadingVM.success(message: "下载成功")
                            }
                        } catch {
                            await MainActor.run {
                                loadingVM.failure(message: error.localizedDescription)
                            }
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $loadingVM.isPresented) {
                CFILoadingView(state: $loadingVM.state)
                    .presentationDetents([.height(60.0)])
                    .presentationDragIndicator(.hidden)
            }
        }
    }
}
