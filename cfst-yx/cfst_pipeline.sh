#!/bin/bash
#
# CloudflareSpeedTest 联动测试脚本 v2.0
# 功能：四阶段递进式 CDN IP 测试 + 智能参数检测
#

set -e

# ===== 错误处理 =====
trap 'log_error "脚本失败，行号: $LINENO"' ERR

# ===== 配置 =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检测操作系统
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw" ]]; then
    CFST_BIN="${SCRIPT_DIR}/CloudflareSpeedTest.exe"
    IS_WINDOWS=1
else
    CFST_BIN="${SCRIPT_DIR}/CloudflareSpeedTest"
    IS_WINDOWS=0
fi

# 验证二进制文件存在
if [ ! -f "$CFST_BIN" ]; then
    log_error "❌ 找不到二进制文件: $CFST_BIN"
    log_error "请确保以下文件存在:"
    log_error "  - CloudflareSpeedTest (Linux)"
    log_error "  - CloudflareSpeedTest.exe (Windows)"
    exit 1
fi

# 验证 IP 数据文件存在
for ipfile in ip.txt ipv6.txt; do
    if [ ! -f "${SCRIPT_DIR}/${ipfile}" ]; then
        log_error "❌ 找不到数据文件: ${SCRIPT_DIR}/${ipfile}"
        log_error "请确保以下文件在 cfst-yx 文件夹中:"
        log_error "  - ip.txt"
        log_error "  - ipv6.txt"
        exit 1
    fi
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_DIR="${SCRIPT_DIR}/speedtest_results_${TIMESTAMP}"
TEST_URL="${TEST_URL:-https://cf.xiu2.xyz/url}"
TEST_REGIONS="${TEST_REGIONS:-HKG,NRT,SIN,LAX}"
THREADS="${THREADS:-15}"

PIPELINE_PORT="${PIPELINE_PORT:-443}"
PIPELINE_LATENCY="${PIPELINE_LATENCY:-200}"
PIPELINE_RESULTS="${PIPELINE_RESULTS:-}"
PIPELINE_TIMES="${PIPELINE_TIMES:-}"
PIPELINE_DOWNLOAD_COUNT="${PIPELINE_DOWNLOAD_COUNT:-}"
PIPELINE_DOWNLOAD_TIME="${PIPELINE_DOWNLOAD_TIME:-}"
PIPELINE_SPEED_LIMIT="${PIPELINE_SPEED_LIMIT:-}"
PIPELINE_LOSS_RATE="${PIPELINE_LOSS_RATE:-}"
PIPELINE_IP_FILE="${PIPELINE_IP_FILE:-}"
PIPELINE_OUTPUT="${PIPELINE_OUTPUT:-}"
PIPELINE_EXTRA_ARGS=()

# ===== 颜色输出 =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

STAGE_ARGS=()

# ===== 工具函数 =====
check_binary() {
    if [ ! -f "$CFST_BIN" ]; then
        log_error "找不到二进制文件: $CFST_BIN"
        exit 1
    fi
}

extract_ips() {
    local csv="$1"
    local count="${2:-20}"
    [ ! -f "$csv" ] && return 1
    tail -n +3 "$csv" 2>/dev/null | grep -v "^#" | awk -F',' 'NF{print $1}' | head -n "$count" | paste -sd ',' - || echo ""
}

build_stage_args() {
    local stage="$1"
    STAGE_ARGS=()

    case "$stage" in
        1)
            STAGE_ARGS+=(-tp "${PIPELINE_PORT}" -n "${THREADS}" -t "${PIPELINE_TIMES:-2}" -dn 0 -dd -tl "${PIPELINE_LATENCY}" -p "${PIPELINE_RESULTS:-50}")
            [ -n "${PIPELINE_LOSS_RATE}" ] && STAGE_ARGS+=(-tlr "${PIPELINE_LOSS_RATE}")
            ;;
        2)
            STAGE_ARGS+=(-httping -cfcolo "$TEST_REGIONS" -httping-code 200 -url "$TEST_URL" -n "$THREADS" -t "${PIPELINE_TIMES:-3}" -dn 0 -dd -tl "$((PIPELINE_LATENCY + 50))" -p "${PIPELINE_RESULTS:-20}")
            [ -n "${PIPELINE_LOSS_RATE}" ] && STAGE_ARGS+=(-tlr "${PIPELINE_LOSS_RATE}")
            ;;
        3)
            STAGE_ARGS+=(-httping -cfcolo "$TEST_REGIONS" -httping-code 200 -url "$TEST_URL" -n "$THREADS" -t "${PIPELINE_TIMES:-4}" -dn "${PIPELINE_DOWNLOAD_COUNT:-10}" -dt "${PIPELINE_DOWNLOAD_TIME:-12}" -sl "${PIPELINE_SPEED_LIMIT:-5}" -tl "$((PIPELINE_LATENCY + 100))" -tlr "${PIPELINE_LOSS_RATE:-0.1}" -p "${PIPELINE_RESULTS:-10}")
            ;;
    esac

    if [ -n "$PIPELINE_IP_FILE" ] && [ "$stage" = "1" ]; then
        STAGE_ARGS+=(-f "$PIPELINE_IP_FILE")
    fi

    STAGE_ARGS+=("${PIPELINE_EXTRA_ARGS[@]}")
}

