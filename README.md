
*This is still under development and not yet ready for use. I.e. it doesn't work.*

## Standlone KRE in Docker

KRE is difficult to install, relying on a number of outside packages and hundreds of Perl modules running in an Apache Web server being used as an application server along side a Mongo database and relying on Memcache and other services. 

Docker to the rescue.

This repository contains the Dockerfiles and source repositories for building a series of Docker images that result in an image for a standalone KRE image that can be run as a Docker container.

## Design Decisions

- the actual application is located in an external volume to facilitate updating and developing KRE using this container. A production version of the container might choose to have the code inside the image.
- this is a standalong KRE image. The Apache application server and Mondo DB are running in the same container. This is useful for development and simple installations, but unlikely to meet the demands of a production site. 

## Use

...*To be written*...
