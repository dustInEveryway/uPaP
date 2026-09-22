import UIKit

class SequencerViewController: UIViewController {

    private let sequencer = Sequencer.shared
    private var trackViews: [TrackView] = []
    private let scrollView = UIScrollView()
    private let gridStack = UIStackView()
    private let transportView = UIView()
    private let playButton = UIButton(type: .system)
    private let bpmLabel = UILabel()
    private let bpmSlider = UISlider()
    private var stepIndicators: [UIView] = []
    private var currentImportTrackIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Step Sequencer"
        view.backgroundColor = .white
        setupUI()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleTick),
                                               name: .sequencerDidTick,
                                               object: nil)
        buildGrid()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        transportView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 80)
        transportView.autoresizingMask = [.flexibleWidth]
        transportView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        view.addSubview(transportView)

        playButton.frame = CGRect(x: 16, y: 15, width: 50, height: 50)
        playButton.setTitle("▶", for: .normal)
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        playButton.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)
        transportView.addSubview(playButton)

        bpmLabel.frame = CGRect(x: 80, y: 15, width: 80, height: 20)
        bpmLabel.text = "BPM: 120"
        bpmLabel.font = UIFont.boldSystemFont(ofSize: 14)
        transportView.addSubview(bpmLabel)

        bpmSlider.frame = CGRect(x: 80, y: 40, width: 200, height: 30)
        bpmSlider.minimumValue = 60
        bpmSlider.maximumValue = 200
        bpmSlider.value = 120
        bpmSlider.addTarget(self, action: #selector(bpmChanged), for: .valueChanged)
        transportView.addSubview(bpmSlider)

        let indicatorStack = UIStackView()
        indicatorStack.axis = .horizontal
        indicatorStack.spacing = 4
        indicatorStack.translatesAutoresizingMaskIntoConstraints = false
        transportView.addSubview(indicatorStack)

        for _ in 0..<sequencer.stepsCount {
            let dot = UIView()
            dot.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            indicatorStack.addArrangedSubview(dot)
            stepIndicators.append(dot)
        }

        NSLayoutConstraint.activate([
            indicatorStack.trailingAnchor.constraint(equalTo: transportView.trailingAnchor, constant: -16),
            indicatorStack.centerYAnchor.constraint(equalTo: transportView.centerYAnchor)
        ])

        scrollView.frame = CGRect(x: 0, y: 80, width: view.bounds.width, height: view.bounds.height - 80)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        gridStack.axis = .vertical
        gridStack.spacing = 4
        gridStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(gridStack)

        NSLayoutConstraint.activate([
            gridStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 8),
            gridStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            gridStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            gridStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8)
        ])

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTrack))
        let clearButton = UIBarButtonItem(title: "Limpiar", style: .plain, target: self, action: #selector(clearPattern))
        navigationItem.rightBarButtonItems = [addButton, clearButton]
    }

    private func buildGrid() {
        for view in gridStack.arrangedSubviews {
            gridStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        trackViews.removeAll()

        for (index, track) in sequencer.tracks.enumerated() {
            let trackView = TrackView(track: track, trackIndex: index, steps: sequencer.stepsCount)
            trackView.delegate = self
            trackView.translatesAutoresizingMaskIntoConstraints = false
            trackView.heightAnchor.constraint(equalToConstant: 60).isActive = true
            trackView.widthAnchor.constraint(equalToConstant: 500).isActive = true
            gridStack.addArrangedSubview(trackView)
            trackViews.append(trackView)
        }
    }

    @objc private func togglePlay() {
        if sequencer.isPlaying {
            sequencer.stop()
            playButton.setTitle("▶", for: .normal)
            playButton.setTitleColor(.blue, for: .normal)
        } else {
            sequencer.start()
            playButton.setTitle("■", for: .normal)
            playButton.setTitleColor(.red, for: .normal)
        }
    }

    @objc private func bpmChanged() {
        sequencer.bpm = Double(bpmSlider.value)
        bpmLabel.text = "BPM: \(Int(sequencer.bpm))"
    }

    @objc private func addTrack() {
        sequencer.addTrack()
        buildGrid()
    }

    @objc private func clearPattern() {
        sequencer.clearPattern()
        for trackView in trackViews {
            trackView.refresh()
        }
    }

    @objc private func handleTick() {
        for (index, dot) in stepIndicators.enumerated() {
            dot.backgroundColor = (index == sequencer.currentStep)
                ? UIColor.blue
                : UIColor.gray.withAlphaComponent(0.3)
        }
        for trackView in trackViews {
            trackView.updateCurrentStep(sequencer.currentStep)
        }
    }
}

extension SequencerViewController: TrackViewDelegate {
    func trackView(_ view: TrackView, didTapStep step: Int) {
        sequencer.toggleStep(trackIndex: view.trackIndex, stepIndex: step)
        view.refresh()
    }

    func trackViewDidTapImport(_ view: TrackView) {
        currentImportTrackIndex = view.trackIndex
        let picker = UIDocumentPickerViewController(documentTypes: ["public.audio"], in: .import)
        picker.delegate = self
        picker.modalPresentationStyle = .formSheet
        present(picker, animated: true, completion: nil)
    }

    func trackViewDidTapMute(_ view: TrackView) {
        sequencer.tracks[view.trackIndex].isMuted.toggle()
        view.refresh()
    }

    func trackViewDidTapDelete(_ view: TrackView) {
        sequencer.removeTrack(at: view.trackIndex)
        buildGrid()
    }

    func trackView(_ view: TrackView, didChangeVolume volume: Float) {
        sequencer.tracks[view.trackIndex].volume = volume
    }
}

extension SequencerViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let trackIndex = currentImportTrackIndex else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        sequencer.assignFile(url: url, toTrack: trackIndex)
        if trackIndex < trackViews.count {
            trackViews[trackIndex].refresh()
        }
        currentImportTrackIndex = nil
    }
}
