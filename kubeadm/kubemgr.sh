#!/usr/bin/env bash

#set -x
set -e
root=$(id -u)
if [ "$root" -ne 0 ] ;then
    echo must run as root
    exit 1
fi


kube::rpm::connect2version()
{
    export NET_WORKING_PLUGIN="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/"
    export RPM_KUBEADM="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/rpm/1.6.0-alpha-88fbc68/kubeadm-1.6.0-0.alpha.0.2074.a092d8e0f95f52.x86_64.rpm"
    export RPM_KUBECTL="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/rpm/1.6.0-alpha-88fbc68/kubectl-1.6.0%2Balpha%2B88fbc68-0.x86_64.rpm"
    export RPM_KUBELET="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/rpm/1.6.0-alpha-88fbc68/kubelet-1.6.0%2Balpha%2B88fbc68-0.x86_64.rpm"
    export RPM_KUBECNI="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/rpm/1.6.0-alpha-88fbc68/kubernetes-cni-0.3.0.1.x86_64.rpm"
    export RPM_OSSFS="http://docs-aliyun.cn-hangzhou.oss.aliyun-inc.com/assets/attach/32196/cn_zh/1481699572723/ossfs_1.80.0_centos7.0_x86_64.rpm?spm=5176.doc32196.2.3.SLZDYl&file=ossfs_1.80.0_centos7.0_x86_64.rpm"

}

kube::common::connect2repository()
{
    export KUBE_REPO_PREFIX="registry.cn-hangzhou.aliyuncs.com/google-containers"
    export KUBE_HYPERKUBE_IMAGE="registry.cn-hangzhou.aliyuncs.com/google-containers/hyperkube-amd64:v1.6.0-alpha.0-alicloud"
    export KUBE_DISCOVERY_IMAGE="registry.cn-hangzhou.aliyuncs.com/google-containers/kube-discovery-amd64:1.0"
	export KUBE_ETCD_IMAGE="registry.cn-hangzhou.aliyuncs.com/google-containers/etcd-amd64:3.0.4"
}

kube::common::classic_route_hack()
{
    ip route del 172.16.0.0/12 dev eth0
}

kube::common::install_docker()
{
    set +e
    kube::common::classic_route_hack
    which docker > /dev/null 2>&1
    i=$?
    if [ $i -ne 0 ]; then
        curl -sSL http://acs-public-mirror.oss-cn-hangzhou.aliyuncs.com/docker-engine/daemon-build/1.12.5/internet_16.04 | sh -
	    systemctl enable docker.service && systemctl start docker.service
    fi
    set -e
    echo docker has been installed
}

kube::common::pause_pod()
{
    pause=$(docker images |grep gcr.io/google_containers/pause-amd64:3.0|wc -l)
    if [ $pause -lt 1 ];then
        docker pull registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0
        docker tag registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0 gcr.io/google_containers/pause-amd64:3.0
    fi
}

kube::rpm::install_binaries()
{
    kube::rpm::connect2version
    yum install -y socat
    rm -rf /tmp/kube && mkdir -p /tmp/kube
    curl -sS -L "$RPM_KUBEADM" > /tmp/kube/kubeadm.rpm
    curl -sS -L "$RPM_KUBECTL" > /tmp/kube/kubectl.rpm
    curl -sS -L "$RPM_KUBELET" > /tmp/kube/kubelet.rpm
    curl -sS -L "$RPM_KUBECNI" > /tmp/kube/kube-cni.rpm
    curl -sS -L "$RPM_OSSFS"  > /tmp/kube/ossfs-1.80.rpm

    rpm -ivh /tmp/kube/kubectl.rpm /tmp/kube/kubelet.rpm /tmp/kube/kube-cni.rpm /tmp/kube/kubeadm.rpm /tmp/kube/ossfs-1.80.rpm

    systemctl enable kubelet.service

    sed -i 's#Environment="KUBELET_DNS_ARGS=--cluster-dns=10.96.0.10 --cluster-domain=cluster.local#Environment="KUBELET_DNS_ARGS=--cluster-dns=172.19.0.10 --cluster-domain=cluster.local --cloud-provider=alicloud --cloud-config=/etc/kubernetes/cloud-config#g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

    systemctl daemon-reload && systemctl start kubelet.service
}

