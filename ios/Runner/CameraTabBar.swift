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

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "os2604/camera-tabs/\(viewId)", binaryMessenger: messenger)
    controller = UIHostingController(rootView: CameraTabs { index in
      channel.invokeMethod("selectTab", arguments: index)
    })
    super.init()
    controller.view.backgroundColor = .clear
    controller.view.isOpaque = false
    controller.view.frame = frame
    controller.view.accessibilityIdentifier = "camera-tab-bar"
  }

  func view() -> UIView { controller.view }
}

private struct CameraTabs: View {
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
      .foregroundStyle(index == 1 ? accent : Color.primary)
      .background {
        if index == 1 {
          Capsule().fill(accent.opacity(0.12))
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityAddTraits(index == 1 ? [.isSelected] : [])
  }
}
