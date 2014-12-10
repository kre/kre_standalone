# Version: 0.0.1 
FROM custom/base00
MAINTAINER Phil Windley <pjw@byu.edu>
ENV REFRESHED_AT 2014-11-12

RUN groupadd web -g 500; useradd web -d /web -m -u 500 -g 500 -s /bin/bash 
RUN for f in /web/etc /web/bin /var/lock/sessions; do /bin/mkdir $f; /bin/chown 500:500 $f; done
ADD dist/apps/web.bashrc /web/.bashrc
ADD dist/apps/ld.so.conf /etc/ld.so.conf
ADD dist/apps/sudoers /etc/sudoers 
ADD dist/apps/httpd.init.d /etc/init.d/httpd

RUN yum -y install \
              httpd \
	      cronolog \
	      mod_perl \
	      httpd-devel \
	      perl-libapreq2 \
	      mod_perl-devel \
	      cpanminus \
	      openssl-devel ; \
    curl -L http://cpanmin.us | perl - --self-upgrade ; \
    /sbin/ldconfig; \
    chmod 755 /etc/init.d/httpd


