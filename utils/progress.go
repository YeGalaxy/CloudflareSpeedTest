package utils

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/cheggaaa/pb/v3"
	isatty "github.com/mattn/go-isatty"
)

type Bar struct {
	pb *pb.ProgressBar
}

func NewBar(count int, MyStrStart, MyStrEnd string) *Bar {
	isTerminal := isatty.IsTerminal(os.Stdout.Fd()) || isatty.IsCygwinTerminal(os.Stdout.Fd())

	var tmpl string
	if isTerminal {
		tmpl = fmt.Sprintf(`{{counters . }} {{ bar . "[" "-" (cycle . "↖" "↗" "↘" "↙" ) "_" "]"}} %s {{string . "MyStr" | green}} %s `, MyStrStart, MyStrEnd)
	} else {
		tmpl = fmt.Sprintf(`{{counters . }} {{ bar . "[" "█" "▓" "░" "]"}} %s {{string . "MyStr"}} %s `, MyStrStart, MyStrEnd)
	}

	bar := pb.ProgressBarTemplate(tmpl).Start(count)

	if !isTerminal {
		bar.SetRefreshRate(2 * time.Second)
		bar.SetWidth(80)
	} else if cols := os.Getenv("COLUMNS"); cols != "" {
		if n, err := strconv.Atoi(cols); err == nil && n > 0 {
			bar.SetWidth(n)
		}
	}

	return &Bar{pb: bar}
}

func (b *Bar) Grow(num int, MyStrVal string) {
	b.pb.Set("MyStr", MyStrVal).Add(num)
}

func (b *Bar) Done() {
	b.pb.Finish()
}
