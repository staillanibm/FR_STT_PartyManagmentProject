# CI/CD Pipeline Architecture

## Overall Flow

```
Developer Commit to main/develop
         ↓
    CI Pipeline (Jenkinsfile)
    ├─ Build Docker image (with ACR base image)
    ├─ Push to OCP ImageStream
    └─ Create Git tag (v1.0.01, v1.0.02, etc.)
         ↓
  Image available in OCP ImageStream
         ↓
  Manual approval (or automated trigger)
         ↓
    CD Pipeline (Jenkinsfile.cd)
    ├─ Pull image from ImageStream
    ├─ Deploy to OCP
    ├─ Health check (http://localhost:5555/health)
    └─ Automatic rollback if health check fails
         ↓
  Service Running or Rolled Back
```

## Component Interaction

```
┌────────────────┐
│   Git Repo     │ (Source code + Dockerfile_test)
└────────┬───────┘
         │
         ├──────────────────────────┐
         │                          │
         ▼                          ▼
    ┌─────────────────┐    ┌──────────────┐
    │  CI Pipeline    │    │  ACR (pull)  │
    │   (Jenkinsfile) │───▶│ (base image) │
    └────────┬────────┘    └──────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │ OCP ImageStream Registry │ (image-registry.openshift-image-registry.svc:5000)
    └────────┬─────────────────┘
             │
             │ (image reference)
             ▼
    ┌──────────────────────────┐
    │  CD Pipeline             │
    │  (Jenkinsfile.cd)        │
    └────────┬─────────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │  OCP Deployment          │
    │  (kubectl set image)     │
    └────────┬─────────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │  Health Check            │
    │  (localhost:5555/health) │
    └────────┬─────────────────┘
             │
        ┌────┴─────┐
        ▼          ▼
    Success    Failure
        │          │
        │          └─→ Automatic Rollback
        │              (kubectl rollout undo)
        │
        ▼
  Service Running
```

## Versioning Scheme

```
Build #1  Build #2  Build #3  ...  Build #99
   │         │         │               │
   v         v         v               v
1.0.01    1.0.02    1.0.03  ...   1.0.99
   │         │         │               │
   └─►Git tag───────────┬───────────────┘
                        │
                    ImageStream
                    (OCP Registry)
```

## CI Pipeline Detail

**Input**: Source code (main/develop branch)
**Output**: Image in OCP ImageStream + Git tag

```
Stage 1: Environment Setup
  └─ Display parameters

Stage 2: SCM Checkout
  └─ Clone git repository

Stage 3: Version Tag
  └─ Create Git tag: v${BASE_VERSION}.${BUILD_NUMBER}

Stage 4: Pre-Build Validation
  └─ Verify Dockerfile exists
  └─ Verify Docker daemon accessible

Stage 5: Build Docker Image
  └─ docker build with args:
     - VERSION=1.0.01
     - WPM_TOKEN (masked)
     - GIT_TOKEN (masked)

Stage 6: Image Validation
  └─ docker inspect (metadata check)

Stage 7: Push to OCP ImageStream
  └─ Verify ImageStream exists
  └─ Tag image: image-registry.../namespace/stream:1.0.01
  └─ Push to OCP internal registry

Stage 8: CI Summary
  └─ Report success
```

## CD Pipeline Detail

**Input**: ImageStream tag (e.g., fr-stt-party-management:1.0.01)
**Output**: Running service in OCP or automatic rollback

```
Stage 1: Environment Setup
  └─ Display parameters

Stage 2: Pre-Deployment Validation
  └─ Verify kubeconfig
  └─ Verify cluster access
  └─ Verify namespace exists
  └─ Verify deployment exists

Stage 3: Save Current Deployment State
  └─ Capture current image (for rollback)
  └─ Save deployment spec

Stage 4: Deploy to OCP
  └─ kubectl set image with ImageStream reference
  └─ Record deployment change

Stage 5: Wait for Rollout
  └─ Monitor pod startup
  └─ Timeout: 10 minutes

Stage 6: Health Check
  └─ Call /health endpoint
  └─ Retry: 30 attempts, 10-second intervals
  └─ Total timeout: 300 seconds
  └─ On failure: Trigger automatic rollback

Stage 7: Post-Deployment Verification
  └─ Check pod status
  └─ Check restart count
  └─ Verify image deployed

Stage 8: CD Summary
  └─ Report success
```

