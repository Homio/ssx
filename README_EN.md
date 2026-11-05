<div align="center">

# ⚡ ssx

**ssh, express.**

*One script + one YAML — passwordless SSH/SCP/SFTP with remote-path Tab completion, built for servers you only have a password for.*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#-contributing)

English | [简体中文](README.md)

</div>

---

## 🤔 Why ssx?

Cloud VMs, ancient routers, test boxes, bastion hosts — there's always a batch of machines that will only give you a password. Sound familiar?

- Too many servers — `ssh user@10.20.30.40 -p 2222 -i ~/.ssh/xxx` is impossible to remember;
- You'd love key-based auth, but some machines only give you a password;
- With `scp`, remote paths are guesswork: ssh in, look around, log out, try again;
- `~/.ssh/config` handles host aliases, but it **can't do password auth**, let alone remote-path completion.

**ssx fixes all of that in ~500 lines of bash:**

| Capability | `~/.ssh/config` | sshpass | ssx |
|---|:---:|:---:|:---:|
| Host aliases | ✅ | ❌ | ✅ |
| Password auto-login | ❌ | ✅ | ✅ |
| Remote-path Tab completion | ❌ | ❌ | ✅ |
| Config changes apply instantly | ❌ reconnect | — | ✅ save & go |
| One-command setup | — | — | ✅ |

**And all of it needs nothing but `bash + python3` — no compilers, no toolchains, drop in one file and go.**

> ### 🏂 Why the name ssx?
> It lives in the `ss` namespace, right next to `ssh` — type `ss` + Tab and they appear side by side. In standard touch-typing, `s`→`x` is the same finger rolling straight down: three letters, one finger. The x stands for e**X**press.
>
> It has nothing to do with EA's snowboarding game SSX — which actually makes it memorable: **not the snowboarding game, the magic word.**

## ✨ Features

- 🚀 **Single file, zero install dependencies** — just `ssx.sh`, runs anywhere
- 📦 **One YAML for all hosts** — alias, address, port, user, key/password at a glance
- 🔥 **Remote-path Tab completion** — `ssx host:/et<TAB>` expands to `/etc/`; no more probing
- ⚡ **Connection reuse (ControlMaster)** — first completion opens the tunnel, subsequent Tabs respond in **milliseconds** for 5 minutes
- 🔑 **Mixed auth per host** — key / password (via sshpass) / default key, independently per host
- 🔄 **Live config** — edit `~/.ssx.yaml`, save, done. No re-sourcing, no reconnecting
- 🧹 **Clean install & uninstall** — fully idempotent; `--purge` removes your config too
- 🛡️ **Non-invasive** — never touches `~/.ssh/config`; everything lives in `~/.local/bin`, `~/.ssx.yaml`, `~/.ssx_cm`

## 🥊 Why not hop / sshs / tssh?

