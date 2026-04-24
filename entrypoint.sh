#!/bin/bash
# 不使用 set -e，确保容器始终运行，不会因为命令失败而退出

DATA_DIR="/app/data"
INPUT_DIR="/app"

CRONTAB_FILE="${DATA_DIR}/crontab"

# 检测是否为交互式终端
IS_TTY=false
if [ -t 0 ] && [ -t 1 ]; then
    IS_TTY=true
fi

# 创建必要的目录
mkdir -p "${DATA_DIR}"

# 恢复 crontab（如果存在持久化文件）
if [ -f "$CRONTAB_FILE" ]; then
    echo "[定时任务] 检测到已保存的定时任务，正在恢复..."
    crontab "$CRONTAB_FILE"
    echo "[定时任务] 定时任务已恢复"
    echo ""
else
    # 首次运行，清空系统默认的 crontab
    crontab -r 2>/dev/null || true
fi

# 保存 crontab 的函数
save_crontab() {
    crontab -l > "$CRONTAB_FILE" 2>/dev/null || true
}

save_crontab_with_msg() {
    crontab -l > "$CRONTAB_FILE" 2>/dev/null || true
    echo "[定时任务] 定时任务已保存到 $CRONTAB_FILE"
}

_ORIG_CFST_F="${CFST_F:-}"

if [ "${_ORIG_CFST_F}" = "ip.txt" ] || [ -z "${_ORIG_CFST_F}" ]; then
    if [ -f "${DATA_DIR}/ip.txt" ]; then
        CFST_F="${DATA_DIR}/ip.txt"
        if [ ! -f "${DATA_DIR}/ipv6.txt" ] && [ -f "${INPUT_DIR}/ipv6.txt" ]; then
            cp "${INPUT_DIR}/ipv6.txt" "${DATA_DIR}/ipv6.txt"
        fi
    elif [ -f "${INPUT_DIR}/ip.txt" ]; then
        cp "${INPUT_DIR}/ip.txt" "${DATA_DIR}/ip.txt"
        [ -f "${INPUT_DIR}/ipv6.txt" ] && cp "${INPUT_DIR}/ipv6.txt" "${DATA_DIR}/ipv6.txt"
        CFST_F="${DATA_DIR}/ip.txt"
    else
        CFST_F="${DATA_DIR}/ip.txt"
    fi
fi

_CFST_O="${CFST_O:-result.csv}"
if [ "${_CFST_O#/}" != "${_CFST_O}" ]; then
    OUTPUT_PATH="${_CFST_O}"
else
    OUTPUT_PATH="${DATA_DIR}/${_CFST_O}"
fi

# 解析命令行参数
USER_ARGS=()
_CLI_REPORT=""
_CLI_REPORT_ONLY=""
_CLI_REPORT_FILE=""
_CLI_REPORT_PORT=""
_CLI_REPORT_WORKER_DOMAIN=""
_CLI_REPORT_UUID=""
_CLI_REPORT_GITHUB_TOKEN=""
_CLI_REPORT_GITHUB_OWNER=""
_CLI_REPORT_GITHUB_REPO=""
_CLI_REPORT_GITHUB_BRANCH=""
_CLI_REPORT_GITHUB_PATH=""
_CLI_REPORT_CONFIG=""
_CLI_SCHEDULER_TASK_NAME=""
_CLI_SCHEDULER_CRON=""

