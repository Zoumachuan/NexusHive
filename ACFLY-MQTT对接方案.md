# ACFLY无人机 - MQTT对接方案(推荐)

**项目**: NexusHive适配ACFLY开源无人机  
**方案**: MQTT统一架构  
**部署**: 阿里云单服务器(华中区域-长沙节点)

---

## 🎯 方案架构

```
┌─────────────────────────────────────────────────────────────┐
│                  阿里云ECS (华中-长沙)                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │               EMQX MQTT Broker                        │  │
│  │            端口: 1883(MQTT) / 8083(WS)               │  │
│  └──────────┬─────────────────────────┬─────────────────┘  │
│            ↓                         ↓                      │
│  ┌──────────────────┐      ┌──────────────────────────┐   │
│  │  ThinkPHP后端     │      │  Vue3前端 (Nginx)        │   │
│  │  (订阅MQTT)      │      │  (WebSocket订阅)         │   │
│  │  - 数据解析       │      │  - 实时地图显示          │   │
│  │  - 入库MySQL     │      │  - 设备状态监控          │   │
│  │  - 指令发布       │      │  - 历史轨迹回放          │   │
│  └──────────────────┘      └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                    ↑
                    │ MQTT over 4G/WiFi
                    │
         ┌──────────┴──────────┐
         │  现场地面站电脑       │
         │  ┌────────────────┐ │
         │  │Python转发脚本   │ │
         │  │ 监听地面站      │ │
         │  │ 发布到EMQX     │ │
         │  └────────────────┘ │
         │         ↓           │
         │  ┌────────────────┐ │
         │  │ ACFLY地面站     │ │
         │  │ (JSON输出)     │ │
         │  └────────────────┘ │
         │         ↓           │
         │  ┌────────────────┐ │
         │  │  3台无人机      │ │
         │  │ (MAVLink协议)  │ │
         │  └────────────────┘ │
         └─────────────────────┘
```

---

## 📊 MQTT主题设计

### 上行数据(现场→云端)

```
acfly/{uavUUID}/status              # 飞机状态(1Hz)
acfly/{uavUUID}/gps                 # GPS位置(2Hz)
acfly/{uavUUID}/battery             # 电池信息(1Hz)
acfly/{uavUUID}/attitude            # 姿态数据(10Hz)
acfly/{uavUUID}/event               # 事件通知

acfly/groundstation/heartbeat       # 地面站心跳
acfly/groundstation/connected       # 设备上线通知
acfly/groundstation/disconnected    # 设备下线通知
```

### 下行控制(云端→现场)

```
acfly/{uavUUID}/cmd/arm             # 解锁
acfly/{uavUUID}/cmd/disarm          # 上锁
acfly/{uavUUID}/cmd/takeoff         # 起飞
acfly/{uavUUID}/cmd/land            # 降落
acfly/{uavUUID}/cmd/rtl             # 返航
acfly/{uavUUID}/cmd/goto            # 指点飞行
acfly/{uavUUID}/cmd/mission         # 航线任务
```

---

## 🔧 现场部署脚本(Python)

