<h1 align="center">DOMAINIM</h1>
<p align="center">
<img src=https://img.shields.io/github/languages/top/pptx704/domainim
>
<img src=https://img.shields.io/badge/OS-Debian_Linux-blue>
<img src=https://img.shields.io/github/languages/code-size/pptx704/domainim>
<img src=https://img.shields.io/github/stars/pptx704/domainim>
<img src=https://img.shields.io/github/v/release/pptx704/domainim
>
<a href="#license"><img src=https://img.shields.io/github/license/pptx704/domainim></a>
</p>

<p align="center">
  <a href="#Features">Features</a> •
  <a href="#Usage">Usage</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#known-bugs">Known Bugs</a> •
  <a href="#additional-notes">Additional Notes</a>
</p>

Domainim is a 🚀 Blazing fast 🚀 domain reconnaissance tool for bounty hunters written in Nim.

# Features
Current features (v0.2.1)-
- Subdomain enumeration (2 engines)
- Resolving A records
- Progress tracking

![](https://i.postimg.cc/zfrqLm1z/image.png)

- Virtual hostname enumeration
- Reverse DNS lookup
- Subdomains as input
- Verbose output

![](https://i.postimg.cc/xThMM9RS/image.png)

A few features are work in progress. See [Planned features](#planned-features) for more details.

# Installation
You can build this repo from source-
- Clone the repository
```bash
git clone git@github.com:pptx704/domainim
```
- Build the binary
```bash
nimble build
```
- Run the binary
```bash
./domainim <domain>
```

Or you can just, download the binary from the [release page](https://github.com/pptx704/domainim/releases). Keep in mind that the binary is tested on Debian based systems only.

# Usage

```bash
./domainim <domain>
```


# Contributing
Contributions are welcome. Feel free to open a pull request or an issue.

## Planned Features
- [ ] Open ports enumeration (v1.0.0)
- [ ] Give more control to the user by adding flags
- [ ] File output (probably CSV or JSON)
- [ ] Multiple domain enumeration
- [ ] Add more engines for subdomain enumeration
- [ ] Dir and File busting

## Others
- [x] Update verbose output when encountering errors (v0.2.0)
- [x] Show progress bar for longer operations
- [ ] Add tests
- [ ] Add comments and docstrings

# Additional Notes
This project is still in its early stages. There are several limitations I am aware of.

The two engines I am using currently have some sort of response limit. [dnsdumpster](https://dnsdumpster.com) can fetch upto 100 subdomains. [crt.sh](https://crt.sh) also randomizes the results in case of too many results. I am planning to add more engines in the future (at least a brute force engine).

It might seem that the way vhostnames are printed, it is just brings repeition on the table.

![](https://i.postimg.cc/HLkC413T/image.png)

Printing as the following might've been better-
```
ack.nmap.org, issues.nmap.org, nmap.org, research.nmap.org, scannme.nmap.org, svn.nmap.org, www.nmap.org
  ↳ 45.33.49.119
    ↳ Reverse DNS: ack.nmap.org. 
```
But previously while testing, I found cases where not all IPs are shared by same set of vhostnames. That is why I decided to keep it this way.

![](https://i.postimg.cc/q7PjB8NW/image.png)

# Known Bugs
For now, I have one known bug. In case the sites are too slow (as in doesn't respond within 20s), the program crashes with a timeout error-
```
net.nim(1475)            waitFor
Error: unhandled exception: Call to 'readLine' timed out. [TimeoutError]
```
This is not an expected behaviour since try-except blocks are used to handle this error. I am still trying to figure out the cause of this error.

# License
MIT License. See [LICENSE](LICENSE) for full text.