#!/bin/bash
export LANG=en_US.UTF-8
sh_t="2024-10-25 22:57:41"
sh_v=$(echo "$sh_t" | sed 's/-/./g' | sed 's/ /./' | tr -d ':')
# 定义颜色
re='\e[0m'
red='\e[1;91m'
white='\e[1;97m'
green='\e[1;32m'
yellow='\e[1;33m'
purple='\e[1;35m'
skyblue='\e[1;96m'
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'
# 配置文件路径
cfnat_file=$HOME/cfnat
colo_file=$HOME/colo
config_file=$cfnat_file/cfnat.conf
ddns_config_file=$HOME/cfnat/ddns.conf # 新增DDNS配置文件路径
ps=""
Androidps=""
cfnat_colo="SJC,LAX,HKG"
cfnat_addr="1234"
cfnat_delay="300"
cfnat_ipnum="10"
cfnat_ips="4"
cfnat_num="10"
cfnat_port="443"
cfnat_random="true"
cfnat_task="100"
cfnat_tls_TF="true"
cfnat_tls="TLS"
cfnat_linux="cfnat-linux-amd64"
colo_linux="colo-linux-amd64"

# Cloudflare DDNS 全局变量
cloudflare_email=""
cloudflare_api_key=""
cloudflare_zone_id=""
cloudflare_record_name=""

################################################################
cfnat_update() {
	cd ~
	clear
	echo "------------------------"

    sh_t_new=$(curl -s https://raw.cmliussss.com/cfnat.sh | grep -oP 'sh_t="\K[0-9\-: ]+(?=")')
    sh_v_new=$(echo "$sh_t_new" | sed 's/-/./g' | sed 's/ /./' | tr -d ':')

	if [ "$sh_v" = "$sh_v_new" ]; then
		echo -e "${gl_lv}你已经是最新版本！${gl_huang}v$sh_v${gl_bai}"
	else
		echo "发现新版本！"
		echo -e "当前版本 v$sh_v"
        echo -e "最新版本 ${gl_huang}v$sh_v_new${gl_bai}"
		echo "------------------------"
		read -e -p "确定更新脚本吗？(Y/N): " choice
		case "$choice" in
			[Yy])
				clear
                curl -sSL https://raw.cmliussss.com/cfnat.sh -o ~/cfnat.sh && chmod +x ~/cfnat.sh
				cp -f ~/cfnat.sh /usr/local/bin/cfnat > /dev/null 2>&1
				echo -e "${gl_lv}脚本已更新到最新版本！${gl_huang}v$sh_v_new${gl_bai}"
				break_end
				bash ~/cfnat.sh
				exit
				;;
			*)
            echo "已取消"
				;;
		esac
	fi
}

# 安装依赖包
install(){
    if [ $# -eq 0 ]; then
        echo -e "${red}未提供软件包参数!${re}"
        return 1
    fi

    for package in "$@"; do
        if command -v "$package" &>/dev/null; then
            echo -e "${green}${package}已经安装了！${re}"
            continue
        fi
        echo -e "${yellow}正在安装 ${package}...${re}"

        if [ -n "$PREFIX" ] && [ -d "$PREFIX" ] && echo "$PREFIX" | grep -q "/data/data/com.termux/files"; then
            pkg install -y "$package"
        elif command -v apt &>/dev/null; then
            apt install -y "$package"
        elif command -v dnf &>/dev/null; then
            dnf install -y "$package"
        elif command -v yum &>/dev/null; then
            yum install -y "$package"
        elif command -v apk &>/dev/null; then
            apk add "$package"
        elif [ -f /etc/openwrt_release ]; then
            opkg update
            opkg install coreutils coreutils-nohup crontab
        else
            echo -e"${red}暂不支持你的系统!${re}"
            return 1
        fi
    done

    return 0
}

check_dependencies() {
    missing_packages=()
    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo -e "缺失的依赖包: ${yellow}${missing_packages[*]}${re}"
        return 1
    fi
    return 0
}

check_and_install() {
    missing_packages=()
    
    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo -e "缺失的依赖包: ${yellow}${missing_packages[*]}${re}"
        read -p "是否允许安装缺失的依赖包 (Y/N): " install_apps
        install_apps=${install_apps^^} # 转换为大写
        if [ "$install_apps" = "Y" ]; then
            install "${missing_packages[@]}"
        fi
    else
        echo "所有依赖包已安装。"
    fi
}

# 选择客户端 CPU 架构
archAffix(){
    if [ -n "$PREFIX" ] && [ -d "$PREFIX" ] && echo "$PREFIX" | grep -q "/data/data/com.termux/files"; then
        echo 'termux'
    else
        case "$(uname -m)" in
        i386 | i686 ) echo '386' ;;
        x86_64 | amd64 ) echo 'amd64' ;;
        armv5 ) echo 'armv5' ;;
        armv6 ) echo 'armv6' ;;
        armv7 ) echo 'armv7' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) echo '未知' ;;
        esac
    fi
}

# 等待用户返回
break_end() {
    echo -e "${green}执行完成${re}"
    echo -e "${yellow}按任意键返回...${re}"
    read -n 1 -s -r -p ""
    echo ""
    clear
}

