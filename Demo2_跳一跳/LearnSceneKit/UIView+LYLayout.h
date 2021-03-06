//
//  UIView+LYLayout.h
//  LYFrameworkDemo
//
//  Created by loyinglin on 16/10/11.
//  Copyright © 2016年 loyinglin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (LYLayout)

@property (nonatomic) CGFloat left;        ///< Shortcut for frame.origin.x.
@property (nonatomic) CGFloat top;         ///< Shortcut for frame.origin.y
@property (nonatomic) CGFloat right;       ///< Shortcut for frame.origin.x + frame.size.width
@property (nonatomic) CGFloat bottom;      ///< Shortcut for frame.origin.y + frame.size.height
@property (nonatomic) CGFloat width;       ///< Shortcut for frame.size.width.
@property (nonatomic) CGFloat height;      ///< Shortcut for frame.size.height.
@property (nonatomic) CGFloat centerX;     ///< Shortcut for center.x
@property (nonatomic) CGFloat centerY;     ///< Shortcut for center.y
@property (nonatomic) CGPoint origin;      ///< Shortcut for frame.origin.
@property (nonatomic) CGSize  size;        ///< Shortcut for frame.size.

@property (nonatomic) CGFloat ssCornerRadius;

- (void)setRoundCornerWithadius:(CGFloat)radius rect:(CGRect)rect corners:(UIRectCorner)corners;

- (void)removeAllSubviews;

@end


