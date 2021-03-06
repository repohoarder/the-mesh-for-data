#!/usr/bin/env bash
# Copyright 2020 IBM Corp.
# SPDX-License-Identifier: Apache-2.0


: ${KUBE_NAMESPACE:=m4d-system}
: ${PORT_TO_FORWARD:=8200}
: ${DATA_PROVIDER_USERNAME:=data_provider}
: ${DATA_PROVIDER_PASSWORD:=password}
: ${KUBERNETES_AUTH_ROLE:=demo}

enable_kv() {
  # Enable kv engine to write secrets to vault
  echo "enabling kv engine for endpoint: $1"

  # Enable the secret endpoint
  curl \
    --header "X-Vault-Token: $2" \
    --request POST \
    --data '{"type": "kv", "options": {"version": "1"} }' \
    http://127.0.0.1:"$PORT_TO_FORWARD"/v1/sys/mounts/"$1"
  
  #Equivalent using the CLI:
  # vault secrets enable -path=$2 -version=1 kv
}

# $1 - policy name
# $2 - vault-token
enable_k8s_auth() {
  # Enable k8s service account token auth
  echo "enabling k8s auth"
  curl \
    --header "X-Vault-Token: $2" \
    --request POST \
    --data '{"type": "kubernetes"}' \
    http://127.0.0.1:"$PORT_TO_FORWARD"/v1/sys/auth/kubernetes
  
  # Equivalent using the CLI:
  # vault auth enable kubernetes

  # Find the name of the vault service account secret using regex, as it's of the form vault-token-<something>
  for SECRET_NAME in $(kubectl get sa vault -n $KUBE_NAMESPACE -o jsonpath="{.secrets[*]['name']}")
  do
    if [[ $SECRET_NAME =~ ^vault-token-.* ]]
    then
      VAULT_SA_SECRET_NAME=$SECRET_NAME
      echo "name of the secret: $VAULT_SA_SECRET_NAME"
    fi
  done
  
  export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_SECRET_NAME -n $KUBE_NAMESPACE -o jsonpath="{.data.token}" | base64 --decode)
  export SA_CA_CRT=$(jq -n --arg cert "$(kubectl get secret $VAULT_SA_SECRET_NAME -n $KUBE_NAMESPACE -o jsonpath="{.data['ca\.crt']}" | base64 --decode)" '$cert')
  
  # Configure the k8s sa auth
  echo "configuring k8s auth"
  curl \
    --header "X-Vault-Token: $2" \
    --request POST \
    --data '{"kubernetes_host": "https://kubernetes.default.svc:443","token_reviewer_jwt":"'"$SA_JWT_TOKEN"'", "kubernetes_ca_cert":'"$SA_CA_CRT"'}' \
    http://127.0.0.1:"$PORT_TO_FORWARD"/v1/auth/kubernetes/config
  
  # Equivalent using the CLI:
  # vault write auth/kubernetes/config \
  #   token_reviewer_jwt="$SA_JWT_TOKEN" \
  #   kubernetes_host="https://kubernetes.default.svc:443" \
  #   kubernetes_ca_cert="$SA_CA_CRT"
  
  # Configure a role for the secret-provider
  echo "creating role $KUBERNETES_AUTH_ROLE in k8s auth"
  curl \
    --header "X-Vault-Token: $2" \
    --request POST \
    --data '{"bound_service_account_names": "secret-provider", "bound_service_account_namespaces": "'$KUBE_NAMESPACE'", "policies": "'$1'", "ttl": "24h"}' \
    http://127.0.0.1:"$PORT_TO_FORWARD"/v1/auth/kubernetes/role/"$KUBERNETES_AUTH_ROLE"

  # Equivalent using the CLI:
  # vault write auth/kubernetes/role/demo \
  #      bound_service_account_names=secret-provider \
  #      bound_service_account_namespaces=$KUBE_NAMESPACE \
  #      policies=$1 \
  #      ttl=24h
}

