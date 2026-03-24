# Mihomo 共享模块
# 包含所有辅助函数和依赖加载逻辑

# ==================== 配置 ====================
MIHOMO_API_BASE="${MIHOMO_API_BASE:-http://127.0.0.1:9090}"
MIHOMO_CONFIG="${MIHOMO_CONFIG:-$HOME/.config/mihomo/config.yaml}"
MIHOMO_LOG="${MIHOMO_LOG:-$HOME/.mihomo.log}"
MIHOMO_AUTO_GROUP="${MIHOMO_AUTO_GROUP:-Auto | PandaFan.sh}"
MIHOMO_FUNCTIONS_DIR="${MIHOMO_FUNCTIONS_DIR:-$HOME/.config/zsh/functions/mihomo}"

# ==================== 依赖加载 ====================
_mihomo_source_once() {
    local file="$1"
    [[ -f "$file" ]] && source "$file"
}

# ==================== API 函数 ====================
_mihomo_url_encode() {
    local string="$1"
    python3 -c "import urllib.parse; print(urllib.parse.quote('$string'))" 2>/dev/null || echo "$string"
}

_mihomo_api_get_proxies() {
    curl -s --noproxy "127.0.0.1" "${MIHOMO_API_BASE}/proxies" 2>/dev/null
}

_mihomo_api_switch_proxy() {
    local proxy_group="$1"
    local proxy_name="$2"
    local encoded_group=$(_mihomo_url_encode "$proxy_group")
    curl -s --noproxy "127.0.0.1" -X PUT "${MIHOMO_API_BASE}/proxies/${encoded_group}" \
         -H "Content-Type: application/json" \
         -d "{\"name\":\"${proxy_name}\"}" 2>/dev/null
}

_mihomo_api_get_group_status() {
    local group_name="$1"
    local encoded_group=$(_mihomo_url_encode "$group_name")
    curl -s --noproxy "127.0.0.1" "${MIHOMO_API_BASE}/proxies/${encoded_group}" 2>/dev/null
}

_mihomo_api_check_connection() {
    curl -s --noproxy "127.0.0.1" -o /dev/null -w "%{http_code}" "${MIHOMO_API_BASE}/proxies" 2>/dev/null
}

_mihomo_api_get_proxy_delay() {
    local proxy_name="$1"
    local proxies=$(_mihomo_api_get_proxies)
    echo "$proxies" | jq -r --arg node "$proxy_name" \
        '.proxies[$node].history[-1].delay // 0' 2>/dev/null
}

# ==================== 节点数据 ====================
typeset -gA MIHOMO_NODE_MAP
typeset -gA MIHOMO_COUNTRY_NAMES
MIHOMO_COUNTRY_NAMES=(
    [au]="澳大利亚" [ca]="加拿大" [cn]="中国" [de]="德国"
    [fr]="法国" [gb]="英国" [hk]="香港" [id]="印尼"
    [in]="印度" [jp]="日本" [kr]="韩国" [sg]="新加坡"
    [tw]="台湾" [us]="美国" [auto]="自动"
)

_mihomo_get_all_proxies_from_config() {
    [[ ! -f "$MIHOMO_CONFIG" ]] && return 1
    python3 -c "
import yaml, sys
try:
    with open('$MIHOMO_CONFIG', 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    for proxy in config.get('proxies', []):
        name = proxy.get('name', '')
        if name: print(name)
except: pass
" 2>/dev/null
}

_mihomo_extract_country_code() {
    local node_name="$1"
    case "$node_name" in
        *🇦🇺*|*澳大利亚*|*澳洲*) echo "au" ;;
        *🇨🇦*|*加拿大*) echo "ca" ;;
        *🇨🇳*|*中国*) echo "cn" ;;
        *🇩🇪*|*德国*) echo "de" ;;
        *🇫🇷*|*法国*) echo "fr" ;;
        *🇬🇧*|*英国*) echo "gb" ;;
        *🇭🇰*|*香港*) echo "hk" ;;
        *🇮🇩*|*印尼*) echo "id" ;;
        *🇮🇳*|*印度*) echo "in" ;;
        *🇯🇵*|*日本*) echo "jp" ;;
        *🇰🇷*|*韩国*) echo "kr" ;;
        *🇸🇬*|*新加坡*) echo "sg" ;;
        *🇹🇼*|*台湾*) echo "tw" ;;
        *🇺🇸*|*美国*) echo "us" ;;
        *" AU"*|*" AU "*|*"AU "*|^AU*) echo "au" ;;
        *" CA"*|*" CA "*|*"CA "*|^CA*) echo "ca" ;;
        *" DE"*|*" DE "*|*"DE "*|^DE*) echo "de" ;;
        *" FR"*|*" FR "*|*"FR "*|^FR*) echo "fr" ;;
        *" GB"*|*" GB "*|*"GB "*|^GB*) echo "gb" ;;
        *" HK"*|*" HK "*|*"HK "*|^HK*) echo "hk" ;;
        *" ID"*|*" ID "*|*"ID "*|^ID*) echo "id" ;;
        *" IN"*|*" IN "*|*"IN "*|^IN*) echo "in" ;;
        *" JP"*|*" JP "*|*"JP "*|^JP*) echo "jp" ;;
        *" KR"*|*" KR "*|*"KR "*|^KR*) echo "kr" ;;
        *" SG"*|*" SG "*|*"SG "*|^SG*) echo "sg" ;;
        *" TW"*|*" TW "*|*"TW "*|^TW*) echo "tw" ;;
        *" US"*|*" US "*|*"US "*|^US*) echo "us" ;;
        *) echo "" ;;
    esac
}

