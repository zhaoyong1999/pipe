#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/pipe pop.sh"


SOLANA_ADDRESS=$1
# 部署 pipe pop 函数
function deploy_pipe_pop() {
    # 检测 DevNet 1 节点服务是否正在运行
    if systemctl is-active --quiet dcdnd.service; then
        echo "DevNet 1 节点服务正在运行，正在停止并禁用该服务..."
        sudo systemctl stop dcdnd.service
        sudo systemctl disable dcdnd.service
    else
        echo "DevNet 1 节点服务未运行，无需操作。"
    fi

    # # 配置防火墙，允许 TCP 端口 8003
    # echo "配置防火墙，允许 TCP 端口 8003..."
    # sudo ufw allow 8003/tcp
    # sudo ufw reload
    # echo "防火墙已更新，允许 TCP 端口 8003。"

    # 安装环境
    echo "正在安装 环境..."
    sudo apt-get update
    sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang aria2 bsdmainutils ncdu unzip libleveldb-dev -y

    # 创建下载缓存目录
    mkdir -p /root/pipenetwork
    mkdir -p /root/pipenetwork/download_cache
    cd /root/pipenetwork

    # 询问用户是否使用白名单
    echo "请选择下载链接类型："
    echo "1) 使用白名单下载链接"
    echo "2) 使用默认下载链接"
    # read -p "请输入选择（1 或 2）： " USE_WHITELIST
    USE_WHITELIST='2'
    if [[ "$USE_WHITELIST" == "1" ]]; then
        # 让用户填写白名单 URL
        read -p "请输入白名单下载链接： " DOWNLOAD_URL
        echo "使用白名单链接下载文件..."
        curl -L -o pop "$DOWNLOAD_URL"
    else
        # 使用默认的 curl 下载链接
        echo "尝试使用 curl 下载文件..."
        if ! curl -L -o pop "https://dl.pipecdn.app/v0.2.5/pop"; then
            echo "curl 下载失败，尝试使用 wget..."
            wget -O pop "https://dl.pipecdn.app/v0.2.5/pop"
        fi
    fi

    # 修改文件权限
    chmod +x pop
    
    echo "下载完成，文件名为 pop，已赋予执行权限，并创建了 download_cache 目录。"

    # 让用户输入邀请码，如果未输入，则使用默认邀请码
    # read -p "请输入邀请码（默认：b06fe87c32aa189）：" REFERRAL_CODE
    REFERRAL_CODE=${REFERRAL_CODE:-949fb09adc080402}  # 如果用户没有输入，则使用默认邀请码

    # 输出使用的邀请码
    echo "使用的邀请码是：$REFERRAL_CODE"

    # 执行 ./pop 命令并传递邀请码
    ./pop --signup-by-referral-route $REFERRAL_CODE

    # 让用户输入内存大小、磁盘大小和 Solana 地址，设置默认值
    # read -p "请输入分配内存大小（默认：4，单位：GB）：" MEMORY_SIZE
    MEMORY_SIZE=${MEMORY_SIZE:-4}  # 如果用户没有输入，则使用默认值 4
    MEMORY_SIZE="${MEMORY_SIZE}"  # 确保单位为 G

    # read -p "请输入分配磁盘大小（默认：100，单位：GB）：" DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-200}  # 如果用户没有输入，则使用默认值 100
    DISK_SIZE="${DISK_SIZE}"  # 确保单位为 G

    # read -p "请输入 Solana 地址： " SOLANA_ADDRESS

    # 创建 systemd 服务文件
    SERVICE_FILE="/etc/systemd/system/pipe-pop.service"
    echo "[Unit]
Description=Pipe POP Node Service
After=network.target
Wants=network-online.target

[Service]
User=root
Group=root
ExecStart=/root/pipenetwork/pop --ram=$MEMORY_SIZE --pubKey $SOLANA_ADDRESS --max-disk $DISK_SIZE --cache-dir /var/cache/pop/download_cache
Restart=always
RestartSec=5
LimitNOFILE=65536
LimitNPROC=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dcdn-node
WorkingDirectory=/root/pipenetwork

[Install]
WantedBy=multi-user.target" | sudo tee $SERVICE_FILE > /dev/null

    # 重新加载 systemd 配置
    sudo systemctl daemon-reload

    # 启动并设置服务开机启动
    sudo systemctl start pipe-pop.service
    sudo systemctl enable pipe-pop.service

    # 提示用户服务已启动
    echo "Pipe POP 服务已启动并配置为开机启动。"
    echo "使用以下命令查看服务状态："
    echo "  sudo systemctl status pipe-pop.service"
    echo "使用以下命令停止服务："
    echo "  sudo systemctl stop pipe-pop.service"
    echo "使用以下命令重新启动服务："
    echo "  sudo systemctl restart pipe-pop.service"

    # 查看服务状态，并提示用户按 q 退出
    echo "现在查看服务状态。按 'q' 退出查看状态。"
    sudo systemctl status pipe-pop.service

    # read -p "按任意键返回主菜单..."
}

