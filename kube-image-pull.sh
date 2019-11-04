#!/bin/bash
KUBE_VERSION=v1.17.0-alpha.0
KUBE_PAUSE_VERSION=3.1
ETCD_VERSION=3.2.18
DNS_VERSION=1.1.3
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
    docker pull ${username}/${image}
    docker tag ${username}/${image} k8s.gcr.io/${image}
    #docker tag ${username}/${image} gcr.io/google_containers/${image}
    docker rmi ${username}/${image}
done
docker pull anjia0532/coredns:${DNS_VERSION}
docker tag anjia0532/coredns:${DNS_VERSION} k8s.grc.io/${DNS_VERSION}
docker rmi anjia0532/coredns:${DNS_VERSION}
unset ARCH version images username

