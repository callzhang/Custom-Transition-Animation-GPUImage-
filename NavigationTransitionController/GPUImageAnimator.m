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

static const float duration = 2;

@interface GPUImageAnimator ()

@property (nonatomic, strong) GPUImagePicture* blurImage;
@property (nonatomic, strong) GPUImageiOSBlurFilter* blurFilter;
@property (nonatomic, strong) GPUImageOpacityFilter* alphaFilter;
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
    
    self.alphaFilter = [GPUImageOpacityFilter new];
    self.alphaFilter.opacity = 1;
    [self.blurFilter addTarget:self.alphaFilter];
    [self.alphaFilter addTarget:self.imageView];
    
    
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
    //toView
    UIView* toView = toViewController.view;
    UIView* fromView = fromViewController.view;
    UIView* container = [transitionContext containerView];
    [container addSubview:toView];
    toView.alpha = 0;
    toView.transform = CGAffineTransformMakeScale(1.3, 1.3);
    
    self.imageView.frame = container.bounds;
    [container addSubview:self.imageView];
    //[container sendSubviewToBack:self.imageView];//GPUImage need to be on top
    
    self.blurImage = [[GPUImagePicture alloc] initWithImage:fromView.objc_snapshot];
    [self.blurImage addTarget:self.blurFilter];
    
    [self triggerRenderOfNextFrame];
    
    self.imageView.alpha = 1;
    self.startTime = 0;
    self.displayLink.paused = NO;
    
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
    self.blurFilter.blurRadiusInPixels = self.progress * self.progress * 20;
    [self triggerRenderOfNextFrame];
    
    if (self.progress == 1 && !self.interactive) {
        [self finishInteractiveTransition];
    }
}

//update progress
- (void)updateProgress:(CADisplayLink*)link
{
    if (self.interactive) return;
    
    if (self.startTime == 0) {
        self.startTime = link.timestamp;
    }
    self.progress = MAX(0, MIN((link.timestamp - self.startTime) / duration, 1));
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
    
    UIView *toView = [self.context viewControllerForKey:UITransitionContextToViewControllerKey].view;
    [self.context.containerView bringSubviewToFront:toView];
    [UIView animateWithDuration:0.3 animations:^{
        toView.alpha = 1;
        toView.transform = CGAffineTransformIdentity;
    }completion:^(BOOL finished) {
        
        [self.context completeTransition:YES];
    }];
}

- (void)cancelInteractiveTransition
{
    // TODO
}

@end