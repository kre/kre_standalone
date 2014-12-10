# Version: 0.0.1 
# get ready for code
FROM windley/kre01
MAINTAINER Phil Windley <pjw@byu.edu>
ENV REFRESHED_AT 2014-11-24

COPY dist/apps/httpd.sysconfig /etc/sysconfig/httpd
COPY dist/apps/startup /web/bin/startup
COPY dist/htdocs /web/htdocs
VOLUME ["/web/etc", "/web/lib/perl", "/web/logs"]

ENV KOBJ_ROOT /web/lib/perl

EXPOSE 80

#CMD ["/usr/sbin/apachectl", "-D", "FOREGROUND"]
CMD ["/web/bin/startup"]

