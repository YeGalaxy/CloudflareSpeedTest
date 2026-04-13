#!/bin/bash
set -e

DATA_DIR="/app/cfst"
INPUT_DIR="/app"
CONFIG_DIR="/app/config"

mkdir -p "${DATA_DIR}" "${CONFIG_DIR}"

if [ -f "${DATA_DIR}/ip.txt" ]; then
    CFST_F="${DATA_DIR}/ip.txt"
fi

if [ -f "${DATA_DIR}/ipv6.txt" ]; then
    IPV6_FILE="${DATA_DIR}/ipv6.txt"
else
    IPV6_FILE="${INPUT_DIR}/ipv6.txt"
fi

OUTPUT_PATH="${DATA_DIR}/${CFST_O:-result.csv}"

ARGS=""

[ -n "${CFST_N}" ] && ARGS="${ARGS} -n ${CFST_N}"
[ -n "${CFST_T}" ] && ARGS="${ARGS} -t ${CFST_T}"
[ -n "${CFST_DN}" ] && ARGS="${ARGS} -dn ${CFST_DN}"
[ -n "${CFST_DT}" ] && ARGS="${ARGS} -dt ${CFST_DT}"
[ -n "${CFST_TP}" ] && ARGS="${ARGS} -tp ${CFST_TP}"
[ -n "${CFST_URL}" ] && ARGS="${ARGS} -url ${CFST_URL}"
[ -n "${CFST_TL}" ] && ARGS="${ARGS} -tl ${CFST_TL}"
[ -n "${CFST_TLL}" ] && ARGS="${ARGS} -tll ${CFST_TLL}"
[ -n "${CFST_TLR}" ] && ARGS="${ARGS} -tlr ${CFST_TLR}"
[ -n "${CFST_SL}" ] && ARGS="${ARGS} -sl ${CFST_SL}"
[ -n "${CFST_P}" ] && ARGS="${ARGS} -p ${CFST_P}"
[ -n "${CFST_HTTPING_CODE}" ] && ARGS="${ARGS} -httping-code ${CFST_HTTPING_CODE}"
[ -n "${CFST_IP}" ] && ARGS="${ARGS} -ip ${CFST_IP}"

ARGS="${ARGS} -f ${CFST_F:-ip.txt}"
ARGS="${ARGS} -o ${OUTPUT_PATH}"

[ "${CFST_DD}" = "true" ] && ARGS="${ARGS} -dd"
[ "${CFST_HTTPING}" = "true" ] && ARGS="${ARGS} -httping"
[ "${CFST_ALLIP}" = "true" ] && ARGS="${ARGS} -allip"
[ "${CFST_DEBUG}" = "true" ] && ARGS="${ARGS} -debug"
[ -n "${CFST_CFCOLO}" ] && ARGS="${ARGS} -cfcolo ${CFST_CFCOLO}"

if [ -n "${CFST_REPORT}" ]; then
    ARGS="${ARGS} -report ${CFST_REPORT}"
fi
if [ "${CFST_REPORT_ONLY}" = "true" ]; then
    ARGS="${ARGS} -report-only"
fi
if [ -n "${CFST_REPORT_FILE}" ]; then
    ARGS="${ARGS} -report-file ${CFST_REPORT_FILE}"
fi
if [ -n "${CFST_REPORT_PORT}" ]; then
    ARGS="${ARGS} -report-port ${CFST_REPORT_PORT}"
fi
if [ -n "${CFST_REPORT_WORKER_DOMAIN}" ]; then
    ARGS="${ARGS} -report-worker-domain ${CFST_REPORT_WORKER_DOMAIN}"
fi
if [ -n "${CFST_REPORT_UUID}" ]; then
    ARGS="${ARGS} -report-uuid ${CFST_REPORT_UUID}"
fi
if [ -n "${CFST_REPORT_GITHUB_TOKEN}" ]; then
    ARGS="${ARGS} -report-github-token ${CFST_REPORT_GITHUB_TOKEN}"
fi
if [ -n "${CFST_REPORT_GITHUB_OWNER}" ]; then
    ARGS="${ARGS} -report-github-owner ${CFST_REPORT_GITHUB_OWNER}"
fi
if [ -n "${CFST_REPORT_GITHUB_REPO}" ]; then
    ARGS="${ARGS} -report-github-repo ${CFST_REPORT_GITHUB_REPO}"
fi
if [ -n "${CFST_REPORT_GITHUB_BRANCH}" ]; then
    ARGS="${ARGS} -report-github-branch ${CFST_REPORT_GITHUB_BRANCH}"
fi
if [ -n "${CFST_REPORT_GITHUB_PATH}" ]; then
    ARGS="${ARGS} -report-github-path ${CFST_REPORT_GITHUB_PATH}"
fi

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
if [ -n "${CFST_REPORT}" ]; then
echo " Report:      ${CFST_REPORT}"
fi
if [ -n "${CFST_CRON}" ]; then
echo " Cron:        ${CFST_CRON}"
fi
echo "============================================"
echo ""

if [ -n "${CFST_CRON}" ]; then
    echo "[定时任务] 检测到定时任务配置: ${CFST_CRON}"

    if ! command -v crond &> /dev/null && ! command -v busybox &> /dev/null; then
        echo "[定时任务] 错误: 容器中未找到 crond，请安装 cron 或 busybox"
        exit 1
    fi

    CRON_CMD="/app/cfst ${ARGS}"
    CRON_LINE="${CFST_CRON} ${CRON_CMD} # CloudflareSpeedTest"

    echo "${CRON_LINE}" > /etc/crontabs/root 2>/dev/null || echo "${CRON_LINE}" > /var/spool/cron/crontabs/root 2>/dev/null || echo "${CRON_LINE}" > /tmp/crontab

    echo "[定时任务] 已配置定时任务"
    echo "[定时任务] 调度: ${CFST_CRON}"
    echo "[定时任务] 命令: ${CRON_CMD}"

    if [ "${CFST_CRON_ONCE}" = "true" ]; then
        echo "[定时任务] 单次执行模式，先执行一次测速..."
        ./cfst ${ARGS}
        echo "[定时任务] 测速完成，启动定时任务..."
    fi

    echo "[定时任务] 启动 cron 守护进程..."

    if command -v crond &> /dev/null; then
        crond -f -l 2
    elif command -v busybox &> /dev/null; then
        busybox crond -f -l 2
    fi
else
    exec ./cfst ${ARGS}
fi
