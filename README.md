# OpenCloset-Share-Web #

https://share.theopencloset.net

## VERSION ##

v0.0.3

## Dependencies ##

    $ cpanm --installdeps .
    $ npm install
    $ bower install

## Build Assets ##

    $ grunt    # requires `grunt-cli`

## Run ##

    $ cp share.conf.sample share.conf    # copy config sample and customize it.
    $ MOJO_CONFIG=share.conf morbo ./script/share