# ===== 四阶段测试 =====

stage1() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 阶段1: TCP 快速筛选"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "使用 TCP 测试所有 IP 延迟，快速定位候选集合"
    log_info "线程=$THREADS, 测试次数=2, 延迟上限=200ms"
    echo ""
    
    mkdir -p "$RESULT_DIR"
    local output="$RESULT_DIR/01_tcp_candidates.csv"
    local stage_args=$(build_stage_args 1)

    log_info "运行命令: cd '$SCRIPT_DIR' && '$CFST_BIN' $stage_args -o '$output'"

    (cd "$SCRIPT_DIR" && "$CFST_BIN" $stage_args -o "$output") || {
        log_error "TCP 测试失败"
        log_error "请检查:"
        log_error "  1. 网络连接是否正常"
        log_error "  2. ip.txt 和 ipv6.txt 文件是否存在"
        log_error "  3. 二进制文件是否可执行"
        exit 1
    }
    
    if [ ! -f "$output" ]; then
        log_error "TCP 测试没有生成输出文件: $output"
        exit 1
    fi
    
    local count=$(tail -n +3 "$output" 2>/dev/null | grep -c . || echo 0)
    log_success "TCP 测试完成！找到 $count 个候选 IP"
    echo "$output"
}

stage2() {
    local stage1_csv="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 阶段2: HTTP 服务验证"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "对 TCP 候选 IP 进行 HTTP 请求验证，确保服务可用"
    echo ""
    
    local ips=$(extract_ips "$stage1_csv" 20)
    [ -z "$ips" ] && { log_error "无法从阶段1提取 IP"; exit 1; }

    local output="$RESULT_DIR/02_http_verified.csv"
    build_stage_args 2

    log_info "延迟上限=$((PIPELINE_LATENCY + 50))ms, 地区=$TEST_REGIONS"

    if ! (cd "$SCRIPT_DIR" && "$CFST_BIN" "${STAGE_ARGS[@]}" -ip "$ips" -o "$output"); then
        log_error "HTTP验证失败"
        exit 1
    fi
    
    local count=$(tail -n +3 "$output" 2>/dev/null | wc -l)
    log_success "HTTP验证完成！通过验证 $count 个 IP"
    echo "$output"
}

stage3() {
    local stage2_csv="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 阶段3: 完整性能评估"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "对验证过的 IP 进行完整下载测试，评估真实性能"
    echo ""
    
    local ips=$(extract_ips "$stage2_csv" 10)
    [ -z "$ips" ] && { log_error "无法从阶段2提取 IP"; exit 1; }

    local output="$RESULT_DIR/03_final_results.csv"
    build_stage_args 3

    log_info "延迟上限=$((PIPELINE_LATENCY + 100))ms, 速度下限=${PIPELINE_SPEED_LIMIT:-5}MB/s, 丢包率上限=${PIPELINE_LOSS_RATE:-0.1}"

    if ! (cd "$SCRIPT_DIR" && "$CFST_BIN" "${STAGE_ARGS[@]}" -ip "$ips" -o "$output"); then
        log_error "性能评估失败"
        exit 1
    fi
    
    local count=$(tail -n +3 "$output" 2>/dev/null | wc -l)
    log_success "性能评估完成！获得 $count 个最终结果"
    echo "$output"
}

print_summary() {
    local final_csv="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 测试完成！最终结果"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "所有结果保存在: $RESULT_DIR/"
    echo ""
    log_info "📈 最快的 5 个 IP:"
    echo ""

    tail -n +3 "$final_csv" 2>/dev/null | head -5 | while IFS=',' read -r ip delay loss speed _; do
        printf "  🌐 %-20s │ 延迟: %6s ms │ 速度: %s\n" "$ip" "$delay" "${speed:-N/A}"
    done || true
    echo ""

    local best_ip=$(tail -n +3 "$final_csv" 2>/dev/null | head -1 | awk -F',' '{print $1}')
    [ -n "$best_ip" ] && log_success "🏆 推荐 IP: $best_ip"

    if [ -n "$PIPELINE_OUTPUT" ]; then
        cp -f "$final_csv" "${SCRIPT_DIR}/${PIPELINE_OUTPUT}"
        log_success "结果已复制到: ${SCRIPT_DIR}/${PIPELINE_OUTPUT}"
    fi
    echo ""
}

