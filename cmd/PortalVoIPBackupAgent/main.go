package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/joseareche/portal-voip-backup-agent/internal/backup"
	"github.com/joseareche/portal-voip-backup-agent/internal/discover"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	switch strings.ToLower(os.Args[1]) {
	case "diagnose", "discover":
		c, err := discover.FindMySQL()
		if err != nil {
			fmt.Println("FAIL:", err)
			os.Exit(1)
		}
		fmt.Printf("OK source=%s\n", c.Source)
		fmt.Printf("host=%s port=%s user=%s db=%s pass_len=%d\n", c.Host, c.Port, c.User, c.Database, len(c.Password))
		fmt.Printf("mysqldump=%s\n", backup.FindMysqldump())
	case "backup":
		out := `C:\ProgramData\VoipSwitchBackup\out`
		if len(os.Args) > 2 {
			out = os.Args[2]
		}
		// also mirror to shared folder if present
		path, err := backup.Run(out)
		if err != nil {
			fmt.Println("FAIL:", err)
			os.Exit(1)
		}
		share := `Y:\voipswitch-backups`
		_ = os.MkdirAll(share, 0755)
		dest := filepath.Join(share, filepath.Base(path))
		_ = copyFile(path, dest)
		fmt.Println("OK", path)
		if _, err := os.Stat(dest); err == nil {
			fmt.Println("SHARE", dest)
		}
	case "install":
		exe, _ := os.Executable()
		tr := fmt.Sprintf(`"%s" backup`, exe)
		cmd := exec.Command("schtasks.exe",
			"/Create",
			"/TN", "VoipSwitchMySQLBackup",
			"/TR", tr,
			"/SC", "DAILY",
			"/ST", "01:00",
			"/RU", "SYSTEM",
			"/RL", "HIGHEST",
			"/F",
		)
		out, err := cmd.CombinedOutput()
		fmt.Print(string(out))
		if err != nil {
			os.Exit(1)
		}
	case "uninstall":
		cmd := exec.Command("schtasks.exe", "/Delete", "/TN", "VoipSwitchMySQLBackup", "/F")
		out, err := cmd.CombinedOutput()
		fmt.Print(string(out))
		if err != nil {
			os.Exit(1)
		}
	case "help", "-h", "--help":
		usage()
	default:
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Println(`PortalVoIPBackupAgent
  diagnose   busca configs VoIPSwitch y muestra MySQL (sin imprimir clave)
  backup     dump zip de la DB descubierta
  install    Task Scheduler diario 01:00
  uninstall  quita la tarea`)
}

func copyFile(src, dst string) error {
	in, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, in, 0644)
}

