package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
)

func printUsage() {
	fmt.Fprintf(os.Stderr, "usage: floor zt_net zt_token [-iface]\n")
}

func waitForDaemon(exit chan os.Signal, start bool) error {
	//wait for daemon to be up

	return nil
}

func joinNetwork(netid string) (string, error) {
	//execute join

	//wait for identity file

	return "", nil
}

func authorizeMember(memberid, netid, token string) error {
	//call http api

	return nil
}

func waitForIP(exit chan os.Signal, iface string) (net.IP, error) {
	//wait for an ip on iface

	return net.IP{}, nil
}

var iface = flag.String("iface", "zt0", "The network interface that is expected receive an address")
var startDaemon = flag.Bool("start-daemon", false, "Also start the daemon (zerotier-one -d), this is for testing only")

func main() {
	flag.Parse()
	exit := make(chan os.Signal, 1)
	signal.Notify(exit, os.Interrupt, os.Kill)
	log.SetPrefix("zero: ")
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
	err := waitForDaemon(exit, *startDaemon)
	if err != nil {
		log.Fatalf("Failed to wait for Daemon: %v", err)
	}

	log.Printf("Joining network '%s'...", netid)
	memberid, err := joinNetwork(netid)
	if err != nil {
		log.Fatalf("Failed to join ZeroTier network '%s': %v", netid, err)
	}

	log.Printf("Authorizing member '%s'...", memberid)
	err = authorizeMember(memberid, netid, token)
	if err != nil {
		log.Fatalf("Failed to authorize member '%s': %v", memberid, err)
	}

	log.Printf("Waiting for network address on interface '%s'...", *iface)
	ip, err := waitForIP(exit, *iface)
	if err != nil {
		log.Fatalf("Failed to receive network address on '%s': %v", iface, err)
	}

	log.Printf("Done: Received address '%s'!", ip.String())
}
