# CloudflareSpeedTest 脚本 v2.0 - 智能参数检测方案

## 问题分析

在 v1.0 中，用户在使用脚本时遇到了参数混淆问题：

```bash
# 用户尝试
./cfst_pipeline.sh -tp 443 -n 5 -t 1 -dn 0 -dd -tl 200 -p 5 test.csv

# 得到错误
❌ 未知参数: -tp
```

**根本原因**：脚本和二进制程序有两套完全不同的参数系统，用户不清楚应该用哪一套。

---

## v2.0 解决方案

### 🎯 核心设计

实现**自动参数检测和智能路由**：

```
输入参数
    ↓
[检测参数类型]
    ↓
    ├─→ 检测到二进制参数 (-tp, -t, -dn, -dd 等)
    │   └─→ 自动调用二进制程序 ✓
    │
    ├─→ 检测到脚本参数 (-u, -r, -n 等)
    │   └─→ 执行四阶段自动化测试 ✓
    │
    └─→ 无参数或帮助
        └─→ 执行四阶段自动化测试（默认） ✓
```

### 🔧 技术实现

#### 1. 参数检测函数

```bash
# 检测单个参数是否是二进制参数
is_binary_param() {
    local param="$1"
    case "$param" in
        -tp|-t|-dn|-dt|-tl|-tll|-tlr|-sl|-p|-f|-ip|-o|-dd|-allip|-debug|-httping|-httping-code|-cfcolo)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 检查是否存在任何二进制参数
has_binary_params() {
    for param in "$@"; do
        if is_binary_param "$param"; then
            return 0  # 找到至少一个二进制参数
        fi
    done
    return 1  # 没有找到任何二进制参数
}
```

#### 2. 智能路由逻辑

```bash
# 主入口（精简版）
if [ $# -eq 0 ]; then
    # 无参数 → 四阶段测试
    main
else
    # 检查是否包含二进制参数
    if has_binary_params "$@"; then
        # 调用二进制程序
        run_binary_directly "$@"
    else
        # 解析脚本参数并执行四阶段测试
        if parse_args "$@"; then
            main
        else
            # 参数错误 → 显示帮助
            usage
        fi
    fi
fi
```

#### 3. 二进制程序直接调用

```bash
run_binary_directly() {
    log_info "检测到二进制程序参数，直接调用二进制程序..."
    log_info "参数: $@"
    
    if [ ! -f "$CFST_BIN" ]; then
        log_error "找不到二进制文件: $CFST_BIN"
        exit 1
    fi
    
    # 直接转发所有参数到二进制程序
    "$CFST_BIN" "$@"
}
```

---

## 📋 使用指南

### 方式1：四阶段自动化测试（推荐）

```bash
# 无参数 → 使用默认值
bash cfst_pipeline.sh

# 脚本参数 → 自动执行四阶段
bash cfst_pipeline.sh -n 20
bash cfst_pipeline.sh -r HKG,NRT,SIN,LAX
bash cfst_pipeline.sh -u https://example.com/file -n 10
```

**智能检测**：系统识别出这些是脚本参数 → 执行四阶段自动化测试

### 方式2：直接调用二进制程序

```bash
# 二进制参数 → 自动检测并调用二进制程序
bash cfst_pipeline.sh -tp 443 -n 5 -t 1 -dn 0 -dd -tl 200 -p 5 -o result.csv
bash cfst_pipeline.sh -httping -n 15 -dn 10 -dt 12 -o result.csv
bash cfst_pipeline.sh -ip "1.1.1.1,2.2.2.2" -n 10
```

**智能检测**：系统识别出这些是二进制参数 → 自动调用二进制程序

### 方式3：获取帮助

```bash
bash cfst_pipeline.sh -h     # 显示帮助信息
bash cfst_pipeline.sh --help
```

---

## 🎯 智能检测的参数列表

### 脚本特有参数（四阶段测试）

| 参数 | 检测优先级 |
|------|----------|
| `-u`, `--url` | 脚本参数 |
| `-r`, `--regions` | 脚本参数 |
| `-n`, `--threads` | 脚本参数（但与二进制 `-n` 有区别） |
| `-v`, `--verbose` | 脚本参数 |
| `-h`, `--help` | 脚本参数 |

**特殊情况**：`-n` 既是脚本参数也是二进制参数！
- 脚本版本：指定四阶段测试中的线程数
- 二进制版本：指定单个 IP 的测试线程数

