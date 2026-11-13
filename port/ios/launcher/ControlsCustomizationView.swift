// GPL-3.0-or-later
import SwiftUI

struct ControlsCustomizationView: View {
    @ObservedObject private var model = LauncherModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showTouchEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Touchscreen Controls") {
                    Button("Arrange and remap touch controls") {
                        model.beginControlsEditing()
                        showTouchEditor = true
                    }
                    Text("Drag controls and set each button's size individually (25% to 600%). Save separate layouts for portrait and landscape.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Physical Controllers") {
                    NavigationLink("Controller button bindings") { ControllerBindingsView() }
                }
            }
            .navigationTitle("Customize Controls")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .fullScreenCover(isPresented: $showTouchEditor, onDismiss: { model.endControlsEditing() }) {
            TouchLayoutEditorView()
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .onAppear { model.beginControlsEditing() }
        .onDisappear { model.endControlsEditing() }
    }
}

private struct TouchLayoutEditorView: View {
    @ObservedObject private var model = LauncherModel.shared
    @ObservedObject private var store = TouchLayoutStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = TouchLayoutStore.shared.configuration
    @State private var baseline = TouchLayoutStore.shared.configuration
    @State private var orientation = TouchLayoutOrientation.portrait
    @State private var prepared = Set<TouchLayoutOrientation>()
    @State private var selected = TouchLayoutSlot.cross
    @State private var showOptions = false
    @State private var errorMessage: String?
    @State private var confirmDiscard = false
    @State private var confirmRestore = false
    @State private var loaded = false
    @State private var histories: [TouchLayoutOrientation: TouchLayoutEditHistory] = [:]

    private let accent = Color(red: 0.30, green: 0.89, blue: 0.73)
    private let panel = Color(red: 0.09, green: 0.11, blue: 0.14)
    private var hasChanges: Bool { draft != baseline }
    private var selectedIndex: Int? { draft[orientation].controls.firstIndex { $0.slot == selected } }
    private var selection: Binding<TouchLayoutSlot> {
        Binding(get: { selected }, set: { select($0) })
    }

