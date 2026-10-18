#!/bin/bash

INSTALL_PATH="/usr/local/bin/cfy"

if [ "$0" != "$INSTALL_PATH" ]; then
    echo "正在安装 [cfy 节点优选生成器]..."

    if [ "$(id -u)" -ne 0 ]; then
        echo "错误: 安装需要管理员权限。请使用 'curl ... | sudo bash' 或 'sudo bash <(curl ...)' 命令来运行。"
        exit 1
    fi

    echo "正在将脚本写入到 $INSTALL_PATH..."

    if [[ "$(basename "$0")" == "bash" || "$(basename "$0")" == "sh" || "$(basename "$0")" == "-bash" ]]; then
        if ! cat /proc/self/fd/0 > "$INSTALL_PATH"; then
            echo "❌ 写入脚本失败 (管道模式)，请重试。"
            exit 1
        fi
    else
        if ! cp "$0" "$INSTALL_PATH"; then
            echo "❌ 复制脚本失败 (文件模式)，请重试。"
            exit 1
        fi
    fi

    if [ $? -eq 0 ]; then
        chmod +x "$INSTALL_PATH"
        echo "✅ 安装成功! 您现在可以随时随地运行 'cfy' 命令。"
        echo "---"
        echo "首次运行..."
        exec "$INSTALL_PATH"
    else
        echo "❌ 安装后赋权失败, 请检查权限。"
        exit 1
    fi
    exit 0
fi

# --- 主程序从这里开始 ---

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============== 韩国 / 亚太优选配置(可按需修改) ==============
KOREA_COLOS="ICN SEL"                                   # 韩国(首尔)机房, 最高优先级
ASIA_COLOS="ICN SEL NRT KIX OKA TPE HKG MFM SIN BKK MNL SGN HAN CGK KUL"  # 亚太机房白名单
ASIA_ONLY="true"                                        # true=只保留韩国/亚太机房
PROBE_TIMEOUT=3                                         # 单 IP 实测超时(秒)
PROBE_JOBS=20                                           # 实测并发数
TEST_SNI=""                                             # 实测用的 SNI, 留空=自动用节点域名, 再退回 www.cloudflare.com
# ===========================================================

URL_WETEST_V4="https://www.wetest.vip/page/cloudflare/address_v4.html"
URL_WETEST_V6="https://www.wetest.vip/page/cloudflare/address_v6.html"
URL_WETEST_TOTAL_V4="https://www.wetest.vip/page/cloudflare/total_v4.html"
URL_CF_V4="https://www.cloudflare.com/ips-v4"

WITH_V6=false

check_deps() {
    for cmd in jq curl base64 grep sed mktemp shuf xargs awk sort head cut tr; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}错误: 命令 '$cmd' 未找到. 请先安装它.${NC}"
            exit 1
        fi
    done
}

# ---------- 解析 wetest 表格: 输出 "IP|机房1 机房2 ..." ----------
parse_wetest_page() {
    local url="$1"
    curl -s --max-time 20 "$url" | tr -d '\n\r' \
      | sed 's/<tr>/\n<TR>/g' | grep -a '^<TR>' \
      | while IFS= read -r row; do
            local ip colos
            ip=$(printf '%s' "$row" | sed -n 's/.*data-label="优选地址">\([^<]*\)<.*/\1/p')
            [ -z "$ip" ] && continue
            # 优选页: data-label="数据中心"
            colos=$(printf '%s' "$row" | sed -n 's/.*data-label="数据中心">\([A-Za-z0-9]\{1,6\}\)<.*/\1/p')
            # 统计页: data-label="移动机房"/"联通机房"/"电信机房"
            if [ -z "$colos" ]; then
                colos=$(printf '%s' "$row" \
                    | grep -o 'data-label="[^"]*机房">[A-Za-z0-9]\{1,6\}<' \
                    | sed 's/.*>\([A-Za-z0-9]\{1,6\}\)<$/\1/' \
                    | awk '!u[$0]++' | tr '\n' ' ')
            fi
            printf '%s|%s\n' "$ip" "${colos:-UNK}"
        done
}

