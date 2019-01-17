//
//  GameViewController.m
//  LearnSceneKit
//
//  Created by loyinglin on 2018/12/31.
//  Reference https://www.jianshu.com/p/37908e6ec7b8
//  Copyright © 2018 ByteDance. All rights reserved.
//

#import "GameViewController.h"
#import "UIView+LYLayout.h"

#define kMaxPressDuration 2.5
#define kMaxPlatformRadius 8
#define kMinPlatformRadius 5
#define kGravityValue (-50)

typedef NS_ENUM(NSUInteger, LYRoleTypeMask) {
    LYRoleTypeMaskNone = 0,
    LYRoleTypeMaskFloor = 1 << 0,
    LYRoleTypeMaskPlatform = 1 << 1,
    LYRoleTypeMaskJumper = 1 << 2,
    LYRoleTypeMaskOldPlatform = 1 << 3,
};

typedef NS_ENUM(NSUInteger, LYGameStatus) {
    LYGameStatusReady,
    LYGameStatusRunning,
};

@interface GameViewController () <SCNPhysicsContactDelegate>
@property (strong, nonatomic) IBOutlet UIView *gameContainerView;
@property (nonatomic, strong) IBOutlet UILabel *gameStatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *gameScoreLabel;

@property(nonatomic, strong) SCNView *sceneView;
@property(nonatomic, strong) SCNScene *scene;
@property(nonatomic, strong) SCNNode *floor;
@property(nonatomic, strong) SCNNode *lastPlatform, *platform, *nextPlatform;
@property(nonatomic, strong) SCNNode *jumper;
@property(nonatomic, strong) SCNNode *camera, *light;
@property(nonatomic) NSInteger score;
@end

@implementation GameViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initGame];
}


#pragma mark - init

#pragma mark - gameLogic

#pragma mark - node

-(void)addFirstPlatform {
    self.platform = [SCNNode node];
    self.platform.geometry = [SCNCylinder cylinderWithRadius:5 height:2];
    self.platform.geometry.firstMaterial.diffuse.contents = UIColor.whiteColor;
    
    SCNPhysicsBody *body = [SCNPhysicsBody staticBody];
    body.restitution = 0;
    body.friction = 1;
    body.damping = 0;
    body.categoryBitMask = LYRoleTypeMaskPlatform;
    body.collisionBitMask = LYRoleTypeMaskJumper;
    self.platform.physicsBody = body;
    
    self.platform.position = SCNVector3Make(0, 1, 0);
    [self.scene.rootNode addChildNode:self.platform];
}

#pragma mark - ui action

- (IBAction)startGame {
    [self.view sendSubviewToBack:self.gameContainerView];
    self.score = 0;
    [self.sceneView removeFromSuperview];
    self.sceneView = nil;
    self.scene = nil;
    self.floor = nil;
    self.lastPlatform = nil;
    self.platform = nil;
    self.nextPlatform = nil;
    self.jumper = nil;
    self.camera = nil;
    self.light = nil;
    
    [self initGame];
}


-(void)accumulateStrength:(UILongPressGestureRecognizer *)recognizer {
    static NSDate *startDate;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        startDate = [NSDate date];
        [self updateStrengthStatus];
    }else if(recognizer.state == UIGestureRecognizerStateEnded) {
        NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:startDate];
        [self jumpWithPower:MIN(timeInterval, kMaxPressDuration)];
    }
}

#pragma mark - delegate

#pragma mark - private


-(void)updateStrengthStatus {
    SCNAction *action = [SCNAction customActionWithDuration:kMaxPressDuration actionBlock:^(SCNNode * node, CGFloat elapsedTime) {
        CGFloat percentage = elapsedTime / kMaxPressDuration;
        self.jumper.geometry.firstMaterial.diffuse.contents = [UIColor colorWithRed:1 green:1 - percentage blue:1 - percentage alpha:1];
    }];
    [self.jumper runAction:action];
}

-(void)jumpWithPower:(double)power {
    power *= 30;
    SCNVector3 platformPosition = self.nextPlatform.presentationNode.position;
    SCNVector3 jumperPosition = self.jumper.presentationNode.position;
    double subtractionX = platformPosition.x - jumperPosition.x;
    double subtractionZ = platformPosition.z - jumperPosition.z;
    double proportion = fabs(subtractionX / subtractionZ);
    double x = sqrt(1 / (pow(proportion, 2) + 1)) * proportion;
    double z = sqrt(1 / (pow(proportion, 2) + 1));
    x *= subtractionX < 0 ? -1 : 1;
    z *= subtractionZ < 0 ? -1 : 1;
    SCNVector3 force = SCNVector3Make(x * power, 20, z * power); // 力包括三个方向，高度y固定为20，由jumper和platform的位置算出x、z的朝向；核心是运动速度固定为1
    [self.jumper.physicsBody applyForce:force impulse:YES];
}

