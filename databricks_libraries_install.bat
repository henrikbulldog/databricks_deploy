@echo off
setlocal
echo Installs libraries (Maven references) on a Databricks cluster.
echo Prerequisites:
echo - Databricks cli must be installed (pip install databricks-cli)
echo - Databricks cli must be configured (databricks configure)

for %%f in (%cd%) do set image_name=%%~nxf

:create_cluster
echo Enter Cluster name (%username%/%image_name%):
set /P "cluster_name=" || set "cluster_name=%username%/%image_name%"

echo Enter Databricks workspace profile (default):
set /P "databricks_profile=" || set "databricks_profile=default"

call :get_cluster_id %cluster_name%, cluster_id

if "%cluster_id%" == "" (
  echo Cluster %cluster_name% not found
  goto :exit
)

set /P c=Upload Libraries to Databricks cluster [Y/N]?
if /I "%c%" EQU "Y" goto :upload_libs
if /I "%c%" EQU "N" goto :exit
goto :exit

:upload_libs

databricks libraries install --maven-coordinates com.amazonaws:aws-encryption-sdk-java:1.3.6 --cluster-id %cluster_id% --profile %databricks_profile%
databricks libraries install --maven-coordinates io.spray:spray-json_2.12:1.3.6 --cluster-id %cluster_id% --profile %databricks_profile%
databricks libraries install --maven-coordinates org.scalaj:scalaj-http_2.12:2.3.0 --cluster-id %cluster_id% --profile %databricks_profile%

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