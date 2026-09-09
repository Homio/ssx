<div align="center">

# ⚡ ssx

**ssh, express.**

*一个脚本 + 一个 YAML —— SSH/SCP/SFTP 免密自动登录 + 远端路径 Tab 补全，为「只有密码」的服务器而生*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#-贡献)

简体中文 | [English](README_EN.md)

</div>

---

## 🤔 为什么是 ssx？

云主机、老路由器、测试机、堡垒机——总有一批机器只肯给你密码。你是不是也这样——

- 服务器越来越多，`ssh user@10.20.30.40 -p 2222 -i ~/.ssh/xxx` 记不住也敲不完；
- 想用 `ssh-copy-id` 免密，但总有几台机器只给密码；
- `scp` 传文件时，远端路径全靠猜、靠先 `ssh` 上去看一眼再退出来；
- `~/.ssh/config` 能配主机，但**密码认证帮不了你**，远端路径更是想都别想。

**ssx 用 500 行 bash 解决上面所有问题：**

| 能力 | `~/.ssh/config` | sshpass | ssx |
|---|:---:|:---:|:---:|
| 主机别名 | ✅ | ❌ | ✅ |
| 密码自动登录 | ❌ | ✅ | ✅ |
| 远端路径 Tab 补全 | ❌ | ❌ | ✅ |
| 改配置即时生效 | ❌ 需重连 | — | ✅ 保存即生效 |
| 安装部署 | — | — | ✅ 一条命令 |

**而这一切只需要 `bash + python3`——不编译、不要工具链、单文件扔进去就能跑。**

> ### 🏂 为什么叫 ssx？
> 它寄居在 `ss` 命名空间里，跟 `ssh` 并肩——敲 `ss` 按 Tab，它和 `ssh` 肩并肩出现；标准指法下 `s`→`x` 是同一根手指正下方，三个字母单指一滚就出来；x = e**X**press。
>
> 另外，它跟 EA 的滑雪游戏 SSX 没有任何关系——不过这样反而好记：**不是滑雪游戏，是开门咒语。**

## ✨ 特性

- 🚀 **单文件，零安装依赖** — 就一个 `ssx.sh`，扔到任何机器上都能跑
- 📦 **一个 YAML 管所有主机** — 别名、地址、端口、用户、密钥/密码，一目了然
- 🔥 **远端路径 Tab 补全** — `ssx 主机:/et<TAB>` 直接补出 `/etc/`，文件传输再也不用来回试探
- ⚡ **连接复用（ControlMaster）** — 第一次补全后连接保持 5 分钟，之后按 Tab **毫秒级响应**
- 🔑 **三种认证方式混用** — 密钥 / 密码（sshpass）/ 默认密钥，每台主机独立配置
- 🔄 **配置实时生效** — 改完 `~/.ssx.yaml` 保存即可，不用 source、不用重连
- 🧹 **干净安装卸载** — `install` / `uninstall` 全程幂等，卸载可以连配置一起清掉
- 🛡️ **不动你的环境** — 不改 `~/.ssh/config`，不碰系统文件，所有东西收在 `~/.local/bin`、`~/.ssx.yaml`、`~/.ssx_cm`

## 🥊 为什么不用 hop / sshs / tssh？

