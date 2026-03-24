#!/bin/bash
#
# Mihomo Proxy 一键部署脚本
# 用法: ./install.sh [选项]
#
# 选项:
#   -c, --config <file>   指定 mihomo 配置文件路径（必需）
#   -b, --binary <file>   指定 mihomo 二进制文件路径（可选，默认下载）
#   -p, --port <port>     指定代理端口（默认 7899）
#   -a, --api-port <port> 指定 API 端口（默认 9090）
#   -u, --uninstall       卸载
#   -h, --help            显示帮助
#

set -e

# ==================== 配置 ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local"
CONFIG_DIR="$HOME/.config/mihomo"
ZSHRC="$HOME/.zshrc"
BACKUP_DIR="$HOME/.config/mihomo-backup-$(date +%Y%m%d_%H%M%S)"

# 默认值
PROXY_PORT=7899
API_PORT=9090
MIHOMO_BINARY=""

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ==================== 帮助信息 ====================
show_help() {
    cat << EOF
Mihomo Proxy 一键部署脚本

用法: $0 [选项]

选项:
  -c, --config <file>     mihomo 配置文件路径（必需）
  -b, --binary <file>     mihomo 二进制文件路径（可选，如未指定则自动下载）
  -p, --port <port>       代理端口（默认: 7899）
  -a, --api-port <port>   API 端口（默认: 9090）
  -u, --uninstall         卸载 mihomo-proxy
  -h, --help              显示此帮助信息

示例:
  # 使用本地配置文件安装
  $0 -c /path/to/config.yaml

  # 使用本地配置和二进制文件安装
  $0 -c /path/to/config.yaml -b /path/to/mihomo

  # 使用自定义端口
  $0 -c /path/to/config.yaml -p 7890 -a 9091

  # 卸载
  $0 -u

EOF
    exit 0
}

# ==================== 参数解析 ====================
CONFIG_FILE=""
UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -b|--binary)
            MIHOMO_BINARY="$2"
            shift 2
            ;;
        -p|--port)
            PROXY_PORT="$2"
            shift 2
            ;;
        -a|--api-port)
            API_PORT="$2"
            shift 2
            ;;
        -u|--uninstall)
            UNINSTALL=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            error "未知选项: $1\n使用 -h 查看帮助"
            ;;
    esac
done

# ==================== 卸载功能 ====================
if $UNINSTALL; then
    info "开始卸载 mihomo-proxy..."

    # 停止服务
    if pgrep -u "$USER" -x "mihomo" > /dev/null; then
        info "停止 mihomo 进程..."
        pkill -u "$USER" -x "mihomo" || true
    fi

    # 备份配置
    if [[ -d "$CONFIG_DIR" ]]; then
        info "备份配置到 $BACKUP_DIR..."
        mv "$CONFIG_DIR" "$BACKUP_DIR"
    fi

    # 删除二进制
    if [[ -f "$INSTALL_DIR/bin/mihomo" ]]; then
        rm -f "$INSTALL_DIR/bin/mihomo"
    fi

    # 删除函数文件
    rm -f "$HOME/.config/zsh/functions/proxy-select"
    rm -f "$HOME/.config/zsh/functions/proxy-current"
    rm -f "$HOME/.config/zsh/functions/proxy-list"
    rm -f "$HOME/.config/zsh/functions/proxy-auto"
    rm -f "$HOME/.config/zsh/functions/mihomo-start"
    rm -f "$HOME/.config/zsh/functions/mihomo-stop"
    rm -rf "$HOME/.config/zsh/functions/mihomo"

    # 从 .zshrc 移除配置
    if [[ -f "$ZSHRC" ]]; then
        info "从 .zshrc 移除配置..."
        sed -i '/# >>> mihomo proxy initialize >>>/,/# <<< mihomo proxy initialize <<</d' "$ZSHRC"
    fi

    success "卸载完成！"
    echo ""
    echo "  配置已备份到: $BACKUP_DIR"
    echo "  请执行: source ~/.zshrc"
    exit 0
fi

# ==================== 安装前检查 ====================
if [[ -z "$CONFIG_FILE" ]]; then
    error "必须指定配置文件！使用 -c <file> 或 --config <file>"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    error "配置文件不存在: $CONFIG_FILE"
fi

if ! command -v zsh &> /dev/null; then
    error "未安装 zsh，请先安装 zsh"
fi

if ! command -v curl &> /dev/null; then
    error "未安装 curl，请先安装 curl"
fi

# ==================== 安装函数 ====================
install_binary() {
    info "安装 mihomo 二进制文件..."

    if [[ -n "$MIHOMO_BINARY" ]]; then
        # 使用用户指定的二进制文件
        if [[ ! -f "$MIHOMO_BINARY" ]]; then
            error "二进制文件不存在: $MIHOMO_BINARY"
        fi
        cp "$MIHOMO_BINARY" "$INSTALL_DIR/bin/mihomo"
        chmod +x "$INSTALL_DIR/bin/mihomo"
    else
        # 自动下载最新版本
        info "正在下载 mihomo..."
        local arch=$(uname -m)
        case $arch in
            x86_64) arch="amd64" ;;
            aarch64) arch="arm64" ;;
            *) error "不支持的架构: $arch" ;;
        esac

        local download_url="https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-${arch}.gz"
        local tmp_file="/tmp/mihomo-${arch}.gz"

        curl -L -o "$tmp_file" "$download_url" || error "下载失败"
        gunzip -c "$tmp_file" > "$INSTALL_DIR/bin/mihomo"
        chmod +x "$INSTALL_DIR/bin/mihomo"
        rm -f "$tmp_file"
    fi

    success "二进制文件已安装到 $INSTALL_DIR/bin/mihomo"
}

