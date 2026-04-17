# Docker 定时任务使用指南

本文档介绍如何使用 Docker 运行 CloudflareSpeedTest，并配置持久化的定时任务。

## 核心改进

参考 yx-tools 项目的设计，我们实现了以下功能：

1. **Crontab 持久化**：定时任务保存到 `/app/data/crontab` 文件
2. **容器重启自动恢复**：启动时自动恢复之前配置的定时任务
3. **容器始终保持运行**：使用 `tail -f /dev/null` 保持容器存活
4. **定期保存 crontab**：每 5 分钟自动保存一次，防止丢失

## 快速开始

### 方式一：使用环境变量配置定时任务（推荐）

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="*/15 * * * *" \
  -e CFST_N=200 \
  -e CFST_T=4 \
  -e CFST_DN=10 \
  -e CFST_REPORT="cloudflare,github" \
  -e CFST_REPORT_WORKER_DOMAIN="bj.tolive.eu.org" \
  -e CFST_REPORT_UUID="81772339-5f60-4414-889f-ef01a62e5b21" \
  -e CFST_REPORT_GITHUB_TOKEN="ghp_xxxx" \
  -e CFST_REPORT_GITHUB_OWNER="YeGalaxy" \
  -e CFST_REPORT_GITHUB_REPO="node" \
  cfst:latest
```

**说明**：
- `-d`：后台运行容器
- `--restart=always`：容器异常退出时自动重启
- `-e CFST_CRON`：设置 cron 表达式（每 15 分钟执行一次）
- `-v ./cfst_data:/app/data`：挂载数据目录，保存测速结果和定时任务文件

### 方式二：使用宿主机 Crontab（更灵活）

在宿主机上设置定时任务，定期启动容器：

```bash
# 编辑 crontab
crontab -e

# 添加定时任务（每 15 分钟执行一次）
*/15 * * * * docker run --rm -v /root/docker/cfst/cfst_data:/app/data cfst:latest
```

**优点**：
- 容器运行完就退出，不占用资源
- 由宿主机 cron 统一管理
- 更容易维护和监控

## 管理定时任务

### 查看定时任务

```bash
# 查看容器内的定时任务
docker exec -it cfst crontab -l

# 查看持久化文件
docker exec -it cfst cat /app/data/crontab

# 查看执行日志
docker exec -it cfst cat /app/data/cron.log
```

### 编辑定时任务

```bash
# 进入容器编辑定时任务
docker exec -it cfst crontab -e
```

### 删除定时任务

```bash
# 方法 1：删除容器（定时任务随容器消失）
docker stop cfst
docker rm cfst

# 方法 2：清空定时任务
docker exec -it cfst crontab -r
```

### 重启容器

```bash
# 重启后定时任务会自动恢复
docker restart cfst

# 查看日志确认恢复情况
docker logs cfst | grep "定时任务"
```

## 环境变量说明

### 基础参数

| 环境变量 | 说明 | 默认值 |
|---------|------|--------|
| `CFST_N` | 延迟测速线程数 | 200 |
| `CFST_T` | 延迟测速次数 | 4 |
| `CFST_DN` | 下载测速数量 | 10 |
| `CFST_DT` | 下载测速时间 | 10 |
| `CFST_TP` | 测速端口 | 443 |
| `CFST_URL` | 测速地址 | https://cf.xiu2.xyz/url |
| `CFST_TL` | 平均延迟上限 | 9999 |
| `CFST_TLL` | 平均延迟下限 | 0 |
| `CFST_TLR` | 丢包几率上限 | 1.0 |
| `CFST_SL` | 下载速度下限 | 0 |
| `CFST_P` | 显示结果数量 | 10 |
| `CFST_F` | IP 段数据文件 | ip.txt |
| `CFST_O` | 输出结果文件 | result.csv |

### 定时任务参数

| 环境变量 | 说明 | 示例 |
|---------|------|------|
| `CFST_CRON` | Cron 表达式 | `*/15 * * * *` |
| `CFST_CRON_ONCE` | 单次执行模式 | `true` |

### 上报参数

| 环境变量 | 说明 |
|---------|------|
| `CFST_REPORT` | 上报目标（逗号分隔） |
| `CFST_REPORT_WORKER_DOMAIN` | Cloudflare Workers 域名 |
| `CFST_REPORT_UUID` | Workers UUID |
| `CFST_REPORT_GITHUB_TOKEN` | GitHub Token |
| `CFST_REPORT_GITHUB_OWNER` | GitHub 仓库所有者 |
| `CFST_REPORT_GITHUB_REPO` | GitHub 仓库名称 |
| `CFST_REPORT_GITHUB_BRANCH` | GitHub 分支 |
| `CFST_REPORT_GITHUB_PATH` | GitHub 文件路径 |

## 使用示例

### 示例 1：每 15 分钟执行一次

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="*/15 * * * *" \
  cfst:latest
```

