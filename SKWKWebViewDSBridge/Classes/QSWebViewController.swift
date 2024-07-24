//
//  SKJSUtil.swift
//  SKWebViewLib
//
//  Created by 帅科 on 2021/8/5.
//

import UIKit
import WebKit
import ObjectNotification

public protocol QSWebViewSystemLifeCycleDelegate {
    func willResignActive() -> Void;
    func didBecomeActive() -> Void;
    func willEnterForeground() -> Void;
    func didEnterBackground() -> Void;
    func keyboardWillShow(_ userInfo:[AnyHashable:Any]?) -> Void;
}

public struct QSJSConstant {
    public static let compositingView = "WKCompositingView"
    public static let light = "light" // 状态栏风格
    public static let keyBoardInfo = "keyBoardInfo" //键盘信息key
    public static let reloadTimeoutInterval = 20.0
    public static let blankUrl = "about:blank"
}

public struct QSJSFuncName {
    public static let appDidBecomeActive = "appDidBecomeActive"
    public static let appWillResignActive = "appWillResignActive"
    public static let appWillEnterForeground = "appWillEnterForeground"
    public static let applicationDidEnterBackground = "applicationDidEnterBackground"
    public static let web_onKeyBoardWillShow = "web_onKeyBoardWillShow"
    public static let web_onKeyBoardWillHidden = "web_onKeyBoardWillHidden"
    
    public static let resume = "resume"
    public static let pause = "pause"
    public static let back = "back"
}

class QSProcessPool : WKProcessPool {
    static let shared = QSProcessPool()
}

open class QSWebViewController : UIViewController {
    
    @objc open var startPage : String = ""
    public var documentReadyState : DocumentReadStateType = .loading
    public var statusBarStyleChangeBlock : ((String,Any)->())?
    public var statusBarStyleStr : String = QSJSConstant.light
    public var resumeDict : [String:Any] = [String:Any]()
    // 默认导航栏右侧icMore按钮样式实现
    public var rightBarIcMoreStyleClickAction : ((_ sender:UIButton)->())?
    
    lazy public var rightNavBtn : UIButton = {
        let btn = UIButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        btn.addTarget(self, action: #selector(rightBarItemClickAction(_:)), for: .touchUpInside)
        btn.isHidden = true
        return btn
    }()
    
    // 自定义右侧按钮点击，默认是显示more样式
    @objc func rightBarItemClickAction(_ sender: UIButton) {
        if self.rightBarIcMoreStyleClickAction != nil {
            self.rightBarIcMoreStyleClickAction!(sender)
        }
    }

    open lazy var webview : QSWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = QSProcessPool.shared
        let view = QSWebView(frame: .zero, configuration: configuration)
        if #available(iOS 11.0, *) {
            view.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        view.navigationDelegate = self
        return view
    }()
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    convenience init(startPage : String){
        self.init()
        self.startPage = startPage
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 16.4, *) {
            self.webview.isInspectable = true
        } else {
            // Fallback on earlier versions
        }
        
        __setupNotification()
        
        self.view.backgroundColor = UIColor.white
        
        /// 布局webview
        self.view.addSubview(webview)
        webview.translatesAutoresizingMaskIntoConstraints = false
        let layoutConstraints = [.top,.left,.right,.bottom].map { attribute in
            return NSLayoutConstraint(item: webview, attribute: attribute, relatedBy: .equal, toItem: self.view, attribute: attribute, multiplier: 1.0, constant: 0)
        }
        self.view.addConstraints(layoutConstraints)
        
        /// 获取网页加载状态
        webview.documentStateBlock = {[weak self] state in
            self?.documentReadyState = state
        }
        
        /// 加载网页地址
        webview.loadUrl(startPage)
        
        /// 触发状态栏风格修改
        self.statusBarStyleChangeBlock = {[weak self] style,param in
            if style.count <= 0 { return }
            self?.statusBarStyleStr = style
            self?.setNeedsStatusBarAppearanceUpdate()
        }
        
