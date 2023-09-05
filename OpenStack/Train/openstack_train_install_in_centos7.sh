#!/bin/bash

#Program
#   OpenStack Train (All In One) Install Scripts
#History
#   2023   Ueincn  Release
#Platform
#   CentOS 7.9.2009

SETP="1"
SCRIPTSPID=$$

#user environment
SETHOSTNAME="openstack"
MARIADB_PASSWORD="root"
RABBIT_PASS="root"
KEYSTONE_DBPASS="root"
ADMIN_PASS="root"
GLANCE_PASS="root"
GLANCE_DBPASS="root"
PLACEMENT_DBPASS="root"
PLACEMENT_PASS="root"
NOVA_DBPASS="root"
NOVA_PASS="root"
NEUTRON_DBPASS="root"
NEUTRON_PASS="root"

#logfile
OPENSTACK_INSTALL_LOG="/tmp/openstack_install.log"
if [ ! -f /tmp/openstack_install.log ]; then
    touch /tmp/openstack_install.log
    chmod 644 /tmp/openstack_install.log
fi

function ExitCode(){
    echo -n "$0 "
    kill $SCRIPTSPID
}
function ShowSpin(){
    $* &
    PID=$!
    local SPINLINE=('-' '/' '|' '\')
    sleep 0.05
    echo -n " ... "
    while kill -0 $PID 2>/dev/null
    do
        for SPIN in "${SPINLINE[@]}"
        do
              echo -ne "$SPIN"
              sleep 0.1
              echo -ne "\b"
        done
    done
}
function StatusCode(){
    local PASS=$(tput setaf 2)
    local FAIL=$(tput setaf 1)
    local CLEAR=$(tput sgr0)
    if [ $? == "0" ]; then
        echo -e "\b${PASS}PASS${CLEAR}"
    else
        echo -e "\b${FAIL}FAIL${CLEAR}"
    fi
}
function EchoTitle(){
    echo -e "\n"
    echo "${SETP}. $*"
    SETP=$(( $SETP + 1 ))  
}

function EchoSubTitle(){
      echo -n "      $*"
}

# System Environment
function OSCheck(){
    EchoSubTitle "System Check"
    sleep 0.1
    
    if dmesg | grep "Linux version" | grep -E "CentOS|centos|CENTOS" >>$OPENSTACK_INSTALL_LOG 2>&1; then
        OS="centos"
        OS_NAME=$(cat /etc/os-release | grep -w "NAME" | awk -F '"' '{print $2}') 
        OS_VERSION=$(cat /etc/os-release | grep -w "VERSION" | awk -F '"' '{print $2}' | awk -F '(' '{print $1}') 
        StatusCode
    else
        echo -e "\b$(tput setaf 1)FAIL$(tput sgr0)"
        echo -e "\b$(tput setaf 7)System version not supported!$(tput sgr0) "
        ExitCode
    fi
}
function VirtualenvCheck(){
    EchoSubTitle "Vritualenv Check"
    sleep 0.1
    egrep "(svm|vmx)" /proc/cpuinfo >/dev/null 2>&1 && lsmod | grep kvm >>$OPENSTACK_INSTALL_LOG 2>&1
    StatusCode
}
function DisableFirewall(){
    EchoSubTitle "Firewall Disable"
    sleep 0.1
    if systemctl status firewalld.service >>$OPENSTACK_INSTALL_LOG 2>&1; then
        systemctl stop firewalld >>$OPENSTACK_INSTALL_LOG 2>&1
        systemctl disable firewalld >>$OPENSTACK_INSTALL_LOG 2>&1
        StatusCode
    elif systemctl status ufw >>$OPENSTACK_INSTALL_LOG 2>&1; then
        systemctl stop ufw >>$OPENSTACK_INSTALL_LOG 2>&1
        systemctl disable ufw >>$OPENSTACK_INSTALL_LOG 2>&1
        StatusCode
    else
        StatusCode
    fi   
}
function DisableSELinux(){
      EchoSubTitle "SELinux Disable"
      sleep 0.1
      SELINUXSTATUS=$(getenforce 2>/dev/null)
      if [ $? -eq 0 ]; then 
            if [[ $SELINUXSTATUS -eq "Enforcing" ]]; then
                  cp /etc/selinux/config /etc/selinux/config.bak >/dev/null 2>&1
                  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config >/dev/null 2>&1
            fi
            StatusCode
      fi
}
function SetHostname(){
    EchoSubTitle "Setting Hostname[$SETHOSTNAME]"
    sleep 0.1
    hostnamectl set-hostname $SETHOSTNAME
    cat > /etc/hosts <<EOF
127.0.0.1   $SETHOSTNAME
::1         $SETHOSTNAME
EOF
    StatusCode
}
function SetRepo(){
    EchoSubTitle "Setting Repo"
    sleep 0.1
    cd /etc/yum.repos.d/
    rm -rf *
    cat >/etc/yum.repos.d/openstack.repo <<EOF
[openstack]
name=Openstack-Train
baseurl=https://mirrors.aliyun.com/centos/7.9.2009/cloud/x86_64/openstack-train/
enabled=1
gpgcheck=0
[qume-kvm]
name=qemu-kvm
baseurl=https://mirrors.aliyun.com/centos/7.9.2009/virt/x86_64/kvm-common/
enabled=1
gpgcheck=0
EOF
    cat >/etc/yum.repos.d/CentOS-Base.repo <<EOF
[base]
name=CentOS-7 - Base - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/7/os/x86_64/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
 
#released updates 
[updates]
name=CentOS-7 - Updates - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/7/updates/x86_64/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
 
#additional packages that may be useful
[extras]
name=CentOS-7 - Extras - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/7/extras/x86_64/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
 
#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-7 - Plus - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/7/centosplus/x86_64/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
EOF
    yum clean all >/dev/null 2>&1
    yum makecache >/dev/null 2>&1
    yum update -y >/dev/null 2>&1
    yum upgrade -y >/dev/null 2>&1
    StatusCode
}

# Basic Software Install
function OpenStackBase(){
    EchoSubTitle "OpenStack base installation"
    sleep 0.1
    yum install python-openstackclient openstack-selinux openstack-utils -y >/dev/null 2>&1
    StatusCode
}
function MariaDB(){
    EchoSubTitle "MariaDB Install"
    sleep 0.1
    yum remove MariaDB* -y >/dev/null 2>&1
    yum install mariadb mariadb-server python2-PyMySQL -y >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        if [ -d /etc/my.cnf.d ]; then
            mkdir -p /etc/my.cnf.d
        fi
        touch /etc/my.cnf.d/openstack.cnf
        cat > /etc/my.cnf.d/openstack.cnf <<EOF
[mysqld]
bind-address = 0.0.0.0
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF
    systemctl enable --now mariadb.service >/dev/null 2>&1
    mysqladmin -u root password "$MARIADB_PASSWORD" >/dev/null 2>&1
    mysql -uroot -p$MARIADB_PASSWORD >/dev/null 2>&1
    fi
    StatusCode
}
function RabbitMQ(){
    EchoSubTitle "RabbitMQ Install"
    sleep 0.1
    yum install rabbitmq-server -y >/dev/null 2>&1
    systemctl enable --now rabbitmq-server.service >/dev/null 2>&1
    rabbitmqctl add_user openstack $RABBIT_PASS >/dev/null 2>&1
    rabbitmqctl set_permissions openstack ".*" ".*" ".*" >/dev/null 2>&1
    systemctl restart rabbitmq-server.service >/dev/null 2>&1
    StatusCode
}
function Memcached(){
    EchoSubTitle "Memcached Install"
    sleep 0.1
    yum install memcached python-memcached -y >/dev/null 2>&1
    cat > /etc/sysconfig/memcached <<EOF
PORT="11211"
USER="memcached"
MAXCONN="1024"
CACHESIZE="64"
OPTIONS="-l 127.0.0.1,::1,openstack"
EOF
    systemctl enable --now memcached.service >/dev/null 2>&1
    StatusCode
}
function Etcd(){
    EchoSubTitle "Etcd Install"
    sleep 0.1
    yum install etcd -y >/dev/null 2>&1

    sed -i 's@#ETCD_LISTEN_PEER_URLS="http://localhost:2380"@ETCD_LISTEN_PEER_URLS="http://localhost:2380"@g' /etc/etcd/etcd.conf
    sed -i 's@ETCD_LISTEN_CLIENT_URLS="http://localhost:2379"@ETCD_LISTEN_CLIENT_URLS="http://localhost:2379,http://127.0.0.1:2379"@g' /etc/etcd/etcd.conf
    sed -i 's@ETCD_NAME="default"@ETCD_NAME="openstack"@g' /etc/etcd/etcd.conf
    sed -i 's@#ETCD_INITIAL_ADVERTISE_PEER_URLS="http://localhost:2380"@ETCD_INITIAL_ADVERTISE_PEER_URLS="http://localhost:2380"@g' /etc/etcd/etcd.conf
    sed -i 's@#ETCD_INITIAL_CLUSTER="default=http://localhost:2380"@ETCD_INITIAL_CLUSTER="openstack=http://localhost:2380"@g' /etc/etcd/etcd.conf
    sed -i 's@#ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"@ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"@g' /etc/etcd/etcd.conf
    sed -i 's@#ETCD_INITIAL_CLUSTER_STATE="new"@ETCD_INITIAL_CLUSTER_STATE="new"@g' /etc/etcd/etcd.conf
    sed -i 's@localhost@172.10.10.124@g' /etc/etcd/etcd.conf

    systemctl enable --now etcd.service >/dev/null 2>&1
    StatusCode
}   

# OpenStack component installation
function Keystone(){
    EchoSubTitle "Keystone Install"
    sleep 0.1
    local CREATE_DB_SQL="CREATE DATABASE IF NOT EXISTS keystone;"
    local CREATE_USER_SQL="GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '${KEYSTONE_DBPASS}';"
    local GRANT_USER_SQL="GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '${KEYSTONE_DBPASS}';"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_DB_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_USER_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${GRANT_USER_SQL}"

    yum install openstack-keystone httpd mod_wsgi -y >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
        grep -Ev ^'(#|$)' /etc/keystone/keystone.conf.bak > /etc/keystone/keystone.conf
        sed -i '9a connection = mysql+pymysql://keystone:'${KEYSTONE_DBPASS}'@openstack/keystone' /etc/keystone/keystone.conf
        sed -i '40a provider = fernet' /etc/keystone/keystone.conf
    fi

    su -s /bin/sh -c "keystone-manage db_sync" keystone

    keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

    keystone-manage bootstrap --bootstrap-password ${ADMIN_PASS} \
        --bootstrap-admin-url http://openstack:5000/v3/ \
        --bootstrap-internal-url http://openstack:5000/v3/ \
        --bootstrap-public-url http://openstack:5000/v3/ \
        --bootstrap-region-id RegionOne

    sed -i 's@#ServerName www.example.com:80@ServerName openstack@g' /etc/httpd/conf/httpd.conf
    ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/ >/dev/null 2>&1
    systemctl enable --now httpd.service >/dev/null 2>&1

    openstack domain create --description "An Example Domain" example
    openstack project create --domain default --description "Service Project" service
    openstack project create --domain default --description "Demo Project" myproject
    openstack user create --domain default --password-prompt myuser
    #root
    openstack role create myrole
    openstack role add --project myproject --user myuser myrole

    openstack --os-auth-url http://openstack:5000/v3 \
  --os-project-domain-name Default --os-user-domain-name Default \
  --os-project-name admin --os-username admin token issue

  openstack --os-auth-url http://openstack:5000/v3 \
  --os-project-domain-name Default --os-user-domain-name Default \
  --os-project-name myproject --os-username myuser token issue

    StatusCode
}
function Glance(){
    EchoSubTitle "Glance Install"
    sleep 0.1

    local CREATE_DB_SQL="CREATE DATABASE glance;"
    local CREATE_USER_SQL="GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${GLANCE_DBPASS}';"
    local GRANT_USER_SQL="GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '${GLANCE_DBPASS}';"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_DB_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_USER_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${GRANT_USER_SQL}"

    source admin-openrc >/dev/null 2>&1

    openstack user create --domain default --password ${GLANCE_PASS} glance >/dev/null 2>&1
    openstack role add --project service --user glance admin >/dev/null 2>&1
    openstack service create --name glance --description "OpenStack Image" image >/dev/null 2>&1

    openstack endpoint create --region RegionOne image public http://openstack:9292 >/dev/null 2>&1
    openstack endpoint create --region RegionOne image internal http://openstack:9292 >/dev/null 2>&1
    openstack endpoint create --region RegionOne image admin http://openstack:9292 >/dev/null 2>&1

    yum install openstack-glance -y >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        cp -a /etc/glance/glance-api.conf{,.bak}
        cp -a /etc/glance/glance-registry.conf{,.bak}
        grep -Ev '^$|#' /etc/glance/glance-api.conf.bak > /etc/glance/glance-api.conf
        grep -Ev '^$|#' /etc/glance/glance-registry.conf.bak > /etc/glance/glance-registry.conf

        openstack-config --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:${GLANCE_DBPASS}@openstack/glance

        openstack-config --set /etc/glance/glance-api.conf keystone_authtoken www_authenticate_uri http://openstack:5000
        openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://openstack:5000
        openstack-config --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers openstack:11211
        openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
        openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name Default
        openstack-config --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name Default
        openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_name service
        openstack-config --set /etc/glance/glance-api.conf keystone_authtoken username glance
        openstack-config --set /etc/glance/glance-api.conf keystone_authtoken password ${GLANCE_PASS}
        openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone

        openstack-config --set /etc/glance/glance-api.conf glance_store stores file,http
        openstack-config --set /etc/glance/glance-api.conf glance_store default_store file
        openstack-config --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/
    fi

    su -s /bin/sh -c "glance-manage db_sync" glance >/dev/null 2>&1

    systemctl enable --now x openstack-glance-registry.service >/dev/null 2>&1

    StatusCode
}

function Placement(){
    EchoSubTitle "Placement Install"
    sleep 0.1

    local CREATE_DB_SQL="CREATE DATABASE placement;"
    local CREATE_USER_SQL="GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '${PLACEMENT_DBPASS}';"
    local GRANT_USER_SQL="GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '${PLACEMENT_DBPASS}';"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_DB_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_USER_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${GRANT_USER_SQL}"

    source admin-openrc >/dev/null 2>&1

    openstack user create --domain default --password ${PLACEMENT_PASS} placement >/dev/null 2>&1
    openstack role add --project service --user placement admin >/dev/null 2>&1
    openstack service create --name placement --description "Placement API" placement >/dev/null 2>&1

    openstack endpoint create --region RegionOne placement public http://openstack:8778 >/dev/null 2>&1
    openstack endpoint create --region RegionOne placement internal http://openstack:8778 >/dev/null 2>&1
    openstack endpoint create --region RegionOne placement admin http://openstack:8778 >/dev/null 2>&1

    yum install openstack-placement-api -y >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        cp /etc/placement/placement.conf /etc/placement/placement.conf.bak
        grep -Ev '^$|#' /etc/placement/placement.conf.bak > /etc/placement/placement.conf
        openstack-config --set /etc/placement/placement.conf placement_database connection mysql+pymysql://placement:${PLACEMENT_DBPASS}@openstack/placement
        openstack-config --set /etc/placement/placement.conf api auth_strategy keystone
        openstack-config --set /etc/placement/placement.conf keystone_authtoken auth_url http://openstack:5000
        openstack-config --set /etc/placement/placement.conf keystone_authtoken memcached_servers openstack:11211
        openstack-config --set /etc/placement/placement.conf keystone_authtoken auth_type password
        openstack-config --set /etc/placement/placement.conf keystone_authtoken project_domain_name Default
        openstack-config --set /etc/placement/placement.conf keystone_authtoken user_domain_name Default
        openstack-config --set /etc/placement/placement.conf keystone_authtoken project_name service
        openstack-config --set /etc/placement/placement.conf keystone_authtoken username placement
        openstack-config --set /etc/placement/placement.conf keystone_authtoken password ${PLACEMENT_PASS}
    fi

# 未测试
HTTP="
  <Directory /usr/bin>
   <IfVersion >= 2.4>
     Require all granted
  </IfVersion>
  <IfVersion < 2.4>
     Order allow,deny
     Allow from all
  </IfVersion>
 </Directory>
"
sed -i '/"#SSLCertificateKeyFile ..."/a\'${HTTP}'' /etc/httpd/conf.d/00-placement-api.conf
    
    su -s /bin/sh -c "placement-manage db sync" placement >/dev/null 2>&1

    systemctl restart httpd >/dev/null 2>&1

    StatusCode
}
function Nova(){
    EchoSubTitle "Nova Install"
    sleep 0.1

    local CREATE_NOVA_DB_SQL="CREATE DATABASE nova;"
    local CREATE_NOVA_API_DB_SQL="CREATE DATABASE nova_api;"
    local CREATE_NOVA_CELL0_DB_SQL="CREATE DATABASE nova_cell0;"

    local CREATE_NOVA_USER_SQL="GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${NOVA_DBPASS}';"
    local GRANT_NOVA_USER_SQL="GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '${NOVA_DBPASS}';"

    local CREATE_NOVA_API_USER_SQL="GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '${NOVA_DBPASS}';"
    local GRANT_NOVA_API_USER_SQL="GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '${NOVA_DBPASS}';"

    local CREATE_NOVA_CELL0_USER_SQL="GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '${NOVA_DBPASS}';"
    local GRANT_NOVA_CELL0_USER_SQL="GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '${NOVA_DBPASS}';"

    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_NOVA_DB_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_NOVA_API_DB_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_NOVA_CELL0_DB_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_NOVA_USER_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${GRANT_NOVA_USER_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_NOVA_API_USER_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${GRANT_NOVA_API_USER_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_NOVA_CELL0_USER_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${GRANT_NOVA_CELL0_USER_SQL}"

    source admin-openrc >/dev/null 2>&1

    openstack user create --domain default --password ${NOVA_PASS} nova >/dev/null 2>&1
    openstack role add --project service --user nova admin >/dev/null 2>&1

    openstack service create --name nova --description "OpenStack Compute" compute >/dev/null 2>&1
    openstack endpoint create --region RegionOne compute public http://openstack:8774/v2.1 >/dev/null 2>&1
    openstack endpoint create --region RegionOne compute internal http://openstack:8774/v2.1 >/dev/null 2>&1
    openstack endpoint create --region RegionOne compute admin http://openstack:8774/v2.1 >/dev/null 2>&1

    yum install openstack-nova-api openstack-nova-conductor openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-compute -y >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        cp -a /etc/nova/nova.conf{,.bak}
        grep -Ev '^$|#' /etc/nova/nova.conf.bak > /etc/nova/nova.conf

        openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
        openstack-config --set /etc/nova/nova.conf DEFAULT transport_url rabbit://openstack:${RABBIT_PASS}@openstack
        openstack-config --set /etc/nova/nova.conf DEFAULT my_ip openstack
        openstack-config --set /etc/nova/nova.conf DEFAULT use_neutron true
        openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

        openstack-config --set /etc/nova/nova.conf api_database connection mysql+pymysql://nova:${NOVA_DBPASS}@openstack/nova_api
        openstack-config --set /etc/nova/nova.conf database connection mysql+pymysql://nova:${NOVA_DBPASS}@openstack/nova

        openstack-config --set /etc/nova/nova.conf api auth_strategy keystone
        openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://openstack:5000
        openstack-config --set /etc/nova/nova.conf keystone_authtoken memcached_servers openstack:11211
        openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_type password
        openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_name Default
        openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_name Default
        openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
        openstack-config --set /etc/nova/nova.conf keystone_authtoken username nova
        openstack-config --set /etc/nova/nova.conf keystone_authtoken password ${NOVA_PASS}

        openstack-config --set /etc/nova/nova.conf vnc enabled true
        openstack-config --set /etc/nova/nova.conf vnc server_listen 0.0.0.0
        openstack-config --set /etc/nova/nova.conf vnc server_proxyclient_address openstack

        openstack-config --set /etc/nova/nova.conf vnc novncproxy_base_url http://openstack:6080/vnc_auto.html

        openstack-config --set /etc/nova/nova.conf glance api_servers http://openstack:9292

        openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

        openstack-config --set /etc/nova/nova.conf placement_database connection mysql+pymysql://placement:${PLACEMENT_DBPASS}@openstack/placement

        openstack-config --set /etc/nova/nova.conf placement region_name RegionOne
        openstack-config --set /etc/nova/nova.conf placement project_domain_name Default
        openstack-config --set /etc/nova/nova.conf placement project_name service
        openstack-config --set /etc/nova/nova.conf placement auth_type password
        openstack-config --set /etc/nova/nova.conf placement user_domain_name Default
        openstack-config --set /etc/nova/nova.conf placement auth_url http://openstack:5000/v3
        openstack-config --set /etc/nova/nova.conf placement username placement
        openstack-config --set /etc/nova/nova.conf placement password ${PLACEMENT_PASS}

        openstack-config --set /etc/nova/nova.conf scheduler discover_hosts_in_cells_interval 300

        openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu
    fi

    su -s /bin/sh -c "nova-manage api_db sync" nova >/dev/null 2>&1
    su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova >/dev/null 2>&1
    su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova >/dev/null 2>&1
    su -s /bin/sh -c "nova-manage db sync" nova >/dev/null 2>&1

    su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova >/dev/null 2>&1

    systemctl enable --now openstack-nova-api.service

    #systemctl enable --now openstack-nova-consoleauth
    systemctl enable --now openstack-nova-scheduler.service
    systemctl enable --now openstack-nova-conductor.service

    systemctl enable --now openstack-nova-novncproxy.service
    systemctl enable --now libvirtd.service
    systemctl enable --now openstack-nova-compute.service

    StatusCode
}
function Neutron(){
    EchoSubTitle "Neutron Install"
    sleep 0.1

    local CREATE_DB_SQL="CREATE DATABASE neutron;"
    local CREATE_USER_SQL="GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '${NEUTRON_DBPASS}';"
    local GRANT_USER_SQL="GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '${NEUTRON_DBPASS}';"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_DB_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${CREATE_USER_SQL}"
    mysql -uroot -p${MARIADB_PASSWORD} -e "${GRANT_USER_SQL}"

    source admin-openrc >/dev/null 2>&1

    openstack user create --domain default --password ${NEUTRON_PASS} neutron >/dev/null 2>&1
    openstack role add --project service --user neutron admin >/dev/null 2>&1
    openstack service create --name neutron --description "OpenStack Networking" network >/dev/null 2>&1
    
    openstack endpoint create --region RegionOne network public http://openstack:9696 >/dev/null 2>&1
    openstack endpoint create --region RegionOne network internal http://openstack:9696 >/dev/null 2>&1
    openstack endpoint create --region RegionOne network admin http://openstack:9696 >/dev/null 2>&1

    yum install openstack-neutron openstack-neutron-linuxbridge ebtables ipset openstack-neutron-ml2 -y >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        cp -a /etc/neutron/neutron.conf{,.bak}
        grep -Ev '^$|#' /etc/neutron/neutron.conf.bak > /etc/neutron/neutron.conf

        openstack-config --set  /etc/neutron/neutron.conf database connection mysql+pymysql://neutron:${NEUTRON_DBPASS}@openstack/neutron
        openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin ml2
        openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins router
        openstack-config --set  /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips true
        openstack-config --set  /etc/neutron/neutron.conf DEFAULT transport_url rabbit://openstack:${RABBIT_PASS}@openstack
        openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

        openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes true
        openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes true

        openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken www_authenticate_uri http://openstack:5000
        openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url http://openstack:5000
        openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken memcached_servers openstack:11211
        openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_type password
        openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
        openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
        openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name service
        openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username neutron
        openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password ${NEUTRON_PASS}

        openstack-config --set  /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp

        #会有空格，影响数据库同步，待解决
        NEUTRONNOVA="[nova]\n
        auth_url = http://openstack:5000\n
        auth_type = password\n
        project_domain_name = default\n
        user_domain_name = default\n
        region_name = RegionOne\n
        project_name = service\n
        username = nova\n
        password = ${NOVA_PASS}"
        echo -e $NEUTRONNOVA >> /etc/neutron/neutron.conf

        cp -a /etc/neutron/plugins/ml2/ml2_conf.ini{,.bak}
        grep -Ev '^$|#' /etc/neutron/plugins/ml2/ml2_conf.ini.bak > /etc/neutron/plugins/ml2/ml2_conf.ini

        openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan
        openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types 
        openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge
        openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
        openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks provider
        openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset true

        cp -a /etc/neutron/plugins/ml2/linuxbridge_agent.ini{,.bak}
        grep -Ev '^$|#' /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak > /etc/neutron/plugins/ml2/linuxbridge_agent.ini

        openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings provider:eth0
        openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan false
        openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group true
        openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

        echo 'net.bridge.bridge-nf-call-iptables=1' >> /etc/sysctl.conf
        echo 'net.bridge.bridge-nf-call-ip6tables=1' >> /etc/sysctl.conf
        modprobe br_netfilter >/dev/null 2>&1

        cp -a /etc/neutron/dhcp_agent.ini{,.bak}
        grep -Ev '^$|#' /etc/neutron/dhcp_agent.ini.bak > /etc/neutron/dhcp_agent.ini

        openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT interface_driver linuxbridge
        openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
        openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata true

        cp -a /etc/neutron/metadata_agent.ini{,.bak}
        grep -Ev '^$|#' /etc/neutron/metadata_agent.ini.bak > /etc/neutron/metadata_agent.ini

        openstack-config --set  /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_host openstack
        openstack-config --set  /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret METADATA_SECRET


        openstack-config --set  /etc/nova/nova.conf neutron url http://openstack:9696
        openstack-config --set  /etc/nova/nova.conf neutron auth_url http://openstack:5000
        openstack-config --set  /etc/nova/nova.conf neutron auth_type password
        openstack-config --set  /etc/nova/nova.conf neutron project_domain_name default
        openstack-config --set  /etc/nova/nova.conf neutron user_domain_name default
        openstack-config --set  /etc/nova/nova.conf neutron region_name RegionOne
        openstack-config --set  /etc/nova/nova.conf neutron project_name service
        openstack-config --set  /etc/nova/nova.conf neutron username neutron
        openstack-config --set  /etc/nova/nova.conf neutron password ${NEUTRON_PASS}
        openstack-config --set  /etc/nova/nova.conf neutron service_metadata_proxy true
        openstack-config --set  /etc/nova/nova.conf neutron metadata_proxy_shared_secret METADATA_SECRET
    fi

    ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
    su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron >/dev/null 2>&1

    systemctl restart openstack-nova-api.service >/dev/null 2>&1
    systemctl restart openstack-nova-compute.service >/dev/null 2>&1

    systemctl enable --now neutron-server.service >/dev/null 2>&1
    systemctl enable --now neutron-linuxbridge-agent.service >/dev/null 2>&1
    systemctl enable --now neutron-dhcp-agent.service >/dev/null 2>&1
    systemctl enable --now neutron-metadata-agent.service >/dev/null 2>&1

    StatusCode
}
function Horizon(){
    EchoSubTitle "Horizon Install"
    sleep 0.1

    yum install openstack-dashboard

    sed -i 's@"ALLOWED_HOSTS = ['horizon.example.com', 'localhost']"@"ALLOWED_HOSTS = ['*']"@g' /etc/openstack-dashboard/local_settings
    sed -i 's@"OPENSTACK_HOST = "127.0.0.1""@"OPENSTACK_HOST = "openstack""@g' /etc/openstack-dashboard/local_settings


    cd /usr/share/openstack-dashboard
    python manage.py make_web_conf --apache > /etc/httpd/conf.d/openstack-dashboard.conf
    ln -s /etc/openstack-dashboard /usr/share/openstack-dashboard/openstack_dashboard/conf

    sed -i 's@WEBROOT = '/'@WEBROOT = '/dashboard'@g' /usr/share/openstack-dashboard/openstack_dashboard/defaults.py
    sed -i 's@WEBROOT = '/'@WEBROOT = '/dashboard'@g' /usr/share/openstack-dashboard/openstack_dashboard/test/settings.py

    sed -i 's@"WSGIScriptAlias /"@"WSGIScriptAlias /dashboard"@g' /etc/httpd/conf.d/openstack-dashboard.conf
    sed -i 's@"Alias /static"@"Alias /dashboard/static"@g' /etc/httpd/conf.d/openstack-dashboard.conf

    cat >> /etc/openstack-dashboard/local_settings <<EOF
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': 'opensatck:11211',
    },
}
EOF
    echo "WEBROOT = '/dashboard/'" >>/etc/openstack-dashboard/local_settings

    systemctl restart httpd.service
    systemctl restart memcached.service

    StatusCode
}

#主函数
function Main(){
    cat producttips
    EchoTitle "System Environment"
    ShowSpin OSCheck
    ShowSpin VirtualenvCheck
    ShowSpin DisableFirewall
    ShowSpin DisableSELinux
    ShowSpin SetHostname
    ShowSpin SetRepo
    EchoTitle "Basic software installation"
    ShowSpin MariaDB
    ShowSpin OpenStackBase
    ShowSpin RabbitMQ
    ShowSpin Memcached
    ShowSpin Etcd
    EchoTitle "OpenStack component installation"
    ShowSpin Keystone
    ShowSpin Glance
    ShowSpin Placement
    ShowSpin Nova
    ShowSpin Neutron
    ShowSpin Horizon
}

if [ $UID -eq 0 ]; then
    Main
else
    echo ""
    echo "[ $(tput setaf 1)!! Please use sudo permissions or switch root to run the script !! $(tput sgr0)]"
    echo ""
fi