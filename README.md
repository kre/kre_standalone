
*This is still under development and not yet ready for use. I.e. it doesn't work.*

## Standalone KRE in Docker

KRE is difficult to install, relying on a number of outside packages and hundreds of Perl modules running in an Apache Web server being used as an application server along side a Mongo database and relying on Memcache and other services. 

Docker to the rescue.

This repository contains the Dockerfiles and source repositories for building a series of Docker images that result in an image for a standalone KRE image that can be run as a Docker container.

## Design Decisions

- the actual application is located in an external volume to facilitate updating and developing KRE using this container. A production version of the container might choose to have the code inside the image.
- this is not a standalone KRE image since it also require MongoDB to run. [Instructions on setting up and using a MongoDB](docs/setting_up_mongodb.md) for use with KRE are included. 

## Manifest

The final docker image is built from a series of previous builds. Here's what's what:

- **base00** &mdash; build minimal server from centos6 image
- **apache00** &mdash; install Apache HTTPD, mod_perl, and other Web-related packages
- **memcachedb00** &mdash; install memcachedb and supporting files
- **kre00** &mdash; install Perl packages
- **kre01** &mdash; build with final configuration

These images build on each other in the order shown. 

The following are not used and can be ignored

- **mongo00**

## Use

1. Build all the images in the Manifest above in the order shown. There's a ```build``` executable in each directory that should do this.

2. Clone the KRE code to the ```kre01``` directory using this command:


        https://github.com/kre/Kinetic-Rules-Engine.git

3. Create the ```kre_config``` directory and install the configuration files (yeah, we need more here)

4. Create the ```logs``` directory.

5. Run

        chown -R 2000:2000 Kinetic-Rules-Engine kre_config logs

    so that they have the same ownership as the ```web``` user and group in the container. 

5. The ```run``` script in the ```kre01``` directory should start KRE. 



## Acknowledgements

Mark Horstmeier wrote a [set of KRE Installation scripts](https://github.com/solargroovy/krl_install). Some of Mark's work was used to create the Docker images. 
