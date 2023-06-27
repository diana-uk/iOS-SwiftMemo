import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseDatabase

struct Reminder: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let timestamp: Date
    let image: UIImage?
}

struct ContentView: View {
    @State private var reminders: [Reminder] = []
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
    
    init() {
        FirebaseApp.configure() // Initialize Firebase
        fetchReminders()
    }
    
    func fetchReminders() {
        let databaseRef = Database.database().reference().child("reminders")
        
        databaseRef.observe(.value) { snapshot in
            var newReminders: [Reminder] = []
            
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let reminderData = snapshot.value as? [String: Any],
                   let title = reminderData["title"] as? String,
                   let description = reminderData["description"] as? String,
                   let timestamp = reminderData["timestamp"] as? TimeInterval {
                    
                    let imageURL = URL(string: reminderData["imageURL"] as? String ?? "")
                    let image = imageURL.flatMap { url -> UIImage? in
                        if let data = try? Data(contentsOf: url),
                           let image = UIImage(data: data) {
                            return image
                        }
                        return nil
                    }
                    let reminder = Reminder(title: title, description: description, timestamp: Date(timeIntervalSince1970: timestamp), image: image)

                    newReminders.append(reminder)
                }
            }
            
            reminders = newReminders
        }
    }
    
    var content: some View {
        List {
            ForEach(reminders) { reminder in
                ReminderRow(reminder: reminder, selectedImage: reminder.image, reminders: $reminders) // Pass the selected image and the reminders binding

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
    @State private var isLongPressed = false // Add this line
    @State private var showAlert = false // Add this line

    let reminder: Reminder
    let selectedImage: UIImage? // Add this line
    @Binding var reminders: [Reminder] // Add this line

    
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
                    .foregroundColor(isChecked ? .gray : .primary)
                    .animation(.easeInOut) // Animation for description line
                    .strikethrough(isChecked) // Add line when checked
                    .opacity(isChecked ? 0.6 : 1.0) // Reduce opacity when checked
                Text(reminder.description)
                    .font(.subheadline)
                    .foregroundColor(isChecked ? .gray : .primary)
                    .animation(.easeInOut) // Animation for description line
                    .strikethrough(isChecked) // Add line when checked
                    .opacity(isChecked ? 0.6 : 1.0) // Reduce opacity when checked
            }
            
            Spacer()
            Circle()
                .frame(width: 40, height: 40)
                .overlay(
                    Image(uiImage: selectedImage ?? UIImage(systemName: "camera")!) // Display the selected image or a default system image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                )
        }
        .background(isLongPressed ? Color.red.opacity(0.2) : Color.clear) // Add this line
        .onLongPressGesture(minimumDuration: 3.0) {
            isLongPressed = true
            showAlert = true
        }
        .actionSheet(isPresented: $showAlert) {
            ActionSheet(title: Text("Delete Reminder?"), buttons: [
                .destructive(Text("Yes"), action: {
                    // Delete the reminder permanently
                    deleteReminder()
                }),
                .cancel(Text("No"), action: {
                    // Keep the reminder and dismiss the alert
                    isLongPressed = false
                    showAlert = false
                })
            ])
        }
    }
    
    func deleteReminder() {
           let databaseRef = Database.database().reference().child("reminders").child(reminder.id.uuidString)
           
           databaseRef.removeValue { error, _ in
               if let error = error {
                   print("Error deleting reminder from Firebase: \(error)")
               }
               // Remove the reminder from the local array
               if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                   reminders.remove(at: index)
               }
               // Reset the long press and alert state
               isLongPressed = false
               showAlert = false
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
                            Image(systemName: "square.and.arrow.down")
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
                    }
                }
            }
            .navigationBarTitle("New Reminder")
            .navigationBarItems(trailing: Button("Done", action: dismiss))
            .onAppear {
                isAnimating = true
            }
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
        
        saveReminderToFirebase(newReminder) // Save reminder to Firebase
        
        dismiss()
    }
    
    func saveReminderToFirebase(_ reminder: Reminder) {
        let databaseRef = Database.database().reference().child("reminders").childByAutoId()
        
        var reminderData: [String: Any] = [
            "title": reminder.title,
            "description": reminder.description,
            "timestamp": reminder.timestamp.timeIntervalSince1970
        ]
        
        if let imageData = reminder.image?.jpegData(compressionQuality: 0.8) {
            let storageRef = Storage.storage().reference().child("images").child(databaseRef.key!)
            storageRef.putData(imageData, metadata: nil) { _, error in
                if let error = error {
                    print("Error uploading image: \(error)")
                    return
                }
                
                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("Error fetching download URL: \(error)")
                        return
                    }
                    
                    guard let downloadURL = url else {
                        print("Download URL is nil.")
                        return
                    }
                    
                    reminderData["imageURL"] = downloadURL.absoluteString
                    
                    databaseRef.setValue(reminderData) { error, _ in
                        if let error = error {
                            print("Error saving reminder to Firebase: \(error)")
                        }
                    }
                }
            }
        } else {
            databaseRef.setValue(reminderData) { error, _ in
                if let error = error {
                    print("Error saving reminder to Firebase: \(error)")
                }
            }
        }
    }
    
    func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedImage: UIImage?
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.selectedImage = selectedImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = context.coordinator
        return imagePickerController
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // No update needed
    }
}

extension DateFormatter {
    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
