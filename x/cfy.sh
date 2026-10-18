#!/bin/bash

INSTALL_PATH="/usr/local/bin/cfy"

if [ "$0" != "$INSTALL_PATH" ]; then
    echo "正在安装 [cfy 节点优选生成器]..."
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误: 安装需要管理员权限。请使用 'curl ... | sudo bash' 来运行。"; exit 1
    fi
    echo "正在将脚本写入到 $INSTALL_PATH..."
    if [[ "$(basename "$0")" == "bash" || "$(basename "$0")" == "sh" ]]; then
        if ! cat /proc/self/fd/0 > "$INSTALL_PATH"; then echo "❌ 写入失败(管道模式)"; exit 1; fi
    else
        if ! cp "$0" "$INSTALL_PATH"; then echo "❌ 复制失败(文件模式)"; exit 1; fi
    fi
    chmod +x "$INSTALL_PATH"
    echo "✅ 安装成功! 现在可以运行 'cfy'。"
    echo "---"; echo "首次运行..."; exec "$INSTALL_PATH"; exit 0
fi

# --- 主程序从这里开始 ---

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

# ================== 配置 ==================
ROUNDS=3                 # 每个IP测几轮, 取最小值(降低抖动)
PROBE_TIMEOUT=3          # 单轮超时(秒)
PROBE_JOBS=24            # 并发数
SAMPLE_PER_CIDR=10       # 每个官方网段随机采样几个
MAX_CANDIDATES=500       # 候选池上限
TEST_SNI=""              # 留空=自动用节点域名, 再退回 www.cloudflare.com

URL_IPDB_BESTCF="https://ipdb.api.030101.xyz/?type=bestcf&country=true"
URL_WETEST_V4="https://www.wetest.vip/page/cloudflare/address_v4.html"
URL_WETEST_V6="https://www.wetest.vip/page/cloudflare/address_v6.html"
URL_WETEST_TOTAL_V4="https://www.wetest.vip/page/cloudflare/total_v4.html"
URL_CF_V4="https://www.cloudflare.com/ips-v4"
URL_SPEED="https://speed.cloudflare.com/__down?bytes=10000000"
# ==========================================

WITH_V6=false

check_deps() {
    for cmd in jq curl base64 grep sed mktemp awk sort head tr cut xargs; do
        command -v "$cmd" &> /dev/null || { echo -e "${RED}错误: 缺少命令 '$cmd'.${NC}"; exit 1; }
    done
}

# ---------- 本机出口位置自检 ----------
check_self_location() {
    local trace loc ip
    trace=$(curl -s --max-time 8 https://www.cloudflare.com/cdn-cgi/trace)
    loc=$(printf '%s' "$trace" | sed -n 's/^loc=//p')
    ip=$(printf '%s' "$trace" | sed -n 's/^ip=//p')
    echo -e "${CYAN}本机出口: ${ip:-未知}  地区: ${loc:-未知}${NC}"
    if [ "$loc" != "CN" ]; then
        echo -e "${RED}⚠ 注意: 本机出口不在中国大陆 (loc=${loc:-?})。${NC}"
        echo -e "${RED}  下面测到的是『本机→IP』的延迟, 不代表国内线路。${NC}"
        echo -e "${YELLOW}  要得到国内真实效果, 请把 cfy 放在国内那台设备"
        echo -e "  (sing-box 客户端所在的 PC / 路由器) 上运行。${NC}"
        echo ""
        read -p "仍然继续? [y/N]: " _c
        [[ "$_c" =~ ^[Yy]$ ]] || exit 1
    fi
}

# ---------- 解析 wetest 三网优选页: 输出 "IP|运营商|机房" ----------
parse_wetest_addr() {
    curl -s --max-time 20 "$1" | tr -d '\n\r' \
      | sed 's/<tr>/\n<TR>/g' | grep -a '^<TR>' \
      | while IFS= read -r row; do
            local ip isp colo
            ip=$(printf '%s' "$row" | sed -n 's/.*data-label="优选地址">\([^<]*\)<.*/\1/p')
            [ -z "$ip" ] && continue
            isp=$(printf '%s' "$row" | sed -n 's/.*data-label="线路名称">\([^<]*\)<.*/\1/p')
            colo=$(printf '%s' "$row" | sed -n 's/.*data-label="数据中心">\([A-Za-z0-9]\{1,6\}\)<.*/\1/p')
            printf '%s|%s|%s\n' "$ip" "${isp:-三网}" "${colo:-UNK}"
        done
}

# ---------- 解析 wetest 统计页(三网同表): 输出 "IP|三网|机房" ----------
parse_wetest_total() {
    curl -s --max-time 20 "$1" | tr -d '\n\r' \
      | sed 's/<tr>/\n<TR>/g' | grep -a '^<TR>' \
      | while IFS= read -r row; do
            local ip colos
            ip=$(printf '%s' "$row" | sed -n 's/.*data-label="优选地址">\([^<]*\)<.*/\1/p')
            [ -z "$ip" ] && continue
            colos=$(printf '%s' "$row" | grep -o 'data-label="[^"]*机房">[A-Za-z0-9]\{1,6\}<' \
                    | sed 's/.*>\([A-Za-z0-9]\{1,6\}\)<$/\1/' | awk '!u[$0]++' | head -n1)
            printf '%s|三网|%s\n' "$ip" "${colos:-UNK}"
        done
}

# ---------- CIDR 内随机取 IP ----------
rand_ip_in_cidr() {
    awk -v c="$1" -v seed="$RANDOM$RANDOM" 'BEGIN{
        srand(seed+0); split(c,p,"/"); split(p[1],o,".")
        ip=((o[1]*256+o[2])*256+o[3])*256+o[4]; host=2^(32-p[2])
        v=ip+int(rand()*host)
        printf "%d.%d.%d.%d\n", int(v/16777216), int(v/65536)%256, int(v/256)%256, v%256
    }'
}