# ---------- 在 CIDR 内随机取一个 IP ----------
rand_ip_in_cidr() {
    awk -v c="$1" -v seed="$RANDOM$RANDOM" 'BEGIN{
        srand(seed+0)
        split(c,p,"/"); split(p[1],o,".")
        ip=((o[1]*256+o[2])*256+o[3])*256+o[4]
        host=2^(32-p[2])
        v=ip+int(rand()*host)
        a=int(v/16777216); b=int(v/65536)%256; cc=int(v/256)%256; d=v%256
        printf "%d.%d.%d.%d\n", a,b,cc,d
    }'
}

# ---------- 实测脚本(在 xargs 子进程里执行) ----------
PROBE_SCRIPT='ip=$1; sni=$2; tmo=$3
case "$ip" in
  *:*) host="[$ip]" ;;
  *)   host="$ip" ;;
esac
out=$(curl -sk --max-time "$tmo" --connect-timeout "$tmo" \
      --resolve "$sni:443:$host" -A "Mozilla/5.0" \
      -w "\n__CT__%{time_connect}" "https://$sni/cdn-cgi/trace" 2>/dev/null)
ct=$(printf "%s" "$out" | sed -n "s/^__CT__//p" | tail -n1)
colo=$(printf "%s" "$out" | sed -n "s/^colo=//p" | head -n1)
[ -z "$ct" ] && exit 0
[ -z "$colo" ] && colo=UNK
printf "%s %s %s\n" "$ip" "$colo" "$ct"'

# ---------- 按 机房优先级 + 延迟 排序, 输出 "IP 机房 延迟ms" ----------
rank_probe_results() {
    awk -v kor="$KOREA_COLOS" -v asia="$ASIA_COLOS" -v asiaonly="$ASIA_ONLY" '
    BEGIN{
        n=split(kor,K," ");  for(i=1;i<=n;i++) isK[K[i]]=1
        m=split(asia,A," "); for(i=1;i<=m;i++) isA[A[i]]=1
    }
    NF>=3 {
        ip=$1; colo=$2; ms=int($3*1000+0.5)
        if (colo=="UNK") rank=3
        else if (colo in isK) rank=0
        else if (colo in isA) rank=1
        else rank=2
        if (asiaonly=="true" && rank>1) next
        printf "%d %d %s %s\n", rank, ms, ip, colo
    }' "$1" | sort -k1,1n -k2,2n | awk '{printf "%s %s %s\n", $3, $4, $2}'
}

# ---------- 收集候选 IP ----------
collect_candidates() {
    local out="$1"
    : > "$out"
    {
        parse_wetest_page "$URL_WETEST_V4"          | cut -d'|' -f1
        parse_wetest_page "$URL_WETEST_TOTAL_V4"    | cut -d'|' -f1
        if $WITH_V6; then parse_wetest_page "$URL_WETEST_V6" | cut -d'|' -f1; fi
    } >> "$out"

    local ranges
    ranges=$(curl -s --max-time 15 "$URL_CF_V4")
    if [ -n "$ranges" ]; then
        while IFS= read -r cidr; do
            [ -z "$cidr" ] && continue
            rand_ip_in_cidr "$cidr" >> "$out"
            rand_ip_in_cidr "$cidr" >> "$out"
        done <<< "$ranges"
    fi

    awk 'NF && !seen[$0]++' "$out" > "$out.dedup" && mv "$out.dedup" "$out"
    head -n 200 "$out" > "$out.cap" && mv "$out.cap" "$out"
}

ask_count() {
    local def="$1" n
    while true; do
        read -p "请输入您想生成的 URL 数量 (默认 ${def}): " n
        if [ -z "$n" ]; then n="$def"; fi
        if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -gt 0 ]; then echo "$n"; return 0; fi
        echo -e "${RED}请输入一个有效的正整数.${NC}"
    done
}

