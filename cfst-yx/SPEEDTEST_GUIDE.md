# 🚀 CloudflareSpeedTest 联动测试指南

## 📖 目录
1. [概述](#概述)
2. [核心概念](#核心概念)
3. [四阶段测试流程](#四阶段测试流程)
4. [使用指南](#使用指南)
5. [命令参考](#命令参考)
6. [常见问题](#常见问题)

---

## 概述

这个指南介绍如何使用 **CloudflareSpeedTest** 进行递进式、全方位的网络性能测试。通过四个阶段的联动测试，从快速筛选到精细评估，找到最适合你网络环境的CDN接入点。

### 测试场景

本指南涵盖以下四个典型场景：

| 场景 | 目标 | 耗时 | 特点 |
|------|------|------|------|
| **场景1: 快速找最快IP** | 迅速定位最佳接入点 | 2-3分钟 | TCP快速、轻量级 |
| **场景2: 确保服务可用** | 验证HTTP服务实际可用 | 3-4分钟 | 应用层验证、稳定性 |
| **场景3: 监控CDN接入点** | 跟踪特定地域节点质量 | 1-2分钟 | 持续监控、历史追踪 |
| **场景4: 评估用户体验** | 完整的真实体验评估 | 5-8分钟 | 全面测试、实际应用 |

---

## 核心概念

### TCP vs HTTP/S 延迟测试

#### TCP 测试（TCPing）

```
工作原理: 客户端 → TCP SYN → 服务器 → SYN-ACK → 测量时间
网络层级: 传输层 (Layer 4)
```

**特点：**
- ✅ **最快** - 只需完成TCP三次握手
- ✅ **最轻** - 不涉及应用层，网络开销最小
- ✅ **最准** - 直接测试底层网络连接质量，不受应用服务影响
- ❌ **无验证** - 无法确认应用服务是否真正可用

**适用场景：**
- 快速筛选IP
- 初步网络诊断
- 监控网络连接状态

#### HTTP/S 测试（HTTPing）

```
工作原理: 客户端 → TCP握手 → TLS握手(HTTPS) → HTTP请求 → 等待响应头 → 测量时间
网络层级: 应用层 (Layer 7)
```

**特点：**
- ✅ **真实** - 模拟实际用户访问，测试应用可用性
- ✅ **验证** - 可检查HTTP状态码（200/301/302等）
- ✅ **全面** - 包含DNS、TLS、HTTP全套协议
- ❌ **较慢** - 涉及更多网络层级，耗时更长

**适用场景：**
- 验证服务真实可用性
- 评估用户真实体验
- 检验应用层性能

### 测试数据流向

```
Raw IP List
    ↓
[阶段1] TCP快速筛选
    ├─ 所有IP进行TCPing
    ├─ 筛选延迟<200ms
    └─ 输出: 50个候选IP
    ↓
[阶段2] HTTP服务验证
    ├─ 前20个候选IP进行HTTPing
    ├─ 验证HTTP状态码=200
    ├─ 确保服务可用
    └─ 输出: 20个已验证IP
    ↓
[阶段3] 完整性能评估
    ├─ 前10个验证IP
    ├─ 进行完整下载测试
    ├─ 计算下载速度
    └─ 输出: 最终排序结果
    ↓
最佳IP (可用于hosts或其他工具)
```

---

## 四阶段测试流程

### 🎯 阶段1：TCP快速筛选

**目的：** 从所有IP中快速筛选出网络延迟低的候选集合

**参数设置：**

```bash
./CloudflareSpeedTest \
    -tp 443              # 使用443端口
    -n 15                # 15个线程（路由器适用）
    -t 2                 # 每个IP测2次
    -dn 0 -dd            # 禁用下载测试，仅测延迟
    -tl 200              # 延迟上限200ms
    -p 50                # 显示50个结果
    -o 01_tcp_candidates.csv
```

**输出示例：**
```
IP,延迟,丢包率
1.2.3.4,45,0.00
1.2.3.5,52,0.00
1.2.3.6,58,0.00
...
```

**预期结果：** 找到50个延迟<200ms的IP

**耗时：** 2-3分钟

**关键参数说明：**

| 参数 | 值 | 说明 |
|------|-----|------|
| `-n` | 15 | 线程数。值越大越快，但对路由器压力越大。华为AX3 Pro建议不超过15-20 |
| `-t` | 2 | 测试次数。初筛2次足够 |
| `-tl` | 200 | 延迟上限。超过200ms的IP过滤掉 |
| `-dd` | - | 禁用下载测试，节省时间 |

---

### 🔍 阶段2：HTTP服务验证

**目的：** 确保阶段1找到的IP在应用层也是真正可用的

**输入：** 阶段1的前20个IP

**参数设置：**

```bash
./CloudflareSpeedTest \
    -httping             # 切换到HTTP测试模式
    -cfcolo HKG,NRT,SIN,LAX  # 指定地区（可选）
    -httping-code 200    # 只接受200响应码
    -url https://cf.xiu2.xyz/url  # 测速URL
    -n 15                # 15个线程
    -t 3                 # 每个IP测3次
    -dn 0 -dd            # 仅测延迟
    -ip "提取的20个IP"   # 指定待测IP
    -tl 250              # 延迟上限250ms（包含HTTP开销）
    -p 20                # 显示20个结果
    -o 02_http_verified.csv
```

**关键参数说明：**

| 参数 | 说明 |
|------|------|
| `-httping` | 启用HTTPing模式（HTTP/HTTPS延迟测试） |
| `-cfcolo` | 仅HTTPing模式可用，按IATA机场码或国家码过滤。例: HKG(香港), NRT(东京), SIN(新加坡), LAX(洛杉矶) |
| `-httping-code` | 接受的HTTP状态码。200=成功, 301/302=重定向。建议设为200最严格 |
| `-url` | 测速文件地址。需要是真实存在的URL，建议自建或使用可靠服务 |
| `-tl` | 250ms是因为HTTP握手比TCP多。不要设太低 |

**输出特点：**
- ✅ 验证了IP的应用层可用性
- ✅ 过滤掉虽然TCP连通但HTTP不可用的IP
- ✅ 延迟时间会比TCP高（包含HTTP开销）

**预期结果：** 获得15-20个应用层可用的IP

**耗时：** 3-4分钟

---

### 🚀 阶段3：完整性能评估

**目的：** 对验证过的IP进行完整下载测试，评估真实用户体验

**输入：** 阶段2的前10个验证IP

**参数设置：**

```bash
./CloudflareSpeedTest \
    -httping             # 使用HTTP模式
    -cfcolo HKG,NRT,SIN,LAX
    -httping-code 200
    -url https://cf.xiu2.xyz/url
    -n 15                # 线程数
    -t 4                 # 每个IP测4次（充分测试）
    -ip "提取的10个IP"   # 指定待测IP
    -dn 10               # 对这10个IP进行下载测试
    -dt 12               # 每个IP下载测12秒（适配208M宽带）
    -sl 5                # 下载速度下限5MB/s
    -tl 300              # 延迟上限300ms
    -tlr 0.1             # 丢包率上限10%
    -p 10                # 显示10个结果
    -o 03_final_results.csv
```

**关键参数说明：**

| 参数 | 值 | 说明 |
|------|-----|------|
| `-t` | 4 | 充分测试，4次确保结果稳定 |
| `-dn` | 10 | 对这10个IP进行完整下载测试 |
| `-dt` | 12 | 下载时间。208M宽带设12秒足够，太长浪费时间 |
| `-sl` | 5 | 下载速度>5MB/s才符合要求 |
| `-tlr` | 0.1 | 丢包率<10%（表示网络稳定） |
| `-tl` | 300 | 最终延迟<300ms（可接受范围） |

**输出示例：**
```
IP,延迟,丢包率,下载速度
1.2.3.4,48,0.00,180.5
1.2.3.5,55,0.00,175.2
1.2.3.6,62,0.05,168.3
...
```

**预期结果：** 获得最终排序的10个最佳IP

**耗时：** 5-8分钟

---

### 📊 阶段4：持续监控（可选）

**目的：** 定期检查最佳IP的可用性，及时发现网络变化

#### 方式1：定期手动测试

使用cron定时运行：

```bash
# 编辑crontab
crontab -e

# 添加以下行（每小时检查一次最佳IP）
0 * * * * cd /workspaces/CloudflareSpeedTest && ./CloudflareSpeedTest -tp 443 -n 5 -t 1 -dn 0 -dd -ip "1.2.3.4" -o /var/log/cfst_check_$(date +\%Y\%m\%d_\%H).csv
```

#### 方式2：监控特定地域

```bash
# 监控HKG地域节点
./CloudflareSpeedTest \
    -httping \
    -cfcolo HKG \
    -httping-code 200 \
    -url https://cf.xiu2.xyz/url \
    -n 10 -t 2 -dn 0 -dd \
    -tl 180 -p 20 \
    -o monitor_hkg_$(date +%Y%m%d_%H%M%S).csv
```

---

## 使用指南

### 快速开始

#### 方式1：使用自动化脚本（推荐）

```bash
# 构建项目
cd /workspaces/CloudflareSpeedTest
go build

# 执行联动测试脚本
chmod +x cfst_pipeline.sh
./cfst_pipeline.sh

# 带参数执行
./cfst_pipeline.sh -n 20 -r HKG,NRT,SIN,LAX -u https://cf.xiu2.xyz/url
```

**脚本特点：**
- ✅ 自动完成四阶段测试
- ✅ 自动提取和传递数据
- ✅ 彩色输出和进度显示
- ✅ 结果汇总和分析

#### 方式2：手动逐步执行

```bash
# 1. 阶段1: TCP筛选
./CloudflareSpeedTest -tp 443 -n 15 -t 2 -dn 0 -dd \
    -tl 200 -p 50 -o 01_tcp_candidates.csv

# 2. 提取前20个IP
CANDIDATES=$(tail -n +3 01_tcp_candidates.csv | awk -F',' '{print $1}' | head -20 | paste -sd ',' -)

# 3. 阶段2: HTTP验证
./CloudflareSpeedTest -httping -cfcolo HKG,NRT,SIN,LAX \
    -httping-code 200 -url https://cf.xiu2.xyz/url \
    -n 15 -t 3 -dn 0 -dd -ip "$CANDIDATES" \
    -tl 250 -p 20 -o 02_http_verified.csv

# 4. 提取前10个IP
VERIFIED=$(tail -n +3 02_http_verified.csv | awk -F',' '{print $1}' | head -10 | paste -sd ',' -)

# 5. 阶段3: 性能评估
./CloudflareSpeedTest -httping -cfcolo HKG,NRT,SIN,LAX \
    -httping-code 200 -url https://cf.xiu2.xyz/url \
    -n 15 -t 4 -ip "$VERIFIED" \
    -dn 10 -dt 12 -sl 5 -tl 300 -tlr 0.1 \
    -p 10 -o 03_final_results.csv
```

### 针对你的网络环境的建议

**硬件配置：**
- 宽带: 208M
- 路由器: 华为 AX3 Pro（中等性能）
- 接入方式: 有线连接（优势）

**参数调整建议：**

| 参数 | 建议值 | 原因 |
|------|--------|------|
| `-n` (线程数) | 15-20 | 路由器性能有限，不建议超过20 |
| `-t` (测试次数) | 2-4 | 有线连接稳定，次数可适中 |
| `-dt` (下载时间) | 10-12秒 | 208M宽带，12秒足以评估性能 |
| `-tp` (端口) | 443 | HTTPS端口，推荐使用 |

---

## 命令参考

### 基础参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-n` | int | 200 | 延迟测速线程数 |
| `-t` | int | 4 | 单个IP延迟测速次数 |
| `-tp` | int | 443 | 测速端口 |
| `-url` | string | https://cf.xiu2.xyz/url | 测速地址 |

### HTTPing 参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-httping` | bool | false | 启用HTTP测试模式 |
| `-httping-code` | int | 0 | 有效HTTP状态码 |
| `-cfcolo` | string | "" | 按地区过滤（IATA码） |

### 下载测速参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-dn` | int | 10 | 下载测速IP数量 |
| `-dt` | int | 10 | 下载测速时间（秒） |
| `-sl` | float | 0 | 下载速度下限(MB/s) |
| `-dd` | bool | false | 禁用下载测速 |

### 筛选参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-tl` | int | 9999 | 平均延迟上限(ms) |
| `-tll` | int | 0 | 平均延迟下限(ms) |
| `-tlr` | float | 1.00 | 丢包率上限(0.00-1.00) |

### 输出参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-p` | int | 10 | 显示结果数量 |
| `-o` | string | result.csv | 输出文件路径 |
| `-ip` | string | "" | 指定待测IP（逗号分隔） |
| `-f` | string | ip.txt | IP数据文件 |

---

## 常见问题

### Q1: 测试花时间太长了，怎么加快？

**A:** 调整以下参数：
```bash
# 方式1: 增加线程数（如果硬件允许）
-n 30  # 从15增加到30

# 方式2: 减少测试次数
-t 1   # 从2减少到1（初筛时可用）

# 方式3: 跳过某个阶段
-dd    # 禁用下载测试
```

### Q2: 如何只测试特定地域的IP？

**A:** 使用 `-cfcolo` 参数（仅HTTPing模式）：
```bash
./CloudflareSpeedTest -httping -cfcolo HKG,NRT \
    -url https://cf.xiu2.xyz/url ...
```

**地域码参考：**
- HKG - 香港
- NRT - 东京
- SIN - 新加坡
- LAX - 洛杉矶
- SJC - 圣何塞
- FRA - 法兰克福
- MAD - 马德里

### Q3: CSV文件的列是什么意思？

**A:** 标准CSV格式（使用 awk -F',' 读取）：
```
IP,延迟(ms),丢包率(%),下载速度(MB/s),其他
1.2.3.4,45,0.00,180.5,...
```

### Q4: 如何将最佳IP添加到hosts文件？

**A:** 获取最佳IP后：
```bash
# 获取最快IP
BEST_IP=$(tail -n +3 03_final_results.csv | head -1 | awk -F',' '{print $1}')

# 添加到hosts（需要root权限）
sudo bash -c "echo '$BEST_IP  example.com' >> /etc/hosts"

# 验证
cat /etc/hosts | grep example.com
```

### Q5: 测试中断了怎么办？

**A:** 可以安全地重新运行，程序会覆盖之前的结果。如果要保留历史结果：
```bash
# 使用时间戳重命名
mv 03_final_results.csv 03_final_results_$(date +%Y%m%d_%H%M%S).csv
```

### Q6: 为什么HTTP延迟比TCP高？

**A:** 这是正常的。HTTP延迟包含：
- TCP握手 (~20ms)
- TLS握手（HTTPS）(~30-50ms)  
- HTTP请求/响应 (~10-20ms)
- 总计: 通常比TCP高 50-100ms

### Q7: 下载测试时出现超时，怎么办？

**A:** 检查以下几点：
1. 下载地址是否可达：`curl -I https://cf.xiu2.xyz/url`
2. 减少下载时间：`-dt 8` （从12减到8秒）
3. 检查网络连接和防火墙设置

### Q8: 为什么有些IP完全测不出来？

**A:** 可能的原因：
- 该IP的服务临时不可用
- 网络连接问题
- 防火墙阻止
- 地理位置限制

建议重新运行测试，某次失败不代表始终失败。

---

## 高级用法

### 自定义测速地址

如果想用自己的服务器测试：

```bash
# 1. 确保你的服务器可以提供大文件下载
# 2. 使用自定义URL
./CloudflareSpeedTest -httping \
    -url https://your-server.com/large-file \
    -httping-code 200 ...
```

### 监控历史数据

保存并对比不同时间的测试结果：

```bash
# 创建监控脚本
cat > cfst_monitor.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
./CloudflareSpeedTest -httping \
    -cfcolo HKG,NRT,SIN,LAX \
    -url https://cf.xiu2.xyz/url \
    -n 15 -t 3 -dn 10 -dt 12 \
    -o results/result_${TIMESTAMP}.csv
EOF

chmod +x cfst_monitor.sh

# 定时运行（每天8点）
echo "0 8 * * * cd /path/to/cfst && ./cfst_monitor.sh" | crontab -
```

### 批量IP段测试

```bash
# 一次性测试多个IP段
./CloudflareSpeedTest \
    -ip "1.0.0.0/24,1.1.0.0/24,2.0.0.0/24" \
    -n 20 -t 2 -dd -tl 150 -p 100 \
    -o batch_results.csv
```

---

## 总结

通过四阶段联动测试，你可以：

1. ✅ **快速筛选** - TCP快速排除高延迟IP
2. ✅ **验证可用性** - HTTP确保应用真正可用
3. ✅ **评估性能** - 完整测试获得准确的性能数据
4. ✅ **持续监控** - 定期检查，及时发现问题

这种方法**成本低、效率高、结果准确**，是测试CDN接入点的最佳实践。

---

## 参考资源

- [CloudflareSpeedTest GitHub](https://github.com/XIU2/CloudflareSpeedTest)
- [IATA 机场代码查询](https://en.wikipedia.org/wiki/List_of_airports_by_IATA_code:_H)
- [HTTP 状态码](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)

