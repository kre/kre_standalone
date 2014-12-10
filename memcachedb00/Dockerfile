# Version: 0.0.1 
# install memcached and memvachedb for use by KRE
FROM windley/apache00
MAINTAINER Phil Windley <pjw@byu.edu>
ENV REFRESHED_AT 2014-11-14

run yum -y install \
             libevent \
	     libevent-devel \
	     memcached \
	     db4


# memcached
COPY dist/apps/memcached /etc/sysconfig/memcached

#memcachedb
COPY dist/apps/memcachedb /etc/init.d/memcachedb
