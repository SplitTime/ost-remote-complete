//
//  OSTDrawerContainer.swift
//  OST Tracker
//
//  Native right-side drawer container replacing MFSideMenuContainerViewController.
//  The center view controller fills the screen; opening the drawer slides it left
//  by the menu width to reveal the right menu underneath, with a dimmed
//  tap-to-dismiss overlay over the center (same feel as the old MFSideMenu).
//

import UIKit

@objc(OSTDrawerContainer)
class OSTDrawerContainer: UIViewController {

    private static let menuWidth: CGFloat = 270

    private(set) var isOpen = false
    private var panStartX: CGFloat = 0

    @objc var rightMenuViewController: UIViewController? {
        didSet {
            oldValue?.willMove(toParent: nil)
            oldValue?.view.removeFromSuperview()
            oldValue?.removeFromParent()
            guard let menu = rightMenuViewController else { return }
            addChild(menu)
            menu.view.autoresizingMask = [.flexibleHeight, .flexibleLeftMargin]
            menu.view.frame = rightMenuFrame()
            view.insertSubview(menu.view, at: 0) // behind the center
            menu.didMove(toParent: self)
        }
    }

    @objc var centerViewController: UIViewController? {
        didSet {
            guard oldValue !== centerViewController else { return }
            oldValue?.willMove(toParent: nil)
            oldValue?.view.removeFromSuperview()
            oldValue?.removeFromParent()
            guard let center = centerViewController else { return }
            addChild(center)
            center.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            center.view.frame = centerFrame(open: isOpen)
            view.addSubview(center.view) // in front of the menu
            center.didMove(toParent: self)
            if isOpen { attachOverlay(to: center) }
        }
    }

    private lazy var overlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = UIColor(white: 0, alpha: 0)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeDrawer)))
        overlay.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        return overlay
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Swipe in from the right edge to open (matches MFSideMenu's slide-to-open).
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        edgePan.edges = .right
        view.addGestureRecognizer(edgePan)
    }

    // MARK: - Interactive pan

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let centerVC = centerViewController, let center = centerVC.view else { return }
        let translation = gesture.translation(in: view).x

        switch gesture.state {
        case .began:
            panStartX = center.frame.origin.x // 0 when closed, -menuWidth when open
            view.endEditing(true)
            if overlay.superview == nil {
                attachOverlay(to: centerVC)
                overlay.backgroundColor = UIColor(white: 0, alpha: 0)
            }
        case .changed:
            let x = min(0, max(-Self.menuWidth, panStartX + translation))
            center.frame = view.bounds.offsetBy(dx: x, dy: 0)
            overlay.frame = center.bounds
            overlay.backgroundColor = UIColor(white: 0, alpha: 0.3 * (-x / Self.menuWidth))
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view).x
            let x = center.frame.origin.x
            let shouldOpen = velocity < -300 || (velocity <= 300 && x < -Self.menuWidth / 2)
            if shouldOpen { open(nil) } else { close(nil) }
        default:
            break
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        rightMenuViewController?.view.frame = rightMenuFrame()
        if !isOpen { centerViewController?.view.frame = view.bounds }
    }

    // MARK: - Public API (matches the old MFSideMenu call sites)

    @objc func toggleRightSideMenuCompletion(_ completion: (() -> Void)?) {
        if isOpen { close(completion) } else { open(completion) }
    }

    @objc func closeDrawer() {
        close(nil)
    }

    // MARK: - Open / close

    private func open(_ completion: (() -> Void)?) {
        guard let center = centerViewController?.view else { completion?(); return }
        view.endEditing(true)
        isOpen = true
        view.bringSubviewToFront(center)
        attachOverlay(to: centerViewController!)
        UIView.animate(withDuration: 0.25, animations: {
            center.frame = self.centerFrame(open: true)
            self.overlay.backgroundColor = UIColor(white: 0, alpha: 0.3)
        }, completion: { _ in completion?() })
    }

    private func close(_ completion: (() -> Void)?) {
        guard let center = centerViewController?.view else { completion?(); return }
        isOpen = false
        UIView.animate(withDuration: 0.25, animations: {
            center.frame = self.centerFrame(open: false)
            self.overlay.backgroundColor = UIColor(white: 0, alpha: 0)
        }, completion: { _ in
            self.overlay.removeFromSuperview()
            completion?()
        })
    }

    // MARK: - Geometry

    private func rightMenuFrame() -> CGRect {
        CGRect(x: view.bounds.width - Self.menuWidth, y: 0, width: Self.menuWidth, height: view.bounds.height)
    }

    private func centerFrame(open: Bool) -> CGRect {
        view.bounds.offsetBy(dx: open ? -Self.menuWidth : 0, dy: 0)
    }

    private func attachOverlay(to center: UIViewController) {
        overlay.frame = center.view.bounds
        center.view.addSubview(overlay)
    }
}