# ===== 主函数 =====
main() {
    log_info "🚀 CloudflareSpeedTest 联动测试脚本"
    log_info "版本: 2.0 | 时间戳: $TIMESTAMP"
    echo ""
    
    check_binary
    log_success "使用二进制: $CFST_BIN"
    echo ""
    
    mkdir -p "$RESULT_DIR"
    log_success "结果目录已创建: $RESULT_DIR"
    echo ""
    
    local s1=$(stage1)
    local s2=$(stage2 "$s1")
    local s3=$(stage3 "$s2")
    
    print_summary "$s3"
    log_success "✨ 测试完成！"
}

# ===== 脚本入口 =====
if [ $# -eq 0 ]; then
    main
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat << 'HELP'
用法: bash cfst_pipeline.sh [选项]

【四阶段自动化测试】(推荐新手)
    bash cfst_pipeline.sh                         # 使用默认参数
    bash cfst_pipeline.sh -n 20                   # 指定线程数
    bash cfst_pipeline.sh -n 20 -r HKG,NRT        # 指定线程和地区
    bash cfst_pipeline.sh -n 10 --port 8443 --latency 150

脚本参数:
    -u, --url URL           指定测速地址 (默认: https://cf.xiu2.xyz/url)
    -r, --regions REGIONS   地区码，逗号分隔 (默认: HKG,NRT,SIN,LAX)
    -n, --threads NUM       线程数 (默认: 15)
    -v, --verbose           显示详细输出
    -h, --help              显示此帮助

流水线二进制参数 (传递给各阶段，与脚本参数可混用):
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
    --extra ARGS            额外二进制参数，引号包裹 (如: --extra "-tll 5 -tlr 0.2")

【直接调用二进制】(高级用户)
    bash cfst_pipeline.sh --raw -tp 443 -n 5 -t 1 -dd -o result.csv
    bash cfst_pipeline.sh --raw -httping -n 15 -dn 10 -url https://example.com

    --raw                   直接调用二进制，后续参数原样传递

例子:
    # 四阶段测试
    bash cfst_pipeline.sh                    # 完整测试
    bash cfst_pipeline.sh -n 5               # 快速测试
    bash cfst_pipeline.sh -n 10 -r HKG,NRT  # 指定参数

    # 混用参数（脚本 + 流水线二进制）
    bash cfst_pipeline.sh -n 10 --port 8443 --latency 150
    bash cfst_pipeline.sh --times 5 --speed-limit 10 --download-time 15
    bash cfst_pipeline.sh -r HKG,NRT --latency 100 --results 30

    # 直接二进制模式
    bash cfst_pipeline.sh --raw -tp 443 -n 5 -dd -o result.csv

提示:
    - 脚本参数和流水线二进制参数可以自由混用
    - 使用 --raw 进入直接二进制模式
    - 完整二进制参数参考: ./CloudflareSpeedTest.exe -h (或 ./CloudflareSpeedTest -h)
    - 结果保存在 speedtest_results_*/ 目录

HELP
    exit 0
else
    RAW_MODE=0
    RAW_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --raw)
                RAW_MODE=1; shift; RAW_ARGS=("$@"); break ;;
            -u|--url) TEST_URL="$2"; shift 2 ;;
            -r|--regions) TEST_REGIONS="$2"; shift 2 ;;
            -n|--threads) THREADS="$2"; shift 2 ;;
            -v|--verbose) set -x; shift ;;
            --port) PIPELINE_PORT="$2"; shift 2 ;;
            --latency) PIPELINE_LATENCY="$2"; shift 2 ;;
            --results) PIPELINE_RESULTS="$2"; shift 2 ;;
            --times) PIPELINE_TIMES="$2"; shift 2 ;;
            --download-count) PIPELINE_DOWNLOAD_COUNT="$2"; shift 2 ;;
            --download-time) PIPELINE_DOWNLOAD_TIME="$2"; shift 2 ;;
            --speed-limit) PIPELINE_SPEED_LIMIT="$2"; shift 2 ;;
            --loss-rate) PIPELINE_LOSS_RATE="$2"; shift 2 ;;
            --ip-file) PIPELINE_IP_FILE="$2"; shift 2 ;;
            --output) PIPELINE_OUTPUT="$2"; shift 2 ;;
            --extra) IFS=' ' read -ra PIPELINE_EXTRA_ARGS <<< "$2"; shift 2 ;;
            *) log_error "未知参数: $1 (使用 --raw 传递二进制参数)"; exit 1 ;;
        esac
    done

    if [ "$RAW_MODE" -eq 1 ]; then
        log_info "直接二进制模式，参数原样传递..."
        log_info "参数: ${RAW_ARGS[*]}"
        echo ""
        check_binary
        exec "$CFST_BIN" "${RAW_ARGS[@]}"
    fi

    main
fi