for arg in "$@"; do
    case "${arg}" in
        cfst|./cfst|/app/cfst) ;;
        -report) NEXT_ARG="report" ;;
        -report-only) _CLI_REPORT_ONLY=true ;;
        -report-file) NEXT_ARG="report_file" ;;
        -report-port) NEXT_ARG="report_port" ;;
        -report-worker-domain) NEXT_ARG="report_worker_domain" ;;
        -report-uuid) NEXT_ARG="report_uuid" ;;
        -report-github-token) NEXT_ARG="report_github_token" ;;
        -report-github-owner) NEXT_ARG="report_github_owner" ;;
        -report-github-repo) NEXT_ARG="report_github_repo" ;;
        -report-github-branch) NEXT_ARG="report_github_branch" ;;
        -report-github-path) NEXT_ARG="report_github_path" ;;
        -report-config) NEXT_ARG="report_config" ;;
        -scheduler-task-name) NEXT_ARG="scheduler_task_name" ;;
        -scheduler-cron) NEXT_ARG="scheduler_cron" ;;
        -*)
            USER_ARGS+=("${arg}")
            NEXT_ARG=""
            ;;
        *)
            if [ -n "${NEXT_ARG}" ]; then
                case "${NEXT_ARG}" in
                    report) _CLI_REPORT="${arg}" ;;
                    report_file) _CLI_REPORT_FILE="${arg}" ;;
                    report_port) _CLI_REPORT_PORT="${arg}" ;;
                    report_worker_domain) _CLI_REPORT_WORKER_DOMAIN="${arg}" ;;
                    report_uuid) _CLI_REPORT_UUID="${arg}" ;;
                    report_github_token) _CLI_REPORT_GITHUB_TOKEN="${arg}" ;;
                    report_github_owner) _CLI_REPORT_GITHUB_OWNER="${arg}" ;;
                    report_github_repo) _CLI_REPORT_GITHUB_REPO="${arg}" ;;
                    report_github_branch) _CLI_REPORT_GITHUB_BRANCH="${arg}" ;;
                    report_github_path) _CLI_REPORT_GITHUB_PATH="${arg}" ;;
                    report_config) _CLI_REPORT_CONFIG="${arg}" ;;
                    scheduler_task_name) _CLI_SCHEDULER_TASK_NAME="${arg}" ;;
                    scheduler_cron) _CLI_SCHEDULER_CRON="${arg}" ;;
                esac
                NEXT_ARG=""
            else
                USER_ARGS+=("${arg}")
            fi
            ;;
    esac
done

# 合并环境变量和命令行参数
_MERGE_REPORT="${_CLI_REPORT:-${CFST_REPORT}}"
_MERGE_REPORT_ONLY="${_CLI_REPORT_ONLY:-${CFST_REPORT_ONLY}}"
_MERGE_REPORT_FILE="${_CLI_REPORT_FILE:-${CFST_REPORT_FILE}}"
_MERGE_REPORT_PORT="${_CLI_REPORT_PORT:-${CFST_REPORT_PORT}}"
_MERGE_REPORT_WORKER_DOMAIN="${_CLI_REPORT_WORKER_DOMAIN:-${CFST_REPORT_WORKER_DOMAIN}}"
_MERGE_REPORT_UUID="${_CLI_REPORT_UUID:-${CFST_REPORT_UUID}}"
_MERGE_REPORT_GITHUB_TOKEN="${_CLI_REPORT_GITHUB_TOKEN:-${CFST_REPORT_GITHUB_TOKEN}}"
_MERGE_REPORT_GITHUB_OWNER="${_CLI_REPORT_GITHUB_OWNER:-${CFST_REPORT_GITHUB_OWNER}}"
_MERGE_REPORT_GITHUB_REPO="${_CLI_REPORT_GITHUB_REPO:-${CFST_REPORT_GITHUB_REPO}}"
_MERGE_REPORT_GITHUB_BRANCH="${_CLI_REPORT_GITHUB_BRANCH:-${CFST_REPORT_GITHUB_BRANCH}}"
_MERGE_REPORT_GITHUB_PATH="${_CLI_REPORT_GITHUB_PATH:-${CFST_REPORT_GITHUB_PATH}}"
_MERGE_REPORT_CONFIG="${_CLI_REPORT_CONFIG:-${CFST_REPORT_CONFIG}}"
_MERGE_SCHEDULER_TASK_NAME="${_CLI_SCHEDULER_TASK_NAME:-${CFST_SCHEDULER_TASK_NAME}}"
_MERGE_SCHEDULER_CRON="${_CLI_SCHEDULER_CRON:-${CFST_SCHEDULER_CRON}}"

# 构建测速命令参数
set --

