import UIKit

/// Swift + UIKit replacement for the XIB-based `OSTLoginViewController`.
/// Programmatic Auto Layout pinned to the safe area (fixes the old "too high"
/// placement and is correct on Dynamic Island devices). Modern-iOS visual style.
@objc(LoginViewController)
final class LoginViewController: UIViewController {

    private let controller: LoginController
    private let store: CredentialStore

    // MARK: Init

    @objc init() {
        let base = (Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String)
            .flatMap(URL.init(string:)) ?? URL(string: "https://www.opensplittime.org/api/v1/")!
        let store = SessionCredentialStore()
        self.store = store
        self.controller = LoginController(auth: APIClient(baseURL: base), store: store)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: Views

    private let logo: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "OST Logo"))
        iv.contentMode = .scaleAspectFit
        iv.heightAnchor.constraint(equalToConstant: 72).isActive = true
        return iv
    }()
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "OST Remote"
        l.textAlignment = .center
        return l
    }()
    private let emailField = StyledTextField(placeholder: "Username", secure: false)
    private let passwordField = StyledTextField(placeholder: "Password", secure: true)
    private let loginButton = PrimaryButton(title: "Login", role: .success)
    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .gray)   // iOS 12-safe
        s.hidesWhenStopped = true
        return s
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        titleLabel.textColor = Theme.label
        titleLabel.font = Theme.Font.title

        emailField.text = store.email
        passwordField.text = store.password
        loginButton.addTarget(self, action: #selector(didTapLogin), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [logo, titleLabel,
                                                   spacer(20), emailField, passwordField,
                                                   spacer(8), loginButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(18, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        view.addSubview(spinner)
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -28),
            // Sit slightly above center for balance, but fully within the safe area.
            stack.centerYAnchor.constraint(equalTo: guide.centerYAnchor, constant: -40),
            stack.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: 20),
            spinner.centerXAnchor.constraint(equalTo: loginButton.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
        ])
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    // MARK: Actions

    @objc private func didTapLogin() {
        let email = emailField.text ?? ""
        let password = passwordField.text ?? ""
        setLoading(true)
        controller.login(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let auth):
                    // Forward the token to the legacy network manager the
                    // event-selection screen still uses, then load events +
                    // present (Obj-C helper reproduces the old loadEventData,
                    // incl. the events fetch + CoreData import + alerts).
                    AppDelegate.getInstance()?.getNetworkManager()?.addToken(toHeader: auth.token)
                    OSTEventSelectionViewController.loadEventDataAndPresent(from: self) { [weak self] _ in
                        DispatchQueue.main.async { self?.setLoading(false) }
                    }
                case .failure:
                    self.setLoading(false)
                    self.showError()
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        loginButton.isEnabled = !loading
        loginButton.alpha = loading ? 0.6 : 1
        loading ? spinner.startAnimating() : spinner.stopAnimating()
    }

    private func showError() {
        let alert = UIAlertController(title: "Login Failed",
                                      message: "Invalid email or password.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
