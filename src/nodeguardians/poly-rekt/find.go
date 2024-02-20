package main

import (
	"bytes"
	"fmt"
	"strconv"
	"encoding/hex"
    "golang.org/x/crypto/sha3"
)

func main() {
	target, _ := hex.DecodeString("ef51774d")
	
	for result := 1908000000 ; ; result++ {
		i := []byte(strconv.Itoa(result))

		hash := sha3.NewLegacyKeccak256()
		hash.Write([]byte("attack"))
		hash.Write(i)
		hash.Write([]byte("(bytes32[],uint64,address)"))
		buf := hash.Sum([]byte{})

		if bytes.Compare(buf[0:4], target) == 0 {
			fmt.Printf("%x found with : attack%d(bytes32[],uint64,address)\n", buf, result )
			println("IDX=", result)
			return
		}

		if result > 0 && result%1000000 == 0 {
			println("IDX=", result)
		}
	}
}