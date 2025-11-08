# Jenkins Agent Deployment

Pod-based Jenkins agents deployed in each application namespace (zone-france, zone-latam).

## Architecture

```
Jenkins Controller (external or dedicated namespace)
    │
    ├─→ Agent zone-france (pod)
    │   └─ Build & push for zone-france
    │
    └─→ Agent zone-latam (pod)
        └─ Build & push for zone-latam
```

Each agent:
- ✅ Runs in its own application namespace
- ✅ Has access to local ImageStream (same namespace)
- ✅ Isolated RBAC (no cross-namespace access)
- ✅ Isolated credentials
- ✅ Forced to English locale (system and Java level)

---

## Prerequisites

1. **Jenkins Controller** accessible via URL (e.g., `http://jenkins.jenkins.svc.cluster.local:8080`)
2. **OCP Cluster** with kubectl/oc configured
3. **Namespaces created**: `zone-france`, `zone-latam`

---

## Deployment Steps

### 1. Configure Jenkins Controller (one-time setup)

#### 1a. Create agent node in Jenkins UI

Jenkins Dashboard:
1. **Manage Jenkins** → **Manage Nodes and Clouds**
2. **New Node**
   - **Node name**: `jenkins-agent-zone-france`
   - **Type**: Permanent Agent
3. **Configure**:
   - **Remote root directory**: `/home/jenkins/agent`
   - **Labels**: `france` (optional)
   - **Launch method**: **Launch via inbound agent**
   - **Executors**: `2` (or as needed)
4. **Save**
5. **Copy the token** displayed (for secrets)

Repeat for `jenkins-agent-zone-latam`:
- **Node name**: `jenkins-agent-zone-latam`
- **Labels**: `latam`

---

### 2. Deploy agent in OCP

#### 2a. Deploy zone-france agent

Token already configured. Deploy:
```bash
kubectl apply -k resources/jenkins/agent/overlays/zone-france/
```

#### 2b. Deploy zone-latam agent

Get token from Jenkins first:
1. Jenkins UI → **Gérer Jenkins** → **Gérer les nœuds et nuages**
2. Click `zone-latam` agent
3. **Configurer**
4. Find the curl command at bottom, extract the `-secret` value

Update secrets.yaml:
```bash
sed -i 's/CHANGE_ME_WITH_ZONE_LATAM_TOKEN/<token-from-curl>/' resources/jenkins/agent/overlays/zone-latam/secrets.yaml
```

Deploy:
```bash
kubectl apply -k resources/jenkins/agent/overlays/zone-latam/
```

---

### 3. Verify deployment

```bash
# Verify pod is running (zone-france)
kubectl get pod -n zone-france -l app=jenkins-agent

# View connection logs
kubectl logs -n zone-france -l app=jenkins-agent -f

# Verify RBAC
kubectl auth can-i get imagestreams \
  --as=system:serviceaccount:zone-france:jenkins-agent \
  -n zone-france
# Should return: yes
```

Same verification for zone-latam:
```bash
kubectl get pod -n zone-latam -l app=jenkins-agent
kubectl logs -n zone-latam -l app=jenkins-agent -f
```

---

### 4. Jenkins will detect agents

After 10-30 seconds:
- Jenkins UI shows agents as **Connected**
- Nodes appear green in **Manage Nodes**

If **Offline**:
- Check logs: `kubectl logs -n zone-france -l app=jenkins-agent`
- Verify Jenkins URL is accessible from pod
- Verify token (typos, expiration, etc.)

---

## Configure Jenkins Jobs

In each job (CI and CD), specify agent label:

```groovy
pipeline {
    agent {
        label 'france'  // For zone-france
        // OR
        // label 'latam'   // For zone-latam
    }
    // ...
}
```

Or in UI: **Job → Configure → Agent → Label expression**: `france`

---

## Troubleshooting

### Agent offline in Jenkins UI

```bash
# Verify pod exists
kubectl get pod -n zone-france -l app=jenkins-agent

# Check error logs
kubectl logs -n zone-france -l app=jenkins-agent

# Restart pod
kubectl delete pod -n zone-france -l app=jenkins-agent
# Kubernetes will create a new one
```

### Can't push to ImageStream

```bash
# Verify RBAC
kubectl auth can-i create imagestreams \
  --as=system:serviceaccount:zone-france:jenkins-agent \
  -n zone-france
# Should return: yes

# Verify service account token in pod
kubectl exec -it -n zone-france deploy/jenkins-agent -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

### Token expired

In Jenkins UI:
1. **Manage Nodes** → Agent node
2. **Configure** → Copy new token
3. Update secret:

```bash
kubectl patch secret jenkins-agent-secret -n zone-france \
  --type='json' -p='[{"op": "replace", "path": "/data/token", "value":"'"$(echo -n "NEW_TOKEN" | base64)"'"}]'

# Restart pod
kubectl delete pod -n zone-france -l app=jenkins-agent
```

---

## Resources Managed

Per overlay (`zone-france`):

1. **ServiceAccount**: `jenkins-agent`
2. **Role**: `jenkins-agent-role` (ImageStream push + deploy)
3. **RoleBinding**: `jenkins-agent-rolebinding`
4. **ConfigMap**: `jenkins-agent-config` (URLs, names)
5. **Secret**: `jenkins-agent-secret` (Jenkins token)
6. **Deployment**: `jenkins-agent` (agent pod)
   - Forces English locale via environment variables:
     - `LANG=en_US.UTF-8`
     - `LC_ALL=en_US.UTF-8`
     - `JAVA_TOOL_OPTIONS=-Duser.language=en -Duser.country=US`

---

## Modify an Agent

To modify agent (CPU, memory, replicas):

```bash
# Edit deployment
kubectl edit deployment jenkins-agent -n zone-france

# Or use kustomize:
# Add patchesJson6902 to overlays/zone-france/kustomization.yaml
```

Example to increase CPU:
```yaml
patchesJson6902:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: jenkins-agent
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/cpu
        value: "4000m"
```

---

## Delete an Agent

```bash
# Delete everything (namespaces remain intact)
kubectl delete -k overlays/zone-france/

# Or specifically:
kubectl delete deployment jenkins-agent -n zone-france
kubectl delete serviceaccount jenkins-agent -n zone-france
kubectl delete role jenkins-agent-role -n zone-france
kubectl delete rolebinding jenkins-agent-rolebinding -n zone-france
```

---

## Files

- **base/** - Generic manifests (reusable)
  - `serviceaccount.yaml` - ServiceAccount + token Secret
  - `rbac.yaml` - Role + RoleBinding
  - `configmap.yaml` - Configuration (URLs)
  - `agent-deployment.yaml` - Pod deployment
  - `kustomization.yaml` - Base kustomize

- **overlays/** - Customizations per namespace
  - `zone-france/kustomization.yaml` - zone-france config
  - `zone-latam/kustomization.yaml` - zone-latam config

- **DEPLOYMENT.md** - This file
