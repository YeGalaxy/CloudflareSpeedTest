package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"runtime"
	"strings"
	"time"

	"github.com/XIU2/CloudflareSpeedTest/task"
	"github.com/XIU2/CloudflareSpeedTest/utils"
)

var (
	version, versionNew string
)

var (
	reportTarget       string
	reportWorkerDomain string
	reportUUID         string
	reportGitHubToken  string
	reportGitHubOwner  string
	reportGitHubRepo   string
	reportGitHubBranch string
	reportGitHubPath   string
	reportConfigPath   string
	reportOnly         bool
	reportFile         string
	reportPort         int
	schedulerMode      bool
	schedulerList      bool
	schedulerDelete    string
	schedulerCron      string
	schedulerTaskName  string
)

func init() {
	var printVersion bool
	var help = `
CloudflareSpeedTest ` + version + `
测试各个 CDN 或网站所有 IP 的延迟和速度，获取最快 IP (IPv4+IPv6)！
https://github.com/XIU2/CloudflareSpeedTest

参数：
    -n 200
        延迟测速线程；越多延迟测速越快，性能弱的设备 (如路由器) 请勿太高；(默认 200 最多 1000)
    -t 4
        延迟测速次数；单个 IP 延迟测速的次数；(默认 4 次)
    -dn 10
        下载测速数量；延迟测速并排序后，从最低延迟起下载测速的数量；(默认 10 个)
    -dt 10
        下载测速时间；单个 IP 下载测速最长时间，不能太短；(默认 10 秒)
    -tp 443
        指定测速端口；延迟测速/下载测速时使用的端口；(默认 443 端口)
    -url https://cf.xiu2.xyz/url
        指定测速地址；延迟测速(HTTPing)/下载测速时使用的地址，默认地址不保证可用性，建议自建；

    -httping
        切换测速模式；延迟测速模式改为 HTTP 协议，所用测试地址为 [-url] 参数；(默认 TCPing)
    -httping-code 200
        有效状态代码；HTTPing 延迟测速时网页返回的有效 HTTP 状态码，仅限一个；(默认 200 301 302)
    -cfcolo HKG,KHH,NRT,LAX,SEA,SJC,FRA,MAD
        匹配指定地区；IATA 机场地区码或国家/城市码，英文逗号分隔，仅 HTTPing 模式可用；(默认 所有地区)

    -tl 200
        平均延迟上限；只输出低于指定平均延迟的 IP，各上下限条件可搭配使用；(默认 9999 ms)
    -tll 40
        平均延迟下限；只输出高于指定平均延迟的 IP；(默认 0 ms)
    -tlr 0.2
        丢包几率上限；只输出低于/等于指定丢包率的 IP，范围 0.00~1.00，0 过滤掉任何丢包的 IP；(默认 1.00)
    -sl 5
        下载速度下限；只输出高于指定下载速度的 IP，凑够指定数量 [-dn] 才会停止测速；(默认 0.00 MB/s)

    -p 10
        显示结果数量；测速后直接显示指定数量的结果，为 0 时不显示结果直接退出；(默认 10 个)
    -f ip.txt
        IP段数据文件；如路径含有空格请加上引号；支持其他 CDN IP段；(默认 ip.txt)
    -ip 1.1.1.1,2.2.2.2/24,2606:4700::/32
        指定IP段数据；直接通过参数指定要测速的 IP 段数据，英文逗号分隔；(默认 空)
    -o result.csv
        写入结果文件；如路径含有空格请加上引号；值为空时不写入文件 [-o ""]；(默认 result.csv)

    -dd
        禁用下载测速；禁用后测速结果会按延迟排序 (默认按下载速度排序)；(默认 启用)
    -allip
        测速全部的IP；对 IP 段中的每个 IP (仅支持 IPv4) 进行测速；(默认 每个 /24 段随机测速一个 IP)

    -debug
        调试输出模式；会在一些非预期情况下输出更多日志以便判断原因；(默认 关闭)

结果上报参数：
    -report cloudflare,github
        上报目标；测速完成后上报结果，支持 cloudflare（Workers API）和 github；多个目标用英文逗号分隔；(默认 空 不上报)
    -report-only
        仅上报模式；跳过测速，直接上报已有的结果文件；(配合 -report 使用)
    -report-file result.csv
        指定上报的结果文件路径；(配合 -report-only 使用，默认 result.csv)
    -report-port 443
        指定上报时使用的端口；(配合 -report-only 使用，默认 443)
    -report-worker-domain example.com
        Cloudflare Workers 域名；(配合 -report cloudflare 使用)
    -report-uuid your-uuid
        Cloudflare Workers UUID；(配合 -report cloudflare 使用)
    -report-github-token ghp_xxxx
        GitHub Token；(配合 -report github 使用)
    -report-github-owner username
        GitHub 仓库所有者；(配合 -report github 使用)
    -report-github-owner repo
        GitHub 仓库名称；(配合 -report github 使用)
    -report-github-branch main
        GitHub 分支；(默认 main)
    -report-github-path preferred_ips.txt
        GitHub 文件路径；(默认 preferred_ips.txt)
    -report-config .cloudflare_speedtest_config.json
        上报配置文件路径；(默认 .cloudflare_speedtest_config.json)

定时任务参数：
    -scheduler
        设置定时任务；交互式创建定时任务；
    -scheduler-list
        列出定时任务；显示当前已配置的所有定时任务；
    -scheduler-delete task_name
        删除定时任务；删除指定名称的定时任务；
    -scheduler-cron "0 2 * * *"
        定时任务表达式；直接指定 cron 表达式创建定时任务（非交互式）；
    -scheduler-task-name cfst_daily
        定时任务名称；配合 -scheduler-cron 使用指定任务名称；

    -v
        打印程序版本 + 检查版本更新
    -h
        打印帮助说明
`
	var minDelay, maxDelay, downloadTime int
	var maxLossRate float64
	flag.IntVar(&task.Routines, "n", 200, "延迟测速线程")
	flag.IntVar(&task.PingTimes, "t", 4, "延迟测速次数")
	flag.IntVar(&task.TestCount, "dn", 10, "下载测速数量")
	flag.IntVar(&downloadTime, "dt", 10, "下载测速时间")
	flag.IntVar(&task.TCPPort, "tp", 443, "指定测速端口")
	flag.StringVar(&task.URL, "url", "https://cf.xiu2.xyz/url", "指定测速地址")

	flag.BoolVar(&task.Httping, "httping", false, "切换测速模式")
	flag.IntVar(&task.HttpingStatusCode, "httping-code", 0, "有效状态代码")
	flag.StringVar(&task.HttpingCFColo, "cfcolo", "", "匹配指定地区")

	flag.IntVar(&maxDelay, "tl", 9999, "平均延迟上限")
	flag.IntVar(&minDelay, "tll", 0, "平均延迟下限")
	flag.Float64Var(&maxLossRate, "tlr", 1, "丢包几率上限")
	flag.Float64Var(&task.MinSpeed, "sl", 0, "下载速度下限")

	flag.IntVar(&utils.PrintNum, "p", 10, "显示结果数量")
	flag.StringVar(&task.IPFile, "f", "ip.txt", "IP段数据文件")
	flag.StringVar(&task.IPText, "ip", "", "指定IP段数据")
	flag.StringVar(&utils.Output, "o", "result.csv", "输出结果文件")

	flag.BoolVar(&task.Disable, "dd", false, "禁用下载测速")
	flag.BoolVar(&task.TestAll, "allip", false, "测速全部 IP")

	flag.BoolVar(&utils.Debug, "debug", false, "调试输出模式")

	flag.StringVar(&reportTarget, "report", "", "上报目标")
	flag.BoolVar(&reportOnly, "report-only", false, "仅上报模式")
	flag.StringVar(&reportFile, "report-file", "", "上报结果文件")
	flag.IntVar(&reportPort, "report-port", 443, "上报端口")
	flag.StringVar(&reportWorkerDomain, "report-worker-domain", "", "Workers 域名")
	flag.StringVar(&reportUUID, "report-uuid", "", "Workers UUID")
	flag.StringVar(&reportGitHubToken, "report-github-token", "", "GitHub Token")
	flag.StringVar(&reportGitHubOwner, "report-github-owner", "", "GitHub 所有者")
	flag.StringVar(&reportGitHubRepo, "report-github-repo", "", "GitHub 仓库")
	flag.StringVar(&reportGitHubBranch, "report-github-branch", "main", "GitHub 分支")
	flag.StringVar(&reportGitHubPath, "report-github-path", "preferred_ips.txt", "GitHub 路径")
	flag.StringVar(&reportConfigPath, "report-config", ".cloudflare_speedtest_config.json", "上报配置文件")

	flag.BoolVar(&schedulerMode, "scheduler", false, "设置定时任务")
	flag.BoolVar(&schedulerList, "scheduler-list", false, "列出定时任务")
	flag.StringVar(&schedulerDelete, "scheduler-delete", "", "删除定时任务")
	flag.StringVar(&schedulerCron, "scheduler-cron", "", "cron 表达式")
	flag.StringVar(&schedulerTaskName, "scheduler-task-name", "", "定时任务名称")

	flag.BoolVar(&printVersion, "v", false, "打印程序版本")
	flag.Usage = func() { fmt.Print(help) }
	flag.Parse()

	if task.MinSpeed > 0 && time.Duration(maxDelay)*time.Millisecond == utils.InputMaxDelay {
		utils.Yellow.Println("[提示] 在使用 [-sl] 参数时，建议搭配 [-tl] 参数，以避免因凑不够 [-dn] 数量而一直测速...")
	}
	utils.InputMaxDelay = time.Duration(maxDelay) * time.Millisecond
	utils.InputMinDelay = time.Duration(minDelay) * time.Millisecond
	utils.InputMaxLossRate = float32(maxLossRate)
	task.Timeout = time.Duration(downloadTime) * time.Second
	task.HttpingCFColomap = task.MapColoMap()

	if printVersion {
		println(version)
		fmt.Println("检查版本更新中...")
		checkUpdate()
		if versionNew != "" {
			utils.Yellow.Printf("*** 发现新版本 [%s]！请前往 [https://github.com/XIU2/CloudflareSpeedTest] 更新！ ***", versionNew)
		} else {
			utils.Green.Println("当前为最新版本 [" + version + "]！")
		}
		os.Exit(0)
	}

	if schedulerList {
		handleSchedulerList()
		os.Exit(0)
	}

	if schedulerDelete != "" {
		handleSchedulerDelete()
		os.Exit(0)
	}

	if schedulerCron != "" {
		handleSchedulerCron()
		os.Exit(0)
	}

	if schedulerMode {
		handleSchedulerInteractive()
		os.Exit(0)
	}

	if reportOnly {
		handleReportOnly()
		os.Exit(0)
	}
}

