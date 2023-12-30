<h1 align="center">DOMAINIM</h1>
<p align="center">
<img src=https://img.shields.io/badge/nim-2.0-blue?logo=nim>
<img src=https://img.shields.io/github/stars/pptx704/domainim>
<img src=https://img.shields.io/github/v/release/pptx704/domainim>
<a href="#license"><img src=https://img.shields.io/github/license/pptx704/domainim></a>
<a href="https://t.me/pptx704"><img src=https://img.shields.io/badge/Contact-telegram-blue></a>
</p>

<p align="center">
  <a href="#Features">Features</a> •
  <a href="#Usage">Usage</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#additional-notes">Additional Notes</a>
</p>

Domainim is a 🚀 Blazing fast 🚀 domain reconnaissance tool for bounty hunters written in Nim.

# Features
Current features (v1.0.1)-
- Subdomain enumeration (2 engines + bruteforcing)
- Resolving A records (IPv4)
- User-friendly output
- Detects wildcard subdomains (for bruteforcing)

![](https://i.postimg.cc/W13H5Dpt/image.png)

- Virtual hostname enumeration
- Reverse DNS lookup
- Subdomains as input
- TCP port scanning with full user control
- Subdomains are accepted as input

![](https://i.postimg.cc/Jz49S6xr/image.png)

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

```
./domainim <domain> [--ports=<ports>] [--dns=<dns>]
```
- `<domain>` is the domain to be enumerated. It can be a subdomain as well.
- `<ports>` is a string speicification of the ports to be scanned. It can be one of the following-
  - `all` - Scan all ports (1-65535)
  - `none` - Skip port scanning (default)
  - `t<n>` - Scan top n ports (same as `nmap`). i.e. `t100` scans top 100 ports. Max value is 5000. If n is greater than 5000, it will be set to 5000.
  - single value - Scan a single port. i.e. `80` scans port 80
  - range value - Scan a range of ports. i.e. `80-100` scans ports 80 to 100
  - comma separated values - Scan multiple ports. i.e. `80,443,8080` scans ports 80, 443 and 8080
  - `combination` - Scan a combination of the above. i.e. `80,443,8080-8090,t500` scans ports 80, 443, 8080 to 8090 and top 500 ports
- `<dns>` is the address of the dns server. This should be a valid IPv4 address and can optionally contain the port number-
  - `a.b.c.d` - Use DNS server at `a.b.c.d` on port 53
  - `a.b.c.d#n` - Use DNS server at `a.b.c.d` on port `e`

**Examples**
- `./domainim nmap.org --ports=all`
- `./domainim google.com --ports=none --dns=8.8.8.8#53`
- `./domainim pptx704.com --ports=t100`
- `./domainim mysite.com --ports=t50,5432,7000-9000 --dns=1.1.1.1`

# Contributing
Contributions are welcome. Feel free to open a pull request or an issue.

## Planned Features
- [x] TCP port scanning
- [ ] UDP port scanning support
- [ ] Resolve AAAA records (IPv6)
- [x] Custom DNS server
- [x] Add more engines for subdomain enumeration (bruteforcing added)
- [ ] File output (probably CSV or JSON)
- [ ] Multiple domain enumeration
- [ ] Local network scanning
- [ ] Dir and File busting

## Others
- [x] Update verbose output when encountering errors (v0.2.0)
- [x] Show progress bar for longer operations
- [ ] Add individual port scan progress bar
- [ ] Add tests
- [ ] Add comments and docstrings

# Additional Notes
This project is still in its early stages. There are several limitations I am aware of.

The two engines I am using (I'm calling them engine because Sublist3r does so) currently have some sort of response limit. [dnsdumpster](https://dnsdumpster.com) can fetch upto 100 subdomains. [crt.sh](https://crt.sh) also randomizes the results in case of too many results. Another issue with [crt.sh](https://crt.sh) is the fact that it returns some SQL error sometimes. So for some domain, results can be different for different runs. I am planning to add more engines in the future (at least a brute force engine).

The port scanner has only `ping response time + 750ms` timeout. This might lead to false negatives. Since, **domainim** is not meant for port scanning but to provide a quick overview, such cases are acceptable. However, I am planning to add a flag to increase the timeout. For the same reason, filtered ports are not shown. For more comprehensive port scanning, I recommend using [Nmap](https://nmap.org). Domainim also doesn't bypass rate limiting (if there is any).

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

DNS server might have some sort of rate limiting. That's why I added random delays (between 0-300ms) for IPv4 resolving per query. This is to not make the DNS server get all the queries at once but rather in a more natural way. For bruteforcing method, the value is between 0-1000ms by default but that can be changed using `--throttle | -t` flag.

One particular limitation that is bugging me is that the DNS resolver would not return all the IPs for a domain. So it is necessary to make multiple queries to get all (or most) of the IPs. But then again, it is not possible to know how many IPs are there for a domain. I still have to come up with a solution for this. Also, `nim-ndns` doesn't support CNAME records. So, if a domain has a CNAME record, it will not be resolved. I am waiting for a response from the author for this.

For now, bruteforcing is skipped if a possible wildcard subdomain is found. This is because, if a domain has a wildcard subdomain, bruteforcing will resolve IPv4 for all possible subdomains. However, this will skip valid subdomains also (i.e. `scanme.nmap.org` will be skipped even though it's not a wildcard value). I will add a `--force-brute | -fb` flag later to force bruteforcing.

Similar thing is true for VHost enumeration for subdomain inputs. Since, urls that ends with given subdomains are returned, subdomains of similar domains are not considered. For example, `scannme.nmap.org` will not be printed for `ack.nmap.org` but `something.ack.nmap.org` might be. I can search for all subdomains of `nmap.org` but that defeats the purpose of having a subdomains as an input.

# License
MIT License. See [LICENSE](LICENSE) for full text.