    var body: some View {
        GeometryReader { geo in
            let viewport = TouchLayoutViewport(geometry: geo, model: model)
            VStack(spacing: 8) {
                toolbar
                if viewport.orientation == .landscape && geo.size.width >= 500 {
                    HStack(spacing: 12) {
                        preview(viewport)
                        ScrollView {
                            inspector
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(width: min(320, geo.size.width * 0.40))
                    }
                } else {
                    preview(viewport)
                    inspector.frame(maxWidth: 520)
                }
                Text("Tap to select. Drag to move. Rotate to change layout.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                if !loaded {
                    draft = store.configuration
                    baseline = draft
                    prepared.removeAll()
                    loaded = true
                }
                prepare(viewport)
            }
            .onChange(of: viewport) { _, next in
                finishEdit(orientation)
                showOptions = false
                prepare(next)
            }
        }
        .background(Color(red: 0.04, green: 0.05, blue: 0.07).ignoresSafeArea())
        .tint(accent)
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                finishEdit(orientation)
                showOptions = false
            }
        }
        .confirmationDialog("Discard unsaved changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) { }
        }
        .alert("Could not save controls", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button {
                finishEdit(orientation)
                if hasChanges { confirmDiscard = true }
                else { dismiss() }
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("Cancel"))

            VStack(alignment: .leading, spacing: 2) {
                Text("Touch Controls")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.text(orientation.title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            iconButton("Undo", systemImage: "arrow.uturn.backward", action: undo)
                .disabled(!(histories[orientation]?.canUndo ?? false))
            iconButton("Redo", systemImage: "arrow.uturn.forward", action: redo)
                .disabled(!(histories[orientation]?.canRedo ?? false))
            Button {
                finishEdit(orientation)
                do { try store.save(draft); dismiss() }
                catch { errorMessage = error.localizedDescription }
            } label: {
                Text("Save")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(accent, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
    }

    private func preview(_ viewport: TouchLayoutViewport) -> some View {
        GeometryReader { geo in
            let canvas = viewport.contentRect.size
            let scale = min(1, min(geo.size.width / canvas.width, geo.size.height / canvas.height))
            let shape = RoundedRectangle(cornerRadius: 16)
            ZStack {
                shape.fill(.black)
                Path { guide in
                    guide.move(to: CGPoint(x: canvas.width / 2, y: 0))
                    guide.addLine(to: CGPoint(x: canvas.width / 2, y: canvas.height))
                    guide.move(to: CGPoint(x: 0, y: canvas.height / 2))
                    guide.addLine(to: CGPoint(x: canvas.width, y: canvas.height / 2))
                }
                .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                TouchControlSurface(layout: viewport.projected(draft[viewport.orientation]),
                                    orientation: viewport.orientation, editing: true, selected: selected,
                                    onSelect: { select($0) },
                                    onMove: { move($0, $1, $2, orientation: viewport.orientation) },
                                    onDragStateChange: { active in
                                        if !active { finishEdit(viewport.orientation) }
                                    })
                    .id("\(canvas.width):\(canvas.height)")
            }
            .frame(width: canvas.width, height: canvas.height)
            .coordinateSpace(name: "touch-layout")
            .clipShape(shape)
            .overlay { shape.strokeBorder(.white.opacity(0.18)).allowsHitTesting(false) }
            .scaleEffect(scale)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let index = selectedIndex {
                let control = draft[orientation].controls[index]
                HStack(spacing: 8) {
                    Menu {
                        Picker("Control", selection: selection) {
                            ForEach(draft[orientation].controls) { placement in
                                Text(verbatim: controlName(placement)).tag(placement.slot)
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Control").font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(verbatim: controlName(control))
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                        }
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(L10n.text("Control"))
                    .accessibilityValue(controlName(control))

                    Spacer(minLength: 0)
                    if !control.visible {
                        Text("Hidden").font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        finishEdit(orientation)
                        showOptions = true
                    } label: {
                        ViewThatFits(in: .horizontal) {
                            Label("Control options", systemImage: "slider.horizontal.3").fixedSize()
                            Image(systemName: "slider.horizontal.3")
                        }
                        .font(.caption)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text("Control options"))
                    .popover(isPresented: $showOptions, arrowEdge: .bottom) {
                        controlOptions
                            .frame(minWidth: 290, idealWidth: 330, minHeight: 300, idealHeight: 400)
                            .presentationCompactAdaptation(.sheet)
                    }
                }
                sizeAdjustment(index)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)).allowsHitTesting(false) }
    }

    private func controlName(_ placement: TouchControlPlacement) -> String {
        let slot = L10n.text(placement.slot.title)
        if placement.slot == placement.action { return slot }
        return "\(slot) → \(L10n.text(placement.action.title))"
    }

    private var controlOptions: some View {
        NavigationStack {
            Form {
                if let index = selectedIndex {
                    let control = draft[orientation].controls[index]
                    Section(controlName(control)) {
                        if selected.isButton {
                            Picker("Action", selection: Binding(
                                get: { draft[orientation].controls[index].action },
                                set: { action in edit { $0.assign(action, to: selected) } }
                            )) {
                                ForEach(TouchLayoutSlot.allCases.filter(\.isButton)) { action in
                                    Text(L10n.text(action.title)).tag(action)
                                }
                            }
                        }
                        Toggle("Visible", isOn: Binding(
                            get: { draft[orientation].controls[index].visible },
                            set: { visible in edit { $0.controls[index].visible = visible } }
                        ))
                        .disabled(!selected.isButton || control.action.essential)
                        adjustment("Horizontal position", value: valueBinding(index, \.x))
                        adjustment("Vertical position", value: valueBinding(index, \.y))
                    }
                }
                Section {
                    Button("Restore this layout", role: .destructive) {
                        finishEdit(orientation)
                        confirmRestore = true
                    }
                }
            }
            .confirmationDialog("Restore this layout?", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Restore this layout", role: .destructive) {
                    edit { $0 = TouchLayoutDevice.isPad ? .ipadDefaults(orientation) : .defaults(orientation) }
                    showOptions = false
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The other orientation will keep its current layout.")
            }
            .navigationTitle("Control options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        finishEdit(orientation)
                        showOptions = false
                    }
                }
            }
        }
    }

    private func sizeAdjustment(_ index: Int) -> some View {
        let value = valueBinding(index, \.scale)
        let range = TouchControlPlacement.minimumScale...TouchControlPlacement.maximumScale
        return VStack(spacing: 2) {
            HStack {
                Text("Size").fontWeight(.semibold)
                Spacer()
                Button("Reset to 100%") { setSize(index, to: 1) }
                    .font(.caption)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 44)
                    .disabled(value.wrappedValue == 1)
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
            .font(.subheadline)
            HStack(spacing: 6) {
                iconButton("Smaller", systemImage: "minus") { changeSize(index, by: -0.10) }
                    .disabled(value.wrappedValue <= range.lowerBound)
                VStack(spacing: 0) {
                    slider("Size", value: value,
                           range: TouchControlPlacement.minimumScale...TouchControlPlacement.maximumScale)
                    HStack {
                        Text(range.lowerBound, format: .percent)
                        Spacer()
                        Text(range.upperBound, format: .percent)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                }
                iconButton("Larger", systemImage: "plus") { changeSize(index, by: 0.10) }
                    .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }

    private func iconButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(L10n.text(title))
    }

    private func changeSize(_ index: Int, by amount: Double) {
        let current = draft[orientation].controls[index].scale
        setSize(index, to: (current * 100 + amount * 100).rounded() / 100)
    }

    private func setSize(_ index: Int, to amount: Double) {
        edit { layout in
            layout.controls[index].scale = min(TouchControlPlacement.maximumScale,
                                               max(TouchControlPlacement.minimumScale, amount))
        }
    }

    private func adjustment(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(L10n.text(title))
                Spacer()
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0))).monospacedDigit()
            }
            .font(.caption)
            slider(title, value: value, range: 0...1)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        let mode = orientation
        return Slider(value: value, in: range, step: 0.01, onEditingChanged: { active in
            if active && mode == orientation { beginEdit(mode) }
            else if !active { finishEdit(mode) }
        })
        .accessibilityLabel(L10n.text(title))
        .accessibilityValue(Text(value.wrappedValue, format: .percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction { direction in
            let delta: Double
            switch direction {
            case .increment: delta = 0.01
            case .decrement: delta = -0.01
            @unknown default: return
            }
            let next = (value.wrappedValue * 100 + delta * 100).rounded() / 100
            value.wrappedValue = min(range.upperBound, max(range.lowerBound, next))
            finishEdit(mode)
        }
    }

    private func prepare(_ viewport: TouchLayoutViewport) {
        orientation = viewport.orientation
        guard !prepared.contains(orientation) else { return }
        draft[orientation] = viewport.projected(draft[orientation])
        baseline[orientation] = draft[orientation]
        prepared.insert(orientation)
    }

    private func move(_ slot: TouchLayoutSlot, _ x: Double, _ y: Double, orientation: TouchLayoutOrientation) {
        guard orientation == self.orientation,
              let index = draft[orientation].controls.firstIndex(where: { $0.slot == slot }) else { return }
        beginEdit(orientation)
        draft[orientation].controls[index].x = x
        draft[orientation].controls[index].y = y
    }

    private func select(_ slot: TouchLayoutSlot) {
        finishEdit(orientation)
        selected = slot
    }

    private func valueBinding(_ index: Int, _ path: WritableKeyPath<TouchControlPlacement, Double>) -> Binding<Double> {
        let mode = orientation
        let slot = selected
        return Binding(get: { draft[mode].controls[index][keyPath: path] }, set: { value in
            guard mode == orientation, slot == selected else { return }
            beginEdit(mode)
            draft[mode].controls[index][keyPath: path] = value
        })
    }

    private func beginEdit(_ orientation: TouchLayoutOrientation) {
        var history = histories[orientation, default: TouchLayoutEditHistory()]
        history.begin(draft[orientation])
        histories[orientation] = history
    }

    private func finishEdit(_ orientation: TouchLayoutOrientation) {
        guard var history = histories[orientation] else { return }
        history.commit(draft[orientation])
        histories[orientation] = history
    }

    private func edit(_ change: (inout TouchLayout) -> Void) {
        finishEdit(orientation)
        let previous = draft[orientation]
        var current = previous
        change(&current)
        var history = histories[orientation, default: TouchLayoutEditHistory()]
        history.record(from: previous, to: current)
        histories[orientation] = history
        draft[orientation] = current
    }

    private func undo() {
        finishEdit(orientation)
        var history = histories[orientation, default: TouchLayoutEditHistory()]
        if let previous = history.undo(draft[orientation]) { draft[orientation] = previous }
        histories[orientation] = history
    }

    private func redo() {
        finishEdit(orientation)
        var history = histories[orientation, default: TouchLayoutEditHistory()]
        if let next = history.redo(draft[orientation]) { draft[orientation] = next }
        histories[orientation] = history
    }
}