_mihomo_build_node_map() {
    MIHOMO_NODE_MAP=()
    local all_nodes_str=$(_mihomo_get_all_proxies_from_config)
    local all_nodes=(${(f)all_nodes_str})
    for node in "${all_nodes[@]}"; do
        [[ -z "$node" ]] && continue
        local country=$(_mihomo_extract_country_code "$node")
        if [[ -n "$country" ]]; then
            if [[ -z "${MIHOMO_NODE_MAP[$country]}" ]]; then
                MIHOMO_NODE_MAP[$country]="$node"
            else
                MIHOMO_NODE_MAP[$country]="${MIHOMO_NODE_MAP[$country]}"$'\n'"$node"
            fi
        fi
    done
}

_mihomo_get_nodes_by_country() {
    local country="$1"
    _mihomo_build_node_map >/dev/null 2>&1
    echo "${MIHOMO_NODE_MAP[$country]}"
}

_mihomo_validate_country() {
    local country="$1"
    _mihomo_build_node_map >/dev/null 2>&1
    [[ -n "${MIHOMO_NODE_MAP[$country]}" ]]
}

_mihomo_get_supported_countries() {
    _mihomo_build_node_map >/dev/null 2>&1
    echo "${(@k)MIHOMO_NODE_MAP}"
}

_mihomo_list_countries() {
    _mihomo_build_node_map >/dev/null 2>&1
    for country in $(echo "${(@k)MIHOMO_NODE_MAP}" | tr ' ' '\n' | sort); do
        local name="${MIHOMO_COUNTRY_NAMES[$country]}"
        printf "   %-5s - %s\n" "$country" "${name:-$country}"
    done
}

# ==================== 辅助函数 ====================
_mihomo_ensure_running() {
    if ! pgrep -u "$USER" -x "mihomo" > /dev/null; then
        echo "❌ Mihomo 未运行"
        echo "💡 启动: mihomo-start"
        return 1
    fi
    local http_status=$(_mihomo_api_check_connection)
    if [[ "$http_status" != "200" ]]; then
        echo "❌ Mihomo API 无法访问 (HTTP $http_status)"
        return 1
    fi
    return 0
}

_mihomo_switch_to_auto() {
    echo "🔄 切换到自动模式..."
    echo "✅ 已使用自动模式（url-test）"
    echo "💡 每 5 分钟自动选择延迟最低的节点"
    echo ""
    proxy-current
}

_mihomo_do_switch() {
    local target_node="$1"
    echo "🔄 正在切换到: $target_node"
    local result=$(_mihomo_api_switch_proxy "$MIHOMO_AUTO_GROUP" "$target_node")
    if echo "$result" | jq -e '.now == "'"$target_node"'"' >/dev/null 2>&1; then
        echo "✅ 切换成功"
        echo ""
        proxy-current
    else
        echo "❌ 切换失败: $result"
        return 1
    fi
}

_mihomo_select_best_node() {
    local nodes=("$@")
    local best_node="" best_delay=99999 first_node=""
    for node in "${nodes[@]}"; do
        [[ -z "$first_node" ]] && first_node="$node"
        local delay=$(_mihomo_api_get_proxy_delay "$node")
        if [[ "$delay" -gt 0 && "$delay" -lt "$best_delay" ]]; then
            best_delay="$delay"
            best_node="$node"
        fi
    done
    echo "${best_node:-$first_node}"
}

_mihomo_show_usage() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 Mihomo 节点选择工具"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "用法: proxy-select <国家代码>"
    echo ""
    echo "支持的国家代码:"
    _mihomo_list_countries
    echo ""
    echo "其他命令:"
    echo "  proxy-auto    - 切换到自动模式"
    echo "  proxy-current - 查看当前节点"
    echo "  proxy-list    - 列出所有节点"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
