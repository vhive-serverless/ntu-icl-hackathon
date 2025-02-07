#! /bin/bash

# create team namespaces, roles, rolebindings, and quotas

for i in {1..5}
do
  cat configs/access-template.yaml | NUMBER=$i envsubst | kubectl apply -f -
done

# Generate team tokens

CA_CERT=$(cat /etc/kubernetes/pki/ca.crt | base64 -w 0)
echo '01' | sudo tee /etc/kubernetes/pki/ca.srl
for i in {1..5}
do
  TEAM="team-${i}"
  openssl req -new -newkey rsa:2048 -nodes -keyout ${TEAM}.key -out ${TEAM}.csr -subj "/CN=${TEAM}/O=${TEAM}"
  sudo openssl x509 -req -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -in ${TEAM}.csr -out ${TEAM}.crt -days 5
  export TEAM=$TEAM
  export CLIENT_CERT=$(cat ${TEAM}.crt | base64 -w 0)
  export CLIENT_KEY=$(cat ${TEAM}.key | base64 -w 0)
  export CA_CERT=$CA_CERT
  cat configs/kubeconfig-template | envsubst > configs/kubeconfig-$TEAM
  chmod 600 configs/kubeconfig-$TEAM
done
