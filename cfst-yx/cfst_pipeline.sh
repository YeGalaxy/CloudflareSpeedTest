#!/bin/bash
#
# CloudflareSpeedTest 联动测试脚本 v2.0
# 功能：四阶段递进式 CDN IP 测试 + 智能参数检测
#

set -e

# ===== 配置 =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检测操作系统
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    CFST_BIN="${SCRIPT_DIR}/CloudflareSpeedTest.exe"
else
    CFST_BIN="${SCRIPT_DIR}/CloudflareSpeedTest"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_DIR="${SCRIPT_DIR}/speedtest_results_${TIMESTAMP}"
TEST_URL="${TEST_URL:-https://cf.xiu2.xyz/url}"
TEST_REGIONS="${TEST_REGIONS:-HKG,NRT,SIN,LAX}"
THREADS="${THREADS:-15}"

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

# ===== 参数检测 =====
is_binary_param() {
    case "$1" in
        -tp|-t|-dn|-dt|-tl|-tll|-tlr|-sl|-p|-f|-ip|-o|-dd|-allip|-debug|-httping|-httping-code|-cfcolo|-url)
            return 0 ;;
        *) return 1 ;;
    esac
}

has_binary_params() {
    for arg in "$@"; do
        is_binary_param "$arg" && return 0
    done
    return 1
}

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

# ===== 四阶段测试 =====

stage1() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 阶段1: TCP 快速筛选"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "使用 TCP 测试所有 IP 延迟，快速定位候选集合"
    log_info "线程=$THREADS, 测试次数=2, 延迟上限=200ms"
    echo ""
    
    local output="$RESULT_DIR/01_tcp_candidates.csv"
    
    if ! "$CFST_BIN" -tp 443 -n "$THREADS" -t 2 -dn 0 -dd -tl 200 -p 50 -o "$output"; then
        log_error "TCP测试失败，请检查网络连接或二进制文件"
        exit 1
    fi
    
    local count=$(tail -n +3 "$output" 2>/dev/null | wc -l)
    log_success "TCP测试完成！找到 $count 个候选 IP"
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
    
    if ! "$CFST_BIN" -httping -cfcolo "$TEST_REGIONS" -httping-code 200 \
        -url "$TEST_URL" -n "$THREADS" -t 3 -dn 0 -dd -ip "$ips" -tl 250 -p 20 -o "$output"; then
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
    
    if ! "$CFST_BIN" -httping -cfcolo "$TEST_REGIONS" -httping-code 200 \
        -url "$TEST_URL" -n "$THREADS" -t 4 -ip "$ips" -dn 10 -dt 12 \
        -sl 5 -tl 300 -tlr 0.1 -p 10 -o "$output"; then
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
    bash cfst_pipeline.sh -u https://example.com/file -n 10

脚本参数:
    -u, --url URL           指定测速地址 (默认: https://cf.xiu2.xyz/url)
    -r, --regions REGIONS   地区码，逗号分隔 (默认: HKG,NRT,SIN,LAX)
    -n, --threads NUM       线程数 (默认: 15)
    -h, --help              显示此帮助

【直接调用二进制】(高级用户，会自动检测)
    bash cfst_pipeline.sh -tp 443 -n 5 -t 1 -dd -o result.csv
    bash cfst_pipeline.sh -httping -n 15 -dn 10 -url https://example.com

二进制参数 (完整参考用 -h):
    -tp, -t, -dn, -dt, -tl, -httping, -dd, -url, -cfcolo, 等

例子:
    # 四阶段测试
    bash cfst_pipeline.sh                    # 完整测试
    bash cfst_pipeline.sh -n 5               # 快速测试
    bash cfst_pipeline.sh -n 10 -r HKG,NRT  # 指定参数
    
    # 二进制参数（自动检测）
    bash cfst_pipeline.sh -tp 443 -n 5 -dd -o result.csv

提示:
    - 脚本会自动检测参数类型，不需要手动区分
    - 完整二进制参数参考: ./CloudflareSpeedTest.exe -h (或 ./CloudflareSpeedTest -h)
    - 结果保存在 speedtest_results_*/ 目录

HELP
    exit 0
elif has_binary_params "$@"; then
    # 检测到二进制参数，直接调用
    log_info "检测到二进制参数，直接调用二进制程序..."
    log_info "参数: $@"
    echo ""
    check_binary
    exec "$CFST_BIN" "$@"
else
    # 解析脚本参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--url) TEST_URL="$2"; shift 2 ;;
            -r|--regions) TEST_REGIONS="$2"; shift 2 ;;
            -n|--threads) THREADS="$2"; shift 2 ;;
            *) log_error "未知参数: $1"; exit 1 ;;
        esac
    done
    main
fi
