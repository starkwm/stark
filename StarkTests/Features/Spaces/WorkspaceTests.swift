import AppKit
import Testing

@testable import Stark

private final class WorkspaceRecorder {
  var addObserverCalls = [(UInt32, String)]()
  var removeObserverCalls = [(UInt32, String)]()
  var postedEvents = [RuntimeEvent]()
}

@Suite(.serialized) struct WorkspaceTests {
  @Test func isObservableReturnsTrueForRegularApplication() {
    let process = process(
      lowPSN: 1,
      application: testApplication(policy: .regular, finishedLaunching: true)
    )
    let workspace = workspace()

    #expect(workspace.isObservable(process))
    #expect(process.policy == .regular)
  }

  @Test func isObservableReturnsFalseForNonRegularApplication() {
    let process = process(
      lowPSN: 2,
      application: testApplication(policy: .accessory, finishedLaunching: true)
    )
    let workspace = workspace()

    #expect(!workspace.isObservable(process))
    #expect(process.policy == .accessory)
  }

  @Test func isObservableSetsProhibitedWhenApplicationIsMissing() {
    let process = process(lowPSN: 3, application: nil)
    let workspace = workspace()

    #expect(!workspace.isObservable(process))
    #expect(process.policy == .prohibited)
  }

  @Test func isFinishedLaunchingReadsApplicationState() {
    let launching = process(
      lowPSN: 4,
      application: testApplication(policy: .regular, finishedLaunching: true)
    )
    let missing = process(lowPSN: 5, application: nil)
    let workspace = workspace()

    #expect(workspace.isFinishedLaunching(launching))
    #expect(!workspace.isFinishedLaunching(missing))
  }

  @Test func observeAndUnobserveActivationPolicyTrackObservedProcesses() {
    let recorder = WorkspaceRecorder()
    let process = process(
      lowPSN: 6,
      application: testApplication(policy: .accessory, finishedLaunching: true)
    )
    let workspace = workspace(recorder: recorder)

    workspace.observeActivationPolicy(process)
    #expect(workspace.activationPolicyObservedForTesting == [6])
    #expect(recorder.addObserverCalls.count == 1)
    #expect(recorder.addObserverCalls[0].0 == 6)
    #expect(recorder.addObserverCalls[0].1 == "activationPolicy")

    workspace.unobserveActivationPolicy(process)
    #expect(workspace.activationPolicyObservedForTesting.isEmpty)
    #expect(recorder.removeObserverCalls.count == 1)
    #expect(recorder.removeObserverCalls[0].0 == 6)
    #expect(recorder.removeObserverCalls[0].1 == "activationPolicy")

    workspace.unobserveActivationPolicy(process)
    #expect(recorder.removeObserverCalls.count == 1)
    #expect(recorder.removeObserverCalls[0].0 == 6)
    #expect(recorder.removeObserverCalls[0].1 == "activationPolicy")
  }

  @Test func observeAndUnobserveFinishedLaunchingTrackObservedProcesses() {
    let recorder = WorkspaceRecorder()
    let process = process(
      lowPSN: 7,
      application: testApplication(policy: .regular, finishedLaunching: false)
    )
    let workspace = workspace(recorder: recorder)

    workspace.observeFinishedLaunching(process)
    #expect(workspace.finishedLaunchingObservedForTesting == [7])
    #expect(recorder.addObserverCalls.count == 1)
    #expect(recorder.addObserverCalls[0].0 == 7)
    #expect(recorder.addObserverCalls[0].1 == "finishedLaunching")

    workspace.unobserveFinishedLaunching(process)
    #expect(workspace.finishedLaunchingObservedForTesting.isEmpty)
    #expect(recorder.removeObserverCalls.count == 1)
    #expect(recorder.removeObserverCalls[0].0 == 7)
    #expect(recorder.removeObserverCalls[0].1 == "finishedLaunching")

    workspace.unobserveFinishedLaunching(process)
    #expect(recorder.removeObserverCalls.count == 1)
    #expect(recorder.removeObserverCalls[0].0 == 7)
    #expect(recorder.removeObserverCalls[0].1 == "finishedLaunching")
  }

  @Test func activationPolicyObservationPostsWhenPolicyChanges() {
    let recorder = WorkspaceRecorder()
    let process = process(
      lowPSN: 8,
      application: testApplication(policy: .accessory, finishedLaunching: true),
      policy: .accessory
    )
    let workspace = workspace(recorder: recorder)
    workspace.observeActivationPolicy(process)

    workspace.observeValue(
      forKeyPath: "activationPolicy",
      of: nil,
      change: [.newKey: NSApplication.ActivationPolicy.regular.rawValue],
      context: context(for: process)
    )

    #expect(workspace.activationPolicyObservedForTesting.isEmpty)
    #expect(recorder.postedEvents.count == 1)
    #expect(recorder.postedEvents.first?.type == .applicationLaunched)

    guard case .application(.launched(let postedProcess))? = recorder.postedEvents.first else {
      Issue.record("Expected launched application event")
      return
    }

    #expect(postedProcess === process)
  }