kube::debian::install_binaries()
{
    export NET_WORKING_PLUGIN="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/"
    export RPM_KUBEADM="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/debian/1.6.0-alpha-88fbc68/kubeadm_1.6.0-alpha.0-00_amd64.deb"
    export RPM_KUBECTL="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/debian/1.6.0-alpha-88fbc68/kubectl_1.6.0-alpha.0-00_amd64.deb"
    export RPM_KUBELET="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/debian/1.6.0-alpha-88fbc68/kubelet_1.6.0-alpha.0-00_amd64.deb"
    export RPM_KUBECNI="http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/debian/1.6.0-alpha-88fbc68/kubernetes-cni_0.3.0.1-07a8a2-00_amd64.deb"
    export RPM_OSSFS="http://docs-aliyun.cn-hangzhou.oss.aliyun-inc.com/assets/attach/32196/cn_zh/1483608175067/ossfs_1.80.0_ubuntu16.04_amd64.deb?spm=5176.doc32196.2.1.SLZDYl&file=ossfs_1.80.0_ubuntu16.04_amd64.deb"

    apt install -y -f gdebi
    apt install -y -f socat

    rm -rf /tmp/kube && mkdir -p /tmp/kube
    curl -sS -L $RPM_KUBEADM > /tmp/kube/kubeadm.deb
    curl -sS -L $RPM_KUBECTL > /tmp/kube/kubectl.deb
    curl -sS -L $RPM_KUBELET > /tmp/kube/kubelet.deb
    curl -sS -L $RPM_KUBECNI > /tmp/kube/kube-cni.deb
    curl -sS -L "$RPM_OSSFS" > /tmp/kube/ossfs-1.80.deb

    gdebi -n /tmp/kube/kube-cni.deb
    gdebi -n /tmp/kube/kubelet.deb
    gdebi -n /tmp/kube/kubectl.deb
    gdebi -n /tmp/kube/kubeadm.deb
    gdebi -n /tmp/kube/ossfs-1.80.deb

    SKIP_FLIGHT_CHECK=--skip-preflight-checks

    #dpkg -i /tmp/kube/kubeadm.deb /tmp/kube/kubectl.deb /tmp/kube/kubelet.deb /tmp/kube/kube-cni.deb

    sed -i 's#Environment="KUBELET_DNS_ARGS=--cluster-dns=10.96.0.10 --cluster-domain=cluster.local#Environment="KUBELET_DNS_ARGS=--cluster-dns=172.19.0.10 --cluster-domain=cluster.local --cloud-provider=alicloud --cloud-config=/etc/kubernetes/cloud-config#g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

    systemctl daemon-reload && systemctl start kubelet.service
}

kube::common::install_binaries()
{
     ubu=$(cat /etc/issue|grep "Ubuntu 16.04"|wc -l)
     cet=$(cat cat /etc/centos-release|grep "CentOS"|wc -l)
     if [ "$ubu" == "1" ];then
        kube::debian::install_binaries
     elif [ "$cet" == "1" ];then
        # CentOS
        kube::rpm::install_binaries

        # set net.bridge.bridge-nf-call-iptables = 1 to allow bridge data to be send to iptables for further process.
        cnt=$(grep "net.bridge.bridge-nf-call-iptables" /usr/lib/sysctl.d/00-system.conf |wc -l)
        if [ $cnt -gt 0 ];then
            sed -i '/net.bridge.bridge-nf-call-iptables/d' /usr/lib/sysctl.d/00-system.conf
        fi
        sed -i '$a net.bridge.bridge-nf-call-iptables = 1' /usr/lib/sysctl.d/00-system.conf
        echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

     else
        echo "unkown os...   exit"
        exit 1
     fi
}

