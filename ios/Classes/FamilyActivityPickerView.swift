import SwiftUI
import FamilyControls

struct FamilyActivityPickerView: View {
    @State private var selection: FamilyActivitySelection
    private let onDismiss: () -> Void
    
    init(selection: FamilyActivitySelection, onDismiss: @escaping () -> Void) {
        self._selection = State(initialValue: selection)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationBarItems(trailing: Button("Done") {
                    onDismiss()
                })
        }
    }
}