import SwiftUI
import FamilyControls

struct FamilyActivityPickerView: View {
    @Binding var selection: FamilyActivitySelection
    private let onDone: () -> Void
    private let onCancel: () -> Void
    
    init(selection: Binding<FamilyActivitySelection>, onDone: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._selection = selection
        self.onDone = onDone
        self.onCancel = onCancel
        print("FamilyActivityPickerView: Initialized with selection: \(selection.wrappedValue.applications.map { $0.bundleIdentifier ?? "nil" })")
    }
    
    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        print("FamilyActivityPickerView: Cancel tapped, selection: \(selection.applications.map { $0.bundleIdentifier ?? "nil" })")
                        onCancel()
                    },
                    trailing: Button("Done") {
                        print("FamilyActivityPickerView: Done tapped, selection: \(selection.applications.map { $0.bundleIdentifier ?? "nil" })")
                        onDone()
                    }
                )
        }
        .onChange(of: selection) { newSelection in
            print("FamilyActivityPickerView: Selection changed: \(newSelection.applications.map { $0.bundleIdentifier ?? "nil" })")
        }
    }
}