**解决方法**：检测其他参数来判断
- 如果同时有 `-tp`, `-t`, `-dd` 等 → 用作二进制参数
- 如果是单独的 `-n` 或 与 `-u` 或 `-r` 组合 → 用作脚本参数

### 二进制特有参数（自动调用二进制程序）

| 参数 | 检测类型 |
|------|---------|
| `-tp` | ✓ 二进制专属 |
| `-t` | ✓ 二进制专属 |
| `-dn` | ✓ 二进制专属 |
| `-dt` | ✓ 二进制专属 |
| `-tl` | ✓ 二进制专属 |
| `-tll` | ✓ 二进制专属 |
| `-tlr` | ✓ 二进制专属 |
| `-sl` | ✓ 二进制专属 |
| `-p` | ✓ 二进制专属 |
| `-ip` | ✓ 二进制专属 |
| `-f` | ✓ 二进制专属 |
| `-o` | ✓ 二进制专属 |
| `-httping` | ✓ 二进制专属 |
| `-httping-code` | ✓ 二进制专属 |
| `-cfcolo` | ✓ 二进制专属 |
| `-dd` | ✓ 二进制专属 |
| `-allip` | ✓ 二进制专属 |
| `-debug` | ✓ 二进制专属 |

---

## 🧪 测试用例

### 测试1：无参数
```bash
$ bash cfst_pipeline.sh
ℹ️  🚀 CloudflareSpeedTest 联动测试脚本
ℹ️  版本: 2.0 | 时间戳: 20260412_120000
✅ 结果目录已创建: ...
📍 阶段 1: TCP快速筛选
# 执行四阶段测试 ✓
```

### 测试2：脚本参数
```bash
$ bash cfst_pipeline.sh -n 5 -r HKG,NRT
ℹ️  🚀 CloudflareSpeedTest 联动测试脚本
# 使用 n=5, regions=HKG,NRT 执行四阶段测试 ✓
```

### 测试3：二进制参数
```bash
$ bash cfst_pipeline.sh -tp 443 -n 5 -t 1 -dd -o result.csv
ℹ️  检测到二进制程序参数，直接调用二进制程序...
ℹ️  参数: -tp 443 -n 5 -t 1 -dd -o result.csv
# CloudflareSpeedTest.exe 输出 ✓
```

### 测试4：帮助信息
```bash
$ bash cfst_pipeline.sh -h
用法: cfst_pipeline.sh [选项]
# 显示完整帮助文本 ✓
```

---

## 🔄 参数流转示意

### 流程图

```
用户输入: bash cfst_pipeline.sh -tp 443 -n 5 -t 1 -dd
    │
    ├─→ $# = 8 (有参数)
    │
    ├─→ has_binary_params("${@}")
    │   │
    │   ├─→ 扫描参数...
    │   ├─→ 找到: -tp (is_binary_param returns 0)
    │   ├─→ 返回 true
    │   │
    │   └─→ 调用 run_binary_directly "$@"
    │       │
    │       ├─→ 检查二进制文件存在
    │       ├─→ 打印信息
    │       └─→ 执行: ./CloudflareSpeedTest.exe -tp 443 -n 5 -t 1 -dd
    │
    └─→ 二进制程序运行完毕 ✓
```

### 另一个例子

```
用户输入: bash cfst_pipeline.sh -n 20 -r HKG,NRT
    │
    ├─→ $# = 4 (有参数)
    │
    ├─→ has_binary_params("-n", "20", "-r", "HKG,NRT")
    │   │
    │   ├─→ 检查 "-n" → 脚本参数 (not binary)
    │   ├─→ 检查 "20" → 不是参数
    │   ├─→ 检查 "-r" → 脚本参数 (not binary)
    │   ├─→ 检查 "HKG,NRT" → 不是参数
    │   │
    │   └─→ 返回 false (没有找到二进制参数)
    │
    ├─→ parse_args "-n" "20" "-r" "HKG,NRT"
    │   │
    │   ├─→ THREADS=20
    │   ├─→ TEST_REGIONS=HKG,NRT
    │   │
    │   └─→ 返回 true
    │
    └─→ main()
        │
        ├─→ 执行四阶段测试
        ├─→ 使用 THREADS=20, TEST_REGIONS=HKG,NRT
        │
        └─→ 返回结果 ✓
```

---

## 💡 为什么这个方案更好

### ✅ 优点

