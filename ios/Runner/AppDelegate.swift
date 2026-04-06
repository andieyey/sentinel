import Flutter
import ActivityKit
import UIKit

@available(iOS 16.1, *)
struct SentinelLiveActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var statusLine: String
    var mode: String
    var changedTaskCount: Int
    var totalTaskCount: Int
    var updatedAtIso8601: String
    var progress: Double
  }

  var title: String
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var activeLiveActivityId: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let activityKitChannel = FlutterMethodChannel(
        name: "sentinel/activitykit",
        binaryMessenger: controller.binaryMessenger
      )

      activityKitChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleActivityKit(call: call, result: result)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleActivityKit(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      if #available(iOS 16.1, *) {
        result(ActivityAuthorizationInfo().areActivitiesEnabled)
      } else {
        result(false)
      }

    case "startActivity":
      guard #available(iOS 16.1, *) else {
        result(
          FlutterError(
            code: "unsupported_ios_version",
            message: "ActivityKit requires iOS 16.1+.",
            details: nil
          )
        )
        return
      }

      guard let payload = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "invalid_payload",
            message: "startActivity expects a payload map.",
            details: nil
          )
        )
        return
      }

      if #available(iOS 16.1, *) {
        do {
          let attributes = SentinelLiveActivityAttributes(
            title: payload["title"] as? String ?? "Project Sentinel"
          )

          let contentState = makeContentState(from: payload)

          let activity = try Activity<SentinelLiveActivityAttributes>.request(
            attributes: attributes,
            contentState: contentState,
            pushType: nil
          )

          activeLiveActivityId = activity.id
          result([
            "status": "started",
            "activityId": activity.id
          ])
        } catch {
          result(
            FlutterError(
              code: "start_failed",
              message: "Failed to start live activity.",
              details: String(describing: error)
            )
          )
        }
      }

    case "updateActivity":
      guard #available(iOS 16.1, *) else {
        result(
          FlutterError(
            code: "unsupported_ios_version",
            message: "ActivityKit requires iOS 16.1+.",
            details: nil
          )
        )
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let activityId = args["activityId"] as? String,
        let payload = args["payload"] as? [String: Any]
      else {
        result(
          FlutterError(
            code: "invalid_payload",
            message: "updateActivity expects activityId and payload.",
            details: nil
          )
        )
        return
      }

      if #available(iOS 16.1, *) {
        guard let activity = findActivity(by: activityId) else {
          result(
            FlutterError(
              code: "activity_not_found",
              message: "No matching live activity id to update.",
              details: nil
            )
          )
          return
        }

        let nextState = makeContentState(from: payload)

        Task {
          await activity.update(using: nextState)
          result([
            "status": "updated",
            "activityId": activityId
          ])
        }
      }

    case "endActivity":
      guard #available(iOS 16.1, *) else {
        result(
          FlutterError(
            code: "unsupported_ios_version",
            message: "ActivityKit requires iOS 16.1+.",
            details: nil
          )
        )
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let activityId = args["activityId"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_payload",
            message: "endActivity expects an activityId.",
            details: nil
          )
        )
        return
      }

      if #available(iOS 16.1, *) {
        guard let activity = findActivity(by: activityId) else {
          result(
            FlutterError(
              code: "activity_not_found",
              message: "No matching live activity id to end.",
              details: nil
            )
          )
          return
        }

        let finalState = SentinelLiveActivityAttributes.ContentState(
          statusLine: "Sentinel closed",
          mode: "-",
          changedTaskCount: 0,
          totalTaskCount: 0,
          updatedAtIso8601: ISO8601DateFormatter().string(from: Date()),
          progress: 0.0
        )

        Task {
          await activity.end(using: finalState, dismissalPolicy: .immediate)
          if activeLiveActivityId == activityId {
            activeLiveActivityId = nil
          }
          result([
            "status": "ended",
            "activityId": activityId
          ])
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.1, *)
  private func findActivity(by activityId: String) -> Activity<SentinelLiveActivityAttributes>? {
    if let cachedId = activeLiveActivityId, cachedId == activityId {
      if let activity = Activity<SentinelLiveActivityAttributes>.activities.first(where: { $0.id == cachedId }) {
        return activity
      }
    }

    return Activity<SentinelLiveActivityAttributes>.activities.first(where: { $0.id == activityId })
  }

  @available(iOS 16.1, *)
  private func makeContentState(from payload: [String: Any]) -> SentinelLiveActivityAttributes.ContentState {
    let statusLine = payload["statusLine"] as? String ?? "Sentinel recalculating"
    let mode = payload["mode"] as? String ?? "Sleep Priority"
    let changedTaskCount = payload["changedTaskCount"] as? Int ?? 0
    let totalTaskCount = payload["totalTaskCount"] as? Int ?? 0
    let updatedAtIso8601 = payload["updatedAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
    let progress = payload["progress"] as? Double ?? 0.0

    return SentinelLiveActivityAttributes.ContentState(
      statusLine: statusLine,
      mode: mode,
      changedTaskCount: changedTaskCount,
      totalTaskCount: totalTaskCount,
      updatedAtIso8601: updatedAtIso8601,
      progress: progress
    )
  }
}
