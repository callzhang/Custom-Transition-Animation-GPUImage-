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

//@property (nonatomic, strong) GPUImageDissolveBlendFilter* blend;
@property (nonatomic, strong) GPUImagePicture* sourceImage;
@property (nonatomic, strong) GPUImageiOSBlurFilter* sourceBlurFilter;
//@property (nonatomic, strong) GPUImagePicture* targetImage;
//@property (nonatomic, strong) GPUImageiOSBlurFilter* targetPixellateFilter;
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
    
//    self.blend = [[GPUImageDissolveBlendFilter alloc] init];
//    self.blend.mix = 0;
//    [self.blend addTarget:self.imageView];
    
    
    self.sourceBlurFilter = [[GPUImageiOSBlurFilter alloc] init];
    self.sourceBlurFilter.blurRadiusInPixels = 0;
    
    //self.targetPixellateFilter = [[GPUImageiOSBlurFilter alloc] init];
    //self.targetPixellateFilter.blurRadiusInPixels = 20;
    
    //[self.sourcePixellateFilter addTarget:self.blend];
    //[self.targetPixellateFilter addTarget:self.blend];
    [self.sourceBlurFilter addTarget:self.imageView];
    
    
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
    toView.transform = CGAffineTransformMakeScale(1.1, 1.1);
    
    self.imageView.frame = container.bounds;
    [container addSubview:self.imageView];
    //[container sendSubviewToBack:self.imageView];
    
    self.sourceImage = [[GPUImagePicture alloc] initWithImage:fromView.objc_snapshot];
    [self.sourceImage addTarget:self.sourceBlurFilter];
    
    //self.targetImage = [[GPUImagePicture alloc] initWithImage:toView.objc_snapshot];
    //[self.targetImage addTarget:self.targetPixellateFilter];
    
    [self triggerRenderOfNextFrame];
    
    
    self.imageView.alpha = 1;
    self.startTime = 0;
    self.displayLink.paused = NO;
    
}

- (void)triggerRenderOfNextFrame
{
    [self.sourceImage processImage];
    //[self.targetImage processImage];
}

- (void)startInteractiveTransition:(id <UIViewControllerContextTransitioning>)transitionContext {
    [self animateTransition:transitionContext];
}

- (void)updateFrame:(CADisplayLink*)link
{
    [self updateProgress:link];
    //self.blend.mix = self.progress;
    self.sourceBlurFilter.blurRadiusInPixels = self.progress * 10;
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