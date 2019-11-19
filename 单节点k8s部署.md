# 单节点Kubernetes部署
## 参考资料:
* [kubernetes官网英文版](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
* [kubernetes官网中文版](https://kubernetes.io/zh/docs/setup/independent/install-kubeadm/)

---

## 环境、工具
阿里云学生机ECS、Ubuntu、docker、kubectl1.15.4、kubelet1.15.4、kubeadm1.15.4、

---

## 安装kubeadm、kubectl、kubelet
### 配置软件源
默认apt软件源里没有这几个软件，需要添加谷歌官方的软件源。但又由于官方提供的源无法访问，需要改为阿里的源
```bash
curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
```
命令说明：
1.通过下载工具下载位于```https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg```的deb软件包密钥，然后通过"apt-key"命令添加密钥
2.通过cat把源```deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main```写入到"/etc/apt/sources.list.d/kubernetes.list"

<font color=red>*</font>此处下载工具使用<font color=red>curl</font>，若未安装，先执行如下命令安装。<font color=red>"apt-transport-https"</font>工具允许apt通过https来下载软件，可以不用安装这个，只装<font color=red>curl</font>
```bash
apt-get update && apt-get install -y apt-transport-https curl
```

完成以上步骤，可通过"apt-key list"命令看到类似如下的密钥信息:
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g8rwywmsf3j30nb06774k.jpg)
查看"/etc/apt/sources.list.d/kubernetes.list",如下:
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g8rx5myn55j30m005pgln.jpg)


### 选择软件版本
kubeadm、kubectl、kubelet三者的版本要一致，否则可能会部署失败，小版本号不同倒也不会出什么问题，不过尽量安装一致的版本。记住kubelet的版本不可以超过API server的版本。例如1.8.0的API server可以适配 1.7.0的kubelet，反之就不行了。
可以通过"apt-cache madison"命令来查看可供安装的软件的版本号
例：
```bash
apt-cache madison kubeadm kubelet kubectl
```

### 开始安装
这里安装的版本是"1.15.4-00"，别忘了后面的"-00"。
需要注意，安装kubeadm的时候，会自动安装kubectl、kubelet和cri-tool，安装kubelet时会自动安装kubernetes-cni，如下：
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g8rxx2lsk0j30mm08p75a.jpg)
然而这并不是一件好事，仔细看会发现自动安装的kubectl和kubelet是最新版本，与kubeadm版本不一致。。。
所以应该先安装kubectl和kubelet，命令如下：
```bash
apt-get install kubectl=1.15.4-00 kubelet=1.15.4-00 kubeadm=1.15.4-00
```
如果不想让软件自动更新，可以输入:
```bash
apt-mark hold kubeadm kubectl kubelet
```
允许更新：
```bash
apt-mark unhold kubeadm kubectl kubelet
```

---

## 部署前准备
### 关闭防火墙
在ubuntu下，可以使用"ufw"管理防火墙。
查看防火墙状态：
```bash
ufw status 
```
禁用防火墙:
```bash
ufw diable
```
启用防火墙:
```bash
ufw enable
```
### 关闭selinux
阿里云ecs没有selinux，在此不作验证，网上找到的方法如下:
* 修改/etc/selinux/config文件中设置SELINUX=disabled，然后重启服务器
* 使用setenforce
  * setenforce 1 设为enforcing模式
  * setenforce 0 设为permissive模式

### 关闭swap
* 临时修改，重启复原
  * 关闭 
  ```bash
  swapoff -a
  ``` 
  
  * 开启
  ```bash
  swapon -a
  ```
  
* 永久修改，重启生效
  1. 把根目录文件系统设为可读写
    ```bash
    sudo mount -n -o remount,rw /
    ```
    
  1. 修改"/etc/fstab"文件，在"/swapfile"一行前加#禁用并保存退出重启服务器

### 开启kubelet服务
```
systemctl enable kubelet
```


### 修改Docker的cgroup-driver
编辑"/etc/docker/daemon.json"
添加如下信息:
```bash
"exec-opts": ["native.cgroupdriver=systemd"]
```
注意，需要在前面的键值对后用“,”逗号隔开，再添加新的配置项，否则配置文件会解析失败。
修改完后保存，重新载入配置文件，重启docker
```bash
systemctl daemon-reload
systemctl restart docker
```

