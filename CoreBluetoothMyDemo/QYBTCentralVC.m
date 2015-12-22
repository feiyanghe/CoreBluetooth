//
//  QYBTCentralVC.m
//  CoreBluetoothMyDemo
//
//  Created by qingyun on 15/12/22.
//  Copyright © 2015年 qingyun. All rights reserved.
//

#import "QYBTCentralVC.h"
//导入支持蓝牙技术的头文件
#import <CoreBluetooth/CoreBluetooth.h>

@interface QYBTCentralVC ()<CBCentralManagerDelegate,CBPeripheralDelegate>
@property (weak, nonatomic) IBOutlet UISwitch *scanSwitch;
@property (weak, nonatomic) IBOutlet UITextView *textView;

@property (nonatomic,strong) CBCentralManager *centralManager;
@property (nonatomic,strong) CBPeripheral *discoverPeripheral;

@property (nonatomic,strong) NSMutableData *data;
@end

@implementation QYBTCentralVC
#pragma mark -view life cycle


- (void)viewDidLoad {
    [super viewDidLoad];
    //**************第一步创建central manager 对象************
    //1、创建central manager 对象
    _centralManager = [[CBCentralManager alloc]initWithDelegate:self queue:nil];//CB:CoreBluetooth
    
}
#pragma mark -数据懒加载
-(NSMutableData *)data{
    if (_data == nil) {
        _data = [NSMutableData data];
        
    }
    return _data;

}
#pragma mark -CBCentralManagerDelegate
//当Central设备的状态改变之后的回调，当_centralManager对象创建时，也会调用该方法
-(void)centralManagerDidUpdateState:(CBCentralManager *)central{
    //当蓝牙未开启时直接返回
    if (central.state != CBCentralManagerStatePoweredOn) {
        NSLog(@"[INFO]:蓝牙未开启");
        return;
    }
    
}

//*****************************第二部发现和连接外围设备**************************

//当Central设备发现Peripheral设备发出的Advertising报文时，调用该方法
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    //如果，已经发现过该设备，则直接返回，否则，保存该设备，并开始连接该设备
    if (self.discoverPeripheral ==peripheral) {
        return;
    }
    NSLog(@"[INFO]:发现Peripheral设备<%@>-<%@>",peripheral.name,RSSI);//RSSI:?????
    self.discoverPeripheral = peripheral;
    peripheral.delegate = self;
    //********************************开始连接设备*****************************
    [self.centralManager connectPeripheral:peripheral options:0];
}


//当Central设备连接Peripheral设备失败时的回调
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@"[ERROR]:连接 %@ 失败 (%@)",peripheral,error);

}

//当Central设备跟Peripheral设备连接成功之后的回调
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    //一旦连接成功，就立刻停止扫描
    [self.centralManager stopScan];
    NSLog(@"[INFO]:正在停止扫描...");
    
    //清空已经存储的数据，为了重新接收数据
    self.data.length = 0;
    
    //发现服务-根据UUID，去发现我们感兴趣的服务
    //UUID含义是通用唯一识别码 (Universally Unique Identifier)，这 是一个软件建构的标准，也是被开源软件基金会 (Open Software Foundation, OSF) 的组织应用在分布式计算环境 (Distributed Computing Environment, DCE) 领域的一部分。
    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];

}

//当Central设备跟Peripheral设备已经断开连接后的回调
-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    if (error) {
        NSLog(@"[ERROR]:断开连接失败 (%@)",error);//???????
        [self cleanup];//清理
        return;
    }
    NSLog(@"[INFO]:连接已断开");
    //在主队列里更新UI
    dispatch_async(dispatch_get_main_queue(), ^{
        //已经连接上设备，就把switch开关的状态置为关闭
        _scanSwitch.on = NO;
    });
    //已经断开连接后将连接设备置为空
    self.discoverPeripheral = nil;

}
//*********************发现连接的外围设备的服务（services）
#pragma mark -CBPeripheralDelegate
//发现Services之后的回调
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    //发现服务失败
    if (error) {
        NSLog(@"[ERROR]:Peripheral设备发现服务（services）失败(%@)",error);
        [self cleanup];
        return;
    }
    //遍历Peripheral设备的所有服务（services），去发现我们需要的Characteristics特性
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]] forService:service];//????
    }
    
}

//发现Characteristics之后的回调
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    //如果失败
    if (error) {
        NSLog(@"[ERROR]:Peripheral设备发现特性失败 (%@)",error);
        [self cleanup];
        return;
    }
    
    //遍历该服务所有的特性，然后去订阅这些特性
    for (CBCharacteristic *characteristic in service.characteristics) {
        //订阅该特性
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }

}

//收到数据更新之后的回调

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        NSLog(@"[ERROR]:更新数据失败 (%@)",error);
        [self cleanup];
        return;
        
        
    }
    //取出数据
    NSData *data = characteristic.value;
    //解析数据
    [self parseData:data WithPeripheral:peripheral andCharacteristic:characteristic];

}

//解析数据的方法
-(void)parseData:(NSData *)data WithPeripheral:(CBPeripheral *)peripheral andCharacteristic:(CBCharacteristic *)characteristic{
    NSString *dataStr = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"[DEBUG]:已收到 - %@",dataStr);
    
    //接收数据完毕 - EOM（End of Message）
    if ([dataStr isEqualToString:EOM]) {
        //更新UI
        _textView.text = [[NSString alloc]initWithData:self.data encoding:NSUTF8StringEncoding];
        //取消订阅
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        
        //断开连接
        [self.centralManager cancelPeripheralConnection:peripheral];
        return;
    }
    
    //拼接数据
    [self.data appendData:data];
    
}
//订阅状态发生变化时的回调
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        NSLog(@"[ERROR]:setNotifyValue:forCharacteristic: 失败! (%@)",error);
        [self cleanup];
        return;
    }
    if (characteristic.isNotifying) {
        NSLog(@"[INFO]: 已经订阅 %@",characteristic);
        
    }else{
        NSLog(@"[INFO]:取消订阅 %@",characteristic);
    
    }

}

#pragma mark -misc process

-(void)cleanup{
    //如果没有连接上就返回
    if (self.discoverPeripheral.state !=CBPeripheralStateDisconnected) {
        return;
    }
    //遍历所有服务的特性，并且取消订阅
    if (self.discoverPeripheral.services) {
        for (CBService *service in self.discoverPeripheral.services) {
            if (service.characteristics) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
                        [self.discoverPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                    }
                }
            }
        }
    }



}
#pragma mark -events handling

- (IBAction)toggleSwitch:(UISwitch *)sender {
    if (sender.on) {
        //scan开始扫描
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:0];
        NSLog(@"[INFO]:开始扫描...");
        
    }else{
        //停止扫描
        [self.centralManager stopScan];
    
    
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
