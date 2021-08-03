@echo off
setlocal
echo Deploys a Scala project to a Databricks cluster.
echo Prerequisites:
echo - Docker must be installed (https://docs.docker.com/docker-for-windows/install/)
echo You must be logged in to a Docker repo (docker login)
echo - Python must be installed (https://www.python.org/ftp/python/3.6.4/python-3.6.4.exe)
echo - Databricks cli must be installed (pip install databricks-cli)
echo - Databricks cli must be configured (databricks configure)

echo Enter Scala version (2.12):
set /P "scala_version=" || set "scala_version=2.12"

set /P c=Build project [Y/N]?
if /I "%c%" EQU "Y" goto :build
if /I "%c%" EQU "N" goto :skip_build
goto :skip_build

:build
del .\target\scala-%scala_version%\*.jar /Q

call sbt clean package copyJarsTask

:skip_build

for %%f in (%cd%) do set image_name=%%~nxf
echo Enter Docker user name:
set /P "docker_username="
echo Enter Docker image (%image_name%):
set /P "image_name=" || set "image_name=%image_name%"
echo Enter Docker image tag (latest):
set /P "tag=" || set "tag=latest"

set /P c=Build and push Docker image [Y/N]?
if /I "%c%" EQU "Y" goto :dockerize
if /I "%c%" EQU "N" goto :skip_dockerize
goto :skip_dockerize

:dockerize

echo FROM databricksruntime/standard:latest > Dockerfile
if exist ./lib/ (
  echo ADD ./lib/*.jar /databricks/jars/ >> Dockerfile
)
if exist ./lib/jars/ (
  echo ADD ./lib/jars/*.jar /databricks/jars/ >> Dockerfile
)
echo ADD ./target/scala-%scala_version%/*.jar /databricks/jars/ >> Dockerfile

@echo on
docker build -t %docker_username%/%image_name%:%tag% .

docker push %docker_username%/%image_name%:%tag%
@echo off

del Dockerfile
if exist ./lib/jars/ (
  rd "./lib/jars" /S /Q
)

:skip_dockerize

set /P c=Create Databricks cluster [Y/N]?
if /I "%c%" EQU "Y" goto :create_cluster
if /I "%c%" EQU "N" goto :exit
goto :exit

:create_cluster
echo Enter Cluster name (%username%/%image_name%):
set /P "cluster_name=" || set "cluster_name=%username%/%image_name%"

if "%scala_version%"=="2.11" (
  set "spark_version=6.4.x-esr-scala2.11"
)
if "%scala_version%"=="2.12" (
  set "spark_version=7.3.x-scala2.12"
)
echo Enter Spark version (%spark_version%):
set /P "spark_version=" || set "spark_version=%spark_version%"

echo Enter Databricks workspace profile (default):
set /P "databricks_profile=" || set "databricks_profile=default"

for /f "eol=- delims=" %%a in (%userprofile%\%databricks_profile%.databricks.config) do set "%%a"

echo Enter Databricks instance profile arn (%instance_profile_arn%):
set /P "instance_profile_arn=" || set "instance_profile_arn=%instance_profile_arn%"

echo Enter Databricks assume role arn (%assume_role_arn%):
set /P "assume_role_arn=" || set "assume_role_arn=%assume_role_arn%"

echo instance_profile_arn=%instance_profile_arn%> %userprofile%\%databricks_profile%.databricks.config
echo assume_role_arn=%assume_role_arn%>> %userprofile%\%databricks_profile%.databricks.config

call :get_cluster_id %cluster_name%, cluster_id

if "%cluster_id%" == "" goto :create_cluster_cont

set /P c=Delete existing cluster %cluster_name% [Y/N]?
if /I "%c%" EQU "Y" goto :delete_cluster
if /I "%c%" EQU "N" goto :create_cluster_cont
goto :create_cluster_cont

:delete_cluster
@echo Deleting cluster with cluster-id %cluster_id% ...
databricks clusters permanent-delete --cluster-id %cluster_id% --profile %databricks_profile%
@echo

:create_cluster_cont
echo { > databricks_cluster.json
echo    "autoscale": { >> databricks_cluster.json
echo    "min_workers": 2, >> databricks_cluster.json
echo    "max_workers": 8 >> databricks_cluster.json
echo   }, >> databricks_cluster.json
echo "cluster_name": "%cluster_name%", >> databricks_cluster.json
echo "spark_version": "%spark_version%", >> databricks_cluster.json
if not "%assume_role_arn%" == "" (
echo "spark_conf": { >> databricks_cluster.json
echo   "spark.hadoop.fs.s3a.impl": "com.databricks.s3a.S3AFileSystem", >> databricks_cluster.json
echo   "spark.hadoop.fs.s3n.impl": "com.databricks.s3a.S3AFileSystem", >> databricks_cluster.json
echo   "spark.hadoop.fs.s3a.credentialsType": "AssumeRole", >> databricks_cluster.json
echo   "spark.hadoop.fs.s3a.stsAssumeRole.arn": "%assume_role_arn%", >> databricks_cluster.json
echo   "spark.hadoop.fs.s3.impl": "com.databricks.s3a.S3AFileSystem" >> databricks_cluster.json
echo }, >> databricks_cluster.json
)
if not "%databricks_profile%" == "DEV" (
echo  "spark_env_vars": { >> databricks_cluster.json
echo    "AWS_STS_REGIONAL_ENDPOINTS": "regional" >> databricks_cluster.json
echo  }, >> databricks_cluster.json
)
echo "aws_attributes": { >> databricks_cluster.json
echo   "zone_id": "eu-west-1b", >> databricks_cluster.json
echo   "instance_profile_arn": "%instance_profile_arn%" >> databricks_cluster.json
echo }, >> databricks_cluster.json
echo "node_type_id": "i3.2xlarge", >> databricks_cluster.json
echo "autotermination_minutes": 120, >> databricks_cluster.json
echo "driver_node_type_id": "i3.2xlarge", >> databricks_cluster.json
echo  "docker_image": { >> databricks_cluster.json
echo    "url": "%docker_username%/%image_name%:%tag%" >> databricks_cluster.json
echo  } >> databricks_cluster.json
echo } >> databricks_cluster.json

echo creating cluster %cluster_name%
databricks clusters create --json-file databricks_cluster.json --profile %databricks_profile%

del databricks_cluster.json

goto :exit

:get_cluster_id cluster_name, cluster_id
databricks clusters list --profile %databricks_profile% | findstr "%~1" > cluster.txt
set /p cluster_info=<cluster.txt
del cluster.txt
for /f "tokens=1 delims= " %%a in ("%cluster_info%") do (
  set %~2=%%a
)
exit /b 0

:exit