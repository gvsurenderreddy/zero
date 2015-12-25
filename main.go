package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"time"
)

const LinePrefix = "zero: "

var ErrUserCancelled = fmt.Errorf("Cancelled")
var ErrMaxRetries = fmt.Errorf("Took too long")

func printUsage() {
	fmt.Fprintf(os.Stderr, "usage: zero [-name] [-iface] [-install-dir] zt_net zt_token\n")
}

func prefixLines(out io.Writer, prefix string) io.Writer {
	pr, pw, err := os.Pipe()
	if err != nil {
		log.Fatalf("%v", err)
	}

	go func() {
		defer pr.Close()
		scanner := bufio.NewScanner(pr)
		for scanner.Scan() {
			fmt.Fprintf(out, "%s%s\n", prefix, scanner.Text())
		}

		if err := scanner.Err(); err != nil {
			log.Fatalf("Error piping prefix: %v", err)
		}
	}()

	return pw
}

func WaitForDaemon(exit chan os.Signal, start bool, installDir string) error {
	if start {
		path := filepath.Join(installDir, "zerotier-one")
		log.Printf("Also starting '%s'...", path)
		cmd := exec.Command(path, "-d")
		cmd.Stdout = prefixLines(os.Stdout, fmt.Sprintf("%s%s", LinePrefix, "(zerotier-one) "))
		cmd.Stderr = prefixLines(os.Stdout, fmt.Sprintf("%s%s", LinePrefix, "(zerotier-one) "))
		err := cmd.Run()
		if err != nil {
			return err
		}
	}

	retries := 0
	for {
		if retries >= 10 {
			return ErrMaxRetries
		}

		fis, err := ioutil.ReadDir(installDir)
		if err != nil {
			if os.IsNotExist(err) {
				log.Fatalf("The ZeroTier installation directory '%s' doesn't exist, did you install it somewhere else?", installDir)
			} else {
				log.Fatalf("Failed to read zerotier-one installation dir '%s': %v", installDir, err)
			}

		}

		for _, fi := range fis {
			if fi.Name() == "authtoken.secret" {
				return nil //we're done waiting
			}
		}

		retries += 1
		select {
		case <-exit:
			return ErrUserCancelled
		case <-time.After(time.Millisecond * 200):
		}
	}

	return nil
}

func JoinNetwork(exit chan os.Signal, netid, installDir string) (string, error) {
	cmd := exec.Command("zerotier-cli", "join", netid)
	cmd.Stdout = prefixLines(os.Stdout, fmt.Sprintf("%s%s", LinePrefix, "(zerotier-cli) "))
	cmd.Stderr = prefixLines(os.Stdout, fmt.Sprintf("%s%s", LinePrefix, "(zerotier-cli) "))
	err := cmd.Run()
	if err != nil {
		return "", err
	}

	idpath := filepath.Join(installDir, "identity.public")
	retries := 0
	for {
		if retries >= 10 {
			return "", ErrMaxRetries
		}

		data, err := ioutil.ReadFile(idpath)
		if err != nil && os.IsExist(err) {
			log.Fatalf("Unexpected error reading file '%s': %v", idpath, err)
		} else if data != nil {
			memberid := string(data[:10])
			return memberid, nil //we're done
		}

		retries += 1
		select {
		case <-exit:
			return "", ErrUserCancelled
		case <-time.After(time.Millisecond * 200):
		}
	}

	return "", nil
}

func AuthorizeMember(memberid, membername, netid, endpoint, token string) error {
	loc := fmt.Sprintf("%snetwork/%s/member/%s", endpoint, netid, memberid)
	req, err := http.NewRequest("POST", loc, strings.NewReader(fmt.Sprintf(`{"config":{"authorized": true}, "annot": {"description": "%s"}}`, membername)))
	if err != nil {
		return fmt.Errorf("Failed to create request: %s", err)
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", token))
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}

	defer resp.Body.Close()
	if resp.StatusCode > 299 {
		return fmt.Errorf("Failed to update member details '%v': %s", req.Header, resp.Status)
	}

	return nil
}

func WaitForIP(exit chan os.Signal, installDir, netid, iface string) (net.IP, string, error) {
	if iface == "" {
		path := filepath.Join(installDir, "devicemap")
		f, err := os.Open(path)
		if err != nil {
			return nil, "", fmt.Errorf("Failed to open ZeroTier devicemap ('%s'): %v", path, err)
		}

		defer f.Close()
		s := bufio.NewScanner(f)
		for s.Scan() {
			if strings.HasPrefix(s.Text(), netid) {
				iface = strings.SplitAfter(s.Text(), "=")[1]
			}

		}

		if err := s.Err(); err != nil {
			return nil, "", err
		}
	}

	retries := 0
	for {
		if retries >= 400 {
			return nil, iface, ErrMaxRetries
		}

		i, err := net.InterfaceByName(iface)
		if err != nil {
			return nil, iface, err
		}

		addrs, err := i.Addrs()
		if err != nil {
			return nil, iface, err
		}

		if len(addrs) > 0 {
			for _, addr := range addrs {
				ip, _, err := net.ParseCIDR(addr.String())
				if err != nil {
					log.Fatalf("Failed to parse received addr '%s' as CIDR: %v", addr, err)
				}

				if ip.To4() != nil {
					return ip, iface, nil //we're done here
				}
			}
		}

		retries += 1
		select {
		case <-exit:
			return nil, iface, ErrUserCancelled
		case <-time.After(time.Millisecond * 200):
		}
	}

	return net.IP{}, iface, nil
}

var iface = flag.String("iface", "", "The network interface that is expected receive an address")
var name = flag.String("name", "", "Give this member a descriptive name upon authorizing")
var startDaemon = flag.Bool("start-daemon", false, "Also start the daemon (-d): this is for testing only")
var installDir = flag.String("install-dir", "/var/lib/zerotier-one", "Where zerotier is installed")
var endpoint = flag.String("api-endpoint", "https://my.zerotier.com/api/", "Location of the ZeroTier API")

func main() {
	flag.Parse()
	exit := make(chan os.Signal, 1)
	signal.Notify(exit, os.Interrupt, os.Kill)
	log.SetPrefix(LinePrefix)
	log.SetFlags(0)

	netid := flag.Arg(0)
	if netid == "" {
		printUsage()
		os.Exit(1)
	}

	token := flag.Arg(1)
	if token == "" {
		printUsage()
		os.Exit(1)
	}

	log.Printf("Waiting for ZeroTier Daemon to be up...")
	err := WaitForDaemon(exit, *startDaemon, *installDir)
	if err != nil {
		log.Fatalf("Failed to wait for Daemon: %v", err)
	}

	log.Printf("Joining network '%s'...", netid)
	memberid, err := JoinNetwork(exit, netid, *installDir)
	if err != nil {
		log.Fatalf("Failed to join ZeroTier network '%s': %v", netid, err)
	}

	log.Printf("Authorizing member '%s' as '%s'...", memberid, *name)
	err = AuthorizeMember(memberid, *name, netid, *endpoint, token)
	if err != nil {
		log.Fatalf("Failed to authorize member '%s': %v", memberid, err)
	}

	log.Printf("Waiting for network address...")
	ip, ipif, err := WaitForIP(exit, *installDir, netid, *iface)
	if err != nil {
		log.Fatalf("Failed to receive network address: %v", err)
	}

	log.Printf("Done! Received address '%s' on '%s'", ip.String(), ipif)
}
