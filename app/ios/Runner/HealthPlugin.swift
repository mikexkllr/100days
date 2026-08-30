import Flutter
import HealthKit
import UIKit

/// Reads Apple Health for the app.
///
/// Like its Android counterpart the plugin stays thin: HealthKit aggregates
/// steps and hydration per day better than we could — its statistics queries
/// already reconcile the iPhone and the Watch counting the same walk — so
/// those come back as day totals, while workouts, sleep and mindful sessions
/// come back as raw intervals for Dart to merge and attribute.
///
/// Read-only. The app requests nothing under `toShare`, so it cannot write to
/// anyone's health record.
final class HealthPlugin: NSObject, FlutterPlugin {
  private let store = HKHealthStore()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "hundred_days/health",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(HealthPlugin(), channel: channel)
  }

  // MARK: - Channel

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "available":
      result(HKHealthStore.isHealthDataAvailable())
    case "access":
      status(for: metrics(from: call), result: result)
    case "request":
      request(metrics(from: call), result: result)
    case "read":
      read(call, result: result)
    case "openSettings":
      openSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func metrics(from call: FlutterMethodCall) -> [String] {
    let arguments = call.arguments as? [String: Any]
    return arguments?["metrics"] as? [String] ?? []
  }

  // MARK: - Authorisation

  /// HealthKit never reveals whether *read* access was granted — a refusal
  /// would otherwise be a signal in itself, which is exactly the leak Apple is
  /// avoiding. So the honest answer here is almost always "unknown", and the
  /// app is written to treat an empty read as "nothing to import" rather than
  /// as a failure.
  private func status(for metrics: [String], result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(HealthPlugin.unavailable)
      return
    }
    let types = objectTypes(for: metrics)
    guard !types.isEmpty else {
      result(HealthPlugin.unavailable)
      return
    }
    result(["status": "unknown", "granted": [String]()])
  }

  private func request(_ metrics: [String], result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(HealthPlugin.unavailable)
      return
    }
    let types = objectTypes(for: metrics)
    guard !types.isEmpty else {
      result(HealthPlugin.unavailable)
      return
    }

    store.requestAuthorization(toShare: [], read: types) { granted, _ in
      DispatchQueue.main.async {
        // `granted` only says the sheet was presented and dismissed without
        // error, not what the user chose. Reporting it as "granted" would be
        // a lie the rest of the app would then repeat.
        result(["status": granted ? "unknown" : "denied", "granted": [String]()])
      }
    }
  }

  private func openSettings(result: @escaping FlutterResult) {
    // There is no deep link into the Health app's per-source screen, so this
    // lands on the app's own settings page, which is where the release is
    // revoked from anyway.
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
    }
    result(nil)
  }

  // MARK: - Reads

  private func read(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    guard
      HKHealthStore.isHealthDataAvailable(),
      let fromDay = arguments?["from"] as? String,
      let toDay = arguments?["to"] as? String,
      let start = HealthPlugin.day(fromDay),
      let endDay = HealthPlugin.day(toDay),
      let end = Calendar.current.date(byAdding: .day, value: 1, to: endDay)
    else {
      result(["daily": [], "sessions": []])
      return
    }

    let metrics = Set(self.metrics(from: call))
    let group = DispatchGroup()
    let lock = NSLock()
    var daily: [[String: Any]] = []
    var sessions: [[String: Any]] = []

    func appendDaily(_ rows: [[String: Any]]) {
      lock.lock()
      daily.append(contentsOf: rows)
      lock.unlock()
    }
    func appendSessions(_ rows: [[String: Any]]) {
      lock.lock()
      sessions.append(contentsOf: rows)
      lock.unlock()
    }

    if metrics.contains("steps"), let type = HKObjectType.quantityType(forIdentifier: .stepCount) {
      group.enter()
      dailyTotals(of: type, unit: .count(), metric: "steps", from: start, to: end) { rows in
        appendDaily(rows)
        group.leave()
      }
    }

    if metrics.contains("water"),
       let type = HKObjectType.quantityType(forIdentifier: .dietaryWater) {
      group.enter()
      dailyTotals(
        of: type,
        unit: HKUnit.literUnit(with: .milli),
        metric: "water",
        from: start,
        to: end
      ) { rows in
        appendDaily(rows)
        group.leave()
      }
    }

    let wantsStrength = metrics.contains("strengthMinutes")
    let wantsCardio = metrics.contains("cardioMinutes")
    if wantsStrength || wantsCardio {
      group.enter()
      workouts(from: start, to: end, strength: wantsStrength, cardio: wantsCardio) { rows in
        appendSessions(rows)
        group.leave()
      }
    }

    if metrics.contains("sleepMinutes"),
       let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      group.enter()
      // Reach back a day: the night that belongs to the first day in the
      // window began the evening before it.
      let sleepStart = Calendar.current.date(byAdding: .day, value: -1, to: start) ?? start
      categorySessions(
        of: type,
        metric: "sleepMinutes",
        from: sleepStart,
        to: end,
        include: HealthPlugin.isAsleep
      ) { rows in
        appendSessions(rows)
        group.leave()
      }
    }

    if metrics.contains("mindfulMinutes"),
       let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
      group.enter()
      categorySessions(
        of: type,
        metric: "mindfulMinutes",
        from: start,
        to: end,
        include: { _ in true }
      ) { rows in
        appendSessions(rows)
        group.leave()
      }
    }

    group.notify(queue: .main) {
      result(["daily": daily, "sessions": sessions])
    }
  }

  /// One number per calendar day, anchored to local midnight so a day means
  /// what the user's calendar says even across a daylight-saving change.
  private func dailyTotals(
    of type: HKQuantityType,
    unit: HKUnit,
    metric: String,
    from start: Date,
    to end: Date,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    let calendar = Calendar.current
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: end,
      options: [.strictStartDate]
    )
    let query = HKStatisticsCollectionQuery(
      quantityType: type,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum,
      anchorDate: calendar.startOfDay(for: start),
      intervalComponents: DateComponents(day: 1)
    )
    query.initialResultsHandler = { _, collection, _ in
      guard let collection else {
        completion([])
        return
      }
      var rows: [[String: Any]] = []
      collection.enumerateStatistics(from: start, to: end) { statistics, _ in
        guard let sum = statistics.sumQuantity() else { return }
        let value = sum.doubleValue(for: unit)
        guard value > 0 else { return }
        rows.append([
          "metric": metric,
          "day": HealthPlugin.dayString(statistics.startDate),
          "value": value,
          "device": statistics.sources?.first?.name as Any,
        ])
      }
      completion(rows)
    }
    store.execute(query)
  }

  private func workouts(
    from start: Date,
    to end: Date,
    strength: Bool,
    cardio: Bool,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: nil
    ) { _, samples, _ in
      let rows: [[String: Any]] = (samples as? [HKWorkout] ?? []).compactMap { workout in
        let metric: String?
        if HealthPlugin.strengthTypes.contains(workout.workoutActivityType) {
          metric = strength ? "strengthMinutes" : nil
        } else if HealthPlugin.cardioTypes.contains(workout.workoutActivityType) {
          metric = cardio ? "cardioMinutes" : nil
        } else {
          metric = nil
        }
        guard let metric else { return nil }
        return HealthPlugin.session(
          metric: metric,
          start: workout.startDate,
          end: workout.endDate,
          device: workout.device?.name ?? workout.sourceRevision.source.name
        )
      }
      completion(rows)
    }
    store.execute(query)
  }

  private func categorySessions(
    of type: HKCategoryType,
    metric: String,
    from start: Date,
    to end: Date,
    include: @escaping (HKCategorySample) -> Bool,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    let query = HKSampleQuery(
      sampleType: type,
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: nil
    ) { _, samples, _ in
      let rows: [[String: Any]] = (samples as? [HKCategorySample] ?? [])
        .filter(include)
        .map { sample in
          HealthPlugin.session(
            metric: metric,
            start: sample.startDate,
            end: sample.endDate,
            device: sample.device?.name ?? sample.sourceRevision.source.name
          )
        }
      completion(rows)
    }
    store.execute(query)
  }

  // MARK: - Types and mapping

  private func objectTypes(for metrics: [String]) -> Set<HKObjectType> {
    var types: Set<HKObjectType> = []
    for metric in metrics {
      switch metric {
      case "steps":
        if let type = HKObjectType.quantityType(forIdentifier: .stepCount) {
          types.insert(type)
        }
      case "water":
        if let type = HKObjectType.quantityType(forIdentifier: .dietaryWater) {
          types.insert(type)
        }
      case "strengthMinutes", "cardioMinutes":
        types.insert(HKObjectType.workoutType())
      case "sleepMinutes":
        if let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
          types.insert(type)
        }
      case "mindfulMinutes":
        if let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
          types.insert(type)
        }
      default:
        continue
      }
    }
    return types
  }

  /// Lifting, in whatever shape a watch recorded it. Cross training sits here
  /// rather than under cardio because in practice it is circuit work.
  private static let strengthTypes: Set<HKWorkoutActivityType> = [
    .traditionalStrengthTraining,
    .functionalStrengthTraining,
    .coreTraining,
    .crossTraining,
  ]

  /// Plain walking is deliberately missing: a walk to the shops is not a
  /// cardio session, and counting it as one would hand out a streak day for
  /// commuting. Walking shows up in the step count instead.
  private static let cardioTypes: Set<HKWorkoutActivityType> = [
    .running,
    .cycling,
    .swimming,
    .rowing,
    .elliptical,
    .hiking,
    .stairClimbing,
    .stairs,
    .highIntensityIntervalTraining,
    .jumpRope,
    .mixedCardio,
  ]

  /// Time in bed is not time asleep, and neither is a stretch of lying awake.
  private static func isAsleep(_ sample: HKCategorySample) -> Bool {
    if #available(iOS 16.0, *) {
      return HKCategoryValueSleepAnalysis.allAsleepValues
        .contains { $0.rawValue == sample.value }
    }
    // Before iOS 16 there was one asleep value and no stages.
    return sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
  }

  private static func session(
    metric: String,
    start: Date,
    end: Date,
    device: String?
  ) -> [String: Any] {
    [
      "metric": metric,
      "start": Int(start.timeIntervalSince1970 * 1000),
      "end": Int(end.timeIntervalSince1970 * 1000),
      "device": device as Any,
    ]
  }

  private static let unavailable: [String: Any] =
    ["status": "unavailable", "granted": [String]()]

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static func dayString(_ date: Date) -> String {
    dayFormatter.string(from: date)
  }

  private static func day(_ iso: String) -> Date? {
    dayFormatter.date(from: iso)
  }
}