[ -n "${CFST_N}" ] && set -- "$@" -n "${CFST_N}"
[ -n "${CFST_T}" ] && set -- "$@" -t "${CFST_T}"
[ -n "${CFST_DN}" ] && set -- "$@" -dn "${CFST_DN}"
[ -n "${CFST_DT}" ] && set -- "$@" -dt "${CFST_DT}"
[ -n "${CFST_TP}" ] && set -- "$@" -tp "${CFST_TP}"
[ -n "${CFST_URL}" ] && set -- "$@" -url "${CFST_URL}"
[ -n "${CFST_TL}" ] && set -- "$@" -tl "${CFST_TL}"
[ -n "${CFST_TLL}" ] && set -- "$@" -tll "${CFST_TLL}"
[ -n "${CFST_TLR}" ] && set -- "$@" -tlr "${CFST_TLR}"
[ -n "${CFST_SL}" ] && set -- "$@" -sl "${CFST_SL}"
[ -n "${CFST_P}" ] && set -- "$@" -p "${CFST_P}"
[ -n "${CFST_HTTPING_CODE}" ] && set -- "$@" -httping-code "${CFST_HTTPING_CODE}"
[ -n "${CFST_IP}" ] && set -- "$@" -ip "${CFST_IP}"

set -- "$@" -f "${CFST_F:-ip.txt}"
set -- "$@" -o "${OUTPUT_PATH}"

[ "${CFST_DD}" = "true" ] && set -- "$@" -dd
[ "${CFST_HTTPING}" = "true" ] && set -- "$@" -httping
[ "${CFST_ALLIP}" = "true" ] && set -- "$@" -allip
[ "${CFST_DEBUG}" = "true" ] && set -- "$@" -debug
[ -n "${CFST_CFCOLO}" ] && set -- "$@" -cfcolo "${CFST_CFCOLO}"

# 处理上报参数
if [ -n "${_MERGE_REPORT}" ]; then
    set -- "$@" -report "${_MERGE_REPORT}"
fi
[ "${_MERGE_REPORT_ONLY}" = "true" ] && set -- "$@" -report-only
[ -n "${_MERGE_REPORT_FILE}" ] && set -- "$@" -report-file "${_MERGE_REPORT_FILE}"
[ -n "${_MERGE_REPORT_PORT}" ] && set -- "$@" -report-port "${_MERGE_REPORT_PORT}"

[ -n "${_MERGE_REPORT_WORKER_DOMAIN}" ] && set -- "$@" -report-worker-domain "${_MERGE_REPORT_WORKER_DOMAIN}"
[ -n "${_MERGE_REPORT_UUID}" ] && set -- "$@" -report-uuid "${_MERGE_REPORT_UUID}"
[ -n "${_MERGE_REPORT_GITHUB_TOKEN}" ] && set -- "$@" -report-github-token "${_MERGE_REPORT_GITHUB_TOKEN}"
[ -n "${_MERGE_REPORT_GITHUB_OWNER}" ] && set -- "$@" -report-github-owner "${_MERGE_REPORT_GITHUB_OWNER}"
[ -n "${_MERGE_REPORT_GITHUB_REPO}" ] && set -- "$@" -report-github-repo "${_MERGE_REPORT_GITHUB_REPO}"
[ -n "${_MERGE_REPORT_GITHUB_BRANCH}" ] && set -- "$@" -report-github-branch "${_MERGE_REPORT_GITHUB_BRANCH}"
[ -n "${_MERGE_REPORT_GITHUB_PATH}" ] && set -- "$@" -report-github-path "${_MERGE_REPORT_GITHUB_PATH}"
[ -n "${_MERGE_REPORT_CONFIG}" ] && set -- "$@" -report-config "${_MERGE_REPORT_CONFIG}"

