# Docker 使用指南

本文档介绍如何使用 Docker 运行 CloudflareSpeedTest，并配置持久化的定时任务。

## 核心特性

1. **Crontab 持久化**：定时任务保存到 `/app/data/crontab` 文件
2. **容器重启自动恢复**：启动时自动恢复之前配置的定时任务
3. **容器始终保持运行**：使用 `tail -f /dev/null` 保持容器存活
4. **定期保存 crontab**：每 5 分钟自动保存一次，防止丢失
5. **环境变量优先级**：命令行参数 > 环境变量
6. **数据持久化**：IP 文件和测速结果自动保存到数据目录
7. **mihomo 集成**：测速前自动停止 mihomo 容器，测速后自动启动
8. **非交互式终端支持**：自动检测 TTY，非 TTY 模式使用 `script` 命令模拟伪终端
9. **单次执行模式**：`CFST_CRON_ONCE=true` 时先执行一次测速再启动定时任务
10. **多端口支持**：IP 数据文件中每个条目可独立指定端口
11. **多格式输入**：支持 TXT/CSV/JSON 格式的 IP 数据文件，支持远程 URL

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

### 方式三：使用 docker-compose（推荐用于生产环境）

```yaml
# docker-compose.yml
name: cfst
services:
  cfst:
    image: cfst:latest
    container_name: cfst
    env_file:
      - path: .env
        required: false
    restart: unless-stopped
    volumes:
      - cfst:/app/data
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - custom-network

volumes:
  cfst:
networks:
  custom-network:
    driver: bridge
```

创建 `.env` 文件：
```env
CFST_N=200
CFST_T=4
CFST_DN=10
CFST_CRON="0 2 * * *"
CFST_REPORT=cloudflare
CFST_REPORT_WORKER_DOMAIN=example.com
CFST_REPORT_UUID=your-uuid
```

启动服务：
```bash
docker compose up -d
```

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

## mihomo 集成

测速时需要绕过代理获得准确结果，因此支持在测速前自动停止 mihomo 容器，测速后自动启动。

### 配置方式

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e CFST_CRON="0 2 * * *" \
  -e CFST_MIHOMO_CONTAINER="mihomo" \
  cfst:latest
```

**说明**：
- `-v /var/run/docker.sock:/var/run/docker.sock`：必须挂载 Docker Socket
- `-e CFST_MIHOMO_CONTAINER`：指定 mihomo 容器名称

### 工作流程

```
1. 定时任务触发 → 停止 mihomo 容器
   ↓
2. 执行测速
   ↓
3. 测速完成 → 启动 mihomo 容器
```

### docker-compose 配置

```yaml
services:
  cfst:
    image: cfst:latest
    container_name: cfst
    volumes:
      - cfst:/app/data
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - CFST_CRON=0 2 * * *
      - CFST_MIHOMO_CONTAINER=mihomo
```

## IP 数据文件

### 文件位置

IP 数据文件默认存放在 `/app/data/` 目录下。首次运行时，容器会自动将默认的 `ip.txt` 和 `ipv6.txt` 复制到数据目录。

### 自定义 IP 文件

将自定义 IP 文件放到挂载的数据目录中：

```bash
# 宿主机
echo "1.0.0.1:443" > ./cfst_data/my_ips.txt
echo "1.0.0.2:8443 #NRT" >> ./cfst_data/my_ips.txt

# 使用自定义文件
docker run -v ./cfst_data:/app/data -e CFST_F=my_ips.txt cfst:latest
```

### 支持的文件格式

| 格式 | 扩展名 | 说明 |
|------|--------|------|
| TXT | .txt | 每行一个 IP/CIDR，支持 `IP:端口 #标签` |
| CSV | .csv | 表头自动识别 IP/端口/标签列 |
| JSON | .json | 字符串数组或对象数组 |
| 远程 URL | http/https | 自动下载远程文件 |

### 多端口支持

IP 数据文件中每个条目可以独立指定端口：

```txt
# 一个 IP 多端口
1.0.0.1:443
1.0.0.1:8443
1.0.0.1:2053

# 一个 IP 一个端口
1.0.0.1:443
1.0.0.2:8443
1.0.0.3:2053

# 混合使用
1.0.0.1:443 #HKG
1.0.0.1:8443 #HKG-Alt
1.0.0.2:2053 #NRT
```

如果未指定端口，则使用 `-tp` 参数（默认 443）。

## 环境变量说明

### 基础参数