### 示例 2：每天凌晨 2 点执行

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="0 2 * * *" \
  cfst:latest
```

### 示例 3：每周执行一次

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="0 2 * * 1" \
  cfst:latest
```

### 示例 4：单次执行 + 定时任务

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="0 2 * * *" \
  -e CFST_CRON_ONCE="true" \
  cfst:latest
```

## 常见问题

### Q1: 定时任务在哪里？

定时任务保存在两个位置：
1. **容器内部**：`/etc/crontabs/root` 或 `/var/spool/cron/crontabs/root`
2. **持久化文件**：`/app/data/crontab`（挂载到宿主机）

容器重启时会自动从持久化文件恢复定时任务。

### Q2: 为什么容器一直在运行？

使用定时任务时，容器需要保持运行状态，crond 服务才能在后台执行定时任务。

如果不使用定时任务，容器会在测速完成后自动退出。

### Q3: 如何查看定时任务是否执行？

```bash
# 查看 cron 执行日志
docker exec -it cfst cat /app/data/cron.log

# 查看容器日志
docker logs cfst

# 查看测速结果文件
ls -lh ./cfst_data/
```

### Q4: 如何修改定时任务？

```bash
# 方法 1：进入容器编辑
docker exec -it cfst crontab -e

# 方法 2：删除容器重新创建
docker stop cfst
docker rm cfst
# 然后重新运行 docker run 命令
```

### Q5: 容器重启后定时任务会丢失吗？

不会！定时任务已保存到 `/app/data/crontab` 文件，容器重启时会自动恢复。

确保挂载了数据目录：
```bash
-v ./cfst_data:/app/data
```

## 最佳实践

1. **始终挂载数据目录**：避免数据丢失
   ```bash
   -v ./cfst_data:/app/data
   ```

2. **使用 restart 策略**：确保容器异常退出后自动重启
   ```bash
   --restart=always
   ```

3. **定期查看日志**：监控定时任务执行情况
   ```bash
   docker logs -f cfst
   docker exec -it cfst cat /app/data/cron.log
   ```

4. **使用宿主机 cron**：如果不想容器一直运行，可以使用宿主机 cron 定期启动容器

## 故障排查

### 问题 1：定时任务未执行

```bash
# 检查 crond 服务是否运行
docker exec -it cfst ps aux | grep cron

# 查看 cron 日志
docker exec -it cfst cat /app/data/cron.log

# 检查定时任务是否存在
docker exec -it cfst crontab -l
```

### 问题 2：容器启动后没有定时任务

```bash
# 检查环境变量是否正确
docker inspect cfst | grep CFST_CRON

# 检查持久化文件
ls -lh ./cfst_data/
cat ./cfst_data/crontab
```

### 问题 3：测速结果未保存

```bash
# 检查数据目录挂载
docker exec -it cfst ls -lh /app/data/

# 检查文件权限
ls -lh ./cfst_data/
```

## 相关资源

- [Docker 官方文档](https://docs.docker.com/)
- [Cron 表达式详解](https://crontab.guru/)
- [项目 GitHub 仓库](https://github.com/XIU2/CloudflareSpeedTest)
