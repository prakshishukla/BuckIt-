import PhotosUI
import SwiftUI

/// BeReal-style camera: back camera first, then auto-switches to the front camera for a skippable selfie.
/// On the Simulator (no camera) it offers the bundled demo photo or the photo library instead.
struct CaptureView: View {
    enum Phase { case back, selfie }

    let challenge: Challenge
    var onCancel: () -> Void
    var onCaptured: (UIImage, UIImage?) -> Void

    @State private var camera = CameraService()
    @State private var cameraReady = false
    @State private var checkedCamera = false
    @State private var phase: Phase = .back
    @State private var mainShot: UIImage?
    @State private var isCapturing = false
    @State private var countdown: Int?
    @State private var flash = false
    @State private var shutterCount = 0
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                topBar
                viewfinder
                Spacer(minLength: 0)
                controls
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Color.white
                .opacity(flash ? 0.85 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .task {
            cameraReady = await camera.start()
            checkedCamera = true
        }
        .onDisappear { camera.stop() }
        .task(id: phase) { await runSelfieCountdown() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPicked(item) }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: shutterCount)
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.app(.headline))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Close")
            Spacer()
            VStack(spacing: 2) {
                Text("BuckIt.").font(.display(.title3, weight: .heavy)).foregroundStyle(.white)
                Text(challenge.title).font(.app(.caption)).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 8)
    }

    private var viewfinder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                if cameraReady {
                    CameraPreview(session: camera.session)
                } else if checkedCamera {
                    noCameraPanel
                } else {
                    ProgressView().tint(.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topLeading) {
                if let mainShot, phase == .selfie {
                    Image(uiImage: mainShot)
                        .resizable().scaledToFill()
                        .frame(width: 84, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white, lineWidth: 2))
                        .padding(12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay {
                if phase == .selfie, let countdown {
                    VStack(spacing: 6) {
                        Text("Selfie time! 🤳").font(.display(.title2, weight: .heavy))
                        Text("\(countdown)")
                            .font(.display(size: 80, weight: .heavy))
                            .contentTransition(.numericText(countsDown: true))
                    }
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                }
            }
    }

    private var noCameraPanel: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.8))
            Text("No camera available")
                .font(.display(.title3))
                .foregroundStyle(.white)
            Text("The Simulator can't use a camera. Use the demo photo or pick one from your library.")
                .font(.app(.subheadline))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if cameraReady {
            HStack {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.app(.title2))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Choose from library")
                Spacer()
                Button {
                    Task { await shoot() }
                } label: {
                    Circle()
                        .stroke(.white, lineWidth: 6)
                        .frame(width: 84, height: 84)
                        .overlay(Circle().fill(.white).padding(10).scaleEffect(isCapturing ? 0.85 : 1))
                }
                .disabled(isCapturing)
                .accessibilityLabel(phase == .back ? "Take photo" : "Take selfie")
                Spacer()
                if phase == .selfie, let mainShot {
                    Button("Skip") {
                        countdown = nil
                        onCaptured(mainShot, nil)
                    }
                    .font(.app(.headline))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                } else {
                    Color.clear.frame(width: 56, height: 56)
                }
            }
            .padding(.horizontal, 12)
            Text(phase == .back ? "Snap your proof" : "Now flip it around")
                .font(.app(.footnote))
                .foregroundStyle(.white.opacity(0.7))
        } else if checkedCamera {
            VStack(spacing: 12) {
                Button {
                    useDemoPhoto()
                } label: {
                    Label("Use demo photo", systemImage: "photo.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose from library", systemImage: "photo.on.rectangle")
                        .font(.display(.headline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.15), in: Capsule())
                }
            }
        }
    }

    // MARK: - Actions

    private func shoot() async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        countdown = nil
        shutterCount += 1
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        withAnimation(.easeIn(duration: 0.3).delay(0.08)) { flash = false }

        guard let image = await camera.capture() else { return }

        switch phase {
        case .back:
            mainShot = image
            if camera.hasFrontCamera {
                await camera.switchCamera(to: .front)
                withAnimation(.spring) { phase = .selfie }
            } else {
                onCaptured(image, nil)
            }
        case .selfie:
            onCaptured(mainShot ?? image, image)
        }
    }

    /// BeReal-style: the selfie fires automatically after a short countdown unless skipped or shot manually.
    private func runSelfieCountdown() async {
        guard phase == .selfie else { return }
        for n in stride(from: 3, through: 1, by: -1) {
            withAnimation(.snappy) { countdown = n }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard countdown != nil else { return } // skipped or shot manually
        }
        countdown = nil
        if phase == .selfie, !isCapturing { await shoot() }
    }

    private func useDemoPhoto() {
        guard let hike = UIImage(named: "demo-hike") else { return }
        shutterCount += 1
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        withAnimation(.easeIn(duration: 0.3).delay(0.08)) { flash = false }
        onCaptured(hike, UIImage(named: "demo-selfie"))
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        if phase == .selfie, let mainShot {
            onCaptured(mainShot, image)
        } else {
            onCaptured(image, nil)
        }
    }
}