# ---------- 构建候选池: "IP|运营商|机房" ----------
build_candidates() {
    local out="$1" tmp; tmp=$(mktemp)
    {
        parse_wetest_addr  "$URL_WETEST_V4"
        $WITH_V6 && parse_wetest_addr "$URL_WETEST_V6"
        parse_wetest_total "$URL_WETEST_TOTAL_V4"
        curl -s --max-time 15 "$URL_IPDB_BESTCF" | tr ' ' '\n' \
          | grep -aE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | awk '{print $0"|三网|UNK"}'
        local ranges; ranges=$(curl -s --max-time 15 "$URL_CF_V4")
        if [ -n "$ranges" ]; then
            while IFS= read -r cidr; do
                [ -z "$cidr" ] && continue
                local k
                for ((k=0;k<SAMPLE_PER_CIDR;k++)); do
                    echo "$(rand_ip_in_cidr "$cidr")|三网|UNK"
                done
            done <<< "$ranges"
        fi
    } > "$tmp"
    awk -F'|' 'NF && !u[$1]++' "$tmp" | head -n "$MAX_CANDIDATES" > "$out"
    rm -f "$tmp"
}

# ---------- 第一阶段: 只测握手延迟 ----------
probe_latency() {   # $1=候选 $2=SNI $3=输出
    local helper; helper=$(mktemp)
    cat > "$helper" <<'EOS'
#!/bin/bash
IFS='|' read -r ip isp colo <<< "$1"
sni="$2"; rounds="$3"; tmo="$4"
case "$ip" in *:*) host="[$ip]" ;; *) host="$ip" ;; esac
best=""
for ((r=0; r<rounds; r++)); do
    t=$(curl -sk -o /dev/null --max-time "$tmo" --connect-timeout "$tmo" \
        --resolve "$sni:443:$host" -A "Mozilla/5.0" \
        -w '%{time_appconnect}' "https://$sni/cdn-cgi/trace" 2>/dev/null) || continue
    ms=$(awk -v t="$t" 'BEGIN{printf "%d", t*1000+0.5}')
    [ "$ms" -le 0 ] && continue
    { [ -z "$best" ] || [ "$ms" -lt "$best" ]; } && best="$ms"
done
[ -z "$best" ] && exit 0
printf '%s %s %s %s\n' "$best" "$ip" "$isp" "${colo:-UNK}"
EOS
    chmod +x "$helper"
    xargs -P "$PROBE_JOBS" -d '\n' -I@ bash "$helper" @ "$2" "$ROUNDS" "$PROBE_TIMEOUT" \
        < "$1" > "$3" 2>/dev/null
    rm -f "$helper"
}

# ---------- 第二阶段: 取机房代码 / 下载测速 ----------
fetch_colo() {   # $1=IP $2=SNI -> 输出 colo
    local h; case "$1" in *:*) h="[$1]" ;; *) h="$1" ;; esac
    curl -sk --max-time 4 --resolve "$2:443:$h" -A "Mozilla/5.0" \
        "https://$2/cdn-cgi/trace" 2>/dev/null | sed -n 's/^colo=//p' | head -n1
}
speed_test() {   # $1=IP $2=SNI -> 输出 Mbps
    local h; case "$1" in *:*) h="[$1]" ;; *) h="$1" ;; esac
    local bps
    bps=$(curl -sk -o /dev/null --max-time 8 --resolve "$2:443:$h" -A "Mozilla/5.0" \
          -w '%{speed_download}' "$URL_SPEED" 2>/dev/null)
    awk -v b="${bps:-0}" 'BEGIN{ printf "%d", b*8/1000000 }'
}

