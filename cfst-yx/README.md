# CloudflareSpeedTest v2.1 - 混合参数模式

一键测试 Cloudflare CDN 最快 IP，支持脚本参数与流水线二进制参数自由混用，通过 `--raw` 标志直接调用二进制。

## 🚀 快速开始

```bash
cd cfst-yx

# 方式1：完整测试（推荐新手）
bash cfst_pipeline.sh

# 方式2：快速测试（5分钟）
bash cfst_pipeline.sh -n 5

# 方式3：自定义参数（脚本 + 流水线二进制参数混用）
bash cfst_pipeline.sh -n 10 -r HKG,NRT --latency 150 --speed-limit 0.25

# 方式4：高级用法（--raw 直接调用二进制）
bash cfst_pipeline.sh --raw -tp 443 -n 5 -t 1 -dd -o result.csv
```

**核心特性**：脚本参数与流水线二进制参数可自由混用 ✓

## 📋 使用场景

| 场景 | 命令 | 耗时 |
|------|------|------|
| 快速找最快 IP | `bash cfst_pipeline.sh -n 8 -r HKG,NRT,SIN,LAX` | 5-8 分钟 |
| 确保服务可用 | `bash cfst_pipeline.sh -u https://example.com/file -n 12` | 10-12 分钟 |
| 严格性能筛选 | `bash cfst_pipeline.sh --latency 100 --loss-rate 0.002 --speed-limit 0.5` | 15 分钟 |
| 监控 CDN 接入点 | `bash cfst_pipeline.sh -n 15 -r HKG,NRT,SIN,LAX,SYD` | 15 分钟 |
| 完整性能评估 | `bash cfst_pipeline.sh -n 20 --output result.csv` | 20-25 分钟 |

## 📖 常见问题

### Q: 脚本参数和流水线二进制参数有什么区别？
**A**: 可以自由混用，不需要区分：
- 脚本参数（`-n`, `-r`, `-u`）→ 控制流水线行为
- 流水线二进制参数（`--port`, `--latency`, `--speed-limit` 等）→ 传递给各阶段的二进制调用
- 两者可以自由组合

### Q: 怎么直接调用二进制程序？
**A**: 使用 `--raw` 标志：
```bash
bash cfst_pipeline.sh --raw -tp 443 -n 5 -dd -o result.csv
```

### Q: 参数怎么传？
**A**: 参考下面的完整参数表，或者用脚本帮助：
```bash
bash cfst_pipeline.sh -h
```

### Q: 结果文件在哪里？
**A**: 
- 四阶段测试：`speedtest_results_YYYYMMDD_HHMMSS/` 目录
  - `01_tcp_candidates.csv` (第1阶段结果)
  - `02_http_verified.csv` (第2阶段结果)
  - `03_final_results.csv` (最终结果 - 最快的 IP)
- 使用 `--output result.csv` → 额外复制最终结果到指定文件
- `--raw` 模式：指定的 `-o` 文件

### Q: 怎么知道脚本选了哪种模式？
**A**: 看输出信息：
- 看到"阶段1"、"阶段2" → 四阶段流水线模式
- 看到"直接二进制模式" → `--raw` 模式

### Q: Windows 上怎么用？
**A**: 用 Git Bash 运行：
```bash
bash cfst_pipeline.sh -n 10
```

### Q: 在 Windows 上显示『阶段1失败』怎么办？
**A**: 按以下步骤排查：

1. **确保文件完整**：检查 cfst-yx/ 文件夹中是否有这些文件
   ```bash
   ls -la CloudflareSpeedTest.exe ip.txt ipv6.txt
   ```
   如果缺少 `ip.txt` 或 `ipv6.txt`，需要从根目录复制：
   ```bash
   cd cfst-yx
   cp ../ip.txt .
   cp ../ipv6.txt .
   ```

2. **更新到最新版本**
   ```bash
   cd cfst-yx
   git pull origin cfst-yx
   ```

3. **使用 bash 而不是 sh**
   ```bash
   # ✅ 正确
   bash cfst_pipeline.sh -n 5
   
   # ❌ 错误
   sh cfst_pipeline.sh -n 5
   ```

4. **检查二进制权限** (如果用 WSL)
   ```bash
   chmod +x CloudflareSpeedTest
   chmod +x CloudflareSpeedTest.exe
   ```

5. **查看详细错误**（调试模式）
   ```bash
   bash -x cfst_pipeline.sh -n 3 2>&1 | head -100
   ```

### Q: Linux/Mac 上怎么用？
**A**: 直接运行：
```bash
bash cfst_pipeline.sh -n 10
```

### Q: 速度单位怎么换算？
**A**: `--speed-limit` 参数使用 **MB/s**，换算关系：
- 1 MB/s = 8 Mbps
- 2 Mbps = 0.25 MB/s → `--speed-limit 0.25`
- 10 Mbps = 1.25 MB/s → `--speed-limit 1.25`

### Q: 丢包率怎么设置？
**A**: `--loss-rate` 参数范围 0~1：
- 0.2% = 0.002 → `--loss-rate 0.002`
- 1% = 0.01 → `--loss-rate 0.01`
- 10% = 0.1 → `--loss-rate 0.1`

## 📚 完整参数参考

### 脚本参数（控制流水线行为）
```
-u, --url URL           指定测速地址 (默认: https://cf.xiu2.xyz/url)
-r, --regions REGIONS   指定地区码，逗号分隔 (默认: HKG,NRT,SIN,LAX)
-n, --threads NUM       指定线程数 (默认: 15)
-v, --verbose           显示详细输出
-h, --help              显示帮助信息
```

