package discover

import (
	"encoding/xml"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type MySQLCreds struct {
	Host     string
	Port     string
	User     string
	Password string
	Database string
	Source   string
}

var searchRoots = []string{
	`C:\Program Files (x86)\VoipSwitch`,
	`C:\Program Files\VoipSwitch`,
	`C:\VoipSwitch`,
	`C:\Program Files (x86)\VoipBox 3.0`,
	`C:\Program Files\VoipBox 3.0`,
}

var preferNames = []string{
	"voipswitch_config.xml",
	"Database.config",
	"DatabaseIF.config",
	"voipbox_config.xml",
	"voipswitchconfig.xml",
}

func FindMySQL() (*MySQLCreds, error) {
	var files []string
	for _, root := range searchRoots {
		_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil || info == nil || info.IsDir() {
				return nil
			}
			base := strings.ToLower(info.Name())
			for _, n := range preferNames {
				if base == strings.ToLower(n) {
					files = append(files, path)
					break
				}
			}
			return nil
		})
	}
	for _, f := range files {
		if c := parseFile(f); c != nil && c.Database != "" {
			return c, nil
		}
	}
	for _, f := range files {
		if c := parseFile(f); c != nil && c.User != "" {
			if c.Database == "" {
				c.Database = "voipswitch"
			}
			return c, nil
		}
	}
	return nil, os.ErrNotExist
}

func parseFile(path string) *MySQLCreds {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	s := string(b)
	low := strings.ToLower(path)
	if strings.Contains(low, "voipswitch_config.xml") || strings.Contains(low, "voipbox_config.xml") {
		if c := parseVPSXML(s, path); c != nil {
			return c
		}
	}
	if strings.Contains(low, "database") {
		if c := parseDatabaseConfig(s, path); c != nil {
			return c
		}
	}
	return parseGeneric(s, path)
}

type param struct {
	Name  string `xml:"name,attr"`
	Key   string `xml:"key,attr"`
	Value string `xml:"value,attr"`
}

func parseVPSXML(s, path string) *MySQLCreds {
	type db struct {
		Params []param `xml:"param"`
	}
	type root struct {
		Database db `xml:"database"`
	}
	var r root
	if err := xml.Unmarshal([]byte(s), &r); err != nil {
		return parseGeneric(s, path)
	}
	c := &MySQLCreds{Host: "127.0.0.1", Port: "3306", Source: path}
	for _, p := range r.Database.Params {
		switch strings.ToLower(p.Name) {
		case "ipaddr", "host":
			c.Host = p.Value
		case "port":
			c.Port = p.Value
		case "username", "user":
			c.User = p.Value
		case "password":
			c.Password = p.Value
		case "dbname", "database":
			c.Database = p.Value
		}
	}
	if c.User == "" && c.Database == "" {
		return nil
	}
	return c
}

func parseDatabaseConfig(s, path string) *MySQLCreds {
	type cfg struct {
		Params []param `xml:"config>param"`
	}
	var r cfg
	if err := xml.Unmarshal([]byte(s), &r); err != nil {
		return parseGeneric(s, path)
	}
	c := &MySQLCreds{Host: "127.0.0.1", Port: "3306", Source: path}
	for _, p := range r.Params {
		switch strings.ToLower(p.Key) {
		case "connhost":
			c.Host = p.Value
		case "connport":
			c.Port = p.Value
		case "connuser":
			c.User = p.Value
		case "connpassword":
			c.Password = p.Value
		case "conndbname":
			c.Database = p.Value
		}
	}
	if c.User == "" && c.Database == "" {
		return nil
	}
	return c
}

func parseGeneric(s, path string) *MySQLCreds {
	c := &MySQLCreds{Host: "127.0.0.1", Port: "3306", Source: path}
	re := regexp.MustCompile(`(?i)(ipaddr|host|port|username|user|password|dbname|database|connhost|connport|connuser|connpassword|conndbname)["'\s:=]+([^<"'\s]+)`)
	for _, m := range re.FindAllStringSubmatch(s, -1) {
		k := strings.ToLower(m[1])
		v := m[2]
		switch k {
		case "ipaddr", "host", "connhost":
			c.Host = v
		case "port", "connport":
			c.Port = v
		case "username", "user", "connuser":
			c.User = v
		case "password", "connpassword":
			c.Password = v
		case "dbname", "database", "conndbname":
			c.Database = v
		}
	}
	if c.User == "" && c.Database == "" {
		return nil
	}
	return c
}
