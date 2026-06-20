import UIKit

/// Theme-styled text field used on the login screen. Carries the field fill,
/// rounded corners, and the appropriate autofill content type.
final class StyledTextField: UITextField {
    init(placeholder: String, secure: Bool) {
        super.init(frame: .zero)
        self.placeholder = placeholder
        borderStyle = .roundedRect
        backgroundColor = Theme.fieldFill
        font = Theme.Font.field
        textColor = Theme.label
        isSecureTextEntry = secure
        autocapitalizationType = .none
        autocorrectionType = .no
        textContentType = secure ? .password : .username
        layer.cornerRadius = Theme.Metric.cornerRadius
        heightAnchor.constraint(equalToConstant: Theme.Metric.fieldHeight).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}
