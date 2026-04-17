# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

ARG VERSION=v2.3.4
ARG TARGETOS=linux
ARG TARGETARCH
ARG GOPROXY=https://goproxy.cn,direct

ENV GOPROXY=${GOPROXY}

WORKDIR /build

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY main.go ./
COPY task/ ./task/
COPY utils/ ./utils/

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags="-s -w -X main.version=${VERSION}" \
    -o cfst .

FROM alpine:latest

RUN apk add --no-cache bash ca-certificates tzdata procps util-linux-misc \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

RUN addgroup -S cfst && adduser -S cfst -G cfst

# 设置工作目录为 /app
WORKDIR /app

COPY --from=builder --chown=cfst:cfst /build/cfst ./cfst
COPY --chown=cfst:cfst ip.txt ./
COPY --chown=cfst:cfst ipv6.txt ./

# 赋予二进制文件执行权限
RUN chmod +x ./cfst

# 定义数据卷挂载点，用于持久化数据
VOLUME ["/app/data"]

# 设置 Cloudflare Speed Test 相关的环境变量默认值
# 测试参数配置
ENV CFST_N=200 \
    CFST_T=4 \
    CFST_DN=10 \
    CFST_DT=10 \
    CFST_TP=443 \
    CFST_URL="https://cf.xiu2.xyz/url" \
    CFST_TL=9999 \
    CFST_TLL=0 \
    CFST_TLR=1.0 \
    CFST_SL=0 \
    CFST_DD=false \
    CFST_HTTPING=false \
    CFST_HTTPING_CODE=200 \
    CFST_CFCOLO="" \
    CFST_IP="" \
    CFST_ALLIP=false \
    CFST_P=10 \
    CFST_O="result.csv" \
    CFST_F="ip.txt" \
    CFST_DEBUG=false \
    CFST_REPORT="" \
    CFST_REPORT_ONLY=false \
    CFST_REPORT_FILE="" \
    CFST_REPORT_PORT=443 \
    CFST_REPORT_WORKER_DOMAIN="" \
    CFST_REPORT_UUID="" \
    CFST_REPORT_GITHUB_TOKEN="" \
    CFST_REPORT_GITHUB_OWNER="" \
    CFST_REPORT_GITHUB_REPO="" \
    CFST_REPORT_GITHUB_BRANCH="main" \
    CFST_REPORT_GITHUB_PATH="preferred_ips.txt" \
    CFST_CRON="" \
    CFST_CRON_ONCE=false \
    TZ="Asia/Shanghai"

COPY --chown=cfst:cfst entrypoint.sh ./
RUN chmod +x ./entrypoint.sh \
    && sed -i 's/\r$//' ./entrypoint.sh

# 设置容器入口点为 entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
