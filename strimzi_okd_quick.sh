#!/usr/bin/env bash

# Turn colors in this script off by setting the NO_COLOR variable in your
# environment to any value:
#
# $ NO_COLOR=1 test.sh
NO_COLOR=${NO_COLOR:-""}
if [ -z "$NO_COLOR" ]; then
  header=$'\e[1;33m'
  reset=$'\e[0m'
else
  header=''
  reset=''
fi

function header_text {
  echo "$header$*$reset"
}

header_text "Starting Strimzi on OpenShift!"

echo "Using oc version:"
oc version

header_text "Writing config"
oc cluster up --write-config
sed -i -e 's/"admissionConfig":{"pluginConfig":null}/"admissionConfig": {\
    "pluginConfig": {\
        "ValidatingAdmissionWebhook": {\
            "configuration": {\
                "apiVersion": "v1",\
                "kind": "DefaultAdmissionConfig",\
                "disable": false\
            }\
        },\
        "MutatingAdmissionWebhook": {\
            "configuration": {\
                "apiVersion": "v1",\
                "kind": "DefaultAdmissionConfig",\
                "disable": false\
            }\
        }\
    }\
}/' openshift.local.clusterup/kube-apiserver/master-config.yaml

header_text "Starting OpenShift with 'oc cluster up'"
oc cluster up --server-loglevel=5

header_text "Logging in as system:admin and setting up 'developer' account"
oc login -u system:admin
oc adm policy add-cluster-role-to-user cluster-admin developer
oc login -u developer -p developer

oc project myproject

header_text "Setting up Strimzi for Openshift"
wget https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.7.0/strimzi-0.7.0.tar.gz
tar xfvz strimzi-0.7.0.tar.gz
cd strimzi-0.7.0

oc apply -f examples/install/cluster-operator -n myproject
oc apply -f examples/templates/cluster-operator -n myproject

header_text "Waiting for Strimzi Cluster Operator to become ready"
sleep 5; while echo && oc get pods -n myproject | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

oc apply -f examples/kafka/kafka-ephemeral.yaml
header_text "Waiting for Apache Kafka Cluster to become ready"
sleep 5; while echo && oc get pods -n myproject | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done
