# Windows Git Bash 使用指南

## 📌 概述 (v2.0 更新)

CloudflareSpeedTest 脚本现在支持**智能参数检测**！

✨ **新特性**：
- 自动识别参数类型，无需手动区分
- 传入脚本参数 → 执行四阶段测试
- 传入二进制参数 → 自动调用二进制程序
- **不再混淆和出错！**

在 Windows 上通过 Git Bash 使用 CloudflareSpeedTest：

1. **四阶段自动化测试** (`bash cfst_pipeline.sh -n 20`) - 推荐，简单易用
2. **直接二进制程序** (`bash cfst_pipeline.sh -tp 443 -n 5 ...`) - 高级用户，完全灵活
3. **纯二进制程序** (`./CloudflareSpeedTest.exe -tp 443 -n 5 ...`) - 直接调用二进制

**智能检测**：脚本会根据参数自动选择执行方式，你不需要担心用错模式！

---

## 方式1：四阶段自动化测试（推荐）✅

**推荐使用！** 脚本自动检测是否传入了脚本参数还是二进制参数，并自动选择执行方式。

### 特点
- ✅ 完整的四阶段递进式测试
- ✅ 自动处理 IP 数据流转
- ✅ 彩色进度显示和结果汇总
- ✅ 超级简单，开箱即用
- ✅ **v2.0 新增**：智能参数检测，无需区分参数类型

### 使用方法

```bash
cd cfst-yx

# 基础用法（使用默认参数）
bash cfst_pipeline.sh

# 指定线程数
bash cfst_pipeline.sh -n 5

# 指定地区和线程数
bash cfst_pipeline.sh -n 5 -r HKG,NRT

# 指定自定义 URL
bash cfst_pipeline.sh -u https://example.com/file -n 10

# 组合参数
bash cfst_pipeline.sh -n 5 -r HKG,NRT,SIN,LAX -u https://example.com/file
```

### 脚本参数说明

| 参数 | 说明 | 默认值 | 示例 |
|------|------|--------|------|
| `-u, --url URL` | 测速地址 | `https://cf.xiu2.xyz/url` | `bash cfst_pipeline.sh -u https://example.com/file` |
| `-r, --regions REGIONS` | 地区码，逗号分隔 | `HKG,NRT,SIN,LAX` | `bash cfst_pipeline.sh -r HKG,NRT` |
| `-n, --threads NUM` | 线程数 | `15` | `bash cfst_pipeline.sh -n 20` |
| `-v, --verbose` | 显示详细输出 | 否 | `bash cfst_pipeline.sh -v` |
| `-h, --help` | 显示帮助 | - | `bash cfst_pipeline.sh -h` |

### 输出结果

脚本会生成 `speedtest_results_YYYYMMDD_HHMMSS/` 目录，包含：

```
speedtest_results_20260410_204254/
├── 01_tcp_candidates.csv      (TCP筛选: 50个候选IP)
├── 02_http_verified.csv       (HTTP验证: 20个验证IP)
└── 03_final_results.csv       (最终结果: 10个最佳IP)
```

### 预计耗时

- 快速模式 (`-n 5`): ~8-10 分钟
- 标准模式 (`-n 15`): ~15-20 分钟
- 高性能模式 (`-n 20`): ~20-25 分钟

---

## 方式2：直接调用二进制程序

### 特点
- ✅ 完全灵活，支持所有参数
- ✅ 只进行单个阶段的测试
- ❌ 需要手动处理 IP 流转
- ❌ 参数众多，需要记忆

### 使用方法

```bash
cd cfst-yx

# 基础 TCP 延迟测试
./CloudflareSpeedTest.exe -tp 443 -n 5 -t 1 -dn 0 -dd -tl 200 -p 5 -o result.csv

# 完整下载测试
./CloudflareSpeedTest.exe -httping -url https://example.com/file \
    -n 15 -t 4 -dn 10 -dt 12 -tl 300 -p 10 -o result.csv

# 指定特定IP测试
./CloudflareSpeedTest.exe -ip "1.1.1.1,2.2.2.2" -n 10 -t 2 -o result.csv
```

