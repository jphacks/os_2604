import AVFoundation
import Flutter
import UIKit
import UserNotifications
#if canImport(FoundationModels)
import FoundationModels
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var cameraPermissionChannel: FlutterMethodChannel?
  private var onDeviceAiChannel: FlutterMethodChannel?
  private let onDeviceAiBridge = OnDeviceAiBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications so notifications can be presented.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CameraPermissionBridge") {
      let channel = FlutterMethodChannel(
        name: "jp.jphacks.os_2604/camera_permission",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "requestCameraPermission" else {
          result(FlutterMethodNotImplemented)
          return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
          result(true)
        case .denied, .restricted:
          result(false)
        case .notDetermined:
          AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { result(granted) }
          }
        @unknown default:
          result(FlutterError(code: "unknownAuthorization", message: nil, details: nil))
        }
      }
      cameraPermissionChannel = channel
    }

    if let aiRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "OnDeviceAiBridge") {
      let aiChannel = FlutterMethodChannel(
        name: "jp.jphacks.os_2604/on_device_ai",
        binaryMessenger: aiRegistrar.messenger()
      )
      aiChannel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "unavailable", message: nil, details: nil))
          return
        }
        self.onDeviceAiBridge.handle(call, result: result)
      }
      onDeviceAiChannel = aiChannel
    }
  }
}

private final class OnDeviceAiBridge {
  private final class PendingGeneration {
    private var result: FlutterResult?
    var task: Task<Void, Never>?

    init(result: @escaping FlutterResult) {
      self.result = result
    }

    func complete(_ value: Any?) {
      guard let callback = result else { return }
      result = nil
      callback(value)
    }
  }

  private var activeGenerations: [String: PendingGeneration] = [:]

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(checkAvailability())
    case "generateReflection":
      generateReflection(call: call, result: result)
    case "cancelGeneration":
      cancelGeneration(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func checkAvailability() -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      let model = SystemLanguageModel.default
      switch model.availability {
      case .available:
        let jaLocale = Locale(identifier: "ja_JP")
        if model.supportsLocale(jaLocale) || model.supportsLocale(Locale.current) {
          return "available"
        }
        return "unavailable"
      case .unavailable(let reason):
        switch reason {
        case .deviceNotEligible:
          return "deviceNotEligible"
        case .appleIntelligenceNotEnabled:
          return "appleIntelligenceNotEnabled"
        case .modelNotReady:
          return "modelNotReady"
        @unknown default:
          return "unavailable"
        }
      @unknown default:
        return "unavailable"
      }
    }
    #endif
    return "deviceNotEligible"
  }

  private func generateReflection(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let requestId = args["requestId"] as? String, !requestId.isEmpty,
      let instructions = args["instructions"] as? String, !instructions.isEmpty,
      let prompt = args["prompt"] as? String, !prompt.isEmpty
    else {
      result(FlutterError(code: "invalidArguments", message: nil, details: nil))
      return
    }
    guard activeGenerations[requestId] == nil else {
      result(FlutterError(code: "generationFailed", message: nil, details: nil))
      return
    }

    let pending = PendingGeneration(result: result)
    activeGenerations[requestId] = pending

    pending.task = Task { @MainActor [weak self] in
      defer {
        self?.activeGenerations.removeValue(forKey: requestId)
      }
      #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        if Task.isCancelled {
          pending.complete(FlutterError(code: "cancelled", message: nil, details: nil))
          return
        }
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
          let jaLocale = Locale(identifier: "ja_JP")
          guard model.supportsLocale(jaLocale) || model.supportsLocale(Locale.current) else {
            pending.complete(FlutterError(code: "unsupported", message: nil, details: nil))
            return
          }
        case .unavailable(let reason):
          let code: String
          switch reason {
          case .deviceNotEligible:
            code = "unsupported"
          case .appleIntelligenceNotEnabled:
            code = "disabled"
          case .modelNotReady:
            code = "modelNotReady"
          @unknown default:
            code = "generationFailed"
          }
          pending.complete(FlutterError(code: code, message: nil, details: nil))
          return
        @unknown default:
          pending.complete(FlutterError(code: "generationFailed", message: nil, details: nil))
          return
        }

        do {
          let session = LanguageModelSession(model: model, instructions: instructions)
          let response = try await session.respond(to: prompt)
          if Task.isCancelled {
            pending.complete(FlutterError(code: "cancelled", message: nil, details: nil))
            return
          }
          pending.complete(response.content)
        } catch {
          if error is CancellationError || Task.isCancelled {
            pending.complete(FlutterError(code: "cancelled", message: nil, details: nil))
            return
          }
          let code = Self.errorCode(for: error)
          pending.complete(FlutterError(code: code, message: nil, details: nil))
        }
        return
      }
      #endif
      pending.complete(FlutterError(code: "unsupported", message: nil, details: nil))
    }
  }

  private func cancelGeneration(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if let args = call.arguments as? [String: Any],
      let requestId = args["requestId"] as? String
    {
      activeGenerations[requestId]?.task?.cancel()
    }
    result(nil)
  }

  #if canImport(FoundationModels)
  @available(iOS 26.0, *)
  private static func errorCode(for error: Error) -> String {
    if error is CancellationError {
      return "cancelled"
    }
    if #available(iOS 27.0, *) {
      if let modelError = error as? SystemLanguageModel.Error {
        switch modelError {
        case .assetsUnavailable:
          return "modelNotReady"
        @unknown default:
          return "generationFailed"
        }
      }
      if let lmError = error as? LanguageModelError {
        switch lmError {
        case .rateLimited:
          return "rateLimited"
        case .guardrailViolation, .refusal:
          return "refused"
        case .timeout:
          return "timeout"
        case .unsupportedLanguageOrLocale,
          .unsupportedCapability,
          .unsupportedGenerationGuide,
          .unsupportedTranscriptContent:
          return "unsupported"
        case .contextSizeExceeded:
          return "generationFailed"
        @unknown default:
          return "generationFailed"
        }
      }
    }
    if let genError = error as? LanguageModelSession.GenerationError {
      switch genError {
      case .assetsUnavailable:
        return "modelNotReady"
      case .rateLimited:
        return "rateLimited"
      case .guardrailViolation, .refusal:
        return "refused"
      case .unsupportedLanguageOrLocale, .unsupportedGuide:
        return "unsupported"
      case .exceededContextWindowSize, .decodingFailure, .concurrentRequests:
        return "generationFailed"
      @unknown default:
        return "generationFailed"
      }
    }
    return "generationFailed"
  }
  #endif
}
