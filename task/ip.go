package task

import (
	"log"
	"math/rand"
	"net"
	"strconv"
	"strings"
	"time"
)

const defaultInputFile = "ip.txt"

type IPEntry struct {
	IP   *net.IPAddr
	Port int
	Tag  string
}

func (e *IPEntry) GetPort() int {
	if e.Port > 0 {
		return e.Port
	}
	return TCPPort
}

var (
	TestAll = false
	IPFile  = defaultInputFile
	IPText  string
)

func InitRandSeed() {
	rand.Seed(time.Now().UnixNano())
}

func isIPv4(ip string) bool {
	return strings.Contains(ip, ".")
}

func parseIPLine(line string) (ipPart string, port int, tag string) {
	if idx := strings.IndexByte(line, '#'); idx >= 0 {
		tag = line[idx+1:]
		line = line[:idx]
	}
	if strings.Contains(line, "]") {
		if idx := strings.LastIndexByte(line, ':'); idx > strings.IndexByte(line, ']') {
			if p, err := strconv.Atoi(line[idx+1:]); err == nil {
				port = p
				line = line[:idx]
			}
		}
		line = strings.TrimPrefix(line, "[")
		line = strings.TrimSuffix(line, "]")
	} else if strings.Contains(line, ".") {
		cidrIdx := strings.IndexByte(line, '/')
		if cidrIdx >= 0 {
			afterCIDR := line[cidrIdx+1:]
			if colonIdx := strings.IndexByte(afterCIDR, ':'); colonIdx >= 0 {
				if p, err := strconv.Atoi(afterCIDR[colonIdx+1:]); err == nil {
					port = p
					line = line[:cidrIdx] + "/" + afterCIDR[:colonIdx]
				}
			}
		} else {
			if idx := strings.LastIndexByte(line, ':'); idx >= 0 {
				if p, err := strconv.Atoi(line[idx+1:]); err == nil {
					port = p
					line = line[:idx]
				}
			}
		}
	}
	return line, port, tag
}

// randIPEndWith 生成随机 IP 末尾数字
// 对于 /32 这种单独的 IP，返回 0
func randIPEndWith(num byte) byte {
	if num == 0 { // 对于 /32 这种单独的 IP
		return byte(0)
	}
	return byte(rand.Intn(int(num)))
}

type IPRanges struct {
	ips     []*net.IPAddr
	mask    string
	firstIP net.IP
	ipNet   *net.IPNet
}

func newIPRanges() *IPRanges {
	return &IPRanges{
		ips: make([]*net.IPAddr, 0),
	}
}

// fixIP 修复 IP 格式，如果是单独 IP 则加上子网掩码，反之则获取子网掩码(r.mask)
func (r *IPRanges) fixIP(ip string) string {
	// 如果不含有 '/' 则代表不是 IP 段，而是一个单独的 IP，因此需要加上 /32 /128 子网掩码
	if i := strings.IndexByte(ip, '/'); i < 0 {
		if isIPv4(ip) {
			r.mask = "/32"
		} else {
			r.mask = "/128"
		}
		ip += r.mask
	} else {
		r.mask = ip[i:]
	}
	return ip
}

// parseCIDR 解析 IP 段，获得 IP、IP 范围、子网掩码
func (r *IPRanges) parseCIDR(ip string) {
	var err error
	if r.firstIP, r.ipNet, err = net.ParseCIDR(r.fixIP(ip)); err != nil {
		log.Fatalln("ParseCIDR err", err)
	}
}

// appendIPv4 添加 IPv4 地址到列表
func (r *IPRanges) appendIPv4(d byte) {
	r.appendIP(net.IPv4(r.firstIP[12], r.firstIP[13], r.firstIP[14], d))
}

// appendIP 添加 IP 地址到列表
func (r *IPRanges) appendIP(ip net.IP) {
	r.ips = append(r.ips, &net.IPAddr{IP: ip})
}