func main() {
	task.InitRandSeed()
	utils.LoadAirportCodes()

	fmt.Printf("# XIU2/CloudflareSpeedTest %s \n\n", version)

	pingData := task.NewPing().Run().FilterDelay().FilterLossRate()
	speedData := task.TestDownloadSpeed(pingData)
	utils.ExportCsv(speedData)
	speedData.Print()

	if reportTarget != "" {
		if len(speedData) > 0 {
			handleReport()
		} else {
			utils.Yellow.Println("[上报] 测速结果 IP 数量为 0，跳过上报。")
		}
	}

	endPrint()
}

func endPrint() {
	if utils.NoPrintResult() {
		return
	}
	if runtime.GOOS == "windows" {
		fmt.Printf("按下 回车键 或 Ctrl+C 退出。")
		fmt.Scanln()
	}
}

func checkUpdate() {
	timeout := 10 * time.Second
	client := http.Client{Timeout: timeout}
	res, err := client.Get("https://api.xiu2.xyz/ver/cloudflarespeedtest.txt")
	if err != nil {
		return
	}
	body, err := io.ReadAll(res.Body)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if string(body) != version {
		versionNew = string(body)
	}
}

func handleReport() {
	cfg := buildReportConfig()

	if reportConfigPath != "" {
		savedCfg, err := utils.LoadConfig(reportConfigPath)
		if err == nil {
			if cfg.WorkerDomain == "" {
				cfg.WorkerDomain = savedCfg.WorkerDomain
			}
			if cfg.UUID == "" {
				cfg.UUID = savedCfg.UUID
			}
			if cfg.GitHubToken == "" {
				cfg.GitHubToken = savedCfg.GitHubToken
			}
			if cfg.GitHubOwner == "" {
				cfg.GitHubOwner = savedCfg.GitHubOwner
			}
			if cfg.GitHubRepo == "" {
				cfg.GitHubRepo = savedCfg.GitHubRepo
			}
			if cfg.GitHubBranch == "" || cfg.GitHubBranch == "main" {
				cfg.GitHubBranch = savedCfg.GitHubBranch
			}
			if cfg.GitHubPath == "" || cfg.GitHubPath == "preferred_ips.txt" {
				cfg.GitHubPath = savedCfg.GitHubPath
			}
		}
	}

	if err := utils.SaveConfig(reportConfigPath, cfg); err != nil {
		utils.Yellow.Printf("[上报] 保存配置文件失败: %v\n", err)
	}

	targets := strings.Split(reportTarget, ",")
	for _, target := range targets {
		target = strings.TrimSpace(target)
		if target == "" {
			continue
		}
		utils.Cyan.Printf("[上报] 上报目标: %s\n", target)
		if err := utils.ReportResults(utils.Output, cfg, target, task.TCPPort); err != nil {
			utils.Red.Printf("[上报] 上报失败 [%s]: %v\n", target, err)
		} else {
			utils.Green.Printf("[上报] 上报成功 [%s]\n", target)
		}
	}
}

