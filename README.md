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
- Resolving A records (IPv4) and AAAA records (IPv6)

![](https://i.postimg.cc/J0SBWgG8/image.png)

![](https://i.postimg.cc/wBHy3RkC/image.png)

- Virtual hostname enumeration
- Reverse DNS lookup

![](https://i.postimg.cc/rsRKgJgP/image.png)

- Detects wildcard subdomains (IPv4 and IPv6). Passive results that resolve only to the wildcard IPs are hidden unless they were seen in a TLS certificate. Bruteforcing can be forced with `--force-brute`, in which case results resolving only to the wildcard IPs are discarded

![](https://i.postimg.cc/wx7GpGvs/image.png)

- Basic TCP port scanning
- Basic UDP port scanning (opt-in with `--udp-ports`, no root needed)
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
./domainim <domain> [--ports=<ports>] [--udp-ports=<ports>]
```

Or, you can just download the binary from the [release page](https://github.com/pptx704/domainim/releases). Keep in mind that the binary is tested on Debian based systems only.

# Usage

```
./domainim <domain> [--ports=<ports> | -p:<ports>] [--udp-ports=<ports>] [--wordlist=<filename> | -l:<filename> [--rps=<int> | -r:<int>] [--force-brute | -f]] [--dns=<dns> | -d:<dns>] [--out=<filename> | -o:<filename>]
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
- `--udp-ports` is a string specification of the UDP ports to be scanned. It uses the same grammar as `--ports` (`all`, `none`, `t<n>`, single value, range value, comma separated values and combinations). UDP scanning is off unless this option is given with at least one port; `--ports` stays TCP-only and never enables UDP. Note that `t<n>` uses the same top ports list as the TCP scan, which is ordered by TCP popularity. i.e.
  - `--udp-ports=53` scans UDP port 53
  - `--udp-ports=53,123,161` scans UDP ports 53, 123 and 161
  - `--udp-ports=1-1024` scans UDP ports 1 to 1024
  - `--udp-ports=t100` scans the top 100 ports as UDP
  - `--ports=80,443 --udp-ports=53,t20` scans TCP ports 80 and 443, and UDP port 53 and the top 20 ports
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
- `./domainim domainim.com --ports=80 --udp-ports=53,123`
- `./domainim nmap.org --udp-ports=53,123,161 --out=results.json`

The help menu can be accessed using `./domainim --help` or `./domainim -h`.
```
Usage:
    domainim <domain> [--ports=<ports> | -p:<ports>] [--udp-ports=<ports>] [--wordlist=<filename> | -l:<filename> [--rps=<int> | -r:<int>] [--force-brute | -f]] [--dns=<dns> | -d:<dns>] [--out=<filename> | -o:<filename>]
    domainim (-h | --help)

Options:
    -h, --help              Show this screen.
    -p, --ports             Ports to scan. [default: `none`]
                            Can be `all`, `none`, `t<n>`, single value, range value, combination
    --udp-ports             UDP ports to scan. Same format as --ports. [default: `none`]
                            Replies are reported as open, silence as open|filtered.
    -l, --wordlist          Wordlist for subdomain bruteforcing. Bruteforcing is skipped for invalid file.
    -f, --force-brute       Bruteforce even if a wildcard record is found. Results resolving only to wildcard IPs are discarded.
    -d, --dns               IP and Port for DNS Resolver. Should be a valid IPv4 with an optional port [default: system default]
    -r, --rps               DNS queries to be made per second [default: 1024 req/s]
    -o, --out               JSON file where the output will be saved. Filename must end with `.json`

Examples:
    domainim domainim.com --ports=80 --udp-ports=53,123
    domainim domainim.com -p:t500 -l:wordlist.txt --dns:1.1.1.1#53 --out=results.json
    domainim sub.domainim.com --ports=all --dns:8.8.8.8 -l:wordlist.txt -r:1500 -f -o:results.json
```

The JSON schema for the results is as follows-

```
[
  {
    "subdomain": string,
    "ipv6": [string],
    "data": [
      {
        "ipv4": string,
        "vhosts": [string],
        "reverse_dns": string,
        "ports": [int],
        "udp_ports": [int],
        "udp_open_filtered": [int]
      }
    ]
  }
]
```

`ipv6` lists the IPv6 addresses (AAAA records) of the subdomain. It is always present and is an empty list when the subdomain has none. The addresses are in compressed lowercase form and sorted as strings. The key comes right after `subdomain` and before `data`. Entries of `data` stay IPv4-based: there is one entry for each IPv4 address, and IPv6 addresses never get an entry of their own. All other fields keep their names, types and meaning, so `ipv6` is the only addition to the JSON output.

`ports` is always present and lists the open TCP ports. `udp_ports` and `udp_open_filtered` are present only when `--udp-ports` was given with at least one port; without it they are left out. All three lists are sorted. `data` is an empty list for a subdomain without a public IPv4 address, also when it has IPv6 addresses.

- `udp_ports` - UDP ports that answered a probe (open)
- `udp_open_filtered` - UDP ports that did not answer (open|filtered)

UDP port states-
- **open** - the host replied to the probe. Shown as `Open UDP Ports` in the terminal and in `udp_ports`.
- **closed** - the host answered with an ICMP port unreachable. Closed ports are not shown and not saved.
- **open|filtered** - no reply arrived within the timeout (1 second), or the probe could not be completed. The port is either open but silent, or a firewall dropped the probe or the ICMP reply; the two cases cannot be told apart. Shown as `Open|Filtered UDP Ports` in the terminal and in `udp_open_filtered`.

Example of a host entry with `--udp-ports=53,123,161`-
```
{
  "ipv4": "45.33.32.156",
  "vhosts": ["echo.nmap.org", "scanme.nmap.org"],
  "reverse_dns": "scanme.nmap.org.",
  "ports": [],
  "udp_ports": [123],
  "udp_open_filtered": []
}
```

Example of a subdomain entry with an IPv4 and two IPv6 addresses-
```
{
  "subdomain": "scanme.nmap.org",
  "ipv6": [
    "2600:3c01::f03c:91ff:fe18:bb2f",
    "2600:3c01::f03c:91ff:fe18:bb30"
  ],
  "data": [
    {
      "ipv4": "45.33.32.156",
      "vhosts": ["echo.nmap.org", "scanme.nmap.org"],
      "reverse_dns": "scanme.nmap.org.",
      "ports": [22, 80]
    }
  ]
}
```

Example json for `nmap.org` can be found [here](https://pastebin.com/iqNiNtsT).

## IPv6
IPv6 addresses come from AAAA records and are shown for each subdomain, after its IPv4 addresses, as one line with the addresses sorted and separated by commas-
```
scanme.nmap.org
  ↳ 45.33.32.156
    ↳ Reverse DNS: scanme.nmap.org.
    ↳ Virtual Hostnames: echo.nmap.org, scanme.nmap.org
    ↳ Open Ports: 22, 80
 
  ↳ IPv6: 2600:3c01::f03c:91ff:fe18:bb2f, 2600:3c01::f03c:91ff:fe18:bb30
 
```
The IPv4 part of the output is unchanged, and the `IPv6:` line is added after it. A subdomain that has only IPv6 addresses shows only the `IPv6:` line. `Public IPv4 not found` is printed only when the subdomain has neither IPv4 nor IPv6 addresses.

Wildcard detection covers both families. The random names that are probed for a wildcard record are resolved for A and AAAA records, and the wildcard IPs printed in `Wildcard record found (...)` can contain IPv4 and IPv6 addresses.
- Bruteforcing (`--force-brute`): wildcard IPs are removed from the A results and from the AAAA results separately. A subdomain is discarded when no IPv4 and no IPv6 address is left, so one with a non-wildcard address in either family is kept with the remaining addresses.
- Passive results: a subdomain is hidden when all of its IPv4 and IPv6 addresses are wildcard IPs, so a single non-wildcard address of either family keeps it. The exception is the same as for IPv4: names seen in a TLS certificate and the target domain itself are never hidden.

IPv6 limitations-
- IPv6 is discovery only. There is no reverse DNS, virtual hostname mapping, ping or port scan (TCP or UDP) for IPv6 addresses. These work on IPv4 addresses only.
- Loopback (`::1`), unspecified (`::`), link-local (`fe80::/10`) and IPv4-mapped (`::ffff:a.b.c.d`) addresses are dropped, as are invalid ones.
- `--dns` still takes an IPv4 resolver address. Records are fetched with AAAA queries sent to that resolver, over IPv4.
- Each host costs one extra DNS query (the AAAA query, sent next to the A query).
- A failed or timed out AAAA lookup leaves `ipv6` empty and does not affect the IPv4 results. A failed A lookup, however, makes the host count as unresolved, and its IPv6 result is not kept.

## UDP scanning limitations
- UDP scanning uses ordinary datagram sockets, so it needs no raw sockets or root. As a result a port is closed only when the target's ICMP port unreachable reaches the scanner.
- Many targets rate limit ICMP errors, and firewalls often drop ICMP. Such ports are reported as open|filtered, so open|filtered is common and does not mean the port is open.
- Probe payloads are sent only for a few common services (DNS 53, NTP 123, SNMP 161, NetBIOS 137, SSDP 1900, mDNS 5353). Other ports get an empty datagram, which most services ignore, so they show up as open|filtered even when open.
- Each probe waits 1 second for a reply, and at most 2000 probes per second are sent. Large ranges (e.g. `all`) take a long time. Prefer a short list or `t<n>`.
- Hosts are scanned even if they do not answer ping. For comprehensive UDP scanning use [Nmap](https://nmap.org).

# Contributing
Contributions are welcome. Feel free to open a pull request or an issue.

## Planned Features
- [x] TCP port scanning
- [x] UDP port scanning
- [x] Resolve AAAA records (IPv6)
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

DNS server might have some sort of rate limiting. That's why I added random delays (between 0-300ms) for resolving per host, before its A and AAAA queries. This is to not make the DNS server get all the queries at once but rather in a more natural way. For bruteforcing method, the value is between 0-1000ms by default but that can be changed using `--rps | -r` flag.

One particular limitation that is bugging me is that the DNS resolver would not return all the IPs for a domain. So it is necessary to make multiple queries to get all (or most) of the IPs. But then again, it is not possible to know how many IPs are there for a domain. I still have to come up with a solution for this. Domains with a CNAME record are resolved to the IPv4 and IPv6 addresses of the CNAME target.

By default, bruteforcing is skipped if a possible wildcard subdomain is found. This is because, if a domain has a wildcard subdomain, bruteforcing will resolve IPv4 and IPv6 addresses for all possible subdomains. Use `--force-brute | -f` to bruteforce anyway. In that case, the wildcard IPs are detected first and subdomains resolving only to those IPs are discarded, so valid subdomains such as `scanme.nmap.org` are still found. Subdomains that share all their IPs with the wildcard record cannot be told apart from it and will be discarded as well.

Passive engines can also return names that only exist because of the wildcard record (e.g. typos that someone once queried). So, for domains with a wildcard record, subdomains that resolve only to the wildcard IPs are hidden, unless they appear in a TLS certificate ([crt.sh](https://crt.sh) or [certspotter](https://sslmate.com/certspotter)). The number of hidden subdomains is printed. If no certificate engine responds, nothing is hidden.

Similar thing is true for VHost enumeration for subdomain inputs. Since, urls that ends with given subdomains are returned, subdomains of similar domains are not considered. For example, `scannme.nmap.org` will not be printed for `ack.nmap.org` but `something.ack.nmap.org` might be. I can search for all subdomains of `nmap.org` but that defeats the purpose of having a subdomains as an input.

# License
MIT License. See [LICENSE](LICENSE) for full text.