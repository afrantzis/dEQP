# dEQP

Experiments in running the dEQP testsuit faster.


### Usage

Run the command it will tell you what's missing.


### Downloading

Download from the CI here:
 [x86-linux](https://ci.walkyrie.se/job/Projects/job/dEQP/job/master/lastSuccessfulBuild/artifact/dEQP-x86-linux.tar.gz),
 [x86_64-linux](https://ci.walkyrie.se/job/Projects/job/dEQP/job/master/lastSuccessfulBuild/artifact/dEQP-x86_64-linux.tar.gz).


### Building yourself

```bash
# Get deps, llvm 5, 6, 7 should work, must be gdc-6 as gdc-7 has bugs.
sudo apt install llvm-5.0 clang-5.0 gdc-6 nasm

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
