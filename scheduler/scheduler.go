package scheduler

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"

	"github.com/XIU2/CloudflareSpeedTest/utils"
)

const (
	taskNamePrefix = "cfst_"
	cronMarker     = "# CloudflareSpeedTest"
)

type TaskType int

const (
	TaskTypeCron TaskType = iota
	TaskTypeDaily
	TaskTypeHourly
	TaskTypeWeekly
)

type Task struct {
	Name      string
	Type      TaskType
	Schedule  string
	Command   string
	Enabled   bool
	CreatedAt time.Time
}

type TaskManager struct {
	tasks []Task
}

func NewTaskManager() *TaskManager {
	return &TaskManager{tasks: make([]Task, 0)}
}

func GenerateCommand() string {
	exePath, err := os.Executable()
	if err != nil {
		exePath = "cfst"
	}
	return exePath
}

func BuildFullCommand(extraArgs []string) string {
	exePath := GenerateCommand()
	args := strings.Join(extraArgs, " ")
	if args != "" {
		return fmt.Sprintf("%s %s", exePath, args)
	}
	return exePath
}

func (tm *TaskManager) ListTasks() []Task {
	if runtime.GOOS == "windows" {
		return tm.listWindowsTasks()
	}
	return tm.listCronTasks()
}

func (tm *TaskManager) CreateTask(name string, taskType TaskType, schedule string, command string) error {
	if runtime.GOOS == "windows" {
		return tm.createWindowsTask(name, taskType, schedule, command)
	}
	return tm.createCronTask(name, schedule, command)
}

func (tm *TaskManager) DeleteTask(name string) error {
	if runtime.GOOS == "windows" {
		return tm.deleteWindowsTask(name)
	}
	return tm.deleteCronTask(name)
}

func (tm *TaskManager) EnableTask(name string) error {
	if runtime.GOOS == "windows" {
		return tm.enableWindowsTask(name)
	}
	return fmt.Errorf("cron 任务启用/禁用请手动编辑 crontab")
}

func (tm *TaskManager) DisableTask(name string) error {
	if runtime.GOOS == "windows" {
		return tm.disableWindowsTask(name)
	}
	return fmt.Errorf("cron 任务启用/禁用请手动编辑 crontab")
}

func (tm *TaskManager) GetTaskStatus(name string) (string, error) {
	if runtime.GOOS == "windows" {
		return tm.getWindowsTaskStatus(name)
	}
	return tm.getCronTaskStatus(name)
}

func isRoot() bool {
	return os.Getuid() == 0
}

func (tm *TaskManager) listCronTasks() []Task {
	var tasks []Task

	cmd := exec.Command("crontab", "-l")
	output, err := cmd.Output()
	if err != nil {
		return tasks
	}

	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.Contains(line, cronMarker) {
			parts := strings.Fields(line)
			if len(parts) >= 6 {
				schedule := strings.Join(parts[:5], " ")
				command := strings.Join(parts[5:], " ")
				name := "cron_task"
				if idx := strings.Index(command, cronMarker); idx > 0 {
					name = fmt.Sprintf("cron_%d", len(tasks)+1)
				}
				tasks = append(tasks, Task{
					Name:     name,
					Type:     TaskTypeCron,
					Schedule: schedule,
					Command:  command,
					Enabled:  true,
				})
			}
		}
	}
	return tasks
}

func (tm *TaskManager) createCronTask(name string, schedule string, command string) error {
	if err := validateCronSchedule(schedule); err != nil {
		return fmt.Errorf("cron 表达式无效: %w", err)
	}

	cronLine := fmt.Sprintf("%s %s %s", schedule, command, cronMarker)

	existingCron, err := getCronContent()
	if err != nil {
		existingCron = ""
	}

	var newCron strings.Builder
	scanner := bufio.NewScanner(strings.NewReader(existingCron))
	hasExisting := false
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, cronMarker) && strings.Contains(line, name) {
			hasExisting = true
			continue
		}
		newCron.WriteString(line + "\n")
	}

	if hasExisting {
		utils.Yellow.Printf("[定时任务] 已存在同名任务，已替换\n")
	}

	newCron.WriteString(cronLine + "\n")

	cmd := exec.Command("crontab", "-")
	cmd.Stdin = strings.NewReader(newCron.String())
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("写入 crontab 失败: %w", err)
	}

	utils.Green.Printf("[定时任务] 成功创建 cron 任务\n")
	utils.Green.Printf("[定时任务] 调度: %s\n", schedule)
	utils.Green.Printf("[定时任务] 命令: %s\n", command)
	return nil
}

func (tm *TaskManager) deleteCronTask(name string) error {
	existingCron, err := getCronContent()
	if err != nil {
		return fmt.Errorf("读取 crontab 失败: %w", err)
	}

	var newCron strings.Builder
	found := false
	scanner := bufio.NewScanner(strings.NewReader(existingCron))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, cronMarker) && strings.Contains(line, name) {
			found = true
			continue
		}
		newCron.WriteString(line + "\n")
	}

	if !found {
		return fmt.Errorf("未找到任务: %s", name)
	}

	cmd := exec.Command("crontab", "-")
	cmd.Stdin = strings.NewReader(newCron.String())
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("更新 crontab 失败: %w", err)
	}

	utils.Green.Printf("[定时任务] 成功删除任务: %s\n", name)
	return nil
}

