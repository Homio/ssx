#!/bin/bash
#==============================================================================
# ssx.sh — 一个脚本 + 一个 YAML 配置，搞定 SSH/SCP 自动登录 + Tab 补全
#
# 安装:   bash ssx.sh install    （幂等，重复执行即升级到本目录版本）
# 升级:   bash ssx.sh sync       （把当前目录版本覆盖到已安装的 ssx）
# 卸载:   bash ssx.sh uninstall [--purge]
#
# install/uninstall 是源码目录操作，仅支持以 bash ssx.sh / ./ssx.sh 方式执行；
# 安装后的 ssx 命令不提供这两个子命令（提示和补全里都不会出现）。
#==============================================================================

SSX_CONF="${SSX_CONF:-$HOME/.ssx.yaml}"
SSX_BIN="$HOME/.local/bin/ssx"
SSX_SELF="${BASH_SOURCE[0]:-$0}"
SSX_SCRIPT="$(cd "$(dirname "$SSX_SELF")" 2>/dev/null && pwd)/$(basename "$SSX_SELF")"
SSX_DIR="$(dirname "$SSX_SCRIPT")"

(return 0 2>/dev/null) && _SSX_SOURCED=1 || _SSX_SOURCED=0

#==============================================================================
# Python 配置引擎（内嵌，零外部依赖，优先 PyYAML）
#==============================================================================
_ssx_py() {
    SSX_CONF="$SSX_CONF" python3 - "$@" << 'PYEOF'
import sys, os, json

def parse_yaml(text):
    result = {}
    stack = [(0, result)]
    for line in text.split('\n'):
        buf = []
        in_q = False; qc = None
        for c in line:
            if c in '"\'':
                if not in_q: in_q = True; qc = c
                elif c == qc: in_q = False
            elif c == '#' and not in_q:
                break
            buf.append(c)
        line = ''.join(buf)
        stripped = line.strip()
        if not stripped:
            continue
        indent = len(line) - len(line.lstrip())
        while len(stack) > 1 and stack[-1][0] >= indent:
            stack.pop()
        content = stripped
        if content.endswith(':') and ' ' not in content.rstrip(':'):
            key = content[:-1].strip()
            if key and key[0] in '"\'' and key[-1] == key[0]:
                key = key[1:-1]
            new_dict = {}
            stack[-1][1][key] = new_dict
            stack.append((indent, new_dict))
        elif ':' in content:
            key, _, val = content.partition(':')
            key = key.strip()
            val = val.strip()
            if val and val[0] in '"\'' and val[-1] == val[0]:
                val = val[1:-1]
            if key and key[0] in '"\'' and key[-1] == key[0]:
                key = key[1:-1]
            stack[-1][1][key] = val
    return result

def load_hosts():
    conf = os.environ.get('SSX_CONF', os.path.expanduser('~/.ssx.yaml'))
    if not os.path.exists(conf):
        return {}
    with open(conf) as f:
        text = f.read()
    try:
        import yaml
        data = yaml.safe_load(text) or {}
    except ImportError:
        data = parse_yaml(text)
    if isinstance(data, dict):
        if 'hosts' in data and isinstance(data['hosts'], dict):
            return data['hosts']
        return data
    return {}

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    hosts = load_hosts()

    if cmd == 'list_hosts':
        for name in sorted(hosts.keys()):
            print(name)
    elif cmd == 'host_exists':
        sys.exit(0 if sys.argv[2] in hosts else 1)
    elif cmd == 'get_auth':
        name = sys.argv[2]
        if name not in hosts:
            sys.exit(1)
        h = hosts[name]
        if not isinstance(h, dict):
            sys.exit(1)
        addr  = h.get('addr', h.get('address', h.get('host', '')))
        port  = str(h.get('port', '22'))
        user  = h.get('user', h.get('username', ''))
        key   = h.get('key', h.get('ssh_key', ''))
        passw = h.get('pass', h.get('password', ''))
        atype = 'none'; aval = ''
        if key:
            atype = 'key'; aval = os.path.expanduser(key)
        elif passw:
            atype = 'pass'; aval = passw
        print(f"{atype}|{aval}|{port}|{user}|{addr}")
    elif cmd == 'list_all':
        for name, h in hosts.items():
            if not isinstance(h, dict):
                continue
            addr  = h.get('addr', h.get('address', ''))
            port  = str(h.get('port', '22'))
            user  = h.get('user', h.get('username', ''))
            key   = h.get('key', h.get('ssh_key', ''))
            passw = h.get('pass', h.get('password', ''))
            if key:     auth = f"key: {key}"
            elif passw: auth = "password"
            else:       auth = "default-key"
            print(f"{name}|{addr}|{port}|{user}|{auth}")
    else:
        print(f"unknown: {cmd}", file=sys.stderr)
        sys.exit(1)

main()
PYEOF
}