-(void)jumpCompleted {
    self.score++;
    self.lastPlatform = self.platform;
    self.platform = self.nextPlatform;
    [self moveCameraToCurrentPlatform];
    [self createNextPlatform];
    
    self.jumper.geometry.firstMaterial.diffuse.contents = UIColor.whiteColor;
    [self.jumper removeAllActions];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.gameScoreLabel setText:[NSString stringWithFormat:@"当前分数:%d",(int)self.score]];
    });
}

-(void)moveCameraToCurrentPlatform {
    SCNVector3 position = self.platform.presentationNode.position;
    
    position.x += 20;
    position.y += 30;
    position.z += 20;
    SCNAction *move = [SCNAction moveTo:position duration:0.5];
    [self.camera runAction:move];
}

-(void)createNextPlatform {
    self.nextPlatform = [SCNNode node];
    
    //随机大小
    int cylinderRadius = (arc4random() % kMinPlatformRadius) + (kMaxPlatformRadius - kMinPlatformRadius) + kMinPlatformRadius / 2.0;
    SCNCylinder *cylinder = [SCNCylinder cylinderWithRadius:cylinderRadius height:2];
    //随机颜色
    CGFloat r = (arc4random() % 255) / 255.0;
    CGFloat g = (arc4random() % 255) / 255.0;
    CGFloat b = (arc4random() % 255) / 255.0;
    cylinder.firstMaterial.diffuse.contents = [UIColor colorWithRed:r green:g blue:b alpha:1];
    self.nextPlatform.geometry = cylinder;


    SCNPhysicsBody *body = [SCNPhysicsBody dynamicBody];
    body.mass = 100;
    body.restitution = 1;
    body.friction = 1;
    body.damping = 0;
    body.allowsResting = YES;
    body.categoryBitMask = LYRoleTypeMaskPlatform;
    body.collisionBitMask = LYRoleTypeMaskJumper|LYRoleTypeMaskFloor|LYRoleTypeMaskOldPlatform|LYRoleTypeMaskPlatform;
    body.contactTestBitMask = LYRoleTypeMaskJumper;
    self.nextPlatform.physicsBody = body;
    
    SCNVector3 position = self.platform.presentationNode.position;
    int xDistance = (arc4random() % ( kMaxPlatformRadius * 3 - 1))+1;
    
    double lastRadius = ((SCNCylinder *)self.platform.geometry).radius;
    double radius = ((SCNCylinder *)self.nextPlatform.geometry).radius;
    double maxDistance = sqrt(pow(kMaxPlatformRadius *  3, 2)-pow(xDistance, 2));
    double minDistance = (xDistance>lastRadius+radius)?xDistance:sqrt(pow(lastRadius+radius, 2)-pow(xDistance, 2));
    double zDistance = (((double) rand() / RAND_MAX) * (maxDistance-minDistance)) + minDistance;
     
    position.z -= zDistance;
    position.x -= xDistance;
    position.y += 5;
    //随机位置
    self.nextPlatform.position = position;

    [self.scene.rootNode addChildNode:self.nextPlatform];
}

-(void)gameDidOver {
    UILabel *label = [[UILabel alloc] initWithFrame:self.gameContainerView.bounds];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1];
    label.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    label.text = @"游戏结束";
    label.font = [UIFont systemFontOfSize:22];
    label.textAlignment = NSTextAlignmentCenter;
    [self.gameContainerView addSubview:label];
    
    self.gameContainerView.userInteractionEnabled = NO;
}

#pragma mark SCNPhysicsContactDelegate

- (void)physicsWorld:(SCNPhysicsWorld *)world didBeginContact:(SCNPhysicsContact *)contact{
    SCNPhysicsBody *bodyA = contact.nodeA.physicsBody;
    SCNPhysicsBody *bodyB = contact.nodeB.physicsBody;

    if (bodyA.categoryBitMask==LYRoleTypeMaskJumper) {
        if (bodyB.categoryBitMask==LYRoleTypeMaskFloor) {
            bodyB.contactTestBitMask = LYRoleTypeMaskNone;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self gameDidOver];
            });
        }else if (bodyB.categoryBitMask==LYRoleTypeMaskPlatform) {
            bodyB.contactTestBitMask = LYRoleTypeMaskNone;
//            bodyB.categoryBitMask = LYRoleTypeMaskOldPlatform;
            [self jumpCompleted];
        }
    }
}

