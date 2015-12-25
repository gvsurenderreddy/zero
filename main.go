package main

import (
	"flag"
	"log"
)

func main() {
	flag.Parse()
	log.SetPrefix("zero: ")
	log.SetFlags(0)

	log.Printf("Hello World!")
}
