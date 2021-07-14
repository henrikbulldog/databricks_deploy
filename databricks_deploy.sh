#!/bin/bash
echo "Prerequisites:"
echo "Docker must be installed (https://docs.docker.com/docker-for-windows/install/)"
echo "You must be logged in to a Docker repo (docker login)"
echo "You must have docker cli installed and profile used here should be configured using docker cofigure"
#Read scala version from sbt
PROJECT_NAME="$(sbt name | tail -1)"
imagename="${PROJECT_NAME#* }"
#
SCALA_VERSION="$(sbt scalaVersion | tail -1 | awk -F '.' '{print $1 "."$2}')"
SCALA_VERSION="${SCALA_VERSION#* }"
#
#
#echo ${PROJECT_NAME}
#Jump to function for better control
function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}
start=${1:-"start"}

jumpto $start

start:
read -p "Do you want to clean and build the project.Pressing no will skip creation of container too and use the exiting container in dockerhub$build? [y/n]" answer
#
if [[ ${answer} = y ]]; then
sbt clean package
sbt copyJarsTask
else
jumpto createcluster
fi
#
read -p "Do you want to build and push the container to docker hub $f? [y/n]" answer

if [[ ${answer} = y ]]; then
read -p "Enter the image name [${imagename}] : $name" imagename
docker build  --build-arg SCALA_VERSION="scala-${SCALA_VERSION}" --no-cache -t imagename:local .
fi


deploy:
#Running deploy script
echo "Creating tag and pushing  the container to dockerhub"
bash  $(pwd)/deploy.sh

createcluster:
#Reading configuration from yaml
echo "Creating cluster"
. parse_yaml.sh

read -p "Please enter the configuration yml file name $f:" filename

if [ -e ${filename} ]
then
eval $(parse_yaml ${filename} "config_")
else
echo "No file with ${filename} name exists.Exiting..."
jumpto end
fi


function strip_quotes() {
    local -n var="$1"
    [[ "${var}" == \"*\" || "${var}" == \'*\' ]] && var="${var:1:-1}"
}
#Create the databricks config json file
function create_databricks_config_json()
{
    {
echo '{
    "autoscale": {
    "min_workers":' $config_min_workers',
    "max_workers":' $config_max_workers '},
    "cluster_name"': $config_clustername',
    "spark_version"': $config_spark_version',
    "spark_conf": {
    "spark.hadoop.fs.s3a.impl": "com.databricks.s3a.S3AFileSystem",
     "spark.hadoop.fs.s3n.impl": "com.databricks.s3a.S3AFileSystem",
     "spark.hadoop.fs.s3a.credentialsType": "AssumeRole",
     "spark.hadoop.fs.s3a.stsAssumeRole.arn":' $config_roles_assume_role_arn ',
     "spark.hadoop.fs.s3.impl": "com.databricks.s3a.S3AFileSystem"
     },
     "aws_attributes": {
     "zone_id"': $config_zone_id ',
     "instance_profile_arn":' $config_roles_instance_profile_arn '},
     "node_type_id":' $config_node_type_id',
     "autotermination_minutes":' $config_autotermination_minutes',
     "driver_node_type_id":' $config_driver_node_type_id',
     "docker_image": {
      "url":'$config_docker_image_url '},'
    }>> databricks_cluster.json
    profile=$config_databricks_profile
    strip_quotes profile
     if [[ $profile != "DEV"  ]]; then
       echo '"spark_env_vars":{
        "AWS_STS_REGIONAL_ENDPOINTS": "regional"}
      }'>> databricks_cluster.json
      fi
}

#Create cluster with specified name
function create_cluster(){
create_databricks_config_json
profile_name=$config_databricks_profile
strip_quotes profile_name
databricks clusters create --json-file databricks_cluster.json --profile $profile_name
echo "### Cluster created sucessfully with below information ###"
cluster_name=$config_clustername
strip_quotes cluster_name
echo $(databricks clusters get --cluster-name "$cluster_name")
}

#delete the cluster if exits and recreates with  new docker image
function delete_create_cluster(){
#  set -x
cluster_id=$1
profile=$config_databricks_profile
strip_quotes profile
echo "cluster ${cluster_id}"
databricks clusters permanent-delete --cluster-id $cluster_id --profile $profile
create_cluster
}

cluster_id=""

read -p "Create Databricks cluster and deploy docker image $cluster? [y/n]" answer

if [[ ${answer} = y ]]; then
cluster_name=$config_clustername
strip_quotes cluster_name
cluster_id=$(databricks clusters get --cluster-name "$cluster_name" | grep -oP '(?<="cluster_id": ")[^"]*')
else
jumpto end
fi
if [[ -z "$cluster_id" ]]; then
echo "Creating cluster"
create_cluster
else
echo "Cluster already  exist with name $config_clustername and id  ${cluster_id} Deleting and recreating"
delete_create_cluster "$cluster_id"
fi
#End of script
end:
echo "Cleaning up"
#Cleanup the jars
sbt deleteJarsTask
##remove json file
if [ -e databricks_cluster.json ]
then
rm databricks_cluster.json
fi
exit 1