优秀的 SSH 工具很多——去试试 [hop](https://github.com/danmartuszewski/hop)，它的 TUI 和模糊搜索非常出色。但它们几乎都从同一个前提出发：**你有 SSH 密钥**。ssx 的出发点正相反：**手里一堆只有密码的机器，而且不想改 `ssh`/`scp` 的肌肉记忆。**

| | hop | tssh | sshs | ssx |
|---|:---:|:---:|:---:|:---:|
| 密码登录 | ❌ | ✅ | ❌ | ✅ |
| scp 远端路径 Tab 补全 | ❌ | ❌ | ❌ | ✅ |
| 保留原生 `ssh`/`scp` 命令 | ❌ 新命令 | ❌ 新命令 | ❌ | ✅ |
| TUI / 模糊搜索 | ✅ | ❌ | ✅ | ❌ |
| 多机批量执行 | ✅ | ❌ | ❌ | ❌ |

> **ssx 不是 hop 的替代品。** 你有密钥、想要 TUI 和批量执行——用 hop，别重复造轮子；你手里是一堆密码机，想让 `ssh`/`scp` 简单地「能用」且 Tab 得出路径——ssx 就是那块缺失的拼图。

## 📦 安装

```bash
git clone https://github.com/Homio/ssx.git
cd ssx
bash ssx.sh install
source ~/.bashrc
```

就这三步。安装器会：

1. 把 `ssx` 命令装到 `~/.local/bin/ssx`
2. 自动创建配置模板 `~/.ssx.yaml`（权限 600）
3. 在 `~/.bashrc` 里注册 Tab 补全
4. 检查 `sshpass`（密码登录需要），缺了会提示怎么装

> **已装过？** `bash ssx.sh sync` 一键升级到当前目录版本。

## ⚙️ 配置

编辑 `~/.ssx.yaml`（或直接 `ssx edit`）：

```yaml
hosts:

  # 密钥登录
  prod:
    addr: 203.0.113.10
    port: 22
    user: ubuntu
    key: ~/.ssh/id_ed25519

  # 密码登录（需要 sshpass）
  lab:
    addr: lab.example.com
    port: 2222
    user: root
    pass: "your-password"

  # 不填 key/pass → 用默认密钥 ~/.ssh/id_rsa
  home:
    addr: home.example.com
    user: me
```

**认证优先级：`key` > `pass` > 默认密钥。** 字段兼容 `addr`/`host`、`user`/`username`、`pass`/`password`、`key`/`ssh_key`，怎么顺手怎么写。

> 💡 配置是**每次执行时实时读取**的：加主机、改端口、换密码，保存退出后下一个 Tab 就生效，无需任何额外动作。

## 🚀 使用

```bash
# 主机名 Tab 补全，直连
ssx prod

# 远端路径 Tab 补全，下载
ssx prod:/etc/nginx/nginx.conf .          # 单文件
ssx prod:/var/log/ ./logs/                # 整个目录

# 上传（远端路径同样可以 Tab）
ssx app.tar.gz prod:/tmp/

# 主机多了记不住？列出所有
ssx list

# 改配置
ssx edit
```

**Tab 补全长这样：**

```text
$ ssx prod:<TAB>
prod:/bin/    prod:/etc/    prod:/home/   prod:/opt/    prod:/root/   prod:/usr/    ...

$ ssx prod:/et<TAB>
$ ssx prod:/etc/          ← 一击命中

$ ssx prod:/etc/ng<TAB>
$ ssx prod:/etc/nginx/    ← 目录内继续深入
```

> ⚡ 首次补全会建立 SSH 连接（约 1 秒）；之后 5 分钟内连接被复用，补全快到无感。

## 🧰 命令一览

| 命令 | 说明 |
|---|---|
| `ssx <主机>` | 直连 |
| `ssx 主机:/路径 目标` | 下载 |
| `ssx 本地文件 主机:/路径` | 上传 |
| `ssx list` | 列出所有主机 |
| `ssx edit` | 编辑配置 |
| `ssx help` | 帮助 |
| `bash ssx.sh install` | 安装（重复执行 = 升级） |
| `bash ssx.sh sync` | 升级（仅源码目录） |
| `bash ssx.sh uninstall [--purge]` | 卸载（`--purge` 连配置删） |

> 📌 `install` / `uninstall` / `sync` 是**源码目录专属操作**，安装后的 `ssx` 命令不提供这三个子命令，避免误触。

## 🔒 安全说明

- 配置文件权限自动设为 `600`，仅本人可读
- 密码模式下密码经 `sshpass` 传递，不会出现在命令行回显中；但明文存于 YAML，请确保机器本身可信
- SSH 连接复用的 socket 存放在 `~/.ssx_cm/`（权限 `700`），5 分钟后自动断开
- 不修改 `~/.ssh/config`、不缓存主机密码到任何其他位置

## ❓ FAQ

**Q: 补全没反应？**
新开一个终端，或执行 `source ~/.bashrc`。补全注册在 source 阶段完成。

**Q: 补全第一条特别慢？**
那是首次 SSH 握手，属正常现象；之后走连接复用，毫秒级。

**Q: 想让原生 `ssh` / `scp` 也吃这份配置？**
编辑 `~/.bashrc` 中 ssx 那行，在 source 之前加：

```bash
export SSX_WRAP_NATIVE=1
```

之后 `ssh prod`、`scp file prod:/tmp/` 也能自动登录。

**Q: 支持 zsh / fish 吗？**
目前仅支持 bash。zsh 可通过 `bashcompinit` 尝试兼容，但不保证。

## 🤝 贡献

Issue / PR 都欢迎。提 PR 前请确保：

- `bash -n ssx.sh` 语法检查通过
- 新功能在真实主机上验证过（沙箱 HOME + 假主机不算数）

## 📄 License

[MIT](./LICENSE) © [Homio](https://github.com/Homio)

---

<div align="center">

**如果 ssx 帮你省下了敲命令的时间，点个 ⭐ 再走吧！**

</div>
