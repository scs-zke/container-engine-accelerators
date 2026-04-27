# NVIDIA Device Plugin

This is a clone of the [GKE Hardware Accelerators](https://github.com/GoogleCloudPlatform/container-engine-accelerators) NVIDIA device plugin.

It is cloned to allow a reproducable build independ of the GKE releases.

## Usage

### Node preparation
Each node must have a file ```/etc/nvidia/gpu.json``` deployed with a content like:

```JSON
{
    "GPUPartitionSize": "",
    "GPUSharingConfig": {
        "GPUSharingStrategy": ""
    }
}
```

The node must have the NVIDIA drivers installed, for example in ```/home/kubernetes/bin/nvidia```. The firmware must be extraced and installed for example in ```/usr/lib/firmware```. Firmware extraction is usually performed by the driver installer.

### Kubernetes Deployment

The plugin can be deployed in Kubernetes using a Daemonset. The example below creates device plugin instances on all nodes having the label ```my.node.label.for.gpus``` set.

#### Namespace

```YAML
apiVersion: v1
kind: Namespace
metadata:
  name: kube-nvidia
```

#### Health monitoring config map

The health monitoring is configured through the XID_CONFIG environment variable. It content can be set in a config map.

The error codes are specified int he [Xid Errors](https://docs.nvidia.com/deploy/xid-errors/) documentation. A more detailed description can ei found in the [Modal Documentation](https://modal.com/docs/guide/gpu-health).

```YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: nvidia-xid-config
  namespace: kube-nvidia
data:
  HealthCriticalXid: "48, 74, 79"
```

#### RBAC

```YAML
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: gpu-device-plugin
  name: gpu-device-plugin
  namespace: kube-nvidia
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gpu-device-plugin
  labels:
    k8s-app: gpu-device-plugin
    addonmanager.kubernetes.io/mode: Reconcile
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["update", "patch", "get", "list", "watch"]
  - apiGroups: [""]
    resources: ["nodes/status"]
    verbs: ["update", "patch", "get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gpu-device-plugin
  namespace: kube-nvidia
  labels:
    k8s-app: gpu-device-plugin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gpu-device-plugin
subjects:
  - kind: ServiceAccount
    name: gpu-device-plugin
    namespace: kube-nvidia
```

#### DaemonSet

```YAML
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-gpu-device-plugin
  namespace: kube-nvidia
  labels:
    k8s-app: nvidia-gpu-device-plugin
    addonmanager.kubernetes.io/mode: EnsureExists
spec:
  selector:
    matchLabels:
      k8s-app: nvidia-gpu-device-plugin
  template:
    metadata:
      labels:
        k8s-app: nvidia-gpu-device-plugin
    spec:
      priorityClassName: system-node-critical
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: my.node.label.for.gpus
                    operator: Exists
      containers:
        - image: ghcr.io/scs-zke/container-engine-accelerators:master
          command:
            - /usr/bin/nvidia-gpu-device-plugin
            - -logtostderr
            - --enable-container-gpu-metrics
            - --enable-health-monitoring
            - --publish-driver-version
          name: nvidia-gpu-device-plugin
          ports:
            - name: metrics
              containerPort: 2112
          env:
            - name: XID_CONFIG
              valueFrom:
                configMapKeyRef:
                  key: HealthCriticalXid
                  name: nvidia-xid-config
                  optional: true
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: LD_LIBRARY_PATH
              value: /usr/local/nvidia/lib64
            - name: GOMAXPROCS
              value: "1"
          resources:
            requests:
              cpu: 50m
              memory: 100Mi
            limits:
              cpu: 50m
              memory: 100Mi
          securityContext:
            privileged: true
          volumeMounts:
            - name: device-plugin
              mountPath: /device-plugin
            - name: dev
              mountPath: /dev
            - name: nvidia
              mountPath: /usr/local/nvidia
            - name: firmware
              mountPath: /usr/lib/firmware
            - name: pod-resources
              mountPath: /var/lib/kubelet/pod-resources
            - name: proc
              mountPath: /proc
            - name: nvidia-config
              mountPath: /etc/nvidia
      restartPolicy: Always
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      tolerations:
        - operator: "Exists"
          effect: "NoExecute"
        - operator: "Exists"
          effect: "NoSchedule"
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
            type: Directory
        - name: dev
          hostPath:
            path: /dev
            type: Directory
        - name: pod-resources
          hostPath:
            path: /var/lib/kubelet/pod-resources
            type: Directory
        - name: proc
          hostPath:
            path: /proc
            type: Directory
        - name: nvidia-config
          hostPath:
            path: /etc/nvidia
            type: DirectoryOrCreate
        - name: nvidia
          hostPath:
            path: /home/kubernetes/bin/nvidia
            type: Directory
        - name: firmware
          hostPath:
            path: /usr/lib/firmware
            type: Directory
      serviceAccountName: gpu-device-plugin
  updateStrategy:
    type: RollingUpdate
```
