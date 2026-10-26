import AppKit
import IOKit.pwr_mgt
import IOKit.ps

struct AppError: LocalizedError {
    let message: String
    var cancelled = false
    var errorDescription: String? { message }
}

func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 10) throws -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = arguments
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    try task.run()
    let deadline = DispatchSource.makeTimerSource(queue: .global())
    deadline.schedule(deadline: .now() + timeout)
    deadline.setEventHandler {
        if task.isRunning { task.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            if task.isRunning { kill(task.processIdentifier, SIGKILL) }
        }
    }
    deadline.resume()
    defer { deadline.cancel() }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    let output = String(decoding: data, as: UTF8.self)
    guard task.terminationStatus == 0 else {
        throw AppError(message: output.isEmpty ? "명령 실행이 중단되었습니다. 다시 시도해 주세요." : output)
    }
    return output
}

func setting(_ name: String, in text: String) -> Int? {
    for line in text.split(separator: "\n") {
        let parts = line.split(whereSeparator: { $0.isWhitespace })
        if parts.count >= 2 && parts[0] == name { return Int(parts[1]) }
    }
    return nil
}

func acSettings(_ text: String) throws -> [String: Int] {
    var readingAC = false
    var result: [String: Int] = [:]
    for line in text.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix(":") { readingAC = trimmed == "AC Power:"; continue }
        guard readingAC else { continue }
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
        if parts.count >= 2, ["sleep", "womp", "tcpkeepalive"].contains(String(parts[0])),
           let value = Int(parts[1]) { result[String(parts[0])] = value }
    }
    guard result["sleep"] != nil else { throw AppError(message: "기존 잠자기 설정을 확인하지 못했습니다.") }
    return result
}

struct PowerState: Equatable {
    let onAC: Bool
    let percent: Int?
    var risk: String? {
        guard let percent else { return nil }
        if percent <= 20 { return onAC ? "low-ac" : "low-battery" }
        return onAC ? nil : "battery"
    }
    var text: String {
        guard let percent else { return "\(onAC ? "외부 전원" : "UPS 전원") · 내장 배터리 없음" }
        return "\(onAC ? "충전기 연결" : "배터리 사용 중") · \(percent)%"
    }
    var warning: String {
        guard let percent else { return "" }
        var reasons: [String] = []
        if !onAC { reasons.append("충전기가 연결되어 있지 않습니다.") }
        if percent <= 20 { reasons.append("배터리가 \(percent)% 남았습니다.") }
        return text + "\n\n" + reasons.joined(separator: "\n") + "\n잠자기 방지가 배터리 소모와 발열을 늘릴 수 있습니다. 통풍되는 곳에서 사용해 주세요."
    }
}

func powerState(_ source: String, descriptions: [[String: Any]]) throws -> PowerState {
    let error = AppError(message: "전원 상태를 확인하지 못했습니다. 상태를 확인한 후 다시 켜 주세요.")
    guard [kIOPMACPowerKey, kIOPMBatteryPowerKey, kIOPMUPSPowerKey].contains(source),
          descriptions.allSatisfy({ description in
              guard let type = description[kIOPSTypeKey] as? String else { return false }
              return [kIOPSInternalBatteryType, kIOPSUPSType].contains(type)
          }) else { throw error }
    let batteries = descriptions.filter { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType }
    guard batteries.count <= 1 else { throw error }
    guard let battery = batteries.first else {
        guard source != kIOPMBatteryPowerKey else { throw error }
        return PowerState(onAC: source == kIOPMACPowerKey, percent: nil)
    }
    guard source != kIOPMUPSPowerKey,
          battery[kIOPSIsPresentKey] as? Bool == true,
          let current = battery[kIOPSCurrentCapacityKey] as? Int,
          let maximum = battery[kIOPSMaxCapacityKey] as? Int,
          maximum > 0, current >= 0, current <= maximum else { throw error }
    let (scaled, overflow) = current.multipliedReportingOverflow(by: 100)
    guard !overflow else { throw error }
    return PowerState(onAC: source == kIOPMACPowerKey, percent: scaled / maximum)
}

func readPowerState() throws -> PowerState {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
          let provider = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else {
        throw AppError(message: "macOS 전원 정보를 읽지 못했습니다. 다시 시도해 주세요.")
    }
    let descriptions = try sources.map { source -> [String: Any] in
        guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
            throw AppError(message: "macOS 배터리 정보를 읽지 못했습니다. 다시 시도해 주세요.")
        }
        return description
    }
    return try powerState(provider as String, descriptions: descriptions)
}

struct SystemState {
    let settings: SavedSettings
    let power: PowerState?
    let powerError: String?
    let lid: String?
    var fullyEnabled: Bool {
        settings.sleepDisabled == 1 && settings.ac["sleep"] == 0 &&
            ["womp", "tcpkeepalive"].allSatisfy { settings.ac[$0] == nil || settings.ac[$0] == 1 }
    }
}

func rootBoolean(_ key: String, in text: String) -> Bool? {
    for line in text.split(separator: "\n") {
        let parts = line.split(whereSeparator: { $0.isWhitespace })
        guard parts.count == 3, parts[0] == "\"\(key)\"", parts[1] == "=" else { continue }
        if parts[2] == "Yes" { return true }
        if parts[2] == "No" { return false }
    }
    return nil
}

