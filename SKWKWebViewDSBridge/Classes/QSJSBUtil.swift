//
//  SKJSUtil.swift
//  SKWebViewLib
//
//  Created by 帅科 on 2021/8/5.
//

import UIKit

enum DSB_API : Int {
 case HASNATIVEMETHOD = 1
 case CLOSEPAGE
 case RETURNVALUE
 case DSINIT
 case DISABLESAFETYALERTBOX
}


open class SKJSUtil: NSObject {
    
    public override init() {
        super.init()
//        test
//        let obj = ["a":[1,2,4],"b":"b","c":["c1":"c1","c2":2]] as [String : Any]
//        
//        
//        let objtostr = SKJSUtil.objToJsonString(obj) as? String
//        
//        let parseNameSpace = SKJSUtil.parseNamespace("device.appinfo")
//        
//        let objfromStr = SKJSUtil.jsonStringToObject(objtostr) as? [String:Any]
//        
//        debugPrint("objtostr\(objtostr)===parseNameSpace:\(parseNameSpace)===\(objfromStr)")
//        
//        let result2 = SKJSUtil.methodByNameArg(10, selName: "app", className: SKJSUtil.self)
//        
//        
//        let method1 = SKJSUtil.methodByNameArg(1, selName: "testMethod", className: SKJSUtil.self)
//        let method2 = SKJSUtil.methodByNameArg(2, selName: "testMethod", className: SKJSUtil.self)
//        
        
//        debugPrint("SKJSUtil method1:\(method1)====\(method2)")
//
//
//        let obj2 = ["data":[],"resumeParam":[]]
//        let objtostr2 = SKJSUtil.objToJsonString(obj2) as? String
//
//        debugPrint("objtostr2:\(objtostr2)")
//
//
//        // swift 消息转发
//        let selasyn = #selector(testMethod(_:_:))
////        let impl = class_getMethodImplementation( (self as AnyObject).classForCoder, selasyn)
//
//        let impl = method_getImplementation(class_getInstanceMethod(self.classForCoder, selasyn)!)
//
//        typealias ObjCVoidVoidFn =  @convention(c) (AnyObject,Selector,Any,QSOBJCCallHandler) -> Void
//        let fn = unsafeBitCast(impl,to: ObjCVoidVoidFn.self)
//
//        let completeHandler = {(res:Bool) in
//            debugPrint("objc sender :\(res)")
//        }
//        fn(self,selasyn,completeHandler,completeHandler)
    }
    
    
    typealias QSOBJCCallHandler = ((_ res:Bool)->Void)
    
    @objc func testMethod(_ param:Any?, _ param2:QSOBJCCallHandler?) {
        debugPrint("12423423:")
     
        (param as! QSOBJCCallHandler)(true)
        
        param2!(false)
    
    }
    
    @objc func testMethodW()  {
        
    }
    
    @objc static func objToJsonString(_ dict:Any?) -> String {
        
        if dict == nil {
            return "{}"
        }
        
        if JSONSerialization.isValidJSONObject(dict!) == false {
            return "{}"
        }
    
        do{
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions.fragmentsAllowed)
            let jsonString = String.init(data: jsonData, encoding: .utf8) ?? "{}"
            return jsonString
        }catch{
            debugPrint("解析出错了:\(error)")
        }
        return "{}"
        
    }
    
    
    @objc static func jsonStringToObject(_ jsonString: String?) -> Dictionary<AnyHashable, Any>? {

        guard jsonString?.count ?? 0 > 0 else {
            return nil
        }
        
        let jsonData = jsonString?.data(using: .utf8)
        
        do {
            let dic = try JSONSerialization.jsonObject(with: jsonData!, options: .mutableContainers)
            return dic as? Dictionary<AnyHashable, Any>
        } catch  {
            debugPrint("jsonStringToObject JSONSerializationError:\(error)")
        }
        return nil
    }
    
    
    @objc static func methodByNameArg(_ argNum:Int ,selName : String, className:AnyClass) -> String? {
        
        var result : String?
        let arr = allMethodFromClass(className)
        if arr?.count == 0 {
            return result
        }
        for (_ ,method) in arr!.enumerated() {
            let tmpArr = method.components(separatedBy: ":")
            let range = method.range(of: ":")
            
            if range?.isEmpty == false {
                let methodName = method[..<range!.lowerBound]
                if methodName == selName && (tmpArr.count == argNum + 1) {
                     result = method
                    return result
                }
            }
        }
        return result
    }

    
    @objc public static func allMethodFromClass(_ className:AnyClass) -> [String]? {
    
        var resultArray = [String]()
        var tempClass : AnyClass? = className
        
        while tempClass != nil {
            var outCount:UInt32 = 0
            let methods: UnsafeMutablePointer<Method>? =  class_copyMethodList(tempClass, &outCount)
            let count:Int = Int(outCount)
            
            for i in 0...(count-1) {
                let name1 :Selector = method_getName(methods![i])
                let selName = sel_getName(name1)
                let strName = String.init(cString: selName)
                resultArray.append(strName)
            }
            
            free(methods)
            let cls: AnyClass? = class_getSuperclass(tempClass)
            tempClass = cls == NSObject.self ? nil : cls
        }
        
        return resultArray
    }
    
    @objc static func parseNamespace(_ method:String) -> [String]? {
        
        var namespace = ""
        guard let range = method.range(of: ".") else {
            return [namespace,method]
        }
        
        namespace = String(method[..<range.lowerBound])
        let realMethod : String = String(method[range.upperBound...])
        
        return [namespace,realMethod]
    }
}

