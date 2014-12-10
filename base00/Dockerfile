# Version: 0.0.1 
FROM centos:centos6 
MAINTAINER Phil Windley <pjw@byu.edu>
ENV REFRESHED_AT 2014-11-11-1

ADD dist/apps/yum.conf /etc/yum.conf

RUN yum clean expire-cache
RUN yum update -y
RUN yum -y install which sudo wget tar gzip make gcc expat zlib-devel expat-devel apr apr-util apr-devel cronie htop git words; yum clean all


ADD dist/apps/crontab /etc/crontab
ADD dist/apps/sshd_config /etc/ssh/sshd_config
# ADD dist/apps/sudoers /etc/sudoers # do in web version