### 拉取镜像
查看kubeadm需要的镜像:
```bash
kubeadm config images list --kubernetes-version=1.15.4
```
结果如下:
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g92h27b8wgj30m008wwf0.jpg)
&emsp;&emsp;这些都是k8s基本组件的镜像，通过kubeadm初始化集群时，kubeadm先检查本地是否已有这些镜像并拉取缺失的镜像，接着生成配置文件，再然后构建容器运行，即可完成集群的初始化工作。
&emsp;&emsp;由于kubeadm默认指定的镜像源需要挂梯子才能访问，因此，可以手动查找合适的镜像拉取到本地，再通过tag把镜像更名成和上诉"list"的结果一样。但是该操作过于繁琐，可以写脚本来实现，网上也有很多这样的脚本，这里贴一份:
```bash
cat <<EOF >$HOME/pull-k8s-images.sh
#!/bin/bash
KUBE_VERSION=v1.15.4
KUBE_PAUSE_VERSION=3.1
ETCD_VERSION=3.3.10
DNS_VERSION=1.3.1
username=mirrorgooglecontainers

images="kube-proxy-amd64:\${KUBE_VERSION} 
kube-scheduler-amd64:\${KUBE_VERSION} 
kube-controller-manager-amd64:\${KUBE_VERSION} 
kube-apiserver-amd64:\${KUBE_VERSION} 
pause:\${KUBE_PAUSE_VERSION} 
etcd-amd64:\${ETCD_VERSION} 
"

for image in \$images
do
    ##remove "-amd64"
    newImage=\${image//-amd64/}
    docker pull \${username}/\${image}
    docker tag \${username}/\${image} k8s.gcr.io/\${newImage}
    docker rmi \${username}/\${image}
done
docker pull coredns/coredns:\${DNS_VERSION}
docker tag coredns/coredns:\${DNS_VERSION} k8s.gcr.io/coredns:\${DNS_VERSION}
docker rmi coredns/coredns:\${DNS_VERSION}
#remove var
unset ARCH version images username
EOF
```
&emsp;&emsp;需要根据自己的需求修改脚本内容，镜像源地址在短期内应该还是有效的。
这时候在执行"$HOME"目录下的"pull-k8s-images.sh"脚本即可。
```bash
bash $HOME/pull-k8s-images.sh
```
&emsp;&emsp;镜像拉取完了，用"docker images -a"命令查看是否与之前list的结果一样，也可以用"kubeadm config images pull --kubernetes-version=1.15.4"尝试拉取，一般不报错就没问题。

---  

## 开始部署
```bash
kubeadm init --kubernetes-version=v1.15.4 --ignore-preflight-errors=NumCPU --pod-network-cidr=10.244.0.0/16 
```
参数说明:
* "kubernetes-version"：指定k8s的版本，对于不同版本k8s，kubeadm会去拉取不同版本的镜像，因此为了部署成功，需要指定与之前拉取镜像时相同的版本号。

* "--ignore-preflight-errors"：kubeadm在初始化之前，会执行“preflight”(预检)，当条件不满足时会报错并停止初始化进程，但是有些报错并不会影响集群的初始化，因此可以指定该参数忽略特定的错误。阿里云学生机cpu只有单核，而k8s要求双核及以上，所以需要指定参数"--ignore-preflight-errors=NumCPU"。
该参数的用法如下：
```bash
--ignore-preflight-errors=<option>
```
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g92i7g3vluj30oy02rdgg.jpg)
\<option>就是错误的类型，如上图所示，错误提示是"[ERROR NumCPU]"，那么参数就写成:
```bash
--ignore-preflight-errors=NumCPU
```

* "--pod-network-cidr": 指定使用"cidr"方式给pod分配IP，参数的数值必须跟后面网络插件的配置文件一致。后面用到的网络插件为flannel，flannel配置文件中默认的数值是“10.244.0.0/16”

---

## 查看部署状态

![](https://tva1.sinaimg.cn/large/006y8mN6gy1g92im4qgl9j30sg0bjjt7.jpg)

&emsp;&emsp;当看到上述信息就表示集群Master节点初始化成功，在同一网络下的机器上同样地安装kuneadm、kubelet并配置好环境之后，即可通过"kubeadm join"命令连接到Master节点使集群成为多节点集群:
```bash
kubeadm join 192.168.1.73:6443 --token gkp9ws.rv2guafeusg7k746 \
    --discovery-token-ca-cert-hash sha256:4578b17cd7198a66438b3d49bfb878093073df23cf6c5c7ac56b3e05d2e7aec0
```
该token默认有效期为24小时，可通过"kubeadm token create --print-join-command"命令创建新token，并打印连接命令:
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g938k3vq0wj30sg06swf0.jpg)

