    $ grunt

v0.1.57

    $ grunt

v0.1.56

v0.1.55

    $ grunt

v0.1.54

v0.1.53

v0.1.52

v0.1.51

v0.1.50

v0.1.49

v0.1.48

v0.1.47

    # cd OpenCloset-Schema/
    $ mysql < db/alter/148-order-shipping-method.sql

    $ closetpan OpenCloset::Schema             # 0.060
    $ grunt

v0.1.46

    $ grunt

v0.1.45

v0.1.44

    $ closetpan OpenCloset::Common    # v0.1.11

v0.1.43

v0.1.42

v0.1.41

    $ grunt

v0.1.40

    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.31
    $ grunt

v0.1.39

v0.1.38

    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.30
    $ grunt

v0.1.37

v0.1.36

v0.1.35

    $ grunt

v0.1.34

    $ grunt

v0.1.33

    $ grunt

v0.1.32

v0.1.31

v0.1.31

    $ grunt

v0.1.30

    $ grunt

v0.1.29

v0.1.28

v0.1.27

    $ grunt

v0.1.26

v0.1.25

v0.1.24

v0.1.23

    $ grunt

v0.1.22

    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.28
    $ closetpan OpenCloset::Schema             # 0.059
    $ grunt

v0.1.21

v0.1.20

    $ grunt

v0.1.19

v0.1.18

v0.1.17

v0.1.16

v0.1.15

v0.1.14

v0.1.13

    $ grunt

v0.1.12

    $ mysql < db/alter/138-coupon-free-shipping.sql
    mysql> UPDATE coupon SET free_shipping = 1 WHERE `desc` = 'gunpo201801';
    $ closetpan OpenCloset::Schema             # 0.057
    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.27
    $ grunt

v0.1.11

v0.1.10

    $ grunt

v0.1.9

v0.1.8

v0.1.7

    $ cpanm WebService::Jandi::WebHook

v0.1.6

v0.1.5

    $ grunt

v0.1.4

v0.1.3

v0.1.2

    $ grunt
    $ closetpan OpenCloset::Common          # v0.1.5
    $ closetpan OpenCloset::Plugin::Helpers # v0.0.26

    # Add below to `share.conf`
    redis_url => $ENV{OPENCLOSET_REDIS_URL} || 'redis://localhost:6379',

v0.1.1

    $ grunt
    $ closetpan OpenCloset::Common    # v0.1.3

v0.1.0

v0.0.26

v0.0.25

    $ grunt

v0.0.24

    $ grunt

v0.0.23

    $ grunt

v0.0.22

    $ grunt

v0.0.21

v0.0.20

    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.21
    $ grunt

v0.0.19

    $ grunt

v0.0.17

    $ grunt

v0.0.16

    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.19
    $ grunt
    $ closetpan OpenCloset::Schema             # 0.051

v0.0.15

    $ grunt

v0.0.14

    $ cpanm --installdeps .    # Text::CSV

v0.0.13

    $ grunt

v0.0.12

    $ grunt

v0.0.11

    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.16
    $ grunt

v0.0.10

    $ closetpan OpenCloset::Common    # v0.0.16

v0.0.6

    $ grunt
    $ closetpan OpenCloset::Size::Guess::DB    # 0.007

v0.0.4

    $ cpanm Parcel::Track::KR::CJKorea      # 0.005
    $ closetpan OpenCloset::Plugin::Helpers # v0.0.14
    $ closetpan OpenCloset::Size::Guess::DB # 0.006
    $ grunt
