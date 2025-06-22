import SwiftUI
import FamilyControls

struct FamilyActivityPickerView: View {
    @State private var selection: FamilyActivitySelection
    private let onDismiss: () -> Void
    
    init(selection: FamilyActivitySelection, onDismiss: @escaping () -> Void) {
        self._selection = State(initialValue: selection)
        self.onDismiss = onDismiss
        print("FamilyActivityPickerView: Initialized with selection: \(selection.applications)")
    }
    
    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
            .navigationBarTitle("Select Apps", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        print("FamilyActivityPickerView: Cancel tapped, selection: \(selection.applications)")
                        onDismiss()
                    },
                    trailing: Button("Done") {
                        print("FamilyActivityPickerView: Done tapped, selection: \(selection.applications)")
                        onDismiss()
                    }
                )
        }
        .onChange(of: selection) { newSelection in
            print("FamilyActivityPickerView: Selection changed: \(newSelection.applications)")
        }
    }
}