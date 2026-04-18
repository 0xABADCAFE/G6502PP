package main

import "os"
import "fmt"
import "time"

#include "cpu.gh"

func main() {

    const (
        BASE  = 0x200
        BLOCK = 32768
        LOOPS = 10000
    )

    mem := new(AddressSpace)
    mem[VEC_RES]     = BASE >> 8
    mem[VEC_RES + 1] = BASE & 0xFF

    cpu := &MOS6502{}
    cpu.Init(mem).ShowStatus();

    {
    
        // Block of NOPS
        for i := range BLOCK {
            mem[BASE + i] = NOP
        }
        mem[BASE + BLOCK] = 0xFF // illegal    

            
        tStart := time.Now()
        for range LOOPS {
            cpu.RunFrom(0x200)
        }
        tElapsed := time.Since(tStart)
        iNanoSeconds := uint64(tElapsed.Nanoseconds())
        fMIPS := 1.0e3 * float64(LOOPS * BLOCK) / float64(iNanoSeconds)

        fmt.Printf(
            "%d loops of %d NOP took %d nanoseconds [%f MIPS]\n",
            LOOPS,
            BLOCK,
            iNanoSeconds,
            fMIPS,
        )
        cpu.ShowStatus();
    
    }
    
    {
        const (
            KLAUS_OP_COUNT = 30648049
            KLAUS_MAGIC    = 0x3469  // Magic endless loop address for a successful run.
            KLAUS_START    = 0x400
            KLAUS_LOOPS    = 10    
        )
        
        payload, err := os.ReadFile("./data/rom/diagnostic/6502_functional_test.bin")
        if err != nil {
            panic(err)
        }

        copy(mem[:], payload)
        
        tStart := time.Now()
        for range KLAUS_LOOPS {
            cpu.RunFrom(KLAUS_START)
        }
        tElapsed := time.Since(tStart)
        iNanoSeconds := uint64(tElapsed.Nanoseconds())
        fMIPS := 1.0e3 * float64(KLAUS_LOOPS * KLAUS_OP_COUNT) / float64(iNanoSeconds)

        if KLAUS_MAGIC == cpu.iProgramCounter {
            fmt.Print("KLAUS PASSED\n")
            fmt.Printf(
                "KlausD %d loops of %d took %d nanoseconds [%f MIPS]\n",
                KLAUS_LOOPS,
                KLAUS_OP_COUNT,
                iNanoSeconds,
                fMIPS,
            )
 
        } else {
            fmt.Printf("KLAUS FAILED AT 0x%04X\n", cpu.iProgramCounter)        
        }

       cpu.ShowStatus();
    }
}
