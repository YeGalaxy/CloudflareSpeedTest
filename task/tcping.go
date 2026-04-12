package task

import (
	"fmt"
	"net"
	"sort"
	"strconv"
	"sync"
	"time"

	"github.com/XIU2/CloudflareSpeedTest/utils"
)

// 常量定义
const (
	tcpConnectTimeout = time.Second * 1 // TCP连接超时时间
	maxRoutine        = 1000            // 最大并发数
	defaultRoutines   = 200             // 默认并发数
	defaultPort       = 443             // 默认TCP端口
	defaultPingTimes  = 4               // 默认Ping次数
)

// 全局变量
var (
	Routines      = defaultRoutines  // 并发数
	TCPPort   int = defaultPort      // TCP端口
	PingTimes int = defaultPingTimes // Ping次数
)

// Ping 结构体，用于管理延迟测速任务
type Ping struct {
	wg      *sync.WaitGroup    // 等待组，用于等待所有goroutine完成
	m       *sync.Mutex        // 互斥锁，用于保护csv数据
	ips     []*net.IPAddr      // IP地址列表
	csv     utils.PingDelaySet // 测速结果集合
	control chan bool          // 并发控制通道
	bar     *utils.Bar         // 进度条
}

// checkPingDefault 检查并设置默认值
func checkPingDefault() {
	if Routines <= 0 {
		Routines = defaultRoutines
	}
	if TCPPort <= 0 || TCPPort >= 65535 {
		TCPPort = defaultPort
	}
	if PingTimes <= 0 {
		PingTimes = defaultPingTimes
	}
}

// NewPing 创建新的Ping实例
func NewPing() *Ping {
	checkPingDefault()
	ips := loadIPRanges()
	return &Ping{
		wg:      &sync.WaitGroup{},
		m:       &sync.Mutex{},
		ips:     ips,
		csv:     make(utils.PingDelaySet, 0),
		control: make(chan bool, Routines),
		bar:     utils.NewBar(len(ips), "可用:", ""),
	}
}

// Run 执行延迟测速
func (p *Ping) Run() utils.PingDelaySet {
	if len(p.ips) == 0 {
		return p.csv
	}
	// 根据模式打印开始信息
	if Httping {
		utils.Cyan.Printf("开始延迟测速（模式：HTTP, 端口：%d, 范围：%v ~ %v ms, 丢包：%.2f)\n", TCPPort, utils.InputMinDelay.Milliseconds(), utils.InputMaxDelay.Milliseconds(), utils.InputMaxLossRate)
	} else {
		utils.Cyan.Printf("开始延迟测速（模式：TCP, 端口：%d, 范围：%v ~ %v ms, 丢包：%.2f)\n", TCPPort, utils.InputMinDelay.Milliseconds(), utils.InputMaxDelay.Milliseconds(), utils.InputMaxLossRate)
	}
	// 启动并发测速
	for _, ip := range p.ips {
		p.wg.Add(1)
		p.control <- false
		go p.start(ip)
	}
	p.wg.Wait()
	p.bar.Done()
	sort.Sort(p.csv)
	return p.csv
}

// start 启动单个IP的测速goroutine
func (p *Ping) start(ip *net.IPAddr) {
	defer p.wg.Done()
	p.tcpingHandler(ip)
	<-p.control
}

// tcping 执行TCP连接测试
// 返回: 连接是否成功, 连接耗时
func (p *Ping) tcping(ip *net.IPAddr) (bool, time.Duration) {
	startTime := time.Now()
	var fullAddress string
	// 根据IP类型格式化地址
	if isIPv4(ip.String()) {
		fullAddress = fmt.Sprintf("%s:%d", ip.String(), TCPPort)
	} else {
		fullAddress = fmt.Sprintf("[%s]:%d", ip.String(), TCPPort)
	}
	conn, err := net.DialTimeout("tcp", fullAddress, tcpConnectTimeout)
	if err != nil {
		return false, 0
	}
	defer conn.Close()
	duration := time.Since(startTime)
	return true, duration
}

// checkConnection 检查连接，根据模式选择HTTP或TCP测试
// 返回: 成功次数, 总延迟, 数据中心代码
func (p *Ping) checkConnection(ip *net.IPAddr) (recv int, totalDelay time.Duration, colo string) {
	if Httping {
		recv, totalDelay, colo = p.httping(ip)
		return
	}
	colo = "" // TCPing 不获取 colo
	for i := 0; i < PingTimes; i++ {
		if ok, delay := p.tcping(ip); ok {
			recv++
			totalDelay += delay
		}
	}
	return
}

// appendIPData 添加测速数据到结果集（线程安全）
func (p *Ping) appendIPData(data *utils.PingData) {
	p.m.Lock()
	defer p.m.Unlock()
	p.csv = append(p.csv, utils.CloudflareIPData{
		PingData: data,
	})
}

// tcpingHandler 处理单个IP的TCP测速
func (p *Ping) tcpingHandler(ip *net.IPAddr) {
	recv, totalDlay, colo := p.checkConnection(ip)
	nowAble := len(p.csv)
	if recv != 0 {
		nowAble++
	}
	p.bar.Grow(1, strconv.Itoa(nowAble))
	if recv == 0 {
		return
	}
	// 计算平均延迟并保存数据
	data := &utils.PingData{
		IP:       ip,
		Sended:   PingTimes,
		Received: recv,
		Delay:    totalDlay / time.Duration(recv),
		Colo:     colo,
	}
	p.appendIPData(data)
}
