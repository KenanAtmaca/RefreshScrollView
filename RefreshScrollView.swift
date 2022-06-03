//
//  RefreshScrollView.swift
//
//  Created by Kenan Atmaca on 3.06.2022.
//

import SwiftUI

struct RefreshScrollView<Content: View>: View {

    enum RefreshScrollType {
        case `default`
        case progress
        case custom(AnyView)
    }

    typealias AsyncVoidBlock = (() async -> ())

    @StateObject private var scrollDelegate: ScrollViewDelegate = .init()

    var type: RefreshScrollType = .default
    var content: Content
    var onRefresh: AsyncVoidBlock
    var showIndicators: Bool = false
    private let refreshContentHeight: CGFloat = 120

    init(type: RefreshScrollType = .default, @ViewBuilder content: @escaping () -> Content, onRefresh: @escaping AsyncVoidBlock, showIndicators: Bool = false) {
        self.type = type
        self.content = content()
        self.onRefresh = onRefresh
        self.showIndicators = showIndicators
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: showIndicators) {
            VStack {
                VStack {
                    switch type {
                    case .default:
                        VStack(spacing: 7) {
                            ProgressView()
                            Text("Loading..")
                                .font(.caption.bold())
                        }
                    case .progress: ProgressView()
                    case .custom(let customView): customView
                    }
                }.frame(height: refreshContentHeight * scrollDelegate.progress)
                    .opacity(scrollDelegate.progress)
                    .offset(y: scrollDelegate.isElligible ? -(scrollDelegate.contentOffset < 0 ? 0 : scrollDelegate.contentOffset) : -(scrollDelegate.scrollOffset < 0 ? 0 : scrollDelegate.scrollOffset))
            }
            .offset(coordinateSpace: "RefreshScrollView") { offset in
                scrollDelegate.contentOffset = offset
                if !scrollDelegate.isElligible {
                    var progress = offset / refreshContentHeight
                    progress = (progress < 0 ? 0 : progress)
                    progress = (progress > 1 ? 1 : progress)
                    scrollDelegate.scrollOffset = offset
                    scrollDelegate.progress = progress
                }

                if scrollDelegate.isElligible && !scrollDelegate.isRefreshing {
                    scrollDelegate.isRefreshing = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }

            content
        }
        .coordinateSpace(name: "RefreshScrollView")
        .onAppear(perform: scrollDelegate.addPanGesture)
        .onDisappear(perform: scrollDelegate.removeGesture)
        .onChange(of: scrollDelegate.isRefreshing) { newValue in
            if newValue {
                Task {
                    await onRefresh()
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrollDelegate.progress = 0
                        scrollDelegate.isElligible = false
                        scrollDelegate.isRefreshing = false
                        scrollDelegate.scrollOffset = 0
                    }
                }
            }
        }
    }
}

// MARK: ScrollViewDelegate Actions

class ScrollViewDelegate: NSObject, ObservableObject, UIGestureRecognizerDelegate {

    @Published var isElligible: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var scrollOffset: CGFloat = 0
    @Published var progress: CGFloat = 0
    @Published var contentOffset: CGFloat = 0

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func addPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(gesture:)))
        panGesture.delegate = self
        rootController().view.addGestureRecognizer(panGesture)
    }

    func removeGesture() {
        rootController().view.gestureRecognizers?.removeAll()
    }

    @objc func panGestureAction(gesture: UIPanGestureRecognizer) {
        if gesture.state == .cancelled || gesture.state == .ended {
            if !isRefreshing {
                isElligible = scrollOffset > 150
            }
        }
    }

    func rootController() -> UIViewController {
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return .init()}
        guard let root = screen.windows.first?.rootViewController else { return .init() }
        return root
    }
}

// MARK: View extension

extension View {
    @ViewBuilder
    func offset(coordinateSpace: String, offset: @escaping (CGFloat) -> ()) -> some View {
        self
            .overlay(
                GeometryReader { proxy in
                    let minY = proxy.frame(in: .named(coordinateSpace)).minY
                    Color.clear
                        .preference(key: OffsetKey.self, value: minY)
                        .onPreferenceChange(OffsetKey.self) { value in
                            offset(value)
                        }
                }
            )
    }
}

// MARK: Offset PreferenceKey

struct OffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