There are great SSH tools out there — go try [hop](https://github.com/danmartuszewski/hop), its TUI and fuzzy matching are excellent. But nearly all of them start from the same assumption: **you have SSH keys.** ssx starts from the opposite corner: **a pile of password-only machines, and no desire to retrain your `ssh`/`scp` muscle memory.**

| | hop | tssh | sshs | ssx |
|---|:---:|:---:|:---:|:---:|
| Password login | ❌ | ✅ | ❌ | ✅ |
| Remote-path Tab completion for scp | ❌ | ❌ | ❌ | ✅ |
| Keeps native `ssh`/`scp` commands | ❌ new command | ❌ new command | ❌ | ✅ |
| TUI / fuzzy finder | ✅ | ❌ | ✅ | ❌ |
| Batch execution | ✅ | ❌ | ❌ | ❌ |

> **ssx is not a hop replacement.** Got keys and want a TUI with batch exec? Use hop — don't reinvent that wheel. Got a fleet of password-only boxes and just want `ssh`/`scp` to *work* with Tab completion? ssx is the missing piece.

## 📦 Installation

```bash
git clone https://github.com/Homio/ssx.git
cd ssx
bash ssx.sh install
source ~/.bashrc
```

That's it. The installer will:

1. Install the `ssx` command to `~/.local/bin/ssx`
2. Create the config template `~/.ssx.yaml` (mode 600)
3. Register Tab completion in `~/.bashrc`
4. Check for `sshpass` (needed for password auth) and tell you how to install it if missing

> **Already installed?** `bash ssx.sh sync` upgrades to the version in your current directory.

## ⚙️ Configuration

Edit `~/.ssx.yaml` (or just run `ssx edit`):

```yaml
hosts:

  # Key-based auth
  prod:
    addr: 203.0.113.10
    port: 22
    user: ubuntu
    key: ~/.ssh/id_ed25519

  # Password auth (requires sshpass)
  lab:
    addr: lab.example.com
    port: 2222
    user: root
    pass: "your-password"

  # No key/pass → default key ~/.ssh/id_rsa
  home:
    addr: home.example.com
    user: me
```

**Auth priority: `key` > `pass` > default key.** Field names are flexible: `addr`/`host`, `user`/`username`, `pass`/`password`, `key`/`ssh_key`.

> 💡 The config is **read fresh on every invocation**: add hosts, change ports, rotate passwords — save the file and your very next Tab already uses it. No restarts, nothing.

## 🚀 Usage

```bash
# Host-name completion, direct login
ssx prod

# Remote-path completion, download
ssx prod:/etc/nginx/nginx.conf .          # single file
ssx prod:/var/log/ ./logs/                # whole directory

# Upload (remote path completes too)
ssx app.tar.gz prod:/tmp/

# Too many hosts? List them
ssx list

# Edit config
ssx edit
```

**Tab completion in action:**

```text
$ ssx prod:<TAB>
prod:/bin/    prod:/etc/    prod:/home/   prod:/opt/    prod:/root/   prod:/usr/    ...

$ ssx prod:/et<TAB>
$ ssx prod:/etc/          ← one keystroke

$ ssx prod:/etc/ng<TAB>
$ ssx prod:/etc/nginx/    ← keep drilling down
```

> ⚡ The first completion pays for the SSH handshake (~1 s); after that, connections are reused for 5 minutes and completion feels instant.

## 🧰 Command Reference

| Command | Description |
|---|---|
| `ssx <host>` | Direct login |
| `ssx host:/path dest` | Download (`~` = remote home directory is supported) |
| `ssx localfile host:/path` | Upload (`~` = remote home directory is supported) |
| `ssx list` | List all hosts |
| `ssx edit` | Edit config |
| `ssx help` | Help |
| `bash ssx.sh install` | Install (re-run = upgrade) |
| `bash ssx.sh sync` | Upgrade (source dir only) |
| `bash ssx.sh uninstall [--purge]` | Uninstall (`--purge` removes config) |

> 📌 `install` / `uninstall` / `sync` are **source-directory operations only**. The installed `ssx` command does not expose them — no accidental uninstall over Tab completion.

## 🔒 Security Notes

- Config file is created with mode `600` (owner-only)
- In password mode the password goes through `sshpass` and never appears on your command line — though it *is* stored in plaintext in the YAML, so keep the machine trusted
- SSH multiplexing sockets live in `~/.ssx_cm/` (mode `700`) and expire after 5 minutes
- Never modifies `~/.ssh/config`; no credentials cached anywhere else

## ❓ FAQ

**Q: Completion doesn't work?**
Open a new terminal or run `source ~/.bashrc`. Completion is registered at source time.

**Q: First completion is slow?**
That's the initial SSH handshake. Subsequent completions ride the multiplexed connection at millisecond speed.

**Q: Completion doesn't show dotfiles (`.bashrc`, `.ssh/`, ...)?**
Same rule as local bash completion: type a `.` prefix before Tab (e.g. `ssx host:~/.<Tab>`) and they appear.

**Q: Does remote path support the home directory `~`?**
Yes. `ssx host:~/logs`, Tab completion on `ssx host:~/<Tab>`, and the `~user` form all work — for uploads and downloads too.

**Q: Can native `ssh` / `scp` use this config too?**
Add this line *above* the ssx source line in `~/.bashrc`:

```bash
export SSX_WRAP_NATIVE=1
```

Then `ssh prod` and `scp file prod:/tmp/` auto-login as well.

**Q: zsh / fish?**
bash only for now. zsh may work via `bashcompinit`, but it's not guaranteed.

## 🤝 Contributing

Issues and PRs welcome. Before submitting a PR:

- `bash -n ssx.sh` must pass
- New features must be verified against a real host (sandbox HOME + fake hosts don't count)

## 📄 License

[MIT](./LICENSE) © [Homio](https://github.com/Homio)

---

<div align="center">

**If ssx saved you some keystrokes, consider leaving a ⭐!**

</div>
