#!/bin/bash

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

rootness(){
    if [[ $EUID -ne 0 ]]; then
       echo "必须使用root账号运行!" 1>&2
       exit 1
    fi
}

tunavailable(){
    if [[ ! -e /dev/net/tun ]]; then
        echo "TUN/TAP设备不可用!" 1>&2
        exit 1
    fi
}

disable_selinux(){
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
}

get_os_info(){
    IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
}


rand(){
    index=0
    str=""
    for i in {a..z}; do arr[index]=${i}; index=`expr ${index} + 1`; done
    for i in {A..Z}; do arr[index]=${i}; index=`expr ${index} + 1`; done
    for i in {0..9}; do arr[index]=${i}; index=`expr ${index} + 1`; done
    for i in {1..10}; do str="$str${arr[$RANDOM%$index]}"; done
    echo ${str}
}


preinstall_l2tp(){
    if [ -d "/proc/vz" ]; then
        echo -e "\033[41;37m WARNING: \033[0m Your VPS is based on OpenVZ, and IPSec might not be supported by the kernel."
        echo "Continue installation? (y/n)"
        read -p "(Default: n)" agree
        [ -z ${agree} ] && agree="n"
        if [ "${agree}" == "n" ]; then
            echo
            echo "L2TP installation cancelled."
            echo
            exit 0
        fi
    fi
    
    # 交互信息固定
    iprange="192.168.18"
    mypsk="111111"
    echo "###########################"
    echo "公网ip: ${IP}"
    echo "l2tp网关: ${iprange}.1"
    echo "拨入客户端可用ip范围: ${iprange}.2-${iprange}.254"
    echo "PSK预共享密钥: ${mypsk}"
    echo "###########################"
}

install_l2tp(){

    mknod /dev/random c 1 9
    yum -y install epel-*
    yum -y install ppp libreswan xl2tpd iptables iptables-services
    yum_install

}

config_install(){

    cat > /etc/ipsec.conf<<EOF
version 2.0

config setup
    protostack=netkey
    nhelpers=0
    uniqueids=no
    interfaces=%defaultroute
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:!${iprange}.0/24

conn l2tp-psk
    rightsubnet=vhost:%priv
    also=l2tp-psk-nonat

conn l2tp-psk-nonat
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%defaultroute
    leftid=${IP}
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    dpddelay=40
    dpdtimeout=130
    dpdaction=clear
    sha2-truncbug=yes
EOF

    cat > /etc/ipsec.secrets<<EOF
%any %any : PSK "${mypsk}"
EOF

    cat > /etc/xl2tpd/xl2tpd.conf<<EOF
[global]
port = 1701

[lns default]
ip range = ${iprange}.2-${iprange}.254
local ip = ${iprange}.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

    cat > /etc/ppp/options.xl2tpd<<EOF
ipcp-accept-local
ipcp-accept-remote
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
hide-password
idle 1800
mtu 1410
mru 1410
nodefaultroute
debug
proxyarp
connect-delay 5000
EOF

    rm -f /etc/ppp/chap-secrets
    cat > /etc/ppp/chap-secrets<<EOF
# Secrets for authentication using CHAP
# client    server    secret    IP addresses
EOF

}


yum_install(){

    config_install

    cp -pf /etc/sysctl.conf /etc/sysctl.conf.bak

    echo "# Added by L2TP VPN" >> /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_ignore_bogus_error_responses=1" >> /etc/sysctl.conf

    for each in `ls /proc/sys/net/ipv4/conf/`; do
        echo "net.ipv4.conf.${each}.accept_source_route=0" >> /etc/sysctl.conf
        echo "net.ipv4.conf.${each}.accept_redirects=0" >> /etc/sysctl.conf
        echo "net.ipv4.conf.${each}.send_redirects=0" >> /etc/sysctl.conf
        echo "net.ipv4.conf.${each}.rp_filter=0" >> /etc/sysctl.conf
    done
    sysctl -p

    systemctl enable ipsec
    systemctl enable xl2tpd
    systemctl restart ipsec
    systemctl restart xl2tpd
}

finally(){
    echo "易十七_提示您_验证安装_易十七QQ214887744"
    echo "易十七_提示您_验证安装_易十七QQ214887744"
    ipsec verify # ipsec内置命令
    systemctl stop firewalld
    systemctl disable firewalld
    systemctl start iptables
    systemctl enable iptables
    echo "易十七_提示您_安装完成_QQ214887744"
    echo "易十七_提示您_安装完成_QQ214887744"
}


l2tp(){
    echo "易十七_提示您_开始安装_QQ214887744"
    echo "易十七_提示您_开始安装_QQ214887744"
    rootness
    tunavailable
    disable_selinux
    get_os_info
    preinstall_l2tp
    install_l2tp
    finally
}

l2tp

iptables -F
iptables -P INPUT ACCEPT
#iptables -t nat -A POSTROUTING -j MASQUERADE
ip -4 a | grep inet | grep -v "127.0.0.1" | awk '{print $2,$NF}' | sed "s/\/[0-9]\{1,2\}//g" > system_ip.txt
start_num=2
rm -f ./account.txt
psk=`cat /etc/ipsec.secrets | awk '{print $5}' | sed 's/"//g'`
ip=`cat /etc/ipsec.conf | grep leftid | awk -F "=" '{print $2}'`

while read line || [[ -n ${line} ]]
do
    nic_ip=`echo $line | awk '{print $1}'`
    echo "易十七_提示您_创建第" `expr $start_num - 1` "个成功"

    echo "user`expr $start_num - 1`     l2tpd     111111     192.168.18.$start_num" >> /etc/ppp/chap-secrets

    iptables -t nat -A POSTROUTING -s 192.168.18.$start_num -j SNAT --to-source $nic_ip

    #public_ip=`curl -s --interface $nic_ip -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.114 Safari/537.36 Edg/103.0.1264.62" https://api.ip.sb/ip`
    public_ip=`curl -s --interface $nic_ip -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.114 Safari/537.36 Edg/103.0.1264.62" https://www.bt.cn/api/getipaddress`
    echo "ip地址  $ip  用户名 user`expr $start_num - 1` 密码  111111  预共享秘钥  $psk  云服务器外网ip  $public_ip" >> ./account.txt
    start_num=`expr $start_num + 1`

done < system_ip.txt
rm -f system_ip.txt

iptables-save > /etc/sysconfig/iptables
systemctl restart xl2tpd
systemctl restart ipsec

echo "账号密码保存在当前目录下 account.txt 中"
echo "易十七_提示您_全部安装完毕_QQ214887744"
cat account.txt
echo "更多学习资料Bilibili_B站_https://www.bilibili.com_搜索_易十七教程"
echo "逆向_内存_封包    QQ交流群：I群747291002  II群819452693"
echo "图色_防封_防检测 QQ交流群：I群907831607  II群894346943"
