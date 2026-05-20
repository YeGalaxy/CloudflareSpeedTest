package task

import (
	"bufio"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/XIU2/CloudflareSpeedTest/utils"
)

const remoteFileTimeout = 30 * time.Second

func isURL(path string) bool {
	return strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://")
}

func fetchRemoteFile(url string) (string, error) {
	utils.Cyan.Printf("[信息] 正在从远程下载文件: %s\n", url)
	client := http.Client{Timeout: remoteFileTimeout}
	res, err := client.Get(url)
	if err != nil {
		return "", fmt.Errorf("下载远程文件失败: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return "", fmt.Errorf("下载远程文件失败: HTTP 状态码 %d", res.StatusCode)
	}
	body, err := io.ReadAll(res.Body)
	if err != nil {
		return "", fmt.Errorf("读取远程文件内容失败: %w", err)
	}
	utils.Green.Printf("[信息] 远程文件下载成功，大小: %d 字节\n", len(body))
	return string(body), nil
}

func readLocalFile(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		if !isURL(path) && !strings.HasPrefix(path, "/") {
			dataPath := "data/" + path
			if dataFile, dataErr := os.Open(dataPath); dataErr == nil {
				defer dataFile.Close()
				utils.Cyan.Printf("[信息] 文件 %s 不存在，已自动使用 %s\n", path, dataPath)
				content, readErr := io.ReadAll(dataFile)
				if readErr != nil {
					return "", readErr
				}
				return string(content), nil
			}
		}
		return "", err
	}
	defer file.Close()
	content, err := io.ReadAll(file)
	if err != nil {
		return "", err
	}
	return string(content), nil
}

func detectFileType(path string, content string) string {
	lowerPath := strings.ToLower(path)
	if idx := strings.Index(lowerPath, "?"); idx >= 0 {
		lowerPath = lowerPath[:idx]
	}
	if strings.HasSuffix(lowerPath, ".json") {
		return "json"
	}
	if strings.HasSuffix(lowerPath, ".csv") {
		return "csv"
	}
	if strings.HasSuffix(lowerPath, ".txt") {
		return "txt"
	}
	trimmed := strings.TrimSpace(content)
	if strings.HasPrefix(trimmed, "[") {
		return "json"
	}
	firstLine := trimmed
	if idx := strings.Index(trimmed, "\n"); idx >= 0 {
		firstLine = trimmed[:idx]
	}
	if strings.Contains(firstLine, ",") && strings.Contains(strings.ToLower(firstLine), "ip") {
		return "csv"
	}
	return "txt"
}

func stripBOM(content string) string {
	return strings.TrimPrefix(content, "\ufeff")
}

func parseTXT(content string) []string {
	var lines []string
	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		lines = append(lines, line)
	}
	return lines
}

func parseCSV(content string) []string {
	content = stripBOM(content)
	reader := csv.NewReader(strings.NewReader(content))
	records, err := reader.ReadAll()
	if err != nil {
		log.Fatalf("解析 CSV 文件失败: %v", err)
	}
	if len(records) == 0 {
		return nil
	}

	ipCol, portCol, tagCol := 0, -1, -1
	isHeader := false

	for i, val := range records[0] {
		lower := strings.ToLower(strings.TrimSpace(val))
		switch lower {
		case "ip 地址", "ip地址", "ip":
			ipCol = i
			isHeader = true
		case "端口", "port":
			portCol = i
			isHeader = true
		case "标签", "tag":
			tagCol = i
			isHeader = true
		}
	}

	startRow := 0
	if isHeader {
		startRow = 1
	} else {
		if len(records[0]) > 1 {
			portCol = 1
		}
		if len(records[0]) > 2 {
			tagCol = 2
		}
	}

	var lines []string
	for i := startRow; i < len(records); i++ {
		row := records[i]
		if ipCol >= len(row) {
			continue
		}
		ip := strings.TrimSpace(row[ipCol])
		if ip == "" {
			continue
		}
		line := ip
		if portCol != -1 && portCol < len(row) {
			port := strings.TrimSpace(row[portCol])
			if port != "" && port != "0" {
				line += ":" + port
			}
		}
		if tagCol != -1 && tagCol < len(row) {
			tag := strings.TrimSpace(row[tagCol])
			if tag != "" && tag != "N/A" {
				line += " #" + tag
			}
		}
		lines = append(lines, line)
	}
	return lines
}

func parseJSON(content string) []string {
	content = strings.TrimSpace(content)

	var strArr []string
	if err := json.Unmarshal([]byte(content), &strArr); err == nil {
		var lines []string
		for _, s := range strArr {
			s = strings.TrimSpace(s)
			if s == "" {
				continue
			}
			lines = append(lines, s)
		}
		return lines
	}

	var objArr []map[string]interface{}
	if err := json.Unmarshal([]byte(content), &objArr); err == nil {
		var lines []string
		for _, obj := range objArr {
			ip := jsonStrField(obj, "ip", "IP")
			if ip == "" {
				continue
			}
			line := ip
			if port := jsonNumField(obj, "port", "Port"); port > 0 {
				line += fmt.Sprintf(":%d", port)
			}
			if tag := jsonStrField(obj, "tag", "Tag"); tag != "" {
				line += " #" + tag
			}
			lines = append(lines, line)
		}
		return lines
	}

	log.Fatal("解析 JSON 文件失败: 无法识别的 JSON 格式（支持字符串数组或对象数组）")
	return nil
}

func jsonStrField(obj map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := obj[k].(string); ok {
			return v
		}
	}
	return ""
}

func jsonNumField(obj map[string]interface{}, keys ...string) int {
	for _, k := range keys {
		if v, ok := obj[k].(float64); ok {
			return int(v)
		}
	}
	return 0
}

func LoadIPFile(path string) []string {
	var content string
	var err error
	if isURL(path) {
		content, err = fetchRemoteFile(path)
	} else {
		content, err = readLocalFile(path)
	}
	if err != nil {
		log.Fatal(err)
	}

	fileType := detectFileType(path, content)
	switch fileType {
	case "json":
		return parseJSON(content)
	case "csv":
		return parseCSV(content)
	default:
		return parseTXT(content)
	}
}