# 显示配置信息
echo "============================================"
echo " CloudflareSpeedTest Docker"
echo "============================================"
echo " IP File:     ${CFST_F:-ip.txt}"
echo " Output:      ${OUTPUT_PATH}"
echo " Threads:     ${CFST_N:-200}"
echo " Mode:        $([ "${CFST_HTTPING}" = "true" ] && echo "HTTP" || echo "TCP")"
echo " Delay:       ${CFST_TLL:-0} ~ ${CFST_TL:-9999} ms"
echo " Loss Rate:   ${CFST_TLR:-1.0}"
echo " Min Speed:   ${CFST_SL:-0} MB/s"
echo " All IP:      ${CFST_ALLIP:-false}"
if [ -n "${_MERGE_REPORT}" ]; then
echo " Report:      ${_MERGE_REPORT} (支持逗号分隔多平台)"
fi
if [ -n "${_MERGE_REPORT_GITHUB_TOKEN}" ] || [ -n "${_MERGE_REPORT_UUID}" ]; then
echo " Token:       ***"
fi
if [ -n "${CFST_CRON}" ]; then
echo " Cron:        ${CFST_CRON}"
fi
if [ -n "${_MERGE_SCHEDULER_CRON}" ]; then
echo " Scheduler:   ${_MERGE_SCHEDULER_CRON}"
fi
echo "============================================"
echo ""

