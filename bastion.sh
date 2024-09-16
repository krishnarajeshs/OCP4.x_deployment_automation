#!/usr/bin/sh
##############################################################
## CONFIGURATION PARAMS TO WORK WITH   		  	    ##
##  							    ##
## BELOW ARE THE IMPORTANT POINTS BEFORE RUNNING THE SCRIPT ##
## 1. MAKE SURE YUM REPO IS CONFIGURED AT /etc/repos.yum.d/ ##
## 2. CHANGE THE PARAMETERS BETWEEN START AND END SECTION   ##
## 3. MAKE SURE DNS ENTERIES ARE ADDED FOR BOTH             ##
##     - BASTION HOST                                       ##
##     - REGISTRY SERVER HOST                               ##
##    ex : nslookup "<<REGISTRY SERVER HOST>>"              ##
##    SHOULD RETURN VALID RESPONSE                          ##  
## 4. DOWNLOAD PULL SECRET AND UPDATE THE PATH OF PULLSECRET##
##							    ##
##############################################################

PRODUCT_REPO='openshift-release-dev'
RELEASE_NAME="ocp-release"
ARCHITECTURE="x86_64"

##############################################################
########################## START OF CHANGES ##################
##############################################################
## OPENSHIFT VERSION TO DOWNLOAD
OCP_VERSION=4.16
OCP_RELEASE=4.16.10

## NAME OF THE DIRECTORY TO DOWNLOAD THE REQUIRED FILES
LOCAL_DIR="/data"

## REGISTRY SERVER DETAILS
LOCAL_REGISTRY_SERVER_NAME="registry.ocp4.homelab.local"
LOCAL_REPOSITORY_PATH="/data"
LOCAL_REPOSITORY_NAME="ocp_416"
REGISTRY_SERVER_ROOT_PASSWD="root123"
LOCAL_REGISTRY_USER=init
LOCAL_REGISTRY_PASSWORD="P@ssw0rd"
LOCAL_REGISTRY_EMAIL="ocpadmin@homelab.com"
#LOCAL_REGISTRY_SERVER="$LOCAL_REGISTRY_SERVER_NAME:8443"
#LOCAL_REGISTRY_CA=$LOCAL_CA

## LOCATION AND FILENAME OF PULL-SECRET DOWNLOADED FROM https://cloud.redhat.com/openshift/install/pull-secret
PULL_SECRET_PATH="/data/registry/downloads/secrets"
PULL_SECRET_FILE="pull-secret.txt"

##############################################################
########################## END OF CHANGES ####################
##############################################################

OCP_CATALOG="registry.redhat.io/redhat/redhat-operator-index:v$OCP_VERSION"
OCP_URL=https://mirror.openshift.com/pub/openshift-v4

echo ""
echo "Downloading Packages from RHEL Repo.."
# Install Red Hat Tools
yum install -y podman jq openssl httpd-tools curl wget telnet nfs-utils httpd.x86_64 bind bind-utils rsync mkisofs haproxy openssh sshpass

echo ""
echo "Downloading Terraform Repo"
## Download and Install Terraform
#yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
#yum clean all
#yum update 
#echo "Installing Terraform"
#yum -y install terraform

## Creating directories
echo ""
echo "Creating required directories in $LOCAL_DIR"
cd $LOCAL_DIR/
mkdir /$LOCAL_DIR/registry
cd $LOCAL_DIR/registry/
mkdir auth certs data downloads
d downloads/
mkdir images tools secrets