func readState() throws -> SystemState {
    let root = try run("/usr/sbin/ioreg", ["-r", "-n", "IOPMrootDomain", "-d", "1"], timeout: 3)
    // pmset may omit SleepDisabled when no explicit preference exists; read the live kernel value.
    guard let disabled = rootBoolean("SleepDisabled", in: root) else {
        throw AppError(message: "시스템 잠자기 상태를 읽지 못했습니다.")
    }
    let settings = try SavedSettings(version: 1, sleepDisabled: disabled ? 1 : 0,
        ac: acSettings(run("/usr/bin/pmset", ["-g", "custom"])), savedAt: Date())
    try settings.validate()
    var power: PowerState?
    var powerError: String?
    do { power = try readPowerState() }
    catch { powerError = error.localizedDescription }
    let lid: String? = power != nil && power?.percent == nil ? nil :
        (rootBoolean("AppleClamshellState", in: root).map { $0 ? "덮개 닫힘" : "덮개 열림" } ?? "덮개 상태 확인 불가")
    return SystemState(settings: settings, power: power, powerError: powerError, lid: lid)
}

struct SavedSettings: Codable {
    let version: Int
    let sleepDisabled: Int
    let ac: [String: Int]
    let savedAt: Date
    func validate() throws {
        guard version == 1, [0, 1].contains(sleepDisabled), ac["sleep"] != nil,
              !ac.isEmpty, ac.allSatisfy({ key, value in
                  ["sleep", "womp", "tcpkeepalive"].contains(key) && value >= 0 && value <= 1440 &&
                  (key == "sleep" || value <= 1)
              }) else { throw AppError(message: "복원 파일이 올바르지 않습니다. 전원 설정을 변경하지 않았습니다.") }
    }
}

func acCommand(_ values: [String: Int]) -> String {
    "/usr/bin/pmset -c " + values.keys.sorted().map { "\($0) \(values[$0]!)" }.joined(separator: " ")
}

func enabledAC(_ original: SavedSettings) -> [String: Int] {
    original.ac.mapValues { _ in 1 }.merging(["sleep": 0]) { _, new in new }
}

func ownedAC(_ original: SavedSettings) -> [String: Int] {
    let target = enabledAC(original)
    return original.ac.filter { target[$0.key] != $0.value }
}

func matches(_ actual: SavedSettings, _ expected: SavedSettings) -> Bool {
    actual.sleepDisabled == expected.sleepDisabled && expected.ac.allSatisfy { actual.ac[$0.key] == $0.value }
}

func restored(_ actual: SavedSettings, _ original: SavedSettings) -> Bool {
    actual.sleepDisabled == original.sleepDisabled && ownedAC(original).allSatisfy { actual.ac[$0.key] == $0.value }
}

func restoreConflicts(_ actual: SavedSettings, _ original: SavedSettings) -> [String] {
    let target = enabledAC(original)
    return ownedAC(original).keys.sorted().filter {
        actual.ac[$0] != original.ac[$0] && actual.ac[$0] != target[$0]
    }
}

func settingsCommands(ac: [String: Int], disabled: Int) -> String {
    (ac.isEmpty ? "" : acCommand(ac) + "\n") + "/usr/bin/pmset -a disablesleep \(disabled)"
}

func transactionCommands(ac: [String: Int], disabled: Int, expected: SavedSettings) throws -> String {
    try expected.validate()
    try SavedSettings(version: 1, sleepDisabled: disabled,
        ac: ["sleep": 0].merging(ac) { _, value in value }, savedAt: Date()).validate()
    var checks = [("$(/usr/sbin/ioreg -r -n IOPMrootDomain -d 1 | /usr/bin/awk '$1 == \"\\\"SleepDisabled\\\"\" {if ($3 == \"Yes\") print 1; else if ($3 == \"No\") print 0; exit}')", expected.sleepDisabled)]
    for key in expected.ac.keys.sorted() {
        let query = "$(/usr/bin/pmset -g custom | /usr/bin/awk '/^[^[:space:]].*:/ {ac = ($0 == \"AC Power:\")} ac && $1 == \"\(key)\" {print $2; exit}')"
        checks.append((query, expected.ac[key]!))
    }
    let guardScript = checks.map { query, value in
        "[ \"\(query)\" = \"\(value)\" ] || { echo '전원 설정이 다른 곳에서 변경되었습니다. 새로고침 후 다시 시도해 주세요.'; exit 75; }"
    }.joined(separator: "\n")
    let rollback = settingsCommands(ac: expected.ac.filter { ac[$0.key] != nil }, disabled: expected.sleepDisabled)
    // Restore the original values if either privileged command fails.
    return "set -eu\n" + guardScript + "\ntrap 'status=$?; trap - 0; set +e\n" + rollback +
        "\nexit \"$status\"' 0\n" + settingsCommands(ac: ac, disabled: disabled) + "\ntrap - 0"
}

