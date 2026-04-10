#!/bin/bash
#
# CloudflareSpeedTest 联动测试脚本 + 直接二进制调用
# 功能：
#   1. 四阶段递进式自动化测试
#   2. 或直接调用二进制程序进行单个阶段测试
#   3. 自动检测参数类型并路由到正确的处理方式
#
# 用法：
#   ./cfst_pipeline.sh                    # 四阶段自动测试
#   ./cfst_pipeline.sh -n 20 -r HKG,NRT  # 自定义参数的四阶段测试
#   ./cfst_pipeline.sh -tp 443 -n 5 ...  # 直接调用二进制程序（自动检测）
#

set -e

# ============= 配置参数 =============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 自动检测操作系统并选择正确的二进制文件
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    CFST_BIN="${SCRIPT_DIR}/CloudflareSpeedTest.exe"
else
    CFST_BIN="${SCRIPT_DIR}/CloudflareSpeedTest"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_DIR="${SCRIPT_DIR}/speedtest_results_${TIMESTAMP}"

# 用户自定义参数（可以在脚本开头修改）
TEST_URL="${TEST_URL:-https://cf.xiu2.xyz/url}"
TEST_REGIONS="${TEST_REGIONS:-HKG,NRT,SIN,LAX}"
THREADS="${THREADS:-15}"
VERBOSE="${VERBOSE:-0}"

# ============= 颜色输出 =============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_tip() {
    echo -e "${CYAN}💡 $1${NC}"
}

# ============= 参数检测 =============

# 检测是否是二进制程序的参数
is_binary_param() {
    local param="$1"
    # 二进制程序特有的参数
    case "$param" in
        -tp|-t|-dn|-dt|-tl|-tll|-tlr|-sl|-p|-f|-ip|-o|-dd|-allip|-debug|-httping|-httping-code|-cfcolo)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 检查参数中是否包含二进制程序参数
has_binary_params() {
    for param in "$@"; do
        if is_binary_param "$param"; then
            return 0
        fi
    done
    return 1
}

# ============= 直接调用二进制程序 =============

run_binary_directly() {
    log_info "检测到二进制程序参数，直接调用二进制程序..."
    log_info "参数: $@"
    echo ""
    
    if [ ! -f "$CFST_BIN" ]; then
        log_error "找不到二进制文件: $CFST_BIN"
        exit 1
    fi
    
    # 直接调用二进制程序，传递所有参数
    "$CFST_BIN" "$@"
}

# ============= 工具函数 =============

# 检查依赖
check_dependencies() {
    if [ ! -f "$CFST_BIN" ]; then
        log_error "找不到 CloudflareSpeedTest 二进制文件: $CFST_BIN"
        log_info "请确保以下文件之一存在:"
        log_info "  - ${SCRIPT_DIR}/CloudflareSpeedTest (Linux/Mac)"
        log_info "  - ${SCRIPT_DIR}/CloudflareSpeedTest.exe (Windows)"
        exit 1
    fi
    
    for cmd in awk sed tail head; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "缺少依赖命令: $cmd"
            exit 1
        fi
    done
}

# 从CSV提取IP列表
extract_ips_from_csv() {
    local csv_file="$1"
    local max_count="${2:-20}"
    
    if [ ! -f "$csv_file" ]; then
        log_warning "CSV文件不存在: $csv_file"
        return 1
    fi
    
    tail -n +3 "$csv_file" 2>/dev/null | grep -v "^#" | awk -F',' 'NF{print $1}' | head -n "$max_count" | paste -sd ',' - || echo ""
}

# 验证IP列表是否为空
validate_ips() {
    local ips="$1"
    if [ -z "$ips" ] || [ "$ips" = "," ]; then
        return 1
    fi
    return 0
}

# 打印进度
print_stage_header() {
    local stage_num="$1"
    local stage_name="$2"
    local description="$3"
    local estimated_time="$4"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 阶段 $stage_num: $stage_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "$description"
    log_info "预计耗时: $estimated_time"
    echo ""
}

# ============= 主测试流程 =============

stage1_tcp_screening() {
    print_stage_header 1 "TCP快速筛选" \
        "使用TCP协议测试所有IP延迟，快速定位候选集合" \
        "2-3 分钟"
    
    local output_file="$RESULT_DIR/01_tcp_candidates.csv"
    
    log_info "启动 TCP 延迟测试..."
    log_info "参数: 线程=$THREADS, 测试次数=2, 延迟上限=200ms"
    
    "$CFST_BIN" \
        -tp 443 \
        -n "$THREADS" \
        -t 2 \
        -dn 0 \
        -dd \
        -tl 200 \
        -p 50 \
        -o "$output_file" \
        > /dev/null 2>&1 || {
        log_error "TCP测试失败"
        return 1
    }
    
    local candidate_count=$(tail -n +3 "$output_file" 2>/dev/null | grep -v "^#" | wc -l)
    log_success "TCP测试完成！找到 $candidate_count 个候选IP"
    
    if [ "$candidate_count" -lt 5 ]; then
        log_warning "候选IP数量较少（<5），后续阶段可能无法进行"
    fi
    
    echo "$output_file"
}

