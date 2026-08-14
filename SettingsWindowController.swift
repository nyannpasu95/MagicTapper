import Cocoa

/// Menu-accessible window exposing the tap-detection thresholds persisted
/// through `ConfigurationManager`. Changes apply live: `MultitouchManager`
/// observes the configuration-change notification on its touch queue.
///
/// Before this window existed, the persisted configuration could only be
/// changed by hand-editing UserDefaults, and the README still told users to
/// edit constants that no longer exist in source.
@MainActor
final class SettingsWindowController: NSWindowController {

    private struct SliderSpec {
        let title: String
        let unit: String
        let decimals: Int
        let minimumValue: Double
        let maximumValue: Double
        let read: (TapConfiguration) -> Double
        let write: (inout TapConfiguration, Double) -> Void
    }

    private let specs: [SliderSpec] = [
        SliderSpec(
            title: "Max Tap Duration",
            unit: "s",
            decimals: 2,
            minimumValue: 0.15,
            maximumValue: 0.6,
            read: { $0.tapTimeThreshold },
            write: { $0.tapTimeThreshold = $1 }
        ),
        SliderSpec(
            title: "Movement Tolerance",
            unit: "px",
            decimals: 0,
            minimumValue: 3,
            maximumValue: 20,
            read: { Double($0.tapMovementThreshold) },
            write: { $0.tapMovementThreshold = CGFloat($1) }
        ),
        SliderSpec(
            title: "Right-Click Hold Time",
            unit: "s",
            decimals: 2,
            minimumValue: 0.05,
            maximumValue: 0.3,
            read: { $0.rightClickTimeThreshold },
            write: { $0.rightClickTimeThreshold = $1 }
        ),
        SliderSpec(
            title: "Double-Tap Window",
            unit: "s",
            decimals: 2,
            minimumValue: 0.15,
            maximumValue: 0.6,
            read: { $0.doubleTapTimeWindow },
            write: { $0.doubleTapTimeWindow = $1 }
        ),
        SliderSpec(
            title: "Left/Right Boundary",
            unit: "%",
            decimals: 0,
            minimumValue: 40,
            maximumValue: 80,
            read: { Double($0.rightClickAreaThreshold) * 100.0 },
            write: { $0.rightClickAreaThreshold = Float($1 / 100.0) }
        ),
        SliderSpec(
            title: "Surface Movement Limit",
            unit: "%",
            decimals: 0,
            minimumValue: 1,
            maximumValue: 15,
            read: { Double($0.surfaceMovementThreshold) * 100.0 },
            write: { $0.surfaceMovementThreshold = Float($1 / 100.0) }
        ),
    ]

    private var sliders: [NSSlider] = []
    private var valueLabels: [NSTextField] = []
    private var pendingCommit: DispatchWorkItem?

    /// Debounce interval: slider drags tick continuously, and every committed
    /// value writes to UserDefaults and wakes the touch queue.
    private let commitDelay: TimeInterval = 0.25

    init() {
        let contentViewController = NSViewController()
        let window = NSWindow(contentViewController: contentViewController)
        window.title = "Sensitivity Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        super.init(window: window)

        buildContent(in: contentViewController.view)
        reloadFromConfiguration()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        pendingCommit?.cancel()
    }

    // MARK: - UI Construction

    private func buildContent(in contentView: NSView) {
        let headerLabel = NSTextField(labelWithString: "Fine-tune how taps are detected. Changes apply immediately.")
        headerLabel.font = NSFont.systemFont(ofSize: 11)
        headerLabel.textColor = .secondaryLabelColor

        let footnoteLabel = NSTextField(labelWithString: "Taps that move farther or last longer than these limits are treated as scrolling and ignored.")
        footnoteLabel.font = NSFont.systemFont(ofSize: 10)
        footnoteLabel.textColor = .secondaryLabelColor

        let grid = NSGridView()
        grid.columnSpacing = 12
        grid.rowSpacing = 14

        let config = ConfigurationManager.shared.current
        for (index, spec) in specs.enumerated() {
            let titleLabel = NSTextField(labelWithString: spec.title)
            titleLabel.font = NSFont.systemFont(ofSize: 12)

            let slider = NSSlider(
                value: spec.read(config),
                minValue: spec.minimumValue,
                maxValue: spec.maximumValue,
                target: self,
                action: #selector(sliderChanged(_:))
            )
            slider.isContinuous = true
            slider.tag = index

            let valueLabel = NSTextField(labelWithString: "")
            valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            valueLabel.alignment = .right

            sliders.append(slider)
            valueLabels.append(valueLabel)
            grid.addRow(with: [titleLabel, slider, valueLabel])
        }

        grid.column(at: 0).xPlacement = .leading
        grid.column(at: 1).xPlacement = .fill
        grid.column(at: 2).xPlacement = .trailing
        grid.column(at: 0).width = 160
        grid.column(at: 2).width = 56

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetToDefaults(_:)))
        resetButton.bezelStyle = .rounded

        let stackView = NSStackView(views: [headerLabel, grid, footnoteLabel, resetButton])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
            grid.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
        ])

        window?.setContentSize(NSSize(width: 460, height: contentView.fittingSize.height))
    }

    // MARK: - Actions

    @objc private func sliderChanged(_ sender: NSSlider) {
        let index = sender.tag
        guard specs.indices.contains(index) else { return }

        updateValueLabel(index: index, value: sender.doubleValue)

        pendingCommit?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.commit(index: index, value: sender.doubleValue)
        }
        pendingCommit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + commitDelay, execute: work)
    }

    private func commit(index: Int, value: Double) {
        let spec = specs[index]
        var config = ConfigurationManager.shared.current
        spec.write(&config, value)
        ConfigurationManager.shared.update(config)
    }

    @objc private func resetToDefaults(_ sender: NSButton) {
        pendingCommit?.cancel()
        ConfigurationManager.shared.resetToDefaults()
        reloadFromConfiguration()
    }

    // MARK: - Refresh

    private func reloadFromConfiguration() {
        let config = ConfigurationManager.shared.current
        for (index, spec) in specs.enumerated() {
            let value = spec.read(config)
            sliders[index].doubleValue = value
            updateValueLabel(index: index, value: value)
        }
    }

    private func updateValueLabel(index: Int, value: Double) {
        let spec = specs[index]
        valueLabels[index].stringValue = String(format: "%.\(spec.decimals)f %@", value, spec.unit as NSString)
    }
}
