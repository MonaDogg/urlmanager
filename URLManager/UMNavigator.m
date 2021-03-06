//
//  UMNavigator.m
//  Demo
//
//  Created by jiajun on 9/27/13.
//  Copyright (c) 2013 SegmentFault.com. All rights reserved.
//

#import "UMNavigator.h"
#import "UMSlideNavigationController.h"
#import "UMViewController.h"
#import "UMWebViewController.h"

#import <objc/objc.h>
#import <objc/runtime.h>

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UMNavigator ()

- (void)pushToViewController:(UIViewController *)hostVC;
- (void)showViewConroller:(UIViewController *)hostVC;

@property (nonatomic, strong)   NSMutableDictionary         *config;

@end

@implementation UMNavigator

#pragma mark - private

- (void)showViewConroller:(UIViewController *)hostVC
{
    if ([[UMNavigator sharedNavigator].currentNav
         respondsToSelector:@selector(pushViewController:animated:)]) {
        [[UMNavigator sharedNavigator].currentNav pushViewController:hostVC animated:NO];
    }
    else if ([[UMNavigator sharedNavigator].currentVC.navigationController
              respondsToSelector:@selector(pushViewController:animated:)]) {
        [[UMNavigator sharedNavigator].currentVC.navigationController
         pushViewController:hostVC animated:NO];
    }
}

- (void)pushToViewController:(UIViewController *)hostVC
{
    if ([[UMNavigator sharedNavigator].currentNav
         respondsToSelector:@selector(pushViewController:animated:)]) {
        [[UMNavigator sharedNavigator].currentNav pushViewController:hostVC animated:YES];
    }
    else if ([[UMNavigator sharedNavigator].currentVC.navigationController
              respondsToSelector:@selector(pushViewController:animated:)]) {
        [[UMNavigator sharedNavigator].currentVC.navigationController
         pushViewController:hostVC animated:YES];
    }
}

+ (UMNavigator *)sharedNavigator
{
    static UMNavigator      *_sharedNavigator = nil;
    static dispatch_once_t  onceToken;
    dispatch_once(&onceToken, ^{
        _sharedNavigator = [[UMNavigator alloc] init];
    });
    return _sharedNavigator;
}

#pragma mark - Public
- (void)setViewControllerName:(NSString *)className forURL:(NSString *)url
{
    if (nil == self.config) {
        self.config = [[NSMutableDictionary alloc] init];
    }
    [self.config setValue:className forKey:url];
}

- (void)setViewController:(UIViewController *)vc forURL:(NSString *)url
{
    if (nil == self.config) {
        self.config = [[NSMutableDictionary alloc] init];
    }
    [self.config setValue:vc forKey:url];
}

- (void)setViewControllersForKeysFromDictionary:(NSDictionary *)dict
{
    if (nil == self.config) {
        self.config = [[NSMutableDictionary alloc] init];
    }
    for (NSString *key in [dict allKeys]) {
        [self.config setValue:[dict objectForKey:key] forKey:key];
    }
}