### 流水线二进制参数（传递给各阶段，与脚本参数可混用）
```
--port PORT             测速端口 (默认: 443)
--latency MS            延迟上限 (默认: 200)
--results COUNT         每阶段显示结果数 (默认: 阶段1=50, 阶段2=20, 阶段3=10)
--times COUNT           单IP测试次数 (默认: 阶段1=2, 阶段2=3, 阶段3=4)
--download-count N      下载测试数量 (默认: 10)
--download-time SEC     下载测试时间秒 (默认: 12)
--speed-limit MB        下载速度下限MB/s (默认: 5)
--loss-rate RATE        丢包率上限0~1 (默认: 阶段1/2=无, 阶段3=0.1)
--ip-file FILE          IP数据文件 (默认: ip.txt)
--output FILE           最终结果输出文件名 (默认: 仅保存到时间戳目录)
--extra ARGS            额外二进制参数，引号包裹
```

### 直接二进制模式（--raw）
```
--raw                   直接调用二进制，后续参数原样传递
```
二进制完整参数参考：
```
-tp PORT                测速端口 (默认: 443)
-n THREADS              线程数 (默认: 200)
-t TIMES                单IP测试次数 (默认: 4)
-dn COUNT               下载测试数量 (默认: 10)
-dt TIME                下载测试时间秒 (默认: 10)
-tl MS                  延迟上限(ms) (默认: 9999)
-tll MS                 延迟下限(ms) (默认: 0)
-tlr RATE               丢包率上限 (默认: 1.00)
-sl SPEED               下载速度下限(MB/s) (默认: 0)
-p COUNT                显示结果数量 (默认: 10)
-o FILE                 输出文件
-ip IPS                 指定IP (逗号分隔)
-httping                使用HTTP测试
-httping-code CODE      HTTP状态码
-cfcolo CODES           地区过滤
-dd                     禁用下载测试
-url URL                测速地址
-f FILE                 IP数据文件
-allip                  测试所有IP
-debug                  调试模式
```

## 🎯 四阶段工作流程

```
【阶段1】TCP 快速筛选 (2-3 分钟)
  ↓ 输入：所有 IP
  ↓ 操作：TCP 延迟测试
  ↓ 参数：--port, --latency, --times, --loss-rate(可选)
  ↓ 输出：50+ 个候选 IP

【阶段2】HTTP 验证 (3-4 分钟)
  ↓ 输入：TCP 候选 IP
  ↓ 操作：HTTP 请求验证（确保服务可用）
  ↓ 参数：--latency(+50), --loss-rate(可选), -r/-u
  ↓ 输出：20+ 个验证通过的 IP

【阶段3】性能评估 (5-8 分钟)
  ↓ 输入：HTTP 验证 IP
  ↓ 操作：完整下载速度测试
  ↓ 参数：--latency(+100), --speed-limit, --loss-rate, --download-*
  ↓ 输出：10+ 个最终结果（包含下载速度）

【输出】汇总报告
  → 显示前 5 个最快 IP
  → 保存 3 个 CSV 结果文件
  → --output 时额外复制到指定文件
```

## 📁 文件结构

```
cfst-yx/
├─ cfst_pipeline.sh         主脚本（v2.1）
├─ CloudflareSpeedTest      Linux 二进制
├─ CloudflareSpeedTest.exe  Windows 二进制
├─ ip.txt                   IPv4 地址列表（二进制程序需要）
├─ ipv6.txt                 IPv6 地址列表（二进制程序需要）
└─ README.md                本文件
```

⚠️ **重要**：请确保 `ip.txt` 和 `ipv6.txt` 文件在 cfst-yx/ 文件夹中，
否则二进制程序无法运行！

## ✨ v2.1 核心改进

✅ **混合参数模式**
- 脚本参数与流水线二进制参数可自由混用
- `--long-name` 形式区分流水线参数与二进制短参数
- `--raw` 显式进入直接二进制模式

✅ **新增参数**
- `--loss-rate` 丢包率控制
- `--output` 自定义结果文件名
- `--port` / `--latency` / `--speed-limit` 等流水线级参数
- `--extra` 传递任意额外二进制参数

✅ **健壮性提升**
- 全局数组替代 echo 返回，消除分词风险
- `--raw` 正确捕获后续所有二进制参数
- 动态日志反映实际参数值

✅ **完全向后兼容**
- 原有脚本参数命令继续工作
- 四阶段流水线行为不变

✅ **跨平台支持**
- Linux ✓
- Windows (Git Bash) ✓
- macOS ✓

## 🔧 获取帮助

```bash
# 查看脚本帮助
bash cfst_pipeline.sh -h
```

## 💡 使用建议

**新手**：直接运行 `bash cfst_pipeline.sh` 或 `bash cfst_pipeline.sh -n 10`

**中级**：根据场景混用参数，参考"使用场景"表格

**高级**：使用 `--raw` 直接调用二进制，完全掌控

## 📞 遇到问题？

| 问题 | 解决方案 |
|------|--------|
| 参数错误 | 用 `-h` 查看帮助，二进制参数需加 `--raw` |
| 找不到二进制 | 检查 CloudflareSpeedTest 或 .exe 是否存在 |
| 结果为空 | 检查网络连接，尝试 `-n 5` 快速测试 |
| Windows 无法运行 | 用 Git Bash 而不是 CMD，确保使用 `bash` 命令 |
| 速度单位不对 | `--speed-limit` 是 MB/s，2Mbps = 0.25 MB/s |

---

**更多了解脚本工作原理？** 查看脚本源码注释或运行 `bash cfst_pipeline.sh -h` 获取完整文档。