### 常用参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-tp PORT` | 端口 | `-tp 443` |
| `-n THREADS` | 线程数 | `-n 5` |
| `-t TIMES` | 测试次数 | `-t 1` |
| `-dn COUNT` | 下载测试数量 | `-dn 10` |
| `-dt TIME` | 下载测试时间(秒) | `-dt 12` |
| `-tl MS` | 延迟上限(ms) | `-tl 200` |
| `-tll MS` | 延迟下限(ms) | `-tll 40` |
| `-tlr RATE` | 丢包率上限 | `-tlr 0.1` |
| `-sl SPEED` | 下载速度下限(MB/s) | `-sl 5` |
| `-p COUNT` | 显示结果数量 | `-p 10` |
| `-o FILE` | 输出文件 | `-o result.csv` |
| `-httping` | 使用HTTP测试 | `-httping` |
| `-cfcolo CODES` | 地区过滤 | `-cfcolo HKG,NRT` |
| `-dd` | 禁用下载测试 | `-dd` |
| `-ip IPS` | 指定IP | `-ip 1.1.1.1,2.2.2.2` |

### 输出结果

直接输出 CSV 文件，格式：

```
IP,延迟(ms),丢包率(%),下载速度(MB/s),...
1.1.1.1,45,0.00,180.5,...
2.2.2.2,52,0.05,175.2,...
```

---

## 常见错误

### ❌ 错误1：混淆参数系统

```bash
# ❌ 错误 - 将二进制参数传给脚本
$ bash cfst_pipeline.sh -tp 443 -n 5 -t 1 -dd -tl 200
未知参数: -tp

# ✅ 正确 - 脚本只有有限的参数
$ bash cfst_pipeline.sh -n 5

# ✅ 也可以直接调用二进制
$ ./CloudflareSpeedTest.exe -tp 443 -n 5 -t 1 -dd -tl 200 -o result.csv
```

### ❌ 错误2：在 PowerShell 中运行

```bash
# ❌ 在 PowerShell 中运行会失败
PS> bash cfst_pipeline.sh
bash: ./CloudflareSpeedTest.exe: 文件未找到

# ✅ 使用 Git Bash
MINGW64> bash cfst_pipeline.sh
✅ 成功
```

### ❌ 错误3：忘记指定输出文件

```bash
# ❌ 没有指定输出文件
$ ./CloudflareSpeedTest.exe -n 5 -t 1 -dd

# ✅ 指定输出文件
$ ./CloudflareSpeedTest.exe -n 5 -t 1 -dd -o result.csv
```

---

## 快速参考

### 常见场景

**快速测试（5分钟）**
```bash
bash cfst_pipeline.sh -n 5
```

**标准测试（15分钟）**
```bash
bash cfst_pipeline.sh -n 15
```

**高精度测试（20分钟）**
```bash
bash cfst_pipeline.sh -n 20 -r HKG,NRT,SIN,LAX
```

**仅TCP延迟测试（1分钟）**
```bash
./CloudflareSpeedTest.exe -n 5 -t 1 -dd -tl 200 -p 10 -o result.csv
```

**完整性能测试（10分钟）**
```bash
./CloudflareSpeedTest.exe -httping -url https://example.com/file \
    -n 15 -t 4 -dn 10 -dt 12 -tl 300 -p 10 -o result.csv
```

---

## 故障排除

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| `未知参数: -tp` | 混淆了参数系统 | 使用 `bash cfst_pipeline.sh` 而不是 `./cfst_pipeline.sh -tp...` |
| `文件未找到` | 不在 cfst-yx 目录 | `cd cfst-yx` 后再运行 |
| `Permission denied` | 脚本没有执行权限 | 使用 `bash cfst_pipeline.sh` 而不是 `./cfst_pipeline.sh` |
| `cannot execute binary` | 网络问题导致测试失败 | 检查网络连接或减少线程数 |

---

## 总结

| 场景 | 推荐方式 | 命令 |
|------|---------|------|
| 初次使用 | 脚本 | `bash cfst_pipeline.sh` |
| 快速测试 | 脚本 | `bash cfst_pipeline.sh -n 5` |
| 完整测试 | 脚本 | `bash cfst_pipeline.sh -n 15` |
| 仅TCP测试 | 二进制 | `./CloudflareSpeedTest.exe -n 5 -t 1 -dd -o result.csv` |
| 仅HTTP测试 | 二进制 | `./CloudflareSpeedTest.exe -httping -n 10 -o result.csv` |
| 高度定制 | 二进制 | 使用完整参数列表 |

---

## 更多信息

- 完整技术指南: `SPEEDTEST_GUIDE.md`
- 快速参考卡片: `QUICKSTART.md`
- 项目说明: `TESTING_GUIDE_README.md`
