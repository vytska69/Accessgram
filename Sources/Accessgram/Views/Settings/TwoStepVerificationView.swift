import SwiftUI

@MainActor
struct TwoStepVerificationView: View {
    @State private var vm: TwoStepVerificationViewModel
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var hintText = ""
    @State private var showRemoveConfirm = false

    init(client: TDLibClient) {
        _vm = State(initialValue: TwoStepVerificationViewModel(client: client))
    }

    private var passwordMismatch: Bool {
        !newPassword.isEmpty && newPassword != confirmPassword
    }

    private var canSubmit: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword && !vm.isSaving
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                form
            }
        }
        .navigationTitle("Two-Step Verification")
        .task { await vm.load() }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Success", isPresented: Binding(
            get: { vm.successMessage != nil },
            set: { if !$0 { vm.successMessage = nil } }
        )) {
            Button("OK") { vm.successMessage = nil }
        } message: {
            Text(vm.successMessage ?? "")
        }
        .confirmationDialog(
            "Disable two-step verification?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Disable", role: .destructive) {
                Task { await vm.applyPassword(old: oldPassword, new: "", newHint: "") }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer need a password when logging in from a new device.")
        }
    }

    private var form: some View {
        List {
            statusSection
            passwordFormSection
            if vm.hasPassword {
                removeSection
            }
        }
        .listStyle(.inset)
    }

    private var statusSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: vm.hasPassword ? "lock.fill" : "lock.open")
                    .foregroundStyle(vm.hasPassword ? .green : .secondary)
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.hasPassword ? "Enabled" : "Disabled")
                        .font(.headline)
                    if vm.hasPassword, !vm.hint.isEmpty {
                        Text("Hint: \(vm.hint)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                vm.hasPassword
                    ? "Two-step verification enabled\(vm.hint.isEmpty ? "" : ", hint: \(vm.hint)")"
                    : "Two-step verification disabled"
            )
        } header: {
            Text("Status")
        } footer: {
            Text(
                vm.hasPassword
                    ? "A password is required when logging in from a new device."
                    : "Add a password as an extra layer of security for your account."
            )
        }
    }

    private var passwordFormSection: some View {
        Section(vm.hasPassword ? "Change Password" : "Set Password") {
            if vm.hasPassword {
                SecureField("Current password", text: $oldPassword)
                    .accessibilityLabel("Current password")
            }
            SecureField("New password", text: $newPassword)
                .accessibilityLabel("New password")
            SecureField("Confirm new password", text: $confirmPassword)
                .accessibilityLabel("Confirm new password")
            if passwordMismatch {
                Text("Passwords do not match.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: passwords do not match")
            }
            TextField("Hint (optional)", text: $hintText)
                .accessibilityLabel("Password hint, optional")
            Button {
                Task {
                    await vm.applyPassword(old: oldPassword, new: newPassword, newHint: hintText)
                    if vm.successMessage != nil {
                        oldPassword = ""
                        newPassword = ""
                        confirmPassword = ""
                        hintText = ""
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    if vm.isSaving {
                        ProgressView()
                    } else {
                        Text(vm.hasPassword ? "Update Password" : "Enable")
                    }
                    Spacer()
                }
            }
            .disabled(!canSubmit)
            .accessibilityLabel(vm.hasPassword ? "Update password" : "Enable two-step verification")
        }
    }

    private var removeSection: some View {
        Section {
            Button(role: .destructive) {
                showRemoveConfirm = true
            } label: {
                Label("Disable Two-Step Verification", systemImage: "lock.open")
                    .foregroundStyle(.red)
            }
            .accessibilityHint("Removes the additional login password from your account")
        }
    }
}
