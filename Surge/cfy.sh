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
            echo "❌ 写入脚本失败 (管道模式)，请重试。"; exit 1
        fi
    else
        if ! cp "$0" "$INSTALL_PATH"; then
            echo "❌ 复制脚本失败 (文件模式)，请重试。"; exit 1
        fi
    fi
    chmod +x "$INSTALL_PATH"
    echo "✅ 安装成功! 您现在可以随时随地运行 'cfy' 命令。"
    echo "---"; echo "首次运行..."
    exec "$INSTALL_PATH"
    exit 0
fi

# --- 主程序从这里开始 ---

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

# ================== 韩国 / 香港 / 日本 优选配置 ==================
# 目标国家, 按优先级排列 (反代IP 的国家归属)
TARGET_COUNTRIES="KR HK JP"
# 目标机房, 按优先级排列 (官方IP 实测 colo 归属)
TARGET_COLOS="ICN SEL HKG NRT KIX TPE"
# 次选亚太机房
ASIA_EXTRA_COLOS="SIN BKK MNL SGN HAN CGK KUL OKA MFM"
# true = 严格只保留目标地区; false = 目标地区优先, 其余按延迟垫底
STRICT_REGION="true"
PROBE_TIMEOUT=3      # 单 IP 握手超时(秒)
PROBE_JOBS=20        # 并发数
TEST_SNI=""          # 实测 SNI, 留空=自动取节点的 host

URL_IPDB_BESTPROXY="https://ipdb.api.030101.xyz/?type=bestproxy&country=true"
URL_WETEST_V4="https://www.wetest.vip/page/cloudflare/address_v4.html"
URL_WETEST_V6="https://www.wetest.vip/page/cloudflare/address_v6.html"
URL_WETEST_TOTAL_V4="https://www.wetest.vip/page/cloudflare/total_v4.html"
URL_CF_V4="https://www.cloudflare.com/ips-v4"
# ==============================================================

WITH_V6=false

check_deps() {
    for cmd in jq curl base64 grep sed mktemp shuf xargs awk sort head tr cut; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}错误: 命令 '$cmd' 未找到. 请先安装它.${NC}"; exit 1
        fi
    done
}

# ---------- 解析 wetest 表格: 输出 "IP|机房" ----------
parse_wetest_page() {
    curl -s --max-time 20 "$1" | tr -d '\n\r' \
      | sed 's/<tr>/\n<TR>/g' | grep -a '^<TR>' \
      | while IFS= read -r row; do
            local ip colos
            ip=$(printf '%s' "$row" | sed -n 's/.*data-label="优选地址">\([^<]*\)<.*/\1/p')
            [ -z "$ip" ] && continue
            colos=$(printf '%s' "$row" | sed -n 's/.*data-label="数据中心">\([A-Za-z0-9]\{1,6\}\)<.*/\1/p')
            if [ -z "$colos" ]; then
                colos=$(printf '%s' "$row" \
                    | grep -o 'data-label="[^"]*机房">[A-Za-z0-9]\{1,6\}<' \
                    | sed 's/.*>\([A-Za-z0-9]\{1,6\}\)<$/\1/' | awk '!u[$0]++' | tr '\n' ' ')
            fi
            printf '%s|%s\n' "$ip" "${colos:-UNK}"
        done
}

# ---------- IPDB 按国家取反代 IP ----------
get_ipdb_country_ips() {   # $1 = 输出文件
    curl -s --max-time 20 "$URL_IPDB_BESTPROXY" | tr ' ' '\n' \
      | grep -aE '^[0-9A-Za-z:.]+#[A-Z]{2}$' \
      | awk -F'#' -v want="$TARGET_COUNTRIES" '
            BEGIN{ n=split(want,W," "); for(i=1;i<=n;i++) pri[W[i]]=i-1 }
            ($2 in pri){ printf "%d %s %s\n", pri[$2], $1, $2 }' \
      | sort -k1,1n | awk '{ if(!u[$2]++) print $2" "$3 }' > "$1"
}