_ssx_host_exists() { _ssx_py host_exists "$1" 2>/dev/null; }
_ssx_auth()        { _ssx_py get_auth "$1" 2>/dev/null; }

#==============================================================================
# bashrc 清理辅助（install/uninstall 共用，幂等）
#==============================================================================
_ssx_clean_bashrc() {
    local brc="$HOME/.bashrc"
    [[ -f "$brc" ]] || return 0
    local tmpf
    tmpf="$(mktemp)"
    grep -vF 'source "$HOME/.local/bin/ssx"' "$brc" \
        | grep -vF '# ssx — SSH/SCP helper with tab completion' \
        | grep -vF 'source ""' \
        | grep -v 'source ".*/ssx\.sh"' \
        > "$tmpf"
    mv "$tmpf" "$brc"
}

#==============================================================================
# 直接执行模式
#==============================================================================
if [[ "$_SSX_SOURCED" == "0" ]]; then

case "${1:-}" in

__complete_hosts)
    _ssx_py list_hosts 2>/dev/null
    ;;

__complete_remote_path)
    hostname="$2"; rpath="$3"
    if [[ -z "$rpath" || "$rpath" == "/" ]]; then
        dir="/"; prefix=""
    elif [[ "$rpath" == */ ]]; then
        dir="$rpath"; prefix=""
    elif [[ "$rpath" == */* ]]; then
        dir="${rpath%/*}"
        if [[ -z "$dir" ]]; then dir="/"; else dir="$dir/"; fi
        prefix="${rpath##*/}"
    else
        # 顶层前缀（如 host:et），应列出根目录下匹配项，而不是查 /et/
        dir="/"; prefix="$rpath"
    fi
    authinfo=$(_ssx_auth "$hostname") || exit 0
    IFS='|' read -r atype avalue port user addr <<< "$authinfo"
    [[ -z "$user" || -z "$addr" ]] && exit 0
    
    # ⚠ 开启 SSH 多路复用，后续 Tab 连接秒建，解决迟钝问题
    # 注意：此分支位于脚本顶层而非函数内，不能用 local
    cm_dir="$HOME/.ssx_cm"
    mkdir -p -m 700 "$cm_dir" 2>/dev/null
    ssh_base="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o LogLevel=ERROR"
    ssh_base="$ssh_base -o ControlMaster=auto -o ControlPath=$cm_dir/%r@%h:%p -o ControlPersist=300"
    [[ -n "$port" && "$port" != "22" ]] && ssh_base="$ssh_base -p $port"
    
    case "$atype" in
        key)  listing=$(command ssh $ssh_base -i "$avalue" "${user}@${addr}" \
                        "command ls -1p '${dir}' 2>/dev/null" 2>/dev/null < /dev/null) ;;
        pass) listing=$(sshpass -p "$avalue" command ssh $ssh_base "${user}@${addr}" \
                        "command ls -1p '${dir}' 2>/dev/null" 2>/dev/null < /dev/null) ;;
        *)    listing=$(command ssh $ssh_base "${user}@${addr}" \
                        "command ls -1p '${dir}' 2>/dev/null" 2>/dev/null < /dev/null) ;;
    esac
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        if [[ -z "$prefix" ]] || [[ "$item" == "$prefix"* ]]; then
            echo "${hostname}:${dir}${item}"
        fi
    done <<< "$listing"
    ;;

