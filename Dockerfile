FROM databricksruntime/standard:latest
ARG SCALA_VERSION
# update ubuntu
RUN apt-get update \
    && apt-get install -y \
        build-essential \
        python3-dev \
    && apt-get clean
ADD ./target/$SCALA_VERSION/*.jar /databricks/jars/
ADD ./lib/*.jar /databricks/jars/
ADD ./lib/jars/*.jar  /databricks/jars/

# clean up
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*