# ---------- 在 CIDR 内随机取一个 IP ----------
rand_ip_in_cidr() {
    awk -v c="$1" -v seed="$RANDOM$RANDOM" 'BEGIN{
        srand(seed+0); split(c,p,"/"); split(p[1],o,".")
        ip=((o[1]*256+o[2])*256+o[3])*256+o[4]; host=2^(32-p[2])
        v=ip+int(rand()*host)
        printf "%d.%d.%d.%d\n", int(v/16777216), int(v/65536)%256, int(v/256)%256, v%256
    }'
}

# ---------- 并发实测: 输入 "IP 标签", 输出 "IP colo 秒 标签" ----------
probe_batch() {   # $1=候选文件 $2=SNI $3=输出文件
    local cand="$1" sni="$2" out="$3" helper
    helper=$(mktemp)
    cat > "$helper" <<EOS
#!/bin/bash
ip="\$1"; tag="\${2:-NA}"
sni="$sni"; tmo="$PROBE_TIMEOUT"
case "\$ip" in
  *:*) host="[\$ip]" ;;
  *)   host="\$ip" ;;
esac
raw=\$(curl -sk --max-time "\$tmo" --connect-timeout "\$tmo" --resolve "\$sni:443:\$host" \
       -A "Mozilla/5.0" -w \$'\\n__CT__%{time_connect}' "https://\$sni/cdn-cgi/trace" 2>/dev/null)
ct=\$(printf '%s' "\$raw" | sed -n 's/^__CT__//p' | tail -n1)
colo=\$(printf '%s' "\$raw" | sed -n 's/^colo=//p' | head -n1)
[ -z "\$ct" ] && exit 0
[ -z "\$colo" ] && colo=UNK
printf '%s %s %s %s\\n' "\$ip" "\$colo" "\$ct" "\$tag"
EOS
    chmod +x "$helper"
    xargs -P "$PROBE_JOBS" -L 1 bash "$helper" < "$cand" > "$out" 2>/dev/null
    rm -f "$helper"
}

# ---------- 排序: 国家优先 -> 机房优先 -> 延迟升序, 输出 "IP colo ms 标签" ----------
rank_results() {   # $1=原始结果 $2=输出
    awk -v tc="$TARGET_COLOS" -v ac="$ASIA_EXTRA_COLOS" -v strict="$STRICT_REGION" \
        -v corder="$TARGET_COUNTRIES" -v unk_r="${1:-3}" '
    BEGIN{
        n=split(tc,T," "); for(i=1;i<=n;i++) rk[T[i]]=0
        m=split(ac,A," "); for(i=1;i<=m;i++) if(!(A[i] in rk)) rk[A[i]]=1
        k=split(corder,C," "); for(i=1;i<=k;i++) crk[C[i]]=i-1
    }
    NF>=3{
        ip=$1; colo=$2; ms=int($3*1000+0.5); tag=$4
        r=(colo in rk)?rk[colo]:((colo=="UNK")?unk_r:2)
        c=(tag in crk)?crk[tag]:9
        if (strict=="true" && c==9 && r>1) next
        printf "%d %d %d %s %s %s\n", c, r, ms, ip, colo, tag
    }' "$2" | sort -k1,1n -k2,2n -k3,3n \
       | awk '{ printf "%s %s %s %s\n", $4, $5, $3, $6 }'
}

ask_count() {
    local def="$1" n
    while true; do
        read -p "请输入您想生成的 URL 数量 (默认 ${def}): " n
        [ -z "$n" ] && n="$def"
        if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -gt 0 ]; then echo "$n"; return 0; fi
        echo -e "${RED}请输入一个有效的正整数.${NC}"
    done
}

