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
                ReminderRow(reminder: reminder, selectedImage: reminder.image, reminders: $reminders)
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
    @State private var isLongPressed = false
    @State private var showAlert = false
    
    let reminder: Reminder
    let selectedImage: UIImage?
    @Binding var reminders: [Reminder]
    
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
                    .animation(.easeInOut)
                    .strikethrough(isChecked)
                    .opacity(isChecked ? 0.6 : 1.0)
                Text(reminder.description)
                    .font(.subheadline)
                    .foregroundColor(isChecked ? .gray : .secondary)
                    .animation(.easeInOut)
                    .strikethrough(isChecked)
                    .opacity(isChecked ? 0.6 : 1.0)
                Text(reminder.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(isChecked ? .gray : .secondary)
                    .animation(.easeInOut)
                    .strikethrough(isChecked)
                    .opacity(isChecked ? 0.6 : 1.0)
            }
            
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            isChecked.toggle()
        }
        .onLongPressGesture {
            isLongPressed = true
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Delete Reminder"),
                message: Text("Are you sure you want to delete this reminder?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteReminder()
                },
                secondaryButton: .cancel()
            )
        }
        .actionSheet(isPresented: $isLongPressed) {
            ActionSheet(
                title: Text("Reminder Actions"),
                message: nil,
                buttons: [
                    .default(Text("Edit")) {
                        // Handle edit action
                    },
                    .destructive(Text("Delete")) {
                        showAlert = true
                    },
                    .cancel()
                ]
            )
        }
    }
    
    func deleteReminder() {
        reminders.removeAll { $0.id == reminder.id }
    }
}

struct AddReminderView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var description = ""
    @State private var selectedImage: UIImage?
    @Binding var reminders: [Reminder]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminder Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Image")) {
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                    }
                    
                    Button(action: {
                        // Handle image selection
                    }) {
                        Text("Select Image")
                    }
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarItems(
                leading: cancelButton,
                trailing: saveButton
            )
        }
    }
    
    var cancelButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("Cancel")
        }
    }
    
    var saveButton: some View {
        Button(action: {
            saveReminder()
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("Save")
        }
    }
    
    func saveReminder() {
        let databaseRef = Database.database().reference().child("reminders").childByAutoId()
        let timestamp = Date().timeIntervalSince1970
        
        let reminderData: [String: Any] = [
            "title": title,
            "description": description,
            "timestamp": timestamp,
            "imageURL": "" // Replace with the URL of the selected image
        ]
        
        databaseRef.setValue(reminderData) { error, _ in
            if let error = error {
                print("Error saving reminder: \(error.localizedDescription)")
            } else {
                let reminder = Reminder(title: title, description: description, timestamp: Date(timeIntervalSince1970: timestamp), image: selectedImage)
                reminders.append(reminder)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
