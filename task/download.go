package task

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/XIU2/CloudflareSpeedTest/utils"

	"github.com/VividCortex/ewma"
)

const (
	bufferSize                     = 1024
	defaultURL                     = "https://cf.xiu2.xyz/url"
	defaultTimeout                 = 10 * time.Second
	defaultDisableDownload         = false
	defaultTestNum                 = 10
	defaultMinSpeed        float64 = 0.0
)

var (
	URL     = defaultURL
	Timeout = defaultTimeout
	Disable = defaultDisableDownload

	TestCount = defaultTestNum
	MinSpeed  = defaultMinSpeed
)

func checkDownloadDefault() {
	if URL == "" {
		URL = defaultURL
	}
	if Timeout <= 0 {
		Timeout = defaultTimeout
	}
	if TestCount <= 0 {
		TestCount = defaultTestNum
	}
	if MinSpeed <= 0.0 {
		MinSpeed = defaultMinSpeed
	}
}

func TestDownloadSpeed(ipSet utils.PingDelaySet) (speedSet utils.DownloadSpeedSet) {
	checkDownloadDefault()
	if Disable {
		return utils.DownloadSpeedSet(ipSet)
	}
	if len(ipSet) <= 0 {
		utils.Yellow.Println("[信息] 延迟测速结果 IP 数量为 0，跳过下载测速。")
		return
	}

	var filteredSet utils.PingDelaySet

	if HttpingCFColomap != nil && HttpingCFColo != "" {
		colos := strings.Split(strings.ToUpper(HttpingCFColo), ",")
		regionMap := make(map[string][]utils.CloudflareIPData)
		for _, ip := range ipSet {
			if ip.Colo != "" {
				regionMap[ip.Colo] = append(regionMap[ip.Colo], ip)
			}
		}

		for _, colo := range colos {
			if ips, ok := regionMap[colo]; ok {
				sort.Slice(ips, func(i, j int) bool {
					return ips[i].Delay < ips[j].Delay
				})

				var qualifiedIPs utils.PingDelaySet
				for _, ip := range ips {
					if ip.Delay >= utils.InputMinDelay && ip.Delay <= utils.InputMaxDelay && ip.GetLossRate() <= utils.InputMaxLossRate {
						qualifiedIPs = append(qualifiedIPs, ip)
						if len(qualifiedIPs) >= TestCount {
							break
						}
					}
				}

				if len(qualifiedIPs) > 0 {
					filteredSet = append(filteredSet, qualifiedIPs...)
				}
			}
		}

		if len(filteredSet) == 0 {
			utils.Yellow.Println("[信息] 未找到指定地区的可用 IP，跳过下载测速。")
			return
		}

		utils.Cyan.Printf("按地区提取数据完成（地区数：%d, 总 IP 数：%d）\n", len(colos), len(filteredSet))
	} else {
		filteredSet = ipSet
	}

	var targetCount int
	if HttpingCFColomap != nil && HttpingCFColo != "" {
		targetCount = len(filteredSet)
	} else {
		targetCount = TestCount
	}

	testNum := len(filteredSet)
	if HttpingCFColomap == nil || HttpingCFColo == "" {
		if MinSpeed == 0 && len(filteredSet) >= TestCount {
			testNum = TestCount
		}
		if testNum < TestCount {
			TestCount = testNum
		}
	}

	utils.Cyan.Printf("开始下载测速（下限：%.2f MB/s, 数量：%d, 队列：%d）\n", MinSpeed, TestCount, testNum)
	bar_a := len(strconv.Itoa(len(filteredSet)))
	bar_b := "     "
	for i := 0; i < bar_a; i++ {
		bar_b += " "
	}
	bar := utils.NewBar(targetCount, bar_b, "")
	for i := 0; i < testNum; i++ {
		entry := IPEntry{IP: filteredSet[i].IP, Port: filteredSet[i].Port, Tag: filteredSet[i].Tag}
		speed, colo := downloadHandler(entry)
		filteredSet[i].DownloadSpeed = speed
		if filteredSet[i].Colo == "" {
			filteredSet[i].Colo = colo
		}
		if speed >= MinSpeed*1024*1024 {
			bar.Grow(1, "")
			speedSet = append(speedSet, filteredSet[i])
			if len(speedSet) == targetCount {
				break
			}
		}
	}
	bar.Done()
	if MinSpeed == 0.00 {
		speedSet = utils.DownloadSpeedSet(filteredSet)
	} else if utils.Debug && len(speedSet) == 0 {
		utils.Yellow.Println("[调试] 没有满足 下载速度下限 条件的 IP，忽略条件返回所有测速数据（方便下次测速时调整条件）。")
		speedSet = utils.DownloadSpeedSet(filteredSet)
	}
	sort.Sort(speedSet)
	return
}