func restoreCommands(_ saved: SavedSettings, current: SavedSettings) throws -> String {
    try saved.validate()
    return try transactionCommands(ac: ownedAC(saved), disabled: saved.sleepDisabled, expected: current)
}

func enableCommands(_ saved: SavedSettings, current: SavedSettings) throws -> String {
    try saved.validate()
    return try transactionCommands(ac: enabledAC(saved), disabled: 1, expected: current)
}

func appleScriptLiteral(_ text: String) -> String {
    "\"" + text.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n") + "\""
}

func authorize(_ command: String) throws {
    // The OS owns the authentication dialog; no password is read or stored by this app.
    let source = "do shell script " + appleScriptLiteral(command) +
        " with administrator privileges with prompt \"원격지킴이가 원격 모드 전원 설정을 변경합니다.\""
    var error: NSDictionary?
    guard let script = NSAppleScript(source: source) else { throw AppError(message: "인증 요청을 만들지 못했습니다.") }
    _ = script.executeAndReturnError(&error)
    if let error {
        if (error[NSAppleScript.errorNumber] as? Int) == -128 { throw AppError(message: "인증을 취소했습니다. 설정은 유지됩니다.", cancelled: true) }
        throw AppError(message: error[NSAppleScript.errorMessage] as? String ?? error.description)
    }
}