stage2_http_verification() {
    local stage1_output="$1"
    
    print_stage_header 2 "HTTP服务验证" \
        "对TCP筛选出的IP进行HTTP/HTTPS请求验证，确保应用服务可用" \
        "3-4 分钟"
    
    local ips=$(extract_ips_from_csv "$stage1_output" 20)
    
    if ! validate_ips "$ips"; then
        log_error "无法从TCP结果中提取有效IP"
        return 1
    fi
    
    local output_file="$RESULT_DIR/02_http_verified.csv"
    
    log_info "提取的IP数量: $(echo "$ips" | tr ',' '\n' | wc -l)"
    log_info "启动 HTTP 服务验证..."
    log_info "参数: HTTPing=启用, 地区=$TEST_REGIONS, 状态码=200"
    
    "$CFST_BIN" \
        -httping \
        -cfcolo "$TEST_REGIONS" \
        -httping-code 200 \
        -url "$TEST_URL" \
        -n "$THREADS" \
        -t 3 \
        -dn 0 \
        -dd \
        -ip "$ips" \
        -tl 250 \
        -p 20 \
        -o "$output_file" \
        > /dev/null 2>&1 || {
        log_error "HTTP验证失败"
        return 1
    }
    
    local verified_count=$(tail -n +3 "$output_file" 2>/dev/null | grep -v "^#" | wc -l)
    log_success "HTTP验证完成！通过验证 $verified_count 个IP"
    
    if [ "$verified_count" -lt 5 ]; then
        log_warning "通过验证的IP较少，可能存在网络问题或服务不可用"
    fi
    
    echo "$output_file"
}

stage3_performance_evaluation() {
    local stage2_output="$1"
    
    print_stage_header 3 "完整性能评估" \
        "对验证过的IP进行完整下载测试，评估真实性能和用户体验" \
        "5-8 分钟"
    
    local ips=$(extract_ips_from_csv "$stage2_output" 10)
    
    if ! validate_ips "$ips"; then
        log_error "无法从HTTP验证结果中提取有效IP"
        return 1
    fi
    
    local output_file="$RESULT_DIR/03_final_results.csv"
    
    log_info "提取的IP数量: $(echo "$ips" | tr ',' '\n' | wc -l)"
    log_info "启动完整性能测试（包含下载速度）..."
    log_info "参数: 测试次数=4, 下载测试=10个IP, 下载时间=12秒"
    
    "$CFST_BIN" \
        -httping \
        -cfcolo "$TEST_REGIONS" \
        -httping-code 200 \
        -url "$TEST_URL" \
        -n "$THREADS" \
        -t 4 \
        -ip "$ips" \
        -dn 10 \
        -dt 12 \
        -sl 5 \
        -tl 300 \
        -tlr 0.1 \
        -p 10 \
        -o "$output_file" \
        > /dev/null 2>&1 || {
        log_error "性能评估失败"
        return 1
    }
    
    local final_count=$(tail -n +3 "$output_file" 2>/dev/null | grep -v "^#" | wc -l)
    log_success "性能评估完成！获得 $final_count 个最终结果"
    
    echo "$output_file"
}

print_summary() {
    local final_result="$1"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 测试完成！汇总报告"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ ! -f "$final_result" ]; then
        log_error "结果文件不存在"
        return 1
    fi
    
    log_success "所有结果保存在: $RESULT_DIR/"
    echo ""
    
    log_info "📈 最终排序结果 (前5快):"
    echo ""
    tail -n +3 "$final_result" 2>/dev/null | grep -v "^#" | head -5 | while IFS=',' read -r ip delay loss_rate download_speed _; do
        ip=$(echo "$ip" | xargs)
        delay=$(echo "$delay" | xargs)
        download_speed=$(echo "$download_speed" | xargs)
        
        if [ -n "$ip" ] && [ -n "$delay" ]; then
            printf "  🌐 %-18s │ 延迟: %6s ms │ 下载: %s MB/s\n" "$ip" "$delay" "${download_speed:-N/A}"
        fi
    done || tail -n +3 "$final_result" | head -5
    
    echo ""
    
    local best_ip=$(tail -n +3 "$final_result" 2>/dev/null | grep -v "^#" | head -1 | awk -F',' '{print $1}' | xargs)
    if [ -n "$best_ip" ]; then
        log_success "🏆 最快IP: $best_ip"
        echo ""
        log_info "你可以将此IP添加到 /etc/hosts 文件中，或在测试工具中指定使用"
    fi
    
    echo ""
    log_info "💾 详细结果文件:"
    log_info "  - 阶段1 (TCP筛选): $RESULT_DIR/01_tcp_candidates.csv"
    log_info "  - 阶段2 (HTTP验证): $RESULT_DIR/02_http_verified.csv"
    log_info "  - 阶段3 (最终结果): $RESULT_DIR/03_final_results.csv"
    echo ""
}

