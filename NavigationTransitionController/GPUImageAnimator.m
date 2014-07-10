//
//  GPUImageAnimator.m
//  NavigationTransitionTest
//
//  Created by Chris Eidhof on 9/28/13.
//  Copyright (c) 2013 Chris Eidhof. All rights reserved.
//

#import "GPUImageAnimator.h"
#import "GPUImage.h"
#import "GPUImagePicture.h"
#import "GPUImagePixellateFilter.h"
#import "UIView+OBJSnapshot.h"
#import "GPUImageView.h"

static const float duration = 0.3;

@interface GPUImageAnimator ()

@property (nonatomic, strong) GPUImagePicture* blurImage;
@property (nonatomic, strong) GPUImageiOSBlurFilter* blurFilter;
//@property (nonatomic, strong) GPUImageOpacityFilter* alphaFilter;
@property (nonatomic, strong) GPUImageView* imageView;
@property (nonatomic, strong) id <UIViewControllerContextTransitioning> context;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic, strong) CADisplayLink* displayLink;
@end

@implementation GPUImageAnimator

- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    
    return self;
}

- (void)setup
{
    self.imageView = [[GPUImageView alloc] init];
    //self.imageView.alpha = 0;
    self.imageView.opaque = NO;
    
    self.blurFilter = [[GPUImageiOSBlurFilter alloc] init];
    self.blurFilter.blurRadiusInPixels = 1;
    self.blurFilter.saturation = 1;
    self.blurFilter.rangeReductionFactor = 0;
    self.blurFilter.downsampling = 1;
    [self.blurFilter addTarget:self.imageView];
    
//    self.alphaFilter = [GPUImageOpacityFilter new];
//    self.alphaFilter.opacity = 0;
//    [self.blurFilter addTarget:self.alphaFilter];
//    [self.alphaFilter addTarget:self.imageView];
    
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.displayLink.paused = YES;
}


- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    return duration;
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext
{
    self.context = transitionContext;
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIView* container = [transitionContext containerView];
    
    self.imageView.frame = container.bounds;
    [container addSubview:self.imageView];
    
    if (self.type == UINavigationControllerOperationPush) {
        
        self.blurImage = [[GPUImagePicture alloc] initWithImage:fromViewController.view.objc_snapshot];
        [self.blurImage addTarget:self.blurFilter];
        
        [self triggerRenderOfNextFrame];
        
        self.imageView.alpha = 1;
        self.startTime = 0;
        self.displayLink.paused = NO;
        
    }else if(self.type == UINavigationControllerOperationPop){
        
        UIView *toView = toViewController.view;
        [[self.context containerView] addSubview:toView];
        [self.context.containerView bringSubviewToFront:toView];
        
        [UIView animateWithDuration:0.3 animations:^{
            
            toView.alpha = 0;
            toView.transform = CGAffineTransformMakeScale(1.3, 1.3);
            
        }completion:^(BOOL finished) {
            [[self.context containerView] sendSubviewToBack:toView];
            
            self.startTime = 0;
            self.displayLink.paused = NO;
        }];

        
    }
    
    
    
}

- (void)triggerRenderOfNextFrame
{
    [self.blurImage processImage];
}

- (void)startInteractiveTransition:(id <UIViewControllerContextTransitioning>)transitionContext {
    [self animateTransition:transitionContext];
}

- (void)updateFrame:(CADisplayLink*)link
{
    [self updateProgress:link];
    //self.alphaFilter.opacity = self.progress;
    self.blurFilter.downsampling = 1 + self.progress * 7;
    self.blurFilter.blurRadiusInPixels = 1+ self.progress * 8;
    [self triggerRenderOfNextFrame];
    
    if (self.interactive) {
        return;
    }
    if (self.type == UINavigationControllerOperationPush && self.progress == 1) {
        [self finishInteractiveTransition];
    }else if (self.type == UINavigationControllerOperationPop && self.progress == 0){
        
    }
}

//update progress
- (void)updateProgress:(CADisplayLink*)link
{
    if (self.interactive) return;
    
    if (self.startTime == 0) {
        self.startTime = link.timestamp;
    }
    
    
    float progress = MAX(0, MIN((link.timestamp - self.startTime) / duration, 1));
    
    if (self.type == UINavigationControllerOperationPush) {
        self.progress = progress;
    }else if (self.type == UINavigationControllerOperationPop){
        self.progress = 1- progress;
    }
}

- (void)setProgress:(CGFloat)progress
{
    _progress = progress;
    if (self.interactive) {
        [self.context updateInteractiveTransition:progress];
    }
}

- (void)finishInteractiveTransition
{
    self.displayLink.paused = YES;
    if (self.interactive) {
        [self.context finishInteractiveTransition];
    }
    
    
    //uiview
    if (self.type == UINavigationControllerOperationPush) {
        
        UIView *toView = [self.context viewControllerForKey:UITransitionContextToViewControllerKey].view;
        [[self.context containerView] addSubview:toView];
        toView.alpha = 0;
        toView.transform = CGAffineTransformMakeScale(1.3, 1.3);
        [self.context.containerView bringSubviewToFront:toView];
        [UIView animateWithDuration:0.3 animations:^{
            toView.alpha = 1;
            toView.transform = CGAffineTransformIdentity;
        }completion:^(BOOL finished) {
            
            [self.context completeTransition:YES];
        }];
        
    }
    
}

- (void)cancelInteractiveTransition
{
    // TODO
}

@end