**文件**: `acfly_mqtt_bridge.py` (部署在地面站电脑)

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ACFLY地面站 → EMQX MQTT桥接脚本
监听地面站UDP输出,转发到阿里云EMQX
"""

import json
import socket
import paho.mqtt.client as mqtt
import time
from datetime import datetime

# ============= 配置区域 =============
GROUND_STATION_UDP_PORT = 14550  # 地面站UDP端口(需确认)
MQTT_BROKER = "mqtt.your-server.com"  # 阿里云ECS公网IP
MQTT_PORT = 1883
MQTT_USERNAME = "acfly_client"
MQTT_PASSWORD = "your_password"
MQTT_CLIENT_ID = "groundstation_001"
# ====================================

class ACFlyMqttBridge:
    def __init__(self):
        self.mqtt_client = None
        self.udp_socket = None
        self.device_cache = {}  # 缓存设备信息
        
    def on_mqtt_connect(self, client, userdata, flags, rc):
        if rc == 0:
            print(f"[✓] MQTT连接成功: {MQTT_BROKER}")
            # 订阅控制指令主题
            client.subscribe("acfly/+/cmd/#")
        else:
            print(f"[✗] MQTT连接失败: {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """接收云端下发的控制指令"""
        try:
            topic = msg.topic
            payload = msg.payload.decode()
            print(f"[←] 收到控制指令: {topic} -> {payload}")
            
            # TODO: 将MQTT指令转换为MAVLink,发送给地面站
            # 这部分需要根据地面站实际接口实现
            
        except Exception as e:
            print(f"[✗] 处理指令失败: {e}")
    
    def parse_json_status(self, json_str):
        """解析地面站JSON数据"""
        try:
            data = json.loads(json_str)
            if data.get("command") == "status":
                return data.get("data")
        except:
            return None
        return None
    
    def publish_to_mqtt(self, uav_data):
        """发布数据到MQTT"""
        if not uav_data:
            return
        
        uuid = uav_data.get("uavUUID")
        if not uuid:
            return
        
        # 发布完整状态
        topic_status = f"acfly/{uuid}/status"
        self.mqtt_client.publish(topic_status, json.dumps(uav_data), qos=1)
        
        # 发布关键数据(减少带宽)
        if uav_data.get("latitude") != -1000:
            gps_data = {
                "lat": uav_data["latitude"],
                "lon": uav_data["longitude"],
                "alt": uav_data["relativeAlt"],
                "speed": uav_data["groundSpeed"],
                "heading": uav_data["yaw"],
                "timestamp": uav_data["timestampString"]
            }
            self.mqtt_client.publish(f"acfly/{uuid}/gps", json.dumps(gps_data), qos=0)
        
        # 发布电池数据
        battery_data = {
            "voltage1": uav_data["voltage1"],
            "voltage2": uav_data["voltage2"],
            "current": uav_data["current"],
            "remain": 100  # 如果有剩余电量百分比字段
        }
        self.mqtt_client.publish(f"acfly/{uuid}/battery", json.dumps(battery_data), qos=0)
    
    def listen_udp(self):
        """监听地面站UDP数据"""
        self.udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udp_socket.bind(("0.0.0.0", GROUND_STATION_UDP_PORT))
        print(f"[✓] 监听地面站UDP: {GROUND_STATION_UDP_PORT}")
        
        while True:
            try:
                data, addr = self.udp_socket.recvfrom(4096)
                json_str = data.decode('utf-8')
                
                # 解析JSON
                uav_data = self.parse_json_status(json_str)
                if uav_data:
                    # 转发到MQTT
                    self.publish_to_mqtt(uav_data)
                    
                    # 打印状态
                    uuid = uav_data.get("uavUUID", "unknown")
                    state = uav_data.get("state", "unknown")
                    mode = uav_data.get("flyMode", "unknown")
                    print(f"[→] {uuid[:8]}... {state} {mode}")
                    
            except Exception as e:
                print(f"[✗] UDP处理错误: {e}")
                time.sleep(1)
    
    def run(self):
        """启动桥接服务"""
        # 连接MQTT
        self.mqtt_client = mqtt.Client(client_id=MQTT_CLIENT_ID)
        self.mqtt_client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_message = self.on_mqtt_message
        
        try:
            self.mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.mqtt_client.loop_start()
            
            # 发送上线通知
            self.mqtt_client.publish("acfly/groundstation/connected", 
                                   json.dumps({"time": datetime.now().isoformat()}))
            
            # 启动UDP监听
            self.listen_udp()
            
        except KeyboardInterrupt:
            print("\n[!] 用户中断")
        except Exception as e:
            print(f"[✗] 运行错误: {e}")
        finally:
            self.mqtt_client.publish("acfly/groundstation/disconnected",
                                   json.dumps({"time": datetime.now().isoformat()}))
            self.mqtt_client.disconnect()
            if self.udp_socket:
                self.udp_socket.close()

if __name__ == "__main__":
    print("=" * 50)
    print("  ACFLY → MQTT 桥接服务")
    print("=" * 50)
    bridge = ACFlyMqttBridge()
    bridge.run()
```

**部署方式**:
```bash
# 安装依赖
pip3 install paho-mqtt

# 后台运行
nohup python3 acfly_mqtt_bridge.py > mqtt_bridge.log 2>&1 &

# 或者用systemd开机自启
```

---

## 💻 后端订阅处理(ThinkPHP)

**修改现有MQTT类**: `/root/NexusHive/NexusHive/extend/mqtt/AcflyMqtt.php`

```php
<?php
namespace mqtt;

use think\facade\Db;
use Workerman\Lib\Timer;
use Workerman\Mqtt\Client;

class AcflyMqtt
{
    private $mqtt = null;
    
    public function onWorkerStart($worker)
    {
        $mqtt = new Client("mqtt://127.0.0.1:1883", [
            'client_id' => 'nexushive_backend',
            'username' => 'nexushive',
            'password' => 'your_password',
            'keepalive' => 60,
        ]);
        
        $mqtt->onConnect = function() use ($mqtt) {
            echo "EMQX连接成功\n";
            
            // 订阅所有ACFLY设备状态
            $mqtt->subscribe('acfly/+/status');
            $mqtt->subscribe('acfly/+/gps');
            $mqtt->subscribe('acfly/+/battery');
            $mqtt->subscribe('acfly/groundstation/#');
        };
        
        $mqtt->onMessage = function($topic, $content) {
            $this->handleMessage($topic, $content);
        };
        
        $mqtt->connect();
        $this->mqtt = $mqtt;
    }
    
    private function handleMessage($topic, $content)
    {
        $parts = explode('/', $topic);
        $data = json_decode($content, true);
        
        if ($parts[0] !== 'acfly') return;
        
        // 处理状态数据
        if ($parts[2] === 'status' && count($parts) === 3) {
            $this->saveStatus($parts[1], $data);
        }
        
        // 处理GPS数据
        if ($parts[2] === 'gps') {
            $this->saveGps($parts[1], $data);
        }
        
        // 处理地面站事件
        if ($parts[1] === 'groundstation') {
            $this->handleGroundStationEvent($parts[2], $data);
        }
    }
    
    private function saveStatus($uuid, $data)
    {
        // 更新设备表
        Db::name('acfly_device')->where('uuid', $uuid)->update([
            'state' => $data['state'],
            'fly_mode' => $data['flyMode'],
            'last_seen' => time(),
            'online' => 1
        ]);
        
        // 保存OSD数据(类似DJI)
        Db::name('acfly_osd')->insert([
            'uuid' => $uuid,
            'latitude' => $data['latitude'],
            'longitude' => $data['longitude'],
            'altitude' => $data['relativeAlt'],
            'ground_speed' => $data['groundSpeed'],
            'yaw' => $data['yaw'],
            'pitch' => $data['pitch'],
            'roll' => $data['roll'],
            'voltage' => $data['voltage1'],
            'current' => $data['current'],
            'state' => $data['state'],
            'fly_mode' => $data['flyMode'],
            'timestamp' => strtotime($data['timestampString']),
            'create_time' => time()
        ]);
    }
}
```

---

## 🌐 前端实时订阅(Vue3 + MQTT.js)

```bash
cd /root/NexusHive/Nexus-Hive-Web
pnpm add mqtt
```

**WebSocket订阅**: `src/services/acflyMqttService.ts`

```typescript
import mqtt from 'mqtt'
import type { MqttClient } from 'mqtt'

class AcflyMqttService {
  private client: MqttClient | null = null
  private callbacks: Map<string, Function[]> = new Map()
  
  connect() {
    // 使用EMQX的WebSocket端口
    this.client = mqtt.connect('ws://your-server.com:8083/mqtt', {
      clientId: `web_${Math.random().toString(16).substr(2, 8)}`,
      username: 'web_user',
      password: 'your_password',
      reconnectPeriod: 3000,
    })
    
    this.client.on('connect', () => {
      console.log('MQTT WebSocket连接成功')
      // 订阅所有设备
      this.client?.subscribe('acfly/+/status')
      this.client?.subscribe('acfly/+/gps')
    })
    
    this.client.on('message', (topic, payload) => {
      const data = JSON.parse(payload.toString())
      this.notify(topic, data)
    })
  }
  
  // 订阅特定主题
  on(topic: string, callback: Function) {
    if (!this.callbacks.has(topic)) {
      this.callbacks.set(topic, [])
    }
    this.callbacks.get(topic)?.push(callback)
  }
  
  // 发送控制指令
  sendCommand(uuid: string, command: string, params: any = {}) {
    const topic = `acfly/${uuid}/cmd/${command}`
    this.client?.publish(topic, JSON.stringify(params), { qos: 1 })
  }
  
  private notify(topic: string, data: any) {
    // 精确匹配
    this.callbacks.get(topic)?.forEach(cb => cb(data))
    
    // 通配符匹配
    const pattern = topic.replace(/[^/]+/, '+')
    this.callbacks.get(pattern)?.forEach(cb => cb(data))
  }
}

export default new AcflyMqttService()
```

---

## 📦 阿里云服务器配置建议

### 服务器选型

**推荐配置**:
- **区域**: 华中1(长沙) - 距离湖南最近,延迟<10ms
- **规格**: ecs.c6.large (2核4GB) 或 ecs.c6.xlarge (4核8GB)
- **带宽**: 5Mbps (3台设备足够)
- **存储**: 40GB系统盘 + 100GB数据盘

**预估费用**:
- 2核4GB: ¥600/年(抢占式实例) 或 ¥1200/年(包年)
- 4核8GB: ¥1200/年(抢占式) 或 ¥2400/年(包年)
- 带宽5M: ¥360/年

### 软件栈部署

```bash
# 1. 安装EMQX (Docker方式)
docker run -d --name emqx \
  -p 1883:1883 -p 8083:8083 -p 18083:18083 \
  -e EMQX_NAME=nexushive \
  -e EMQX_HOST=127.0.0.1 \
  --restart=always \
  emqx/emqx:latest

# 2. 配置EMQX认证(访问 http://ip:18083 默认账号admin/public)
# 创建用户:
#   - acfly_client / password123  (现场Python脚本)
#   - nexushive / password456     (ThinkPHP后端)
#   - web_user / password789      (前端WebSocket)

# 3. 部署后端(已有ThinkPHP)
cd /root/NexusHive/NexusHive
php think worker:server start -d

# 4. 部署前端(Nginx)
cd /root/NexusHive/Nexus-Hive-Web
pnpm build
# 将dist目录部署到 /var/www/nexushive

# 5. 配置Nginx
server {
    listen 80;
    server_name your-domain.com;
    
    # 前端静态文件
    location / {
        root /var/www/nexushive;
        try_files $uri $uri/ /index.html;
    }
    
    # 后端API代理
    location /api {
        proxy_pass http://127.0.0.1:8000;
    }
    
    # MQTT WebSocket代理
    location /mqtt {
        proxy_pass http://127.0.0.1:8083;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
}
```

---

## ⚡ 方案优势

| 对比项 | 自写工具 | OSS | **MQTT** |
|-------|---------|-----|----------|
| 实时性 | 中(1-3s) | 差(5-10s) | **优(100ms)** |
| 可靠性 | 中 | 中 | **高(QoS保证)** |
| 扩展性 | 差 | 中 | **优(支持N台设备)** |
| 运维难度 | 高 | 中 | **低(EMQX稳定)** |
| 双向控制 | 难 | 不支持 | **易(发布订阅)** |
| 成本 | ¥0 | OSS费用 | **服务器已有** |
| 开发周期 | 10天 | 8天 | **12天(但更完善)** |

---

## 🎯 最终建议

**强烈推荐MQTT方案**,理由:

1. ✅ **你已有EMQX经验** - NexusHive项目已集成MQTT
2. ✅ **架构统一** - 前后端MQTT+数据库+Web全在一台服务器
3. ✅ **实时性最好** - WebSocket推送,地图实时刷新
4. ✅ **支持双向控制** - 未来可远程起飞降落
5. ✅ **易于扩展** - 从3台扩展到30台只需订阅主题
6. ✅ **现场部署简单** - Python脚本50行代码,pip安装即可
7. ✅ **长沙节点** - 华中区域延迟最低

**报价调整**: 
- 基础功能(数据展示): **¥12,000** (12天)
- 含远程控制: **¥15,000** (15天)
- 服务器费用: 甲方承担或你代购(¥1500/年)
