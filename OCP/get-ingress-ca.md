# Command to get ingress default CA certificate

```bash
# Certificate:
oc get secret/router-ca -n openshift-ingress-operator -o jsonpath="{.data['tls\.crt']}" | base64 -d
#Key:
oc get secret/router-ca -n openshift-ingress-operator -o jsonpath="{.data['tls\.key']}" | base64 -d
```