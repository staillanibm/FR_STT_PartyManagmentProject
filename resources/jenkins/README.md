# Jenkins CI/CD Pipeline

## Configuration

Set these environment variables before use:

```bash
export OCP_NAMESPACE="zone-france"
export IMAGE_STREAM_NAME="cdf-party-management"
export DEPLOYMENT_NAME="cdf-party-management"
export WHI_CR_SERVER="iwhicr.azurecr.io"
export OCP_REGISTRY="default-route-openshift-image-registry.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com"
```

## Overview

- **CI (Jenkinsfile)**: Build Docker image → push to ImageStream → Git tag
- **CD (Jenkinsfile.cd)**: Deploy to OCP → health checks → automatic rollback on failure
- **Agents**: Pod-based agents deployed per namespace (zone-france, zone-latam)

See **ARCHITECTURE.md** for detailed flow diagrams and **agent/DEPLOYMENT.md** for agent setup.

---

## Setup (OneTime)

### 0. Deploy Jenkins Agents

**Prerequisites**: Jenkins Controller accessible at `https://jenkins-jenkins.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com`

**Zone France** - Already configured with token:
```bash
kubectl apply -k resources/jenkins/agent/overlays/zone-france/
```

**Zone Latam** - Update token first:
```bash
# Get token from Jenkins UI → Manage Nodes → zone-latam → Configure
# Copy the secret value from curl command
sed -i 's/CHANGE_ME_WITH_ZONE_LATAM_TOKEN/<token>/' resources/jenkins/agent/overlays/zone-latam/secrets.yaml
kubectl apply -k resources/jenkins/agent/overlays/zone-latam/
```

See **agent/DEPLOYMENT.md** for detailed instructions.

### 1. Create ServiceAccount + Token for Each Namespace

**Must be done for EACH namespace** (zone-france AND zone-latam):

```bash
# Define variables
NAMESPACE="zone-france"  # Change to "zone-latam" for second namespace
SERVICE_ACCOUNT="${DEPLOYMENT_NAME}-jenkins"
ROLE_NAME="${DEPLOYMENT_NAME}-push"
SECRET_NAME="${DEPLOYMENT_NAME}-jenkins-token"

# Create ServiceAccount
kubectl create serviceaccount ${SERVICE_ACCOUNT} -n ${NAMESPACE}

# Create role for ImageStream operations
kubectl create role ${ROLE_NAME} \
  --verb=get,list,create,update,patch \
  --resource=imagestreams,imagestreamimages \
  -n ${NAMESPACE}

# Bind role to ServiceAccount
kubectl create rolebinding ${ROLE_NAME} \
  --role=${ROLE_NAME} \
  --serviceaccount=${NAMESPACE}:${SERVICE_ACCOUNT} \
  -n ${NAMESPACE}

# Create 3-month token (2160 hours)
kubectl create secret generic ${SECRET_NAME} \
  --from-literal=token=$(kubectl create token ${SERVICE_ACCOUNT} \
    --duration=2160h -n ${NAMESPACE}) \
  -n ${NAMESPACE}

# Extract token for Jenkins
kubectl get secret ${SECRET_NAME} \
  -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d
```

**Repeat this for zone-latam with `NAMESPACE="zone-latam"`**

### 2. Create ACR Pull Secret for Base Image Access

**For each namespace** (zone-france, zone-latam), create a Docker registry secret for pulling the base image from Azure Container Registry:

```bash
# Define variables
NAMESPACE="zone-france"  # Change to "zone-latam" for second namespace
SECRET_NAME="acr-pull-secret"

# Create the Docker registry secret using your ACR credentials
# Replace with your actual ACR registry, username, and password
kubectl create secret docker-registry ${SECRET_NAME} \
  --docker-server=iwhicr.azurecr.io \
  --docker-username=<YOUR_ACR_USERNAME> \
  --docker-password=<YOUR_ACR_PASSWORD> \
  --docker-email=your-email@example.com \
  -n ${NAMESPACE}

# Verify the secret was created
kubectl get secret ${SECRET_NAME} -n ${NAMESPACE}
```

