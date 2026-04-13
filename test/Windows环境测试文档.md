# Windows 环境测试文档

## 1. 环境配置要求

### 1.1 硬件要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| 操作系统 | Windows 10 64位 | Windows 10/11 64位 |
| CPU | 双核 x86_64 | 四核及以上 |
| 内存 | 512MB | 2GB 及以上 |
| 磁盘空间 | 100MB | 500MB 及以上 |
| 网络 | 可访问 Cloudflare CDN | 稳定的互联网连接 |

### 1.2 软件依赖

| 软件 | 版本要求 | 用途 |
|------|----------|------|
| Go | 1.18+ | 编译源码（仅开发测试需要） |
| Git | 2.0+ | 获取源码（仅开发测试需要） |
| curl | 任意版本 | 验证上报结果（可选） |

### 1.3 测试文件准备

确保以下文件存在于程序目录中：

- `ip.txt`：IPv4 IP 段数据文件
- `ipv6.txt`：IPv6 IP 段数据文件（IPv6 测试需要）

## 2. 基础功能测试

### 2.1 程序启动测试

**测试步骤**：

1. 打开命令提示符（CMD）或 PowerShell
2. 导航到程序所在目录
3. 执行以下命令：

```powershell
.\CloudflareST.exe
```

**预期结果**：

- 程序正常启动，显示版本号信息
- 开始延迟测速，显示进度
- 延迟测速完成后开始下载测速
- 测速完成后显示结果表格
- 生成 `result.csv` 文件
- 显示"按下 回车键 或 Ctrl+C 退出"提示

**验证方法**：

```powershell
# 检查结果文件是否生成
Test-Path .\result.csv

# 查看结果文件内容
Get-Content .\result.csv | Select-Object -First 5
```

### 2.2 命令行参数测试

**测试步骤**：

1. 测试各主要参数组合：

```powershell
# 指定延迟上限和速度下限
.\CloudflareST.exe -tl 200 -sl 5

# 禁用下载测速
.\CloudflareST.exe -dd

# HTTPing 模式
.\CloudflareST.exe -httping

# 指定输出文件
.\CloudflareST.exe -o test_result.csv

# 指定 IP 段文件
.\CloudflareST.exe -f ip.txt

# 调试模式
.\CloudflareST.exe -debug -n 10 -dn 2
```

**预期结果**：

- 各参数组合正常执行
- `-tl 200 -sl 5`：仅输出延迟低于 200ms 且速度高于 5MB/s 的 IP
- `-dd`：结果按延迟排序而非速度排序
- `-httping`：使用 HTTP 协议测速
- `-o test_result.csv`：结果保存到指定文件
- `-debug`：输出更多调试信息

**验证方法**：

```powershell
# 验证输出文件
Test-Path .\test_result.csv

# 验证延迟上限
$data = Import-Csv .\result.csv
$data | Where-Object { [int]$_.'延迟速度' -gt 200 } | Measure-Object | Select-Object -ExpandProperty Count
# 结果应为 0
```

### 2.3 版本检查测试

**测试步骤**：

```powershell
.\CloudflareST.exe -v
```

**预期结果**：

- 显示当前版本号
- 检查版本更新
- 显示是否为最新版本

## 3. 结果上报功能测试

### 3.1 不填写上报目标（默认行为）

**测试步骤**：

```powershell
.\CloudflareST.exe -n 50 -dn 2
```

**预期结果**：

- 测速正常完成
- 不显示任何上报相关日志
- 不生成上报配置文件（或仅生成空配置）
- 结果正常保存在 `result.csv` 中
- 无错误信息

**验证方法**：

```powershell
# 确认结果文件存在且不为空
$file = Get-Item .\result.csv
$file.Length -gt 0
```

### 3.2 Cloudflare Workers API 上报测试

**前置条件**：

- 已部署 Cloudflare Workers API 服务
- 已获取 Workers 域名和 UUID

**测试步骤**：

```powershell
.\CloudflareST.exe -n 50 -dn 2 -report cloudflare -report-worker-domain your-domain.com -report-uuid your-uuid
```

**预期结果**：

- 测速正常完成
- 显示 `[上报] 正在上传到 Cloudflare Workers API...`
- 显示 `[上报] API 地址: https://your-domain.com/your-uuid/api/preferred-ips`
- 显示 `[上报] 成功上传 N 条优选IP到 Cloudflare Workers API`
- 生成 `.cloudflare_speedtest_config.json` 配置文件

**验证方法**：

```powershell
# 检查配置文件
Test-Path .\.cloudflare_speedtest_config.json
Get-Content .\.cloudflare_speedtest_config.json

# 使用 curl 验证上报结果
curl https://your-domain.com/your-uuid/api/preferred-ips
```

### 3.3 GitHub 上报测试