# 查看声誉函数
function check_status() {
    echo "正在查看 ./pop 的状态..."
    cd /root/pipenetwork
    ./pop --status
    read -p "按任意键返回主菜单..."
}

# 备份 node_info.json 函数
function backup_node_info() {
    echo "正在备份 node_info.json 文件..."
    cd /root/pipenetwork
    cp ~/node_info.json ~/node_info.backup2-4-25  # 备份文件到新的目标文件
    echo "备份完成，node_info.json 已备份到 ~/node_info.backup2-4-25 文件。"
    read -p "按任意键返回主菜单..."
}

# 生成pop邀请
function generate_referral() {
    echo "正在生成 pop邀请码..."
    cd /root/pipenetwork
    ./pop --gen-referral-route
    read -p "按任意键返回主菜单..."
}

# 升级版本 (2.0.5)
function upgrade_version() {
    echo "正在升级到版本 2.0.5..."

    # 停止 pipe-pop 服务
    sudo systemctl stop pipe-pop
    echo "已停止 pipe-pop 服务。"

    # 删除旧版本的 pop
    sudo rm -f /root/pipenetwork/pop
    echo "已删除旧版本 pop 文件。"

    # 下载新版本的 pop 到指定路径
    wget -O /root/pipenetwork/pop "https://dl.pipecdn.app/v0.2.5/pop"
    sudo chmod +x /root/pipenetwork/pop
    echo "已下载并赋予执行权限，pop 已更新为版本 2.0.5。"

    # 重新加载 systemd 配置
    sudo systemctl daemon-reload

    # 重启 pipe-pop 服务
    sudo systemctl restart pipe-pop
    echo "pipe-pop 服务已重启。"

    # 实时查看服务日志
    journalctl -u pipe-pop -f

    read -p "按任意键返回主菜单..."
}

# # 主菜单函数
# function main_menu() {
#     while true; do
#         clear
#         echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
#         echo "如有问题，可联系推特，仅此只有一个号"
#         echo "================================================================"
#         echo "退出脚本，请按键盘 ctrl + C 退出即可"
#         echo "请选择要执行的操作:"
#         echo "1. 部署 pipe pop节点"
#         echo "2. 查看声誉"
#         echo "3. 备份 info"
#         echo "4. 生成pop邀请"
#         echo "5. 升级版本（升级前建议备份info）"
#         echo "6. 退出"

#         read -p "请输入选项: " choice

#         case $choice in
#             1)
#                 deploy_pipe_pop
#                 ;;
#             2)
#                 check_status
#                 ;;
#             3)
#                 backup_node_info
#                 ;;
#             4)
#                 generate_referral
#                 ;;
#             5)
#                 upgrade_version
#                 ;;
#             6)
#                 echo "退出脚本。"
#                 exit 0
#                 ;;
#             *)
#                 echo "无效选项，请重新选择。"
#                 read -p "按任意键继续..."
#                 ;;
#         esac
#     done
# }

# 启动主菜单
deploy_pipe_pop
check_status