| 环境变量 | 说明 | 默认值 |
|---------|------|--------|
| `CFST_N` | 延迟测速线程数 | 200 |
| `CFST_T` | 延迟测速次数 | 4 |
| `CFST_DN` | 下载测速数量 | 10 |
| `CFST_DT` | 下载测速时间 | 10 |
| `CFST_TP` | 测速端口（全局默认） | 443 |
| `CFST_URL` | 测速地址 | https://cf.xiu2.xyz/url |
| `CFST_TL` | 平均延迟上限 | 9999 |
| `CFST_TLL` | 平均延迟下限 | 0 |
| `CFST_TLR` | 丢包率上限 | 1.0 |
| `CFST_SL` | 下载速度下限 | 0 |
| `CFST_P` | 显示结果数量 | 10 |
| `CFST_F` | IP 段数据文件 | ip.txt |
| `CFST_O` | 输出结果文件 | result.csv |
| `CFST_DD` | 禁用下载测速 | false |
| `CFST_HTTPING` | HTTPing 模式 | false |
| `CFST_HTTPING_CODE` | HTTP 状态码 | 200 |
| `CFST_CFCOLO` | Cloudflare 地区 | 空 |
| `CFST_IP` | 指定 IP 段 | 空 |
| `CFST_ALLIP` | 测速全部 IP | false |
| `CFST_DEBUG` | 调试模式 | false |

### 定时任务参数

| 环境变量 | 说明 | 示例 |
|---------|------|------|
| `CFST_CRON` | Cron 表达式 | `*/15 * * * *` |
| `CFST_CRON_ONCE` | 单次执行模式 | `true` |
| `CFST_SCHEDULER_TASK_NAME` | 定时任务名称 | `cfst_daily` |
| `CFST_SCHEDULER_CRON` | 定时任务 cron 表达式 | `0 2 * * *` |

### mihomo 集成参数

| 环境变量 | 说明 | 示例 |
|---------|------|------|
| `CFST_MIHOMO_CONTAINER` | mihomo 容器名称 | `mihomo` |

### 上报参数

| 环境变量 | 说明 |
|---------|------|
| `CFST_REPORT` | 上报目标（逗号分隔多目标） |
| `CFST_REPORT_ONLY` | 仅上报模式 |
| `CFST_REPORT_FILE` | 上报文件路径 |
| `CFST_REPORT_PORT` | 上报端口 |
| `CFST_REPORT_WORKER_DOMAIN` | Cloudflare Workers 域名 |
| `CFST_REPORT_UUID` | Workers UUID |
| `CFST_REPORT_GITHUB_TOKEN` | GitHub Token |
| `CFST_REPORT_GITHUB_OWNER` | GitHub 仓库所有者 |
| `CFST_REPORT_GITHUB_REPO` | GitHub 仓库名称 |
| `CFST_REPORT_GITHUB_BRANCH` | GitHub 分支 |
| `CFST_REPORT_GITHUB_PATH` | GitHub 文件路径 |
| `CFST_REPORT_CONFIG` | 上报配置文件路径 |

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

### 示例 5：测速并上报到 Cloudflare Workers

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="0 2 * * *" \
  -e CFST_REPORT="cloudflare" \
  -e CFST_REPORT_WORKER_DOMAIN="example.com" \
  -e CFST_REPORT_UUID="your-uuid" \
  cfst:latest
```

### 示例 6：测速并上报到 GitHub

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="0 2 * * *" \
  -e CFST_REPORT="github" \
  -e CFST_REPORT_GITHUB_TOKEN="ghp_xxxx" \
  -e CFST_REPORT_GITHUB_OWNER="username" \
  -e CFST_REPORT_GITHUB_REPO="repo" \
  cfst:latest
```

### 示例 7：多目标上报

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="0 2 * * *" \
  -e CFST_REPORT="cloudflare,github" \
  -e CFST_REPORT_WORKER_DOMAIN="example.com" \
  -e CFST_REPORT_UUID="your-uuid" \
  -e CFST_REPORT_GITHUB_TOKEN="ghp_xxxx" \
  -e CFST_REPORT_GITHUB_OWNER="username" \
  -e CFST_REPORT_GITHUB_REPO="repo" \
  cfst:latest
```

### 示例 8：带 mihomo 集成

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e CFST_CRON="0 2 * * *" \
  -e CFST_MIHOMO_CONTAINER="mihomo" \
  cfst:latest
```

### 示例 9：使用自定义多端口 IP 文件