  @Test func activationPolicyObservationIgnoresUnchangedAndInvalidValues() {
    let recorder = WorkspaceRecorder()
    let process = process(
      lowPSN: 9,
      application: testApplication(policy: .regular, finishedLaunching: true),
      policy: .regular
    )
    let workspace = workspace(recorder: recorder)
    workspace.observeActivationPolicy(process)

    workspace.observeValue(
      forKeyPath: "activationPolicy",
      of: nil,
      change: [.newKey: NSApplication.ActivationPolicy.regular.rawValue],
      context: context(for: process)
    )
    workspace.observeValue(
      forKeyPath: "activationPolicy",
      of: nil,
      change: [.newKey: "bad"],
      context: context(for: process)
    )
    workspace.observeValue(
      forKeyPath: "activationPolicy",
      of: nil,
      change: nil,
      context: context(for: process)
    )

    #expect(recorder.postedEvents.isEmpty)
    #expect(workspace.activationPolicyObservedForTesting == [9])
  }

  @Test func finishedLaunchingObservationPostsOnlyForTrueValues() {
    let recorder = WorkspaceRecorder()
    let process = process(
      lowPSN: 10,
      application: testApplication(policy: .regular, finishedLaunching: false)
    )
    let workspace = workspace(recorder: recorder)
    workspace.observeFinishedLaunching(process)

    workspace.observeValue(
      forKeyPath: "finishedLaunching",
      of: nil,
      change: [.newKey: false],
      context: context(for: process)
    )
    #expect(recorder.postedEvents.isEmpty)
    #expect(workspace.finishedLaunchingObservedForTesting == [10])

    workspace.observeValue(
      forKeyPath: "finishedLaunching",
      of: nil,
      change: [.newKey: true],
      context: context(for: process)
    )

    #expect(workspace.finishedLaunchingObservedForTesting.isEmpty)
    #expect(recorder.postedEvents.count == 1)
    #expect(recorder.postedEvents.first?.type == .applicationLaunched)

    guard case .application(.launched(let postedProcess))? = recorder.postedEvents.first else {
      Issue.record("Expected launched application event")
      return
    }

    #expect(postedProcess === process)
  }

  @Test func activeSpaceDidChangePostsSpaceChangedEvent() {
    let recorder = WorkspaceRecorder()
    let workspace = workspace(recorder: recorder)

    workspace.activeSpaceDidChange(
      Notification(name: NSWorkspace.activeSpaceDidChangeNotification)
    )

    #expect(recorder.postedEvents.count == 1)
    #expect(recorder.postedEvents.first?.type == .spaceChanged)

    guard case .space(.changed(let space))? = recorder.postedEvents.first else {
      Issue.record("Expected changed space event")
      return
    }

    #expect(space.id > 0)
  }

  private func workspace(recorder: WorkspaceRecorder? = nil) -> Workspace {
    Workspace(
      environment: WorkspaceEnvironment(
        addActiveSpaceObserver: { _ in },
        addObserver: { _, process, keyPath, _ in
          recorder?.addObserverCalls.append((process.psn.lowLongOfPSN, keyPath))
        },
        removeObserver: { _, process, keyPath, _ in
          recorder?.removeObserverCalls.append((process.psn.lowLongOfPSN, keyPath))
        },
        postEvent: { event in
          recorder?.postedEvents.append(event)
        }
      )
    )
  }

  private func process(
    lowPSN: UInt32,
    application: NSRunningApplication?,
    policy: NSApplication.ActivationPolicy? = nil
  ) -> Stark.Process {
    Stark.Process(
      psn: ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: lowPSN),
      pid: 1,
      name: "Test",
      application: application,
      policy: policy
    )
  }

  private func context(for process: Stark.Process) -> UnsafeMutableRawPointer? {
    Unmanaged.passUnretained(process).toOpaque()
  }
}

private func testApplication(
  policy: NSApplication.ActivationPolicy,
  finishedLaunching: Bool
) -> NSRunningApplication {
  TestRunningApplication(policy: policy, finishedLaunching: finishedLaunching)
}

private final class TestRunningApplication: NSRunningApplication, @unchecked Sendable {
  private let testPolicy: NSApplication.ActivationPolicy
  private let testFinishedLaunching: Bool

  init(policy: NSApplication.ActivationPolicy, finishedLaunching: Bool) {
    self.testPolicy = policy
    self.testFinishedLaunching = finishedLaunching
    super.init()
  }

  override var activationPolicy: NSApplication.ActivationPolicy {
    testPolicy
  }

  override var isFinishedLaunching: Bool {
    testFinishedLaunching
  }
}