func buildReportConfig() *utils.Config {
	return &utils.Config{
		WorkerDomain: reportWorkerDomain,
		UUID:         reportUUID,
		GitHubToken:  reportGitHubToken,
		GitHubOwner:  reportGitHubOwner,
		GitHubRepo:   reportGitHubRepo,
		GitHubBranch: reportGitHubBranch,
		GitHubPath:   reportGitHubPath,
	}
}

func handleReportOnly() {
	if reportTarget == "" {
		utils.Red.Printf("[上报] 错误: 仅上报模式需要指定 -report 参数\n")
		os.Exit(1)
	}

	resultPath := reportFile
	if resultPath == "" {
		resultPath = utils.Output
	}

	port := reportPort
	if port <= 0 {
		port = 443
	}

	fmt.Printf("# CloudflareSpeedTest 仅上报模式 \n\n")
	utils.Cyan.Printf("[上报] 结果文件: %s\n", resultPath)
	utils.Cyan.Printf("[上报] 上报目标: %s\n", reportTarget)
	utils.Cyan.Printf("[上报] 上报端口: %d\n", port)

	cfg := buildReportConfig()

	if reportConfigPath != "" {
		savedCfg, err := utils.LoadConfig(reportConfigPath)
		if err == nil {
			if cfg.WorkerDomain == "" {
				cfg.WorkerDomain = savedCfg.WorkerDomain
			}
			if cfg.UUID == "" {
				cfg.UUID = savedCfg.UUID
			}
			if cfg.GitHubToken == "" {
				cfg.GitHubToken = savedCfg.GitHubToken
			}
			if cfg.GitHubOwner == "" {
				cfg.GitHubOwner = savedCfg.GitHubOwner
			}
			if cfg.GitHubRepo == "" {
				cfg.GitHubRepo = savedCfg.GitHubRepo
			}
			if cfg.GitHubBranch == "" || cfg.GitHubBranch == "main" {
				cfg.GitHubBranch = savedCfg.GitHubBranch
			}
			if cfg.GitHubPath == "" || cfg.GitHubPath == "preferred_ips.txt" {
				cfg.GitHubPath = savedCfg.GitHubPath
			}
		}
	}

	if err := utils.SaveConfig(reportConfigPath, cfg); err != nil {
		utils.Yellow.Printf("[上报] 保存配置文件失败: %v\n", err)
	}

	targets := strings.Split(reportTarget, ",")
	hasError := false
	for _, target := range targets {
		target = strings.TrimSpace(target)
		if target == "" {
			continue
		}
		utils.Cyan.Printf("[上报] 上报目标: %s\n", target)
		if err := utils.ReportResults(resultPath, cfg, target, port); err != nil {
			utils.Red.Printf("[上报] 上报失败 [%s]: %v\n", target, err)
			hasError = true
		} else {
			utils.Green.Printf("[上报] 上报成功 [%s]\n", target)
		}
	}
	if hasError {
		os.Exit(1)
	}
}

