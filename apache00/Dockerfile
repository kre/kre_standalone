# Version: 0.0.1 
FROM custom/base00
MAINTAINER Phil Windley <pjw@byu.edu>
ENV REFRESHED_AT 2015-07-16-01

# picking gid and uid of 2000 in hopes it is clear on the host too; mounted volumes owned by 2000
RUN groupadd web -g 2000; useradd web -d /web -m -u 2000 -g 2000 -s /bin/bash 
RUN for f in /web/etc /web/bin /var/lock/sessions; do /bin/mkdir $f; /bin/chown 2000:2000 $f; done
ADD dist/apps/web.bashrc /web/.bashrc
ADD dist/apps/ld.so.conf /etc/ld.so.conf
ADD dist/apps/sudoers /etc/sudoers 

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
    /sbin/ldconfig
    

ADD dist/apps/httpd.init.d /etc/init.d/httpd
RUN chmod 755 /etc/init.d/httpd