__ssh)
    hostname="$2"; shift 2
    if authinfo=$(_ssx_auth "$hostname"); then
        IFS='|' read -r atype avalue port user addr <<< "$authinfo"
        ssh_base="-o StrictHostKeyChecking=no"
        [[ -n "$port" && "$port" != "22" ]] && ssh_base="$ssh_base -p $port"
        case "$atype" in
            key)  command ssh $ssh_base -i "$avalue" "${user}@${addr}" "$@" ;;
            pass) sshpass -p "$avalue" command ssh $ssh_base "${user}@${addr}" "$@" ;;
            *)    command ssh $ssh_base "${user}@${addr}" "$@" ;;
        esac
    else
        command ssh "$hostname" "$@"
    fi
    ;;

__scp)
    shift
    scp_args=(); found=0; authinfo=""
    for arg in "$@"; do
        if [[ "$arg" == *:* ]]; then
            phost="${arg%%:*}"; ppath="${arg#*:}"
            if _ssx_host_exists "$phost"; then
                [[ "$found" == "0" ]] && { authinfo=$(_ssx_auth "$phost"); found=1; }
                IFS='|' read -r _ _ _ user addr <<< "$authinfo"
                scp_args+=("${user}@${addr}:${ppath}")
                continue
            fi
        fi
        scp_args+=("$arg")
    done
    if [[ "$found" == "0" ]]; then
        command scp "$@"; exit $?
    fi
    IFS='|' read -r atype avalue port user addr <<< "$authinfo"
    scp_opts="-o StrictHostKeyChecking=no"
    [[ -n "$port" && "$port" != "22" ]] && scp_opts="$scp_opts -P $port"
    case "$atype" in
        key)  command scp $scp_opts -i "$avalue" "${scp_args[@]}" ;;
        pass) sshpass -p "$avalue" command scp $scp_opts "${scp_args[@]}" ;;
        *)    command scp $scp_opts "${scp_args[@]}" ;;
    esac
    ;;

__sftp)
    hostname="$2"; shift 2
    if authinfo=$(_ssx_auth "$hostname"); then
        IFS='|' read -r atype avalue port user addr <<< "$authinfo"
        sftp_base="-o StrictHostKeyChecking=no"
        [[ -n "$port" && "$port" != "22" ]] && sftp_base="$sftp_base -P $port"
        case "$atype" in
            key)  command sftp $sftp_base -i "$avalue" "${user}@${addr}" "$@" ;;
            pass) sshpass -p "$avalue" command sftp $sftp_base "${user}@${addr}" "$@" ;;
            *)    command sftp $sftp_base "${user}@${addr}" "$@" ;;
        esac
    else
        command sftp "$hostname" "$@"
    fi
    ;;

__list)
    echo -e "\033[1mConfigured hosts\033[0m ($SSX_CONF):"
    echo "----------------------------------------------------------"
    printf "%-16s %-26s %-6s %-12s %s\n" "ALIAS" "ADDRESS" "PORT" "USER" "AUTH"
    echo "----------------------------------------------------------"
    while IFS='|' read -r name addr port user auth; do
        printf "%-16s %-26s %-6s %-12s %s\n" "$name" "$addr" "$port" "$user" "$auth"
    done < <(_ssx_py list_all 2>/dev/null)
    ;;

__edit)
    "${EDITOR:-vi}" "$SSX_CONF"
    ;;