#pragma mark - gameLogic

- (void)initGame {
    [self.gameContainerView removeAllSubviews];
    
    self.gameContainerView.userInteractionEnabled = YES;
    [self.gameContainerView addSubview:self.sceneView]; // 添加整个世界显示view
    [self.scene.rootNode addChildNode:self.floor]; // 添加地板
    [self.scene.rootNode addChildNode:self.jumper]; // 添加小方块
    
    [self addFirstPlatform];
    [self moveCameraToCurrentPlatform];
    [self createNextPlatform];
    
    [self.gameScoreLabel setText:[NSString stringWithFormat:@"当前分数:%d",(int)self.score]];
}

#pragma mark - getter

-(SCNScene *)scene {
    if (!_scene) {
        _scene = [SCNScene new];
        _scene.physicsWorld.contactDelegate = self;
        _scene.physicsWorld.gravity = SCNVector3Make(0, kGravityValue, 0); // 重力
    }
    return _scene;
}

-(SCNView *)sceneView {
    if (!_sceneView) {
        _sceneView = [[SCNView alloc] initWithFrame:self.gameContainerView.bounds];
        _sceneView.scene = self.scene;
        _sceneView.allowsCameraControl = NO;
        _sceneView.autoenablesDefaultLighting = NO;
        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(accumulateStrength:)];
        longPressGesture.minimumPressDuration = 0;
        _sceneView.gestureRecognizers = @[longPressGesture];
    }
    return _sceneView;
}

-(SCNNode *)floor {
    if (!_floor) {
        _floor = [SCNNode node];
        
        // floor
        SCNFloor *floor = [SCNFloor floor]; // xz平面的地板
        floor.firstMaterial.diffuse.contents = UIColor.whiteColor;
        _floor.geometry = floor;
        
        // body
        SCNPhysicsBody *body = [SCNPhysicsBody staticBody];
        body.restitution = 0;
        body.friction = 1;
        body.damping = 0.3;
        body.categoryBitMask = LYRoleTypeMaskFloor;
        body.collisionBitMask = LYRoleTypeMaskJumper | LYRoleTypeMaskPlatform | LYRoleTypeMaskOldPlatform;
        body.contactTestBitMask = LYRoleTypeMaskJumper; //
        
        _floor.physicsBody = body;
    }
    return _floor;
}

-(SCNNode *)jumper {
    if (!_jumper) {
        _jumper = [SCNNode node];
        
        SCNBox *box = [SCNBox boxWithWidth:1 height:1 length:1 chamferRadius:0];
        box.firstMaterial.diffuse.contents = UIColor.whiteColor;
        _jumper.geometry = box;
        
        SCNPhysicsBody *body = [SCNPhysicsBody dynamicBody];
        body.restitution = 0;
        body.friction = 1;
        body.rollingFriction = 1;
        body.damping = 0.3;
        body.allowsResting = YES;
        body.categoryBitMask = LYRoleTypeMaskJumper; // 类别是Jumper
        body.collisionBitMask = LYRoleTypeMaskPlatform | LYRoleTypeMaskFloor | LYRoleTypeMaskOldPlatform; // 允许和平台 地板碰撞
        _jumper.physicsBody = body;
        
        _jumper.position = SCNVector3Make(0, 12, 0); // y=12，所以有开头自由落地到第一个平台的动作
    }
    return _jumper;
}

-(SCNNode *)camera {
    if (!_camera) {
        _camera = [SCNNode node];
        _camera.camera = [SCNCamera camera];
        _camera.camera.zFar = 200.f;
        _camera.camera.zNear = .1f;
        [self.scene.rootNode addChildNode:_camera];
        _camera.eulerAngles = SCNVector3Make(-0.7, 0.6, 0); // 光源的朝向
        
        [_camera addChildNode:self.light]; // 顺便把光源也加上，为了保证摄像机看到的区域一直有光，把光源和相机关联在一起
    }
    return _camera;
}

-(SCNNode *)light {
    if (!_light) {
        _light = [SCNNode node];
        _light.light = [SCNLight light];
        _light.light.color = UIColor.whiteColor;
        _light.light.type = SCNLightTypeOmni; // 点光源
    }
    return _light;
}

@end
