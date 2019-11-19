# kubernetes基础
##容器
<center>![](https://tva1.sinaimg.cn/large/006y8mN6gy1g922v2w1byj30e8063gmc.jpg)</center>
&emsp;&emsp;容器技术是虚拟化技术的一种，以Docker为例，Docker利用Linux的LXC(LinuX Containers)技术、CGroup(Controll Group)技术和AUFS(Advance UnionFileSystem)技术等，通过对进程和资源加以限制，进行调控，隔离出来一套供程序运行的环境。 我们把这一环境称为“容器”，把构建该“容器”的“只读模板”，称之为“镜像”。 
&emsp;&emsp;容器是独立的、隔离的，不同容器间不能直接通信，容器与宿主机也是隔离开来的，容器不能直接感知到宿主机的存在，同时宿主机也无法直接窥探容器内部。 
&emsp;&emsp;虽然容器与宿主机在环境上，逻辑上是隔离的，但容器与宿主机共享内核，容器直接依赖于宿主机Linux系统的内核，这与传统虚拟化技术不同，后者是在宿主机的操作系统上，虚拟化一套硬件环境，然后在此环境上运行需要的操作系统。容器技术常用来在宿主机上隔离出环境来部署应用，而传统虚拟化技术常用来运行一个与宿主机不同的操作系统，从而运行特定的软件。
&emsp;&emsp;容器非常轻量级，无论是启动速度，资源占用情况，灵活性等均优于传统的虚拟化技术。容器的特性给开发生产提供了非常大的便利：
* DevOps理念，开发者可以使用同一个镜像，在开发环境、测试环境和生产环境构建相同的容器，即相同的程序运行环境，这样可以大大减少前期的环境部署时间，可以有效避免由于各个环境不一致而造成的灾难。 
* “容器”与“微服务”常是一起出现的一组名词，有了容器技术以后，可以更加方便的部署微服务，例如，可以把评论服务部署到一个容器里，把阅读的服务部署到另一个容器，这样在一个服务崩溃时不至于影响到其它服务，再者，容器启动速度快，可以在极短时间内恢复。
* 很多时候，一些环境、工具需要复用，这时候容器是个很好的选择，我们可以把环境和工具打包成镜像，需要的时候用来构建容器使用。在Docker的镜像仓库上，也有很多官方的或第三方的镜像，这些镜像都是别人已经打包好的工具或者环境，我们只需一条命令，就可以把镜像拉取下来并构建容器启动，免去了自己动手开发部署的麻烦。

[Docker技术解析](https://www.cnblogs.com/hwlong/articles/9060557.html)

##集群
&emsp;&emsp;计算机是独立的，但我们可以通过一系列技术、软件，把分散的算力有效的集中起来，把多台独立的计算机当做一个整体来使用，而且这些计算机实现相同的业务，这就是集群。

##分布式
&emsp;&emsp;分布式就是把一个系统拆分开来部署到不同机器，与集群相同的是，两者都需要多台服务器，不同点是分布式并不强调实现相同的业务。貌似网上大多数资料，对于集群和分布式的区分，都执着于两者是否实现相同的业务，即不同服务器运行同一份功能就是集群，运行不同功能就是分布式。个人看法是，集群强调的是“集”、“统一的概念”，是物理上的、环境上的概念，只要是多台计算机搞在一起就是集群；而分布式，更多的是描述应用系统的部署方式，把一个系统拆开部署到不同服务器，就是分布式。这里有一篇关于分布式和集群的文章——[浅谈集群与分布式的区别](http://www.imooc.com/article/details/id/290175)

##微服务
&emsp;&emsp;有必要提一下微服务，虽然微服务与kubernetes没有必然联系，但微服务和分布式是有一定联系的，微服务和分布式都强调“拆”、“分”，但微服务描述的是应用系统的架构，即怎么样把系统拆分，拆成多“微”，这是微服务需要考虑的；而分布式，强调的是“分布”，即系统的部署方式，该怎么把系统的模块分布好，从而提高容灾能力、高可用性。当“微服务”应用部署到一台服务器上，它就是“微服务应用”，当把“微服务”应用的模块分开来部署到不同服务器，那么它也成了“分布式应用”。
&emsp;&emsp;关于“集群”、“分布式”、“微服务”三者的联系与区别——[微服务，分布式，集群三者区别联系](http://blog.csdn.net/qq646040754/article/details/81511795)

##kubernetes
&emsp;&emsp;"kubernetes"这个词比较长，常简写成k8s，"8"表示中间的8个字母。k8s是谷歌开源的用于管理容器化应用和服务的平台，k8s是容器化集群管理平台。通过k8s以及容器引擎(Docker或rtk或其它)，可以非常方便快速地搭建集群环境。这样部署出来的集群有一个特点——容器化，在集群中部署的应用，都是采用容器化的方式进行部署，即把应用放到容器中运行，至于这个容器是在集群中哪个节点运行，就交由集群管理人员和k8s控制。
&emsp;&emsp;通过k8s，能够进行应用的自动化部署和扩缩容，k8s可以根据事先配置好的配置文件，实时监测<font color=red>容器</font>的运行状态，当<font color=red>容器</font>出现问题时，k8s会自动地重建<font color=red>容器</font>，当负载上升时，k8s会自动扩容，创建新的<font color=red>容器</font>。这里说<font color=red>容器</font>其实并不恰当，因为k8s的基本调度单位是<font color=red>“pod”</font>，下文会介绍。 

&emsp;&emsp;关于kubernetes，这篇文章总结的很好——[k8s-整体概述和架构](https://www.cnblogs.com/wwchihiro/p/9261607.html)。
![k8s架构图](https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1574014452459&di=f4a9b2b9a546008b0792bf949712b6fe&imgtype=0&src=http%3A%2F%2Fimg2018.cnblogs.com%2Fblog%2F916267%2F201812%2F916267-20181202113142615-1452130758.png)
<center>k8s架构图</center>

##k8s基础概念解析

###Pod
&emsp;&emsp;Pod是k8s的基本调度单位，Pod包含一个或一组Container(容器)，这些Container共享Pod的IP，所以一个Pod内的Container可以通过localhost+各自的端口进行通信，跨Pod的通信，则通过对应的PodIP+端口进行。再次提到，Pod是k8s的基本调度单位，所以要想运行一个Container，必须先为其创建一个Pod。

---

###Node(节点)
&emsp;&emsp;一个node，就是k8s集群中的一个服务器，node分为Master Node和Worker Node。
#####Master Node
&emsp;&emsp;顾名思义，Master Node就是集群中的控制中心，负责整个集群的控制、管理。默认情况下，在部署集群时master会被分配一个名为NoSchedule的Taint(污点)，这个taint使得master节点不能被调度，也就是说新建Pod时，Pod不会被分配到master节点。

#####Worker Node

&emsp;&emsp;Worker Node用于承载应用的运行，k8s会根据配置文件中的策略，对worker node进行调度，把pod分配到合适的worker node。

---

###CRI(容器运行时接口)
&emsp;&emsp;全称"Container-Runtime-Interface"，k8s通过CRI对容器进行操作，启停容器等。安装kubeadm时会自动安装cri-tool
从v1.6.0起，Kubernetes开始允许使用CRI，即容器运行时接口。默认的容器运行时是Docker，这是由kubelet内置的CRI实现——dockershim开启的。
其他的容器运行时有：
containerd (containerd 的内置 CRI 插件)
cri-o
frakti
rkt

---

###CNI(容器网络接口)
&emsp;&emsp;全称"Container-Network-Interface"，其实现为各种网络插件(network-plugin)如：flannel等。cni用于给pod分配ip，其配置文件里包含"--pod-network-cidr"参数，该参数表示用"cidr"(<font color=blue>《计算机网络基础》的知识</font>)方法给pod分配ip，数值表示ip的前缀，如flannel的官方的配置文件中的默认值为10.244.0.0/16，把10.244.0.0转换成二进制表示，取前面16位，即为pod的ip的前缀。


##k8s组件简介
###Kubectl(集群控制器)
&emsp;&emsp;kubectl全称"Kubernetes-Controller"，运行于master节点，是k8s的控制工具，是一个命令行工具，是用户管理k8s集群的接口，负责把用户的指令传给API Server，用于集群中资源的增删查改，注意，kubeclt只是个交互接口，并不负责实际上的资源的增删查改。
&emsp;&emsp;在k8s中的所有内容都被抽象为“资源”，如Pod、Service、Node等都是资源。“资源”的实例可以称为“资源对象”，如某个具体的Pod、某个具体的Node。这有点类似Java中的“类”和“对象”的概念。k8s中的资源有很多种，kubectl可以通过配置文件来创建这些“资源对象”，配置文件更像是描述对象“属性”的文件，配置文件格式可以是“JSON”或“YAML”，不过常用的是“YAML”。

---

###Kubelet(节点代理)
&emsp;&emsp;运行在所有节点上。Kubelet全称"Kubernetes-Lifecycle-Event-Trigger"，也是Kubernetes中最主要的控制器，kubelet被称为"Node Agent"，意思是“节点上的代理”。如果说kubectl是决策者，那么kubelet相当于是管理者、执行者；如果说kubectl是总裁，那么kubelet就是各个分公司的总经理。

kubelet的主要工作如下:
* pod管理：kubelet会监测本节点上pod、container的健康，出错时根据配置文件的重启策略，对pod、container进行重启。 kubelet还会定期通过API Server获取本节点上的pod、container状态的期望值，然后调用容器运行时接口，对container进行调度。

* 资源监控：kubelet监控本节点资源使用情况，定时向master报告，知道整个集群所有节点的资源情况，对于pod的调度和正常运行至关重要。

---

###API Server(网关)
&emsp;&emsp;API Server运行在master节点。对于整个k8s集群，可以把kubectl看做前端，看作集群管理员与k8s集群交互的接口。而API Server则相当于后端的"Controller"，负责对各个组件(包括kubectl)发来的请求进行分发、处理。各个组件都与API Server进行通信，而API Server则是各个组件间通信的桥梁，是消息的中转地。
&emsp;&emsp;值得一提的是，各个组件与API Server的通信是api是RESTful风格的api，这与“万物皆资源”的理念是相符的。
&emsp;&emsp;另外，API Server也作为集群的网关。默认情况，客户端通过API Server对集群进行访问，客户端需要通过认证，并使用API Server作为访问Node和Pod（以及service）的堡垒和代理/通道。

---

###Etcd(集群信息存储)
&emsp;&emsp;运行在Master节点。etcd与zookeeper相识但又不同，在分布式中经常会见到，是一个键值存储仓库，用于配置共享和服务发现。接着上面讲的，etcd相当于后端中的数据库，用于存储集群中的所有状态，包括各个节点的信息，集群中的资源状态等等。etcd的watch机制可以在信息发生变化时，快速的通知集群中相关的组件。

---

###Scheduler(调度器)
&emsp;&emsp;运行在Master节点。scheduler组件为容器自动选择运行的主机。依据请求资源的可用性，服务请求的质量等约束条件，scheduler监控未绑定的pod，并将其绑定至特定的node节点。Kubernetes也支持用户自己提供的调度器，Scheduler负责根据调度策略自动将Pod部署到合适Node中，调度策略分为预选策略和优选策略，Pod的整个调度过程分为两步：

1）预选Node：遍历集群中所有的Node，按照具体的预选策略筛选出符合要求的Node列表。如没有Node符合预选策略规则，该Pod就会被挂起，直到集群中出现符合要求的Node。

2）优选Node：预选Node列表的基础上，按照优选策略为待选的Node进行打分和排序，从中获取最优Node。

---

###Controller-Manager(管理控制中心)
&emsp;&emsp;运行在Master节点。如果说API Server是后端中的controller，那么Controller-Manager就是后端中的server。
Controller-Manager Serve用于执行大部分的集群层次的功能，它既执行生命周期功能(例如：命名空间创建和生命周期、事件垃圾收集、已终止垃圾收集、级联删除垃圾收集、node垃圾收集)，也执行API业务逻辑（例如：pod的弹性扩容）。控制管理提供自愈能力、扩容、应用生命周期管理、服务发现、路由、服务绑定和提供。Kubernetes默认提供Replication Controller、Node Controller、Namespace Controller、Service Controller、Endpoints Controller、Persistent Controller、DaemonSet Controller等控制器。
负责集群内的Node、Pod副本、服务端点（Endpoint）、命名空间（Namespace）、服务账号（ServiceAccount）、资源定额（ResourceQuota）的管理，当某个Node意外宕机时，Controller Manager会及时发现并执行自动化修复流程，确保集群始终处于预期的工作状态。

---