## Automatic Rollback Flow

```
Deployment Triggered
     │
     ▼
  Rollout Complete
     │
     ▼
Health Check Called
     │
  ┌──┴──┐
  ▼     ▼
 200  Other
  │    │
  ✓    └─→ Retry (max 30x)
           │
           ├─→ Success: Continue
           └─→ Failure: ROLLBACK
               │
               ├─ kubectl rollout undo
               ├─ Verify previous version
               └─ Alert

Result: Previous version restored automatically
```

## Image Reference Flow

```
Local Build:
  docker build -t fr-stt-party-management:1.0.01

Tag for OCP:
  docker tag fr-stt-party-management:1.0.01 \
    image-registry.openshift-image-registry.svc:5000/\
    fr-stt-party-management/\
    fr-stt-party-management:1.0.01

Push to ImageStream:
  docker push image-registry.openshift-image-registry.svc:5000/...

Deploy from ImageStream:
  kubectl set image deployment/app app=image-registry.../1.0.01

Result: Pod pulls image from OCP ImageStream
```

## Credential Flow

```
Jenkins Agent
    │
    ├─ Docker credentials
    │  └─ Login to ACR (for base image pull)
    │
    ├─ ServiceAccount token
    │  └─ Login to OCP registry (for image push)
    │
    ├─ kubeconfig
    │  └─ Access Kubernetes API (for deployment)
    │
    └─ Git credentials
       └─ Push tags to GitHub

OCP Cluster
    │
    ├─ acr-pull-secret
    │  └─ Link to ServiceAccount (for pod image pull)
    │
    ├─ ImageStream
    │  └─ Stores all image versions
    │
    └─ RBAC
       └─ Controls Jenkins push/pull permissions
```

## Network Topology

```
Jenkins Agent
    ↓ (HTTPS)
ACR Registry (pull base image)
    ↓
Docker Build
    ↓
OCP Internal Registry
    ↓ (internal network)
OCP API Server
    ↓
Kubernetes Nodes
    ↓ (internal pull)
Pod (runs application)
    ↓
Health Check (localhost:5555/health)
    ↓
CD Pipeline verifies
```

## Failure Scenarios

### Build Failure
```
CI Build Fails
    ↓
No image pushed
    ↓
No deployment triggered
    ↓
Previous version still running
```

### Deployment Failure (Pods won't start)
```
Rollout fails
    ↓
Manual rollback with:
  kubectl rollout undo deployment/...
```

### Health Check Failure
```
Health check returns != 200
    ↓ (30 retries)
Still failing
    ↓
Automatic rollback triggered
    ↓
Previous version restored
    ↓
Health check verified for previous version
```

## State Preservation

```
Before Deployment:
  ├─ Save current image tag
  ├─ Save deployment spec
  └─ Verify cluster state

During Deployment:
  ├─ Update image
  ├─ Monitor rollout
  └─ Keep previous revision in Kubernetes history

On Failure:
  ├─ Retrieve saved image
  ├─ kubectl rollout undo
  └─ Verify previous version restored
```

## Key Design Decisions

1. **Separated CI/CD**: Independent pipelines with different triggers
2. **ImageStream**: Push to OCP internal registry (no ACR write needed)
3. **Semantic versioning**: Automatic with build numbers (1.0.01, 1.0.02, etc.)
4. **Health checks**: Mandatory verification after deployment
5. **Automatic rollback**: No manual intervention on health check failure
6. **Pre-deployment validation**: Fail fast approach
7. **State preservation**: Previous version always available for rollback

## Deployment Timeline

```
t=0   : Build starts
t=5-20: Docker build (depends on dependencies)
t=21  : Image push to ImageStream
t=22  : CD pipeline triggered
t=23  : Deployment update (kubectl set image)
t=24  : Pods starting
t=24-34: Rollout monitoring
t=35  : Health check starts (30 retries max)
t=35-365: Waiting for health check
t=366 : Rollout complete or Rollback triggered
```

**Total CI time**: 20-30 minutes (depends on docker build)
**Total CD time**: 5-20 minutes (depends on app startup)
