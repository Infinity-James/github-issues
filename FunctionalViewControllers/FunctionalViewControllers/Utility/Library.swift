//
//  ViewController.swift
//  FunctionalViewControllers
//
//  Created by Chris Eidhof on 03/09/14.
//  Copyright (c) 2014 Chris Eidhof. All rights reserved.
//

import UIKit

//	MARK: Box Class

/**
	By boxing values we can treat structs and classes the same.
 */

public class Box<T> {
    public let unbox: T
    public init(_ value: T) { self.unbox = value }
}


//	MARK: Public Functions

/**
	Maps a Screen with a callback that takes A to a Screen with a callback that takes B.

	:param:	vc		The Screen to be mapped.
	:param:	f		The function responsible for mapping A to B.

	:returns:		A Screen with a callback that takes B mapped from the given vc.
*/
public func map<A,B>(vc: Screen<A>, f: A -> B) -> Screen<B> {
    return Screen { callback in
        return vc.run { y in
            callback(f(y))
        }
    }
}


public func map<A,B>(nc: NavigationController<A>, f: A -> B) -> NavigationController<B> {
    return NavigationController { callback in
        return nc.build { (y, nc) in
            callback(f(y), nc)
        }
    }
}

extension UIViewController {
    public func presentModal<A>(screen: NavigationController<A>, cancellable: Bool, callback: A -> ()) {
        let vc = screen.build { [unowned self] x, nc in
            callback(x)
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        vc.modalTransitionStyle = UIModalTransitionStyle.CoverVertical
        if cancellable {
            let cancelButton = BarButton(title: BarButtonTitle.SystemItem(UIBarButtonSystemItem.Cancel), callback: { _ in
                self.dismissViewControllerAnimated(true, completion: nil)
            })
            let rootVC = vc.viewControllers[0] as! UIViewController
            rootVC.setLeftBarButton(cancelButton)
        }
        presentViewController(vc, animated: true, completion: nil)
    }
}

//	MARK: Screen Struct

/**
	A screen object capable of building a UIViewController object.
 */

public struct Screen<A> {
	/**	A block which builds a UIViewController from this screen.	*/
    private let build: (A -> ()) -> UIViewController
	/**	A navigation item attached to the UIViewController built form this screen.	*/
    public var navigationItem: NavigationItem
	
	/**
		Initialises this screen object with a function that will build the UIViewController.
		
		:param:	build	A function capable of build the UIViewController this Screen represents.
	
		:returns:	An initialised Screen object.
	 */
    public init(_ build: (A -> ()) -> UIViewController) {
        self.init(defaultNavigationItem, build)
    }

	/**
		Initialises this screen object with a function that will build the UIViewController and a navigation item..
		
		:param:	navigationItem	An item attached to the built UIViewController.
		:param:	build			A function capable of build the UIViewController this Screen represents.
		
		:returns:	An initialised Screen object.
	 */
    public init(_ navigationItem: NavigationItem, _ build: (A -> ()) -> UIViewController) {
        self.build = build
        self.navigationItem = navigationItem
    }

	/**
		Builds the UIViewController from this Screen.
		
		:param:	f		The callback function to pass to the created UIViewController.
	
		:returns:		The UIViewController this Screen represents.
	 */
    public func run(f: A -> ()) -> UIViewController {
        let vc = build(f)
        vc.applyNavigationItem(navigationItem)
        return vc
     }
}

func ignore<A>(_: A, _: UINavigationController) { }

public struct NavigationController<A> {
    public let build: (f: (A, UINavigationController) -> ()) -> UINavigationController

    public func run() -> UINavigationController {
       return build { _ in }
    }
}

public func navigationController<A>(vc: Screen<A>) -> NavigationController<A> {
    return NavigationController { callback in
        let navController = UINavigationController()
        let rootController = vc.run { callback($0, navController) }
        navController.viewControllers = [rootController]
        return navController
    }
}

infix operator >>> { associativity left }

public func >>><A,B>(l: NavigationController<A>, r: A -> Screen<B>) -> NavigationController<B> {
    return NavigationController { (callback) -> UINavigationController in
        let nc = l.build { a, nc in
            let rvc = r(a).run { c in
                callback(c, nc)
            }
            nc.pushViewController(rvc, animated: true)

        }
        return nc
    }
}

public func textViewController(string: String) -> Screen<()> {
    return Screen { _ in
        var tv = TextViewController()
        tv.textView.text = string
        return tv
    }
}

class TextViewController: UIViewController {
    var textView: UITextView = {
        var tv = UITextView()
        tv.editable = false
        return tv
    }()
    
    override func viewDidLoad() {
        view.addSubview(textView)
        textView.frame = view.bounds
    }
}

public func modalButton<A>(title: BarButtonTitle, nc: NavigationController<A>, callback: A -> ()) -> BarButton {
    return BarButton(title: title, callback: { context in
        context.viewController.presentModal(nc, cancellable: true, callback: callback)
    })
}

public func add<A>(screen: Screen<A>, callback: A -> ()) -> BarButton {
    return modalButton(.SystemItem(.Add), navigationController(screen), callback)
}

// TODO: is this a good name?
infix operator <|> { associativity left }

public func <|><A,B>(screen: A -> Screen<B>, button: A -> BarButton) -> A -> Screen<B> {
    return { a in
        var screen = screen(a)
        screen.navigationItem.rightBarButtonItem = button(a)
        return screen
    }
}