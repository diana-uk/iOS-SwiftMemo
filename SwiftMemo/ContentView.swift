import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseDatabase

struct Reminder: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let timestamp: Date
    let image: UIImage?
    var isChecked: Bool // Add isChecked field to the struct

    init(id: UUID?, title: String, description: String, timestamp: Date, image: UIImage?, isChecked: Bool = false) { // Provide a default value for isChecked
        if let id = id {
            self.id = id
        } else {
            self.id = UUID()
        }
        self.title = title
        self.description = description
        self.timestamp = timestamp
        self.image = image
        self.isChecked = isChecked // Initialize isChecked with the provided value or false by default
    }
}


struct ContentView: View {
    @State private var reminders: [Reminder] = []
    @State private var showAddReminder = false
    
    var databaseRef: DatabaseReference // Add database reference

    
    var body: some View {
        #if os(iOS)
        NavigationView {
            content
                .navigationBarTitle("Reminders")
                .navigationBarItems(trailing: addButton)
        }
        .sheet(isPresented: $showAddReminder) {
            AddReminderView(reminders: $reminders, databaseRef: databaseRef) // Pass database reference
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
        databaseRef = Database.database().reference().child("reminders") // Initialize database reference
          fetchReminders()
      
      }
    
    func fetchReminders() {
        let databaseRef = Database.database().reference().child("reminders")
        
        databaseRef.observe(.value) { snapshot, error in
            if let error = error {
                print("Error fetching reminders: \(error)")
                return
            }
             var newReminders: [Reminder] = []
            
             for child in snapshot.children {
                 if let snapshot = child as? DataSnapshot,
                    let reminderData = snapshot.value as? [String: Any],
                    let id = reminderData["id"] as? String,
                    let title = reminderData["title"] as? String,
                    let description = reminderData["description"] as? String,
                    let isChecked = reminderData["isChecked"] as? Bool,
                    let timestamp = reminderData["timestamp"] as? TimeInterval {
                    
                     let imageURL = URL(string: reminderData["imageURL"] as? String ?? "")
                     let image = imageURL.flatMap { url -> UIImage? in
                         if let data = try? Data(contentsOf: url),
                            let image = UIImage(data: data) {
                             return image
                         }
                         return nil
                     }
                     let reminder = Reminder(id: UUID(uuidString: id), title: title, description: description, timestamp: Date(timeIntervalSince1970: timestamp), image: image, isChecked: isChecked) // Update the initializer
                    
                     newReminders.append(reminder)
                 }
             }
            
             DispatchQueue.main.async {
                 reminders.append(contentsOf: newReminders)
             }
        }
    }
        
        struct ReminderRow: View {
            @State private var isChecked = false
            @State private var isLongPressed = false
            @State private var showAlert = false
            @State private var isEditing = false
            
            var reminder: Reminder
            var databaseRef: DatabaseReference
            var selectedImage: UIImage?
            @Binding var reminders: [Reminder]
            
            
            var body: some View {
                HStack {
                    Button(action: {
                        isChecked.toggle()
                        updateIsChecked(isChecked: Bool())
                    }) {
                        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
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
                        Text("\(formattedDate((reminder.timestamp)))")
                                       .font(.caption)
                                       .foregroundColor(isChecked ? .gray : .secondary)
                                       .animation(.easeInOut)
                                       .strikethrough(isChecked)
                                       .opacity(isChecked ? 0.6 : 1.0)
                    }
                    
                    Spacer()
                              
                              if let image = reminder.image {
                                  Image(uiImage: image)
                                      .resizable()
                                      .aspectRatio(contentMode: .fit)
                                      .frame(width: 50, height: 50)
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
                                isEditing = true
                            },
                            .destructive(Text("Delete")) {
                                showAlert = true
                            },
                            .cancel()
                        ]
                    )
                }
                .sheet(isPresented: $isEditing) {
                           EditReminderView(reminder: reminder, selectedImage: selectedImage, reminders: $reminders, databaseRef: databaseRef)
                       }
                
                
            }
            func deleteReminder() {
                reminders.removeAll { $0.id == reminder.id }
                let databaseRef = Database.database().reference().child("reminders")
                        let reminderRef = databaseRef.child(reminder.id.uuidString)
                        
                        reminderRef.removeValue { error, _ in
                            if let error = error {
                                print("Error deleting reminder: \(error.localizedDescription)")
                            } else {
                                reminders.removeAll { $0.id == reminder.id }
                            }
                        }
            }
            
