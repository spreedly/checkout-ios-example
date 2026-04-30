//
//  SceneDelegate.m
//  SpreedlySDKExampleObjectiveC
//
//  Created by Vinay Naikade on 12/08/25.
//

#import "SceneDelegate.h"
#import "ViewController.h"
#import "SpreedlyConfigManager.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <SpreedlyBraintree/SpreedlyBraintree-Swift.h>

@interface SceneDelegate ()

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    
    if ([scene isKindOfClass:[UIWindowScene class]]) {
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
        
        // Setup SpreedlyConfigManager
        [SpreedlyConfigManager setup];
        
        // Create the main view controller
        ViewController *mainViewController = [[ViewController alloc] init];
        
        // Create navigation controller
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:mainViewController];
        
        // Wrap navigation controller in secure protection for screen prevention
        UIViewController *secureRootViewController = [navigationController wrapInSecureViewControllerWithPlaceholderText:@""];
        
        // Set as root view controller
        self.window.rootViewController = secureRootViewController;
        
        // Make window visible
        [self.window makeKeyAndVisible];
    }
}


- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    NSURL *url = URLContexts.allObjects.firstObject.URL;
    if (!url) return;
    if ([BraintreeURLHandlerObjC handleOpenWithUrl:url]) return;
    BOOL isSpreedlyURL = [[Spreedly shared] handleOffsiteReturnWithUrl:url];
    if (!isSpreedlyURL) {
        // Handle other custom URL navigations
    }
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}


@end
