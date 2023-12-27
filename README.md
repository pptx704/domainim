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
Current features (v1.0.0-beta)-
- Subdomain enumeration (2 engines)
- Resolving A records (IPv4)
- Progress tracking

![](https://i.postimg.cc/rsjqrNXn/image.png)

- Virtual hostname enumeration
- Reverse DNS lookup
- Subdomains as input
- Verbose output
- TCP port scanning with full user control

![](https://i.postimg.cc/x8JGCN3J/image.png)

A few features are work in progress. See [Planned features](#planned-features) for more details.

The project is inspired by [Sublist3r](https://github.com/aboul3la/Sublist3r). The port scanner module is heavily based on [NimScan](https://github.com/elddy/NimScan).

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
./domainim <domain> [--ports=<ports>]
```

Or, you can just download the binary from the [release page](https://github.com/pptx704/domainim/releases). Keep in mind that the binary is tested on Debian based systems only.

# Usage

```bash
./domainim <domain> [--ports=<ports>]
```
- `<domain>` is the domain to be enumerated. It can be a subdomain as well.
- `<ports>` is a string speicification of the ports to be scanned. It can be one of the following-
  - `all` - Scan all ports (1-65535)
  - `none` - Skip port scanning
  - `t<n>` - Scan top n ports (same as `nmap`). i.e. `t100` scans top 100 ports
  - `single value` - Scan a single port. i.e. `80` scans port 80
  - `range value` - Scan a range of ports. i.e. `80-100` scans ports 80 to 100
  - `comma separated values` - Scan multiple ports. i.e. `80,443,8080` scans ports 80, 443 and 8080
  - `combination` - Scan a combination of the above. i.e. `80,443,8080-8090,t500` scans ports 80, 443, 8080 to 8090 and top 500 ports

**Examples**
- `./domainim nmap.org --ports=all`
- `./domainim google.com --ports=none`
- `./domainim pptx704.com --ports=t100`
- `./domainim mysite.com --ports=t50,5432,7000-9000`

# Contributing
Contributions are welcome. Feel free to open a pull request or an issue.

## Planned Features
- [x] TCP port scanning
- [ ] UDP port scanning support
- [ ] Resolve AAAA records (IPv6)
- [ ] Custom DNS server
- [ ] Add more engines for subdomain enumeration
- [ ] File output (probably CSV or JSON)
- [ ] Multiple domain enumeration
- [ ] Dir and File busting

## Others
- [x] Update verbose output when encountering errors (v0.2.0)
- [x] Show progress bar for longer operations
- [ ] Add individual port scan progress bar
- [ ] Add tests
- [ ] Add comments and docstrings

# Additional Notes
This project is still in its early stages. There are several limitations I am aware of.

The two engines I am using (I'm calling them engine because Sublist3r does so) currently have some sort of response limit. [dnsdumpster](https://dnsdumpster.com) can fetch upto 100 subdomains. [crt.sh](https://crt.sh) also randomizes the results in case of too many results. I am planning to add more engines in the future (at least a brute force engine).

The port scanner has only `ping response time + 750ms` timeout. This might lead to false negatives. Since, **domainim** is not meant for port scanning but to provide a quick overview such cases are acceptable. However, I am planning to add a flag to increase the timeout. For the same reason, filtered ports are not shown. For more comprehensive port scanning, I recommend using [NimScan](https://nmap.org). This also doesn't bypass rate limiting (if there is any).

It might seem that the way vhostnames are printed, it just brings repeition on the table.

![](https://i.postimg.cc/HLkC413T/image.png)

Printing as the following might've been better-
```
ack.nmap.org, issues.nmap.org, nmap.org, research.nmap.org, scannme.nmap.org, svn.nmap.org, www.nmap.org
  ↳ 45.33.49.119
    ↳ Reverse DNS: ack.nmap.org. 
```
But previously while testing, I found cases where not all IPs are shared by same set of vhostnames. That is why I decided to keep it this way.

![](https://i.postimg.cc/q7PjB8NW/image.png)

Currently, the program uses system's DNS server to resolve the IPv4 addresses. It would make much more sense if the user could specify the DNS server.

One particular limitation that is bugging me is that the DNS resolver would not return all the IPs for a domain. So it is necessary to make multiple queries to get all (or most) of the IPs. But then again, it is not possible to know how many IPs are there for a domain. I still have to come up with a solution for this.

# Known Bugs
For now, I have one known bug. In case the sites are too slow (as in doesn't respond within 20s), the program crashes with a timeout error-
```
net.nim(1475)            waitFor
Error: unhandled exception: Call to 'readLine' timed out. [TimeoutError]
```
This is not an expected behaviour since try-except blocks are used to handle this error. I am still trying to figure out the cause of this error.

# License
MIT License. See [LICENSE](LICENSE) for full text.