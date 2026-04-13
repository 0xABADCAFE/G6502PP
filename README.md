# G6502PP

## The most cursed 6502 emulator yet.

The C++ port of SixPhphive02 converted to Go... Almost.

![Erm...](res/chimera.jpg)

Just because you can do a thing, doesn't mean you should.

## What

A quick and inexpressibly dirty port of [C6502PP](https://github.com/0xABADCAFE/C6502PP) (itself a port from PHP [SixPhphive02](https://github.com/0xABADCAFE/sixphphive02)) to Go:

- **MVC** (*Manually Vibe Coded*). I have no idea what I am doing but:
    - I know Go has braces and a familiar smell of the sea.
    - I read the first few pages of the go by example site.

- An unholy union of the C Preprocessor (CPP) and Go compiler:
    - CPP pulls together a bunch of include files that contain various macros.
    - Macros generate imperative Go code from a Domain Specific Language (DSL) representation.
    - Interpreter code is almost 100% inlined in a single Run() method.

- The DSL is almost identical to the one defined in C6502PP which was added so that depending on the compilation flags, generated either a switch case model or a computed goto with threaded dispatch.
    - In this version, it produces only the switch case as there's no obvious alternative, other than a function pointer table.
    - Slight modifications were needed to satisy Go's particular idioms on statements.

 
## Why?

For fun and to see if it would work.

## Building

Wait, you're serious? You will need:

**cpp** - Just install gcc for your system.

**Go** - I've only tested 1.26 and I have no idea if older version work or what incompatibilities there may be with any other version at all.

A **basic** text editor, or at least one you can turn off parsing on, because the syntactical byrid code is so cursed your preferred IDE might have a stroke.

```bash
    :~/$ git clone https://github.com/0xABADCAFE/G6502PP.git

    :~/$ cd G6502PP/src
    :~/C6502PP/src$ make clean && make
```

If you are lucky, you should see outout similar to the following:

```
    rm -rf build bin/G65O2PP
    Preprocessing Go files...
    gcc -E -P -xc -undef src/main.go -o build/processed.go
    Formatting intermediate file...
    go fmt build/processed.go
    build/processed.go
    Compiling G65O2PP...
    go build -ldflags="-s -w" -gcflags="all=-B -l" -trimpath -o bin/G65O2PP build/processed.go
```

The the build process actually creates a single file `build/processed.go` that is then compiled in one step. You can view this file to see what has been unleashed.

## Results

The binary will perform two basic tests:

- The fastest instruction throughput, based on execution long spans of NOP.
- A more typical case instruction throughput, based on running the [Klaus Dormann](https://github.com/Klaus2m5/6502_65C02_functional_tests) diagnostic ROM.

Each test takes a few seconds to run and outputs the same data. For example:

```
    :~/C6502PP/bin$ ./G65O2PP 
    PC: 0x0002 => 0x00
    SP: 0x01FF => 0x00
    A: 0x00 [   0] 
    X: 0x00 [   0]
    Y: 0x00 [   0]
    F: [- - | - - I Z -]
    10000 loops of 32768 NOP took 384550446 nanoseconds [852.111871 MIPS]
    PC: 0x8200 => 0xFF
    SP: 0x01FF => 0x00
    A: 0x00 [   0]
    X: 0x00 [   0]
    Y: 0x00 [   0]
    F: [- - | - - I Z -]
    KLAUS PASSED
    KlausD 10 loops of 30648049 took 686804716 nanoseconds [446.241097 MIPS]
    PC: 0x3469 => 0x4C
    SP: 0x01FF => 0x34
    A: 0xF0 [ -16]
    X: 0x0E [  14]
    Y: 0xFF [  -1]
    F: [N V | - - - - C]

```
These are from a 2018 i7-7500U @ 3.5GHz. Compared to the *equivalent* compile-time-abstracted C++ version:

- The peak NOP performance is about the same.
- The KlausD performance is **20%** better at 446 versus 371 MIPS for the C++ version.
    - This is probably due to the fact that in this version, the Status and Accumulator registers have been pinned, in addition to the Program Counter and memory reference.
    - I should probably go back and make that change there too.

