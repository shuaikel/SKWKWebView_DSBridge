//
//  SKBaseWKWebview.swift
//  SKWebViewLib
//
//  Created by 帅科 on 2021/8/5.
//

import UIKit
import WebKit

public typealias JSCallback = (_ result:String?,_ complete:Bool) -> Void

open class SKBaseWKWebview: WKWebView {

    private var alertHandler : (()->Void)?
    private var confirmHandler : ((_ result:Bool)->Void)?
    private var promptHandler : ((_ str:String)->Void)?
    private var javascriptCloseWindowListener : (()->Void)?
    private var dialogType : Int = 0
    private var callId : Int64 = 0
    private var jsDialogBlock : Bool = false
    private var javaScriptNamespaceInterfaces : [String:Any] = [:]
    private var handerMap : [AnyHashable:Any] = [:]
    private var callInfoList : [QSCallInfo]? = []
    private var dialogTextDic : [String:String] = [:]
    private var txtName : UITextField?
    private var lastCallTime : UInt64 = 0
    private var jsCache : String? = ""
    private var isPending : Bool = false
    private var isDebug : Bool = false
    
    open weak var DSUIDelegate : WKUIDelegate?;
    
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        
        let script = WKUserScript.init(source: "window._dswk=true;", injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)
        
        super.init(frame: frame, configuration: configuration)
    
        self.uiDelegate = self
        