| 特性 | v1.0 | v2.0 |
|------|------|------|
| 参数混淆 | ❌ 容易混淆 | ✅ 自动检测 |
| 学习成本 | ❌ 高（需要学两套系统） | ✅ 低（自动判断） |
| 用户体验 | ❌ 报错信息不清楚 | ✅ 智能路由 |
| 向后兼容 | ✅ 支持 | ✅ 完全兼容 |
| 灵活性 | ✅ 两种模式 | ✅ 两种模式 + 自动检测 |
| 新手友好 | ❌ 容易出错 | ✅ 错不了 |

### 🎯 使用场景

#### 新手用户
```bash
# 这样就行，不需要记住各种参数
bash cfst_pipeline.sh
bash cfst_pipeline.sh -n 10
```

#### 高级用户
```bash
# 需要完全控制时，直接传二进制参数
bash cfst_pipeline.sh -tp 443 -n 5 -t 1 -dn 10 -dt 12 -o result.csv
```

#### 不确定时
```bash
# 脚本会自动判断，无需担心
bash cfst_pipeline.sh -n 20 -r HKG,NRT  # 脚本参数 → 四阶段测试
bash cfst_pipeline.sh -tp 443 -n 5      # 二进制参数 → 直接二进制
```

---

## 📚 完整参数参考

### 脚本参数（四阶段自动化）

```
-u, --url URL           # 测速地址（默认: https://cf.xiu2.xyz/url）
-r, --regions REGIONS   # 地区码，逗号分隔（默认: HKG,NRT,SIN,LAX）
-n, --threads NUM       # 线程数（默认: 15）
-v, --verbose           # 显示详细输出
-h, --help              # 显示帮助
```

### 二进制参数（单阶段完全控制）

```
-tp PORT                # 测速端口（默认: 443）
-n THREADS              # 线程数（默认: 200）
-t TIMES                # 单IP测试次数（默认: 4）
-dn COUNT               # 下载测试IP数量（默认: 10）
-dt TIME                # 下载测试时间秒（默认: 10）
-tl MS                  # 延迟上限(ms)（默认: 9999）
-tll MS                 # 延迟下限(ms)（默认: 0）
-tlr RATE               # 丢包率上限（默认: 1.00）
-sl SPEED               # 下载速度下限(MB/s)（默认: 0）
-p COUNT                # 显示结果数量（默认: 10）
-ip IPS                 # 指定IP（逗号分隔）
-o FILE                 # 输出文件
-f FILE                 # IP数据文件
-httping                # 使用HTTP测试
-httping-code CODE      # HTTP状态码
-cfcolo CODES           # 地区过滤
-dd                     # 禁用下载测试
-allip                  # 测试所有IP
-debug                  # 调试模式
```

---

## 🚀 快速开始

### 3 步上手

#### 第1步：进入目录
```bash
cd cfst-yx
```

#### 第2步：运行脚本（任选一种）
```bash
# 方式A：四阶段自动化（推荐新手）
bash cfst_pipeline.sh

# 方式B：自定义参数
bash cfst_pipeline.sh -n 10 -r HKG,NRT

# 方式C：直接二进制（高级用户）
bash cfst_pipeline.sh -tp 443 -n 5 -t 1 -dd -o result.csv
```

#### 第3步：查看结果
```bash
# 四阶段模式的结果
ls speedtest_results_*/

# 或查看 CSV 结果
cat speedtest_results_*/03_final_results.csv
```

---

## 🔍 调试提示

### 如果出现问题

```bash
# 1. 检查二进制文件是否存在
ls -la CloudflareSpeedTest* 

# 2. 查看完整帮助
bash cfst_pipeline.sh -h

# 3. 运行脚本时查看详细输出
bash cfst_pipeline.sh -v

# 4. 测试二进制程序是否正常
./CloudflareSpeedTest -h  # Linux
./CloudflareSpeedTest.exe -h  # Windows
```

---

## 📝 更新日志

### v2.0（当前版本）
- ✨ 添加智能参数检测系统
- ✨ 自动路由到二进制程序或四阶段测试
- ✨ 改进用户体验和错误处理
- ✨ 完整向后兼容

### v1.0（之前版本）
- 基础的四阶段测试脚本
- 两套独立的参数系统
- 需要手动区分使用模式

---

## 📞 需要帮助？

- 查看脚本帮助：`bash cfst_pipeline.sh -h`
- 查看详细文档：`cat SPEEDTEST_GUIDE.md`
- 查看 Windows 指南：`cat WINDOWS_USAGE.md`
