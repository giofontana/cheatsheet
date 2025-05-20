
# Jsonpath with dot

```bash
oc get secret/router-ca -n openshift-ingress-operator -o jsonpath="{.data['tls\.crt']}" | base64 -d
```