func handleSchedulerList() {
	tm := utils.NewTaskManager()
	tasks := tm.ListTasks()
	utils.PrintTaskList(tasks)
}

func handleSchedulerDelete() {
	tm := utils.NewTaskManager()
	if err := tm.DeleteTask(schedulerDelete); err != nil {
		utils.Red.Printf("[定时任务] 删除失败: %v\n", err)
		os.Exit(1)
	}
}

func handleSchedulerCron() {
	tm := utils.NewTaskManager()
	taskName := schedulerTaskName
	if taskName == "" {
		taskName = fmt.Sprintf("cfst_auto_%d", time.Now().Unix())
	}

	command := utils.BuildFullCommand(buildCurrentArgs())

	if runtime.GOOS == "windows" {
		if err := tm.CreateTask(taskName, utils.TaskTypeDaily, schedulerCron, command); err != nil {
			utils.Red.Printf("[定时任务] 创建失败: %v\n", err)
			os.Exit(1)
		}
	} else {
		if err := tm.CreateTask(taskName, utils.TaskTypeCron, schedulerCron, command); err != nil {
			utils.Red.Printf("[定时任务] 创建失败: %v\n", err)
			os.Exit(1)
		}
	}
}

func handleSchedulerInteractive() {
	tm := utils.NewTaskManager()
	tasks := tm.ListTasks()
	utils.PrintTaskList(tasks)

	fmt.Println()
	fmt.Println("请选择操作：")
	fmt.Println("  1. 创建新的定时任务")
	fmt.Println("  2. 删除定时任务")
	fmt.Println("  3. 退出")

	var choice int
	fmt.Print("请输入选项 (1-3): ")
	fmt.Scanln(&choice)

	switch choice {
	case 1:
		createTaskInteractive(tm)
	case 2:
		deleteTaskInteractive(tm)
	case 3:
		return
	default:
		utils.Yellow.Println("[定时任务] 无效选项")
	}
}

