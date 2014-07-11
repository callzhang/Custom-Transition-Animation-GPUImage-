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

static const float duration = 0.4;

@interface GPUImageAnimator ()

@property (nonatomic, strong) UIImage *sourceImage;
@property (nonatomic, strong) CIContext *CIContext;
@property (nonatomic, strong) CIFilter* blurFilter;
//@property (nonatomic, strong) GPUImageOpacityFilter* alphaFilter;
@property (nonatomic, strong) UIImageView* imageView;
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
    UIView *toView = toViewController.view;
    UIView *fromView = fromViewController.view;
    
    
    self.imageView = [[UIImageView alloc] initWithFrame:toView.frame];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.frame = container.bounds;
    self.imageView.alpha = 1;
    [container addSubview:self.imageView];
    
    if (self.type == UINavigationControllerOperationPush) {
        
        self.sourceImage = fromView.objc_snapshot;
        
        //create our blurred image
        self.CIContext = [CIContext contextWithOptions:nil];
        CIImage *inputImage = [CIImage imageWithCGImage:self.sourceImage.CGImage];
        
        //setting up Gaussian Blur (we could use one of many filters offered by Core Image)
        self.blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
        [self.blurFilter setValue:inputImage forKey:kCIInputImageKey];
        [self.blurFilter setValue:@1 forKey:@"inputRadius"];
        
        self.startTime = 0;
        self.displayLink.paused = NO;
        
        //animation
        [[self.context containerView] addSubview:toView];
        toView.alpha = 0;
        toView.transform = CGAffineTransformMakeScale(1.3, 1.3);
        [UIView animateWithDuration:0.3 delay:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            toView.alpha = 1;
            toView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [self.context completeTransition:YES];
        }];
        
    }else if(self.type == UINavigationControllerOperationPop){
        
        UIView *fromView = fromViewController.view;
        [[self.context containerView] addSubview:fromView];
        
        [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            
            fromView.alpha = 0;
            fromView.transform = CGAffineTransformMakeScale(1.3, 1.3);
            
        }completion:^(BOOL finished) {
            
            [fromView removeFromSuperview];
            [container addSubview:toViewController.view];
            [container sendSubviewToBack:toViewController.view];
            
        }];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            self.sourceImage = toView.objc_snapshot;
            
            
            [self triggerRenderOfNextFrame];
            self.startTime = 0;
            self.displayLink.paused = NO;
        });
        
    }
    
}

- (void)triggerRenderOfNextFrame
{
    //[self.blurImage processImage];
    
    
    CIImage *result = [self.blurFilter valueForKey:kCIOutputImageKey];
    //CIGaussianBlur has a tendency to shrink the image a little, this ensures it matches up exactly to the bounds of our original image
    CGImageRef cgImage = [self.CIContext createCGImage:result fromRect:self.imageView.frame];
    //add our blurred image to the scrollview
    self.imageView.image = [UIImage imageWithCGImage:cgImage];
}

- (void)startInteractiveTransition:(id <UIViewControllerContextTransitioning>)transitionContext {
    [self animateTransition:transitionContext];
}

- (void)updateFrame:(CADisplayLink*)link
{
    [self updateProgress:link];
    
    [self.blurFilter setValue:[NSNumber numberWithFloat:1 + self.progress * 40] forKey:@"inputRadius"];
    [self triggerRenderOfNextFrame];
    
    if (self.interactive) {
        return;
    }
    if (self.type == UINavigationControllerOperationPush && self.progress == 1) {
        
        self.displayLink.paused = YES;
        
    }else if (self.type == UINavigationControllerOperationPop && self.progress == 0){
        
        self.displayLink.paused = YES;
        [self.context completeTransition:YES];
        self.imageView.alpha = 0;
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

- (void)finishTransition
{
    self.displayLink.paused = YES;
    if (self.interactive) {
        [self.context finishInteractiveTransition];
    }
    
}

- (void)cancelInteractiveTransition
{
    // TODO
}

@end