# ============= 主函数 =============

main() {
    log_info "🚀 CloudflareSpeedTest 联动测试脚本"
    log_info "版本: 2.0 | 时间戳: $TIMESTAMP"
    log_info "检测到操作系统: $(uname -s 2>/dev/null || echo 'Windows')"
    echo ""
    
    # 检查依赖
    check_dependencies
    log_success "使用二进制文件: $CFST_BIN"
    echo ""
    
    # 创建结果目录
    mkdir -p "$RESULT_DIR"
    log_success "结果目录已创建: $RESULT_DIR"
    echo ""
    
    # 阶段1: TCP快速筛选
    stage1_output=$(stage1_tcp_screening) || {
        log_error "阶段1失败，终止测试"
        exit 1
    }
    
    # 阶段2: HTTP服务验证
    stage2_output=$(stage2_http_verification "$stage1_output") || {
        log_error "阶段2失败，终止测试"
        exit 1
    }
    
    # 阶段3: 完整性能评估
    stage3_output=$(stage3_performance_evaluation "$stage2_output") || {
        log_error "阶段3失败，终止测试"
        exit 1
    }
    
    # 打印汇总
    print_summary "$stage3_output"
    
    log_success "✨ 所有阶段测试完成！"
}

# ============= 脚本入口 =============

# 显示用法
usage() {
    cat << EOF
用法: $0 [选项]

两种使用模式：

【模式1】四阶段自动化测试（推荐）
    $0                                      # 使用默认参数
    $0 -n 20                               # 指定线程数
    $0 -n 20 -r HKG,NRT                   # 指定线程数和地区
    $0 -u https://example.com/file -n 10  # 自定义URL和线程

脚本参数:
    -u, --url URL           指定测速地址 (默认: https://cf.xiu2.xyz/url)
    -r, --regions REGIONS   指定地区码，逗号分隔 (默认: HKG,NRT,SIN,LAX)
    -n, --threads NUM       指定线程数 (默认: 15)
    -v, --verbose           显示详细输出
    -h, --help              显示此帮助信息

【模式2】直接调用二进制程序（高级用户）
    $0 -tp 443 -n 5 -t 1 -dd -o result.csv
    $0 -httping -n 15 -dn 10 -dt 12 -o result.csv

二进制程序参数 (将自动检测并调用):
    -tp PORT                测速端口 (默认: 443)
    -n THREADS              线程数 (默认: 200)
    -t TIMES                单个IP测试次数 (默认: 4)
    -dn COUNT               下载测试数量 (默认: 10)
    -dt TIME                下载测试时间秒 (默认: 10)
    -tl MS                  延迟上限(ms) (默认: 9999)
    -tll MS                 延迟下限(ms) (默认: 0)
    -tlr RATE               丢包率上限 (默认: 1.00)
    -sl SPEED               下载速度下限(MB/s) (默认: 0)
    -p COUNT                显示结果数量 (默认: 10)
    -o FILE                 输出文件
    -ip IPS                 指定IP (逗号分隔)
    -httping                使用HTTP测试
    -httping-code CODE      HTTP状态码
    -cfcolo CODES           地区过滤
    -dd                     禁用下载测试
    -f FILE                 IP数据文件
    -allip                  测试所有IP
    -debug                  调试模式

例子:

四阶段测试:
    $0                      # 完整测试 (推荐)
    $0 -n 5                 # 快速测试 (5分钟)
    $0 -n 20 -r HKG,NRT    # 指定参数的完整测试

直接二进制:
    $0 -tp 443 -n 5 -t 1 -dd -o result.csv
    $0 -httping -n 15 -dn 10 -o result.csv

环境变量:
    TEST_URL                测速地址
    TEST_REGIONS            地区码
    THREADS                 线程数
    VERBOSE                 是否显示详细输出

EOF
    exit 0
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--url)
                TEST_URL="$2"
                shift 2
                ;;
            -r|--regions)
                TEST_REGIONS="$2"
                shift 2
                ;;
            -n|--threads)
                THREADS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                # 未知参数，可能是二进制程序的参数
                return 1
                ;;
        esac
    done
    return 0
}

# 主入口
if [ $# -eq 0 ]; then
    # 无参数，执行四阶段测试
    main
else
    # 检查是否是二进制程序的参数
    if has_binary_params "$@"; then
        # 直接调用二进制程序
        run_binary_directly "$@"
    else
        # 尝试解析脚本参数
        if parse_args "$@"; then
            # 成功解析脚本参数，执行四阶段测试
            main
        else
            # 解析失败，显示错误和帮助
            log_error "未知参数: $1"
            echo ""
            usage
        fi
    fi
fi