# 如果提供了自定义命令（非选项参数），直接执行（覆盖默认行为）
if [ ${#USER_ARGS[@]} -gt 0 ] && [[ "${USER_ARGS[0]}" != -* ]]; then
    exec "${USER_ARGS[@]}"
fi

# 确定使用的 cron 配置（优先使用环境变量，其次使用命令行参数）
EFFECTIVE_CRON="${CFST_CRON:-${_MERGE_SCHEDULER_CRON}}"
EFFECTIVE_TASK_NAME="${CFST_SCHEDULER_TASK_NAME:-${_MERGE_SCHEDULER_TASK_NAME}}"

# 如果设置了 cron 配置，启动 cron 服务并设置定时任务
if [ -n "${EFFECTIVE_CRON}" ]; then
    echo "[信息] 检测定时任务配置..."
    echo "[定时任务] ✓ 检测到定时任务: ${EFFECTIVE_CRON}"
    echo ""
    
    # 检查 crond 是否可用
    if ! command -v crond >/dev/null 2>&1 && ! command -v busybox >/dev/null 2>&1; then
        echo "[定时任务] ✗ 错误: 容器中未找到 crond，请安装 cron 或 busybox"
        exit 1
    fi
    
    # 创建测速脚本
    RUN_SCRIPT="${DATA_DIR}/run_cfst.sh"
    printf '#!/bin/sh\ncd /app\nexec /app/cfst' > "${RUN_SCRIPT}"
    for arg in "$@"; do
        printf ' "%s"' "${arg}" >> "${RUN_SCRIPT}"
    done
    if [ ${#USER_ARGS[@]} -gt 0 ]; then
        for arg in "${USER_ARGS[@]}"; do
            printf ' "%s"' "${arg}" >> "${RUN_SCRIPT}"
        done
    fi
    printf '\n' >> "${RUN_SCRIPT}"
    chmod 700 "${RUN_SCRIPT}"
    
    # 设置定时任务（只写入测速任务，不保留系统默认任务）
    CRON_LINE="${EFFECTIVE_CRON} ${RUN_SCRIPT} >> ${DATA_DIR}/cron.log 2>&1 # CloudflareSpeedTest${EFFECTIVE_TASK_NAME:+ (${EFFECTIVE_TASK_NAME})}"
    echo "${CRON_LINE}" | crontab -
    
    # 保存 crontab 到持久化文件
    save_crontab_with_msg
    
    # 显示当前 cron 任务
    echo "[定时任务] 当前定时任务："
    crontab -l 2>/dev/null || echo "  无"
    echo ""
    
    echo "[定时任务] ✓ 已配置定时任务"
    echo "[定时任务]   任务名: ${EFFECTIVE_TASK_NAME:-default}"
    echo "[定时任务]   调度: ${EFFECTIVE_CRON}"
    echo "[定时任务]   脚本: ${RUN_SCRIPT}"
    echo "[定时任务]   日志: ${DATA_DIR}/cron.log"
    echo ""
    
    # 如果设置了单次执行模式，先执行一次
    if [ "${CFST_CRON_ONCE}" = "true" ]; then
        echo "[定时任务] 单次执行模式 (CFST_CRON_ONCE=true)，先执行一次测速..."
        echo ""
        echo "[测速] 完整执行命令:"
        echo "------------------------------------------------------------"
        printf "[测速]   /app/cfst"
        for arg in "$@"; do
            printf " %s" "${arg}"
        done
        printf "\n"
        echo "------------------------------------------------------------"
        echo ""
        echo "[测速] 开始执行..."
        echo ""
        "${RUN_SCRIPT}"
        EXIT_CODE=$?
        if [ ${EXIT_CODE} -eq 0 ]; then
            echo "[定时任务] ✓ 测速完成 (退出码: ${EXIT_CODE})"
        else
            echo "[定时任务] ✗ 测速异常 (退出码: ${EXIT_CODE})"
        fi
        echo ""
        echo "[定时任务] 启动定时任务守护进程..."
    else
        echo "[定时任务] 启动定时任务守护进程..."
    fi
    
    echo ""
    
    # 启动 cron 服务（后台运行）
    if command -v crond >/dev/null 2>&1; then
        crond -l 2
    elif command -v busybox >/dev/null 2>&1; then
        busybox crond -l 2
    fi
    
    echo "[定时任务] Cron 服务已启动"
    echo ""
    echo "容器将保持运行，定时任务将按计划执行"
    echo "使用以下命令管理容器："
    echo "  查看定时任务: docker exec -it <container_name> crontab -l"
    echo "  编辑定时任务: docker exec -it <container_name> crontab -e"
    echo "  查看执行日志: docker exec -it <container_name> cat ${DATA_DIR}/cron.log"
    echo "  查看容器日志: docker logs <container_name>"
    echo ""
    
    # 设置定期保存 crontab（每 5 分钟保存一次）
    while true; do
        sleep 300
        save_crontab
    done &
    
    # 保持容器运行
    tail -f /dev/null
else
    echo "[信息] 检测定时任务配置..."
    if [ -n "${EFFECTIVE_CRON}" ]; then
        echo "[信息] ✗ 定时任务配置解析失败"
    else
        echo "[信息] ✗ 未检测到定时任务配置 (CFST_CRON 或 -scheduler-cron 未设置)"
    fi
    echo "[信息] 将立即执行测速程序..."
    echo ""
    echo "[测速] 完整执行命令:"
    echo "------------------------------------------------------------"
    printf "[测速]   /app/cfst"
    for arg in "$@"; do
        printf " %s" "${arg}"
    done
    if [ ${#USER_ARGS[@]} -gt 0 ]; then
        for arg in "${USER_ARGS[@]}"; do
            printf " %s" "${arg}"
        done
    fi
    printf "\n"
    echo "------------------------------------------------------------"
    echo ""
    echo "[测速] 开始执行..."
    echo ""
    
    # 执行测速程序
    if [ "${IS_TTY}" = "false" ]; then
        if command -v script >/dev/null 2>&1 || [ -x /usr/bin/script ]; then
            SCRIPT_CMD="script"
            [ -x /usr/bin/script ] && SCRIPT_CMD="/usr/bin/script"
            echo "[信息] 非交互式终端，已自动启用伪终端以优化进度条显示"
            echo ""
            CFST_CMD="stty cols 80 rows 24 2>/dev/null; export COLUMNS=80; /app/cfst"
            for arg in "$@"; do
                CFST_CMD="${CFST_CMD} $(printf '%q' "$arg")"
            done
            if [ ${#USER_ARGS[@]} -gt 0 ]; then
                for arg in "${USER_ARGS[@]}"; do
                    CFST_CMD="${CFST_CMD} $(printf '%q' "$arg")"
                done
            fi
            exec "${SCRIPT_CMD}" -qfc "${CFST_CMD}" /dev/null
        else
            echo "[信息] 当前为非交互式终端模式，进度条将使用低频刷新方式显示"
            echo ""
            if [ ${#USER_ARGS[@]} -gt 0 ]; then
                exec -- /app/cfst "$@" "${USER_ARGS[@]}"
            else
                exec -- /app/cfst "$@"
            fi
        fi
    else
        if [ ${#USER_ARGS[@]} -gt 0 ]; then
            exec -- /app/cfst "$@" "${USER_ARGS[@]}"
        else
            exec -- /app/cfst "$@"
        fi
    fi
fi