        let interalApis = QSInternalApis()
        interalApis.webview = self
        addJavascriptObject(interalApis, "_dsb")
    }
    
    func setDebugMode(_ debug:Bool) {
        self.isDebug = debug
    }
    

    func onMessage(_ msg:Dictionary<AnyHashable, Any>, _ type:DSB_API) -> Any? {
        
        var ret : Any? = nil
        switch type {
            case .HASNATIVEMETHOD:do {
                ret = hasNativeMethod(msg)
                break
            }
            case .CLOSEPAGE : do {
                closePage(msg)
                break
            }
            case .RETURNVALUE : do {
                ret = returnValue(msg)
                break
            }
            case .DSINIT : do {
                ret = dsinit(msg)
                break
            }
            case .DISABLESAFETYALERTBOX : do {
                let disable = msg["disable"] as? Bool ?? false
                self.disableJavascriptDialogBlock(disable)
                break
            }
        }
        return ret
    }
    
    
    func hasNativeMethod(_ args:[AnyHashable:Any?]) -> Bool {
        
        let nameStr : [String]? = SKJSUtil.parseNamespace(((args["name"] as? String)?.trimmingCharacters(in:.whitespaces))!)
        let typeName = (args["type"] as? String)?.trimmingCharacters(in: .whitespaces)
        
        let JavascriptInterfaceObject = javaScriptNamespaceInterfaces[nameStr?.first ?? ""]
        
        if  JavascriptInterfaceObject != nil{
            let classNameInfo : AnyClass =  (type(of: JavascriptInterfaceObject!) as? AnyClass)!
            let syn : Bool = SKJSUtil.methodByNameArg(1, selName: nameStr![1], className: classNameInfo)?.count ?? 0 > 0
            let asyn : Bool = SKJSUtil.methodByNameArg(2, selName: nameStr![1], className: classNameInfo)?.count ?? 0 > 0
            
            if (typeName == "all" && syn||asyn) || (typeName == "asyn" && asyn) || (typeName=="syn" || syn) {
                return true
            }
        }
        return false
    }
    
    open func addJavascriptObject(_ object:Any? , _ namespace : String) {
        if object != nil {
            javaScriptNamespaceInterfaces[namespace] = object
        }
    }
    
    func removeJavascriptObject(_ namespace:String) {
        javaScriptNamespaceInterfaces.removeValue(forKey: namespace)
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


public extension SKBaseWKWebview {
    
    func callHandler(_ method:String ,arguments:Array<Any>? = nil ,completionHandler: ((Any) -> Void)? = nil ) {
        
        let callInfo = QSCallInfo()
        callId+=1
        callInfo.id = callId
        callInfo.args = arguments
        callInfo.method = method
        if completionHandler != nil {
            handerMap[callId] = completionHandler
        }
        
        guard callInfoList != nil else {
            self.dispatchJavascriptCall(callInfo)
            return
        }
        callInfoList?.append(callInfo)
    }
    
    
    func setJavascriptCloseWindowListener(_ callback:(() -> Void)? ) {
        javascriptCloseWindowListener = callback
    }
    
    
    func hasJavascriptMethod(_ handlerName:String ,methodExistCallback:((_ exist:Bool)->Void)?) {
        callHandler("_hasJavascriptMethod", arguments: [handlerName]) { (value) in
            if methodExistCallback != nil {
                methodExistCallback!(value as! Bool)
            }
        }
    }
    
    func customJavascriptDialogLabelTitles(_ dic:[AnyHashable:Any]?) {
        guard let temp = dic as? [String:String] else {
            return
        }
        dialogTextDic = temp
    }
    
    
}


extension SKBaseWKWebview {
    
    func loadUrl(_ url:String) {
        let request = URLRequest.init(url: URL.init(string: url)!)
        self.load(request)
    }

    func closePage(_ args:[AnyHashable:Any?]) {
        if javascriptCloseWindowListener != nil {
            javascriptCloseWindowListener!()
        }
    }
    
    func returnValue(_ args:[AnyHashable:Any?]) {
        
        let callID = args["id"] as! Int64

        let completionHandler = handerMap[callID] as? ((Any) -> Void)?
        
        if completionHandler != nil {
            if completionHandler! != nil {
                let arg = args["data"] as Any? ?? ""
                completionHandler!!(arg)
            }
        }
        
        if (args["complete"] as? Bool) == true {
            handerMap.removeValue(forKey: (args["id"]! as? AnyHashable)!)
        }

    }
    

    func dsinit(_ args:[AnyHashable:Any?]) {
        self.dispatchStartupQueue()
    }
    
    
    func dispatchStartupQueue() {
        if (callInfoList == nil) {
            return
        }
        callInfoList?.forEach({ (callInfo) in
            self.dispatchJavascriptCall(callInfo)
        })
        callInfoList = nil
    }
    
    func dispatchJavascriptCall(_ callInfo:QSCallInfo) {
        
        guard let methodStr = callInfo.method else { return  }
        
        let json = SKJSUtil.objToJsonString(["method":methodStr,"callbackId":callInfo.id,"data":SKJSUtil.objToJsonString(callInfo.args)])
        
        self.evaluateJavaScript(String.init(format: "window._handleMessageFromNative(%@)", json), completionHandler: nil)
    }
    
    public func disableJavascriptDialogBlock(_ disable:Bool) {
        jsDialogBlock = !disable
    }
    
}

extension SKBaseWKWebview : WKUIDelegate {
    
    
    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        
        let prefix = "_dsbridge="
        
        let range = prompt.range(of: prefix)
        
        if prompt.hasPrefix(prefix) {
            
            let method = prompt[range!.upperBound...]
            
            let result = self.call(String(method), defaultText ?? "")
            
            completionHandler(result)
        } else {
            
            if jsDialogBlock == false {
                completionHandler(nil)
            }
            
            if (self.DSUIDelegate != nil) && self.DSUIDelegate!.responds(to: #selector(webView(_:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:))) {
                
                 self.DSUIDelegate?.webView?(webView, runJavaScriptTextInputPanelWithPrompt: prompt, defaultText: defaultText, initiatedByFrame: frame, completionHandler: completionHandler)
                
                return
            } else {
                
                dialogType = 3
                
                if jsDialogBlock {
                    promptHandler = completionHandler
                }
                
                let alertVC = UIAlertController.init(title: prompt, message: "", preferredStyle: UIAlertController.Style.alert)
                
                alertVC.addAction(UIAlertAction.init(title: dialogTextDic["promptCancelBtn"] ?? "取消",
                                                     style: UIAlertAction.Style.cancel,
                                                     handler: { [weak self] (action:UIAlertAction) in
                                                        
                                                        self?.promptHandler?("")
                                       
                                                        if self != nil {
                                                            self!.promptHandler = nil
                                                            self!.txtName = nil
                                                        }
                }))
                
                alertVC.addAction(UIAlertAction.init(title: dialogTextDic["promptOkBtn"] ?? "确定",
                                                     style: UIAlertAction.Style.default,
                                                     handler: {[weak self] (action:UIAlertAction) in
                   
                                                        if (self?.promptHandler != nil && self?.txtName != nil) {
                                                            self?.promptHandler?(self?.txtName?.text ?? "")
                                                        }
                                                        
                                                        if self != nil {
                                                            self!.promptHandler = nil
                                                            self!.txtName = nil
                                                        }
                }))
                
                txtName = alertVC.textFields?.first
                txtName?.text = defaultText
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+0.1) {
                    let rootVC = UIApplication.shared.keyWindow?.rootViewController
                    rootVC?.present(alertVC, animated: true, completion: nil)
                }
            }
        }
    }
    
  
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        
        if jsDialogBlock == false {
           completionHandler()
        }
        
        if (self.DSUIDelegate != nil) && self.DSUIDelegate!.responds(to: #selector(webView(_:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:))) {
             self.DSUIDelegate?.webView?(webView, runJavaScriptAlertPanelWithMessage: message, initiatedByFrame: frame, completionHandler: completionHandler)
            return
        }
        
        dialogType = 1
        
        if jsDialogBlock {
            alertHandler = completionHandler
        }
        
        let alertVC = UIAlertController.init(title: dialogTextDic["alertTitle"] ?? "提示", message: message, preferredStyle: UIAlertController.Style.alert)
        
        alertVC.addAction(UIAlertAction.init(title: dialogTextDic["alertBtn"] ?? "确定",
                                             style: UIAlertAction.Style.cancel,
                                             handler: { [weak self] (action:UIAlertAction) in
        
                                                self?.alertHandler?()
                                                self?.alertHandler = nil
        }))
    
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+0.1) {
            let rootVC = UIApplication.shared.keyWindow?.rootViewController
            rootVC?.present(alertVC, animated: true, completion: nil)
        }
    }
    
    
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
      
        if jsDialogBlock == false {
           completionHandler(true)
        }
        
        if (self.DSUIDelegate != nil) && self.DSUIDelegate!.responds(to: #selector(webView(_:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:completionHandler:))) {
             self.DSUIDelegate?.webView?(webView, runJavaScriptConfirmPanelWithMessage: message, initiatedByFrame: frame, completionHandler: completionHandler)
            return
        }
        
        dialogType = 2
        
        if(jsDialogBlock){
            confirmHandler=completionHandler;
        }
        
        let alertVC = UIAlertController.init(title: dialogTextDic["confirmTitle"] ?? "提示", message: message, preferredStyle: UIAlertController.Style.alert)
        
        alertVC.addAction(UIAlertAction.init(title: dialogTextDic["confirmCancelBtn"] ?? "确定",
                                             style: UIAlertAction.Style.cancel,
                                             handler: {[weak self] (action:UIAlertAction) in
                                                
                                                self?.confirmHandler?(false)
                                                if self != nil {
                                                    self!.confirmHandler = nil
                                                }
        }))
        
        alertVC.addAction(UIAlertAction.init(title: dialogTextDic["confirmOkBtn"] ?? "确定",
                                             style: UIAlertAction.Style.default,
                                             handler: { [weak self] (action:UIAlertAction) in
           
                                                self?.confirmHandler?(true)
                                                if self != nil {
                                                    self!.confirmHandler = nil
                                                }
        }))
        
        
    
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+0.1) {
            let rootVC = UIApplication.shared.keyWindow?.rootViewController
            rootVC?.present(alertVC, animated: true, completion: nil)
        }
        
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        if (self.DSUIDelegate != nil) && self.DSUIDelegate!.responds(to: #selector(webView(_:createWebViewWith:for:windowFeatures:))) {
            return self.DSUIDelegate?.webView?(webView, createWebViewWith: configuration, for: navigationAction, windowFeatures: windowFeatures)
        }
        return nil
    }
    
    
    public func webViewDidClose(_ webView: WKWebView) {
        if (self.DSUIDelegate != nil) && self.DSUIDelegate!.responds(to: #selector(webViewDidClose(_:))) {
            self.DSUIDelegate?.webViewDidClose?(webView)
        }
    }
    
    @available(iOS 10.0, *)
    public func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {

        if (self.DSUIDelegate != nil) && self.DSUIDelegate!.responds(to: #selector(webView(_:shouldPreviewElement:))) {
            let res = self.DSUIDelegate?.webView?(webView, shouldPreviewElement: elementInfo) ?? false
            return res
        }
        
        return false
    }
    
    @available(iOS 10.0, *)
    public func webView(_ webView: WKWebView, previewingViewControllerForElement elementInfo: WKPreviewElementInfo, defaultActions previewActions: [WKPreviewActionItem]) -> UIViewController? {

        if (self.DSUIDelegate != nil) && self.DSUIDelegate!.responds(to: #selector(webView(_:previewingViewControllerForElement:defaultActions:))) {
            let res = self.DSUIDelegate?.webView?(webView, previewingViewControllerForElement: elementInfo, defaultActions: previewActions)
            return res
        }
        
        return nil
    }
    
    @available(iOS 10.0, *)
    public func webView(_ webView: WKWebView, commitPreviewingViewController previewingViewController: UIViewController) {
        if (self.DSUIDelegate != nil) && self.DSUIDelegate!.responds(to: #selector(webView(_:commitPreviewingViewController:))) {
            self.DSUIDelegate?.webView?(webView, commitPreviewingViewController: previewingViewController)
        }
    }
    
    
    func call(_ method:String,_ argStr:String) -> String {
        
        let nameStr = SKJSUtil.parseNamespace(method.trimmingCharacters(in: .whitespaces))
        
        let JavascriptInterfaceObject = javaScriptNamespaceInterfaces[nameStr?.first ?? ""]
        var result = ["code":-1,"data":""] as [String : Any]
        let error = String.init(format: "Error! \n Method %@ is not invoked, since there is not a implementation for it", method )
        if  JavascriptInterfaceObject == nil{
            debugPrint("Js bridge  called, but can't find a corresponded JavascriptObject , please check your code")
        }else {
            let classNameInfo :AnyClass = (type(of: JavascriptInterfaceObject!) as? AnyClass)!
            let methodOne = SKJSUtil.methodByNameArg(1, selName: nameStr![1], className: classNameInfo) ?? ""
            let methodTwo = SKJSUtil.methodByNameArg(2, selName: nameStr![1], className: classNameInfo) ?? ""
            
            let sel = NSSelectorFromString(methodOne)
            let selasyn = NSSelectorFromString(methodTwo)
            
            let args = SKJSUtil.jsonStringToObject(argStr)
        
            var arg = args?["data"] ?? nil
            
            if arg != nil {
                if type(of: arg!) == NSNull.self {
                    arg = nil
                }
            }
            repeat {
                if (args?["_dscbstub"] as? String)?.count ?? 0 > 0 {
                    
                    if (JavascriptInterfaceObject as AnyObject).responds(to: selasyn) {
                        
                        let completionHandler = { [self](value:Any?,complete:Bool) in
                            
                            if let resultValue = value {
                                result["data"] = resultValue
                            }
                            result["code"] = 0
                            
                            var tempValue = SKJSUtil.objToJsonString(result)
                            tempValue = tempValue.addingPercentEncoding(withAllowedCharacters: .whitespaces)!
                            
                            var del = ""
                            
                            if complete == true {
                                del = "delete window.".appending(args?["_dscbstub"] as! String)
                            }
                            
                            let js = String.init(format: "try {%@(JSON.parse(decodeURIComponent(\"%@\")).data);%@; } catch(e){};", args?["_dscbstub"] as! String, tempValue,del)
                            
                            objc_sync_enter(self)
                            
                            let t = Date().timeIntervalSince1970*1000
                            
                            jsCache = jsCache?.appending(js)
                            
                            if (UInt64(t)-lastCallTime < 50) {
                                if isPending == false {
                                    self.evalJavascript(50)
                                    self.isPending = true
                                }
                            } else {
                                self.evalJavascript(0)
                            }
                        }
                        
                        // 消息转发
                        let impl = method_getImplementation(class_getInstanceMethod((JavascriptInterfaceObject as AnyObject).classForCoder, selasyn)!)
                        typealias ObjCVoidVoidFn =  @convention(c) (AnyObject,Selector,Any?,@escaping JSCallback) -> Any?
                        let fn = unsafeBitCast(impl,to: ObjCVoidVoidFn.self)
                        _ = fn(JavascriptInterfaceObject as AnyObject,selasyn,arg,completionHandler)
                        break
                    }
                    
                } else if ( (JavascriptInterfaceObject as AnyObject).responds(to: sel)) {
                    
                    // 消息转发
                    let impl = method_getImplementation(class_getInstanceMethod((JavascriptInterfaceObject as AnyObject).classForCoder, sel)!)
                    typealias ObjCVoidVoidFn =  @convention(c) (AnyObject,Selector,Any?) -> Any?
                    let fn = unsafeBitCast(impl,to: ObjCVoidVoidFn.self)
                    let ret = fn(JavascriptInterfaceObject as AnyObject,sel,arg)
                    result["code"] = 0
                    result["data"] = ret
                    
                    
                    break
                }
                
                var js : String = error.addingPercentEncoding(withAllowedCharacters: .whitespaces) ?? ""
                
                if isDebug {
                    js = String.init(format: "window.alert(decodeURIComponent(\"%@\"));", js)
                    self.evaluateJavaScript(js, completionHandler: nil)
                }
                
                debugPrint("error: \(error.debugDescription)")
                
            }while(false)
        }

        return SKJSUtil.objToJsonString(result)
    }

    
    func evalJavascript(_ delay : Int) {
        
        let timeInterval = DispatchTime.now() + DispatchTimeInterval.milliseconds(delay)
        DispatchQueue.main.asyncAfter(deadline: timeInterval) { [self] in
            
            objc_sync_enter(self)
            
            if jsCache?.count ?? 0 > 0 {
                self.evaluateJavaScript(jsCache!, completionHandler: nil)
                self.isPending = false
                self.jsCache = ""
                lastCallTime = UInt64(Date().timeIntervalSince1970*1000)
            }
            
            objc_sync_exit(self)
        }
    }
    
}



class QSInternalApis: NSObject {
    
    weak var webview : SKBaseWKWebview?
    
    @objc func hasNativeMethod(_ args:Dictionary<AnyHashable, Any>?) -> Any? {
        return self.webview?.onMessage(args ?? [:], DSB_API.HASNATIVEMETHOD)
    }
    
    @objc func closePage(_ args:Dictionary<AnyHashable, Any>?) -> Any? {
        return self.webview?.onMessage(args ?? [:], DSB_API.CLOSEPAGE)
    }
    
    @objc func  returnValue(_ args:Dictionary<AnyHashable, Any>?) -> Any? {
        return self.webview?.onMessage(args ?? [:], DSB_API.RETURNVALUE)
    }
    
    @objc func dsinit(_ args:Dictionary<AnyHashable, Any>?) -> Any? {
        return self.webview?.onMessage(args ?? [:], DSB_API.DSINIT)
    }
    
    @objc func disableJavascriptDialogBlock(_ args:Dictionary<AnyHashable, Any>?) -> Any? {
        return self.webview?.onMessage(args ?? [:], DSB_API.DISABLESAFETYALERTBOX)
    }
}