main() {
    local url_file="/etc/sing-box/list"
    declare -a valid_urls valid_ps_names

    echo -e "${GREEN}=================================================="
    echo -e " 节点优选生成器 (cfy) · 韩国/香港/日本 优选版"
    echo -e " (适配老王的4合一sing-box)"
    echo -e " "
    echo -e " 作者: byJoey (github.com/byJoey)"
    echo -e " 目标: ${TARGET_COUNTRIES} / 机房 ${TARGET_COLOS}"
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
    echo -e "${YELLOW}请选择 IP 地址来源:${NC}"
    echo "  1) 反代IP 按国家 (KR/HK/JP) + 本地实测   ${CYAN}[韩国首选]${NC}"
    echo "  2) Cloudflare 官方IP + 实测筛 ICN/HKG/NRT ${CYAN}[纯净, 但亚太池子小]${NC}"
    echo "  3) 云优选数据 wetest.vip, 只筛亚太机房 (不实测)"
    echo "  4) Cloudflare 官方网段随机生成 (自行测速)"

    local ip_src mode
    while true; do
        read -p "请输入选项编号 (1-4): " ip_src
        case "$ip_src" in
            1) mode="proxy";  break ;;
            2) mode="official"; break ;;
            3) mode="wetest"; break ;;
            4) mode="random"; break ;;
            *) echo -e "${RED}无效的输入, 请重试.${NC}" ;;
        esac
    done

    if [ "$mode" = "official" ] || [ "$mode" = "wetest" ]; then
        local ans
        read -p "候选 IP 是否包含 IPv6? 客户端支持再选 y [y/N]: " ans
        [[ "$ans" =~ ^[Yy]$ ]] && WITH_V6=true
    fi

    # ---------- 确定 SNI ----------
    local sni="$TEST_SNI"
    if [ -z "$sni" ]; then
        sni=$(echo "$original_json" | jq -r '.host // empty' 2>/dev/null)
        sni="${sni%%:*}"
        if [ -z "$sni" ] || [[ "$sni" =~ ^[0-9.]+$ ]]; then sni="www.cloudflare.com"; fi
    fi

    declare -a ip_list colo_list lat_list tag_list
    local num_to_generate=0

    # ================= 1) 反代IP 按国家 =================
    if [ "$mode" = "proxy" ]; then
        local cand_file raw_file sorted_file
        cand_file=$(mktemp); raw_file=$(mktemp); sorted_file=$(mktemp)

        echo -e "${YELLOW}正在获取 IPDB 反代 IP 并按 ${TARGET_COUNTRIES} 筛选...${NC}"
        get_ipdb_country_ips "$cand_file"
        local n_cand; n_cand=$(awk 'NF' "$cand_file" | wc -l | tr -d ' ')
        if [ "$n_cand" -eq 0 ]; then
            echo -e "${RED}没有取到 ${TARGET_COUNTRIES} 的反代 IP, 可稍后重试或改用选项 2.${NC}"
            rm -f "$cand_file" "$raw_file" "$sorted_file"; exit 1
        fi
        echo -e "${GREEN}拿到 ${n_cand} 个候选.${NC}"
        awk '{printf "  %-16s %s\n", $1, $2}' "$cand_file" | head -n 10

        echo -e "${YELLOW}正在用 SNI=${sni} 实测 (并发 ${PROBE_JOBS}, 超时 ${PROBE_TIMEOUT}s)...${NC}"
        probe_batch "$cand_file" "$sni" "$raw_file"

        rank_results 3 "$raw_file" > "$sorted_file"
        local ok; ok=$(awk 'NF' "$sorted_file" | wc -l | tr -d ' ')
        if [ "$ok" -eq 0 ]; then
            echo -e "${YELLOW}严格模式下无结果, 已放宽为全部可用节点按延迟排序.${NC}"
            sed 's/^/ /' /dev/null
            STRICT_REGION="false"; rank_results 3 "$raw_file" > "$sorted_file"
            ok=$(awk 'NF' "$sorted_file" | wc -l | tr -d ' ')
        fi
        if [ "$ok" -eq 0 ]; then
            echo -e "${RED}全部握手失败. 反代 IP 变动很快, 建议改用选项 2.${NC}"
            rm -f "$cand_file" "$raw_file" "$sorted_file"; exit 1
        fi

        echo -e "${GREEN}实测可用 ${ok} 个 (国家 / 机房 / 延迟):${NC}"
        head -n 15 "$sorted_file" | awk '{printf "  %2d) %-16s %-3s %-4s %s ms\n", NR, $1, $4, $2, $3}'
        [ "$ok" -gt 15 ] && echo "  ... (仅显示前 15 条)"

        num_to_generate=$(ask_count 10)
        [ "$num_to_generate" -gt "$ok" ] && { echo -e "${YELLOW}可用只有 ${ok} 个, 已调整.${NC}"; num_to_generate=$ok; }

        local idx=0 ip colo ms tag
        while read -r ip colo ms tag; do
            [ "$idx" -ge "$num_to_generate" ] && break
            ip_list+=("$ip"); colo_list+=("$colo"); lat_list+=("$ms"); tag_list+=("$tag")
            idx=$((idx+1))
        done < "$sorted_file"

        rm -f "$cand_file" "$raw_file" "$sorted_file"

    # ================= 2) 官方IP 实测筛机房 =================
    elif [ "$mode" = "official" ]; then
        local cand_file raw_file sorted_file
        cand_file=$(mktemp); raw_file=$(mktemp); sorted_file=$(mktemp)

        echo -e "${YELLOW}正在收集候选 IP (wetest 优选 + 官方段抽样)...${NC}"
        {
            parse_wetest_page "$URL_WETEST_V4"       | cut -d'|' -f1 | awk '{print $0" NA"}'
            parse_wetest_page "$URL_WETEST_TOTAL_V4" | cut -d'|' -f1 | awk '{print $0" NA"}'
            if $WITH_V6; then parse_wetest_page "$URL_WETEST_V6" | cut -d'|' -f1 | awk '{print $0" NA"}'; fi
            local ranges; ranges=$(curl -s --max-time 15 "$URL_CF_V4")
            if [ -n "$ranges" ]; then
                while IFS= read -r cidr; do
                    [ -z "$cidr" ] && continue
                    echo "$(rand_ip_in_cidr "$cidr") NA"
                    echo "$(rand_ip_in_cidr "$cidr") NA"
                done <<< "$ranges"
            fi
        } > "$cand_file"

        awk 'NF && !u[$1]++' "$cand_file" | head -n 200 > "$cand_file.cap" && mv "$cand_file.cap" "$cand_file"
        local total; total=$(awk 'NF' "$cand_file" | wc -l | tr -d ' ')

        echo -e "${YELLOW}正在实测 ${total} 个 IP (SNI=${sni})...${NC}"
        probe_batch "$cand_file" "$sni" "$raw_file"

        rank_results 3 "$raw_file" > "$sorted_file"
        local ok; ok=$(awk 'NF' "$sorted_file" | wc -l | tr -d ' ')
        if [ "$ok" -eq 0 ]; then
            echo -e "${YELLOW}目标机房无结果, 已放宽为全部机房按延迟排序.${NC}"
            STRICT_REGION="false"; rank_results 1 "$raw_file" > "$sorted_file"
            ok=$(awk 'NF' "$sorted_file" | wc -l | tr -d ' ')
        fi
        if [ "$ok" -eq 0 ]; then
            echo -e "${RED}实测全部失败, 请确认能访问 443.${NC}"
            rm -f "$cand_file" "$raw_file" "$sorted_file"; exit 1
        fi

        echo -e "${GREEN}实测可用 ${ok} 个:${NC}"
        head -n 15 "$sorted_file" | awk '{printf "  %2d) %-40s %-4s %s ms\n", NR, $1, $2, $3}'
        [ "$ok" -gt 15 ] && echo "  ... (仅显示前 15 条)"

        num_to_generate=$(ask_count 10)
        [ "$num_to_generate" -gt "$ok" ] && { echo -e "${YELLOW}可用只有 ${ok} 个, 已调整.${NC}"; num_to_generate=$ok; }

        local idx=0 ip colo ms tag
        while read -r ip colo ms tag; do
            [ "$idx" -ge "$num_to_generate" ] && break
            ip_list+=("$ip"); colo_list+=("$colo"); lat_list+=("$ms"); tag_list+=("")
            idx=$((idx+1))
        done < "$sorted_file"

        rm -f "$cand_file" "$raw_file" "$sorted_file"

    # ================= 3) wetest 数据筛选 =================
    elif [ "$mode" = "wetest" ]; then
        echo -e "${YELLOW}正在获取 wetest.vip 数据并筛选亚太机房...${NC}"
        local pairs; pairs=$(mktemp)
        {
            parse_wetest_page "$URL_WETEST_V4"
            parse_wetest_page "$URL_WETEST_TOTAL_V4"
            if $WITH_V6; then parse_wetest_page "$URL_WETEST_V6"; fi
        } | awk 'NF' > "$pairs"
        if ! [ -s "$pairs" ]; then echo -e "${RED}获取失败.${NC}"; rm -f "$pairs"; exit 1; fi

        local filtered
        filtered=$(awk -v tc="$TARGET_COLOS" -v ac="$ASIA_EXTRA_COLOS" -v strict="$STRICT_REGION" '
            BEGIN{
                n=split(tc,T," "); for(i=1;i<=n;i++) rk[T[i]]=0
                m=split(ac,A," "); for(i=1;i<=m;i++) if(!(A[i] in rk)) rk[A[i]]=1
            }
            {
                split($0,f,"|"); ip=f[1]; nc=split(f[2],C," "); best=9
                for(j=1;j<=nc;j++){ r=(C[j] in rk)?rk[C[j]]:2; if(r<best) best=r }
                if (strict=="true" && best>1) next
                printf "%d %s %s\n", best, ip, f[2]
            }' "$pairs" | sort -k1,1n | awk '!u[$2]++')

        local cnt; cnt=$(printf '%s\n' "$filtered" | awk 'NF' | wc -l | tr -d ' ')
        if [ "$cnt" -eq 0 ]; then
            echo -e "${YELLOW}目标机房无数据, 放宽为全部.${NC}"
            filtered=$(awk -F'|' '{printf "9 %s %s\n", $1, $2}' "$pairs" | awk '!u[$2]++')
            cnt=$(printf '%s\n' "$filtered" | awk 'NF' | wc -l | tr -d ' ')
        fi
        echo -e "${GREEN}筛选后 ${cnt} 个:${NC}"
        printf '%s\n' "$filtered" | head -n 15 | awk '{printf "  %2d) %-45s %s\n", NR, $2, $3}'

        num_to_generate=$(ask_count 10)
        [ "$num_to_generate" -gt "$cnt" ] && { echo -e "${YELLOW}可用只有 ${cnt} 个, 已调整.${NC}"; num_to_generate=$cnt; }

        local idx=0 r ip colo_str
        while read -r r ip colo_str; do
            [ "$idx" -ge "$num_to_generate" ] && break
            ip_list+=("$ip"); colo_list+=("$(printf '%s' "$colo_str" | awk '{print $1}')")
            lat_list+=(""); tag_list+=("")
            idx=$((idx+1))
        done <<< "$filtered"
        rm -f "$pairs"

    # ================= 4) 官方网段随机 =================
    else
        echo -e "${YELLOW}正在获取 Cloudflare IPv4 网段...${NC}"
        local cf_ips; cf_ips=$(curl -s --max-time 20 "$URL_CF_V4")
        if [ -z "$cf_ips" ]; then echo -e "${RED}无法获取 Cloudflare IP 列表.${NC}"; exit 1; fi
        mapfile -t ip_list <<< "$cf_ips"
        echo -e "${GREEN}获取到 ${#ip_list[@]} 个网段.${NC}"
        num_to_generate=$(ask_count 10)
    fi

    # ---------- 生成链接 ----------
    echo "---"; echo -e "${YELLOW}生成的新节点链接如下:${NC}"
    local i
    for ((i=0; i<num_to_generate; i++)); do
        local current_ip="${ip_list[$i]}"
        local colo="${colo_list[$i]:-}" tag="${tag_list[$i]:-}" ms="${lat_list[$i]:-}"
        local new_ps modified_json new_base64 lbl=""

        if [ "$mode" = "random" ]; then
            modified_json=$(echo "$original_json" | jq --arg a "${current_ip%/*}" '.add = $a')
        else
            if [ -n "$tag" ] && [ -n "$colo" ]; then lbl="$tag-$colo"
            elif [ -n "$tag" ]; then lbl="$tag"
            else lbl="${colo:-优选}"; fi
            if [ -n "$ms" ]; then new_ps="${original_ps}-${lbl}-${ms}ms"; else new_ps="${original_ps}-${lbl}"; fi
            modified_json=$(echo "$original_json" | jq --arg a "$current_ip" --arg p "$new_ps" '.add = $a | .ps = $p')
        fi

        new_base64=$(echo -n "$modified_json" | base64 | tr -d '\n')
        echo "vmess://${new_base64}"
    done

    echo "---"; echo -e "${GREEN}共 ${num_to_generate} 个链接已生成完毕.${NC}"
}

check_deps
main