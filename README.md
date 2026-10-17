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

Domainim is a fast domain reconnaissance tool for organizational network scanning. The tool aims to provide a brief overview of an organization's structure using techniques like OSINT, bruteforcing, DNS resolving etc.

# Features
Current features (v1.3.0)-
- Subdomain enumeration (6 engines + bruteforcing). Engines are queried concurrently-
  - [dnsdumpster.com](https://dnsdumpster.com)
  - [crt.sh](https://crt.sh)
  - [anubisdb.com](https://anubisdb.com)
  - [hackertarget.com](https://hackertarget.com)
  - [certspotter.com](https://sslmate.com/certspotter)
  - [rapiddns.io](https://rapiddns.io)
- User-friendly output
- Resolving A records (IPv4)

![](https://i.postimg.cc/J0SBWgG8/image.png)

![](https://i.postimg.cc/wBHy3RkC/image.png)

- Virtual hostname enumeration
- Reverse DNS lookup

![](https://i.postimg.cc/rsRKgJgP/image.png)

- Detects wildcard subdomains. Passive results that resolve only to the wildcard IPs are hidden unless they were seen in a TLS certificate. Bruteforcing can be forced with `--force-brute`, in which case results resolving only to the wildcard IPs are discarded

![](https://i.postimg.cc/wx7GpGvs/image.png)

- Basic TCP port scanning
- Subdomains are accepted as input

![](https://i.postimg.cc/2SZYS5Sh/image.png)

- Export results to JSON file

![](https://i.postimg.cc/9fv3ZYRM/image.png)

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
./domainim <domain> [--ports=<ports> | -p:<ports>] [--wordlist=<filename> | -l:<filename> [--rps=<int> | -r:<int>] [--force-brute | -f]] [--dns=<dns> | -d:<dns>] [--out=<filename> | -o:<filename>]
```
- `<domain>` is the domain to be enumerated. It can be a subdomain as well.
- `-- ports | -p` is a string speicification of the ports to be scanned. It can be one of the following-
  - `all` - Scan all ports (1-65535)
  - `none` - Skip port scanning (default)
  - `t<n>` - Scan top n most common ports (same as `nmap`). i.e. `t100` scans top 100 ports. Max value is 5000. If n is greater than 5000, it will be set to 5000.
  - single value - Scan a single port. i.e. `80` scans port 80
  - range value - Scan a range of ports. i.e. `80-100` scans ports 80 to 100
  - comma separated values - Scan multiple ports. i.e. `80,443,8080` scans ports 80, 443 and 8080
  - combination - Scan a combination of the above. i.e. `80,443,8080-8090,t500` scans ports 80, 443, 8080 to 8090 and top 500 ports
- `--dns | -d` is the address of the dns server. This should be a valid IPv4 address and can optionally contain the port number-
  - `a.b.c.d` - Use DNS server at `a.b.c.d` on port 53
  - `a.b.c.d#n` - Use DNS server at `a.b.c.d` on port `n`
- `--wordlist | -l` - Path to the wordlist file. This is used for bruteforcing subdomains. If the file is invalid, bruteforcing will be skipped. Empty lines and lines starting with `#` are ignored. You can get a wordlist from [SecLists](https://github.com/danielmiessler/SecLists/tree/master/Discovery/DNS). A wordlist is also provided in the [release page](https://github.com/pptx704/domainim/releases).
- `--force-brute | -f` - Bruteforce even if a wildcard record is found. Subdomains that resolve only to the wildcard IPs are discarded.
- `--rps | -r` - Number of requests to be made per second during bruteforce. The default value is `1024 req/s`. It is to be noted that, DNS queries are made in batches and next batch is made only after the previous one is completed. Since quries can be rate limited, increasing the value does not always guarantee faster results.
- `--out | -o` - Path to the output file. The output will be saved in JSON format. The filename must end with `.json`.

**Examples**
- `./domainim nmap.org --ports=all`
- `./domainim google.com --ports=none --dns=8.8.8.8#53`
- `./domainim pptx704.com --ports=t100 --wordlist=wordlist.txt --rps=1500`
- `./domainim pptx704.com --ports=t100 --wordlist=wordlist.txt --out=results.json`
- `./domainim nmap.org --wordlist=wordlist.txt --force-brute`
- `./domainim mysite.com --ports=t50,5432,7000-9000 --dns=1.1.1.1`

The help menu can be accessed using `./domainim --help` or `./domainim -h`.
```
Usage:
    domainim <domain> [--ports=<ports> | -p:<ports>] [--wordlist=<filename> | -l:<filename> [--rps=<int> | -r:<int>] [--force-brute | -f]] [--dns=<dns> | -d:<dns>] [--out=<filename> | -o:<filename>]
    domainim (-h | --help)

Options:
    -h, --help              Show this screen.
    -p, --ports             Ports to scan. [default: `none`]
                            Can be `all`, `none`, `t<n>`, single value, range value, combination
    -l, --wordlist          Wordlist for subdomain bruteforcing. Bruteforcing is skipped for invalid file.
    -f, --force-brute       Bruteforce even if a wildcard record is found. Results resolving only to wildcard IPs are discarded.
    -d, --dns               IP and Port for DNS Resolver. Should be a valid IPv4 with an optional port [default: system default]
    -r, --rps               DNS queries to be made per second [default: 1024 req/s]
    -o, --out               JSON file where the output will be saved. Filename must end with `.json`

Examples:
    domainim domainim.com -p:t500 -l:wordlist.txt --dns:1.1.1.1#53 --out=results.json
    domainim sub.domainim.com --ports=all --dns:8.8.8.8 -l:wordlist.txt -r:1500 -f -o:results.json
```

The JSON schema for the results is as follows-

```
[
  {
    "subdomain": string,
    "data": [
      {
        "ipv4": string,
        "vhosts": [string],
        "reverse_dns": string,
        "ports": [int]
      }
    ]
  }
]
```

Example json for `nmap.org` can be found [here](https://pastebin.com/iqNiNtsT).

# Contributing
Contributions are welcome. Feel free to open a pull request or an issue.

## Planned Features
- [x] TCP port scanning
- [ ] UDP port scanning support
- [ ] Resolve AAAA records (IPv6)
- [x] Custom DNS server
- [x] Add bruteforcing subdomains using a wordlist
- [x] Force bruteforcing (even if wildcard subdomain is found)
- [x] Add more engines for subdomain enumeration
- [x] File output (JSON)
- [ ] Multiple domain enumeration
- [ ] Dir and File busting

## Others
- [x] Update verbose output when encountering errors (v0.2.0)
- [x] Show progress bar for longer operations
- [x] Add individual port scan progress bar
- [ ] Add tests
- [ ] Add comments and docstrings

# Additional Notes
This project is still in its early stages. There are several limitations I am aware of.

The engines I am using (I'm calling them engine because Sublist3r does so) are free, keyless services and most have some sort of response limit. [dnsdumpster](https://dnsdumpster.com) returns up to 50 subdomains for free users and [rapiddns](https://rapiddns.io) about 100. [hackertarget](https://hackertarget.com) allows only a few queries per day per IP and [certspotter](https://sslmate.com/certspotter) only returns currently valid certificates. [crt.sh](https://crt.sh) randomizes the results in case of too many results and is frequently overloaded (HTTP 502). So for some domain, results can be different for different runs. A failing engine is reported and skipped; it never stops the scan. Passive sources may also contain stale or wildcard-generated names.

All IPs are port scanned concurrently on a single event loop (at most 4096 connection attempts in flight and 5000 started per second, so local and router queues don't drop SYN packets). Hosts that don't answer ping are not scanned. The port scanner has only `ping response time + 750ms` timeout. This might lead to false negatives. Since, **domainim** is not meant for port scanning but to provide a quick overview, such cases are acceptable. However, I am planning to add a flag to increase the timeout. For the same reason, filtered ports are not shown. For more comprehensive port scanning, I recommend using [Nmap](https://nmap.org). Domainim also doesn't bypass rate limiting (if there is any).

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

DNS server might have some sort of rate limiting. That's why I added random delays (between 0-300ms) for IPv4 resolving per query. This is to not make the DNS server get all the queries at once but rather in a more natural way. For bruteforcing method, the value is between 0-1000ms by default but that can be changed using `--rps | -r` flag.

One particular limitation that is bugging me is that the DNS resolver would not return all the IPs for a domain. So it is necessary to make multiple queries to get all (or most) of the IPs. But then again, it is not possible to know how many IPs are there for a domain. I still have to come up with a solution for this. Domains with a CNAME record are resolved to the IPv4 addresses of the CNAME target.

By default, bruteforcing is skipped if a possible wildcard subdomain is found. This is because, if a domain has a wildcard subdomain, bruteforcing will resolve IPv4 for all possible subdomains. Use `--force-brute | -f` to bruteforce anyway. In that case, the wildcard IPs are detected first and subdomains resolving only to those IPs are discarded, so valid subdomains such as `scanme.nmap.org` are still found. Subdomains that share an IP with the wildcard record cannot be told apart from it and will be discarded as well.

Passive engines can also return names that only exist because of the wildcard record (e.g. typos that someone once queried). So, for domains with a wildcard record, subdomains that resolve only to the wildcard IPs are hidden, unless they appear in a TLS certificate ([crt.sh](https://crt.sh) or [certspotter](https://sslmate.com/certspotter)). The number of hidden subdomains is printed. If no certificate engine responds, nothing is hidden.

Similar thing is true for VHost enumeration for subdomain inputs. Since, urls that ends with given subdomains are returned, subdomains of similar domains are not considered. For example, `scannme.nmap.org` will not be printed for `ack.nmap.org` but `something.ack.nmap.org` might be. I can search for all subdomains of `nmap.org` but that defeats the purpose of having a subdomains as an input.

# License
MIT License. See [LICENSE](LICENSE) for full text.