// getIPRange 返回第四段 ip 的最小值及可用数目
func (r *IPRanges) getIPRange() (minIP, hosts byte) {
	minIP = r.firstIP[15] & r.ipNet.Mask[3] // IP 第四段最小值

	// 根据子网掩码获取主机数量
	m := net.IPv4Mask(255, 255, 255, 255)
	for i, v := range r.ipNet.Mask {
		m[i] ^= v
	}
	total, _ := strconv.ParseInt(m.String(), 16, 32) // 总可用 IP 数
	if total > 255 {                                 // 矫正 第四段 可用 IP 数
		hosts = 255
		return
	}
	hosts = byte(total)
	return
}

// chooseIPv4 选择 IPv4 地址（单个/随机/全部）
func (r *IPRanges) chooseIPv4() {
	if r.mask == "/32" { // 单个 IP 则无需随机，直接加入自身即可
		r.appendIP(r.firstIP)
	} else {
		minIP, hosts := r.getIPRange()    // 返回第四段 IP 的最小值及可用数目
		for r.ipNet.Contains(r.firstIP) { // 只要该 IP 没有超出 IP 网段范围，就继续循环随机
			if TestAll { // 如果是测速全部 IP
				for i := 0; i <= int(hosts); i++ { // 遍历 IP 最后一段最小值到最大值
					r.appendIPv4(byte(i) + minIP)
				}
			} else { // 随机 IP 的最后一段 0.0.0.X
				r.appendIPv4(minIP + randIPEndWith(hosts))
			}
			r.firstIP[14]++ // 0.0.(X+1).X
			if r.firstIP[14] == 0 {
				r.firstIP[13]++ // 0.(X+1).X.X
				if r.firstIP[13] == 0 {
					r.firstIP[12]++ // (X+1).X.X.X
				}
			}
		}
	}
}

// chooseIPv6 选择 IPv6 地址（单个/随机）
func (r *IPRanges) chooseIPv6() {
	if r.mask == "/128" { // 单个 IP 则无需随机，直接加入自身即可
		r.appendIP(r.firstIP)
	} else {
		var tempIP uint8                  // 临时变量，用于记录前一位的值
		for r.ipNet.Contains(r.firstIP) { // 只要该 IP 没有超出 IP 网段范围，就继续循环随机
			r.firstIP[15] = randIPEndWith(255) // 随机 IP 的最后一段
			r.firstIP[14] = randIPEndWith(255) // 随机 IP 的倒数第二段

			targetIP := make([]byte, len(r.firstIP))
			copy(targetIP, r.firstIP)
			r.appendIP(targetIP) // 加入 IP 地址池

			for i := 13; i >= 0; i-- { // 从倒数第三位开始往前随机
				tempIP = r.firstIP[i]              // 保存前一位的值
				r.firstIP[i] += randIPEndWith(255) // 随机 0~255，加到当前位上
				if r.firstIP[i] >= tempIP {        // 如果当前位的值大于等于前一位的值，说明随机成功了，可以退出该循环
					break
				}
			}
		}
	}
}

func loadIPRanges() []IPEntry {
	ranges := newIPRanges()
	entries := make([]IPEntry, 0)

	processLine := func(line string) {
		ipPart, port, tag := parseIPLine(line)
		ranges.ips = ranges.ips[:0]
		ranges.parseCIDR(ipPart)
		if isIPv4(ipPart) {
			ranges.chooseIPv4()
		} else {
			ranges.chooseIPv6()
		}
		for _, ip := range ranges.ips {
			entries = append(entries, IPEntry{IP: ip, Port: port, Tag: tag})
		}
	}

	if IPText != "" {
		IPs := strings.Split(IPText, ",")
		for _, IP := range IPs {
			IP = strings.TrimSpace(IP)
			if IP == "" {
				continue
			}
			processLine(IP)
		}
	} else {
		if IPFile == "" {
			IPFile = defaultInputFile
		}
		lines := LoadIPFile(IPFile)
		for _, line := range lines {
			processLine(line)
		}
	}
	return entries
}