- (void)openURL:(NSURL *)url
{
    [self openURL:url withQuery:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)openURL:(NSURL *)url withQuery:(NSDictionary *)query
{
    // Host标示的ViewController
    UIViewController *hostVC = [self viewControllerForURL:url withQuery:query];

    // Path数组
    NSArray *pp = [[NSArray alloc] initWithArray:
                          [url.path componentsSeparatedByString:@"/"]];
    NSMutableArray *paths = [[NSMutableArray alloc] init];
    for (NSString *p in pp) {
        if (p && 0 < p.length) {
            [paths addObject:p];
        }
    }
    pp = nil;
    
    // 是SlideViewController，切换 URL: nav://slide/0/1
    if ([hostVC isKindOfClass:[UMSlideNavigationController class]]) {
        NSInteger section = (0 < paths.count) ? [[paths objectAtIndex:0] integerValue] : 0;
        NSInteger row     = (1 < paths.count) ? [[paths objectAtIndex:1] integerValue] : 0;
        NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
        if (section < ((UMSlideNavigationController *)hostVC).items.count
            && row < ((NSArray *)[((UMSlideNavigationController *)hostVC).items
                                  objectAtIndex:section]).count) {
            [((UMSlideNavigationController *)hostVC) showItemAtIndex:path withAnimation:YES];
        }
    }
    // 是UITabBarController，切换 URL: nav://tab/1
    else if ([hostVC isKindOfClass:[UITabBarController class]]) {
        NSInteger index = (0 < paths.count) ? [[paths objectAtIndex:0] integerValue] : 0;
        UITabBarController *tabBarVC = (UITabBarController *)hostVC;
        if (index < tabBarVC.viewControllers.count) {
            tabBarVC.selectedIndex = index;
        }
    }
    // 是UINavigationController，切换 URL://??
#warning 我还没想明白。。。
    else if ([hostVC isKindOfClass:[UINavigationController class]]) {
        ;;
    }
    // UIViewController
    else if ([hostVC isKindOfClass:[UIViewController class]]) {
        // Path第一段被识别为上一级VC
        if (paths && 0 < paths.count) {
            UIViewController *vc = [self viewControllerForURL:[NSURL URLWithString:
                                                               [NSString
                                                                stringWithFormat:@"%@://%@",
                                                                url.scheme,
                                                                [paths objectAtIndex:0]]]
                                                         withQuery:nil];
            // 上一级VC如果是Slide，则切换到相应的，然后在用nav
            if ([vc isKindOfClass:[UMSlideNavigationController class]]) {
                UMSlideNavigationController *slideVC = (UMSlideNavigationController *)vc;
                NSInteger section = (1 < paths.count) ? [[paths objectAtIndex:1] integerValue] : 0;
                NSInteger row     = (2 < paths.count) ? [[paths objectAtIndex:2] integerValue] : 0;
                NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
                
                if (section < slideVC.items.count
                    && row < ((NSArray *)[slideVC.items objectAtIndex:section]).count) {
                    [slideVC showItemAtIndex:path withAnimation:YES];
                }
                [self performSelector:@selector(showViewConroller:)
                           withObject:hostVC
                           afterDelay:.5f];
            }
            // 上一级如果是tab，切换，再nav push
            else if ([vc isKindOfClass:[UITabBarController class]]) {
                NSInteger index = (1 < paths.count) ? [[paths objectAtIndex:1] integerValue] : 0;
                UITabBarController *tabBarVC = (UITabBarController *)vc;
                if (index < tabBarVC.viewControllers.count) {
                    tabBarVC.selectedIndex = index;
                }
                [self performSelector:@selector(pushToViewController:)
                           withObject:hostVC
                           afterDelay:.3f];
            }
        }
        else {
            [self pushToViewController:hostVC];
        }
    }
}

- (UIViewController *)viewControllerForURL:(NSURL *)url withQuery:(NSDictionary *)query
{
    UIViewController* viewController = nil;
    NSString *host = url.host;
    NSString *home = [NSString stringWithFormat:@"%@://%@", url.scheme, url.host];

    if ([self URLAvailable:url]) {
        if ([[self.config objectForKey:home] isKindOfClass:[UIViewController class]]) {
            viewController = (UIViewController *)[self.config objectForKey:home];
        }
        else if ([[self.config objectForKey:host] isKindOfClass:[UIViewController class]]) {
            viewController = (UIViewController *)[self.config objectForKey:host];
        }
        else if (nil == query) {
            Class class;
            if ([self.config.allKeys containsObject:home]) {
                class = NSClassFromString([self.config objectForKey:host]);
            }
            else if ([self.config.allKeys containsObject:host]) {
                class = NSClassFromString([self.config objectForKey:host]);
            }
            viewController = (UIViewController *)[[class alloc] initWithURL:url];
        }
        else {
            Class class;
            if ([self.config.allKeys containsObject:home]) {
                class = NSClassFromString([self.config objectForKey:home]);
            }
            else if ([self.config.allKeys containsObject:host]) {
                class = NSClassFromString([self.config objectForKey:host]);
            }
            viewController = (UIViewController *)[[class alloc] initWithURL:url query:query];
        }
    }
    else if ([@"http" isEqualToString:[url scheme]]) {
        viewController = (UIViewController *)[[UMWebViewController alloc] initWithURL:url
                                                                                query:query];
    }
    
    return viewController;
}

- (BOOL)URLAvailable:(NSURL *)url
{
    return [self.config.allKeys containsObject:url.host]
    || [self.config.allKeys containsObject:[NSString stringWithFormat:@"%@://%@",
                                            url.scheme, url.host]];
}

#pragma mark - Hook

- (void)newViewDidAppear:(BOOL)animated
{
    if ([self isKindOfClass:[UINavigationController class]]) {
        [UMNavigator sharedNavigator].currentNav = (UINavigationController *)self;
    }
    else if ([self isKindOfClass:[UITabBarController class]]) {
        [UMNavigator sharedNavigator].currentTab = (UITabBarController *)self;
    }
    else if ([self isKindOfClass:[UMSlideNavigationController class]]) {
        [UMNavigator sharedNavigator].currentSlide = (UMSlideNavigationController *)self;
    }
    else if ([self isKindOfClass:[UMViewController class]]) {
        [UMNavigator sharedNavigator].currentVC = (UMViewController *)self;
    }
    
    [self performSelector:@selector(originViewDidAppear:)
               withObject:[NSNumber numberWithBool:animated]];
}

+ (void)initialize
{
    Method oriDidAppear = class_getInstanceMethod([UIViewController class],
                                                  @selector(viewDidAppear:));
    Method newDidAppear = class_getInstanceMethod([self class],
                                                  @selector(newViewDidAppear:));
    
    IMP oriDidAppearImp = method_getImplementation(oriDidAppear);
    class_addMethod([UIViewController class], @selector(originViewDidAppear:),
                    oriDidAppearImp, method_getTypeEncoding(oriDidAppear));
    
    IMP newDidAppearImp = method_getImplementation(newDidAppear);
    class_replaceMethod([UIViewController class], @selector(viewDidAppear:),
                        newDidAppearImp, method_getTypeEncoding(oriDidAppear));
}

@end