ask_count() {
    local def="$1" n
    while true; do
        read -p "想生成几个? (默认 ${def}): " n
        [ -z "$n" ] && n="$def"
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -gt 0 ] && { echo "$n"; return 0; }
        echo -e "${RED}请输入正整数.${NC}"
    done
}

main() {
    local url_file="/etc/sing-box/list"
    declare -a valid_urls valid_ps_names

    echo -e "${GREEN}=================================================="
    echo -e " 节点优选生成器 (cfy) · 国内低延迟优选版"
    echo -e " (适配老王的4合一sing-box)"
    echo -e " "
    echo -e " 作者: byJoey (github.com/byJoey)"
    echo -e " 逻辑: 候选池(中国三网数据) → 本机实测握手 → 延迟升序"
    echo -e "==================================================${NC}"
    echo ""

    check_self_location

    # ---------- 选节点 ----------
    if [ -f "$url_file" ]; then
        mapfile -t urls < "$url_file"
        for url in "${urls[@]}"; do
            decoded_json=$(echo "${url#"vmess://"}" | base64 -d 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$decoded_json" ]; then
                ps=$(echo "$decoded_json" | jq -r .ps 2>/dev/null)
                [ $? -eq 0 ] && [ -n "$ps" ] && { valid_urls+=("$url"); valid_ps_names+=("$ps"); }
            fi
        done
    fi

    local selected_url
    if [ ${#valid_urls[@]} -gt 0 ]; then
        if [ ${#valid_urls[@]} -eq 1 ]; then
            selected_url=${valid_urls[0]}
            echo -e "${YELLOW}只有一个有效节点, 已自动选择: ${valid_ps_names[0]}${NC}"
        else
            echo -e "${YELLOW}请选择节点:${NC}"
            for i in "${!valid_ps_names[@]}"; do printf "%3d) %s\n" "$((i+1))" "${valid_ps_names[$i]}"; done
            local choice
            while true; do
                read -p "编号 (1-${#valid_urls[@]}): " choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#valid_urls[@]} ]; then
                    selected_url=${valid_urls[$((choice-1))]}; break
                fi
                echo -e "${RED}无效输入.${NC}"
            done
        fi
    else
        echo -e "${YELLOW}$url_file 中无有效节点.${NC}"
        while true; do
            read -p "粘贴一个 vmess:// 链接: " selected_url
            [[ "$selected_url" != vmess://* ]] && { echo -e "${RED}必须以 vmess:// 开头.${NC}"; continue; }
            decoded_json=$(echo "${selected_url#"vmess://"}" | base64 -d 2>/dev/null)
            if [ $? -ne 0 ] || [ -z "$decoded_json" ]; then echo -e "${RED}解码失败.${NC}"; continue; fi
            jq -e .ps >/dev/null 2>&1 <<< "$decoded_json" || { echo -e "${RED}JSON 不完整.${NC}"; continue; }
            break
        done
    fi

    local original_json original_ps
    original_json=$(echo "${selected_url#"vmess://"}" | base64 -d)
    original_ps=$(echo "$original_json" | jq -r .ps)
    echo -e "${GREEN}已选择: $original_ps${NC}"

    # ---------- SNI ----------
    local sni="$TEST_SNI"
    if [ -z "$sni" ]; then
        sni=$(echo "$original_json" | jq -r '.host // empty' 2>/dev/null)
        sni="${sni%%:*}"
        if [ -z "$sni" ] || [[ "$sni" =~ ^[0-9.]+$ ]]; then sni="www.cloudflare.com"; fi
    fi
    echo -e "${CYAN}实测 SNI: $sni${NC}"

    # ---------- 运营商偏好 ----------
    local isp_want="不限"
    echo -e "${YELLOW}你的宽带运营商? (只用于同延迟时优先排序, 可跳过)${NC}"
    echo "  0) 不限 / 不确定    1) 电信    2) 联通    3) 移动"
    local ic
    read -p "编号 (默认 0): " ic
    case "$ic" in 1) isp_want="电信" ;; 2) isp_want="联通" ;; 3) isp_want="移动" ;; esac

    local ans
    read -p "候选是否包含 IPv6? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && WITH_V6=true

    # ---------- 采集 + 实测 ----------
    local cand raw sorted
    cand=$(mktemp); raw=$(mktemp); sorted=$(mktemp)

    echo -e "${YELLOW}正在采集候选 IP (wetest三网 + CF优选 + 官方段抽样)...${NC}"
    build_candidates "$cand"
    local n; n=$(awk 'NF' "$cand" | wc -l | tr -d ' ')
    [ "$n" -eq 0 ] && { echo -e "${RED}候选为空, 请检查网络.${NC}"; rm -f "$cand" "$raw" "$sorted"; exit 1; }
    echo -e "${GREEN}候选 ${n} 个.${NC}"

    echo -e "${YELLOW}正在实测握手延迟 (每IP ${ROUNDS} 轮取最小, 并发 ${PROBE_JOBS})...${NC}"
    probe_latency "$cand" "$sni" "$raw"

    local ok; ok=$(awk 'NF' "$raw" | wc -l | tr -d ' ')
    [ "$ok" -eq 0 ] && { echo -e "${RED}全部失败: 检查该节点是否是 ws+tls, 或 443 是否被墙.${NC}"; rm -f "$cand" "$raw" "$sorted"; exit 1; }

    # 排序: 运营商匹配优先 -> 延迟升序
    awk -v w="$isp_want" '{ p=(w!="不限" && $3==w)?0:1; printf "%d %s %s %s %s\n", p, $1, $2, $3, $4 }' "$raw" \
        | sort -k1,1n -k2,2n | awk '{print $2, $3, $4, $5}' > "$sorted"

    echo -e "${GREEN}可用 ${ok} 个, 延迟最低的 15 个:${NC}"
    head -n 15 "$sorted" | awk '{printf "  %2d) %-16s %5s ms   %-5s %s\n", NR, $2, $1, $3, $4}'

    local num; num=$(ask_count 10)
    [ "$num" -gt "$ok" ] && { echo -e "${YELLOW}可用只有 ${ok} 个, 已调整.${NC}"; num=$ok; }

    # ---------- 复核机房 + 可选测速 ----------
    read -p "对最终结果做一次下载测速? (较慢, 约 ${num}×8s) [y/N]: " ans
    local do_speed=false; [[ "$ans" =~ ^[Yy]$ ]] && do_speed=true

    declare -a ip_list ms_list isp_list colo_list spd_list
    local i ip ms isp colo sp
    i=0
    while read -r ms ip isp colo; do
        [ "$i" -ge "$num" ] && break
        [ "$colo" = "UNK" ] && colo=$(fetch_colo "$ip" "$sni") && [ -z "$colo" ] && colo="UNK"
        sp=""
        $do_speed && sp=$(speed_test "$ip" "$sni")
        ip_list+=("$ip"); ms_list+=("$ms"); isp_list+=("$isp"); colo_list+=("$colo"); spd_list+=("$sp")
        i=$((i+1))
    done < "$sorted"

    rm -f "$cand" "$raw" "$sorted"

    # ---------- 汇总 ----------
    echo ""
    echo -e "${CYAN}最终清单:${NC}"
    for ((i=0; i<${#ip_list[@]}; i++)); do
        printf "  %2d) %-16s %5sms  %-5s %-4s %s\n" "$((i+1))" "${ip_list[$i]}" \
            "${ms_list[$i]}" "${isp_list[$i]}" "${colo_list[$i]}" \
            "${spd_list[$i]:+${spd_list[$i]}Mbps}"
    done

    echo ""
    echo "---"; echo -e "${YELLOW}生成的新节点链接如下:${NC}"
    for ((i=0; i<${#ip_list[@]}; i++)); do
        local lbl="${ms_list[$i]}ms"
        [ -n "${colo_list[$i]}" ] && [ "${colo_list[$i]}" != "UNK" ] && lbl="${colo_list[$i]}-${lbl}"
        local new_ps="${original_ps}-${lbl}"
        local mj; mj=$(echo "$original_json" | jq --arg a "${ip_list[$i]}" --arg p "$new_ps" '.add=$a | .ps=$p')
        echo "vmess://$(echo -n "$mj" | base64 | tr -d '\n')"
    done

    echo "---"; echo -e "${GREEN}共 ${#ip_list[@]} 个链接已生成完毕.${NC}"
    echo -e "${YELLOW}提示: 客户端切换节点后建议重新跑一次, 早晚高峰路由会变。${NC}"
}

check_deps
main
