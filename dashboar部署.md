# kubernetes-dashboard部署
## 参考资料
* [kubernetes官方文档](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
* [官方GitHub](https://github.com/kubernetes/dashboard)
* [创建访问用户](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md)
* [解决chrome无法访问dashboard](https://blog.51cto.com/10616534/2430512)

-------

官方部署方法如下:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml
```
该方法是通过指定官方的[yaml文件](https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml), 通过kubectl来进行部署，然而这个方法存在很多问题，首先是该yaml文件的地址有时候并不能访问，需要挂梯子；其次，该文件指定的dashboard的镜像也需要梯子才能访问；再者，部署的dashboard的证书过期时间有问题，导致chrome、safari等都不能访问，仅firefox可以访问。所以需要对部署流程做调整，先创建自签证书，再用证书来部署。

------

## 生成自签证书
1) 生成证书请求的key

```bash
openssl genrsa -out dashboard.key 2048
```

2) 生成证书请求
```bash
openssl req -new -out dashboard.csr -key dashboard.key -subj '/CN=<your_ip>'
``` 
<font color=red>\<your_ip>换成自己的ip或域名？？</font>
3) 生成自签证书
```bash
openssl x509 -days 3650 -req -in dashboard.csr -signkey dashboard.key -out dashboard.crt
``` 
<font color=red>这里指定了过期时间3650天，默认365天</font>

----------

## 部署kubernetes-dashboard
1) 创建部署kubernetes-dashboard的yaml文件
<details><summary>kubernetes-dashboard.yaml</summary><pre>
# Copyright 2017 The Kubernetes Authors.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
 
apiVersion: v1
kind: Namespace
metadata:
  name: kubernetes-dashboard
---

apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
 ---

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  type: NodePort #NodePort方式,改用其它方式把这行去掉
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 32100 #NodePort方式端口，改用其它方式把这行去掉
  selector:
    k8s-app: kubernetes-dashboard
---

#不要用自带的证书，自带证书时间出错
#apiVersion: v1
#kind: Secret
#metadata:
#  labels:
#    k8s-app: kubernetes-dashboard
#  name: kubernetes-dashboard-certs
#  namespace: kubernetes-dashboard
#type: Opaque
---

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-csrf
  namespace: kubernetes-dashboard
type: Opaque
data:
  csrf: ""
---

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-key-holder
  namespace: kubernetes-dashboard
type: Opaque
---

kind: ConfigMap
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-settings
  namespace: kubernetes-dashboard
---

kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
rules:
  # Allow Dashboard to get, update and delete Dashboard exclusive secrets.
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["kubernetes-dashboard-key-holder", "kubernetes-dashboard-certs", "kubernetes-dashboard-csrf"]
    verbs: ["get", "update", "delete"]
    # Allow Dashboard to get and update 'kubernetes-dashboard-settings' config map.
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["kubernetes-dashboard-settings"]
    verbs: ["get", "update"]
    # Allow Dashboard to get metrics.
  - apiGroups: [""]
    resources: ["services"]
    resourceNames: ["heapster", "dashboard-metrics-scraper"]
    verbs: ["proxy"]
  - apiGroups: [""]
    resources: ["services/proxy"]
    resourceNames: ["heapster", "http:heapster:", "https:heapster:", "dashboard-metrics-scraper", "http:dashboard-metrics-scraper"]
    verbs: ["get"]
---

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
rules:
  # Allow Metrics Scraper to get metrics from the Metrics server
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods", "nodes"]
    verbs: ["get", "list", "watch"]
---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kubernetes-dashboard
subjects:
  - kind: ServiceAccount
    name: kubernetes-dashboard
    namespace: kubernetes-dashboard
---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kubernetes-dashboard
subjects:
  - kind: ServiceAccount
    name: kubernetes-dashboard
    namespace: kubernetes-dashboard
---

kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
    spec:
      containers:
        - name: kubernetes-dashboard
          #image: registry.cn-hangzhou.aliyuncs.com/kubernetesui/dashboard:v2.0.0-beta5
          image: kubernetesui/dashboard:v2.0.0-beta5
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8443
              protocol: TCP
          args:
            - --auto-generate-certificates
            - --namespace=kubernetes-dashboard
            # Uncomment the following line to manually specify Kubernetes API server Host
            # If not specified, Dashboard will attempt to auto discover the API server and connect
            # to it. Uncomment only if the default does not work.
            # - --apiserver-host=http://my-address:port
          volumeMounts:
            - name: kubernetes-dashboard-certs
              mountPath: /certs
              # Create on-disk volume to store exec logs
            - mountPath: /tmp
              name: tmp-volume
          livenessProbe:
            httpGet:
              scheme: HTTPS
              path: /
              port: 8443
            initialDelaySeconds: 30
            timeoutSeconds: 30
      volumes:
        - name: kubernetes-dashboard-certs
          secret:
            secretName: kubernetes-dashboard-certs
        - name: tmp-volume
          emptyDir: {}
      serviceAccountName: kubernetes-dashboard
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
---

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: dashboard-metrics-scraper
  name: dashboard-metrics-scraper
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 8000
      targetPort: 8000
  selector:
    k8s-app: dashboard-metrics-scraper
---

kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: dashboard-metrics-scraper
  name: dashboard-metrics-scraper
  namespace: kubernetes-dashboard
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: dashboard-metrics-scraper
  template:
    metadata:
      labels:
        k8s-app: dashboard-metrics-scraper
    spec:
      containers:
        - name: dashboard-metrics-scraper
          image: kubernetesui/metrics-scraper:v1.0.1
          ports:
            - containerPort: 8000
              protocol: TCP
          livenessProbe:
            httpGet:
              scheme: HTTP
              path: /
              port: 8000
            initialDelaySeconds: 30
            timeoutSeconds: 30
          volumeMounts:
          - mountPath: /tmp
            name: tmp-volume
      serviceAccountName: kubernetes-dashboard
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      volumes:
        - name: tmp-volume
          emptyDir: {}
</pre></details>
<font color=red>这里根据官方文件做了微调: 1)把cert注释掉，使用待会自己创建的cert,因为默认的证书有问题 2)把dashboard访问方式改为NodePort,端口是32100，访问时用主机ip加端口号即可访问; 3)imagePullPolicy改为IfNotPresent,当本地找不到镜像时才从网上拉取; 
注意查看镜像路径是否有效，如果无效，自行百度查找镜像源，或者到别的地方把镜像下载到本地，然后把tag改成和yaml文件中的image一致</font>

-------

2) 部署kubernetes-dashboard
```bash
kubectl create -f <yaml_path>
```
<font color=red>\<yaml_path>换成自己yaml的路径</font>

-------

3) 部署完成后还是不能访问，因为yaml文件中注释掉了kubernetes-dashboard-certs，相关的pod没跑起来，所以此时应创建certs
```bash
kubectl create secret generic kubernetes-dashboard-certs --from-file=dashboard.key --from-file=dashboard.crt -n kubernetes-dashboard
```
<font color=red>"dashboard.key"、"dashboard.crt"是之前生成的自签证书的相关文件的路径，这里用相对路径，所以直接给个名字;  创建的secret名为"kubernetes-dashboard-certs"; 用"-n kubernetes-dashboard"指明命名空间"kubernetes-dashboard",可自行更改，不过建议用这个，因为后面的操作是接着这里的</font>
    
-------

4) 一般经过以上步骤就可以访问dashboard，可以跳过这一步了，但如果此时仍不能访问，pod不是处于"running"状态，可以删除kubenetes-dashboard相关的pod，让kubelet自动生成一个新的可运行的pod

  查看kubernetes-dashboard的pod名:
```bash
kubectl get pods -n kubernetes-dashboard 
```
  删除该pod:
```bash
kubectl delete pod -n kubernetes-dashboard <pod名>
```
5) 如果chrome仍然无法访问，需要到设置里把证书设置为"受信任证书"

## 创建访问用户
### 创建用于访问dashboard的Service Account
admin-user.yaml:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
```
```bash
kubectl create -f admin-user.yaml
```
### 为用户绑定角色，创建ClusterRoleBinding
rolebinding.yaml:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```
```bash
kubectl create -f rolebinding.yaml
```

------

也可以把两个yaml文件合成一个，中间用"---"隔开,用一个"kubectl create"语句即可，如下：
<details><summary>dashboard-adminuser.yaml</summary>
<pre>
## 创建名为admin-user的用户
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---

## 把集群角色cluster-admin绑定到admin-user
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
</pre>
</details>
<details><summary>操作命令:</summary>
```bash
kubectl create -f dashboard-adminuser.yaml
```
</details>

--------

不用配置文件，直接命令行也是可以的:
<details><summary>示例</summary>
在"kubernetes-dashboard"命名空间下创建一个名为"admin-user"的用户:
<pre>
kubectl create serviceaccount admin-user -n kubernetes-dashboard
</pre>
创建一个叫"admin-user"的“角色绑定”,给"admin-user"用户授予"cluster-admin"角色:
<pre>
kubectl create clusterrolebinding admin-user -–clusterrole=cluster-admin –-serviceaccount=kubernetes-dashboard:admin-user
</pre>
</details>

---------

### 获取登录密钥
在上面创建用户的时候，kubectl会自动生成一个对应该用户的"secret",”secret“的名字是以用户名为前缀加上"-token-五位随机序列"，例如创建的是"admin-user",在我电脑上的"secret"为"admin-user-token-5fkcr",
此时通过"kubectl describe"命令即可看到该用户的token，但由于kubernetes中的密钥太多，所以需要用以下命令筛选出需要的密钥:
```bash
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
```
得到类似如下的信息，把”token“后面那一串复制到dashboard登录,然后就可以愉快的玩耍啦
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g8m4y06ce2j30sg0gpae1.jpg)
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g8m94rolt9j30mc09zt9t.jpg)
![](https://tva1.sinaimg.cn/large/006y8mN6gy1g8m96wbrgyj30y90jw0vh.jpg)

## 补充
以上对官方的yaml做了修改，把dashboard部署方式改为NodePort,以使得可以外网访问，当然这是不太安全的，最好是改为ingress或apiserver方式；如果使用官方默认部署方式，只能本机访问，而且需要先开启代理
```
kubectl proxy
```
访问地址是:
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/.
