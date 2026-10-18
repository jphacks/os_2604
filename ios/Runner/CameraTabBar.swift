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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let onSelect: (Int) -> Void
  private let accent = Color(red: 0.64, green: 0.31, blue: 0.16)

  var body: some View {
    GeometryReader { geometry in
      let slot = geometry.size.width / 3
      ZStack(alignment: .leading) {
        // One glass surface moves continuously; it is not recreated per tab.
        if #available(iOS 26.0, *) {
          GlassEffectContainer {
            Capsule()
              .fill(.clear)
              .frame(width: slot - 8, height: 64)
              .glassEffect(.regular.tint(accent.opacity(0.12)).interactive(), in: .capsule)
              .offset(x: CGFloat(selection.index) * slot + 4)
          }
          .allowsHitTesting(false)
        } else {
          Capsule()
            .fill(accent.opacity(0.12))
            .frame(width: slot - 8, height: 64)
            .offset(x: CGFloat(selection.index) * slot + 4)
            .allowsHitTesting(false)
        }
        HStack(spacing: 0) {
          item("履歴", symbol: "calendar", index: 0)
          item("カメラ", symbol: "camera.fill", index: 1)
          item("設定", symbol: "gearshape", index: 2)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: selection.index)
      .background {
        Capsule()
          .fill(.ultraThinMaterial)
      }
      .overlay(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1))
      .clipShape(Capsule())
      .environment(\.colorScheme, .light)
    }
    .frame(maxWidth: 280)
    .frame(height: 76)
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func item(_ title: String, symbol: String, index: Int) -> some View {
    Button {
      onSelect(index)
    } label: {
      Group {
        if index == 1 {
          // デザインのカメラボタン：コーラル #FF8A5B の丸と濃い茶のアイコン。
          Image(systemName: symbol)
            .font(.system(size: 31, weight: .semibold))
            .foregroundStyle(Color(red: 0x2B / 255, green: 0x12 / 255, blue: 0x06 / 255))
            .frame(width: 66, height: 66)
            .background(Color(red: 0xFF / 255, green: 0x8A / 255, blue: 0x5B / 255), in: Circle())
        } else {
          VStack(spacing: 4) {
            Image(systemName: symbol)
              .font(.system(size: 20, weight: .medium))
            Text(title)
              .font(.caption2)
          }
          .foregroundStyle(index == selection.index ? accent : Color.primary)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 76)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityAddTraits(index == selection.index ? [.isSelected] : [])
  }
}