main() {
    local url_file="/etc/sing-box/list"
    declare -a valid_urls valid_ps_names

    echo -e "${GREEN}=================================================="
    echo -e " 节点优选生成器 (cfy) · 韩国/亚太优选版"
    echo -e " (适配老王的4合一sing-box)"
    echo -e " "
    echo -e " 作者: byJoey (github.com/byJoey)"
    echo -e " 韩国化修改: 只选 ICN/SEL 及亚太机房"
    echo -e "==================================================${NC}"
    echo ""

    if [ -f "$url_file" ]; then
        mapfile -t urls < "$url_file"
        for url in "${urls[@]}"; do
            decoded_json=$(echo "${url#"vmess://"}" | base64 -d 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$decoded_json" ]; then
                ps=$(echo "$decoded_json" | jq -r .ps 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$ps" ]; then valid_urls+=("$url"); valid_ps_names+=("$ps"); fi
            fi
        done
    fi

    local selected_url
    if [ ${#valid_urls[@]} -gt 0 ]; then
        if [ ${#valid_urls[@]} -eq 1 ]; then
            selected_url=${valid_urls[0]}
            echo -e "${YELLOW}检测到只有一个有效节点, 已自动选择: ${valid_ps_names[0]}${NC}"
        else
            echo -e "${YELLOW}请选择一个节点作为:${NC}"
            for i in "${!valid_ps_names[@]}"; do printf "%3d) %s\n" "$((i+1))" "${valid_ps_names[$i]}"; done
            local choice
            while true; do
                read -p "请输入选项编号 (1-${#valid_urls[@]}): " choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#valid_urls[@]} ]; then
                    selected_url=${valid_urls[$((choice-1))]}; break
                else echo -e "${RED}无效的输入, 请重试.${NC}"; fi
            done
        fi
    else
        echo -e "${YELLOW}在 $url_file 中未找到有效节点.${NC}"
        while true; do
            read -p "请手动粘贴一个 vmess:// 链接作为: " selected_url
            if [[ "$selected_url" != vmess://* ]]; then echo -e "${RED}格式错误, 必须以 vmess:// 开头.${NC}"; continue; fi
            decoded_json=$(echo "${selected_url#"vmess://"}" | base64 -d 2>/dev/null)
            if [ $? -ne 0 ] || [ -z "$decoded_json" ]; then echo -e "${RED}无法解码链接, 请检查链接是否完整有效.${NC}"; continue; fi
            ps_check=$(echo "$decoded_json" | jq -e .ps >/dev/null 2>&1)
            if [ $? -ne 0 ]; then echo -e "${RED}解码成功, 但JSON内容不完整或格式错误. 请重试.${NC}"; continue; fi
            break
        done
    fi

    local base64_part=${selected_url#"vmess://"}
    local original_json=$(echo "$base64_part" | base64 -d)
    local original_ps=$(echo "$original_json" | jq -r .ps)
    echo -e "${GREEN}已选择: $original_ps${NC}"

    # ---------- 选择 IP 来源 ----------
    echo -e "${YELLOW}请选择 IP 地址来源 (韩国线路建议 1):${NC}"
    echo "  1) 本地实测优选【推荐】自动测 443 握手延迟, 只保留韩国/亚太机房, 按延迟排序"
    echo "  2) 云优选数据 (wetest.vip, 只筛亚太机房, 不实测)"
    echo "  3) Cloudflare 官方网段 (随机生成, 自行测速)"

    local ip_src mode
    while true; do
        read -p "请输入选项编号 (1-3): " ip_src
        case "$ip_src" in
            1) mode="probe";  break ;;
            2) mode="wetest"; break ;;
            3) mode="random"; break ;;
            *) echo -e "${RED}无效的输入, 请重试.${NC}" ;;
        esac
    done

    if [ "$mode" != "random" ]; then
        local ans
        read -p "候选 IP 是否包含 IPv6? 客户端支持再选 y [y/N]: " ans
        [[ "$ans" =~ ^[Yy]$ ]] && WITH_V6=true
    fi

    declare -a ip_list colo_list lat_list
    local num_to_generate=0

    # ---------- 1) 本地实测 ----------
    if [ "$mode" = "probe" ]; then
        local cand_file raw_file sorted_file
        cand_file=$(mktemp); raw_file=$(mktemp); sorted_file=$(mktemp)

        echo -e "${YELLOW}正在收集候选 IP...${NC}"
        collect_candidates "$cand_file"
        local total_cand
        total_cand=$(wc -l < "$cand_file" | tr -d ' ')
        if [ "$total_cand" -eq 0 ]; then
            echo -e "${RED}没有收集到任何候选 IP, 请检查网络.${NC}"
            rm -f "$cand_file" "$raw_file" "$sorted_file"; exit 1
        fi

        # 确定 SNI
        local sni="$TEST_SNI"
        if [ -z "$sni" ]; then
            sni=$(echo "$original_json" | jq -r '.host // empty' 2>/dev/null)
            sni="${sni%%:*}"
            if [ -z "$sni" ] || [[ "$sni" =~ ^[0-9.]+$ ]]; then sni="www.cloudflare.com"; fi
        fi

        echo -e "${YELLOW}正在实测 ${total_cand} 个 IP 的 443 延迟 (并发 ${PROBE_JOBS}, 超时 ${PROBE_TIMEOUT}s)...${NC}"
        xargs -P "$PROBE_JOBS" -I{} bash -c "$PROBE_SCRIPT" _ {} "$sni" "$PROBE_TIMEOUT" \
            < "$cand_file" > "$raw_file" 2>/dev/null

        rank_probe_results "$raw_file" > "$sorted_file"
        local ok_count
        ok_count=$(wc -l < "$sorted_file" | tr -d ' ')
        if [ "$ok_count" -eq 0 ]; then
            echo -e "${YELLOW}亚太机房无结果, 已放宽为全部机房按延迟排序.${NC}"
            ASIA_ONLY="false"
            rank_probe_results "$raw_file" > "$sorted_file"
            ok_count=$(wc -l < "$sorted_file" | tr -d ' ')
        fi
        if [ "$ok_count" -eq 0 ]; then
            echo -e "${RED}实测全部失败, 请检查能否访问 443 端口.${NC}"
            rm -f "$cand_file" "$raw_file" "$sorted_file"; exit 1
        fi

        echo -e "${GREEN}实测完成, 可用 IP ${ok_count} 个:${NC}"
        head -n 15 "$sorted_file" | awk '{printf "  %2d) %-45s %-4s %s ms\n", NR, $1, $2, $3}'
        [ "$ok_count" -gt 15 ] && echo "  ... (仅显示前 15 条)"

        num_to_generate=$(ask_count 10)
        if [ "$num_to_generate" -gt "$ok_count" ]; then
            echo -e "${YELLOW}可用 IP 只有 ${ok_count} 个, 已自动调整为 ${ok_count}.${NC}"
            num_to_generate=$ok_count
        fi

        local idx=0
        while read -r ip colo ms; do
            [ "$idx" -ge "$num_to_generate" ] && break
            ip_list+=("$ip"); colo_list+=("$colo"); lat_list+=("$ms")
            idx=$((idx+1))
        done < "$sorted_file"

        rm -f "$cand_file" "$raw_file" "$sorted_file"

    # ---------- 2) 云优选数据(仅筛选, 不实测) ----------
    elif [ "$mode" = "wetest" ]; then
        echo -e "${YELLOW}正在获取 wetest.vip 优选数据并筛选亚太机房...${NC}"
        local pairs_file
        pairs_file=$(mktemp)
        {
            parse_wetest_page "$URL_WETEST_V4"
            parse_wetest_page "$URL_WETEST_TOTAL_V4"
            if $WITH_V6; then parse_wetest_page "$URL_WETEST_V6"; fi
        } | awk 'NF' > "$pairs_file"

        if ! [ -s "$pairs_file" ]; then
            echo -e "${RED}获取失败, 请稍后重试.${NC}"; rm -f "$pairs_file"; exit 1
        fi

        # 按机房优先级筛选(韩国 > 亚太 > 其它, ASIA_ONLY=true 时丢弃其它)
        local filtered
        filtered=$(awk -v kor="$KOREA_COLOS" -v asia="$ASIA_COLOS" -v asiaonly="$ASIA_ONLY" '
            BEGIN{
                n=split(kor,K," ");  for(i=1;i<=n;i++) isK[K[i]]=1
                m=split(asia,A," "); for(i=1;i<=m;i++) isA[A[i]]=1
            }
            {
                split($0, f, "|"); ip=f[1]; nc=split(f[2], C, " ")
                best=9
                for(j=1;j<=nc;j++){
                    if (C[j] in isK) { r=0 } else if (C[j] in isA) { r=1 } else { r=2 }
                    if (r<best) best=r
                }
                if (asicount==0) {}
                if (asiaonly=="true" && best>1) next
                printf "%d %s %s\n", best, ip, f[2]
            }' "$pairs_file" | sort -k1,1n | awk '!u[$2]++')

        local filtered_count
        filtered_count=$(printf '%s\n' "$filtered" | awk 'NF' | wc -l | tr -d ' ')
        if [ "$filtered_count" -eq 0 ]; then
            echo -e "${YELLOW}亚太机房无数据, 已放宽为全部机房.${NC}"
            filtered=$(awk -F'|' '{printf "9 %s %s\n", $1, $2}' "$pairs_file" | awk '!u[$2]++')
            filtered_count=$(printf '%s\n' "$filtered" | awk 'NF' | wc -l | tr -d ' ')
        fi

        echo -e "${GREEN}筛选后可用 IP ${filtered_count} 个 (韩国机房优先置顶).${NC}"
        printf '%s\n' "$filtered" | head -n 15 | awk '{printf "  %2d) %-45s %s\n", NR, $2, $3}'

        num_to_generate=$(ask_count 10)
        if [ "$num_to_generate" -gt "$filtered_count" ]; then
            echo -e "${YELLOW}可用 IP 只有 ${filtered_count} 个, 已自动调整为 ${filtered_count}.${NC}"
            num_to_generate=$filtered_count
        fi

        local idx=0 ip colo_str first_colo
        while read -r rank ip colo_str; do
            [ "$idx" -ge "$num_to_generate" ] && break
            first_colo=$(printf '%s' "$colo_str" | awk '{print $1}')
            ip_list+=("$ip"); colo_list+=("${first_colo:-UNK}")
            idx=$((idx+1))
        done <<< "$filtered"

        rm -f "$pairs_file"

    # ---------- 3) Cloudflare 官方网段 ----------
    else
        echo -e "${YELLOW}正在从 Cloudflare 官网获取 IPv4 地址列表...${NC}"
        cloudflare_ips=$(curl -s --max-time 20 "$URL_CF_V4")
        if [ -z "$cloudflare_ips" ]; then echo -e "${RED}无法获取 Cloudflare IP 列表.${NC}"; exit 1; fi
        mapfile -t ip_list <<< "$cloudflare_ips"
        echo -e "${GREEN}成功获取 ${#ip_list[@]} 个 Cloudflare IPv4 地址段.${NC}"
        num_to_generate=$(ask_count 10)
    fi

    # ---------- 生成链接 ----------
    echo "---"; echo -e "${YELLOW}生成的新节点链接如下:${NC}"
    local i
    for ((i=0; i<num_to_generate; i++)); do
        local current_ip="${ip_list[$i]}"
        local modified_json new_base64 new_ps

        if [ "$mode" = "random" ]; then
            local random_ip_range=${current_ip}
            local ip_from_range=${random_ip_range%/*}
            modified_json=$(echo "$original_json" | jq --arg new_add "$ip_from_range" '.add = $new_add')
        else
            if [ -n "${lat_list[$i]:-}" ]; then
                new_ps="${original_ps}-${colo_list[$i]}-${lat_list[$i]}ms"
            else
                new_ps="${original_ps}-${colo_list[$i]:-优选}"
            fi
            modified_json=$(echo "$original_json" | jq --arg new_add "$current_ip" --arg new_ps "$new_ps" '.add = $new_add | .ps = $new_ps')
        fi

        new_base64=$(echo -n "$modified_json" | base64 | tr -d '\n')
        echo "vmess://${new_base64}"
    done

    echo "---"; echo -e "${GREEN}共 ${num_to_generate} 个链接已生成完毕.${NC}"
}

check_deps
main