# Download and Install OCP Tools
echo ""
echo "Downloading required OCP Pacakges - $LOCAL_DIR/registry/downloads/tools/"
cd $LOCAL_DIR/registry/downloads/tools/
rm -f $LOCAL_DIR/registry/downloads/tools/*.tar.gz

wget $OCP_URL/clients/butane/latest/butane --no-check-certificate
wget $OCP_URL/x86_64/clients/ocp/$OCP_RELEASE/openshift-client-linux-$OCP_RELEASE.tar.gz --no-check-certificate
wget $OCP_URL/x86_64/clients/ocp/$OCP_RELEASE/openshift-install-linux-$OCP_RELEASE.tar.gz --no-check-certificate
## IGNORE BELOW URLS
#wget $OCP_URL/x86_64/clients/ocp/latest-$OCP_VERSION/openshift-client-linux-$OCP_RELEASE.tar.gz --no-check-certificate
#wget $OCP_URL/x86_64/clients/ocp/latest-$OCP_VERSION/openshift-install-linux-$OCP_RELEASE.tar.gz --no-check-certificate

# TO SETUP quay.io local registry in registry server
echo ""
echo "Downloading oc-mirror to setup quay in registry server ($LOCAL_REGISTRY_SERVER_NAME)"
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/$OCP_RELEASE/oc-mirror.tar.gz --no-check-certificate

 Mirror registry binary - THIS HAS TO BE INSTALLED IN REGISTRY SERVER  
wget https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/mirror-registry/latest/mirror-registry.tar.gz --no-check-certificate

## Unpacking the downloaded packages
echo ""
echo "Unpacking downloaded tar.gz files "
tar -xvf openshift-client-linux-$OCP_RELEASE.tar.gz --directory=/usr/bin/ --exclude="README*"
tar -xvf openshift-install-linux-$OCP_RELEASE.tar.gz --directory=/usr/bin/ --exclude="README*"
tar -xvf oc-mirror.tar.gz --directory=/usr/bin/ --exclude="README*"

echo ""
echo "Setting execute permissions to downloaded executables"
mv butane /usr/bin/.
chmod +x /usr/bin/oc
chmod +x /usr/bin/kubectl
chmod +x /usr/bin/butane
chmod +x /usr/bin/oc-mirror
chmod +x /usr/bin/openshift-install

##### IGNORE - START #######

#mkdir $LOCAL_DIR/registry/downloads/tools/mirror-registry
#tar -xvf $LOCAL_DIR/registry/downloads/tools/mirror-registry.tar.gz --directory=$LOCAL_DIR/registry/downloads/tools/mirror-registry/
## Keys needs to be shared between Bastion and Registry
#echo ""
#echo "Generating SSH keys for Bastion (to be shared with Registry server"
##ssh-keygen
#ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
#ssh-add
#echo $REGISTRY_SERVER_ROOT_PASSWD | sshpass ssh-copy-id -f -i /root/.ssh/id_rsa.pub $LOCAL_REGISTRY_SERVER_NAME
#mirror_cmd="$LOCAL_DIR/registry/downloads/tools/mirror-registry/mirror-registry install --targetHostname $LOCAL_REGISTRY_SERVER_NAME --targetUsername init --quayHostname $LOCAL_REGISTRY_SERVER_NAME    --quayRoot $LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME/install --initUser $LOCAL_REGISTRY_USER --initPassword $LOCAL_REGISTRY_PASSWORD  --quayStorage $LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME/data -k /root/.ssh/id_rsa.pub -v" 
#echo ""
#echo $mirror_cmd
#$mirror_cmd

##### IGNORE - END  ######

 Copying files to Registry server
echo ""
echo "Copying mirror-registry.tar.gz to $LOCAL_REGISTRY_SERVER_NAME:/tmp/ocp_registry"
## Creating directory
sshpass -p "$REGISTRY_SERVER_ROOT_PASSWD" ssh -t $LOCAL_REGISTRY_SERVER_NAME rm -rf /tmp/ocp_registry/ 2>&1
unpack_output=`sshpass -p "$REGISTRY_SERVER_ROOT_PASSWD" ssh -t $LOCAL_REGISTRY_SERVER_NAME mkdir /tmp/ocp_registry  2>&1`
## Copying the file to remote server
sshpass -p "$REGISTRY_SERVER_ROOT_PASSWD" scp -r -o "StrictHostKeyChecking no" $LOCAL_DIR/registry/downloads/tools/mirror-registry.tar.gz $LOCAL_REGISTRY_SERVER_NAME:/tmp/ocp_registry/ 2>&1
echo "finished copying file mirror-registry.tar.gz to $LOCAL_REGISTRY_SERVER_NAME:/tmp/registry"

## Unpacking the file $LOCAL_REGISTRY_SERVER_NAME:/tmp/mirror-registry.tar.gz
echo "started unpacking the file - $LOCAL_REGISTRY_SERVER_NAME:/tmp/ocp_registry/mirror-registry.tar.gz"
unpack_output=`sshpass -p "$REGISTRY_SERVER_ROOT_PASSWD" ssh -t $LOCAL_REGISTRY_SERVER_NAME  tar -xvf /tmp/ocp_registry/mirror-registry.tar.gz --directory=/tmp/ocp_registry/ 2>&1`
echo $unpack_output
echo "successfully unpacked the file - $LOCAL_REGISTRY_SERVER_NAME:/tmp/ocp_registry/mirror-registry.tar.gz"

#echo "Unpacking mirror registry in bastion host"
#tar -xvf $LOCAL_DIR/registry/downloads/tools/mirror-registry.tar.gz --directory=$LOCAL_DIR/registry/downloads/tools/

echo ""
## Copying file to Registry Server and creating required directories
echo "Creating local repo directories $LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME in $LOCAL_REGISTRY_SERVER_NAME"
unpack_output=`sshpass -p "$REGISTRY_SERVER_ROOT_PASSWD" ssh -t $LOCAL_REGISTRY_SERVER_NAME mkdir -p /$LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME /$LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME/data /$LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME/install`
echo "Created local repo directories $LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME in $LOCAL_REGISTRY_SERVER_NAME"

echo "Setting up local QUAY in registry server : $LOCAL_REGISTRY_SERVER_NAME "
registry_cmd="/tmp/ocp_registry/mirror-registry install --quayRoot $LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME/install --quayHostname $LOCAL_REGISTRY_SERVER_NAME --initUser $LOCAL_REGISTRY_USER --initPassword $LOCAL_REGISTRY_PASSWORD  --quayStorage $LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME/data"
echo "Command to run in registry server : $registry_cmd"
unpack_output=`sshpass -p "$REGISTRY_SERVER_ROOT_PASSWD" ssh -t $LOCAL_REGISTRY_SERVER_NAME $registry_cmd`
echo $unpack_output
echo "Completed setting up local QUAY in registry server : $LOCAL_REGISTRY_SERVER_NAME and response .."

## Adding Registry CA to trust store in Registry server
echo "Adding rootCA.pem generated in $LOCAL_REGISTRY_SERVER_NAME to truststore in $LOCAL_REGISTRY_SERVER_NAME server"
unpack_output=`sshpass -p "$REGISTRY_SERVER_ROOT_PASSWD" ssh -t $LOCAL_REGISTRY_SERVER_NAME cp $LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME/install/quay-rootCA/rootCA.pem /etc/pki/ca-trust/source/anchors/ && update-ca-trust`
echo $unpack_output
echo "Succesfully updated truststore in $LOCAL_REGISTRY_SERVER_NAME server"

##  PULL THE CA CERTIFICATE FROM REGISTRY TO BASTION AND UPDATE IN BASTION
echo ""
echo "Downloading $LOCAL_REGISTRY_SERVER_NAME default certificates"
#openssl s_client -showcerts -connect registry.ocp4.homelab.local:8443 </dev/null 2>/dev/null |openssl x509 -outform PEM >"$LOCAL_DIR/registry/certs/registry_defaultca.pem"
cd $LOCAL_DIR/registry/certs/
openssl s_client -showcerts -verify 5 -connect $LOCAL_REGISTRY_SERVER_NAME  < /dev/null | awk '/BEGIN/,/END/{ if(/BEGIN/){a++}; out="registry_cert"a".pem"; print >out}'
echo "Successfully $LOCAL_REGISTRY_SERVER_NAME default certificates"

echo "Adding $LOCAL_DIR/registry/certs/registry_defaultca.crt to Bastion host trust store.."
cp $LOCAL_DIR/registry/certs/*.pem /etc/pki/ca-trust/source/anchors/
update-ca-trust
echo "Successfully added $LOCAL_DIR/registry/certs/registry_defaultca.crt to Bastion host trust store!"

echo ""
echo "Looking for Pull secret at $PULL_SECRET_PATH/$PULL_SECRET_FILE"
cat $PULL_SECRET_PATH/$PULL_SECRET_FILE | jq . > $PULL_SECRET_PATH/pull-secret.json
echo "Successfully created $PULL_SECRET_PATH/pull-secret.json"

## Generating local registry username and password to base64 so as to append to pull-secret file
registry_userdetails_base64=`echo -n "$LOCAL_REGISTRY_USER:$LOCAL_REGISTRY_PASSWORD" | base64 -w0`
#echo $registry_userdetails_base64

## Updating Pull secret with local registry details too
echo "Updating Pull secret with local registry details"
cat $PULL_SECRET_PATH/pull-secret.json | jq --arg REGISTRY "$LOCAL_REGISTRY_SERVER_NAME" --arg auth "$registry_userdetails_base64" --arg email "$LOCAL_REGISTRY_EMAIL" '.auths |= . + { ($REGISTRY) : {"auth":$auth,"email":$email}}' | jq --arg REGISTRY "$LOCAL_REPOSITORY_PATH/$LOCAL_REPOSITORY_NAME" > $PULL_SECRET_PATH/pull-secret-new.json
mv $PULL_SECRET_PATH/pull-secret-new.json $PULL_SECRET_PATH/pull-secret.json
echo "Successfully updated secret with local registry details"

## Setting Docker / Containers authorization
echo "Setting Podman and Docker authorizations to use pull-secret"
XDG_RUNTIME_DIR=echo "$XDG_RUNTIME_DIR"
#echo $XDG_RUNTIME_DIR
mkdir $XDG_RUNTIME_DIR/containers
cp $PULL_SECRET_PATH/pull-secret.json $XDG_RUNTIME_DIR/containers/auth.json
mkdir ~/.docker
cp $PULL_SECRET_PATH/pull-secret.json ~/.docker/config.json
echo "successfully updated Podman and Docker authorizations to use pull-secret"


echo ""
echo "Creating imageset-config.yaml in $LOCAL_DIR/registry"
cd $LOCAL_DIR/registry
cat <<EOF > imageset-config.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v1alpha2
archiveSize: 4
storageConfig:
  registry:
    imageURL: $LOCAL_REGISTRY_SERVER_NAME:8443/$LOCAL_REPOSITORY_NAME
    skipTLS: false
mirror:
  platform:
    architectures:
      - "amd64"
    channels:
    - name: stable-$OCP_VERSION
      type: ocp
      minVersion: $OCP_RELEASE
      maxVersion: $OCP_RELEASE
      shortestPath: true
    graph: true
  operators:
  - catalog: registry.redhat.io/redhat/redhat-operator-index:v$OCP_VERSION
    packages:
    - name: cluster-logging
      defaultChannel: stable
      channels:
      - name: stable
    - name: elasticsearch-operator
      defaultChannel: stable
      channels:
      - name: stable
    - name: openshift-pipelines-operator-rh
      defaultChannel: latest
      channels:
      - name: latest
  additionalImages:
  - name: registry.redhat.io/ubi8/ubi:latest
  helm: {}
EOF
echo "Successfully created imageset-config.yaml in $LOCAL_DIR/registry"

## Change to directory so that workspace is created
echo ""
echo ""
cd $LOCAL_DIR
## Below command is tested in Customer env. Before enabling this command, make sure local registry ssl.key and ssl.certs are uploaded
oc_mirror_cmd="oc mirror --config=$LOCAL_DIR/registry/imageset-config.yaml docker://$LOCAL_REGISTRY_SERVER_NAME:8443 --dest-skip-tls"
echo "Starting to mirror ${OCP_RELEASE}-${ARCHITECTURE} from  quay.io to ${LOCAL_REGISTRY_SERVER_NAME}/${LOCAL_REPOSITORY_NAME}"

## NOTE: Below command is not required. Above one worked 
#oc_mirror_cmd="oc adm release mirror -a ${PULL_SECRET_PATH}/pull-secret.json --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} --to=${LOCAL_REGISTRY_SERVER_NAME}/${LOCAL_REPOSITORY_NAME} --to-release-image=${LOCAL_REGISTRY_SERVER_NAME}/${LOCAL_REPOSITORY_NAME}:${OCP_RELEASE}-${ARCHITECTURE} --dry-run"
oc_mirror_output=`$oc_mirror_cmd`

echo $oc_mirror_output
echo "Successfully completed to mirror ${OCP_RELEASE}-${ARCHITECTURE} from  quay.io to ${LOCAL_REGISTRY_SERVER_NAME}/${LOCAL_REPOSITORY_NAME}"
