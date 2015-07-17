# Version: 0.0.1 
# install mongo db
FROM windley/kre00
MAINTAINER Phil Windley <pjw@byu.edu>
ENV REFRESHED_AT 2014-11-14

RUN yum install -y mongodb-org; \
    mkdir -p /var/lib/mongo; \
    chown mongod:mongod /var/lib/mongo

COPY dist/apps/mongod.conf /etc/mongod.conf

# the distributed mongod doesn't work, this fixes is per
#  http://stackoverflow.com/questions/26594612/dirname-missing-operand-error-while-starting-mongod-service/27051453#27051453
COPY dist/apps/mongod /etc/init.d/mongod

# This has to match location given in mongod.conf above
VOLUME ["/var/lib/mongo"]