            func updateIsChecked(isChecked:Bool) {
                let databaseRef = Database.database().reference().child("reminders").child(reminder.id.uuidString) // Use existing reminder ID

                let updatedReminderData: [String: Any] = [
                    "title": reminder.title,
                    "description": reminder.description,
                    "isChecked": isChecked,
                    "timestamp": reminder.timestamp.timeIntervalSince1970,
                    "imageURL": "" // Replace with the URL of the selected image
                ]

                databaseRef.updateChildValues(updatedReminderData) { error, _ in
                    if let error = error {
                        print("Error updating reminder: \(error.localizedDescription)")
                    } else {
                        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                            let updatedReminder =
                            Reminder(id: reminder.id,
                                     title: reminder.title, description: reminder.description, timestamp: reminder.timestamp, image: selectedImage,isChecked: reminder.isChecked)
                            reminders[index] = updatedReminder
                        }
                    }
                }
            }
                   
            
            struct EditReminderView: View {
                @Environment(\.presentationMode) var presentationMode
                @State private var title: String
                @State private var description: String
                @State private var selectedImage: UIImage?
                @State private var isShowingImagePicker = false
                @Binding var reminders: [Reminder]
                
                var reminder: Reminder
                var databaseRef: DatabaseReference // Add database reference

                init(reminder: Reminder, selectedImage: UIImage?, reminders: Binding<[Reminder]>, databaseRef: DatabaseReference) {
                    self.reminder = reminder
                    self._title = State(initialValue: reminder.title)
                    self._description = State(initialValue: reminder.description)
                    self._selectedImage = State(initialValue: selectedImage)
                    self._reminders = reminders
                    self.databaseRef = databaseRef
                }
                
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
                                            .onTapGesture {
                                                isShowingImagePicker = true
                                            }
                                    } else {
                                        Button(action: {
                                            isShowingImagePicker = true
                                        }) {
                                            Image(systemName: "plus.circle")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 100, height: 100)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                
                                Button(action: {
                                    // Handle image selection
                                    isShowingImagePicker = true
                                }) {
                                    Text("Select Image")
                                }
                                .sheet(isPresented: $isShowingImagePicker) {
                                    ImagePickerView(selectedImage: $selectedImage)
                                }

                        }
                        .navigationTitle("Edit Reminder")
                        .navigationBarItems(
                            leading: cancelButton,
                            trailing: saveButton
                        )
                    }
                    .onAppear {
                        title = reminder.title
                        description = reminder.description
                        // Assign selectedImage from reminder.image if necessary
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
                          updateReminder()
                          presentationMode.wrappedValue.dismiss()
                      }) {
                          Text("Save")
                      }
                  }
                func updateReminder() {
                      let databaseRef = self.databaseRef.child(reminder.id.uuidString) // Use existing reminder ID

                      let updatedReminderData: [String: Any] = [
                          "title": title,
                          "description": description,
                          "isChecked": reminder.isChecked,
                          "timestamp": reminder.timestamp.timeIntervalSince1970,
                          "imageURL": "" // Replace with the URL of the selected image
                      ]

                      databaseRef.updateChildValues(updatedReminderData) { error, _ in
                          if let error = error {
                              print("Error updating reminder: \(error.localizedDescription)")
                          } else {
                              if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                                  let updatedReminder =
                                  Reminder(id: reminder.id,
                                                      title: title, description: description, timestamp: reminder.timestamp, image: selectedImage)
                                  reminders[index] = updatedReminder
                              }
                          }
                      }
                  }
              }
            

    }
    struct ImagePickerView: UIViewControllerRepresentable {
        @Environment(\.presentationMode) var presentationMode
        @Binding var selectedImage: UIImage?
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        func makeUIViewController(context: Context) -> UIImagePickerController {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = context.coordinator
            return imagePickerController
        }
        
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        
        class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let parent: ImagePickerView
            
            init(_ parent: ImagePickerView) {
                self.parent = parent
            }
            
            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
                if let image = info[.originalImage] as? UIImage {
                    parent.selectedImage = image
                }
                parent.presentationMode.wrappedValue.dismiss()
            }
            
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
    struct AddReminderView: View {
        @Environment(\.presentationMode) var presentationMode
        @State private var title = ""
        @State private var description = ""
        @State private var selectedImage: UIImage?
        @State private var isShowingImagePicker = false

        @Binding var reminders: [Reminder]
        var databaseRef: DatabaseReference // Add database reference

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
                                           .aspectRatio(contentMode: .fit)
                                           .frame(maxWidth: 200, maxHeight: 200)
                                           .clipShape(Circle())
                                           .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                                           .onTapGesture {
                                               isShowingImagePicker = true
                                           }
                                   } else {
                                       Button(action: {
                                           isShowingImagePicker = true
                                       }) {
                                           Image(systemName: "plus.circle")
                                               .resizable()
                                               .aspectRatio(contentMode: .fit)
                                               .frame(width: 100, height: 100)
                                               .foregroundColor(.blue)
                                       }
                                   }
                               }
                               
                               Section(header: Text("Reminder Timestamp")) {
                                   Text("Posted at: \(formattedDate(Date()))")
                                       .font(.caption)
                                       .foregroundColor(.secondary)
                               }
                           }
                           .sheet(isPresented: $isShowingImagePicker) {
                               ImagePickerView(selectedImage: $selectedImage)
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
            let timestamp = Date().timeIntervalSince1970
        
            let reminder = Reminder(id: nil, title: title, description: description, timestamp: Date(timeIntervalSince1970: timestamp), image: selectedImage)
            
            let databaseRef = self.databaseRef.child(reminder.id.uuidString)

               let reminderData: [String: Any] = [
                "id": reminder.id.uuidString,
                   "title": title,
                   "description": description,
                    "isChecked": reminder.isChecked ,
                   "timestamp": timestamp,
                   "imageURL": "" // Replace with the URL of the selected image
               ]

               databaseRef.setValue(reminderData) { error, _ in
                   if let error = error {
                       print("Error saving reminder: \(error.localizedDescription)")
                   } else {
                     
                       reminders.append(reminder)
                   }
               }
           }
    }

    var content: some View {
        List {
            ForEach(reminders) { reminder in
                ReminderRow(reminder: reminder, databaseRef: databaseRef, selectedImage: reminder.image, reminders: $reminders)
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

    
  
   
    

// Function to calculate the time ago since a given date
   private func timeAgoSince(_ date: Date) -> String {
       let formatter = RelativeDateTimeFormatter()
       formatter.unitsStyle = .full
       return formatter.localizedString(for: date, relativeTo: Date())
   }

private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
