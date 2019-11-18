#!/bin/bash
KUBE_VERSION=v1.15.4
KUBE_PAUSE_VERSION=3.1
ETCD_VERSION=3.3.10
DNS_VERSION=1.3.1
username=mirrorgooglecontainers

images="kube-proxy-amd64:${KUBE_VERSION} 
kube-scheduler-amd64:${KUBE_VERSION} 
kube-controller-manager-amd64:${KUBE_VERSION} 
kube-apiserver-amd64:${KUBE_VERSION} 
pause:${KUBE_PAUSE_VERSION} 
etcd-amd64:${ETCD_VERSION} 
"

for image in $images
do
    ##remove "-amd64"
    newImage=${image//-amd64/}
    docker pull ${username}/${image}
    docker tag ${username}/${image} k8s.gcr.io/${newImage}
    docker rmi ${username}/${image}
done
docker pull coredns/coredns:${DNS_VERSION}
docker tag coredns/coredns:${DNS_VERSION} k8s.gcr.io/coredns:${DNS_VERSION}
docker rmi coredns/coredns:${DNS_VERSION}
#remove var
unset ARCH version images username