**Repeat this for zone-latam with `NAMESPACE="zone-latam"`**

**Note**: The ACR credentials are stored in Kubernetes secrets within each namespace. The OCP build system will use this secret to authenticate pulling the base image.

### 3. Add Tokens to Jenkins (One Per Namespace)

Jenkins UI → **Manage Credentials** → **System** → **Global credentials**:

**Credential 1: zone-france token**
- **ID**: `imagestream-push-token-zone-france`
- **Type**: Secret text
- **Secret**: (token from step 1 for zone-france)

**Credential 2: zone-latam token**
- **ID**: `imagestream-push-token-zone-latam`
- **Type**: Secret text
- **Secret**: (token from step 1 for zone-latam)

### 4. Create Jenkins Jobs

**Job 1: CI Pipeline**
- Definition: Pipeline script from SCM
- Repository: `https://github.com/staillanibm/FR_STT_PartyManagmentProject`
- Script path: `resources/jenkins/Jenkinsfile`

**Job 2: CD Pipeline**
- Definition: Pipeline script from SCM
- Repository: `https://github.com/staillanibm/FR_STT_PartyManagmentProject`
- Script path: `resources/jenkins/Jenkinsfile.cd`

**Job Parameters** (in each job configuration):

CI job:
- `VERSION_BASE` (default: `1.0`)
- `OCP_REGISTRY` (default: from env above)
- `OCP_NAMESPACE` (default: from env above)
- `IMAGE_STREAM_NAME` (default: from env above)

CD job:
- `IMAGE_STREAM_TAG` (e.g., `1.0.01`)
- `OCP_NAMESPACE` (default: from env above)
- `DEPLOYMENT_NAME` (default: from env above)
- `HEALTH_CHECK_URL` (default: `http://localhost:5555/health`)

---

## Token Renewal (Before 3-Month Expiry)

```bash
NAMESPACE="${OCP_NAMESPACE}"
SERVICE_ACCOUNT="${DEPLOYMENT_NAME}-jenkins"
SECRET_NAME="${DEPLOYMENT_NAME}-jenkins-token"

# Delete old secret
kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE}

# Create new 3-month token
kubectl create secret generic ${SECRET_NAME} \
  --from-literal=token=$(kubectl create token ${SERVICE_ACCOUNT} \
    --duration=2160h -n ${NAMESPACE}) \
  -n ${NAMESPACE}

# Extract and update Jenkins credential
kubectl get secret ${SECRET_NAME} \
  -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d
```

---

## Troubleshooting

### Verify ImageStream exists
```bash
kubectl get is ${IMAGE_STREAM_NAME} -n ${OCP_NAMESPACE}
```

### Check ServiceAccount permissions
```bash
SERVICE_ACCOUNT="${DEPLOYMENT_NAME}-jenkins"
kubectl auth can-i update imagestreams \
  --as=system:serviceaccount:${OCP_NAMESPACE}:${SERVICE_ACCOUNT} \
  -n ${OCP_NAMESPACE}
```

### Manual rollback
```bash
kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n ${OCP_NAMESPACE}
```

### View deployment image
```bash
kubectl get deployment ${DEPLOYMENT_NAME} -n ${OCP_NAMESPACE} \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Files

- **Jenkinsfile** - CI pipeline (build, tag, push to ImageStream)
- **Jenkinsfile.cd** - CD pipeline (deploy, health check, rollback)
- **pipeline-config.groovy** - Reusable Groovy functions
- **ARCHITECTURE.md** - Detailed flow diagrams and design decisions
- **agent/** - Jenkins agent deployment manifests
  - **base/** - Generic agent manifests (kustomize base)
  - **overlays/zone-france/** - France region agent config
  - **overlays/zone-latam/** - Latam region agent config
  - **DEPLOYMENT.md** - Agent setup and troubleshooting
- **README.md** - This file
