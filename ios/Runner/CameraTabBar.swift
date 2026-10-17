import Flutter
import SwiftUI
import UIKit

/// A small SwiftUI navigation surface embedded in the Flutter camera landing page.
final class CameraTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    CameraTabBarPlatformView(frame: frame, viewId: viewId, messenger: messenger)
  }
}

private final class CameraTabBarPlatformView: NSObject, FlutterPlatformView {
  // Retain the controller for as long as Flutter owns this platform view.
  private let controller: UIHostingController<CameraTabs>
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    let selection = CameraTabSelection()
    let channel = FlutterMethodChannel(name: "os2604/camera-tabs/\(viewId)", binaryMessenger: messenger)
    self.channel = channel
    controller = UIHostingController(rootView: CameraTabs(selection: selection) { index in
      channel.invokeMethod("selectTab", arguments: index)
    })
    super.init()
    channel.setMethodCallHandler { [weak selection] call, result in
      guard call.method == "setSelectedIndex" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let index = call.arguments as? Int, (0...2).contains(index) else {
        result(FlutterError(code: "invalid_tab", message: "Invalid tab index", details: nil))
        return
      }
      selection?.index = index
      result(nil)
    }
    controller.view.backgroundColor = .clear
    controller.view.isOpaque = false
    controller.view.frame = frame
    controller.view.accessibilityIdentifier = "camera-tab-bar"
  }

  deinit { channel.setMethodCallHandler(nil) }

  func view() -> UIView { controller.view }
}

private final class CameraTabSelection: ObservableObject {
  @Published var index = 1
}

private struct CameraTabs: View {
  @ObservedObject var selection: CameraTabSelection
  let onSelect: (Int) -> Void
  private let accent = Color(red: 0.64, green: 0.31, blue: 0.16)

  var body: some View {
    Group {
      if #available(iOS 26.0, *) {
        tabs
          .glassEffect(.regular.interactive(), in: .capsule)
      } else {
        tabs
          .background(.ultraThinMaterial, in: Capsule())
      }
    }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var tabs: some View {
    HStack(spacing: 10) {
      item("履歴", symbol: "calendar", index: 0)
      item("カメラ", symbol: "camera.fill", index: 1)
      item("設定", symbol: "gearshape", index: 2)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
  }

  private func item(_ title: String, symbol: String, index: Int) -> some View {
    Button {
      onSelect(index)
    } label: {
      VStack(spacing: 3) {
        Image(systemName: symbol)
          .font(.system(size: index == 1 ? 23 : 19, weight: .medium))
        Text(title)
          .font(.caption2)
      }
      .frame(minWidth: 52, minHeight: 48)
      .foregroundStyle(index == selection.index ? accent : Color.primary)
      .background {
        if index == selection.index {
          Capsule().fill(accent.opacity(0.12))
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityAddTraits(index == selection.index ? [.isSelected] : [])
  }
}
