# OpenCloset-Share-Web #

[![Build Status](https://travis-ci.org/opencloset/monitor.svg?branch=v0.1.61)](https://travis-ci.org/opencloset/OpenCloset-Share-Web)

https://share.theopencloset.net

## VERSION ##

v0.1.61

## Dependencies ##

    $ cpanm --installdeps .
    $ npm install
    $ bower install

## Build Assets ##

    $ grunt    # requires `grunt-cli`

## Run ##

    $ cp share.conf.sample share.conf    # copy config sample and customize it.
    $ MOJO_CONFIG=share.conf morbo ./script/share

## Build docker file ##

    $ docker build -f Dockerfile -t opencloset/share .
    $ docker build -f Dockerfile.returning2returned -t opencloset/share/returning2returned .
    $ docker build -f Dockerfile.shipped2delivered -t opencloset/share/shipped2delivered .
