oc create secret docker-registry ibm-entitlement-key --docker-username=cp --docker-password=$IBM_CR_PASSWORD --docker-server="cp.icr.io" 
oc ibm-pak get ibm-eventendpointmanagement 
oc ibm-pak generate mirror-manifests ibm-eventendpointmanagement icr.io 
oc apply -f ~/.ibm-pak/data/mirror/ibm-eventendpointmanagement/11.6.4/catalog-sources.yaml
oc apply -f operatorGroup.yaml
oc get OperatorGroup
oc apply -f subscription.yaml
oc get csv
oc apply -f eventEndpointManagement.yaml
oc get EventEndpointManagement eem-manager