kube::master_up()
{

    kube::common::connect2repository

    kube::common::install_docker

    kube::common::pause_pod

    kube::common::install_binaries
    kube::common::write_cloud_config

    kubeadm init $SKIP_FLIGHT_CHECK --discovery=$DISCOVERY --cloud-provider="alicloud" --service-cidr="172.19.0.0/20" --pod-network-cidr="172.16.0.0/16"

    #kubectl apply -f http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/conf/flannel-vxlan.yml
    kubectl apply -f http://aliacs-k8s.oss-cn-hangzhou.aliyuncs.com/conf/kubernetes-dashboard1.5.0.yml

    #kubectl taint nodes --all dedicated-
    #show pods
    kubectl --namespace=kube-system get po
    echo kubectl --namespace=kube-system get po

    # kubectl run nginx --image=registry.cn-hangzhou.aliyuncs.com/spacexnice/nginx:latest --replicas=2 --labels run=nginx
    # kubectl expose deployment nginx --port=80 --target-port=80 --type=LoadBalancer
}

kube::node_up()
{
    kube::common::connect2repository

    kube::common::install_docker

    kube::common::pause_pod

    kube::common::install_binaries

    kube::common::write_cloud_config

    kubeadm join $SKIP_FLIGHT_CHECK --discovery $DISCOVERY
}

kube::common::write_cloud_config()
{
    mkdir -p /etc/kubernetes/
    cat >/etc/kubernetes/cloud-config <<EOF
{
    "global": {
     "accessKeyID": "$KEY_ID",
     "accessKeySecret": "$KEY_SECRET",
     "kubernetesClusterTag": "hangzhou-kube",
     "region": "$REGION"
   }
}
EOF

}

kube::tear_down()
{
    set +e
    kubeadm reset >/dev/null 2>&1
    ubu=$(cat /etc/issue|grep "Ubuntu 16.04"|wc -l)
    cet=$(cat cat /etc/centos-release|grep "CentOS"|wc -l)
    if [ "$ubu" == "1" ];then
        dpkg --purge kubectl kubeadm kubelet kubernetes-cni
        apt-get erase ossfs
        rm -rf /etc/kubernetes /var/lib/kubelet
    elif [ "$cet" == "1" ];then
        # CentOS
        yum remove -y kubectl kubeadm kubelet kubernetes-cni ossfs
    else
       echo "unkown os...   exit"
       exit 1
    fi
    rm -rf /var/lib/cni /etc/cni/ /run/flannel/subnet.env
    ip link del cni0 ; ip link del flannel.1
    set -e
}

export REGION=cn-hangzhou
export DISCOVERY=token://
main()
{

    while [[ $# -gt 1 ]]
    do
    key="$1"

    case $key in
        -k|--key-id)
            export KEY_ID=$2
            shift
        ;;
        -s|--key-secret)
            export KEY_SECRET=$2
            shift
        ;;
        -d|--discovery)
            export DISCOVERY=$2
            shift
        ;;
        -t|--node-type)
            export NODE_TYPE=$2
            shift
        ;;
        -r|--region)
            export REGION=$2
            shift
        ;;
        *)
                # unknown option
            echo "unkonw option [$key]"
        ;;
    esac
    shift
    done

    if [ "" == "$KEY_ID" -o "" == "$KEY_SECRET" ];then
        if [ "$NODE_TYPE" != "down" ];then
            echo "--key-id and --key-secret must be provided!"
            exit 1
        fi
    fi

    case $NODE_TYPE in
    "m" | "master" )
        kube::master_up
        ;;
    "n" | "node" )
        kube::node_up
        ;;
    "d" | "down" )
        kube::tear_down
        ;;
    *)
        echo "usage: $0 --node-type master --key-id xxxx --key-secret xxxx "
        echo "       $0 --node-type node --key-id xxxx --key-secret xxxx --discovery xxxx"
        echo "       $0 down   to tear down node or master"
        echo "       $0 master to setup master "
        echo "       $0 join   to join master with token "
        echo "       $0 down   to tear all down ,inlude all data! so becarefull"
        echo "       unkown command $0 $@"
        ;;
    esac
}

main $@