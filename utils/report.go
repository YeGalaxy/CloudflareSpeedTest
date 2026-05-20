package utils

import (
	"bytes"
	"encoding/base64"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	maxRetries    = 3
	retryDelay    = 2 * time.Second
	httpTimeout   = 30 * time.Second
	workerAPIPath = "/api/preferred-ips"
)

type Config struct {
	WorkerDomain string `json:"worker_domain"`
	UUID         string `json:"uuid"`
	GitHubToken  string `json:"github_token"`
	GitHubOwner  string `json:"github_owner"`
	GitHubRepo   string `json:"github_repo"`
	GitHubBranch string `json:"github_branch"`
	GitHubPath   string `json:"github_path"`
}

type PreferredIP struct {
	IP   string `json:"ip"`
	Port int    `json:"port"`
	Name string `json:"name"`
}

type GitHubContentResponse struct {
	SHA string `json:"sha"`
}

func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func SaveConfig(path string, cfg *Config) error {
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

func ReadResultCSV(filePath string) ([]CloudflareIPResult, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("打开结果文件失败: %w", err)
	}
	defer f.Close()

	reader := csv.NewReader(f)
	if _, err := reader.Read(); err != nil {
		return nil, fmt.Errorf("读取CSV头部失败: %w", err)
	}

	var results []CloudflareIPResult
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}
		if len(record) < 8 {
			continue
		}

		delay, _ := strconv.ParseFloat(record[5], 64)
		speed, _ := strconv.ParseFloat(record[6], 64)

		var coloName string
		if len(record) >= 9 {
			coloName = strings.TrimSpace(record[8])
		} else {
			coloName = GetAirportCodeName(strings.TrimSpace(record[7]))
		}

		var countryCode string
		if len(record) >= 10 {
			countryCode = strings.TrimSpace(record[9])
		} else {
			countryCode = GetAirportCountryCode(strings.TrimSpace(record[7]))
		}

		var countryName string
		if len(record) >= 11 {
			countryName = strings.TrimSpace(record[10])
		} else {
			countryName = GetAirportCountryName(strings.TrimSpace(record[7]))
		}

		results = append(results, CloudflareIPResult{
			IP:          strings.TrimSpace(record[0]),
			Sended:      record[2],
			Received:    record[3],
			LossRate:    record[4],
			Delay:       delay,
			Speed:       speed,
			Colo:        strings.TrimSpace(record[7]),
			ColoName:    coloName,
			CountryCode: countryCode,
			CountryName: countryName,
		})
	}
	return results, nil
}

type CloudflareIPResult struct {
	IP          string
	Sended      string
	Received    string
	LossRate    string
	Delay       float64
	Speed       float64
	Colo        string
	ColoName    string
	CountryCode string
	CountryName string
}

func FormatPreferredIPs(results []CloudflareIPResult, port int) []PreferredIP {
	ips := make([]PreferredIP, 0, len(results))
	for _, r := range results {
		name := fmt.Sprintf("%s-%s-%.2fMB/s", r.CountryCode, r.ColoName, r.Speed)
		if r.ColoName == "" || r.ColoName == "N/A" {
			name = fmt.Sprintf("%.2fMB/s", r.Speed)
		}
		if (r.CountryCode == "" || r.CountryCode == "N/A") && r.ColoName != "" && r.ColoName != "N/A" {
			name = fmt.Sprintf("%s-%.2fMB/s", r.ColoName, r.Speed)
		}
		ips = append(ips, PreferredIP{
			IP:   r.IP,
			Port: port,
			Name: name,
		})
	}
	return ips
}

func FormatGitHubContent(results []CloudflareIPResult, port int) string {
	var lines []string
	for _, r := range results {
		region := r.ColoName
		if region == "" || region == "N/A" {
			region = "UNKNOWN"
		}
		countryCode := r.CountryCode
		if countryCode == "" || countryCode == "N/A" {
			countryCode = "XX"
		}
		line := fmt.Sprintf("%s:%d#%s-%s-%.2fMB/s", r.IP, port, countryCode, region, r.Speed)
		lines = append(lines, line)
	}
	return strings.Join(lines, "\n")
}

func doRequestWithRetry(method, url string, body io.Reader, headers map[string]string) (*http.Response, error) {
	var lastErr error
	for i := 0; i < maxRetries; i++ {
		if i > 0 {
			time.Sleep(retryDelay)
			Yellow.Printf("[上报] 第 %d 次重试...\n", i)
		}

		req, err := http.NewRequest(method, url, body)
		if err != nil {
			lastErr = err
			continue
		}

		for k, v := range headers {
			req.Header.Set(k, v)
		}

		client := &http.Client{Timeout: httpTimeout}
		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			continue
		}

		if resp.StatusCode >= 500 {
			resp.Body.Close()
			lastErr = fmt.Errorf("服务器错误: HTTP %d", resp.StatusCode)
			continue
		}

		return resp, nil
	}
	return nil, fmt.Errorf("达到最大重试次数(%d)，最后一次错误: %w", maxRetries, lastErr)
}

