kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
kubectl apply -f ClusterIssuer.yaml

DOMAIN=$(oc get dnses.config.openshift.io cluster -o jsonpath='{.spec.baseDomain}')
NAMESPACE=events

EGW_SUFFIX=${NAMESPACE}.apps.${DOMAIN}
sed -i '' "s/events\.apps\.[a-z0-9\.]*\.techzone\.ibm\.com/$EGW_SUFFIX/g" GatewayCertificate.yaml

kubectl apply -f GatewayCertificate.yaml
kubectl get secret stt-egw-certs -o yaml

kubectl apply -f egw-secret.yaml
kubectl apply -f egw-deploy.yaml


keytool -import -trustcacerts \
  -alias eem-selfsigned-ca \
  -file ca-cert.pem \
  -keystore eem.truststore.jks \
  -storetype JKS \
  -storepass changeit \
  -noprompt


kcat -L -b vb0-events.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com:443,vb1-events.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com:443,vb2-events.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com:443 \
  -X security.protocol=SASL_SSL \
  -X sasl.mechanism=PLAIN \
  -X sasl.username=... \
  -X sasl.password=... \
  -X ssl.ca.location=./ca-cert.pem
