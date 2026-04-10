# CloudflareSpeedTest v2.0 - 使用示例

## 📋 目录

1. [基础示例](#基础示例)
2. [实际场景](#实际场景)
3. [高级用法](#高级用法)
4. [常见问题](#常见问题)

---

## 基础示例

### 示例1：一键启动四阶段测试（推荐）

```bash
$ cd cfst-yx
$ bash cfst_pipeline.sh
```

**输出**：
```
ℹ️  🚀 CloudflareSpeedTest 联动测试脚本
ℹ️  版本: 2.0 | 时间戳: 20260412_150000
✅ 结果目录已创建: /path/to/speedtest_results_20260412_150000

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 阶段 1: TCP快速筛选
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ️  使用TCP协议测试所有IP延迭，快速定位候选集合
ℹ️  预计耗时: 2-3 分钟
...
✅ TCP测试完成！找到 48 个候选IP
```

### 示例2：快速测试（5个线程）

```bash
$ bash cfst_pipeline.sh -n 5
```

**说明**：
- 使用 5 个线程（而不是默认的 15 个）
- 快速模式，预计 8-10 分钟完成
- 适合时间有限的情况

### 示例3：指定测试地区

```bash
$ bash cfst_pipeline.sh -n 10 -r HKG,NRT
```

**说明**：
- `-n 10`: 使用 10 个线程
- `-r HKG,NRT`: 只测试香港(HKG)和东京(NRT)两个地区
- 地区码可选值: HKG, NRT, SIN, LAX, SYD, SEA, 等等

### 示例4：自定义测速地址

```bash
$ bash cfst_pipeline.sh -u https://example.com/file -n 15
```

**说明**：
- `-u`: 自定义测速文件地址
- 用于测试你自己的服务器可用性
- 脚本会验证每个 IP 都能访问这个地址

---

## 实际场景

### 场景1：快速找最快的 IP（5-8 分钟）

**需求**：我想快速找到响应最快的 IP 地址

```bash
$ bash cfst_pipeline.sh -n 8 -r HKG,NRT,SIN,LAX
```

**预期结果**：
```
📊 测试完成！汇总报告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 所有结果保存在: /path/to/speedtest_results_20260412_150000/

📈 最终排序结果 (前5快):
  🌐 1.2.3.4           │ 延迟:     25 ms │ 下载: 150 MB/s
  🌐 1.2.3.5           │ 延迟:     26 ms │ 下载: 145 MB/s
  🌐 1.2.3.6           │ 延迟:     28 ms │ 下载: 140 MB/s
  🌐 1.2.3.7           │ 延迟:     31 ms │ 下载: 135 MB/s
  🌐 1.2.3.8           │ 延迟:     35 ms │ 下载: 125 MB/s

🏆 最快IP: 1.2.3.4
```

### 场景2：确保服务真正可用（10-12 分钟）

**需求**：我要测试 CDN IP 是否真的能访问我的服务

```bash
$ bash cfst_pipeline.sh -u https://myservice.example.com/file -n 12
```

**工作流程**：
1. 阶段1：TCP 连接测试（排除网络不通的 IP）
2. 阶段2：HTTP 请求验证（排除无法访问服务的 IP）✨ 关键
3. 阶段3：下载速度评估（排除慢速 IP）

**优势**：不仅测试网络延迟，还确保真实服务可用！

### 场景3：监控 CDN 就近接入点（15 分钟）

**需求**：我想评估不同地区的 CDN 接入点性能

```bash
$ bash cfst_pipeline.sh -n 15 -r HKG,NRT,SIN,LAX,SYD
```

**结果分析**：
- 查看最终结果文件
- 按地区统计最快 IP
- 了解不同地区的接入质量

### 场景4：评估用户真实体验（20-25 分钟）

**需求**：完整评估从这个网络到 CDN 的真实体验

```bash
$ bash cfst_pipeline.sh -n 20
```

**完整流程**：
1. 大量候选 IP（50+）
2. 多次验证（确保结果稳定）
3. 完整下载测试（真实速度测量）
4. 综合排名（延迟 + 丢包率 + 下载速度）

**特点**：最全面，最耗时，但结果最可靠

---

## 高级用法

### 高级示例1：直接调用二进制程序 - TCP 快速筛选

如果你需要更细粒度的控制，可以直接传入二进制参数：

```bash
$ bash cfst_pipeline.sh -tp 443 -n 5 -t 1 -dn 0 -dd -tl 200 -p 10 -o result.csv
```

**参数说明**：
- `-tp 443`: 使用 443 端口 TCP 测试
- `-n 5`: 5 个线程
- `-t 1`: 每个 IP 测试 1 次
- `-dn 0`: 不进行下载测试
- `-dd`: 禁用下载阶段
- `-tl 200`: 延迟上限 200ms
- `-p 10`: 显示前 10 个结果
- `-o result.csv`: 输出到 result.csv

**什么时候用**：
- 需要极快的筛选（几分钟内）
- 只关心网络延迟，不关心应用层
- 脚本参数满足不了需求

### 高级示例2：直接调用二进制程序 - HTTP 完整测试

```bash
$ bash cfst_pipeline.sh -httping \
    -url https://example.com/file \
    -cfcolo HKG,NRT,SIN \
    -n 20 \
    -t 3 \
    -dn 15 \
    -dt 12 \
    -tl 300 \
    -p 20 \
    -o result_full.csv
```

**参数说明**：
- `-httping`: 使用 HTTP 测试（不仅 TCP）
- `-url https://example.com/file`: 要测速的地址
- `-cfcolo HKG,NRT,SIN`: 地区过滤
- `-dn 15`: 15 个 IP 进行下载测试
- `-dt 12`: 每个下载测试 12 秒
- `-tl 300`: 延迟上限 300ms
- `-p 20`: 显示前 20 个结果

### 高级示例3：测试特定 IP 列表

```bash
# 保存 IP 到文件
echo "1.1.1.1" > ips.txt
echo "1.0.0.1" >> ips.txt
echo "2.2.2.2" >> ips.txt

# 测试这些 IP
bash cfst_pipeline.sh -f ips.txt -n 10 -o result.csv
```

或者直接指定 IP：

```bash
bash cfst_pipeline.sh -ip "1.1.1.1,1.0.0.1,2.2.2.2" -n 10 -o result.csv
```

### 高级示例4：调试模式

```bash
$ bash cfst_pipeline.sh -n 5 -debug
```

**作用**：
- 显示详细的调试信息
- 适合诊断问题
- 输出会更详细

---

## 常见问题

### Q1：两种模式是什么时候自动选择？

**A**：
- 检测到 `-tp`, `-t`, `-dn`, `-dd`, `-httping` 等 → **二进制模式**
- 检测到 `-u`, `-r`, `-n` (单独) 等 → **四阶段模式**
- 都没有检测到 → **四阶段模式（默认）**

### Q2：`-n` 参数在两种模式下是否冲突？

**A**：
- 在**四阶段模式**中：`-n` 表示线程数（整个四阶段共用）
- 在**二进制模式**中：`-n` 也表示线程数（二进制程序的参数）
- 脚本会根据其他参数自动判断

例如：
```bash
bash cfst_pipeline.sh -n 10          # 四阶段模式，线程=10
bash cfst_pipeline.sh -n 10 -tp 443  # 二进制模式，线程=10
```

### Q3：结果文件在哪里？

**A**：
- 四阶段模式：`speedtest_results_YYYYMMDD_HHMMSS/` 目录
  - `01_tcp_candidates.csv`
  - `02_http_verified.csv`
  - `03_final_results.csv`
- 二进制模式：指定的输出文件（或标准输出）

### Q4：如何导出并使用最快的 IP？

**A**：
```bash
# 1. 运行测试
bash cfst_pipeline.sh

# 2. 获取最快 IP
tail -n 1 speedtest_results_*/03_final_results.csv | awk -F',' '{print $1}'

# 3. 添加到 /etc/hosts（Linux/Mac）
# echo "$BEST_IP example.com" | sudo tee -a /etc/hosts

# 或在应用配置中使用
# 在代码中指定 IP，或配置 CDN 参数
```

### Q5：脚本报错"找不到二进制文件"怎么办？

**A**：
```bash
# 检查文件是否存在
ls -la CloudflareSpeedTest*

# 应该看到：
# -rwxr-xr-x  CloudflareSpeedTest (Linux)
# -rwxr-xr-x  CloudflareSpeedTest.exe (Windows)

# 如果不存在，确保在 cfst-yx 目录中
cd cfst-yx
```

### Q6：四阶段和二进制模式有什么区别？

**A**：

| 方面 | 四阶段模式 | 二进制模式 |
|------|-----------|---------|
| 复杂度 | 简单易用 | 需要理解各参数 |
| 自动化 | 完全自动 | 手动控制 |
| 结果处理 | 自动流转 | 需要手动处理 |
| 灵活性 | 中等 | 高（完全控制） |
| 时间 | 较长（多阶段） | 较快（单阶段） |
| 学习成本 | 低 | 高 |
| 适合人群 | 新手 | 高级用户 |

**简单说**：
- 新手用四阶段 ✓
- 高级用户用二进制 ✓

### Q7：可以同时运行多个测试吗？

**A**：可以，但需要注意：
```bash
# 终端1
bash cfst_pipeline.sh -n 5 &

# 终端2（稍后启动，避免争夺系统资源）
sleep 30
bash cfst_pipeline.sh -n 5 &

# 查看进程
jobs
```

### Q8：如何定期监控 CDN 性能？

**A**：使用 cron 定时任务：
```bash
# 编辑 crontab
crontab -e

# 每天 9:00 和 18:00 运行测试
0 9,18 * * * cd /path/to/cfst-yx && bash cfst_pipeline.sh -n 10 >> cron.log 2>&1
```

---

## 🎓 学习路径

### 初级用户
1. ✅ 学会基础用法：`bash cfst_pipeline.sh`
2. ✅ 尝试自定义参数：`bash cfst_pipeline.sh -n 10`
3. ✅ 查看结果文件：`cat speedtest_results_*/03_final_results.csv`

### 中级用户
1. ✅ 掌握所有脚本参数
2. ✅ 理解四阶段流程
3. ✅ 能够解释各个指标

### 高级用户
1. ✅ 掌握二进制程序参数
2. ✅ 能够处理复杂场景
3. ✅ 可以开发自己的分析工具

---

## 需要帮助？

- 📖 查看完整文档：`cat SPEEDTEST_GUIDE.md`
- 🔧 查看脚本帮助：`bash cfst_pipeline.sh -h`
- 🎯 查看设计文档：`cat SOLUTION_v2.0.md`
- 🪟 查看 Windows 指南：`cat WINDOWS_USAGE.md`
