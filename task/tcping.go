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
	wg      *sync.WaitGroup
	m       *sync.Mutex
	ips     []IPEntry
	csv     utils.PingDelaySet
	control chan bool
	bar     *utils.Bar
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

func (p *Ping) Run() utils.PingDelaySet {
	if len(p.ips) == 0 {
		return p.csv
	}
	if Httping {
		utils.Cyan.Printf("开始延迟测速（模式：HTTP, 端口：%d, 范围：%v ~ %v ms, 丢包：%.2f)\n", TCPPort, utils.InputMinDelay.Milliseconds(), utils.InputMaxDelay.Milliseconds(), utils.InputMaxLossRate)
	} else {
		utils.Cyan.Printf("开始延迟测速（模式：TCP, 端口：%d, 范围：%v ~ %v ms, 丢包：%.2f)\n", TCPPort, utils.InputMinDelay.Milliseconds(), utils.InputMaxDelay.Milliseconds(), utils.InputMaxLossRate)
	}
	for _, entry := range p.ips {
		p.wg.Add(1)
		p.control <- false
		go p.start(entry)
	}
	p.wg.Wait()
	p.bar.Done()
	sort.Sort(p.csv)
	return p.csv
}

func (p *Ping) start(entry IPEntry) {
	defer p.wg.Done()
	p.tcpingHandler(entry)
	<-p.control
}

func (p *Ping) tcping(ip *net.IPAddr, port int) (bool, time.Duration) {
	startTime := time.Now()
	var fullAddress string
	if isIPv4(ip.String()) {
		fullAddress = fmt.Sprintf("%s:%d", ip.String(), port)
	} else {
		fullAddress = fmt.Sprintf("[%s]:%d", ip.String(), port)
	}
	conn, err := net.DialTimeout("tcp", fullAddress, tcpConnectTimeout)
	if err != nil {
		return false, 0
	}
	defer conn.Close()
	duration := time.Since(startTime)
	return true, duration
}

func (p *Ping) checkConnection(entry IPEntry) (recv int, totalDelay time.Duration, colo string) {
	if Httping {
		recv, totalDelay, colo = p.httping(entry)
		return
	}
	colo = ""
	port := entry.GetPort()
	for i := 0; i < PingTimes; i++ {
		if ok, delay := p.tcping(entry.IP, port); ok {
			recv++
			totalDelay += delay
		}
	}
	return
}

func (p *Ping) appendIPData(data *utils.PingData) {
	p.m.Lock()
	defer p.m.Unlock()
	p.csv = append(p.csv, utils.CloudflareIPData{
		PingData: data,
	})
}

func (p *Ping) tcpingHandler(entry IPEntry) {
	recv, totalDlay, colo := p.checkConnection(entry)
	nowAble := len(p.csv)
	if recv != 0 {
		nowAble++
	}
	p.bar.Grow(1, strconv.Itoa(nowAble))
	if recv == 0 {
		return
	}
	data := &utils.PingData{
		IP:       entry.IP,
		Port:     entry.GetPort(),
		Tag:      entry.Tag,
		Sended:   PingTimes,
		Received: recv,
		Delay:    totalDlay / time.Duration(recv),
		Colo:     colo,
	}
	p.appendIPData(data)
}