sync|__sync)
    # 只允许源码方式（bash ssx.sh / ./ssx.sh）；安装后的 ssx 命令一律拒绝
    if [[ "$SSX_SCRIPT" -ef "$SSX_BIN" ]]; then
        echo "✗ 安装后的 ssx 命令不提供 sync，请在源码目录执行: bash ssx.sh sync"
        exit 1
    fi
    cp "$SSX_SCRIPT" "$SSX_BIN" && chmod +x "$SSX_BIN"
    echo "✓ 已升级: $SSX_SCRIPT → $SSX_BIN"
    ;;

install|__install)
    # 只允许源码方式（bash ssx.sh / ./ssx.sh）；安装后的 ssx 命令一律拒绝
    if [[ "$SSX_SCRIPT" -ef "$SSX_BIN" ]]; then
        echo "✗ 安装后的 ssx 命令不提供 install，请在源码目录执行: bash ssx.sh install"
        exit 1
    fi
    _ssx_clean_bashrc

    mkdir -p "$(dirname "$SSX_BIN")"
    if [[ "$SSX_SCRIPT" -ef "$SSX_BIN" ]]; then
        echo "→ 命令已就位: $SSX_BIN"
    else
        cp "$SSX_SCRIPT" "$SSX_BIN"
        chmod +x "$SSX_BIN"
        echo "✓ 命令已安装: $SSX_BIN"
    fi

    brc="$HOME/.bashrc"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *)
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$brc"
            echo "✓ 已将 ~/.local/bin 加入 PATH"
            ;;
    esac

    if [[ -f "$SSX_DIR/config.example.yaml" && ! -f "$SSX_CONF" ]]; then
        cp "$SSX_DIR/config.example.yaml" "$SSX_CONF"
        chmod 600 "$SSX_CONF"
        echo "✓ 配置文件已从模板复制: $SSX_CONF"
    elif [[ ! -f "$SSX_CONF" ]]; then
        cat > "$SSX_CONF" << 'YAMLTEMPLATE'
# ssx 配置文件
#
# key:   密钥路径（~ 自动展开）
# pass:  密码（需安装 sshpass）
# 都不填: 使用默认 SSH 密钥 (~/.ssh/id_rsa)
# 认证优先级: key > pass > 默认密钥

hosts:

  # 示例 1: 密钥登录
  my-server:
    addr: example.com
    port: 22
    user: your-username
    key: ~/.ssh/id_rsa

  # 示例 2: 密码登录（需安装 sshpass）
  my-server2:
    addr: 203.0.113.10
    port: 22
    user: your-username
    pass: your-password-here

  # 示例 3: 不填 key/pass → 使用默认密钥 ~/.ssh/id_rsa
  # my-server3:
  #   addr: 198.51.100.20
  #   port: 22
  #   user: your-username
YAMLTEMPLATE
        chmod 600 "$SSX_CONF"
        echo "✓ 已创建配置模板: $SSX_CONF"
    else
        echo "→ 配置文件已存在: $SSX_CONF"
    fi
    echo "  请编辑并填入真实主机信息: ssx edit"

    if ! grep -qF 'source "$HOME/.local/bin/ssx"' "$brc" 2>/dev/null; then
        printf '\n# ssx — SSH/SCP helper with tab completion\nsource "$HOME/.local/bin/ssx"\n' >> "$brc"
        echo "✓ 已添加到 $brc"
    else
        echo "→ $brc 中已存在 source 行"
    fi

    if ! command -v sshpass &>/dev/null; then
        echo ""
        echo "⚠ 未找到 sshpass（密码登录时需要）:"
        echo "  Ubuntu/Debian: sudo apt install sshpass"
        echo "  macOS:         brew install hudochenkov/sshpass/sshpass"
        echo "  CentOS/RHEL:   sudo yum install sshpass"
    fi

    echo ""
    echo "✓ 安装完成！请运行: source ~/.bashrc"
    ;;

