// Jenkins Pipeline Configuration and Utility Functions
// This file contains reusable functions and configurations for the CI/CD pipeline

def getVersionString(baseVersion, buildNumber) {
    """
    Generate version string in format: baseVersion.paddedBuildNumber
    Example: 1.0.05 (with baseVersion=1.0 and buildNumber=5)
    """
    String paddedBuild = String.format("%02d", buildNumber.toInteger())
    return "${baseVersion}.${paddedBuild}"
}

def validateDockerEnvironment() {
    """
    Validate that Docker is properly configured and accessible
    """
    try {
        sh '''
            echo "Validating Docker environment..."
            docker --version
            docker info > /dev/null 2>&1 || exit 1
            echo "✓ Docker environment is valid"
        '''
        return true
    } catch (Exception e) {
        echo "ERROR: Docker validation failed - ${e.message}"
        return false
    }
}

def buildDockerImage(String dockerfile, String buildContext, String imageTag, Map buildArgs = [:]) {
    """
    Build Docker image with the provided parameters

    Args:
        dockerfile: Path to Dockerfile
        buildContext: Build context directory
        imageTag: Image tag to apply
        buildArgs: Map of build arguments (ARG key=value)
    """
    try {
        String buildArgsStr = buildArgs.collect { k, v -> "--build-arg ${k}=${v}" }.join(" ")

        sh """
            echo "Building Docker image: ${imageTag}"
            docker build \
                ${buildArgsStr} \
                -t "${imageTag}" \
                -f "${dockerfile}" \
                "${buildContext}"
            echo "✓ Image built successfully: ${imageTag}"
        """
        return true
    } catch (Exception e) {
        echo "ERROR: Docker build failed - ${e.message}"
        return false
    }
}

def pushDockerImage(String imageTag) {
    """
    Push Docker image to registry

    Args:
        imageTag: Full image tag including registry
    """
    try {
        sh '''
            echo "Pushing image to registry..."
            docker push "${imageTag}"
            echo "✓ Image pushed successfully"
        '''
        return true
    } catch (Exception e) {
        echo "ERROR: Docker push failed - ${e.message}"
        return false
    }
}

def createGitTag(String tagName, String message) {
    """
    Create and push Git tag

    Args:
        tagName: Tag name (e.g., v1.0.05)
        message: Tag message/annotation
    """
    try {
        sh '''
            if git rev-parse "${tagName}" >/dev/null 2>&1; then
                echo "Tag ${tagName} already exists"
                return 1
            else
                git tag -a "${tagName}" -m "${message}"
                git push origin "${tagName}"
                echo "✓ Tag created and pushed: ${tagName}"
                return 0
            fi
        '''
        return true
    } catch (Exception e) {
        echo "WARNING: Git tag operation failed - ${e.message}"
        // Don't fail the build for tag issues
        return true
    }
}

def validateKubeConfig() {
    """
    Validate that kubeconfig is properly configured
    """
    try {
        sh '''
            echo "Validating Kubernetes configuration..."
            kubectl cluster-info || exit 1
            kubectl get namespaces || exit 1
            echo "✓ Kubernetes configuration is valid"
        '''
        return true
    } catch (Exception e) {
        echo "ERROR: Kubernetes validation failed - ${e.message}"
        return false
    }
}

def deployToOCP(String namespace, String imageTag, String deploymentName) {
    """
    Deploy image to OpenShift Container Platform

    Args:
        namespace: OCP namespace
        imageTag: Full Docker image tag
        deploymentName: Name of the Kubernetes deployment
    """
    try {
        sh '''
            echo "Deploying to OCP namespace: ${namespace}"

            # Set the new image for the deployment
            kubectl set image deployment/${deploymentName} \
                ${deploymentName}=${imageTag} \
                -n ${namespace}

            # Wait for rollout to complete
            kubectl rollout status deployment/${deploymentName} \
                -n ${namespace} \
                --timeout=5m

            echo "✓ Deployment completed"
        '''
        return true
    } catch (Exception e) {
        echo "ERROR: OCP deployment failed - ${e.message}"
        return false
    }
}

def performHealthCheck(String healthUrl, int maxAttempts = 5, int delaySeconds = 10) {
    """
    Perform health check on deployed service

    Args:
        healthUrl: Health check endpoint URL
        maxAttempts: Maximum number of retry attempts
        delaySeconds: Delay between attempts
    """
    try {
        sh '''
            echo "Performing health check on: ${healthUrl}"

            for i in $(seq 1 ${maxAttempts}); do
                echo "Attempt ${i}/${maxAttempts}..."

                if curl -f -s -o /dev/null "${healthUrl}"; then
                    echo "✓ Health check passed"
                    exit 0
                fi

                if [ ${i} -lt ${maxAttempts} ]; then
                    echo "Health check failed, retrying in ${delaySeconds} seconds..."
                    sleep ${delaySeconds}
                fi
            done

            echo "ERROR: Health check failed after ${maxAttempts} attempts"
            exit 1
        '''
        return true
    } catch (Exception e) {
        echo "ERROR: Health check failed - ${e.message}"
        return false
    }
}

def rollbackDeployment(String namespace, String deploymentName) {
    """
    Rollback deployment to previous revision

    Args:
        namespace: OCP namespace
        deploymentName: Name of the Kubernetes deployment
    """
    try {
        sh '''
            echo "Rolling back deployment: ${deploymentName} in namespace ${namespace}"

            kubectl rollout undo deployment/${deploymentName} \
                -n ${namespace}

            kubectl rollout status deployment/${deploymentName} \
                -n ${namespace} \
                --timeout=5m

            echo "✓ Rollback completed"
        '''
        return true
    } catch (Exception e) {
        echo "ERROR: Rollback failed - ${e.message}"
        return false
    }
}

def getCurrentDeploymentImage(String namespace, String deploymentName) {
    """
    Get the currently deployed image tag

    Args:
        namespace: OCP namespace
        deploymentName: Name of the Kubernetes deployment

    Returns:
        Current image tag string
    """
    try {
        String currentImage = sh(
            script: """
                kubectl get deployment ${deploymentName} \
                    -n ${namespace} \
                    -o jsonpath='{.spec.template.spec.containers[0].image}'
            """,
            returnStdout: true
        ).trim()

        return currentImage
    } catch (Exception e) {
        echo "WARNING: Could not retrieve current image - ${e.message}"
        return null
    }
}

return this