**前置条件**：

- 已创建 GitHub Personal Access Token（需要 `repo` 权限）
- 已创建 GitHub 仓库

**测试步骤**：

```powershell
.\CloudflareST.exe -n 50 -dn 2 -report github -report-github-token ghp_xxxx -report-github-owner username -report-github-repo repo
```

**预期结果**：

- 测速正常完成
- 显示 `[上报] 正在上传到 GitHub 仓库...`
- 显示 `[上报] 目标: username/repo (preferred_ips.txt)`
- 显示 `[上报] 成功创建/更新 GitHub 文件！`
- 显示 `[上报] 文件地址: https://raw.githubusercontent.com/...`

**验证方法**：

```powershell
# 使用 GitHub API 验证
$headers = @{ "Authorization" = "token ghp_xxxx" }
Invoke-RestMethod -Uri "https://api.github.com/repos/username/repo/contents/preferred_ips.txt" -Headers $headers
```

### 3.4 上报配置不完整测试

**测试步骤**：

```powershell
# Cloudflare 缺少 UUID
.\CloudflareST.exe -n 10 -dn 1 -report cloudflare -report-worker-domain example.com

# GitHub 缺少 Token
.\CloudflareST.exe -n 10 -dn 1 -report github -report-github-owner username -report-github-repo repo
```

**预期结果**：

- 显示红色错误信息：`[上报] 上报失败: Cloudflare Workers API 配置不完整，需要 worker_domain 和 uuid`
- 显示红色错误信息：`[上报] 上报失败: GitHub 配置不完整，需要 token、owner 和 repo`
- 测速结果仍然正常保存在本地 CSV 文件中

### 3.5 上报重试机制测试

**测试步骤**：

```powershell
# 使用无效域名触发重试
.\CloudflareST.exe -n 10 -dn 1 -report cloudflare -report-worker-domain invalid-domain-12345.com -report-uuid test-uuid
```

**预期结果**：

- 显示重试日志：`[上报] 第 1 次重试...`
- 显示重试日志：`[上报] 第 2 次重试...`
- 最终显示上报失败信息
- 最多重试 3 次

### 3.6 配置文件持久化测试

**测试步骤**：

1. 首次运行（命令行指定参数）：

```powershell
.\CloudflareST.exe -n 10 -dn 1 -report cloudflare -report-worker-domain example.com -report-uuid test-uuid
```

2. 第二次运行（仅指定 -report，其他参数从配置文件读取）：

```powershell
.\CloudflareST.exe -n 10 -dn 1 -report cloudflare
```

**预期结果**：

- 首次运行后生成 `.cloudflare_speedtest_config.json`
- 第二次运行时从配置文件读取 `worker_domain` 和 `uuid`
- 上报正常执行

**验证方法**：

```powershell
# 查看配置文件内容
Get-Content .\.cloudflare_speedtest_config.json
```

## 4. 定时任务功能测试

### 4.1 交互式创建定时任务

**前置条件**：

- 以管理员权限运行命令提示符
- Windows 任务计划程序服务正常运行

**测试步骤**：

1. 执行交互式命令：

```powershell
.\CloudflareST.exe -scheduler
```

2. 根据提示操作：
   - 选择"1. 创建新的定时任务"
   - 输入任务名称：`daily_test`
   - 选择调度类型"1. 每天"
   - 输入执行时间：`02:00`

**预期结果**：

- 显示当前定时任务列表（可能为空）
- 显示操作选择菜单
- 成功创建任务后显示：`[定时任务] 成功创建 Windows 任务: cfst_daily_test`

**验证方法**：

```powershell
# 使用 schtasks 查看任务
schtasks /query /tn "cfst_daily_test" /fo csv /nh

# 或通过 GUI 查看
taskschd.msc
```

### 4.2 命令行创建定时任务

**测试步骤**：

```powershell
# 创建每天定时任务
.\CloudflareST.exe -scheduler-cron "02:00" -scheduler-task-name daily_speed_test

# 创建每小时定时任务（需要交互式选择）
.\CloudflareST.exe -scheduler
```

**预期结果**：

- 成功创建定时任务
- 显示任务创建成功信息

**验证方法**：

```powershell
schtasks /query /tn "cfst_daily_speed_test" /fo csv /nh
```

### 4.3 列出定时任务

**测试步骤**：

```powershell
.\CloudflareST.exe -scheduler-list
```

**预期结果**：

- 显示所有以 `cfst_` 为前缀的定时任务
- 每个任务显示名称、状态、调度信息

### 4.4 删除定时任务

**测试步骤**：

```powershell
.\CloudflareST.exe -scheduler-delete daily_test
```

**预期结果**：

- 显示：`[定时任务] 成功删除任务: cfst_daily_test`

**验证方法**：