uninstall|__uninstall)
    # 只允许源码方式（bash ssx.sh / ./ssx.sh）；安装后的 ssx 命令一律拒绝
    if [[ "$SSX_SCRIPT" -ef "$SSX_BIN" ]]; then
        echo "✗ 安装后的 ssx 命令不提供 uninstall，请在源码目录执行: bash ssx.sh uninstall"
        exit 1
    fi
    purge=0
    for arg in "$@"; do
        [[ "$arg" == "--purge" || "$arg" == "-p" ]] && purge=1
    done

    _ssx_clean_bashrc
    echo "✓ 已从 ~/.bashrc 清除 ssx 相关行"

    if [[ -f "$SSX_BIN" ]]; then
        rm -f "$SSX_BIN"
        echo "✓ 已删除命令: $SSX_BIN"
    else
        echo "→ 命令本体不存在: $SSX_BIN"
    fi

    if [[ "$purge" == "1" ]]; then
        rm -f "$SSX_CONF"
        echo "✓ 已删除配置: $SSX_CONF"
    elif [[ -f "$SSX_CONF" ]]; then
        echo "→ 配置文件已保留: $SSX_CONF （连同删除请加 --purge）"
    else
        echo "→ 配置文件不存在: $SSX_CONF"
    fi

    echo ""
    echo "✓ 卸载完成！当前 shell 请执行:"
    echo "  unset -f ssx 2>/dev/null; complete -r ssx 2>/dev/null"
    ;;

*)
    cat << 'HELP'
ssx — 一个脚本 + 一个 YAML 配置，搞定 SSH/SCP

配置文件: ~/.ssx.yaml (YAML)  (配置是实时读取的，改完立即生效)
依赖:     python3（配置解析）、sshpass（密码登录）

用法:
  ssx <别名>                 # Tab 补全主机名，直连
  ssx <别名>:/path  dest     # Tab 补全远端路径，下载
  ssx src <别名>:/path       # Tab 补全远端路径，上传
  ssx list                   # 列出所有主机
  ssx edit                   # 编辑配置

安装/升级/卸载（仅限源码目录，安装后的 ssx 命令不提供）:
  bash ssx.sh install              # 首次安装；重复执行即升级到当前目录版本
  bash ssx.sh sync                 # 升级：把当前目录版本覆盖到已安装的 ssx
  bash ssx.sh uninstall [--purge]  # 卸载（--purge 连配置一起删）
HELP
    ;;
esac
exit 0
fi

#==============================================================================
# source 模式 — 注册 ssx 主命令 + Tab 补全
#==============================================================================

# 关键修复：把冒号从 COMP_WORDBREAKS 移除
COMP_WORDBREAKS="${COMP_WORDBREAKS//:/}"

# ⚡ 优化体验：按一下 Tab 如果有多个匹配，直接立刻列出，不再需要等1秒或按第二下
bind 'set show-all-if-ambiguous on' 2>/dev/null

ssx() {
    case "${1:-}" in
        edit)
            "${EDITOR:-vi}" "$SSX_CONF"
            ;;
        list)
            "$SSX_SCRIPT" "__$1" "${@:2}"
            ;;
        help|-h|--help)
            # 无参执行脚本 → 打印完整帮助（帮助文本只维护在直接执行模式的 * 分支）
            "$SSX_SCRIPT"
            ;;
        "")
            echo "usage: ssx <host> | ssx host:/path . | ssx list | ssx help"
            ;;
        *)
            local has_remote=0 arg
            for arg in "$@"; do
                if [[ "$arg" == *:* ]] && _ssx_host_exists "${arg%%:*}"; then
                    has_remote=1; break
                fi
            done
            if [[ "$has_remote" == "1" ]]; then
                "$SSX_SCRIPT" __scp "$@"
            else
                "$SSX_SCRIPT" __ssh "$@"
            fi
            ;;
    esac
}

