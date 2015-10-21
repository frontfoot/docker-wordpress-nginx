#docker-wordpress-nginx

A Dockerfile that installs the latest wordpress, nginx, php-apc and php-fpm.

## Installation

The easiest way to get this docker image installed is to pull the latest version
from the Docker registry:

If you'd like to build the image yourself then:

```bash
$ git clone git@github.com:frontfoot/docker-wordpress-nginx.git
$ cd docker-wordpress-nginx
$ sudo docker build -t="frontfoot/docker-wordpress-nginx" .
```

## Usage

To spawn a new instance of wordpress on port 80.  The -p 80:80 maps the internal docker port 80 to the outside port 80 of the host machine.

```bash
$ sudo docker run -p 80:80 --name docker-wordpress-nginx -d frontfoot/docker-wordpress-nginx
```

Start your newly created docker.

```
$ sudo docker start docker-wordpress-nginx
```

After starting the docker-wordpress-nginx check to see if it started and the port mapping is correct.  This will also report the port mapping between the docker container and the host machine.

```
$ sudo docker ps

0.0.0.0:80 -> 80/tcp docker-wordpress-nginx
```

You can the visit the following URL in a browser on your host machine to get started:

```
http://127.0.0.1:80
```
