# Domainim
A domain reconnaissance tool for bounty hunters written in Nim.

Current features (v0.1.0)-
- Subdomain enumeration
- Resolving A records
- Resolving Virtual Host Names

![v0.1.0](https://i.postimg.cc/rFFhvm5L/image.png)

## Table of Contents
- [Domainim](#domainim)
  - [Table of Contents](#table-of-contents)
- [Usage](#usage)
  - [Building from source](#building-from-source)
- [Contributing](#contributing)
  - [Planned features](#planned-features)
  - [Others](#others)
- [License](#license)

# Usage

Download the binary from the [release page](https://github.com/pptx704/domainim/releases).

```bash
./domainim <domain>
```

## Building from source
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

# Contributing
Contributions are welcome. Feel free to open a pull request or an issue.

## Planned features
- [ ] Open ports enumeration (v1.0.0)
- [ ] Give more control to the user by adding flags
- [ ] File output (probably CSV or JSON)
- [ ] Multiple domain enumeration
- [ ] Add more engines for subdomain enumeration
- [ ] Dir and File busting

## Others
- [ ] Update verbose output when encountering errors (v0.2.0)
- [ ] Add tests
- [ ] Add comments and docstrings

# License
MIT License. See [LICENSE](LICENSE) for full text.