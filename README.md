# Mihomo Proxy 一键部署包

## 系统要求

| 项目 | 要求 |
|------|------|
| **操作系统** | Linux (测试于 Ubuntu 20.04/22.04/24.04) |
| **Shell** | zsh |
| **架构** | x86_64 (amd64) / aarch64 (arm64) |

### 依赖

安装前请确保系统已安装：

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y zsh curl jq python3 python3-yaml

# 切换到 zsh（如尚未使用）
chsh -s $(which zsh)
```

| 依赖 | 用途 |
|------|------|
| `zsh` | Shell 环境 |
| `curl` | API 请求 / 下载 |
| `jq` | JSON 解析 |
| `python3` + `pyyaml` | 解析 mihomo 配置文件 |

---

## 快速使用

### 1. 克隆或上传

```bash
# 方式一：克隆仓库
git clone https://github.com/Doctorluka/mihomo-deploy.git
cd mihomo-deploy

# 方式二：上传压缩包
tar -xzvf mihomo-deploy.tar.gz
cd mihomo-deploy
```

### 2. 安装

```bash
# 指定你的配置文件
./install.sh -c /path/to/your/config.yaml
```

### 3. 启动

```bash
source ~/.zshrc
mihomo-start
proxy-select us
```

---

## 命令选项

```
用法: ./install.sh [选项]

选项:
  -c, --config <file>     mihomo 配置文件路径（必需）
  -b, --binary <file>     mihomo 二进制文件路径（可选，自动下载）
  -p, --port <port>       代理端口（默认: 7899）
  -a, --api-port <port>   API 端口（默认: 9090）
  -u, --uninstall         卸载
  -h, --help              显示帮助
```

---

## 示例

```bash
# 基本安装（自动下载 mihomo）
./install.sh -c ~/my-config.yaml

# 使用本地二进制文件
./install.sh -c ~/my-config.yaml -b ~/mihomo-linux-amd64

# 自定义端口
./install.sh -c ~/my-config.yaml -p 7890 -a 9091

# 卸载
./install.sh -u
```

---

## 安装后命令

| 命令 | 说明 |
|------|------|
| `mihomo-start` | 启动（自动启用代理） |
| `mihomo-stop` | 停止（自动关闭代理） |
| `proxy-select <代码>` | 切换节点 |
| `proxy-current` | 查看当前节点 |
| `proxy-list` | 列出所有节点 |
| `proxy-on` | 启用代理 |
| `proxy-off` | 关闭代理 |

---

## 文件结构

```
mihomo-deploy/
├── install.sh              # 安装脚本
├── README.md               # 本文件
└── functions/
    ├── proxy-select        # 节点选择
    ├── proxy-current       # 查看当前
    ├── proxy-list          # 列出节点
    ├── proxy-auto          # 自动模式
    ├── mihomo-start        # 启动
    ├── mihomo-stop         # 停止
    └── mihomo-common.zsh   # 共享模块
```

---

## 安装位置

所有文件安装到用户目录，无 root 权限要求：

| 文件 | 位置 |
|------|------|
| mihomo 二进制 | `~/.local/bin/mihomo` |
| 配置文件 | `~/.config/mihomo/config.yaml` |
| 函数文件 | `~/.config/zsh/functions/` |
| 日志 | `~/.mihomo.log` |

---

## 配置文件要求

你的 mihomo 配置文件需要包含：

```yaml
# 示例配置结构
mixed-port: 7899
external-controller: 127.0.0.1:9090

proxies:
  - name: "🇺🇸 US Node"
    type: ss
    server: xxx
    # ...

proxy-groups:
  - name: "Auto"
    type: url-test
    proxies:
      - "🇺🇸 US Node"
    url: 'http://www.gstatic.com/generate_204'
    interval: 300
```

**重要：** 代理组名称需要包含可识别的国旗 emoji 或国家名称：
- 🇺🇸, 🇯🇵, 🇭🇰, 🇸🇬, 🇰🇷, 🇹🇼, 🇬🇧, 🇩🇪, 🇫🇷, 🇦🇺, 🇨🇦
- 或文字：美国, 日本, 香港, 新加坡, 韩国, 台湾, 英国, 德国, 法国, 澳大利亚, 加拿大

---

## 卸载

```bash
./install.sh -u
```

会自动备份配置到 `~/.config/mihomo-backup-时间戳/`

---

## 故障排除

### `command not found: proxy-select`

```bash
source ~/.zshrc
```

### `python3: No module named 'yaml'`

```bash
sudo apt install python3-yaml
# 或
pip3 install pyyaml
```

### 下载 mihomo 失败

手动下载后使用 `-b` 参数：
```bash
# 从 https://github.com/MetaCubeX/mihomo/releases 下载
./install.sh -c config.yaml -b ./mihomo-linux-amd64
```

---

**Tested on:** Ubuntu 20.04/22.04/24.04
**Created:** 2026-03-25