---

&emsp;&emsp;在master节点上可以通过kubectl命令来查看集群上资源的状态，为避免出现"Unable to connect to the server"这样的错误，在使用该命令前，需要配置下环境变量。
```
export KUBECONFIG=/etc/kubernetes/admin.conf
```
<font color=red>也可以把这条变量添加到"/etc/profile"，然后"source /etc/profile"。</font>
添加好环境变量后，通过"kubectl get node"即可看到集群的所有节点状态:
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g9386unkkdj30m006sdfz.jpg)
&emsp;&emsp;可以看到当前节点处于"NotReady"状态，通过"kubectl describe node \<your_node>"命令查看node情况，\<your_node>替换成自己的节点名，此时可以看到这样的信息:
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g938aacsllj313g03njsf.jpg)
在"Ready"一行，"status"为"false"，"message"提示"Runtime newtwork not ready"，意思是网络插件未准备好，所以此时应该给集群安装网络插件。

---

## 安装网络插件
网络插件有很多种，此处选择"flannel"，flannel的安装比较简单，直接指定配置文件，用"kubectl"安装即可。配置文件如下:
<details><summary>flannel.yaml</summary>
<pre>
---
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: psp.flannel.unprivileged
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: docker/default
    seccomp.security.alpha.kubernetes.io/defaultProfileName: docker/default
    apparmor.security.beta.kubernetes.io/allowedProfileNames: runtime/default
    apparmor.security.beta.kubernetes.io/defaultProfileName: runtime/default