func getDialContext(entry IPEntry) func(ctx context.Context, network, address string) (net.Conn, error) {
	var fakeSourceAddr string
	port := entry.GetPort()
	if isIPv4(entry.IP.String()) {
		fakeSourceAddr = fmt.Sprintf("%s:%d", entry.IP.String(), port)
	} else {
		fakeSourceAddr = fmt.Sprintf("[%s]:%d", entry.IP.String(), port)
	}
	return func(ctx context.Context, network, address string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, network, fakeSourceAddr)
	}
}

func printDownloadDebugInfo(entry IPEntry, err error, statusCode int, url, lastRedirectURL string, response *http.Response) {
	finalURL := url
	if lastRedirectURL != "" {
		finalURL = lastRedirectURL
	} else if response != nil && response.Request != nil && response.Request.URL != nil {
		finalURL = response.Request.URL.String()
	}
	if url != finalURL {
		if statusCode > 0 {
			utils.Red.Printf("[调试] IP: %s, 下载测速终止，HTTP 状态码: %d, 下载测速地址: %s, 出错的重定向后地址: %s\n", entry.IP.String(), statusCode, url, finalURL)
		} else {
			utils.Red.Printf("[调试] IP: %s, 下载测速失败，错误信息: %v, 下载测速地址: %s, 出错的重定向后地址: %s\n", entry.IP.String(), err, url, finalURL)
		}
	} else {
		if statusCode > 0 {
			utils.Red.Printf("[调试] IP: %s, 下载测速终止，HTTP 状态码: %d, 下载测速地址: %s\n", entry.IP.String(), statusCode, url)
		} else {
			utils.Red.Printf("[调试] IP: %s, 下载测速失败，错误信息: %v, 下载测速地址: %s\n", entry.IP.String(), err, url)
		}
	}
}

func downloadHandler(entry IPEntry) (float64, string) {
	var lastRedirectURL string
	client := &http.Client{
		Transport: &http.Transport{DialContext: getDialContext(entry)},
		Timeout:   Timeout,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			lastRedirectURL = req.URL.String()
			if len(via) > 10 {
				if utils.Debug {
					utils.Red.Printf("[调试] IP: %s, 下载测速地址重定向次数过多，终止测速，下载测速地址: %s\n", entry.IP.String(), req.URL.String())
				}
				return http.ErrUseLastResponse
			}
			if req.Header.Get("Referer") == defaultURL {
				req.Header.Del("Referer")
			}
			return nil
		},
	}
	defer client.CloseIdleConnections()
	req, err := http.NewRequest("GET", URL, nil)
	if err != nil {
		if utils.Debug {
			utils.Red.Printf("[调试] IP: %s, 下载测速请求创建失败，错误信息: %v, 下载测速地址: %s\n", entry.IP.String(), err, URL)
		}
		return 0.0, ""
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.80 Safari/537.36")

	response, err := client.Do(req)
	if err != nil {
		if utils.Debug {
			printDownloadDebugInfo(entry, err, 0, URL, lastRedirectURL, response)
		}
		return 0.0, ""
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		if utils.Debug {
			printDownloadDebugInfo(entry, nil, response.StatusCode, URL, lastRedirectURL, response)
		}
		return 0.0, ""
	}

	colo := getHeaderColo(response.Header)

	timeStart := time.Now()
	timeEnd := timeStart.Add(Timeout)

	contentLength := response.ContentLength
	buffer := make([]byte, bufferSize)

	var (
		contentRead     int64 = 0
		timeSlice             = Timeout / 100
		timeCounter           = 1
		lastContentRead int64 = 0
	)

	var nextTime = timeStart.Add(timeSlice * time.Duration(timeCounter))
	e := ewma.NewMovingAverage()

	for contentLength != contentRead {
		currentTime := time.Now()
		if currentTime.After(nextTime) {
			timeCounter++
			nextTime = timeStart.Add(timeSlice * time.Duration(timeCounter))
			e.Add(float64(contentRead - lastContentRead))
			lastContentRead = contentRead
		}
		if currentTime.After(timeEnd) {
			break
		}
		bufferRead, err := response.Body.Read(buffer)
		if err != nil {
			if err != io.EOF {
				break
			} else if contentLength == -1 {
				break
			}
			last_time_slice := timeStart.Add(timeSlice * time.Duration(timeCounter-1))
			e.Add(float64(contentRead-lastContentRead) / (float64(currentTime.Sub(last_time_slice)) / float64(timeSlice)))
		}
		contentRead += int64(bufferRead)
	}
	return e.Value() / (Timeout.Seconds() / 120), colo
}
