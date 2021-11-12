# GO (TCP) Echo

A Simple go TCP echo server. Written to learn and test [Kubernetes | Istio] TCP networking.



## 概述

使用Istio的流量管理模型，本质上是将流量与基础设施扩容进行解耦，让运维人员可以通过Pilot指定流量遵循什么规则，而不是指定哪些pods/VM应该接收流量。通过将流量从基础设施扩展中解耦，就可以让 Istio 提供各种独立于应用程序代码之外的流量管理功能。 这些功能都是通过部署的Envoy sidecar代理来实现的。

在一个典型的网格中，通常有一个或多个用于终结外部 TLS 链接，将流量引入网格的负载均衡器（我们称之为 gateway），然后流量通过sidecar gateway流经内部服务。下图描绘了网关在网格中的使用情况：
![图片.png](http://ata2-img.cn-hangzhou.img-pub.aliyun-inc.com/48b4f3c8a8985c624251e447168fe73b.png)

Istio Gateway 为 HTTP/TCP 流量配置了一个负载均衡，多数情况下在网格边缘进行操作，用于启用一个服务的入口（ingress）流量。网格中可以存在任意数量的 Gateway，并且多个不同的 Gateway 实现可以共存。 对于入口流量管理，可能会问为什么不直接使用 Kubernetes Ingress API ？ 原因是 Ingress API 无法表达 Istio 的路由需求。 Ingress 试图在不同的 HTTP 代理之间取一个公共的交集，因此只能支持最基本的 HTTP 路由，最终导致需要将代理的其他高级功能放入到注解（annotation）中，而注解的方式在多个代理之间是不兼容的，无法移植。

此外，Kubernetes Ingress本身不支持TCP协议。因此，即使TCP不是NGINX的限制，也无法通过Ingress创建来配置NGINX Ingress Controller以进行TCP负载均衡。当然可以通过创建一个Kubernetes ConfigMap，来使用NGINX的TCP负载均衡功能，具体可参阅这里：[Support for TCP/UDP Load Balancing](https://github.com/nginxinc/kubernetes-ingress/tree/master/examples/tcp-udp) 。可想而知，这种配置在多个代理中无法兼容与移植。

与Kubernetes Ingress 不同，Istio Gateway 通过将 L4-L6 配置与L7配置分离的方式克服了 Ingress 的上述缺点。 Gateway 只用于配置 L4-L6 功能（例如，对外公开的端口、TLS 配置），所有主流的代理均以统一的方式实现了这些功能。 然后，通过在 Gateway 上绑定 VirtualService 的方式，可以使用标准的 Istio 规则来控制进入 Gateway 的 HTTP 和 TCP 流量。

本文通过一个示例来讲述如何通过一个简单且标准的Istio规则来控制TCP入口流量的路由，从而实现TCP入口流量路由的统一管理。

## 准备Kubernetes集群

阿里云容器服务Kubernetes 1.11.2目前已经上线，可以通过容器服务管理控制台非常方便地快速创建 Kubernetes 集群。具体过程可以参考[创建Kubernetes集群](https://help.aliyun.com/document_detail/53752.html)。

确保安装配置kubectl 能够连接上Kubernetes 集群。

## 部署Istio

打开容器服务控制台，在左侧导航栏中选中集群，右侧点击更多，在弹出的菜单中选中 部署Istio。

![图片.png](http://ata2-img.cn-hangzhou.img-pub.aliyun-inc.com/948a1d91344a0ce046076febf9886176.png)

在打开的页面中可以看到Istio默认安装的命名空间、发布名称；
通过勾选来确认是否安装相应的模块，默认是勾选前四项；
第5项是提供基于日志服务的分布式跟踪能力，本示例中不启用。
![图片.png](http://ata2-img.cn-hangzhou.img-pub.aliyun-inc.com/2b58c09f755dd6668ebcb47099a968b8.png)

点击 部署Istio 按钮，几十秒钟之后即可完成部署。

## 自动 Sidecar 注入

Istio就是充分利用了Kubernets Webhook机制实现Envoy Proxy Sidecar的自动注入。执行以下命令可以为命令空间default增加标签istio-injection且值设为enabled。

查看namespace：

![图片.png](http://ata2-img.cn-hangzhou.img-pub.aliyun-inc.com/eae95ff97884893bc1daf4e6326e0855.png)

点击编辑，为 default 命名空间打上标签 `istio-injection=enabled`。

![图片.png](http://ata2-img.cn-hangzhou.img-pub.aliyun-inc.com/c69588b05167690a29d93ee66f509c89.png)

## TCP Server镜像

你可以直接使用已经构建好的镜像文件：
`yansongwei/tcpport:v1`。

或者按照以下步骤自行构建。

从以下地址克隆代码库：

```
https://github.com/yansongwel/Istio-TCPRoute-Sample-master
```

切换到代码目录可以看到一个Dockerfile：
![图片.png](http://ata2-img.cn-hangzhou.img-pub.aliyun-inc.com/3fc67222239e3bf86a0829eed28acf64.png)

运行以下命令构建镜像，例如：

```
[root@k8s-svr-node4 Istio-TCPRoute-Sample]# docker build -t yansongwei/tcpport:v1 .
Sending build context to Docker daemon  195.6kB
Step 1/10 : FROM mpfmedical/golang-glide AS builder
 ---> b01261301bee
Step 2/10 : RUN mkdir -p /go/src/github.com/osswangxining/go-echo
 ---> Using cache
 ---> ff29b01ce079
Step 3/10 : COPY . /go/src/github.com/osswangxining/go-echo
 ---> Using cache
 ---> 73923210b7b4
Step 4/10 : RUN go get ...
 ---> Using cache
 ---> 17d9ca095126
Step 5/10 : RUN CGO_ENABLED=0 go build -a -installsuffix cgo -o /go/bin/tcp-echo ./src/github.com/osswangxining/go-echo
 ---> Using cache
 ---> 93ed4207335d
Step 6/10 : FROM alpine:latest
 ---> 14119a10abf4
Step 7/10 : RUN apk --no-cache add ca-certificates
 ---> Using cache
 ---> 2b2936efe832
Step 8/10 : COPY --from=builder /go/bin/tcp-echo /tcp-echo
 ---> Using cache
 ---> 3d953bf64f2d
Step 9/10 : WORKDIR /
 ---> Using cache
 ---> 04f90b5f5980
Step 10/10 : ENTRYPOINT ["/tcp-echo"]
 ---> Using cache
 ---> 272d3d614a03
Successfully built 272d3d614a03
Successfully tagged yansongwei/tcpport:v1
[root@k8s-svr-node4 Istio-TCPRoute-Sample]# docker push yansongwei/tcpport:v1
The push refers to repository [docker.io/yansongwei/tcpport]
f107fac6260d: Preparing 
3e07c925ff68: Preparing 
e2eb06d8af82: Preparing 
denied: requested access to the resource is denied
[root@k8s-svr-node4 Istio-TCPRoute-Sample]# cat Dockerfile 
FROM mpfmedical/golang-glide AS builder

RUN mkdir -p /go/src/github.com/osswangxining/go-echo
COPY . /go/src/github.com/osswangxining/go-echo

RUN go get ...
RUN CGO_ENABLED=0 go build -a -installsuffix cgo -o /go/bin/tcp-echo ./src/github.com/osswangxining/go-echo

FROM alpine:latest
RUN apk --no-cache add ca-certificates

COPY --from=builder /go/bin/tcp-echo /tcp-echo

WORKDIR /

ENTRYPOINT ["/tcp-echo"]

docker build -t yansongwei/tcpport:v1 .
```

之后推送到你自己的镜像仓库地址。

## 部署应用

- 使用 kubectl 部署服务

```
cd k8s
kubectl apply -f deployment.yml
kubectl apply -f service.yml
```

上面的命令会创建1个Service(`tcp-echo`)与2个Deployment(`tcp-echo-v1`与`tcp-echo-v2`)，其中这2个Deployment都包含了标签`app: tcp-echo`，并且Service(`tcp-echo`)对应到上述2个Deployment：

```
selector:
    app: "tcp-echo"
```

- 确认TCPServer的POD启动：

```
kubectl get pods --selector=app=tcp-echo
NAME                           READY     STATUS    RESTARTS   AGE
tcp-echo-v1-7c775f57c9-frprp   2/2       Running   0          1m
tcp-echo-v2-6bcfd7dcf4-2sqhf   2/2       Running   0          1m
```

- 确认TCPServer的服务：

```
kubectl get service --selector=app=tcp-echo
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
tcp-echo   ClusterIP   172.19.46.255   <none>        3333/TCP   17h
```

## 定义 gateway

使用如下命令创建2个Gateway，其中一个Gateway监听31400端口，另一个Gateway监听31401端口。

```
kubectl apply -f gateway.yaml
```

gateway.yaml代码如下：

```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: tcp-echo-gateway
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 31400
      name: tcp
      protocol: TCP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: tcp-echo-gateway-v2
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 31401
      name: tcp
      protocol: TCP
    hosts:
    - "*"
```

如下所示，这2个Gateway共用了一个ingressgateway服务，该ingressgateway使用了Loadbalancer方式暴露，可提供对外使用的IP地址。
![图片.png](http://ata2-img.cn-hangzhou.img-pub.aliyun-inc.com/dedbc53e079a009cf84435443761e604.png)

## 创建Istio规则

```
kubectl apply -f destination-rule-all.yaml
kubectl apply -f virtualservice.yaml
```

该示例规则中定义了2个subset（或者称之为版本）,第一个Gateway会把请求到端口31400的TCP流量进行转发到版本v1的POD，第二个Gateway会把请求到端口31401的TCP流量进行转发到版本v2的POD。

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: tcp-echo
spec:
  hosts:
  - "*"
  gateways:
  - tcp-echo-gateway
  - tcp-echo-gateway-v2
  tcp:
  - match:
    - port: 31400
      gateways:
        - tcp-echo-gateway
    route:
    - destination:
        host: tcp-echo.default.svc.cluster.local
        subset: v1
        port:
          number: 3333
  - match:
    - port: 31401
      gateways:
        - tcp-echo-gateway-v2
    route:
    - destination:
        host: tcp-echo.default.svc.cluster.local
        subset: v2
        port:
          number: 3333        
```

## 体验TCP路由功能

- 查看Ingress Gateway的地址
  点击左侧导航栏中的服务，在右侧上方选择对应的集群和命名空间，在列表中找到istio-ingressgateway的外部端点地址。
- 打开终端，运行以下命令（前提是安装了nc）：

```
nc INGRESSGATEWAY_IP 31400
```

- 输入文字进行如下交互，可以看到该端口的TCP流量转发到了版本v1对应的POD：

```
Welcome, you are connected to node cn-beijing.i-2zeij4aznsu1dvd4mj5c.
Running on Pod tcp-echo-v1-7c775f57c9-frprp.
In namespace default.
With IP address 172.16.2.90.
Service default.
hello, app1
hello, app1
continue..
continue..
```

- 查看版本v1的POD的日志:

```
kubectl logs -f tcp-echo-v1-7c775f57c9-frprp -c tcp-echo-container | grep Received
2018/10/17 07:32:29 6c7f4971-40f1-4f72-54c4-e1462a846189 - Received Raw Data: [104 101 108 108 111 44 32 97 112 112 49 10]
2018/10/17 07:32:29 6c7f4971-40f1-4f72-54c4-e1462a846189 - Received Data (converted to string): hello, app1
2018/10/17 07:34:40 6c7f4971-40f1-4f72-54c4-e1462a846189 - Received Raw Data: [99 111 110 116 105 110 117 101 46 46 10]
2018/10/17 07:34:40 6c7f4971-40f1-4f72-54c4-e1462a846189 - Received Data (converted to string): continue..
```

- 打开另外一个终端，运行以下命令：

```
nc INGRESSGATEWAY_IP 31401
```

- 输入文字进行如下交互，可以看到该端口的TCP流量转发到了版本v2对应的POD：

```
Welcome, you are connected to node cn-beijing.i-2zeij4aznsu1dvd4mj5b.
Running on Pod tcp-echo-v2-6bcfd7dcf4-2sqhf.
In namespace default.
With IP address 172.16.1.95.
Service default.
hello, app2
hello, app2
yes,this is app2
yes,this is app2
```

- 查看版本v2的POD的日志:

```
kubectl logs -f tcp-echo-v2-6bcfd7dcf4-2sqhf -c tcp-echo-container | grep Received
2018/10/17 07:36:29 1a70b9d4-bbc7-471d-4686-89b9234c8f87 - Received Raw Data: [104 101 108 108 111 44 32 97 112 112 50 10]
2018/10/17 07:36:29 1a70b9d4-bbc7-471d-4686-89b9234c8f87 - Received Data (converted to string): hello, app2
2018/10/17 07:36:37 1a70b9d4-bbc7-471d-4686-89b9234c8f87 - Received Raw Data: [121 101 115 44 116 104 105 115 32 105 115 32 97 112 112 50 10]
2018/10/17 07:36:37 1a70b9d4-bbc7-471d-4686-89b9234c8f87 - Received Data (converted to string): yes,this is app2
```

## 总结

本文通过一个示例来讲述如何通过一个简单且标准的Istio规则来控制TCP入口流量的路由，从而实现TCP入口流量路由的统一管理。



## Build the Docker image

Clone this repo and switch to this directory, and then run from a terminal:

>> Note: you should replace the tag with your own tag.

```bash
docker build -t yansongwei/tcpport:v1 .
```

And push this image:
```bash
docker push yansongwei/tcpport:v1
```

## Test with [Docker] before deploying to Kubernetes and Istio

Run the container from a terminal:
```bash
docker run --rm -it -e TCP_PORT=3333 -e NODE_NAME="EchoNode" -p 3333:3333 yansongwei/tcpport:v1
```

In another terminal run:
```bash
nc localhost 3333
Welcome, you are connected to node EchoNode.
hello
hello
```

## Test with [Kubernetes and Istio]

Create the deployment:
```bash
cd k8s
kubectl apply -f deployment.yml
```

Create the service:
```
kubectl apply -f service.yml
```

You should now have two TCP echo containers running:

```bash
kubectl get pods --selector=app=tcp-echo
```

```bash
NAME                           READY     STATUS    RESTARTS   AGE
tcp-echo-v1-7c775f57c9-frprp   2/2       Running   0          1m
tcp-echo-v2-6bcfd7dcf4-2sqhf   2/2       Running   0          1m
```

You should also have a service:

```bash
kubectl get service --selector=app=tcp-echo
```

```bash
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
tcp-echo   ClusterIP   172.19.46.255   <none>        3333/TCP   17h

```

Create the destination rule for this service:
```bash
kubectl apply -f destination-rule-all.yaml
```

Create the gateway and virtual service:
```bash
kubectl apply -f gateway.yaml
```

Echo some data, replace INGRESSGATEWAY_IP with the external IP of Istio Ingress Gateway:
```
nc INGRESSGATEWAY_IP 31400
```

After connecting, type the word hello and hit return:
```bash
Welcome, you are connected to node cn-beijing.i-2zeij4aznsu1dvd4mj5c.
Running on Pod tcp-echo-v1-7c775f57c9-frprp.
In namespace default.
With IP address 172.16.2.90.
Service default.
hello, app1
hello, app1
continue..
continue..
```

Verify the logs from version 1 POD:
```bash
kubectl logs -f tcp-echo-v1-7c775f57c9-frprp -c tcp-echo-container | grep Received
2018/10/17 07:32:29 6c7f4971-40f1-4f72-54c4-e1462a846189 - Received Raw Data: [104 101 108 108 111 44 32 97 112 112 49 10]
2018/10/17 07:32:29 6c7f4971-40f1-4f72-54c4-e1462a846189 - Received Data (converted to string): hello, app1
2018/10/17 07:34:40 6c7f4971-40f1-4f72-54c4-e1462a846189 - Received Raw Data: [99 111 110 116 105 110 117 101 46 46 10]
2018/10/17 07:34:40 6c7f4971-40f1-4f72-54c4-e1462a846189 - Received Data (converted to string): continue..
```

Switch to another port 31401, replace INGRESSGATEWAY_IP with the external IP of Istio Ingress Gateway:
```
nc INGRESSGATEWAY_IP 31401
```

After connecting, type the word hello and hit return:
```bash
Welcome, you are connected to node cn-beijing.i-2zeij4aznsu1dvd4mj5b.
Running on Pod tcp-echo-v2-6bcfd7dcf4-2sqhf.
In namespace default.
With IP address 172.16.1.95.
Service default.
hello, app2
hello, app2
yes,this is app2
yes,this is app2
```

```bash
kubectl logs -f tcp-echo-v2-6bcfd7dcf4-2sqhf -c tcp-echo-container | grep Received
2018/10/17 07:36:29 1a70b9d4-bbc7-471d-4686-89b9234c8f87 - Received Raw Data: [104 101 108 108 111 44 32 97 112 112 50 10]
2018/10/17 07:36:29 1a70b9d4-bbc7-471d-4686-89b9234c8f87 - Received Data (converted to string): hello, app2
2018/10/17 07:36:37 1a70b9d4-bbc7-471d-4686-89b9234c8f87 - Received Raw Data: [121 101 115 44 116 104 105 115 32 105 115 32 97 112 112 50 10]
2018/10/17 07:36:37 1a70b9d4-bbc7-471d-4686-89b9234c8f87 - Received Data (converted to string): yes,this is app2
```

## Resources
- [Expose Pod Information to Containers Through Environment Variables]
- [Docker]
- [Kubernetes]
- [Istio]


[Expose Pod Information to Containers Through Environment Variables]: https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/
[Docker]: https://www.docker.com/
[Kubernetes]: https://kubernetes.io/
[Istio]: https://istio.io/