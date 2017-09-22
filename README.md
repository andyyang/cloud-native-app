# cloud-native-app

A simple cloud native app for Cloud Native Victoria Meetup

## Tutorial

This tutorial demostrates deploying a cloud native application that runs on Kubernetes along side Prometheus,
Fluentd and Istio to provide a complete platform to run your microservices on.

## Prerequisites

Configure google cloud region and zone

```bash
gcloud config set compute/region us-west1
```

```bash
gcloud config set compute/zone us-west1-b
```

## Provision the Infrastructure for Kubernetes

### Provision a Kubernetes Cluster

Create Kubernetes Cluster

```bash
gcloud container clusters create cloud-native-app \
  --machine-type n1-standard-1 \
  --num-nodes 3 \
  --cluster-version 1.7.5
```

Wait for the kubernetes cluster to come up

*it might take couple of minutes*

```bash
gcloud container clusters list
```

```bash
NAME              ZONE        MASTER_VERSION  MASTER_IP      MACHINE_TYPE   NODE_VERSION  NUM_NODES  STATUS
cloud-native-app  us-west1-b  1.7.5           35.197.117.21  n1-standard-1  1.7.5         3          RUNNING
```

Configure kubectl to point to the kubernetes cluster

```bash
gcloud container clusters get-credentials cloud-native-app --zone us-west1-b --project {PROJECT_NAME}
```

## Provision Istio

Follow the [guide](https://istio.io/docs/setup/install-kubernetes.html) on Istio's website to install Istio on Kubernetes. Just make sure you get to the [Verify the installation](https://istio.io/docs/setup/install-kubernetes.html#verifying-the-installation) step.

Now you have istio and the addons like Prometheus, Grafana and ServiceGraph installed!

## Test Cloud Native App

```bash
go run main.go
```

```bash
2017/09/20 15:43:29 starting web server on port :8080
```

In a new terminal test the application

```bash
curl localhost:8080
```

```bash
You've hit the home page of the cloud native app with hostname "hostname.local" on node "".
```

Cool! Our app works!

Lets build a docker container

```bash
GOOS=linux GOARCH=amd64 go build -v .
```

```bash
docker build -t anubhavmishra/cloud-native-app:v0.1.0 .
```

```bash
docker tag anubhavmishra/cloud-native-app:v0.1.0 anubhavmishra/cloud-native-app:latest
```

Now lets test the docker image

```bash
docker run -it -p 8080:8080 anubhavmishra/cloud-native-app
```

In a new terminal curl the application

```bash
curl localhost:8080
```

```bash
You've hit the home page of the cloud native app with hostname "docker-hostname" on node "".
```

Push the docker image to docker registry (docker hub)

```bash
docker push anubhavmishra/cloud-native-app:v0.1.0
docker push anubhavmishra/cloud-native-app:latest
```

Awesome! Now we have a docker image of our app. Lets deploy it to kubernetes

```bash
kubectl apply -f kubernetes/cloud-native-app-deployment.yaml
```

Check if it is running

```bash
kubectl get pods | grep cloud-native-app
```

```bash
cloud-native-app-913471705-4j2zx   1/1       Running   0          15s
```

Test the app

```bash
kubectl port-forward cloud-native-app-913471705-4j2zx 8080:8080
```

In a new terminal curl the application

```bash
curl localhost:8080
```

```bash
You've hit the home page of the cloud native app with hostname "cloud-native-app-913471705-4j2zx" on node "node-name".
```

Lets expose this application to the world

```bash
kubectl apply -f kubernetes/cloud-native-app-service.yaml
```

Check if the service is up

```bash
kubectl get service cloud-native-app
```

> Give it a minute for the `EXTERNAL-IP` to show up

```bash
NAME               CLUSTER-IP    EXTERNAL-IP     PORT(S)        AGE
cloud-native-app   10.7.253.76   35.203.186.75   80:31567/TCP   2m
```

In a new terminal curl the `EXTERNAL-IP`

```bash
curl 35.203.186.75:8080
```

```bash
You've hit the home page of the cloud native app with hostname "cloud-native-app-913471705-4j2zx" on node "node-name".
```

Scale the application

```bash
kubectl scale deployment cloud-native-app --replicas=3
```

Check if the application is scaled

```bash
kubectl get pods | grep cloud-native-app
```

```bash
cloud-native-app-913471705-4j2zx   1/1       Running   0          16m
cloud-native-app-913471705-djpnz   1/1       Running   0          58s
cloud-native-app-913471705-v247t   1/1       Running   0          58s
```

Get some logs

```bash
kubectl logs -f {POD_NAME}
```

* Look at fluentd and GCP

## Deploy Cloud Native Microservices

First we delete currently running `cloud-native-app` service since it exposed as `LoadBalancer` type

```bash
kubectl delete -f cloud-native-app-service.yaml
```

Let's explore the our microservices

```bash
vim kubernetes/cloud-native-microservices-v1.yaml
```

```bash
kubectl apply -f <(istioctl kube-inject -f kubernetes/cloud-native-microservices-v1.yaml --namespace=istio-system)
```

```bash
kubectl apply -f <(istioctl kube-inject -f kubernetes/cloud-native-app-ingress.yaml --namespace=istio-system)
```

Now lets find our ingress

```bash
kubectl get ingress cloud-native-app-gateway
``` 

```bash
kubectl describe ingress cloud-native-app-gateway
```

curl the ip or domain

```bash
curl -H 'Host: cloud-native-app.livedemos.xyz' 104.196.249.219
```

```bash
curl cloud-native-app.livedemos.xyz
```

Lets loop it!

```bash
while true; do curl -H 'Host: cloud-native-app.livedemos.xyz' 104.196.249.219; echo ""; sleep 0.5;done
```

### Traffic Shaping

Deploy v2 of the applications

```bash
kubectl apply -f <(istioctl kube-inject -f kubernetes/cloud-native-microservices-v2.yaml --namespace=istio-system)
```

```bash
istioctl create -f rules/foo.yaml --namespace=istio-system
```

```bash
istioctl create -f rules/bar.yaml --namespace=istio-system
```

```bash
istioctl get route-rules --namespace istio-system
```

```bash
foo-istio-system
bar-istio-system
```

Lets now try to shape some traffic for `foo` application

```bash
vim rules/foo.yaml
```

```bash
istioctl replace -f rules/foo.yaml
```

I want to canary a mobile device

```bash
istioctl create -f rules/foo-mobile.yaml --namespace=istio-system
```

```bash
istioctl delete route-rule foo-canary --namespace istio-system
```


Deny

```bash
istioctl mixer rule create global foo.istio-system.svc.cluster.local -f rules/foo-deny.yaml --namespace istio-system
```

```bash
istioctl mixer rule delete global foo.istio-system.svc.cluster.local --namespace istio-system
```






