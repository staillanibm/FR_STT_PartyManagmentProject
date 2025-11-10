kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
kubectl apply -f ClusterIssuer.yaml

DOMAIN=$(oc get dnses.config.openshift.io cluster -o jsonpath='{.spec.baseDomain}')
NAMESPACE=events

EGW_SUFFIX=${NAMESPACE}.apps.${DOMAIN}
sed -i '' "s/events\.apps\.[a-z0-9\.]*\.techzone\.ibm\.com/$EGW_SUFFIX/g" GatewayCertificate.yaml

kubectl apply -f GatewayCertificate.yaml
kubectl get secret stt-egw-certs -o yaml

kubectl apply -f egw-secret.yaml

openssl pkcs12 -export \
  -in eem-truststore.pem \
  -out eem-truststore.p12 \
  -nokeys \
  -name "eem-truststore" \
  -passout pass:Password123@

keytool -importkeystore \
  -srckeystore eem-truststore.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass Password123@ \
  -destkeystore eem-truststore.jks \
  -deststoretype JKS \
  -deststorepass Password123@