# 安装cfnat
install_cfnat(){
    if [ ! ${Architecture} = "termux" ]; then
        if [ -n "$1" ]; then 
            install curl nohup crontab ps jq
        else
            check_and_install curl nohup crontab ps jq
        fi
    fi

    # 检测 $cfnat_file 文件夹是否存在
    if [ ! -d $cfnat_file ]; then
        # 如果不存在，则创建该文件夹
        mkdir $cfnat_file
        echo "目录 $cfnat_file 已创建。"
    fi

    # 检测 $cfnat_file/locations.json 是否存在
    echo "下载 locations.json 文件。"
    if [ ! -f $cfnat_file/locations.json ]; then
        # 如果不存在，则使用 curl 下载文件
        curl -k -SL https://speed.cloudflare.com/locations -o $cfnat_file/locations.json
        if [ $? -ne 0 ]; then
            curl -k -SL https://cf.090227.xyz/locations_cn -o $cfnat_file/locations.json
        fi

        if [ $? -ne 0 ]; then
            echo "locations.json 下载失败。"
        else
            echo "locations.json 下载完成。"
        fi
    else
        echo "locations.json 准备就绪。"
    fi

    # 检测 $cfnat_file/cfnat 是否存在
    echo "下载 cfnat 主程序。"
    if [ ! -f ${cfnat_file}/${cfnat_linux} ]; then
        # 如果不存在，则使用 curl 下载文件
        curl -k -SL https://raw.cmliussss.com/cfnat/${cfnat_linux} -o $cfnat_file/cfnat
        if [ $? -eq 0 ]; then
            mv -f "$cfnat_file/cfnat" "$cfnat_file/$cfnat_linux"
            chmod +x $cfnat_file/${cfnat_linux}
            echo "${cfnat_linux} 主程序 下载完成。"
        else
            echo "${cfnat_linux} 下载失败 请检查网络。"
        fi
    else
        echo "${cfnat_linux} 主程序 准备就绪。"
    fi

    echo "下载 IP库 文件。"
    # 检测 $cfnat_file/ips-v4.txt 是否存在
    if [ ! -f ${cfnat_file}/ips-v4.txt ]; then
        # 如果不存在，则使用 curl 下载文件
        curl -k -SL https://raw.cmliussss.com/cfnat/ips-v4.txt -o $cfnat_file/ips-v4.txt
        echo "ips-v4.txt 下载完成。"
    else
        echo "ips-v4.txt 准备就绪。"
    fi

    curl -sSL https://raw.cmliussss.com/cfnat.sh -o ~/cfnat.sh && chmod +x ~/cfnat.sh
    if [ "${Architecture}" != "termux" ] && [ -f ~/cfnat.sh ]; then
        echo -e "设置 ${gl_lv}cfnat${gl_bai} 启动命令"
        cp -f ~/cfnat.sh /usr/local/bin/cfnat > /dev/null 2>&1
        chmod +x /usr/local/bin/cfnat
    fi
}

# 安装colo
install_colo(){
    # 检测 $colo_file 文件夹是否存在
    if [ ! -d $colo_file ]; then
        # 如果不存在，则创建该文件夹
        mkdir $colo_file
        echo "目录 $colo_file 已创建。"
    fi

    # 检测 $colo_file/locations.json 是否存在
    echo "下载 locations.json 文件。"
    if [ ! -f $colo_file/locations.json ]; then
        # 如果不存在，则使用 curl 下载文件
        curl -k -SL https://cf.090227.xyz/locations_cn -o $colo_file/locations.json
        if [ $? -ne 0 ]; then
            curl -k -SL https://raw.cmliussss.com/colo/locations.json -o $colo_file/locations.json
        fi

        if [ $? -ne 0 ]; then
            echo "locations.json 下载失败。"
        else
            echo "locations.json 下载完成。"
        fi
    else
        echo "locations.json 准备就绪。"
    fi

    # 检测 $colo_file/colo 是否存在
    echo "下载 colo 主程序。"
    if [ ! -f ${colo_file}/${colo_linux} ]; then
        # 如果不存在，则使用 curl 下载文件
        curl -k -SL https://raw.cmliussss.com/colo/${colo_linux} -o $colo_file/colo
        if [ $? -eq 0 ]; then
            mv -f "$colo_file/colo" "$colo_file/$colo_linux"
            chmod +x $colo_file/${colo_linux}
            echo "${colo_linux} 主程序 下载完成。"
        else
            echo "${colo_linux} 下载失败 请检查网络。"
        fi
        chmod +x $colo_file/${colo_linux}
        echo "${colo_linux} 主程序 下载完成。"
    else
        echo "${colo_linux} 主程序 准备就绪。"
    fi

    # 检测 $colo_file/ips-v4.txt 是否存在
    echo "下载 IP库 文件。"
    if [ ! -f ${colo_file}/ips-v4.txt ]; then
        # 如果不存在，则使用 curl 下载文件
        curl -k -SL https://raw.cmliussss.com/colo/ips-v4.txt -o $colo_file/ips-v4.txt
        echo "ips-v4.txt 下载完成。"
    else
        echo "ips-v4.txt 准备就绪。"
    fi
}

up_ips() {
    cfnat_ips=$1

    download_and_copy() {
        # 下载文件并检查是否成功
        curl -k -SL https://raw.cmliussss.com/cfnat/ips-v${cfnat_ips}.txt -o $cfnat_file/up_ips.txt
        if [ $? -eq 0 ]; then
            cp -f "$cfnat_file/up_ips.txt" "$cfnat_file/ips-v${cfnat_ips}.txt"
            if [ -d "$colo_file" ]; then
                cp -f "$cfnat_file/up_ips.txt" "$colo_file/ips-v${cfnat_ips}.txt"
            fi
            echo "ips-v${cfnat_ips}.txt 下载完成。"
        else
            echo "下载失败，请检查网络或URL。"
        fi
    }

    # 检测文件是否存在
    if [ -f "${cfnat_file}/ips-v${cfnat_ips}.txt" ]; then
        read -p "IPv${cfnat_ips}库文件已存在，是否重新下载(N): " up_ipss
        up_ipss=${up_ipss^^}  # 将输入转换为大写
        if [ "$up_ipss" = "Y" ]; then
            download_and_copy
        fi
    else
        download_and_copy
    fi

    config_cfnat_write "ips" "$cfnat_ips"
}

# 卸载cfnat
uninstall_cfnat(){
    kill_cfnat
    delete_cron
    rm -rf $cfnat_file
    if [ -f /usr/local/bin/cfnat ]; then
        rm -f /usr/local/bin/cfnat
    fi
    echo "cfnat 已清除。"
    if [ -d "$colo_file" ]; then
        rm -rf $colo_file
        echo "colo 已清除。"
    fi
}

