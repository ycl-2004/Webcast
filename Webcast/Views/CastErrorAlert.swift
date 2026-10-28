import SwiftUI

/// 统一的投屏错误提示。根视图与各个 sheet 各自挂载一次，
/// 保证无论哪个层级在台上，用户都能看到同一份 CastManager.errorMessage。
struct CastErrorAlertModifier: ViewModifier {
    @EnvironmentObject private var cast: CastManager

    func body(content: Content) -> some View {
        content.alert("投屏提示", isPresented: Binding(
            get: { cast.errorMessage != nil },
            set: { if !$0 { cast.errorMessage = nil } }
        )) {
            if cast.canRetryLoad {
                Button("重试投屏") { cast.retryLoad() }
            }
            Button("知道了", role: .cancel) { cast.errorMessage = nil }
        } message: {
            Text(cast.errorMessage ?? "")
        }
    }
}

extension View {
    /// 挂载统一的投屏错误 alert（可含「重试投屏」）
    func castErrorAlert() -> some View { modifier(CastErrorAlertModifier()) }
}
