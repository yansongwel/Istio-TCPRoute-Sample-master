# GO (TCP) Echo

A Simple go TCP echo server. Written to learn and test [Kubernetes | Istio] TCP networking.

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