spec:
  privileged: false
  volumes:
    - configMap
    - secret
    - emptyDir
    - hostPath
  allowedHostPaths:
    - pathPrefix: "/etc/cni/net.d"
    - pathPrefix: "/etc/kube-flannel"
    - pathPrefix: "/run/flannel"
  readOnlyRootFilesystem: false
  # Users and groups
  runAsUser:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  # Privilege Escalation
  allowPrivilegeEscalation: false
  defaultAllowPrivilegeEscalation: false
  # Capabilities
  allowedCapabilities: ['NET_ADMIN']
  defaultAddCapabilities: []
  requiredDropCapabilities: []
  # Host namespaces
  hostPID: false
  hostIPC: false
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  # SELinux
  seLinux:
    # SELinux is unused in CaaSP
    rule: 'RunAsAny'
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: flannel
rules:
  - apiGroups: ['extensions']
    resources: ['podsecuritypolicies']
    verbs: ['use']
    resourceNames: ['psp.flannel.unprivileged']
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes/status
    verbs:
      - patch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-system
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-system
  labels:
    tier: node
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds-amd64
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: beta.kubernetes.io/os
                    operator: In
                    values:
                      - linux
                  - key: beta.kubernetes.io/arch
                    operator: In
                    values:
                      - amd64
      hostNetwork: true
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: quay.io/coreos/flannel:v0.11.0-amd64
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.11.0-amd64
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_ADMIN"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run/flannel
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds-arm64
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: beta.kubernetes.io/os
                    operator: In
                    values:
                      - linux
                  - key: beta.kubernetes.io/arch
                    operator: In
                    values:
                      - arm64
      hostNetwork: true
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: quay.io/coreos/flannel:v0.11.0-arm64
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.11.0-arm64
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
             add: ["NET_ADMIN"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run/flannel
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds-arm
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: beta.kubernetes.io/os
                    operator: In
                    values:
                      - linux
                  - key: beta.kubernetes.io/arch
                    operator: In
                    values:
                      - arm
      hostNetwork: true
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: quay.io/coreos/flannel:v0.11.0-arm
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.11.0-arm
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
             add: ["NET_ADMIN"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run/flannel
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds-ppc64le
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: beta.kubernetes.io/os
                    operator: In
                    values:
                      - linux
                  - key: beta.kubernetes.io/arch
                    operator: In
                    values:
                      - ppc64le
      hostNetwork: true
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: quay.io/coreos/flannel:v0.11.0-ppc64le
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.11.0-ppc64le
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
             add: ["NET_ADMIN"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run/flannel
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds-s390x
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: beta.kubernetes.io/os
                    operator: In
                    values:
                      - linux
                  - key: beta.kubernetes.io/arch
                    operator: In
                    values:
                      - s390x
      hostNetwork: true
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: quay.io/coreos/flannel:v0.11.0-s390x
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.11.0-s390x
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
             add: ["NET_ADMIN"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run/flannel
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg
</pre>
</details>

![](https://tva1.sinaimg.cn/large/006y8mN6gy1g9391bsfyxj30bb04gjrr.jpg)

128行的network数值应与"kubeadm"初始化时指定的"--pod-network-cidr"一致，该值表示给pod分配ip时的ip前缀。
创建好配置文件后，通过"kubeclt"安装flannel:
```bash
kubectl create -f <flannel_yaml_path>
```
把\<flannel_yaml_path>替换成自己的配置文件路径，执行命令后稍等片刻，单节点k8s集群就部署好了。

---

## 测试
### 处理taint
默认情况下，master节点会被打上一个叫"NoSchedule"的Taint(污点)，可以通过"kubectl describe"看到:
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g93bbdazqhj30kb08umyr.jpg)
这个taint使得master节点不能被调度，也就是说master节点不能部署应用，由于现在搭建的是单节点集群，当前节点既充当master又得充当worker，所以需要把这个taint去掉:
```bash
kubectl taint node <node_name> <taint>-
```
\<node_name>替换成自己节点名称，\<taint>替换成taint，如:
```bash
kubectl taint node yo node-role.kubernetes.io/master:NoSchedule-
```
<font color=red>注意别忘了taint后面的横杠"-"，"-"表示“减号”，即把taint“减去”</font>
###运行nginx:
```bash
docker pull nginx
kubectl run nginx --image=nginx
```
稍等片刻nginx就部署好了，可以通过"kubectl get pods --all-namespaces"查看，或者直接访问"curl localhost:80"。

---

## 排错工具
### kubectl 
##### kubectl get \<resource_type>
&emsp;&emsp;"kubectl get"可以列出集群环境中的某类资源，对于k8s，几乎所有内容都是“资源”，如Node、Pod、Service等，只要把"\<resource_type>"替换成想查看的资源类型即可。
如查看节点资源:
```bash
kubectl get node
```
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g939kcba10j30m006s3yn.jpg)
&emsp;&emsp;对于pod等其它的资源，kubectl的用法会有些许不同。k8s使用"namespace"来对集群中的资源进行分组管理，可以把"namespace"当做“分组的名称”，也可以把"namespace"当做k8s集群中的"集群"，不同"namespace"的资源在逻辑上彼此隔离，以此提高安全性，提高管理效率。用kubeectl查看这些个资源时，需要用"-n"来指定"namespace"，如：
```bash
kubectl get pod -n kube-system
```
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g939v9wrl0j30m00ahmy6.jpg)
还可以用"--all-namespaces"来查看所有"namespaces"下的资源:
```bash
kubectl get pod --all-namespaces
```
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g939ytitjhj30ok05ejsp.jpg)

---

##### kubectl describe \<resource_type> \<resource_name>
&emsp;&emsp;对于处于异常状态的资源，可以使用该命令查看其详细信息，只要把\<resource_type>替换成资源类别，把\<resource_name>替换成资源名称即可，当然也还需要用"-n"指明"namespaces"。
如:
```bash
kubectl describe pod -n kubernetes-dashboard kubernetes-dashboard-6b855d4584-9sgsk
```
然后就可以看到该pod的事件信息:
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g93a6s065cj313g043dgz.jpg)

---

##### docker ps -a
&emsp;&emsp;该命令可以查看当前所有docker容器，"-a"表示所有容器，当不加该参数时，显示的则是正在运行的容器。由于要查看的是k8s相关的容器，以此可以使用管道命令和"grep"对显示结果进行筛选:
```bash
docker ps -a | grep kube
```
对于处于"Exited"状态的异常容器，使用"docker logs \<container_id>"命令查看容器日志。如：
```bash
docker logs 37443d902aee
```
此处"37443d902aee"是我机器上"kubernetes-dashboard"的容器id。

---

## 友情链接
[Kubernetes最佳实践之：命名空间（Namespace）](https://blog.csdn.net/ouyangtianhan/article/details/85107967)



