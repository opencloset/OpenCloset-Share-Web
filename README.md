# OpenCloset-Share-Web #

https://share.theopencloset.net

## Dependencies ##

    $ cpanm --installdeps .
    $ npm install
    $ bower install

## Build Assets ##

    $ grunt    # requires `grunt-cli`

## Run ##

    $ ln -s share.conf.sample share.conf    # symlink config sample and customize it.
    $ MOJO_CONFIG=share.conf morbo ./script/share