func createTaskInteractive(tm *utils.TaskManager) {
	taskName := ""
	fmt.Print("请输入任务名称: ")
	fmt.Scanln(&taskName)
	if taskName == "" {
		taskName = fmt.Sprintf("cfst_task_%d", time.Now().Unix())
	}

	command := utils.BuildFullCommand(buildCurrentArgs())

	if runtime.GOOS == "windows" {
		fmt.Println("请选择调度类型：")
		fmt.Println("  1. 每天 (指定时间)")
		fmt.Println("  2. 每小时")
		fmt.Println("  3. 每周 (指定星期和时间)")

		var scheduleType int
		fmt.Print("请输入选项 (1-3): ")
		fmt.Scanln(&scheduleType)

		var schedule string
		var taskType utils.TaskType

		switch scheduleType {
		case 1:
			taskType = utils.TaskTypeDaily
			fmt.Print("请输入执行时间 (HH:MM, 如 02:00): ")
			fmt.Scanln(&schedule)
		case 2:
			taskType = utils.TaskTypeHourly
			schedule = "01:00"
		case 3:
			taskType = utils.TaskTypeWeekly
			fmt.Print("请输入星期和时间 (如 MONDAY 02:00): ")
			fmt.Scanln(&schedule)
		default:
			utils.Yellow.Println("[定时任务] 无效选项")
			return
		}

		if err := tm.CreateTask(taskName, taskType, schedule, command); err != nil {
			utils.Red.Printf("[定时任务] 创建失败: %v\n", err)
		}
	} else {
		fmt.Println("请输入 cron 表达式 (5个字段: 分 时 日 月 周)")
		fmt.Println("  示例: 0 2 * * *  (每天凌晨2点)")
		fmt.Println("  示例: 30 4 * * 1 (每周一凌晨4:30)")
		fmt.Println("  示例: 0 */6 * * * (每6小时)")

		var cronExpr string
		fmt.Print("cron 表达式: ")
		fmt.Scanln(&cronExpr)

		if err := tm.CreateTask(taskName, utils.TaskTypeCron, cronExpr, command); err != nil {
			utils.Red.Printf("[定时任务] 创建失败: %v\n", err)
		}
	}
}