install_config() {
    info "安装配置文件..."

    mkdir -p "$CONFIG_DIR"
    cp "$CONFIG_FILE" "$CONFIG_DIR/config.yaml"

    success "配置文件已安装到 $CONFIG_DIR/config.yaml"
}

install_functions() {
    info "安装 shell 函数..."

    local func_dir="$HOME/.config/zsh/functions"
    mkdir -p "$func_dir/mihomo"

    # 复制函数文件
    cp "$SCRIPT_DIR/functions/proxy-select" "$func_dir/"
    cp "$SCRIPT_DIR/functions/proxy-current" "$func_dir/"
    cp "$SCRIPT_DIR/functions/proxy-list" "$func_dir/"
    cp "$SCRIPT_DIR/functions/proxy-auto" "$func_dir/"
    cp "$SCRIPT_DIR/functions/mihomo-start" "$func_dir/"
    cp "$SCRIPT_DIR/functions/mihomo-stop" "$func_dir/"
    cp "$SCRIPT_DIR/functions/mihomo-common.zsh" "$func_dir/mihomo/"

    # 替换端口配置
    sed -i "s/MIHOMO_API_BASE=\"http:\/\/127.0.0.1:9090\"/MIHOMO_API_BASE=\"http:\/\/127.0.0.1:${API_PORT}\"/g" \
        "$func_dir/mihomo/mihomo-common.zsh"

    sed -i "s/:7899/:${PROXY_PORT}/g" "$ZSHRC" 2>/dev/null || true

    success "函数文件已安装"
}

install_zshrc() {
    info "配置 .zshrc..."

    # 检查是否已安装
    if grep -q "# >>> mihomo proxy initialize >>>" "$ZSHRC" 2>/dev/null; then
        warn "检测到已安装，跳过 .zshrc 配置"
        return
    fi

    cat >> "$ZSHRC" << 'EOF'

# >>> mihomo proxy initialize >>>
# Mihomo 配置
export MIHOMO_FUNCTIONS_DIR="$HOME/.config/zsh/functions/mihomo"
export MIHOMO_API_BASE="http://127.0.0.1:API_PORT"
export MIHOMO_CONFIG="$HOME/.config/mihomo/config.yaml"
export MIHOMO_LOG="$HOME/.mihomo.log"

# 添加 autoload 路径
fpath=("$HOME/.config/zsh/functions" $fpath)

# Autoload mihomo 相关函数
autoload -Uz proxy-select proxy-current proxy-list proxy-auto
autoload -Uz mihomo-start mihomo-stop

# Mihomo 快捷命令
alias mihomo-status='pgrep -a mihomo'
alias mihomo-log='tail -f ~/.mihomo.log'

# 代理环境变量管理
proxy-on() {
    if [ -n "$http_proxy" ]; then
        echo "✅ 代理已启用"
        echo "  HTTP: $http_proxy"
        return 0
    fi
    export http_proxy=http://127.0.0.1:PROXY_PORT
    export https_proxy=http://127.0.0.1:PROXY_PORT
    echo "✅ 代理已启用"
}

proxy-off() {
    unset http_proxy https_proxy
    echo "✅ 代理已关闭"
}

proxy-status() {
    echo "HTTP代理: ${http_proxy:-未设置}"
    echo "Mihomo: $(pgrep -a mihomo 2>/dev/null || echo '未运行')"
}
# <<< mihomo proxy initialize <<<

EOF

    # 替换端口占位符
    sed -i "s/API_PORT/${API_PORT}/g" "$ZSHRC"
    sed -i "s/PROXY_PORT/${PROXY_PORT}/g" "$ZSHRC"

    success ".zshrc 已配置"
}

# ==================== 主流程 ====================
main() {
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║     Mihomo Proxy 一键部署脚本                ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "配置信息:"
    echo "  配置文件: $CONFIG_FILE"
    echo "  代理端口: $PROXY_PORT"
    echo "  API 端口: $API_PORT"
    [[ -n "$MIHOMO_BINARY" ]] && echo "  二进制:   $MIHOMO_BINARY"
    echo ""

    read -p "确认安装? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi

    mkdir -p "$INSTALL_DIR/bin"

    install_binary
    install_config
    install_functions
    install_zshrc

    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║              安装完成！                      ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "下一步:"
    echo "  1. source ~/.zshrc"
    echo "  2. mihomo-start"
    echo "  3. proxy-select <国家代码>"
    echo ""
    echo "快速测试:"
    echo "  curl https://api.ipify.org?format=json"
    echo ""
}

main