check_cfnat(){
    if grep -q "^Architecture=" "$config_file"; then
        Architecture=$(grep "^Architecture=" "$config_file" | cut -d'=' -f2)
    else
        Architecture=$(archAffix)
        if [ "$Architecture" = "未知"  ]; then
            site_Architecture
        fi
    fi

    if grep -q "^release=" "$config_file"; then
        release=$(grep "^release=" "$config_file" | cut -d'=' -f2)
    elif [ "$Architecture" = "termux" ]; then 
        release="Android"
    else
        if [[ -f /etc/redhat-release ]]; then 
            release="Centos"
        elif grep -q -E -i "openwrt" /etc/os-release 2>/dev/null; then 
            release="OpenWRT"
        elif grep -q -E -i "alpine" /etc/issue 2>/dev/null; then 
            release="Alpine"
        elif grep -q -E -i "debian" /etc/issue 2>/dev/null; then 
            release="Debian"
        elif grep -q -E -i "ubuntu" /etc/issue 2>/dev/null; then 
            release="Ubuntu"
        elif grep -q -E -i "centos|red hat|redhat" /etc/issue 2>/dev/null; then 
            release="Centos"
        elif grep -q -E -i "openwrt" /proc/version 2>/dev/null; then 
            release="OpenWRT"
        elif grep -q -E -i "debian" /proc/version 2>/dev/null; then 
            release="Debian"
        elif grep -q -E -i "ubuntu" /proc/version 2>/dev/null; then 
            release="Ubuntu"
        elif grep -q -E -i "centos|red hat|redhat" /proc/version 2>/dev/null; then 
            release="Centos"
        else  
            site_release
        fi
    fi

    if [ ${Architecture} = "termux" ]; then
        #install net-tools
        lanip=$(ifconfig | grep -Eo 'inet (192\.168|10\.|172\.(1[6-9]|2[0-9]|3[0-1]))[0-9.]+' | awk '{print $2}')
        Androidps="${yellow} 安卓手机推荐使用 ${green}调试运行 ${yellow}来执行任务"
        cfnat_linux="cfnat-termux"
    else
        lanip=$(ip -4 addr | grep -Eo 'inet (192\.168|10\.|172\.(1[6-9]|2[0-9]|3[0-1]))[0-9.]+/[0-9]+' | awk '{print $2}' | cut -d'/' -f1)
        cfnat_linux="cfnat-linux-${Architecture}"
    fi

    # 检测 $cfnat_file 文件夹是否存在
    if [ -d $cfnat_file ]; then
        # 检测 $cfnat_file/${cfnat_linux} 文件是否存在
        if [ -f $cfnat_file/${cfnat_linux} ] && [ -f $cfnat_file/locations.json ]; then
            InstallationStatus="${green}已安装"
            OneclickInstallation="${red}一键卸载"

            if [ -f "$config_file" ]; then
                # 如果存在，读取 colo 字段内容
                cfnat_colo=$(grep '^colo=' "$config_file" | cut -d'=' -f2)
                cfnat_addr=$(grep '^addr=' "$config_file" | cut -d'=' -f2)
                cfnat_delay=$(grep '^delay=' "$config_file" | cut -d'=' -f2)

                cfnat_ipnum=$(grep '^ipnum=' "$config_file" | cut -d'=' -f2)
                cfnat_ips=$(grep '^ips=' "$config_file" | cut -d'=' -f2)
                cfnat_num=$(grep '^num=' "$config_file" | cut -d'=' -f2)
                cfnat_port=$(grep '^port=' "$config_file" | cut -d'=' -f2)
                cfnat_random=$(grep '^random=' "$config_file" | cut -d'=' -f2)
                cfnat_task=$(grep '^task=' "$config_file" | cut -d'=' -f2)
                port139=$(grep '^port139=' "$config_file" | cut -d'=' -f2)
                if [ -n "$port139" ]; then
                    if ! [[ $ipv4_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        for service in ipv4.ip.sb ipv4.ping0.cc; do
                            ipv4_address=$(curl -s --max-time 1 $service)
                            if [[ $ipv4_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                break
                            fi
                        done
                    fi
                    cfnat_addr="10003"
                fi
            fi
            cfnat_colo=${cfnat_colo:-"SJC,LAX,HKG"}
            cfnat_addr=${cfnat_addr:-"1234"}
            cfnat_delay=${cfnat_delay:-"300"}

            cfnat_ipnum=${cfnat_ipnum:-"10"}
            cfnat_ips=${cfnat_ips:-"4"}
            cfnat_num=${cfnat_num:-"10"}
            cfnat_port=${cfnat_port:-"443"}
            cfnat_random=${cfnat_random:-"true"}
            cfnat_task=${cfnat_task:-"100"}
            # 如果不存在，创建配置文件并写入内容
            config_cfnat_write "colo" "$cfnat_colo"
            config_cfnat_write "addr" "$cfnat_addr"
            config_cfnat_write "delay" "$cfnat_delay"

            config_cfnat_write "ipnum" "$cfnat_ipnum"
            config_cfnat_write "ips" "$cfnat_ips"
            config_cfnat_write "num" "$cfnat_num"
            config_cfnat_write "port" "$cfnat_port"
            config_cfnat_write "random" "$cfnat_random"
            config_cfnat_write "task" "$cfnat_task"
        else
            InstallationStatus="${red}未安装"
            OneclickInstallation="${green}一键安装"
        fi
    else
        InstallationStatus="${red}未安装"
        OneclickInstallation="${green}一键安装"
    fi

    if [ "$release" = "OpenWRT" ]; then
        cfnat_pid=$(pgrep -f "./${cfnat_linux}")
        # 检查是否找到了 PID
        if [ -n "$cfnat_pid" ]; then
            statecfnat="${green}运行中 PID:${cfnat_pid}"
        else
            statecfnat="${red}未运行"
        fi
    else
        # 检测 $cfnat_file/cfnat 程序是否正在运行
        if pgrep -f "cfnat-" > /dev/null; then
            # 如果正在运行，赋值
            statecfnat="${green}运行中"
        else
            # 如果未运行，赋值
            statecfnat="${red}未运行"
        fi
    fi

    if [ "${Architecture}" != "termux" ] && [ ! -f /usr/local/bin/cfnat ] && [ "${InstallationStatus}" = "${green}已安装" ] && [ -f ~/cfnat.sh ]; then
        echo -e "设置 ${gl_lv}cfnat${gl_bai} 启动命令"
        cp -f ~/cfnat.sh /usr/local/bin/cfnat > /dev/null 2>&1
        chmod +x /usr/local/bin/cfnat
    fi

    # 加载 DDNS 配置
    if [ -f "$ddns_config_file" ]; then
        cloudflare_email=$(grep '^cloudflare_email=' "$ddns_config_file" | cut -d'=' -f2)
        cloudflare_api_key=$(grep '^cloudflare_api_key=' "$ddns_config_file" | cut -d'=' -f2)
        cloudflare_zone_id=$(grep '^cloudflare_zone_id=' "$ddns_config_file" | cut -d'=' -f2)
        cloudflare_record_name=$(grep '^cloudflare_record_name=' "$ddns_config_file" | cut -d'=' -f2)
    fi
}

add_cron(){
    if [ "${Architecture}" != "termux" ]; then
        delete_cron
        cron_cfnat="*/5 * * * * cd ~ && bash cfnat.sh $cfnat_colo"
        cron_colo="* */6 * * * cd ~ && bash cfnat.sh colo"
        (crontab -l; echo "$cron_cfnat") | crontab -
        echo "添加 crontab 守护任务 $cron_cfnat"

        if [ -f ${colo_file}/${colo_linux} ]; then
            (crontab -l; echo "$cron_colo") | crontab -
            echo "添加 crontab 守护任务 $cron_colo"
        fi

    fi
}

delete_cron(){
    if [ "${Architecture}" != "termux" ]; then
        crontab -l | grep -v 'bash cfnat.sh' | crontab -
        crontab -l | grep -v 'bash cfnat.sh' | crontab -
        echo "清理 crontab 守护任务"
    fi
}

config_cfnat_write(){
    if grep -q "^$1=" "$config_file"; then
        sed -i "s/^$1=.*/$1=$2/" "$config_file"
    else
        echo "$1=$2" >> "$config_file"
    fi
}

# 写入 DDNS 配置到文件
config_cfnat_write_ddns(){
    if grep -q "^$1=" "$ddns_config_file"; then
        sed -i "s/^$1=.*/$1=$2/" "$ddns_config_file"
    else
        echo "$1=$2" >> "$ddns_config_file"
    fi
}

config_cfnat(){
    stty erase '^H'  # 设置退格键
    echo "电信/联通 推荐 SJC,LAX"
    echo "移动/广电 推荐 HKG"
    # 读取并处理数据中心输入
    read -p "输入筛选数据中心（多个数据中心用逗号隔开，留空则使用 SJC,LAX,HKG）: " colo
    colo=${colo:-"SJC,LAX,HKG"}
    colo=${colo^^}
    # 更新配置文件中的 colo 参数
    config_cfnat_write "colo" "$colo"

    # 读取并处理端口输入
    echo ""
    read -p "输入本地监听端口（默认 1234）: " addr
    addr=${addr:-1234}
    # 更新配置文件中的 port 参数
    config_cfnat_write "addr" "$addr"

    # 读取并处理延迟输入
    echo ""
    echo "电信/联通 有效延迟推荐 300"
    echo "移动/广电 有效延迟可尝试 100"
    read -p "输入有效延迟（毫秒），超过此延迟将断开连接（默认 300）: " delay
    delay=${delay:-300}
    # 更新配置文件中的 delay 参数
    config_cfnat_write "delay" "$delay"

    read -p "是否高级设置（默认 N）: " cfnat_config_plus
    if [ "${cfnat_config_plus^^}" = "Y" ]; then
        echo ""
        read -p "转发的目标端口（默认 443）: " port
        port=${port:-443}
        config_cfnat_write "port" "$port"

        echo ""
        read -p "是否随机生成IP（默认 Y）: " random_config
        if [ "${random_config^^}" = "N" ] || [ "${random_config^^}" = "NO" ]; then
            random="false"
        else
            random="true"
        fi
        config_cfnat_write "random" "$random"

        echo ""
        read -p "提取的有效IP数量（默认 10）: " ipnum
        ipnum=${ipnum:-10}
        config_cfnat_write "ipnum" "$ipnum"

        echo ""
        read -p "目标负载IP数量（默认 10）: " num
        num=${num:-10}
        config_cfnat_write "num" "$num"

        echo ""
        read -p "并发请求最大协程数（默认 100）: " task
        task=${task:-100}
        config_cfnat_write "task" "$task"
    fi
    stty sane  # 恢复终端设置
}

# 配置 Cloudflare DDNS
config_cloudflare_ddns() {
    clear
    echo -e "${yellow}------------------------------------${re}"
    echo -e "${yellow}        Cloudflare DDNS 配置        ${re}"
    echo -e "${yellow}------------------------------------${re}"

    # 检查 jq 是否安装
    if ! command -v jq &>/dev/null; then
        echo -e "${red}未检测到 jq，正在尝试安装...${re}"
        install jq
        if ! command -v jq &>/dev/null; then
            echo -e "${red}jq 安装失败，无法进行 Cloudflare DDNS 配置。请手动安装 jq。${re}"
            break_end
            return 1
        fi
        echo -e "${green}jq 安装成功。${re}"
    fi

    # 加载现有配置
    local current_email=""
    local current_api_key=""
    local current_zone_id=""
    local current_record_name=""

    if [ -f "$ddns_config_file" ]; then
        current_email=$(grep '^cloudflare_email=' "$ddns_config_file" | cut -d'=' -f2)
        current_api_key=$(grep '^cloudflare_api_key=' "$ddns_config_file" | cut -d'=' -f2)
        current_zone_id=$(grep '^cloudflare_zone_id=' "$ddns_config_file" | cut -d'=' -f2)
        current_record_name=$(grep '^cloudflare_record_name=' "$ddns_config_file" | cut -d'=' -f2)
    fi

    echo -e "${yellow}当前 Cloudflare DDNS 配置:${re}"
    echo -e "${yellow}  邮箱: ${green}${current_email:-未设置}${re}"
    echo -e "${yellow}  API Key: ${green}${current_api_key:-未设置}${re}"
    echo -e "${yellow}  Zone ID: ${green}${current_zone_id:-未设置}${re}"
    echo -e "${yellow}  记录名称: ${green}${current_record_name:-未设置}${re}"
    echo "------------------------------------"

    read -p "是否要更新这些配置？(Y/N，默认 N): " update_choice
    update_choice=${update_choice^^} # 转换为大写

    local new_email="$current_email"
    local new_api_key="$current_api_key"
    local new_zone_id="$current_zone_id"
    local new_record_name="$current_record_name"

    if [ "$update_choice" = "Y" ]; then
        clear
        echo -e "${yellow}------------------------------------${re}"
        echo -e "${yellow}        Cloudflare DDNS 配置        ${re}"
        echo -e "${yellow}------------------------------------${re}"
        echo -e "${yellow}请提供您的 Cloudflare API 信息。${re}"
        echo -e "${yellow}您可以在 Cloudflare 仪表板中找到这些信息。${re}"
        echo "获取 API Key: [Cloudflare API Keys](https://dash.cloudflare.com/profile/api-tokens)"
        echo "获取 Zone ID: 在您的域名概述页面右侧边栏"
        echo "------------------------------------"

        # 邮箱
        read -p "当前邮箱: ${green}${current_email:-未设置}${re}，是否修改？(Y/N，默认 N): " modify_email
        modify_email=${modify_email^^}
        if [ "$modify_email" = "Y" ]; then
            read -p "输入 Cloudflare 注册邮箱: " temp_email
            new_email="${temp_email}"
        fi

        # Global API Key
        read -p "当前 Global API Key: ${green}${current_api_key:-未设置}${re}，是否修改？(Y/N，默认 N): " modify_api_key
        modify_api_key=${modify_api_key^^}
        if [ "$modify_api_key" = "Y" ]; then
            read -p "输入 Cloudflare Global API Key: " temp_api_key
            new_api_key="${temp_api_key}"
        fi

        # Zone ID
        read -p "当前 Zone ID: ${green}${current_zone_id:-未设置}${re}，是否修改？(Y/N，默认 N): " modify_zone_id
        modify_zone_id=${modify_zone_id^^}
        if [ "$modify_zone_id" = "Y" ]; then
            read -p "输入您的 Zone ID: " temp_zone_id
            new_zone_id="${temp_zone_id}"
        fi

        # DNS 记录名称
        read -p "当前 DNS 记录名称: ${green}${current_record_name:-未设置}${re}，是否修改？(Y/N，默认 N): " modify_record_name
        modify_record_name=${modify_record_name^^}
        if [ "$modify_record_name" = "Y" ]; then
            read -p "输入要更新的 DNS 记录名称 (例如: example.com 或 sub.example.com): " temp_record_name
            new_record_name="${temp_record_name}"
        fi

        # 保存配置到文件
        mkdir -p "$cfnat_file" # 确保目录存在
        touch "$ddns_config_file" # 确保文件存在

        config_cfnat_write_ddns "cloudflare_email" "$new_email"
        config_cfnat_write_ddns "cloudflare_api_key" "$new_api_key"
        config_cfnat_write_ddns "cloudflare_zone_id" "$new_zone_id"
        config_cfnat_write_ddns "cloudflare_record_name" "$new_record_name"

        echo -e "${green}Cloudflare DDNS 配置已保存到 $ddns_config_file ${re}"
        echo -e "${green}请确保您输入的 API 信息是正确的。${re}"
    else
        echo -e "${yellow}已取消配置更新，返回主菜单。${re}"
    fi
    break_end
    return 0
}

# 获取 DNS 记录 ID
get_dns_record_id() {
    local record_type=$1
    local record_name=$2
    local zone_id=$cloudflare_zone_id
    local email=$cloudflare_email
    local api_key=$cloudflare_api_key

    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=${record_type}&name=${record_name}" \
        -H "X-Auth-Email: ${email}" \
        -H "X-Auth-Key: ${api_key}" \
        -H "Content-Type: application/json")

    echo "$response" | jq -r '.result[] | select(.name=="'${record_name}'") | .id' | head -n 1
}

# 更新 Cloudflare DNS
update_cloudflare_dns() {
    local new_ip=$1
    local record_type=""

    if [[ "$new_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        record_type="A"
    elif [[ "$new_ip" =~ ^([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{1,4})?(:[0-9a-fA-F]{1,4}){0,2}$ ]]; then
        record_type="AAAA"
    else
        echo -e "${red}无效的 IP 地址格式: ${new_ip}${re}"
        return 1
    fi

    local record_id=$(get_dns_record_id "$record_type" "$cloudflare_record_name")
    local zone_id=$cloudflare_zone_id
    local email=$cloudflare_email
    local api_key=$cloudflare_api_key

    if [ -z "$record_id" ]; then
        echo -e "${yellow}未找到现有的 ${record_type} 记录，正在创建新的记录...${re}"
        response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${email}" \
            -H "X-Auth-Key: ${api_key}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'"${record_type}"'","name":"'"${cloudflare_record_name}"'","content":"'"${new_ip}"'","ttl":1,"proxied":false}')
    else
        echo -e "${yellow}正在更新现有的 ${record_type} 记录 (ID: ${record_id})...${re}"
        response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${email}" \
            -H "X-Auth-Key: ${api_key}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'"${record_type}"'","name":"'"${cloudflare_record_name}"'","content":"'"${new_ip}"'","ttl":1,"proxied":false}')
    fi

    if echo "$response" | jq -e '.success' >/dev/null; then
        echo -e "${green}Cloudflare DNS ${record_type} 记录已成功更新为: ${new_ip}${re}"
        
        # 检查并删除其他 IP 类型的旧记录 (例如，如果是 IPv4，删除同名的 IPv6 记录)
        if [ "$record_type" = "A" ]; then
            local old_aaaa_id=$(get_dns_record_id "AAAA" "$cloudflare_record_name")
            if [ -n "$old_aaaa_id" ]; then
                echo -e "${yellow}检测到旧的 AAAA 记录，正在删除...${re}"
                curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${old_aaaa_id}" \
                    -H "X-Auth-Email: ${email}" \
                    -H "X-Auth-Key: ${api_key}" \
                    -H "Content-Type: application/json" >/dev/null
                echo -e "${yellow}旧的 AAAA 记录已删除。${re}"
            fi
        elif [ "$record_type" = "AAAA" ]; then
            local old_a_id=$(get_dns_record_id "A" "$cloudflare_record_name")
            if [ -n "$old_a_id" ]; then
                echo -e "${yellow}检测到旧的 A 记录，正在删除...${re}"
                curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${old_a_id}" \
                    -H "X-Auth-Email: ${email}" \
                    -H "X-Auth-Key: ${api_key}" \
                    -H "Content-Type: application/json" >/dev/null
                echo -e "${yellow}旧的 A 记录已删除。${re}"
            fi
        fi

    else
        echo -e "${red}Cloudflare DNS 更新失败！${re}"
        echo -e "${red}错误信息: $(echo "$response" | jq -r '.errors[].message')${re}"
    fi
}


kill_cfnat(){
    cfnat_pid=$(pgrep -f "cfnat-")
    
    if [ -n "$cfnat_pid" ]; then
        full_process_name=$(ps -p $cfnat_pid -o comm=)
        echo "$cfnat_linux 进程正在运行，准备杀死进程..."
        if [ "$release" = "OpenWRT" ]; then
            kill "$cfnat_pid"
        else
            pkill -f "$full_process_name"
        fi
        echo -e "${red}./${cfnat_linux} 进程已被杀死。${re}"
    #else
        #echo "./${cfnat_linux} 进程未在运行。"
    fi
}

go_cfnat(){
    if [ "$OneclickInstallation" = "${green}一键安装" ]; then
        install_cfnat
    fi
    check_cfnat
    if [ -d "$colo_file" ]; then
        cp -f "$colo_file/ips-v${cfnat_ips}.txt" "$cfnat_file/ips-v${cfnat_ips}.txt"
    fi
    # 将 cfnat 的输出重定向到 cfnat_output.log 文件
    cd "$cfnat_file" && nohup ./${cfnat_linux} -colo=$cfnat_colo -port=$cfnat_port -delay=$cfnat_delay -ips="$cfnat_ips" -addr="0.0.0.0:$cfnat_addr" -ipnum=$cfnat_ipnum -num=$cfnat_num -random=$cfnat_random -task=$cfnat_task -tls=$cfnat_tls_TF > "$cfnat_file/cfnat_output.log" 2>&1 &
}

state_cfnat(){
    echo -e "${yellow} 系统: ${re}${release}${re}"
    echo -e "${yellow} 架构: ${re}${Architecture}${re}"
    echo -e "${yellow} IP类型: ${green}IPv${cfnat_ips}${re}"
    echo -e "${yellow} 随机IP: ${re}${cfnat_random^^}${re}"
    echo -e "${yellow} 数据中心: ${re}${cfnat_colo}${re}"
    echo -e "${yellow} 有效延迟: ${re}${cfnat_delay}ms${re}"

    case "$cfnat_port" in
        80|8080|8880|2052|2082|2086|2095)
            cfnat_tls="noTLS"
            cfnat_tls_TF="false"
            ;;
        *)
            cfnat_tls="TLS"
            cfnat_tls_TF="true"
            ;;
    esac
    echo -e "${yellow} 转发端口: ${re}${cfnat_port} ${cfnat_tls}${re}"
    echo -e "${yellow} 有效IP数: ${re}${cfnat_ipnum}${re}"
    echo -e "${yellow} 负载IP数: ${re}${cfnat_num}${re}"
    echo -e "${yellow} 最大并发请求数: ${re}${cfnat_task}${re}"

    echo -e "${yellow} 本地服务: ${re}127.0.0.1:${cfnat_addr}${re}"
    #echo -e "${yellow} 内网服务: ${re}${lanip}:${cfnat_addr}${re}"
    # 将lanip转成数组
    IFS=$'\n' read -rd '' -a ip_array <<< "$lanip"

    # 输出结果
    if [ ${#ip_array[@]} -eq 1 ]; then
        echo -e "${yellow} 内网服务: ${re}${ip_array[0]}:$cfnat_addr${reset}"
    else
        echo -e "${yellow} 内网服务: ${re}${ip_array[0]}:$cfnat_addr${reset}"
        for i in "${!ip_array[@]}"; do
            if [ $i -ne 0 ]; then
                echo "           ${ip_array[$i]}:$cfnat_addr"
            fi
        done
    fi

    if [ -n "$port139" ]; then
        echo -e "${yellow} 转发服务: ${re}${ipv4_address}:${port139}${re}"
    fi
}

site_release(){
    stty erase '^H'  # 设置退格键
    echo -e "${yellow} 设置系统信息...${re}"
    echo -e "${yellow} 1. ${re}Alpine"
    echo -e "${yellow} 2. ${re}Centos"
    echo -e "${yellow} 3. ${re}Debian"
    echo -e "${yellow} 4. ${re}Ubuntu"
    echo -e "${yellow} 5. ${re}OpenWRT"
    read -p $'\033[1;91m请输入你的选择（默认 OpenWRT）: \033[0m' choice_release
    # 根据用户选择赋值给 release 变量
    case $choice_release in
        1)
            release="Alpine"
            ;;
        2)
            release="Centos"
            ;;
        3)
            release="Debian"
            ;;
        4)
            release="Ubuntu"
            ;;
        5)
            release="OpenWRT"
            ;;
        *)
            release="Debian"  # 默认值
            ;;
    esac

    config_cfnat_write "release" "$release"

    echo "你选择的系统是: $release"
    stty sane  # 恢复终端设置
}

site_Architecture(){
    stty erase '^H'  # 设置退格键
    echo -e "${yellow} 设置架构信息...${re}"
    echo -e "${yellow} 1. ${re}termux （安卓termux）"
    echo -e "${yellow} 2. ${re}386 （老古董 32位x86软路由）"
    echo -e "${yellow} 3. ${re}amd64 （64位x86软路由虚拟机）"
    echo -e "${yellow} 4. ${re}armv5"
    echo -e "${yellow} 5. ${re}armv6"
    echo -e "${yellow} 6. ${re}armv7"
    echo -e "${yellow} 7. ${re}arm64 （硬路由刷机OpenWRT）"
    echo -e "${yellow} 8. ${re}mips"
    echo -e "${yellow} 9. ${re}mips64"
    echo -e "${yellow} 10. ${re}mips64le"
    echo -e "${yellow} 11. ${re}mipsle"
    echo -e "${yellow} 12. ${re}ppc64"
    echo -e "${yellow} 13. ${re}ppc64le"
    echo -e "${yellow} 14. ${re}riscv64"
    echo -e "${yellow} 15. ${re}s390x"
    read -p $'\033[1;91m请输入你的选择（默认 amd64）: \033[0m' choice_Architecture
    # 根据用户选择赋值给 release 变量
    case $choice_Architecture in
        1) Architecture="termux" ;;
        2) Architecture="386" ;;
        3) Architecture="amd64" ;;
        4) Architecture="armv5"  ;;
        5) Architecture="armv6" ;;
        6) Architecture="armv7" ;;
        7) Architecture="arm64" ;;
        8) Architecture="mips" ;;
        9) Architecture="mips64" ;;
        10) Architecture="mips64le" ;;
        11) Architecture="mipsle" ;;
        12) Architecture="ppc64" ;;
        13) Architecture="ppc64le" ;;
        14) Architecture="riscv64" ;;
        15) Architecture="s390x" ;;
        *) Architecture="amd64" ;; # 默认值
    esac

    config_cfnat_write "Architecture" "$Architecture"

    echo "你选择的架构是: $Architecture"
    stty sane  # 恢复终端设置
}