func (tm *TaskManager) getCronTaskStatus(name string) (string, error) {
	tasks := tm.listCronTasks()
	for _, t := range tasks {
		if strings.Contains(t.Name, name) {
			return "enabled", nil
		}
	}
	return "not_found", nil
}

func getCronContent() (string, error) {
	cmd := exec.Command("crontab", "-l")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(output), nil
}

func validateCronSchedule(schedule string) error {
	parts := strings.Fields(schedule)
	if len(parts) != 5 {
		return fmt.Errorf("cron 表达式需要 5 个字段（分 时 日 月 周），当前 %d 个", len(parts))
	}
	return nil
}

func (tm *TaskManager) listWindowsTasks() []Task {
	var tasks []Task

	cmd := exec.Command("schtasks", "/query", "/fo", "csv", "/nh")
	output, err := cmd.Output()
	if err != nil {
		return tasks
	}

	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.Contains(line, taskNamePrefix) {
			fields := strings.Split(line, ",")
			if len(fields) >= 2 {
				taskName := strings.Trim(fields[0], "\"")
				status := strings.Trim(fields[1], "\"")
				tasks = append(tasks, Task{
					Name:    taskName,
					Enabled: status == "Ready",
				})
			}
		}
	}
	return tasks
}

func (tm *TaskManager) createWindowsTask(name string, taskType TaskType, schedule string, command string) error {
	fullName := taskNamePrefix + name

	var args []string
	args = append(args, "/create", "/tn", fullName, "/tr", command, "/f")

	switch taskType {
	case TaskTypeDaily:
		args = append(args, "/sc", "daily", "/st", schedule)
	case TaskTypeHourly:
		args = append(args, "/sc", "hourly", "/mo", "1")
	case TaskTypeWeekly:
		parts := strings.Split(schedule, " ")
		if len(parts) >= 2 {
			args = append(args, "/sc", "weekly", "/d", parts[0], "/st", parts[1])
		} else {
			args = append(args, "/sc", "weekly", "/st", schedule)
		}
	default:
		args = append(args, "/sc", "daily", "/st", schedule)
	}

	cmd := exec.Command("schtasks", args...)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("创建 Windows 任务失败: %w, 输出: %s", err, string(output))
	}

	utils.Green.Printf("[定时任务] 成功创建 Windows 任务: %s\n", fullName)
	return nil
}

func (tm *TaskManager) deleteWindowsTask(name string) error {
	fullName := taskNamePrefix + name

	cmd := exec.Command("schtasks", "/delete", "/tn", fullName, "/f")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("删除 Windows 任务失败: %w, 输出: %s", err, string(output))
	}

	utils.Green.Printf("[定时任务] 成功删除任务: %s\n", fullName)
	return nil
}

func (tm *TaskManager) enableWindowsTask(name string) error {
	fullName := taskNamePrefix + name

	cmd := exec.Command("schtasks", "/change", "/tn", fullName, "/enable")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("启用 Windows 任务失败: %w, 输出: %s", err, string(output))
	}

	utils.Green.Printf("[定时任务] 成功启用任务: %s\n", fullName)
	return nil
}

func (tm *TaskManager) disableWindowsTask(name string) error {
	fullName := taskNamePrefix + name

	cmd := exec.Command("schtasks", "/change", "/tn", fullName, "/disable")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("禁用 Windows 任务失败: %w, 输出: %s", err, string(output))
	}

	utils.Green.Printf("[定时任务] 成功禁用任务: %s\n", fullName)
	return nil
}

func (tm *TaskManager) getWindowsTaskStatus(name string) (string, error) {
	fullName := taskNamePrefix + name

	cmd := exec.Command("schtasks", "/query", "/tn", fullName, "/fo", "csv", "/nh")
	output, err := cmd.Output()
	if err != nil {
		return "not_found", nil
	}

	line := strings.TrimSpace(string(output))
	if strings.Contains(line, "Ready") {
		return "enabled", nil
	}
	if strings.Contains(line, "Disabled") {
		return "disabled", nil
	}
	return "unknown", nil
}

func PrintTaskList(tasks []Task) {
	if len(tasks) == 0 {
		utils.Yellow.Println("[定时任务] 当前没有已配置的定时任务")
		return
	}

	fmt.Println("\n============================================")
	fmt.Println(" 定时任务列表")
	fmt.Println("============================================")
	for i, t := range tasks {
		status := "启用"
		if !t.Enabled {
			status = "禁用"
		}
		fmt.Printf("  [%d] 名称: %s\n", i+1, t.Name)
		fmt.Printf("      状态: %s\n", status)
		if t.Schedule != "" {
			fmt.Printf("      调度: %s\n", t.Schedule)
		}
		if t.Command != "" {
			fmt.Printf("      命令: %s\n", t.Command)
		}
		fmt.Println()
	}
	fmt.Println("============================================")
}

func SetupCronFromEnv(schedule string, command string) error {
	if schedule == "" {
		return fmt.Errorf("未指定定时任务调度表达式")
	}
	if command == "" {
		return fmt.Errorf("未指定定时任务命令")
	}

	tm := NewTaskManager()
	taskName := fmt.Sprintf("cfst_auto_%d", time.Now().Unix())

	if runtime.GOOS == "windows" {
		return tm.CreateTask(taskName, TaskTypeDaily, schedule, command)
	}
	return tm.CreateTask(taskName, TaskTypeCron, schedule, command)
}
