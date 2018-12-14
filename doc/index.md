---
layout: page
---

# dEQP

Experiments in running the dEQP testsuit faster.


### Usage

Run the command it will tell you what's missing.


### Code documentation

A good place to start is with the [Driver][Driver] class. Along with the
[deqp.tests][Tests] package that houses all of the modules containing test
related code. Some deep diving into the program lanching can be found
[here][Launcher].

### Downloading

Download from the CI here:
 [x86-linux](https://ci.walkyrie.se/job/Projects/job/dEQP/job/master/lastSuccessfulBuild/artifact/dEQP-x86-linux.tar.gz),
 [x86_64-linux](https://ci.walkyrie.se/job/Projects/job/dEQP/job/master/lastSuccessfulBuild/artifact/dEQP-x86_64-linux.tar.gz).


### Building yourself

```bash
# Get deps, llvm 5, 6, 7 should work, must be gdc-6 as gdc-7 has bugs.
sudo apt install llvm-7.0 clang-7.0 gdc-6 nasm

# Get the Volt toolchain.
wget https://ci.walkyrie.se/job/VoltLang/job/Battery/job/master/lastSuccessfulBuild/artifact/battery-x86_64-linux.tar.gz
tar xfv battery-x86_64-linux.tar.gz
git clone https://github.com/VoltLang/Volta
git clone https://github.com/VoltLang/Watt
git clone https://github.com/Wallbraker/dEQP
./battery config \
        Volta \
        Watt \
        dEQP
./battery build
```

[Driver]: {{ "deqp.driver.Driver" | vdoc_find_url }} "Driver class"
[Tests]: {{ "deqp.tests" | vdoc_find_url }} "Tests module"
[Launcher]: {{ "deqp.launcher.posix" | vdoc_find_url }} "Launcher class"