install139() {
    pkill httpd
    #rm -rf /data/139
    #mkdir /data/139
    #wget -q -O /data/139/httpd "https://raw.cmliussss.com/139/busybox"
    curl -sSL https://raw.cmliussss.com/139/busybox -o $cfnat_file/httpd
    chmod +x $cfnat_file/httpd
    $cfnat_file/httpd -p 10003
    httpdstatus=$(ps -ef | grep httpd | grep -v grep | awk '{print $2}')
    if [[ $httpdstatus ]]; then
        echo -e "${green} httpd 启动成功${re}"
    else
        echo -e "${red} httpd 启动失败${re}"
        uninstall139
        #exit
    fi
}

uninstall139() {
    #echo -e "${YELLOW}======回车删除环境======${NC}"
    #read
    pkill httpd
    #rm -rf /data/139
}

# 监控 cfnat 日志并同步 DNS
monitor_and_sync_ddns() {
    local cfnat_output_log="$cfnat_file/cfnat_output.log"
    local last_synced_ip=""  # 记录上次同步的 IP

    # 检查 cfnat 是否正在运行，如果未运行则尝试启动
    if pgrep -f "cfnat-" > /dev/null; then
        echo -e "${green}cfnat 已经在运行。${re}"
    else
        echo -e "${yellow}cfnat 未运行，正在尝试启动 cfnat...${re}"
        go_cfnat # 调用启动 cfnat 的函数
        # 等待一小段时间，确保 cfnat 启动并开始写入日志
        sleep 5 
        if ! pgrep -f "cfnat-" > /dev/null; then
            echo -e "${red}无法启动 cfnat。请检查 cfnat 配置或手动启动。${re}"
            break_end
            return 1
        fi
        echo -e "${green}cfnat 已成功启动。${re}"
    fi

    if [ ! -f "$cfnat_output_log" ]; then
        echo -e "${red}cfnat 日志文件 ($cfnat_output_log) 不存在，DDNS 监控无法启动。${re}"
        break_end
        return 1
    fi

    echo -e "${yellow}开始监控 cfnat 日志并同步 Cloudflare DNS... (按 Ctrl+C 停止)${re}"
    tail -F "$cfnat_output_log" 2>/dev/null | \
    while IFS= read -r line; do
        echo "$line"
        current_best_ip=$(echo "$line" | grep -oP '(?<=选择最佳连接: 地址: )(\[[0-9A-Fa-f:]+\]|[0-9.]+)(?=:)')
        current_best_ip=${current_best_ip//[\[\]]/}

        # 只在 IP 变动时才同步
        if [ -n "$current_best_ip" ] && [ "$current_best_ip" != "$last_synced_ip" ]; then
            echo -e "${green}检测到新的最佳IP: $current_best_ip${re}"
            # 在后台执行 update_cloudflare_dns，不阻塞当前循环
            update_cloudflare_dns "$current_best_ip" &
            last_synced_ip="$current_best_ip"
        fi
    done
}

# 停止 DDNS 监控 (仅在有后台进程时才需要，但当前实现是前台运行，此函数主要用于清除历史状态或辅助菜单逻辑)
stop_ddns_monitor() {
    echo -e "${yellow}请手动按 Ctrl+C 退出当前正在运行的 DDNS 监控程序。${re}"
    # 如果未来改成后台运行，这里会是杀死进程的逻辑
    break_end
}

#########################梦开始的地方##############################
#无交互执行

if [ -n "$1" ]; then 
    check_cfnat
    if [ "$1" = "colo" ] && [ -f ${colo_file}/${colo_linux} ]; then
        cd $colo_file && ./${colo_linux} -ips="$cfnat_ips" -random=$cfnat_random -task=$cfnat_task
    else
        if [ "$OneclickInstallation" = "${green}一键安装" ]; then
            install_cfnat
            #if [ "${Architecture}" != "termux" ]; then
                #install_colo
            #fi
        fi
        cfnat_colo=${1^^}
        # 检测配置文件是否存在
        if [ -f "$config_file" ]; then
            # 如果存在，读取 colo 字段内容
            colo=$(grep '^colo=' "$config_file" | cut -d'=' -f2)
            if [ "$cfnat_colo" = "$colo" ] && [ ! "$statecfnat" = "${red}未运行" ]; then
                state_cfnat
                echo -e "${green}cfnat 正在运行...${re}"
                exit
            else
                kill_cfnat
            fi
        fi
        config_cfnat_write "colo" "$cfnat_colo"

        cd "$cfnat_file" && nohup ./${cfnat_linux} -colo=$cfnat_colo -port=$cfnat_port -delay=$cfnat_delay -ips="$cfnat_ips" -addr="0.0.0.0:$cfnat_addr" -ipnum=$cfnat_ipnum -num=$cfnat_num -random=$cfnat_random -task=$cfnat_task -tls=$cfnat_tls_TF > "$cfnat_file/cfnat_output.log" 2>&1 & # 将日志重定向到文件
        #echo "nohup ./cfnat -colo HKG -port 443 -delay 200 -ips 4 -addr "0.0.0.0:1234" >/dev/null 2>&1 &"
        state_cfnat
        echo -e "${green}cfnat 开始执行...${re}"
    fi
else
    while true; do
    check_cfnat
    clear
    echo -e "${yellow}           .o88o.  ${gl_kjlan}                         .   "
    echo -e "${yellow}           888 \`\"${gl_kjlan}                         .o8   "
    echo -e "${yellow} .ooooo.  o888oo  ${gl_kjlan}ooo. .oo.    .oooo.   .o888oo "
    echo -e "${yellow}d88' \`\"Y8  888  ${gl_kjlan}  \`888P\"Y88b  \`P  )88b    888   "
    echo -e "${yellow}888        888    ${gl_kjlan} 888   888   .oP\"888    888   ${re}"
    echo -e "${yellow}888   .o8  888    ${gl_kjlan} 888   888  d8(  888    888 . ${re}原作者: https://t.me/CF_NAT/38840"
    echo -e "${yellow}\`Y8bod8P' o888o  ${gl_kjlan} o888o o888o \`Y888\"\"8o   \"888\" ${re}版本号: v${sh_v}"
    if [ -f /usr/local/bin/cfnat ]; then
        echo "--------------------------------"
        echo -e "${gl_kjlan}快捷键已设置为 ${yellow}cfnat${re} ${gl_kjlan},下次运行输入 ${yellow}cfnat${re} ${gl_kjlan}可快速启动此脚本${re}"
    fi
    echo "--------------------------------"
    echo -e "${yellow} 状态: ${InstallationStatus} ${statecfnat} ${re}"
    state_cfnat
    echo "--------------------------------"
    echo -e "${yellow} 1. ${OneclickInstallation}${re}"
    echo "--------------------------------"

    if [ "$OneclickInstallation" = "${red}一键卸载" ]; then

        if [ "${Architecture}" != "termux" ]; then
            echo -e "${yellow} 2. 启动 cfnat ${re}"
            echo -e "${yellow} 3. 停止 cfnat ${re}"
            echo -e "${yellow} 4. 重启 cfnat ${re}"
        fi

        echo -e "${yellow} 5. 配置 cfnat ${ps}${re}"
        echo "--------------------------------"
        echo -e "${yellow} 6. ${green}调试运行 cfnat ${re} ${Androidps}${re}"
        echo -e "${yellow} 7. 手动设置系统架构${re}"
        echo "--------------------------------"

        if [ "${cfnat_ips}" = "4" ]; then
            up_cfnat_ips="6"
        else
            up_cfnat_ips="4"
        fi
        echo -e "${yellow} 8. IP类型 更改为 ${green}IPv${up_cfnat_ips}${re}"
        echo "--------------------------------"
        echo -e "${yellow} 9. ${gl_kjlan}脚本更新${re}"
        echo -e "${yellow} 10. Cloudflare DDNS 自动同步配置${re}"
        echo -e "${yellow} 11. 启动 Cloudflare DDNS 监控${re}"
        echo -e "${yellow} 12. 停止 Cloudflare DDNS 监控${re}" # 此选项现在主要是提示用户如何退出
    fi
    #echo "--------------------------------"
    echo -e "\033[0;97m 0. 退出脚本"
    echo -e "${yellow}--------------------------------${re}"
    ps=""
    siteps=""
    stty erase '^H'  # 设置退格键
    read -p $'\033[1;91m请输入你的选择: \033[0m' choice
    stty sane  # 恢复终端设置
    case $choice in
        1)
            clear
            if [ "$OneclickInstallation" = "${red}一键卸载" ]; then
                uninstall_cfnat
            else
                install_cfnat
                #if [ "${Architecture}" != "termux" ]; then
                    #install_colo
                #fi
            fi
        ;;
        2)
            if [ ! "$statecfnat" = "${red}未运行" ]; then
                echo -e "$cfnat_linux $statecfnat"
            else
                if [ ! -f "$config_file" ]; then
                    config_cfnat
                fi
                go_cfnat
                add_cron
            fi
        ;;
        3)
            kill_cfnat
            delete_cron
        ;;
        4)
            kill_cfnat
            go_cfnat
            add_cron
        ;;
        5)
            if [ "$OneclickInstallation" = "${green}一键安装" ]; then
                install_cfnat
            fi
            config_cfnat
            ps="${red}完成配置后需重启cfnat才能生效！"
        ;;
        6)
            if [ "$OneclickInstallation" = "${green}一键安装" ]; then
                install_cfnat
            elif [ ! "$statecfnat" = "${red}未运行" ]; then
                kill_cfnat
                delete_cron
            fi
            if [ -d "$colo_file" ]; then
                cp -f "$colo_file/ips-v${cfnat_ips}.txt" "$cfnat_file/ips-v${cfnat_ips}.txt"
            fi
            cd "$cfnat_file" && ./${cfnat_linux} -colo=$cfnat_colo -port=$cfnat_port -delay=$cfnat_delay -ips="$cfnat_ips" -addr="0.0.0.0:$cfnat_addr" -ipnum=$cfnat_ipnum -num=$cfnat_num -random=$cfnat_random -task=$cfnat_task -tls=$cfnat_tls_TF
        ;;
        7)  
            kill_cfnat
            delete_cron
            site_release
            site_Architecture
            echo -e "${red}设置完成后需卸载重装 cfnat 才能生效！"
            check_cfnat
            install_cfnat
        ;;
        8)
            if [ "${cfnat_ips}" = "4" ]; then
                up_ips "6"
            else
                up_ips "4"
            fi
        ;;
        9) cfnat_update ;;
        10) config_cloudflare_ddns ;;
        11) monitor_and_sync_ddns ;;
        12) stop_ddns_monitor ;;
        139)
            #if [[ ! $(id -u) == '0' ]]; then
            #    echo -e "${red}ROOT?${re} 需要开启ROOT权限"
            #else
                echo -e "${yellow}========安装环境========${re}"
                install139
                ipv4_address=$(curl -s --max-time 1 ipv4.ip.sb)
                if [[ ! $ipv4_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    ipv4_address=$(curl -s --max-time 1 ipv4.ping0.cc)
                fi
                echo -e " 当前IP: ${green}${ipv4_address}${re}"
                echo " 开始探测端口"
                echo -e "${yellow}========等待一会========${re}"
                for a in {000..999}; do
                    a="10${a}"
                    url="http://${ipv4_address}:${a}"
                    status=$(curl --connect-timeout 0.1 --max-time 0.1 -o /dev/null -s -w "%{http_code}" "${url}")
                    if [[ ${status} == '404' ]]; then
                        port139=${a}
                        break
                    fi
                done
                if [[ ${port139} ]]; then
                    echo -e " 端口：10002 ———— ${green}$((${port139} - 1))${re}"
                    echo -e " 端口：10003 ———— ${green}${port139}${re}"
                    config_cfnat_write "port139" "$port139"
                    echo -e " 端口：10004 ———— ${green}$((${port139} + 1))${re}"
                else
                    echo '========================'
                    echo -e "${red}未找到可用端口${re}"
                fi
                uninstall139
                read -p "执行完毕！未能找到该脚本出处，云致谢！"
            #fi
        ;;
        0)
            clear
            exit
        ;;
        *)
            read -p "无效的输入!"
            ps=""
        ;;
    esac
        break_end
    done
fi
