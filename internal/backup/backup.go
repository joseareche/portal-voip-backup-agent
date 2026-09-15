package backup

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/joseareche/portal-voip-backup-agent/internal/discover"
)

func FindMysqldump() string {
	cands := []string{
		`C:\MySQL\bin\mysqldump.exe`,
		`C:\Program Files\MySQL\MySQL Server 5.0\bin\mysqldump.exe`,
		`C:\Program Files (x86)\MySQL\MySQL Server 5.0\bin\mysqldump.exe`,
	}
	for _, c := range cands {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	if p, err := exec.LookPath("mysqldump"); err == nil {
		return p
	}
	return ""
}

func Run(outDir string) (string, error) {
	creds, err := discover.FindMySQL()
	if err != nil {
		return "", fmt.Errorf("no MySQL config found under VoipSwitch: %w", err)
	}
	dump := FindMysqldump()
	if dump == "" {
		return "", fmt.Errorf("mysqldump.exe not found")
	}
	if err := os.MkdirAll(outDir, 0755); err != nil {
		return "", err
	}
	stamp := time.Now().Format("20060102-150405")
	sql := filepath.Join(outDir, fmt.Sprintf("%s_%s.sql", creds.Database, stamp))
	zipPath := filepath.Join(outDir, fmt.Sprintf("%s_%s.zip", creds.Database, stamp))

	args := []string{
		"--host=" + creds.Host,
		"--port=" + creds.Port,
		"--user=" + creds.User,
		"--single-transaction",
		"--quick",
		"--routines",
		"--hex-blob",
		"--result-file=" + sql,
		creds.Database,
	}
	if creds.Password != "" {
		args = append([]string{"--password=" + creds.Password}, args...)
	}
	cmd := exec.Command(dump, args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("mysqldump: %v: %s", err, string(out))
	}
	fi, err := os.Stat(sql)
	if err != nil || fi.Size() < 100 {
		return "", fmt.Errorf("sql dump missing or too small")
	}
	if err := zipFile(sql, zipPath); err != nil {
		return "", err
	}
	_ = os.Remove(sql)
	return zipPath, nil
}

func zipFile(src, dest string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()
	zw := zip.NewWriter(out)
	w, err := zw.Create(filepath.Base(src))
	if err != nil {
		_ = zw.Close()
		return err
	}
	if _, err := io.Copy(w, in); err != nil {
		_ = zw.Close()
		return err
	}
	return zw.Close()
}