```bash
# 创建自定义 IP 文件
cat > ./cfst_data/my_ips.txt << 'EOF'
1.0.0.1:443
1.0.0.1:8443
1.0.0.2:2053
1.0.0.3:2083 #SJC
EOF

# 使用自定义文件运行
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="0 2 * * *" \
  -e CFST_F="my_ips.txt" \
  cfst:latest
```

### 示例 10：使用远程 IP 数据文件

```bash
docker run -d --restart=always \
  --name cfst \
  -v ./cfst_data:/app/data \
  -e CFST_CRON="0 2 * * *" \
  -e CFST_F="https://example.com/ip_list.txt" \
  cfst:latest
```

## 测速结果

### 输出文件

测速完成后会在数据目录生成以下文件：

| 文件 | 说明 |
|------|------|
| `result.csv` | 完整测速结果（12 列，含下载速度） |
| `result_ping.csv` | 延迟测速结果（11 列，不含下载速度） |
| `cron.log` | 定时任务执行日志 |
| `crontab` | 持久化的 crontab 文件 |
| `run_cfst.sh` | 定时任务执行的测速脚本 |

### CSV 列定义

| 列 | 名称 | 说明 |
|----|------|------|
| 1 | IP 地址 | 测速 IP |
| 2 | 端口 | 测速端口 |
| 3 | 已发送 | 发送的数据包数 |
| 4 | 已接收 | 接收的数据包数 |
| 5 | 丢包率 | 丢包百分比 |
| 6 | 平均延迟 | 平均延迟（ms） |
| 7 | 下载速度(MB/s) | 下载速度 |
| 8 | 地区码 | IATA 机场码 |
| 9 | 地区码名称 | 地区码中文名称 |
| 10 | 二字地区码 | 国家二字码 |
| 11 | 二字地区名称 | 国家名称 |
| 12 | 标签 | IP 条目标签 |

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

### Q6: 环境变量和命令行参数冲突时如何处理？

命令行参数优先级高于环境变量。如果同时设置了环境变量和命令行参数，以命令行参数为准。

### Q7: 如何查看容器启动时的配置信息？

容器启动时会打印配置信息摘要：
```bash
docker logs cfst | head -30
```

### Q8: 如何配置 mihomo 集成？

需要两个条件：
1. 挂载 Docker Socket：`-v /var/run/docker.sock:/var/run/docker.sock`
2. 设置 mihomo 容器名称：`-e CFST_MIHOMO_CONTAINER=mihomo`

测速前会自动停止 mihomo，测速后自动启动。如果 mihomo 容器不存在或停止失败，不影响测速执行。

### Q9: 如何使用多端口测速？

在 IP 数据文件中为每个条目指定端口：
```
1.0.0.1:443
1.0.0.1:8443
1.0.0.2:2053
```

如果未指定端口，则使用 `CFST_TP` 环境变量（默认 443）。

### Q10: 非交互式终端下进度条显示异常怎么办？

容器会自动检测终端类型：
- **交互式终端**：使用旋转动画进度条
- **非交互式终端**：自动使用 `script` 命令模拟伪终端，或使用低频刷新的静态进度条

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

5. **使用 docker-compose**：生产环境推荐使用 docker-compose 管理配置

6. **mihomo 集成**：如果使用 mihomo 代理，务必配置 `CFST_MIHOMO_CONTAINER` 以获得准确的测速结果

7. **多端口测速**：在 IP 文件中为每个条目指定端口，可以同时测试同一 IP 的不同端口

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

### 问题 4：上报失败

```bash
# 检查上报配置
docker exec -it cfst cat /app/data/.cfst_config.json

# 查看容器日志中的上报信息
docker logs cfst | grep "上报"
```

### 问题 5：mihomo 集成失败

```bash
# 检查 Docker Socket 是否挂载
docker exec -it cfst docker ps

# 检查 mihomo 容器是否存在
docker ps -a | grep mihomo

# 查看 mihomo 操作日志
docker logs cfst | grep "mihomo"
```

### 问题 6：非交互式终端进度条异常

```bash
# 查看容器是否检测到 TTY
docker logs cfst | grep "终端"

# 手动指定交互式模式
docker run -it cfst:latest
```

## 相关资源

- [Docker 官方文档](https://docs.docker.com/)
- [Cron 表达式详解](https://crontab.guru/)
- [项目 GitHub 仓库](https://github.com/XIU2/CloudflareSpeedTest)
