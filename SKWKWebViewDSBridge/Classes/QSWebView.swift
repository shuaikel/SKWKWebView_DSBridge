//
//  SKJSUtil.swift
//  SKWebViewLib
//
//  Created by 帅科 on 2021/8/5.
//

import Foundation
import WebKit

public enum DocumentReadStateType : String{
    case loading = ""
    case interactive = "interactive"
    case complete = "complete"
}

let kDocumentStateHandlerName = "documentStateHandler"

open class QSWebView : SKBaseWKWebview {
    
    /// 网页DocumentReadyState
    public var documentStateBlock : ((DocumentReadStateType)->())?
    
    /// 网页ScriptHandler事件回调
    public var scriptHandlerBlock : ((QSWebView,WKScriptMessage)->())?
    
    private var scriptHandler : QSWeakScriptMessageHandler?
    
    @objc public var temp : String?
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        
        // config configuration
        configuration.allowsInlineMediaPlayback = true
        configuration.suppressesIncrementalRendering = false
        configuration.allowsAirPlayForMediaPlayback = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes.init()
        } else {
            // Fallback on earlier versions
        };
        
        // inject default js  configuration
        let documentScript = WKUserScript(source: "window.document.onreadystatechange= (state)=>{window.webkit.messageHandlers.\(kDocumentStateHandlerName).postMessage(document.readyState)};", injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(documentScript)
        
        //
        let bundle : Bundle = Bundle.init(for: QSWebView.self)
        let url = bundle.url(forResource: "SKWebViewLib", withExtension: "bundle")
        let qsBundle : Bundle = Bundle.init(url: url!)!;
        let jsPath = qsBundle.path(forResource: "dsBridge", ofType: "js")
        do {
            let jsStr = try String(contentsOfFile: jsPath!,encoding: .utf8)
            let defautJsScript = WKUserScript(source: jsStr, injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: false)
            configuration.userContentController.addUserScript(defautJsScript)
        } catch {
            debugPrint("inject dsBridge fail : \(error.localizedDescription)")
        }

        //
        let windowScript = WKUserScript(source: "window.UniqueJSBridge=window.dsBridge;", injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(windowScript)
        
        // 初始化
        super.init(frame: frame, configuration: configuration)
        
        self.scriptHandler = QSWeakScriptMessageHandler.init(self)
        configuration.userContentController.add(self.scriptHandler!, name: kDocumentStateHandlerName)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension QSWebView : WKScriptMessageHandler{
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == kDocumentStateHandlerName {
            let state = DocumentReadStateType.init(rawValue: message.body as? String ?? "") ?? .loading
            documentStateBlock?(state)
        }
        scriptHandlerBlock?(self,message)
    }
}


class QSWeakScriptMessageHandler : NSObject,WKScriptMessageHandler {
    
    private weak var weakscriptDelegate : WKScriptMessageHandler?
    
    convenience init<T:WKScriptMessageHandler>(_ handler:T) {
        self.init()
        weakscriptDelegate = handler
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if self.weakscriptDelegate != nil {
            self.weakscriptDelegate!.userContentController(userContentController, didReceive: message)
        }
    }
}

