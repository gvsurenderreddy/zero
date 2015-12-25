# zero
[ZeroTier](https://www.zerotier.com/) is an awesome zero-configuration vpn that runs almost anywhere. But the default CLI doesn't make particulary easy to join a network unattended. Manual intervention can be combersome in a cluster environment were machine are added and removed dynamically. 

*Zero* presents the simple function of joining a Zerotier network without manual intervention. It does this by using the ZeroTier API:

```
usage: zero [-name] [-iface] [-install-dir] zt_net zt_token
```

The `zt_net` (network ID) and `zt_token` (API access token) can both be retrieved from the ZeroTier web interface. Typical usage looks like this:

```
zero -name=my-machine e6df831e1c561fff ZkJelfeQ1dd2ffff
```

## Installation
A 64-bit Linux binary is available on the releases page, for other platforms use `go get` to build from source:

```
go get -u github.com/microfactory/zero
```

NOTE: This requires you to install the Go SDK (>1.5.1)