func UploadToCloudflareAPI(cfg *Config, results []CloudflareIPResult, port int) error {
	var apiURL string
	if strings.HasPrefix(cfg.WorkerDomain, "http://") || strings.HasPrefix(cfg.WorkerDomain, "https://") {
		apiURL = fmt.Sprintf("%s/%s%s", cfg.WorkerDomain, cfg.UUID, workerAPIPath)
	} else {
		apiURL = fmt.Sprintf("https://%s/%s%s", cfg.WorkerDomain, cfg.UUID, workerAPIPath)
	}

	Cyan.Printf("[上报] 正在上传到 Cloudflare Workers API...\n")
	Cyan.Printf("[上报] API 地址: %s\n", apiURL)

	headers := map[string]string{
		"Content-Type": "application/json",
	}

	resp, err := doRequestWithRetry("GET", apiURL, nil, headers)
	if err != nil {
		return fmt.Errorf("检查现有IP失败: %w", err)
	}
	resp.Body.Close()

	clearBody := bytes.NewBufferString(`{"all": true}`)
	resp, err = doRequestWithRetry("DELETE", apiURL, clearBody, headers)
	if err != nil {
		Yellow.Printf("[上报] 清除现有数据失败: %v，继续上传...\n", err)
	} else {
		resp.Body.Close()
	}

	preferredIPs := FormatPreferredIPs(results, port)
	jsonData, err := json.Marshal(preferredIPs)
	if err != nil {
		return fmt.Errorf("序列化数据失败: %w", err)
	}

	resp, err = doRequestWithRetry("POST", apiURL, bytes.NewBuffer(jsonData), headers)
	if err != nil {
		return fmt.Errorf("上传数据失败: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("上传失败: HTTP %d, 响应: %s", resp.StatusCode, string(body))
	}

	Green.Printf("[上报] 成功上传 %d 条优选IP到 Cloudflare Workers API\n", len(preferredIPs))
	return nil
}

func UploadToGitHub(cfg *Config, results []CloudflareIPResult, port int) error {
	apiURL := fmt.Sprintf("https://api.github.com/repos/%s/%s/contents/%s",
		cfg.GitHubOwner, cfg.GitHubRepo, cfg.GitHubPath)

	Cyan.Printf("[上报] 正在上传到 GitHub 仓库...\n")
	Cyan.Printf("[上报] 目标: %s/%s (%s)\n", cfg.GitHubOwner, cfg.GitHubRepo, cfg.GitHubPath)

	content := FormatGitHubContent(results, port)
	headers := map[string]string{
		"Authorization": fmt.Sprintf("token %s", cfg.GitHubToken),
		"Content-Type":  "application/json",
		"Accept":        "application/vnd.github.v3+json",
	}

	resp, err := doRequestWithRetry("GET", apiURL, nil, headers)
	if err != nil {
		Yellow.Printf("[上报] 检查文件是否存在失败: %v，尝试直接创建\n", err)
	} else {
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		var contentResp GitHubContentResponse
		if json.Unmarshal(body, &contentResp) == nil && contentResp.SHA != "" {
			encodedContent := base64Encode(content)
			payload := map[string]interface{}{
				"message": "Update Cloudflare preferred IPs",
				"content": encodedContent,
				"sha":     contentResp.SHA,
				"branch":  cfg.GitHubBranch,
			}
			jsonPayload, _ := json.Marshal(payload)
			resp, err = doRequestWithRetry("PUT", apiURL, bytes.NewBuffer(jsonPayload), headers)
			if err != nil {
				return fmt.Errorf("更新GitHub文件失败: %w", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
				body, _ := io.ReadAll(resp.Body)
				return fmt.Errorf("更新GitHub文件失败: HTTP %d, 响应: %s", resp.StatusCode, string(body))
			}

			rawURL := fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s/%s",
				cfg.GitHubOwner, cfg.GitHubRepo, cfg.GitHubBranch, cfg.GitHubPath)
			Green.Printf("[上报] 成功更新 GitHub 文件！\n")
			Green.Printf("[上报] 文件地址: %s\n", rawURL)
			return nil
		}
	}

	encodedContent := base64Encode(content)
	payload := map[string]interface{}{
		"message": "Add Cloudflare preferred IPs",
		"content": encodedContent,
		"branch":  cfg.GitHubBranch,
	}
	jsonPayload, _ := json.Marshal(payload)

	resp, err = doRequestWithRetry("PUT", apiURL, bytes.NewBuffer(jsonPayload), headers)
	if err != nil {
		return fmt.Errorf("创建GitHub文件失败: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("创建GitHub文件失败: HTTP %d, 响应: %s", resp.StatusCode, string(body))
	}

	rawURL := fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s/%s",
		cfg.GitHubOwner, cfg.GitHubRepo, cfg.GitHubBranch, cfg.GitHubPath)
	Green.Printf("[上报] 成功创建 GitHub 文件！\n")
	Green.Printf("[上报] 文件地址: %s\n", rawURL)
	return nil
}

func base64Encode(s string) string {
	return base64.StdEncoding.EncodeToString([]byte(s))
}

func ReportResults(resultFile string, cfg *Config, reportTarget string, port int) error {
	results, err := ReadResultCSV(resultFile)
	if err != nil {
		return fmt.Errorf("读取测速结果失败: %w", err)
	}

	if len(results) == 0 {
		return fmt.Errorf("测速结果为空，跳过上报")
	}

	switch reportTarget {
	case "cloudflare":
		if cfg.WorkerDomain == "" || cfg.UUID == "" {
			return fmt.Errorf("Cloudflare Workers API 配置不完整，需要 worker_domain 和 uuid")
		}
		return UploadToCloudflareAPI(cfg, results, port)
	case "github":
		if cfg.GitHubToken == "" || cfg.GitHubOwner == "" || cfg.GitHubRepo == "" {
			return fmt.Errorf("GitHub 配置不完整，需要 token、owner 和 repo")
		}
		if cfg.GitHubBranch == "" {
			cfg.GitHubBranch = "main"
		}
		if cfg.GitHubPath == "" {
			cfg.GitHubPath = "preferred_ips.txt"
		}
		return UploadToGitHub(cfg, results, port)
	default:
		return fmt.Errorf("不支持的上报目标: %s", reportTarget)
	}
}
