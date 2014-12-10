# Version: 0.0.1 
# install all the perl libraries needed by KRE
FROM windley/memcachedb00
MAINTAINER Phil Windley <pjw@byu.edu>
ENV REFRESHED_AT 2014-11-14-1


RUN yum -y install \
                    java-1.6.0-openjdk \
	            java-1.6.0-openjdk-devel \
	            "perl(Carp)" \
                    "perl(Crypt::OpenSSL::RSA)" \
		    "perl(Crypt::OpenSSL::X509)" \
		    "perl(File::Temp)" \
		    "perl(Parallel::ForkManager)" \
		    "perl(AnyEvent)" \
		    "perl(AnyEvent::HTTP)" \
		    "perl(Apache2::RequestRec)" \
		    "perl(Apache::DBI)" \
		    "perl(Apache::Session::DB_File)" \
		    "perl(APR::Table)" \
		    "perl(Bundle::Apache2)" \
		    "perl(Cache::Memcached)" \
		    "perl(CGI)" \
		    "perl(CPAN)" \
		    "perl(Clone)" \
		    "perl(Compress::Zlib)" \
		    "perl(Crypt::RC4::XS)" \
		    "perl(Crypt::SSLeay)" \
		    "perl(Data::Dumper)" \
		    "perl(Data::ICal)" \
		    "perl(Data::UUID)" \
		    "perl(DateTime)" \
		    "perl(DateTime::Format::ISO8601)" \
		    "perl(DateTime::Format::RFC3339)" \
		    "perl(DateTime::Format::HTTP)" \
		    "perl(DateTime::Format::Mail)" \
		    "perl(Digest::MD5)" \
		    "perl(Digest::SHA)" \
		    "perl(Email::MIME)" \
		    "perl(Email::Simple)" \
		    "perl(ExtUtils::XSBuilder)" \
		    "perl(File::Find::Rule)" \
		    "perl(Geo::IP)" \
		    "perl(Getopt::Std)" \
		    "perl(HTML::Template)" \
		    "perl(Inline)" \
		    "perl(JavaScript::Minifier)" \
		    "perl(JSON::XS)" \
		    "perl(JSON::PP)" \
		    "perl(Log::Dispatch::File)" \
		    "perl(Log::Dispatch::Screen)" \
		    "perl(Log::Log4perl)" \
		    "perl(List::Util)" \
		    "perl(List::MoreUtils)" \
		    "perl(LWP)" \
		    "perl(LWP::Simple)" \
		    "perl(ModPerl::Registry)" \
		    "perl(ModPerl::Util)" \
		    "perl(Net::SSLeay)" \
		    "perl(Net::Twitter::Lite)" \
		    "perl(Proc::Daemon)" \
		    "perl(Proc::PID::File)" \
		    "perl(Scalar::Util)" \
		    "perl(Schedule::Cron::Events)" \
		    "perl(Sys::Hostname)" \
		    "perl(Test::Exception)" \
		    "perl(Test::LongString)" \
		    "perl(Test::MockObject)" \
		    "perl(Test::More)" \
		    "perl(Test::WWW::Selenium)" \
		    "perl(Text::CSV)" \
		    "perl(URI)" \
		    "perl(URI::Escape)" \
		    "perl(YAML::XS)" \
		    "perl(Test::WWW::Mechanize)" \
                    "perl(WWW::Mechanize)" \
		    "perl(XML::LibXML)" \	
		    "perl(XML::XPath)" 

ENV JAVA_HOME /usr/lib/jvm/java-1.6.0-openjdk.x86_64

# order matters below, --notest for Apache::Session::Memcached which requires running memcached (and faster)
# version 8 of Data::ICal::DateTime is broken, so we get 7 explicity
RUN cpanm --notest \
          Amazon::S3 \
	  JSON::PP \
          Apache2::xForwardedFor \
	  Apache::Session::Memcached \
	  Data::Diver \
	  http://search.cpan.org/CPAN/authors/id/S/SI/SIMONW/Data-ICal-DateTime-0.7.tar.gz \
	  DateTime::Event::Cron \
	  Devel::Size \
	  Geo::StreetAddress::US \
	  HTML::ParseBrowser \
	  HTML::Query \
	  Inline::Java \
	  IPC::Lock::Memcached \
          Net::SSLeay \
	  Math::Combinatorics \
	  Math::Round \
	  MIME::Entity \
	  MIME::QuotedPrint::Perl \
	  Mobile::UserAgent \
	  MongoDB \
	  Net::OAuth::Simple \
	  Net::SMTP::Server::Client \
	  Net::SMTP::TLS \
	  Schedule::Cron \
	  XDI \
	  XML::XML2JSON 

# the SendGrid module on CPAN is NOT the same as this one. 
COPY dist/src/SendGrid-1.0.tar.gz /web/src/SendGrid-1.0.tar.gz
RUN mkdir -p /web/src; \
    cd /web/src; \
    /bin/rm -rf /web/src/SendGrid-1.0; \
    tar xzf SendGrid-1.0.tar.gz; \
    cd /web/src/SendGrid-1.0; \
    perl Makefile.PL && make && make install
