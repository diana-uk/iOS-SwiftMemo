import SwiftUI

struct Reminder: Identifiable {
    let id = UUID()
      let title: String
      let description: String
      let timestamp: Date
      let image: UIImage?
  }

  struct ContentView: View {
      @State private var reminders = [
          Reminder(title: "Reminder 1", description: "This is reminder 1", timestamp: Date(), image: nil),
          Reminder(title: "Reminder 2", description: "This is reminder 2", timestamp: Date(), image: nil),
          Reminder(title: "Reminder 3", description: "This is reminder 3", timestamp: Date(), image: nil)
      ]
      
      @State private var showAddReminder = false
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            content
                .navigationBarTitle("Reminders")
                .navigationBarItems(trailing: addButton)
        }
        .sheet(isPresented: $showAddReminder) {
            AddReminderView(reminders: $reminders)
        }
        #else
        content
            .frame(minWidth: 200, idealWidth: 300, maxWidth: .infinity, minHeight: 200, idealHeight: 400, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text("Reminders")
                        .font(.title)
                }
            }
        #endif
    }
    
    var content: some View {
        List {
            ForEach(reminders) { reminder in
                ReminderRow(reminder: reminder)
            }
        }
    }
    
    var addButton: some View {
        Button(action: {
            showAddReminder = true
        }) {
            Image(systemName: "plus")
        }
    }
}
struct ReminderRow: View {
    @State private var isChecked = false
    
    let reminder: Reminder
    
    var body: some View {
        HStack {
            Button(action: {
                isChecked.toggle()
            }) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "checkmark.square")
            }
            .foregroundColor(isChecked ? .green : .primary)
            
            VStack(alignment: .leading) {
                Text(reminder.title)
                    .font(.headline)
                    .foregroundColor(.gray)
                    .animation(.easeInOut) // Animation for description line
                    .strikethrough(isChecked) // Add line when checked
                    .opacity(isChecked ? 0.6 : 1.0) // Reduce opacity when checked
                Text(reminder.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .animation(.easeInOut) // Animation for description line
                    .strikethrough(isChecked) // Add line when checked
                    .opacity(isChecked ? 0.6 : 1.0) // Reduce opacity when checked
            }
            
            Spacer()
            Circle()
                .frame(width: 24, height: 24)
        }
    }
}


struct AddReminderView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var reminders: [Reminder]
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var creationTimestamp = Date()
    @State private var showDescriptionError = false
    @State private var isAnimating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminder Details")) {
                    TextField("Title", text: $title)
                    
                    TextEditor(text: $description)
                        .frame(height: 120) // Set desired height for the description TextEditor
                }
                
                if showDescriptionError {
                    Section {
                        Text("Description of the reminder cannot be empty!")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                
                Section {
                    if selectedImage != nil {
                        Image(uiImage: selectedImage!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Button(action: {
                            showImagePicker = true
                        }) {
                            Image(systemName: "camera")
                                .font(.title)
                                .frame(width: 120, height: 120)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                }
                
                Section {
                    Text("Created: \(creationTimestamp, formatter: DateFormatter.timestampFormatter)")
                        .foregroundColor(.gray)
                }
                
                Section {
                    Button(action: addReminder) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.title)
                            Text("Save")
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(
                            Group {
                                if isAnimating {
                                    Circle()
                                        .stroke(Color.green, lineWidth: 4)
                                        .scaleEffect(0.8)
                                        .opacity(isAnimating ? 1 : 0)
                                        .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: false))
                                }
                            }
                        )
                        .onAppear {
                            isAnimating = true
                        }
                        .onDisappear {
                            isAnimating = false
                        }
                    }
                }
            }
            .navigationBarTitle("New Reminder")
            .navigationBarItems(trailing: Button("Done", action: dismiss))
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
    
    func addReminder() {
        if title.isEmpty {
            title = "Empty Title"
        }
        
        if description.isEmpty {
            showDescriptionError = true
            return
        }
        
        let newReminder = Reminder(title: title, description: description, timestamp: creationTimestamp, image: selectedImage)
        reminders.append(newReminder)
        dismiss()
    }
    
    func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}



struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = context.coordinator
        return imagePicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.selectedImage = selectedImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

extension DateFormatter {
    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