        // 导航栏右按钮
        let barBtnItem = UIBarButtonItem(customView: rightNavBtn)
        self.navigationItem.rightBarButtonItem = barBtnItem
    }


    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let params = ["data":[],"resumeParam":resumeDict] as [String : Any]
        webview.callHandler(QSJSFuncName.resume, arguments: [params]) {[weak self] value in
            if let info = value as? [String:Any]{
                self?.resumeDict = info
            }
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webview.callHandler(QSJSFuncName.pause, arguments: [], completionHandler: nil)
    }
    
    private func __setupNotification() -> Void {
        /// 应用生命周期监听
        
        ObjectNotice.shared.observer(self, UIApplication.didBecomeActiveNotification.rawValue) {[weak
                                                                                                    self] object, userInfo in
            self?.didBecomeActive()
        }
        
        ObjectNotice.shared.observer(self, UIApplication.willResignActiveNotification.rawValue) {[weak
                                                                                                    self] object, userInfo in
            self?.willResignActive()
        }
        
        ObjectNotice.shared.observer(self, UIApplication.willEnterForegroundNotification.rawValue) {[weak
                                                                                                        self] object, userInfo in
            self?.willEnterForeground()
        }
        
        ObjectNotice.shared.observer(self, UIApplication.didEnterBackgroundNotification.rawValue) {[weak
                                                                                                        self] object, userInfo in
            self?.didEnterBackground()
        }
        
        ObjectNotice.shared.observer(self, UIApplication.keyboardWillShowNotification.rawValue) {[weak
                                                                                                    self] object, userInfo in
            self?.keyboardWillShow(userInfo)
        }
        
        ObjectNotice.shared.observer(self, UIApplication.keyboardWillHideNotification.rawValue) {[weak self] object, userInfo in
            self?.webview.hasJavascriptMethod(QSJSFuncName.web_onKeyBoardWillHidden, methodExistCallback: { isExists in
                if !isExists{ return }
                /// OC版对userInfo执行了mj_JSONObject方法；
                self?.webview.callHandler(QSJSFuncName.web_onKeyBoardWillHidden, arguments: [[QSJSConstant.keyBoardInfo:userInfo]], completionHandler: nil)
            })
        }
    }
    
    /// 状态栏风格
    open override var preferredStatusBarStyle: UIStatusBarStyle{
        if statusBarStyleStr == "light" {
            return .lightContent
        }
        if #available(iOS 13.0, *) {
            return .darkContent
        }
        return .default
    }
    
    /// 白屏判断
    private func isBlankView(_ view:UIView) -> Bool {

        guard let compositingViewClass = NSClassFromString(QSJSConstant.compositingView) else { return true }
        if view.isKind(of: compositingViewClass.self) {
            return false
        }
        for subview in view.subviews {
            if !isBlankView(subview){
                return false
            }
        }
        return true
    }
    
    open func reload() -> Void {
        guard let url = URL(string: startPage) else { return }
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: QSJSConstant.reloadTimeoutInterval)
        webview.load(request)
    }
    
    open func reloadRequestIfNeed() -> Void {
        // 存在url
        if self.webview.url != nil { return }
        // 非白屏
        if !isBlankView(self.webview) { return }
        // 重新加载
        reload()
    }
    
    deinit {
        ObjectNotice.shared.removeObserver(self)
        debugPrint("\(#function)")
    }
}

// 这里相当于申明，子类可以直接重写这些方法了。
extension QSWebViewController:WKNavigationDelegate{
    
    open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    open func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }
    
    open func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        
    }
    
    open func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        
    }
    
    open func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        
    }
    
    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
    }
    
    open func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        
    }
    
    open func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reloadRequestIfNeed()
    }
}

extension QSWebViewController: QSWebViewSystemLifeCycleDelegate{
    
    @objc open func willResignActive() {
        self.webview.callHandler(QSJSFuncName.appWillResignActive, arguments: [], completionHandler: nil)
    }
    
    @objc open func didBecomeActive() {
        self.webview.callHandler(QSJSFuncName.appDidBecomeActive, arguments: [], completionHandler: nil)
        // 检查白屏
        if self.isBlankView(self.webview){ self.reload() }
    }
     
    @objc open func willEnterForeground() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.25) {
            self.webview.callHandler(QSJSFuncName.appWillEnterForeground, arguments: [], completionHandler: nil)
        }
    }
    
    @objc open func didEnterBackground() {
        self.webview.callHandler(QSJSFuncName.applicationDidEnterBackground, arguments: [], completionHandler: nil)
    }
    
    @objc open func keyboardWillShow(_ userInfo:[AnyHashable:Any]?) {
        self.webview.hasJavascriptMethod(QSJSFuncName.web_onKeyBoardWillShow, methodExistCallback: { isExists in
            if !isExists { return }
            self.webview.callHandler(QSJSFuncName.web_onKeyBoardWillShow, arguments: [[QSJSConstant.keyBoardInfo:userInfo]], completionHandler: nil)
        })
    }
}
