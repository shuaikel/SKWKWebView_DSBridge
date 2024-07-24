//
//  ViewController.swift
//  SKWKWebViewDSBridge
//
//  Created by shuaike on 07/22/2024.
//  Copyright (c) 2024 shuaike. All rights reserved.
//

import UIKit
import SKWKWebViewDSBridge
import Foundation

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
       let classMethods = getClassMethods(of: MyClass.self)
       print(classMethods)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

class MyClass {
    class func classMethod1() {}
    class func classMethod2() {}
}
 
func getClassMethods(of classType: AnyClass) -> [String] {
    var classMethods = [String]()
    let mirror = Mirror(reflecting: classType)
    
    if let children = mirror.children.filter({ $0.value is Selector }) as? [Mirror.Child]{
        for child in children {
            if let methodName = child.label {
                classMethods.append(methodName)
            }
        }
    }
    
    return classMethods
}

