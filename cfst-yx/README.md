# CloudflareSpeedTest v2.0 - 智能参数检测

一键测试 Cloudflare CDN 最快 IP，自动识别参数类型，无需区分脚本/二进制参数。

## 🚀 快速开始

```bash
cd cfst-yx

# 方式1：完整测试（推荐新手）
bash cfst_pipeline.sh

# 方式2：快速测试（5分钟）
bash cfst_pipeline.sh -n 5

# 方式3：自定义参数
bash cfst_pipeline.sh -n 10 -r HKG,NRT -u https://example.com/file

# 方式4：高级用法（直接二进制参数）
bash cfst_pipeline.sh -tp 443 -n 5 -t 1 -dd -o result.csv
```

**核心特性**：脚本自动识别参数类型，用什么参数都能正确执行 ✓

## 📋 使用场景

| 场景 | 命令 | 耗时 |
|------|------|------|
| 快速找最快 IP | `bash cfst_pipeline.sh -n 8 -r HKG,NRT,SIN,LAX` | 5-8 分钟 |
| 确保服务可用 | `bash cfst_pipeline.sh -u https://example.com/file -n 12` | 10-12 分钟 |
| 监控 CDN 接入点 | `bash cfst_pipeline.sh -n 15 -r HKG,NRT,SIN,LAX,SYD` | 15 分钟 |
| 完整性能评估 | `bash cfst_pipeline.sh -n 20` | 20-25 分钟 |

## 📖 常见问题

### Q: 脚本参数和二进制参数有什么区别？
**A**: 不用区分！脚本会自动识别。传什么参数都能正确执行。
- 传脚本参数（`-n`, `-r`, `-u`）→ 执行四阶段自动测试
- 传二进制参数（`-tp`, `-t`, `-dd`）→ 直接调用二进制程序

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
- 二进制模式：指定的 `-o` 文件

### Q: 怎么知道脚本选了哪种模式？
**A**: 看输出信息：
- 看到"阶段1"、"阶段2" → 四阶段模式
- 看到"检测到二进制程序参数" → 二进制模式

### Q: Windows 上怎么用？
**A**: 用 Git Bash 运行：
```bash
bash cfst_pipeline.sh -n 10
```

### Q: Linux/Mac 上怎么用？
**A**: 直接运行：
```bash
bash cfst_pipeline.sh -n 10
```

## 📚 完整参数参考

### 脚本参数（四阶段自动化）
```
-u, --url URL           指定测速地址 (默认: https://cf.xiu2.xyz/url)
-r, --regions REGIONS   指定地区码，逗号分隔 (默认: HKG,NRT,SIN,LAX)
-n, --threads NUM       指定线程数 (默认: 15)
-v, --verbose           显示详细输出
-h, --help              显示帮助信息
```

### 二进制参数（直接调用二进制程序）
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
  ↓ 输出：50+ 个候选 IP

【阶段2】HTTP 验证 (3-4 分钟)
  ↓ 输入：TCP 候选 IP
  ↓ 操作：HTTP 请求验证（确保服务可用）✨
  ↓ 输出：20+ 个验证通过的 IP

【阶段3】性能评估 (5-8 分钟)
  ↓ 输入：HTTP 验证 IP
  ↓ 操作：完整下载速度测试
  ↓ 输出：10+ 个最终结果（包含下载速度）✨

【输出】汇总报告
  → 显示前 5 个最快 IP
  → 保存 3 个 CSV 结果文件
```

## 📁 文件结构

```
cfst-yx/
├─ cfst_pipeline.sh         主脚本
├─ CloudflareSpeedTest      Linux 二进制
├─ CloudflareSpeedTest.exe  Windows 二进制
└─ README.md                本文件
```

## ✨ v2.0 核心改进

✅ **智能参数检测**
- 自动识别参数类型
- 用户无需区分脚本/二进制参数
- 错误处理更清晰

✅ **完全向后兼容**
- v1.0 所有命令继续工作
- 无破坏性更改

✅ **跨平台支持**
- Linux ✓
- Windows (Git Bash) ✓
- macOS ✓

## 🔧 获取帮助

```bash
# 查看脚本帮助
bash cfst_pipeline.sh -h

# 查看完整参数
bash cfst_pipeline.sh -h | grep -A 50 "二进制程序参数"
```

## 💡 使用建议

**新手**：直接运行 `bash cfst_pipeline.sh` 或 `bash cfst_pipeline.sh -n 10`

**中级**：根据场景选择，参考"使用场景"表格

**高级**：直接传二进制参数，完全掌控

## 📞 遇到问题？

| 问题 | 解决方案 |
|------|--------|
| 参数错误 | 用 `-h` 查看帮助 |
| 找不到二进制 | 检查 CloudflareSpeedTest 或 .exe 是否存在 |
| 结果为空 | 检查网络连接，尝试 `-n 5` 快速测试 |
| Windows 无法运行 | 用 Git Bash 而不是 CMD，确保使用 `bash` 命令 |

---

**更多了解脚本工作原理？** 查看脚本源码注释或运行 `bash cfst_pipeline.sh -h` 获取完整文档。