func deleteTaskInteractive(tm *utils.TaskManager) {
	tasks := tm.ListTasks()
	if len(tasks) == 0 {
		utils.Yellow.Println("[定时任务] 当前没有可删除的任务")
		return
	}

	utils.PrintTaskList(tasks)

	var idx int
	fmt.Print("请输入要删除的任务编号: ")
	fmt.Scanln(&idx)

	if idx < 1 || idx > len(tasks) {
		utils.Yellow.Println("[定时任务] 无效编号")
		return
	}

	if err := tm.DeleteTask(tasks[idx-1].Name); err != nil {
		utils.Red.Printf("[定时任务] 删除失败: %v\n", err)
	}
}

func buildCurrentArgs() []string {
	var args []string

	args = append(args, fmt.Sprintf("-n %d", task.Routines))
	args = append(args, fmt.Sprintf("-t %d", task.PingTimes))
	args = append(args, fmt.Sprintf("-dn %d", task.TestCount))
	args = append(args, fmt.Sprintf("-tp %d", task.TCPPort))
	args = append(args, fmt.Sprintf("-url %s", task.URL))
	args = append(args, fmt.Sprintf("-tl %d", utils.InputMaxDelay.Milliseconds()))
	args = append(args, fmt.Sprintf("-tll %d", utils.InputMinDelay.Milliseconds()))
	args = append(args, fmt.Sprintf("-tlr %.2f", utils.InputMaxLossRate))
	args = append(args, fmt.Sprintf("-sl %.2f", task.MinSpeed))
	args = append(args, fmt.Sprintf("-p %d", utils.PrintNum))
	args = append(args, fmt.Sprintf("-o %s", utils.Output))
	args = append(args, fmt.Sprintf("-f %s", task.IPFile))

	if task.Disable {
		args = append(args, "-dd")
	}
	if task.Httping {
		args = append(args, "-httping")
	}
	if task.TestAll {
		args = append(args, "-allip")
	}
	if utils.Debug {
		args = append(args, "-debug")
	}
	if task.HttpingStatusCode > 0 {
		args = append(args, fmt.Sprintf("-httping-code %d", task.HttpingStatusCode))
	}
	if task.HttpingCFColo != "" {
		args = append(args, fmt.Sprintf("-cfcolo %s", task.HttpingCFColo))
	}
	if task.IPText != "" {
		args = append(args, fmt.Sprintf("-ip %s", task.IPText))
	}

	if reportTarget != "" {
		args = append(args, fmt.Sprintf("-report %s", reportTarget))
		if reportWorkerDomain != "" {
			args = append(args, fmt.Sprintf("-report-worker-domain %s", reportWorkerDomain))
		}
		if reportUUID != "" {
			args = append(args, fmt.Sprintf("-report-uuid %s", reportUUID))
		}
		if reportGitHubToken != "" {
			args = append(args, fmt.Sprintf("-report-github-token %s", reportGitHubToken))
		}
		if reportGitHubOwner != "" {
			args = append(args, fmt.Sprintf("-report-github-owner %s", reportGitHubOwner))
		}
		if reportGitHubRepo != "" {
			args = append(args, fmt.Sprintf("-report-github-repo %s", reportGitHubRepo))
		}
		if reportGitHubBranch != "" {
			args = append(args, fmt.Sprintf("-report-github-branch %s", reportGitHubBranch))
		}
		if reportGitHubPath != "" {
			args = append(args, fmt.Sprintf("-report-github-path %s", reportGitHubPath))
		}
	}

	return args
}
