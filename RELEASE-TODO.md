
    $ mysql < OpenCloset-Schema/db/alter/111-user-address-name-phone.sql
    $ mysql < OpenCloset-Schema/db/alter/110-order-shipping-misc.sql
    $ mysql < OpenCloset-Schema/db/alter/114-user-info-jacket-skirt-size.sql
    $ closetpan OpenCloset::Schema OpenCloset::Common
    $ bower install
    $ grunt