# $1 - policy name
# $2 - vault-token
enable_userpass_auth() {
  echo "enabling userpass auth"
  curl \
    --header "X-Vault-Token: $2" \
    --request POST \
    --data '{"type": "userpass"}' \
    http://127.0.0.1:"$PORT_TO_FORWARD"/v1/sys/auth/userpass
  
  echo "creating user $DATA_PROVIDER_USERNAME in userpass auth"
  curl \
    --header "X-Vault-Token: $2" \
    --request POST \
    --data '{"password": "'$DATA_PROVIDER_PASSWORD'", "policies": "'$1'", "ttl": "24h"}' \
    http://127.0.0.1:"$PORT_TO_FORWARD"/v1/auth/userpass/users/"$DATA_PROVIDER_USERNAME"
}

# $1 - policy name
# $2 - path
# $3 - vault-token
create_policy() {
  echo "creating policy $1, to access the secrets in: $2 "
  curl \
    --header "X-Vault-Token: $3" \
    --request PUT \
    --data '{"policy": "path \"'$2'\" { capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"] }"}' \
    http://127.0.0.1:"$PORT_TO_FORWARD"/v1/sys/policy/"$1"
  
  # Equivalent using the CLI:
  # vault policy write "$2" - <<EOF
#path '"'$3'"' {
#    capabilities = ["create", "read", "update", "delete", "list"]
#}
#EOF
}

configure() {
  # Make sure the vault pod is ready
  while [[ $(kubectl get -n $KUBE_NAMESPACE pods -l statefulset.kubernetes.io/pod-name=vault-0 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]];
  do
      echo "waiting for vault pod to become ready" 
      sleep 5
  done
  
  # Port forward, so we could access vault
  kubectl port-forward -n $KUBE_NAMESPACE service/vault "$PORT_TO_FORWARD":8200 &
  while ! nc -z localhost "$PORT_TO_FORWARD"; do echo "Waiting for the port-forward from $PORT_TO_FORWARD to 8200 to take effect"; sleep 1; done

  # Get Vault's root token
  export VAULT_TOKEN=$(kubectl get secrets vault-unseal-keys -n $KUBE_NAMESPACE -o jsonpath={.data.vault-root} | base64 --decode)
  
  # Enabling kv
  enable_kv "secret" "$VAULT_TOKEN"
  enable_kv "external" "$VAULT_TOKEN"
  
  # creating allow-all policy
  create_policy "allow-all-secret" "secret/*" $VAULT_TOKEN
  # creating external policy (for the data-provider)
  create_policy "allow-all-external" "external/*" $VAULT_TOKEN

  enable_k8s_auth "allow-all-secret" $VAULT_TOKEN
  enable_userpass_auth "allow-all-external" $VAULT_TOKEN
}

# $1 - the path of the secret
# $2 - the secret, as json
# $3 - vault-token
push_secret() {
  curl \
    -H "X-Vault-Token: $3" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$2" \
    http://127.0.0.1:"$PORT_TO_FORWARD"/v1/$1
}

populate_demo_secrets() {
  # Push some secrets, assuming the user has exported the APIKEY
  export VAULT_TOKEN=$(kubectl get secrets vault-unseal-keys -n $KUBE_NAMESPACE -o jsonpath={.data.vault-root} | base64 --decode)
  echo "pushing some secrets to vault"
  push_secret "secret/cos" '{"api_key":"'"$APIKEY"'"}' $VAULT_TOKEN
  push_secret "secret/fake-key" '{"api_key":"abcdefgh12345678"}' $VAULT_TOKEN
  push_secret "secret/db2y" '{"password":"s3cr3t", "username":"user1"}' $VAULT_TOKEN
  push_secret "secret/some-secret" '{"password":"pass-pass", "username":"data-provider-1"}' $VAULT_TOKEN
  push_secret "external/some-secret" '{"password":"pass-pass", "username":"data-provider-2"}' $VAULT_TOKEN
  
  #Equivalent using the CLI:
  #vault kv put secret/cos api_key=$APIKEY
  #vault kv put secret/fake-key api_key=abcdefgh12345678
  #vault kv put secret/db2 username=user1 password=s3cr3t
  #vault kv put secret/some-secret username=data-provider password=pass-pass
  #vault kv put external/some-secret username=data-provider password=pass-pass
}

case "$1" in
    configure)
      configure
    ;;
    populate_demo_secrets)
      populate_demo_secrets
    ;;
    *)
      echo "usage: %0 [configure|populate_demo_secrets]"
      exit 1
    ;;
esac
