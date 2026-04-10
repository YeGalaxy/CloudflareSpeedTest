# 🎯 CloudflareSpeedTest 联动测试使用指南

## 📌 本次更新内容

为了帮助你更高效地使用 CloudflareSpeedTest，我们提供了：

1. **cfst_pipeline.sh** - 完整的四阶段自动化测试脚本
2. **SPEEDTEST_GUIDE.md** - 详细的测试指南（9700+ 字）
3. **QUICKSTART.md** - 快速参考卡片

## 🚀 快速开始（仅需2步）

### 第1步：运行自动化脚本
```bash
cd cfst-yx
chmod +x cfst_pipeline.sh
./cfst_pipeline.sh
```

### 第2步：查看结果
脚本会自动生成含时间戳的结果目录，包含：
- `01_tcp_candidates.csv` - TCP延迟筛选
- `02_http_verified.csv` - HTTP服务验证  
- `03_final_results.csv` - 最终排序结果

**注意**：二进制文件 `CloudflareSpeedTest` 已预编译好，无需 Go 环境

## 📚 文档体系

| 文件 | 大小 | 内容 | 适合 |
|------|------|------|------|
| **QUICKSTART.md** | 2.4KB | 常用命令、快速参考 | 快速查阅 |
| **SPEEDTEST_GUIDE.md** | 15KB | 完整原理、详细参数 | 深入理解 |
| **cfst_pipeline.sh** | 11KB | 自动化测试脚本 | 一键测试 |

## 🎯 四阶段联动工作流

```
原始IP列表 (5000+ IPs)
    ↓
阶段1: TCP筛选 (2-3分钟)
    ├─ 150+线程并发
    ├─ 过滤延迟>200ms
    └─ 输出: 50个候选IP
    ↓
阶段2: HTTP服务验证 (3-4分钟)
    ├─ 验证应用层可用性
    ├─ 状态码检查
    └─ 输出: 20个验证通过IP
    ↓
阶段3: 完整性能评估 (5-8分钟)
    ├─ 下载速度测试
    ├─ 稳定性评估
    └─ 输出: 10个最佳IP (排序)
    ↓
推荐用于hosts配置或其他工具
```

## 💡 核心优势

✅ **递进式筛选** - 从快到准，逐步精化  
✅ **数据复用** - 前一阶段的输出作为下一阶段的输入  
✅ **自动化处理** - 无需手动提取IP和传递参数  
✅ **成本递减** - TCP快→HTTP中速→完整测最少IP  
✅ **完整档案** - 保留每个阶段结果供后续分析  

## 🔧 自定义参数

### 针对你的网络环境

你的网络配置：**208M宽带 + 华为AX3 Pro路由器 + 有线连接**

```bash
# 推荐使用
./cfst_pipeline.sh -n 15 -r HKG,NRT,SIN,LAX -u https://cf.xiu2.xyz/url

# 或者快速模式（如果需要快速结果）
./cfst_pipeline.sh -n 20  # 更多线程，但对路由器压力更大

# 自定义地域
./cfst_pipeline.sh -r HKG,NRT  # 只测香港和东京
```

## 📊 三个典型场景

### 场景1: 快速找最快IP（5分钟）
```bash
./CloudflareSpeedTest -tp 443 -n 15 -t 2 -dn 0 -dd -tl 150 -p 10
```

### 场景2: 确保服务真正可用（15分钟）
```bash
./cfst_pipeline.sh  # 使用自动脚本，它会自动进行所有验证
```

### 场景3: 持续监控特定IP（1分钟/次）
```bash
./CloudflareSpeedTest -httping -url https://cf.xiu2.xyz/url \
    -ip "1.2.3.4" -t 1 -dn 0 -dd
```

## 🎓 学习路径

1. **新手**: 直接运行 `./cfst_pipeline.sh`，查看结果
2. **进阶**: 阅读 QUICKSTART.md，理解各参数含义
3. **高级**: 阅读 SPEEDTEST_GUIDE.md，掌握原理和高级用法

## ❓ 常见问题

**Q: 脚本在哪一步会卡住？**  
A: 最耗时的是阶段3的下载测试。TCP和HTTP阶段都很快。

**Q: 能否同时测试多个地域？**  
A: 可以，使用 `-r HKG,NRT,SIN,LAX,FRA` 指定多个地域。

**Q: 结果文件能用在哪里？**  
A: 最佳IP可以添加到 `/etc/hosts`、DNS配置、或其他工具。

**Q: TCP和HTTP延迟差这么大，为什么？**  
A: HTTP需要完整的应用层握手，包含TLS等协议。

## 📖 详细文档

- 快速参考: `cat QUICKSTART.md`
- 完整指南: `cat SPEEDTEST_GUIDE.md`
- 脚本源码: `cat cfst_pipeline.sh`

## 🔗 相关资源

- [CloudflareSpeedTest GitHub](https://github.com/XIU2/CloudflareSpeedTest)
- [IATA机场代码列表](https://en.wikipedia.org/wiki/List_of_airports_by_IATA_code)

---

**📝 总结**: 通过这个完整的联动测试方案，你可以快速、准确地找到最适合你网络的CDN接入点。所有复杂工作都已自动化，只需运行脚本即可！🎉
