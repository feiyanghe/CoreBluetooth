//
//  QYBTPeripheralVC.m
//  CoreBluetoothMyDemo
//
//  Created by qingyun on 15/12/22.
//  Copyright © 2015年 qingyun. All rights reserved.
//

#import "QYBTPeripheralVC.h"
#import <CoreBluetooth/CoreBluetooth.h>
@interface QYBTPeripheralVC ()<CBPeripheralManagerDelegate>
@property (weak, nonatomic) IBOutlet UISwitch *advertisingSwitch;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (nonatomic,strong) CBPeripheralManager *peripheralManager;
@property (nonatomic,strong) CBMutableCharacteristic *characteristic2Send;
@property (nonatomic,strong) NSData *data2Send;
@property (nonatomic,assign) NSInteger data2SendIndex;

@end

@implementation QYBTPeripheralVC
#pragma mark -view life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}
#pragma mark -peripheralManager懒加载
-(CBPeripheralManager *)peripheralManager{
    if (_peripheralManager == nil) {
        _peripheralManager = [[CBPeripheralManager alloc]initWithDelegate:self queue:nil options:nil];
    }
    return _peripheralManager;

}
#pragma mark -CBPeripheralManagerDelegate
//当peripheral设备的状态更新时，会回调该方法(_peripheralManager对象创建时也会调用该方法)
-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral{
    //必须上电（开启switch开关）
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        NSLog(@"[INFO]:蓝牙未开启");
        return;
    }
    //创建服务
    CBMutableService *service = [[CBMutableService alloc]initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID] primary:YES];
    //创建特性
    self.characteristic2Send = [[CBMutableCharacteristic alloc]initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID] properties:CBCharacteristicPropertyNotify|CBCharacteristicPropertyNotifyEncryptionRequired value:nil permissions:CBAttributePermissionsReadEncryptionRequired];//?????????
    
    service.characteristics = @[self.characteristic2Send];
    
    //添加服务
    [self.peripheralManager addService:service];

}
//已经开始ADvertising
-(void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error{
    if (error) {
        NSLog(@"[ERROR]:%@",error);
        return;
    }
    NSLog(@"[INFO]:开始ADvertiasing...");

}

//当peripheral设备，收到订阅时的回调
-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic{
    //构造数据
    self.data2Send = [_textView.text dataUsingEncoding:NSUTF8StringEncoding];
    
    self.data2SendIndex = 0;
    [self sendData];

}

#pragma mark -misc process
-(void)sendData{
    //是否需要发送EOM??????????????
    if (self.data2SendIndex >=self.data2Send.length) {
        NSData *data = [EOM dataUsingEncoding:NSUTF8StringEncoding];
        BOOL isOk = [self.peripheralManager updateValue:data forCharacteristic:self.characteristic2Send onSubscribedCentrals:nil];
        if (isOk) {
            NSLog(@"[INFO]:EOM 已发送");
        }
        return;
    }
    
#warning ??????????????????????
    
    BOOL canSend =YES;
    do {
        //1、剩余需要发送的量
        NSInteger amount2Send = self.data2Send.length - self.data2SendIndex;
        //2.本次要发送的数据的长度
        NSInteger length = amount2Send > BTLE_MTU ? BTLE_MTU : amount2Send;
        
        //3、本次要发送的数据
        
        NSData *data = [NSData dataWithBytes:self.data2Send.bytes+self.data2SendIndex length:length];
        //4.发送
        
        canSend = [self.peripheralManager updateValue:data forCharacteristic:self.characteristic2Send onSubscribedCentrals:nil];
        
        
        if (!canSend) {
            //硬件已不能再发送，等下次硬件再次准备好的时候发送
            return;
        }
        
        //打印已经发送的数据
        NSLog(@"[DEBUG]:已经发送 - %@",data);
        
        //更新记录发送位置的索引
        
        self.data2SendIndex += length;
        
        
    } while (canSend);


}

#pragma mark -events handling

-(void)dismissKeyboard{
    
    self.navigationItem.rightBarButtonItem =nil;
    //失去第一响应
    [_textView resignFirstResponder];


}

- (IBAction)advertising:(UISwitch *)sender {
    if (sender.on) {
        [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]}];
    }else{
        [self.peripheralManager stopAdvertising];
    
    
    }
    
    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
