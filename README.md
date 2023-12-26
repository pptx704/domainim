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
  <a href="#known-bugs">Known Bugs</a>
</p>

Domainim is a 🚀 Blazing fast 🚀 domain reconnaissance tool for bounty hunters written in Nim.

# Features
Current features (v0.2.0)-
- Subdomain enumeration (2 engines)
- Resolving A records
- Progress tracking

![](https://i.postimg.cc/zfrqLm1z/image.png)

- Resolving Virtual Host Names (using PTR records)
- Verbose output

![](https://i.postimg.cc/Fz878PkY/image.png)

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

# Known Bugs
For now, I have one known bug. In case the sites are too slow (as in doesn't respond within 20s), the program crashes with a timeout error-
```
net.nim(1475)            waitFor
Error: unhandled exception: Call to 'readLine' timed out. [TimeoutError]
```
This is not an expected behaviour since try-except blocks are used to handle this error. I am still trying to figure out the cause of this error.

# License
MIT License. See [LICENSE](LICENSE) for full text.