func menuIcon(active: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 22, height: 20), flipped: false) { _ in
        NSColor.black.setStroke()
        NSColor.black.setFill()
        let screen = NSBezierPath(roundedRect: NSRect(x: 3, y: 5, width: 16, height: 11), xRadius: 1.5, yRadius: 1.5)
        screen.lineWidth = 1.5; screen.stroke()
        let base = NSBezierPath()
        base.move(to: NSPoint(x: 1, y: 3)); base.line(to: NSPoint(x: 21, y: 3))
        base.lineWidth = 1.8; base.lineCapStyle = .round; base.stroke()
        let dot = NSBezierPath(ovalIn: NSRect(x: 9, y: 8, width: 4, height: 4))
        if active { dot.fill() } else { dot.lineWidth = 1; dot.stroke() }
        return true
    }
    image.isTemplate = true
    image.accessibilityDescription = active ? "원격 모드 켜짐" : "원격 모드 꺼짐"
    return image
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let worker = DispatchQueue(label: "personal.remotelid.power", qos: .userInitiated)
    var window: NSWindow?
    let stateLabel = NSTextField(labelWithString: "상태 확인 중")
    let detailLabel = NSTextField(wrappingLabelWithString: "")
    let modeSwitch = NSSwitch()
    let restoreButton = NSButton(title: "이전 설정 복원…", target: nil, action: nil)
    var timer: Timer?
    var busy = false
    var refreshing = false
    var warningVisible = false
    var terminationPending = false
    var live: SystemState?
    var saved: SavedSettings?
    var storageError: String?
    var lastError: String?
    var acknowledgedRisk: String?
    var assertion: IOPMAssertionID = 0
    let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("RemoteLid", isDirectory: true)
    var stateURL: URL { folder.appendingPathComponent("restore.json") }
    var sleepDisabled: Int? { live?.settings.sleepDisabled }
    var fullyEnabled: Bool { live?.fullyEnabled == true }
    var working: Bool { busy || refreshing || warningVisible }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status.menu = menu
        status.autosaveName = "RemoteLidStatus"
        status.isVisible = true
        menu.autoenablesItems = false
        menu.delegate = self
        loadSaved()
        makeWindow()
        refresh()
        showWindow()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.refresh() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    func makeWindow() {
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 440),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "원격지킴이"
        panel.isReleasedWhenClosed = false
        panel.center()
        let title = NSTextField(labelWithString: "Mac은 깨어 있고, 작업은 계속")
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        stateLabel.font = .systemFont(ofSize: 17, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 5
        let toggleLabel = NSTextField(labelWithString: "원격 모드")
        toggleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        modeSwitch.target = self
        modeSwitch.action = #selector(toggleMode)
        modeSwitch.setAccessibilityLabel("원격 모드")
        restoreButton.target = self
        restoreButton.action = #selector(disableMode)
        restoreButton.bezelStyle = .rounded
        let toggleRow = NSStackView(views: [toggleLabel, modeSwitch, restoreButton])
        toggleRow.spacing = 14
        let note = NSTextField(wrappingLabelWithString: "전원을 안정적으로 연결하고 통풍되는 곳에 두세요.\n끄면 앱이 변경한 전원 설정을 이전 값으로 복원합니다.\n창을 닫아도 메뉴 막대에서 계속 실행됩니다.")
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 12)
        let stack = NSStackView(views: [title, stateLabel, detailLabel, toggleRow, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: panel.contentView!.bottomAnchor, constant: -24),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        window = panel
    }

    @objc func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func loadSaved() {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return }
        do {
            let value = try JSONDecoder().decode(SavedSettings.self, from: Data(contentsOf: stateURL))
            try value.validate()
            saved = value
        } catch { storageError = "복원 기록을 읽지 못했습니다. 원래 값은 복원할 수 없습니다. \(error.localizedDescription)" }
    }

    func save(_ value: SavedSettings) throws {
        try value.validate()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        try JSONEncoder().encode(value).write(to: stateURL, options: .atomic)
        saved = value
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
    }

    func clearSaved() throws {
        try FileManager.default.removeItem(at: stateURL)
        saved = nil
    }

    func apply(_ result: Result<SystemState, Error>) {
        switch result {
        case .success(let value): live = value; lastError = value.powerError
        case .failure(let error): live = nil; lastError = error.localizedDescription
        }
        updateAssertion()
    }

    func readAsync(_ completion: @escaping (Result<SystemState, Error>) -> Void) {
        worker.async {
            let result = Result { try readState() }
            DispatchQueue.main.async { completion(result) }
        }
    }

    func refresh() {
        guard !working else { return }
        refreshing = true
        render()
        readAsync { [self] result in
            apply(result)
            refreshing = false
            render()
            checkPowerRisk()
        }
    }

    func beginChange(_ action: @escaping (SystemState) -> Void, failed: @escaping () -> Void = {}) {
        guard !working else { failed(); return }
        busy = true
        render()
        readAsync { [self] result in
            apply(result)
            switch result {
            case .success(let state): action(state)
            case .failure(let error):
                busy = false
                render()
                showError(error.localizedDescription)
                failed()
            }
        }
    }

    func endChange(_ error: String? = nil) {
        busy = false
        updateAssertion()
        render()
        if let error { showError(error) }
    }

    func updateAssertion() {
        if saved != nil && sleepDisabled == 1 && assertion == 0 {
            let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn), "원격지킴이 원격 모드" as CFString, &assertion)
            if result != kIOReturnSuccess { lastError = "유휴 잠자기 방지 요청을 적용하지 못했습니다. 전원 설정 상태를 확인해 주세요." }
        } else if (saved == nil || sleepDisabled == 0) && assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
    }

    @discardableResult func item(_ title: String, action: Selector? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        entry.isEnabled = action != nil
        menu.addItem(entry)
        return entry
    }

    func render() {
        let label: String
        if busy { label = "설정 변경 중" }
        else if live == nil { label = "상태 확인 필요" }
        else if storageError != nil { label = "복원 기록 확인 필요" }
        else if fullyEnabled { label = saved == nil ? "다른 곳에서 잠자기 방지 중" : "원격 모드 켜짐" }
        else if sleepDisabled == 1 { label = "잠자기 방지 켜짐 · 설정 확인 필요" }
        else if saved != nil { label = "원격 모드 꺼짐 · 복원 기록 있음" }
        else { label = "원격 모드 꺼짐" }
        let power = live?.power?.text ?? "전원 상태 확인 불가"
        let details = [power, live?.lid].compactMap { $0 }.joined(separator: " · ")
        status.button?.title = ""
        status.button?.image = menuIcon(active: sleepDisabled == 1)
        status.button?.toolTip = "원격지킴이 · \(label)\n\(details)"
        stateLabel.stringValue = label
        stateLabel.textColor = fullyEnabled && saved != nil ? .systemGreen : .labelColor
        let message = storageError ?? lastError ?? (saved == nil && sleepDisabled == 1
            ? "이 앱의 복원 기록이 없습니다. 끄면 잠자기 방지만 해제합니다."
            : (fullyEnabled ? "앱이 변경한 설정은 끌 때 이전 값으로 복원합니다." : "원격 모드를 켜면 전원 설정을 적용합니다."))
        detailLabel.stringValue = "\(details)\n\(message)"
        modeSwitch.state = sleepDisabled == 1 ? .on : .off
        modeSwitch.isEnabled = !working && live != nil && (sleepDisabled == 1 || storageError == nil)
        restoreButton.isHidden = saved == nil || storageError != nil
        restoreButton.isEnabled = !working && saved != nil && live != nil
        menu.removeAllItems()
        item("원격지킴이 · \(label)")
        item(power)
        if let lid = live?.lid { item(lid) }
        if let error = storageError ?? lastError { item(String(error.prefix(100))) }
        menu.addItem(.separator())
        let toggle = item(sleepDisabled == 1 ? "원격 모드 끄기…" : "원격 모드 켜기…", action: #selector(toggleMode))
        toggle.state = sleepDisabled == 1 ? .on : .off
        toggle.isEnabled = modeSwitch.isEnabled
        if saved != nil {
            item("이전 설정 복원…", action: #selector(disableMode)).isEnabled = !working && live != nil
        }
        if storageError != nil || (saved == nil && sleepDisabled == 1) {
            item("잠자기 방지만 긴급 해제…", action: #selector(disableMode)).isEnabled = !working && live != nil
        }
        item("지금 상태 새로고침", action: #selector(refreshAction)).isEnabled = !working
        menu.addItem(.separator())
        item("제어 창 열기", action: #selector(showWindow))
        item("사용 안내", action: #selector(help))
        item("종료…", action: #selector(quit)).isEnabled = !busy && !warningVisible
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }
    @objc func refreshAction() { refresh() }
    @objc func woke() { refresh() }
    @objc func toggleMode() {
        render()
        if sleepDisabled == 1 { disableMode() } else { enableMode() }
    }

    func confirm(_ title: String, _ message: String, accept: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "취소")
        alert.addButton(withTitle: accept)
        menu.cancelTracking()
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn
    }

    @objc func enableMode() {
        guard storageError == nil else { showError(storageError!); return }
        beginChange { [self] state in
            guard !(saved == nil && state.settings.sleepDisabled == 1) else {
                endChange("다른 곳에서 잠자기 방지를 켰습니다. 기존 앱에서 해제한 뒤 다시 켜 주세요.")
                return
            }
            guard let power = state.power else { endChange(state.powerError); return }
            if power.risk != nil && !confirm("이 전원 상태에서 원격 모드를 켤까요?", power.warning,
                accept: "확인하고 켜기") { endChange(); return }
            if saved == nil && !UserDefaults.standard.bool(forKey: "explained") &&
                !confirm("Mac의 잠자기를 방지합니다", "시스템 잠자기와 외부 전원 사용 시 자동 잠자기를 막고, 지원되는 네트워크 설정을 변경합니다.\n\nMacBook에서는 덮개 잠자기 방지와 배터리 경고도 적용합니다. 가방에 넣기 전에는 꺼 주세요. 끄면 앱이 변경한 항목을 이전 값으로 복원합니다. 켜고 끌 때 관리자 인증이 필요할 수 있습니다.", accept: "원격 모드 켜기") {
                endChange(); return
            }
            let newRecord = saved == nil
            let original = saved ?? state.settings
            if !newRecord {
                let target = enabledAC(original)
                let conflicts = target.keys.sorted().filter {
                    state.settings.ac[$0] != original.ac[$0] && state.settings.ac[$0] != target[$0]
                }
                if !conflicts.isEmpty && !confirm("다른 곳에서 변경한 설정이 있습니다",
                    "변경 항목: \(conflicts.joined(separator: ", "))\n원격 모드를 다시 적용하면 이 변경을 덮어씁니다.", accept: "원격 모드 다시 적용") {
                    endChange(); return
                }
            }
            do {
                let command = try enableCommands(original, current: state.settings)
                if newRecord { try save(original) }
                var authorizationError: String?
                var authorizationCancelled = false
                do { try authorize(command) } catch {
                    authorizationError = error.localizedDescription
                    authorizationCancelled = (error as? AppError)?.cancelled == true
                }
                readAsync { [self] result in
                    apply(result)
                    var error = authorizationError
                    if case .success(let actual) = result {
                        if authorizationError != nil || !actual.fullyEnabled {
                            error = error ?? "설정 적용을 확인하지 못했습니다. 복원 기록으로 이전 설정을 복원해 주세요."
                            if newRecord && authorizationCancelled && matches(actual.settings, original) {
                                do { try clearSaved() }
                                catch let cleanupError { error = "설정은 바뀌지 않았지만 복원 기록을 정리하지 못했습니다: \(cleanupError.localizedDescription)" }
                            }
                        } else {
                            acknowledgedRisk = power.risk
                            UserDefaults.standard.set(true, forKey: "explained")
                        }
                    } else { error = error ?? "변경 후 상태를 읽지 못했습니다. 복원 기록을 보존했습니다." }
                    endChange(error)
                    if error == nil { checkPowerRisk() }
                }
            } catch { endChange(error.localizedDescription) }
        }
    }

    @objc func disableMode() { turnOff() }

    func turnOff(completion: @escaping (Bool) -> Void = { _ in }) {
        beginChange({ [self] state in
            let original = storageError == nil ? saved : nil
            if let original {
                let conflicts = restoreConflicts(state.settings, original)
                if !conflicts.isEmpty && !confirm("다른 곳에서 변경한 설정이 있습니다", "변경 항목: \(conflicts.joined(separator: ", "))\n켜기 전에 저장한 값으로 복원하면 이 변경을 덮어씁니다.", accept: "저장한 값으로 복원") {
                    endChange(); completion(false); return
                }
            } else if !confirm("잠자기 방지만 해제할까요?", "유효한 복원 기록이 없어 이전 전원 설정 전체를 복원할 수 없습니다. 시스템 잠자기 방지만 해제하고, 나머지 설정과 복원 파일은 유지합니다. Mac이 잠자기에 들어가 원격 연결이 끊길 수 있습니다.", accept: "잠자기 방지 해제") {
                endChange(); completion(false); return
            }
            do {
                let command = try original.map { try restoreCommands($0, current: state.settings) } ??
                    transactionCommands(ac: [:], disabled: 0, expected: state.settings)
                var authorizationError: String?
                do { try authorize(command) } catch { authorizationError = error.localizedDescription }
                readAsync { [self] result in
                    apply(result)
                    var error = authorizationError
                    var verified = false
                    if case .success(let actual) = result {
                        verified = original.map { restored(actual.settings, $0) } ?? (actual.settings.sleepDisabled == 0)
                        if authorizationError == nil && verified {
                            do {
                                if original != nil { try clearSaved() }
                                acknowledgedRisk = nil
                            } catch let cleanupError { error = "설정은 복원됐지만 기록을 삭제하지 못했습니다: \(cleanupError.localizedDescription)" }
                        } else if error == nil { error = "이전 설정 복원을 확인하지 못했습니다. 복원 기록을 보존했습니다." }
                    } else { error = error ?? "변경 후 상태를 읽지 못했습니다. 복원 기록을 보존했습니다." }
                    endChange(error)
                    completion(error == nil && verified)
                }
            } catch { endChange(error.localizedDescription); completion(false) }
        }, failed: { completion(false) })
    }

    func checkPowerRisk() {
        guard !working, saved != nil, sleepDisabled == 1 else { return }
        let risk = live?.power?.risk ?? (live?.power == nil ? "unknown" : nil)
        guard let risk else { acknowledgedRisk = nil; return }
        guard risk != acknowledgedRisk else { return }
        acknowledgedRisk = risk
        warningVisible = true
        render()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "원격 모드의 전원 상태를 확인해 주세요"
        alert.informativeText = (live?.power?.warning ?? "배터리와 전원 상태를 읽지 못했습니다.") +
            "\n\n끄면 이전 설정을 복원합니다. Mac이 잠자기에 들어가 원격 연결이 끊길 수 있습니다."
        alert.addButton(withTitle: "끄고 복원")
        alert.addButton(withTitle: "계속 유지")
        menu.cancelTracking()
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        warningVisible = false
        render()
        if response == .alertFirstButtonReturn { turnOff() }
    }

    @objc func help() {
        let alert = NSAlert()
        alert.messageText = "원격지킴이 1.1 · 개인용"
        alert.informativeText = "토글로 원격 모드를 켜거나 끄세요. 실제 설정을 10초마다 확인합니다.\n\n끄면 앱이 변경한 전원 항목을 이전 값으로 복원합니다. MacBook에서 충전기가 없거나 배터리가 20% 이하이면 켜기 전에 확인합니다. Mac mini·Mac Studio 등은 배터리 경고 없이 사용합니다. 실행 중 위험 상태가 바뀌면 다시 알립니다. 자동으로 끄지는 않습니다.\n\n이 앱은 Codex 원격 연결 자체를 설정하거나 연결 여부를 검사하지 않습니다. 다른 잠자기 제어 앱과 함께 사용하지 마세요.\n\n강제 종료·전원 중단 후에도 설정은 남을 수 있습니다. 앱을 다시 열어 이전 설정을 복원해 주세요. 복원 파일이 손상되면 잠자기 방지만 긴급 해제할 수 있습니다.\n\n수동 긴급 해제: sudo pmset -a disablesleep 0\n개인용 로컬 서명 앱 · Apple 공증 없음."
        alert.addButton(withTitle: "확인")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc func quit() { NSApp.terminate(nil) }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !busy, !warningVisible, !terminationPending else { return .terminateCancel }
        guard saved != nil || sleepDisabled == 1 || assertion != 0 else { return .terminateNow }
        guard !refreshing else { return .terminateCancel }
        guard confirm("원격 모드를 끄고 종료할까요?", "끄면 이전 설정을 복원합니다. Mac이 잠자기에 들어가 연결이 끊길 수 있습니다.", accept: "끄고 종료") else { return .terminateCancel }
        terminationPending = true
        turnOff { [self] success in
            terminationPending = false
            sender.reply(toApplicationShouldTerminate: success)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if assertion != 0 { IOPMAssertionRelease(assertion) }
    }

    func showError(_ message: String) {
        let previous = warningVisible
        warningVisible = true
        render()
        defer { warningVisible = previous; render() }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "원격지킴이 확인"
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

func selfTest() throws {
    precondition(rootBoolean("SleepDisabled", in: " \"SleepDisabled\" = No") == false)
    precondition(rootBoolean("SleepDisabled", in: " \"SleepDisabled\" = Yes") == true)
    precondition(rootBoolean("SleepDisabled", in: " \"SleepDisabled\" = unknown") == nil)
    precondition(setting("SleepDisabled", in: "System-wide power settings:\n SleepDisabled\t\t1\n") == 1)
    precondition(setting("SleepDisabled", in: "no value") == nil)
    let text = "Battery Power:\n sleep 5\nAC Power:\n sleep 12\n womp 0\n tcpkeepalive 1\nUPS Power:\n sleep 99\n"
    let parsed = try acSettings(text)
    precondition(parsed == ["sleep": 12, "womp": 0, "tcpkeepalive": 1])
    let original = SavedSettings(version: 1, sleepDisabled: 0, ac: parsed, savedAt: Date())
    let decoded = try JSONDecoder().decode(SavedSettings.self, from: JSONEncoder().encode(original))
    precondition(matches(decoded, original))
    precondition(ownedAC(original) == ["sleep": 12, "womp": 0])
    let active = SavedSettings(version: 1, sleepDisabled: 1, ac: enabledAC(original), savedAt: Date())
    let enable = try enableCommands(original, current: original)
    precondition(enable.contains("trap '"))
    precondition(enable.contains("/usr/bin/pmset -c sleep 0 tcpkeepalive 1 womp 1"))
    precondition(enable.contains("/usr/bin/pmset -a disablesleep 1"))
    let restore = try restoreCommands(original, current: active)
    precondition(restore.contains("/usr/bin/pmset -c sleep 12 womp 0\n/usr/bin/pmset -a disablesleep 0"))
    let changed = SavedSettings(version: 1, sleepDisabled: 1,
        ac: ["sleep": 30, "womp": 1, "tcpkeepalive": 0], savedAt: Date())
    precondition(restoreConflicts(changed, original) == ["sleep"])
    let preserved = SavedSettings(version: 1, sleepDisabled: 0,
        ac: ["sleep": 12, "womp": 0, "tcpkeepalive": 0], savedAt: Date())
    precondition(restored(preserved, original))
    precondition(!matches(preserved, original))
    let unchanged = SavedSettings(version: 1, sleepDisabled: 0, ac: ["sleep": 0, "womp": 1], savedAt: Date())
    precondition(ownedAC(unchanged).isEmpty)
    let unchangedRestore = try restoreCommands(unchanged, current: unchanged)
    precondition(unchangedRestore.contains("/usr/bin/pmset -a disablesleep 0"))
    for unsafe in [["sleep; touch /tmp/bad": 1], ["sleep": -1], ["sleep": 0, "womp": 2]] {
        let bad = SavedSettings(version: 1, sleepDisabled: 0, ac: unsafe, savedAt: Date())
        do { try bad.validate(); preconditionFailure("Unsafe restore data accepted") } catch {}
    }
    func battery(_ current: Int, maximum: Int = 100) -> [String: Any] {
        [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true,
         kIOPSCurrentCapacityKey: current, kIOPSMaxCapacityKey: maximum]
    }
    for (source, percent, risk) in [(kIOPMACPowerKey, 80, nil), (kIOPMBatteryPowerKey, 80, "battery"),
        (kIOPMACPowerKey, 21, nil), (kIOPMACPowerKey, 20, "low-ac"),
        (kIOPMBatteryPowerKey, 20, "low-battery"), (kIOPMBatteryPowerKey, 0, "low-battery")] as [(String, Int, String?)] {
        let power = try powerState(source, descriptions: [battery(percent)])
        precondition(power.percent == percent && power.risk == risk)
    }
    for percent in 0...100 {
        let exact = try powerState(kIOPMACPowerKey, descriptions: [battery(percent)])
        precondition(exact.percent == percent)
    }
    let desktop = try powerState(kIOPMACPowerKey, descriptions: [])
    precondition(desktop.percent == nil && desktop.risk == nil && desktop.warning.isEmpty)
    precondition(desktop.text.contains("내장 배터리 없음"))
    let desktopOriginal = SavedSettings(version: 1, sleepDisabled: 0, ac: ["sleep": 12], savedAt: Date())
    let desktopActive = SavedSettings(version: 1, sleepDisabled: 1, ac: ["sleep": 0], savedAt: Date())
    let desktopState = SystemState(settings: desktopActive, power: desktop, powerError: nil, lid: nil)
    precondition(desktopState.fullyEnabled && desktopState.lid == nil)
    let desktopEnable = try enableCommands(desktopOriginal, current: desktopOriginal)
    let desktopRestore = try restoreCommands(desktopOriginal, current: desktopActive)
    precondition(desktopRestore.contains("/usr/bin/pmset -c sleep 12"))
    precondition(!desktopEnable.contains("womp") && !desktopEnable.contains("tcpkeepalive"))
    let ups = try powerState(kIOPMUPSPowerKey, descriptions: [[kIOPSTypeKey: kIOPSUPSType]])
    precondition(ups.percent == nil && ups.risk == nil && ups.text.contains("UPS"))
    let scaled = try powerState(kIOPMACPowerKey, descriptions: [battery(1000, maximum: 5000)])
    precondition(scaled.percent == 20 && scaled.risk == "low-ac")
    for (source, descriptions) in [("unknown", []), (kIOPMBatteryPowerKey, []),
        (kIOPMACPowerKey, [[:]]), (kIOPMACPowerKey, [[kIOPSTypeKey: kIOPSInternalBatteryType]]),
        (kIOPMACPowerKey, [battery(101)]), (kIOPMACPowerKey, [battery(-1)]),
        (kIOPMACPowerKey, [battery(0, maximum: 0)]),
        (kIOPMACPowerKey, [battery(Int.max, maximum: Int.max)]),
        (kIOPMACPowerKey, [[kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: false]])] as [(String, [[String: Any]])] {
        do { _ = try powerState(source, descriptions: descriptions); preconditionFailure("Invalid power state accepted") } catch {}
    }
    let enableSyntax = try run("/bin/sh", ["-n", "-c", enable])
    let restoreSyntax = try run("/bin/sh", ["-n", "-c", restore])
    precondition(enableSyntax.isEmpty && restoreSyntax.isEmpty)
    let stub = #"""
    global=0; sleep=12; womp=0; tcpkeepalive=1
    mock_ioreg() {
        if [ "$global" = 1 ]; then printf '"SleepDisabled" = Yes\n'; else printf '"SleepDisabled" = No\n'; fi
    }
    mock_pmset() {
        operation=$1
        case "$1" in
        -g)
            if [ "${2:-}" = custom ]; then
                printf 'Battery Power:\n sleep 5\nAC Power:\n sleep %s\n womp %s\n tcpkeepalive %s\n' "$sleep" "$womp" "$tcpkeepalive"
            else printf ' SleepDisabled %s\n' "$global"; fi ;;
        -c)
            shift
            while [ "$#" -gt 0 ]; do
                case "$1" in sleep) sleep=$2 ;; womp) womp=$2 ;; tcpkeepalive) tcpkeepalive=$2 ;; *) return 92 ;; esac
                shift 2
            done ;;
        -a)
            if [ "$3" = "$fail_on" ]; then echo MOCK_FAILURE; return 9; fi
            global=$3 ;;
        *) return 93 ;;
        esac
        if [ "$operation" != -g ]; then printf 'MOCK_STATE %s %s %s %s\n' "$global" "$sleep" "$womp" "$tcpkeepalive"; fi
    }
    """#
    let mockDesktop = desktopEnable.replacingOccurrences(of: "/usr/bin/pmset", with: "mock_pmset")
        .replacingOccurrences(of: "/usr/sbin/ioreg", with: "mock_ioreg")
    _ = try run("/bin/sh", ["-c", stub + "\nfail_on=never\n" + mockDesktop +
        "\n[ \"$global $sleep $womp $tcpkeepalive\" = '1 0 0 1' ]"])
    let mockEnable = enable.replacingOccurrences(of: "/usr/bin/pmset", with: "mock_pmset").replacingOccurrences(of: "/usr/sbin/ioreg", with: "mock_ioreg")
    let success = try run("/bin/sh", ["-c", stub + "\nfail_on=never\n" + mockEnable +
        "\n[ \"$global $sleep $womp $tcpkeepalive\" = '1 0 1 1' ]"])
    precondition(success.contains("MOCK_STATE 1 0 1 1"))
    do {
        _ = try run("/bin/sh", ["-c", stub + "\nfail_on=1\n" + mockEnable])
        preconditionFailure("Failed transaction accepted")
    } catch { precondition(error.localizedDescription.contains("MOCK_STATE 0 12 0 1")) }
    let mockRestore = restore.replacingOccurrences(of: "/usr/bin/pmset", with: "mock_pmset").replacingOccurrences(of: "/usr/sbin/ioreg", with: "mock_ioreg")
    let activeStub = stub + "\nglobal=1; sleep=0; womp=1; tcpkeepalive=0; fail_on=never\n"
    let preserveExternal = try restoreCommands(original, current:
        SavedSettings(version: 1, sleepDisabled: 1, ac: ["sleep": 0, "womp": 1, "tcpkeepalive": 0], savedAt: Date()))
        .replacingOccurrences(of: "/usr/bin/pmset", with: "mock_pmset").replacingOccurrences(of: "/usr/sbin/ioreg", with: "mock_ioreg")
    _ = try run("/bin/sh", ["-c", activeStub + preserveExternal +
        "\n[ \"$global $sleep $womp $tcpkeepalive\" = '0 12 0 0' ]"])
    do {
        _ = try run("/bin/sh", ["-c", stub + "\nglobal=1; sleep=0; womp=1; fail_on=0\n" + mockRestore])
        preconditionFailure("Failed restore accepted")
    } catch { precondition(error.localizedDescription.contains("MOCK_STATE 1 0 1 1")) }
    do {
        _ = try run("/bin/sh", ["-c", stub + "\nsleep=30; fail_on=never\n" + mockEnable])
        preconditionFailure("Concurrent setting change ignored")
    } catch { precondition(error.localizedDescription.contains("다른 곳에서 변경")) }
    do {
        _ = try run("/bin/sleep", ["2"], timeout: 0.05)
        preconditionFailure("Command timeout ignored")
    } catch {}
    // Compile the authentication request without executing it or requesting privileges.
    let source = "do shell script " + appleScriptLiteral(enable) +
        " with administrator privileges with prompt \"원격지킴이가 원격 모드 전원 설정을 변경합니다.\""
    var error: NSDictionary?
    let script = NSAppleScript(source: source)!
    precondition(script.compileAndReturnError(&error), "\(String(describing: error))")
    let live = try readState()
    guard live.power != nil else { throw AppError(message: live.powerError ?? "Live power state missing") }
    print("PASS: parsing, desktop power, battery warnings, restore ownership, validation, guarded transactions, rollback, timeout, auth compilation, live read")
}

if CommandLine.arguments.contains("--self-test") {
    do { try selfTest() } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
} else if CommandLine.arguments.contains("--status") {
    do {
        let state = try readState()
        print("실제 SleepDisabled: \(state.settings.sleepDisabled)")
        print(state.power?.text ?? "전원 상태 확인 불가")
        if let lid = state.lid { print(lid) }
        print(try run("/usr/bin/pmset", ["-g"]))
        print(try run("/usr/bin/pmset", ["-g", "custom"]))
        print(try run("/usr/bin/pmset", ["-g", "batt"]))
    } catch { fputs("\(error)\n", stderr); exit(1) }
} else {
    if let identifier = Bundle.main.bundleIdentifier,
       let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
        .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
        existing.activate(options: [])
        exit(0)
    }
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
