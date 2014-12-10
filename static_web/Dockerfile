# Version: 0.0.1 
FROM centos:centos6 
MAINTAINER Phil Windley <pjw@byu.edu>
ENV REFRESHED_AT 2014-11-07
RUN yum clean expire-cache
RUN yum update -y
RUN yum -y install which
RUN yum -y install git
RUN yum install -y httpd 
VOLUME ["/var/www/html"]

WORKDIR /var/www/html 
ENV APACHE_RUN_USER www-data 
ENV APACHE_RUN_GROUP www-data 
ENV APACHE_LOG_DIR /var/log/apache2 
ENV APACHE_PID_FILE /var/run/apache2.pid 
ENV APACHE_RUN_DIR /var/run/apache2 
ENV APACHE_LOCK_DIR /var/lock/apache2 
RUN mkdir -p $ APACHE_RUN_DIR $ APACHE_LOCK_DIR $ APACHE_LOG_DIR

EXPOSE 80

RUN service httpd start

CMD ["/usr/sbin/apachectl", "-D", "FOREGROUND"]
