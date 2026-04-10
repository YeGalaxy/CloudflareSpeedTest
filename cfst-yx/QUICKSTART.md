# CloudflareSpeedTest 快速参考卡

## 🚀 一键启动

**Linux/Mac:**
```bash
cd cfst-yx
chmod +x cfst_pipeline.sh
./cfst_pipeline.sh
```

**Windows (Git Bash/WSL):**
```bash
cd cfst-yx
bash cfst_pipeline.sh
```

**带参数：**
```bash
./cfst_pipeline.sh -n 20 -r HKG,NRT              # 指定线程和地区
./cfst_pipeline.sh -u https://example.com/file   # 自定义URL
```

## 📊 四阶段流程（自动处理）

```
TCP筛选 (2-3分钟)
  ↓ 50个IP
HTTP验证 (3-4分钟)  
  ↓ 20个IP
性能评估 (5-8分钟)
  ↓ 10个最快IP
持续监控 (可选)
```

## 🎯 快速命令

### 场景1: 快速找最快IP
```bash
./CloudflareSpeedTest -tp 443 -n 15 -t 2 -dn 0 -dd \
    -tl 150 -p 10 -o result.csv
```

### 场景2: 验证服务可用
```bash
./CloudflareSpeedTest -httping -cfcolo HKG,NRT,SIN,LAX \
    -httping-code 200 -url https://example.com/test-file \
    -n 15 -t 3 -tl 250 -p 10 -o result.csv
```

### 场景3: 完整性能测试
```bash
./CloudflareSpeedTest -httping -cfcolo HKG,NRT,SIN,LAX \
    -httping-code 200 -url https://example.com/test-file \
    -n 15 -t 4 -dn 10 -dt 12 -sl 5 -tl 300 -tlr 0.1 \
    -p 10 -o result.csv
```

## 📍 地域代码

| 代码 | 地区 | 代码 | 地区 |
|------|------|------|------|
| HKG | 香港 | LAX | 洛杉矶 |
| NRT | 东京 | SJC | 圣何塞 |
| SIN | 新加坡 | FRA | 法兰克福 |
| SYD | 悉尼 | MAD | 马德里 |

## ⚙️ 关键参数速查

| 参数 | 说明 | 建议值 |
|------|------|--------|
| `-n` | 线程数 | 15-20 |
| `-t` | 测试次数 | 2-4 |
| `-dn` | 下载测试数量 | 10 |
| `-dt` | 下载时间(秒) | 12 |
| `-tl` | 延迟上限(ms) | 200-300 |
| `-tp` | 端口 | 443 |

## 🔄 使用之前

```bash
# 直接运行脚本即可，无需任何依赖
cd cfst-yx
chmod +x cfst_pipeline.sh
./cfst_pipeline.sh
```

**二进制文件已预编译好，无需 Go 环境！**

## 📁 输出文件

自动脚本会生成：
- `01_tcp_candidates.csv` - TCP筛选结果
- `02_http_verified.csv` - HTTP验证结果
- `03_final_results.csv` - 最终排序结果

## 🐛 故障排除

| 问题 | 解决方案 |
|------|----------|
| 找不到二进制文件 | 文件已在 cfst-yx 文件夹中，无需编译 |
| 权限被拒绝 | 运行 `chmod +x cfst_pipeline.sh` |
| 测试超时 | 检查网络、减少线程数 |
| 找不到IP | 检查根目录的 `ip.txt` 或 `-ip` 参数 |

## 💡 提示

- TCP测试最快，用来快速筛选
- HTTP测试真实，用来验证服务
- 完整测试最准，用来评估性能
- 有线连接比WiFi稳定，可用更多线程
- 自定义URL要求文件存在且可访问