_ssx_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"

    if [[ "$cur" == *:* ]]; then
        local hostname="${cur%%:*}"
        local rpath="${cur#*:}"
        if _ssx_host_exists "$hostname"; then
            if [[ -z "$rpath" ]]; then
                COMPREPLY=("${hostname}:/")
                return 0
            fi
            local listing
            listing=$("$SSX_SCRIPT" __complete_remote_path "$hostname" "$rpath" 2>/dev/null)
            if [[ -n "$listing" ]]; then
                # 服务端已按用户输入的前缀过滤，这里逐行透传即可；
                # 不能用整词 compgen —— 顶层前缀(e)与结果(/etc/)文本上不构成前缀关系
                local item
                COMPREPLY=()
                while IFS= read -r item; do
                    [[ -n "$item" ]] && COMPREPLY+=("$item")
                done <<< "$listing"
            else
                compopt +o default +o bashdefault 2>/dev/null
                COMPREPLY=()
            fi
        else
            compopt +o default +o bashdefault 2>/dev/null
            COMPREPLY=()
        fi
        return 0
    fi

    if [[ "$COMP_CWORD" -eq 1 ]]; then
        local subcmds="list edit help"
        local hosts host_list=""
        hosts=$("$SSX_SCRIPT" __complete_hosts 2>/dev/null)
        while IFS= read -r h; do
            [[ -n "$h" ]] && host_list+=" ${h}"
        done <<< "$hosts"
        COMPREPLY=($(compgen -W "$subcmds $host_list" -- "$cur"))
        return 0
    fi

    COMPREPLY=($(compgen -f -- "$cur"))
    return 0
}
complete -o filenames -o nospace -F _ssx_complete ssx

if [[ "${SSX_WRAP_NATIVE:-0}" == "1" ]]; then
    ssh()  { "$SSX_SCRIPT" __ssh "$@"; }
    scp()  { "$SSX_SCRIPT" __scp "$@"; }
    sftp() { "$SSX_SCRIPT" __sftp "$@"; }

    _ssx_complete_ssh() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        if [[ "$COMP_CWORD" -eq 1 ]]; then
            local hosts
            hosts=$("$SSX_SCRIPT" __complete_hosts 2>/dev/null)
            COMPREPLY=($(compgen -W "$hosts" -- "$cur"))
        else
            COMPREPLY=()
        fi
    }
    _ssx_complete_scp() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        if [[ "$cur" == *:* ]]; then
            local hostname="${cur%%:*}" rpath="${cur#*:}"
            if _ssx_host_exists "$hostname"; then
                if [[ -z "$rpath" ]]; then
                    COMPREPLY=("${hostname}:/")
                    return 0
                fi
                local listing
                listing=$("$SSX_SCRIPT" __complete_remote_path "$hostname" "$rpath" 2>/dev/null)
                if [[ -n "$listing" ]]; then
                    local item
                    COMPREPLY=()
                    while IFS= read -r item; do
                        [[ -n "$item" ]] && COMPREPLY+=("$item")
                    done <<< "$listing"
                    return 0
                fi
            fi
            compopt +o default +o bashdefault 2>/dev/null
            COMPREPLY=(); return 0
        fi
        local hosts host_list=""
        hosts=$("$SSX_SCRIPT" __complete_hosts 2>/dev/null)
        while IFS= read -r h; do
            [[ -n "$h" ]] && host_list+=" ${h}"
        done <<< "$hosts"
        COMPREPLY=($(compgen -W "$host_list" -- "$cur"))
        local local_files
        local_files=$(compgen -f -- "$cur" 2>/dev/null)
        [[ -n "$local_files" ]] && COMPREPLY+=($local_files)
    }
    complete -o filenames -o nospace -F _ssx_complete_ssh ssh
    complete -o filenames -o nospace -F _ssx_complete_scp scp
    complete -o filenames -o nospace -F _ssx_complete_ssh sftp
fi

_n=$("$SSX_SCRIPT" __complete_hosts 2>/dev/null | wc -l | tr -d ' ')
echo "[ssx] 已加载 | 主机数: ${_n} | 配置: ${SSX_CONF}"

