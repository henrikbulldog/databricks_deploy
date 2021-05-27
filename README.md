# README #
Windows command scripts to deploy a Scala project to a Databricks cluster.
# Prerequisites
- Docker must be installed (https://docs.docker.com/docker-for-windows/install/)
- You must be logged in to a Docker repo (docker login)
- Python must be installed (https://www.python.org/ftp/python/3.6.4/python-3.6.4.exe)
- Databricks cli must be installed (pip install databricks-cli)
- Databricks cli must be configured (databricks configure)
- If you are using STS assume roles to access AWS S3 buckets from Databricks, you need the ARN of instance profile role and the assume role (1 time per profile)
# Usage
- Go to the root folder of your project.
- Run databricks_deploy.bat and follow instructions
- If you need to add Maven refernces the cluster, 
  - Add lines to databricks_libraries_install.bat after the label :upload_libs
  - Run databricks_libraries_install.bat
# Planned Work
Create a unix shell version of the Windows scripts (when I get around to it).