```powershell
# 确认任务已删除
schtasks /query /tn "cfst_daily_test" 2>&1
# 应显示"系统找不到指定的文件"
```

### 4.5 不设置定时任务（默认行为）

**测试步骤**：

```powershell
.\CloudflareST.exe -n 50 -dn 2
```

**预期结果**：

- 测速正常执行一次
- 不显示任何定时任务相关日志
- 程序正常退出
- 无后台进程残留

**验证方法**：

```powershell
# 确认没有残留进程
Get-Process | Where-Object { $_.Name -like "*CloudflareST*" }
# 结果应为空
```

## 5. 综合场景测试

### 5.1 测速 + 上报组合

**测试步骤**：

```powershell
.\CloudflareST.exe -n 100 -dn 5 -tl 200 -sl 5 -report cloudflare -report-worker-domain example.com -report-uuid your-uuid
```

**预期结果**：

- 测速正常完成
- 仅输出符合延迟和速度条件的 IP
- 上报成功
- 本地 CSV 文件和远程数据一致

### 5.2 测速 + 定时任务组合

**测试步骤**：

```powershell
# 创建带上报的定时任务
.\CloudflareST.exe -n 100 -dn 5 -report cloudflare -report-worker-domain example.com -report-uuid your-uuid -scheduler-cron "02:00" -scheduler-task-name daily_report
```

**预期结果**：

- 定时任务创建成功
- 定时任务命令包含 `-report cloudflare` 参数
- 到达指定时间后自动执行测速并上报

**验证方法**：

```powershell
# 查看任务详情
schtasks /query /tn "cfst_daily_report" /v /fo csv
```

### 5.3 长时间运行稳定性测试

**测试步骤**：

```powershell
# 大量 IP 测速
.\CloudflareST.exe -n 500 -dn 20 -allip
```

**预期结果**：

- 程序稳定运行不崩溃
- 内存使用稳定
- 结果文件完整

## 6. 常见问题排查

### 6.1 程序无法启动

| 症状 | 可能原因 | 解决方案 |
|------|----------|----------|
| 双击闪退 | 缺少命令行参数 | 使用 CMD/PowerShell 运行 |
| 权限不足 | 需要管理员权限 | 右键"以管理员身份运行" |
| 缺少 ip.txt | IP 段文件不存在 | 确保 ip.txt 在程序同目录 |
| 被杀毒软件拦截 | 误报 | 添加白名单 |

### 6.2 上报失败

| 症状 | 可能原因 | 解决方案 |
|------|----------|----------|
| 连接超时 | 网络问题 | 检查网络连接，使用代理 |
| 配置不完整 | 缺少必要参数 | 检查 -report-worker-domain 和 -report-uuid |
| 401/403 错误 | 认证失败 | 检查 GitHub Token 是否有效 |
| 404 错误 | Workers 域名或 UUID 错误 | 核对域名和 UUID |
| 重试3次后失败 | 服务端不可用 | 检查 Workers 服务是否正常运行 |

### 6.3 定时任务问题

| 症状 | 可能原因 | 解决方案 |
|------|----------|----------|
| 创建失败 | 权限不足 | 以管理员身份运行 |
| 任务不执行 | 任务被禁用 | 使用 `schtasks /change /enable` 启用 |
| 执行报错 | 路径包含空格 | 使用引号包裹路径 |
| 找不到任务 | 名称不匹配 | 使用 `-scheduler-list` 查看实际名称 |

### 6.4 结果文件问题

| 症状 | 可能原因 | 解决方案 |
|------|----------|----------|
| 结果为空 | 所有 IP 不符合条件 | 放宽 -tl/-sl 条件 |
| 文件编码异常 | Excel 打开乱码 | 使用记事本或 UTF-8 兼容编辑器 |
| 无法写入 | 文件被占用 | 关闭占用程序后重试 |

## 7. 测试检查清单

### 7.1 基础功能

- [ ] 程序正常启动和退出
- [ ] 默认参数测速正常
- [ ] 自定义参数测速正常
- [ ] 结果文件正确生成
- [ ] 版本检查功能正常

### 7.2 上报功能

- [ ] 不填写上报目标时正常测速
- [ ] Cloudflare Workers API 上报成功
- [ ] GitHub 上报成功
- [ ] 上报配置不完整时正确报错
- [ ] 重试机制正常工作
- [ ] 配置文件持久化正常

### 7.3 定时任务

- [ ] 交互式创建任务成功
- [ ] 命令行创建任务成功
- [ ] 列出任务正常
- [ ] 删除任务成功
- [ ] 不设置定时任务时正常退出

### 7.4 综合场景

- [ ] 测速 + 上报组合正常
- [ ] 测速 + 定时任务组合正常
- [ ] 长时间运行稳定
