import SwiftUI
import SwiftData

struct AddContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var contact: Contact?
    
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Details") {
                    TextField("Full Name", text: $name)
                    TextField("Username", text: $username)
                    TextField("Email", text: $email)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle(contact == nil ? "Add New Contact" : "Edit Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveContact()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .frame(width: 400, height: 300)
        .onAppear {
            if let contact = contact {
                name = contact.name
                username = contact.username
                email = contact.email
            }
        }
    }
    
    private func saveContact() {
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedEmail.isEmpty else {
            errorMessage = "Email is required."
            showError = true
            return
        }
        
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let contact = contact {
            contact.name = cleanedName.isEmpty ? cleanedUsername : cleanedName
            contact.username = cleanedUsername.isEmpty ? cleanedEmail : cleanedUsername
            contact.email = cleanedEmail
        } else {
            let newContact = Contact(
                name: cleanedName.isEmpty ? cleanedUsername : cleanedName,
                username: cleanedUsername.isEmpty ? cleanedEmail : cleanedUsername,
                email: cleanedEmail
            )
            modelContext.insert(newContact)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save contact: \(error.localizedDescription)"
            showError = true
        }
    }
}
