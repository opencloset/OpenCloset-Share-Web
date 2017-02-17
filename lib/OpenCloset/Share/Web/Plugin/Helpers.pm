package OpenCloset::Share::Web::Plugin::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

use DateTime;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Encode qw/encode_utf8/;
use HTTP::Tiny;
use Mojo::ByteStream;
use Mojo::JSON qw/decode_json/;
use String::Random;
use Time::HiRes;

use OpenCloset::Schema;
use OpenCloset::Constants qw/$DEFAULT_RENTAL_PERIOD $SHIPPING_BUFFER/;
use OpenCloset::Constants::Category qw/$JACKET $PANTS $TIE %PRICE/;
use OpenCloset::Constants::Status
    qw/$RENTABLE $RENTAL $RENTALESS $LOST $DISCARD $CHOOSE_CLOTHES $CHOOSE_ADDRESS $PAYMENT $PAYMENT_DONE $WAITING_SHIPPED $SHIPPED $RETURNED $PARTIAL_RETURNED $DELIVERED $WAITING_DEPOSIT/;
use OpenCloset::Constants::Measurement;

=encoding utf8

=head1 NAME

OpenCloset::Share::Web::Plugin::Helpers - opencloset share web mojo helper

=head1 SYNOPSIS

    # Mojolicious::Lite
    plugin 'OpenCloset::Share::Web::Plugin::Helpers';

    # Mojolicious
    $self->plugin('OpenCloset::Share::Web::Plugin::Helpers');

=cut

sub register {
    my ( $self, $app, $conf ) = @_;

    $app->helper( agent                => \&agent );
    $app->helper( current_user         => \&current_user );
    $app->helper( is_success           => \&is_success );
    $app->helper( trim_code            => \&trim_code );
    $app->helper( clothes2desc         => \&clothes2desc );
    $app->helper( clothes2status       => \&clothes2status );
    $app->helper( clothes_measurements => \&clothes_measurements );
    $app->helper( order2link           => \&order2link );
    $app->helper( timezone             => \&timezone );
    $app->helper( payment_done         => \&payment_done );
    $app->helper( waiting_deposit      => \&waiting_deposit );
    $app->helper( waiting_shipped      => \&waiting_shipped );
    $app->helper( returned             => \&returned );
    $app->helper( partial_returned     => \&partial_returned );
    $app->helper( admin_auth           => \&admin_auth );
    $app->helper( status2label         => \&status2label );
    $app->helper( update_parcel_status => \&update_parcel_status );
    $app->helper( categories           => \&categories );
    $app->helper( shirt_type           => \&shirt_type );
    $app->helper( blouse_type          => \&blouse_type );
    $app->helper( send_mail            => \&send_mail );
    $app->helper( check_measurement    => \&check_measurement );
    $app->helper( category_price       => \&category_price );
    $app->helper( merchant_uid         => \&merchant_uid );
    $app->helper( formatted            => \&formatted );
    $app->helper( date_calc            => \&date_calc );
    $app->helper( payment_deadline     => \&payment_deadline );
}

=head1 HELPERS

=head2 agent

    my $agent = $self->agent;    # HTTP::Tiny object
    my $res   = $agent->get('https://staff.theopencloset.net/api/user/30000');

=cut

sub agent {
    my $self = shift;

    my $agent  = __PACKAGE__;
    my $cookie = $self->cookie('opencloset');

    unless ($cookie) {
        $self->log->error('Not found cookie: opencloset');
        return;
    }

    my $http = HTTP::Tiny->new(
        default_headers => {
            agent  => $agent,
            cookie => "opencloset=$cookie",
            accept => 'application/json',
        }
    );

    return $http;
}

=head2 current_user

    my $user = $self->current_user;

=cut

sub current_user {
    my $self = shift;

    my $id = $self->session('access_token');
    unless ($id) {
        $self->log->error('Not found session: access_token');
        return;
    }

    my $user = $self->schema->resultset('User')->find( { id => $id } );
    unless ($user) {
        $self->log->error("Not found user: $id");
        return;
    }

    return $user;
}

=head2 is_success

print error log unless C<$res->{success}>

    my $res = $agent->get('somewhere');
    return $self->error(xxx, 'blahblah') unless $self->is_success($res);

    # do something

=cut

sub is_success {
    my ( $self, $res ) = @_;
    return unless $res;
    return $res if $res->{success};

    my $url     = $res->{url};
    my $content = decode_json( $res->{content} );
    my $error   = $content->{error};
    $self->log->error("Failed to request $url: $error");
    return;
}

=head2 trim_code

trim clothes code

    % trim_code('0J001')
    # J001

=cut

sub trim_code {
    my ( $self, $clothes_or_code ) = @_;
    return '' unless $clothes_or_code;

    my $code;
    if ( ref $clothes_or_code ) {
        $code = $clothes_or_code->code;
    }
    else {
        $code = $clothes_or_code;
    }

    $code =~ s/^0//;
    return $code;
}

=head2 clothes2desc

    % clothes2desc($clothes)
    # 가슴 99 / 허리 88 black

Support only a suit of top bottom set.

=cut

sub clothes2desc {
    my ( $self, $clothes ) = @_;
    return '' unless $clothes;

    my $top    = $clothes->top;
    my $bottom = $clothes->bottom;

    return '' unless $top;
    return '' unless $bottom;

    my $bust  = $top->bust      || 'Unknown';
    my $waist = $bottom->waist  || 'Unknown';
    my $color = $clothes->color || 'Unknown';

    return sprintf "가슴 %s / 허리 %s %s", $bust, $waist, $color;
}

=head2 clothes2status

    % clothes2status($clothes)
    # <span class="label label-primary">
    #   J001
    #   <small>대여가능</small>
    # </span>

=cut

sub clothes2status {
    my ( $self, $clothes ) = @_;
    return '' unless $clothes;

    my $dom  = Mojo::DOM::HTML->new;
    my $code = $clothes->code =~ s/^0//r;

    my $status    = $clothes->status;
    my $name      = $status->name;
    my $status_id = $status->id;

    my @class = qw/label/;
    if ( $status_id == $RENTABLE || $status_id == $WAITING_SHIPPED ) {
        push @class, 'label-success';
    }
    elsif ( $status_id == $RENTAL || $status_id == $RENTALESS || $status_id == $LOST || $status_id == $DISCARD ) {
        push @class, 'label-danger';
    }
    else {
        push @class, 'label-default';
    }

    my $html = qq{<span class="@class">$code <small>$name</small></span>};

    $dom->parse($html);
    my $tree = $dom->tree;
    return Mojo::ByteStream->new( Mojo::DOM::HTML::_render($tree) );
}

=head2 clothes_measurements

    my @measurements = $self->clothes_measurements($clothes);
    # ('가슴둘레' => 90, '허리둘레' => 80, ...);

=cut

sub clothes_measurements {
    my ( $self, $clothes ) = @_;
    return unless $clothes;

    my @parts = ( $COLOR, $GENDER, $NECK, $BUST, $WAIST, $HIP, $TOPBELLY, $BELLY, $ARM, $THIGH, $LENGTH, $CUFF );

    my @sizes;
    for my $part (@parts) {
        my $size = $part eq $CUFF ? $clothes->cuff : $clothes->get_column($part);
        next unless $size;
        my $label = $OpenCloset::Constants::Measurement::LABEL_MAP{$part} || $part;
        push @sizes, $label, $size;
    }

    return @sizes;
}

=head2 order2link

    % order2link($order, @class)
    # <a href="/order/35155" class="btn btn-link">
    #   2016-08-01
    #   <small>결제대기</small>
    # </a>

=cut

sub order2link {
    my ( $self, $order, @class ) = @_;
    return '' unless $order;

    push @class, 'btn btn-link' unless @class;

    my $order_id  = $order->id;
    my $status_id = $order->status_id;
    my $ymd       = $order->create_date->ymd;
    my $dom       = Mojo::DOM::HTML->new;

    my $status = $OpenCloset::Constants::Status::LABEL_MAP{$status_id} || 'Unknown';
    my $html = qq{<a href="/order/$order_id" class="@class">
  $ymd
  <small>$status</small>
</a>};
    $dom->parse($html);
    my $tree = $dom->tree;
    return Mojo::ByteStream->new( Mojo::DOM::HTML::_render($tree) );
}

=head2 timezone

    % $order->create_date->hms    # 06:56:43
    % timezone($order->create_date);
    % $order->create_date->hms    # 15:56:43

=cut

sub timezone {
    my ( $self, $dt ) = @_;
    my $tz = $self->config->{timezone};

    return $tz unless $dt;
    return $dt unless $tz;

    ## when you create DateTime object without time zone specified, "floating" time zone is set
    ## first call of set_time_zone change time zone to UTC without conversion
    ## second call of set_time_zone change UTC to $timezone
    $dt->set_time_zone('UTC');
    $dt->set_time_zone($tz);
    return $dt;
}

=head2 payment_done($order)

    # 결제대기 -> 결제완료
    $self->payment_done($order);

선택했던 의류가 있는지 확인하고, 이에 따라 주문서와 의류의 상태를 변경함

=cut

sub payment_done {
    my ( $self, $order ) = @_;
    return unless $order;
    return $order if $order->status_id == $PAYMENT_DONE;

    my $user      = $order->user;
    my $user_info = $user->user_info;
    my $msg       = $self->render_to_string(
        'sms/payment/payment_done',
        format => 'txt',
        order  => $order,
        user   => $user,
    );

    chomp $msg;
    $self->sms( $user_info->phone, $msg );

    $order->update( { status_id => $PAYMENT_DONE } );
    $order->find_or_create_related( 'order_parcel', { status_id => $PAYMENT_DONE } );
    my $detail = $order->order_details( { name => 'jacket' } )->next;

    ## 선택한 의류가 있는지 확인
    return $order unless $detail;
    return $order unless $detail->clothes_code;

    ## 의류의 상태를 확인
    my $jacket = $detail->clothes;
    unless ($jacket) {
        $self->log->error( "Couldn't find a clothes: " . $detail->clothes_code );
        return $order;
    }

    return $order;
}

=head2 waiting_deposit($order)

    # 결제대기 -> 입금대기
    $self->waiting_deposit($order, $payment_log?);

=cut

sub waiting_deposit {
    my ( $self, $order, $payment_log ) = @_;
    return unless $order;
    return $order if $order->status_id == $WAITING_DEPOSIT;

    $order->update( { status_id => $WAITING_DEPOSIT } );

    $payment_log ||= $order->payments->search_related( 'payment_logs', { status => 'ready' }, { rows => 1 } )->single;

    unless ($payment_log) {
        $self->log->error("Not found ready status payment log");
        return $order;
    }

    my $detail = $payment_log->detail;
    unless ($detail) {
        $self->log->error("Not found payment info");
        return $order;
    }

    my $payment_info = decode_json( encode_utf8($detail) );
    my $epoch        = $payment_info->{response}{vbank_date};
    unless ($epoch) {
        $self->log->error("Wrong payment info: $detail");
        $self->log->error("Couldn't find vbank due date.");
        return $order;
    }

    my $user      = $order->user;
    my $user_info = $user->user_info;
    my $tz        = $self->config->{timezone};
    my $due       = DateTime->from_epoch( epoch => $epoch, time_zone => $tz );
    my $msg       = $self->render_to_string(
        'sms/payment/waiting_deposit',
        format       => 'txt',
        order        => $order,
        user         => $user,
        due          => $due,
        payment_info => $payment_info
    );

    chomp $msg;
    $self->sms( $user_info->phone, $msg );

    return $order;
}

=head2 waiting_shipped($order, $codes)

    # 결제완료 -> 발송대기
    $self->waiting_shipped($order, ['J001', 'P001']);

선택했던 의류가 있는지 확인하고, 이에 따라 주문서와 의류의 상태를 변경함

=cut

sub waiting_shipped {
    my ( $self, $order, $codes ) = @_;
    return unless $order;

    ## $WAITING_SHIPPED
    ## 1. $codes 에 선택했던 의류가 잇는지 확인
    ## 2. 주문서와 의류 모두 상태를 변경

    ## 대여자가 선택한 의류가 대여품목에 있는지 확인
    map { $_ = sprintf( '%05s', $_ ) } @$codes;
    my $detail = $order->order_details( { name => 'jacket' } )->next;
    if ($detail) {
        if ( my $code = $detail->clothes_code ) {
            my $found = grep { /$code/ } @$codes;
            unless ($found) {
                ## 없으면 알려만 주고 계속해서 진행
                my $msg = "대여자가 선택한 의류가 대여품목에 없습니다: $code";
                $self->log->info($msg);
                $self->flash( alert => $msg );

                ## 희망의류를 desc 에 기록
                my $jacket = $detail->clothes;
                my $status = $jacket->status->name;
                $detail->update( { desc => sprintf( "희망의류: %s, 상태: %s", $code, $status ) } );
            }
        }
    }

    ## 대여품목과 주문서품목을 비교확인
    my @clothes = $self->schema->resultset('Clothes')->search( { code => { -in => $codes } } );
    my @details = $order->order_details;

    my ( %source, %target );
    for my $detail (@details) {
        my $name = $detail->name;
        next unless $name =~ m/^[a-z]/; # 배송비 예외처리
        $source{$name} = $detail;
    }

    for my $clothes (@clothes) {
        my $category = $clothes->category;
        $target{$category} = $clothes;
    }

    my @source = sort keys %source;
    my @target = sort keys %target;

    if ( "@source" ne "@target" ) {
        ## 일치하지 않으면 진행하면 아니됨
        my $msg = "주문서 품목과 대여품목이 일치하지 않습니다.";
        $self->log->error($msg);
        $self->log->error("주문서품목: @source");
        $self->log->error("대여품목: @target");
        $self->flash( alert => $msg );
        return;
    }

    my $guard = $self->schema->txn_scope_guard;
    for my $category ( keys %source ) {
        my $detail  = $source{$category};
        my $clothes = $target{$category};

        my $name = join( ' - ', $self->trim_code( $clothes->code ), $OpenCloset::Constants::Category::LABEL_MAP{$category} );
        $detail->update(
            {
                name         => $name,
                status_id    => $RENTAL,
                clothes_code => $clothes->code,
            }
        );
        $clothes->update( { status_id => $RENTAL } );
    }

    $order->update( { status_id => $RENTAL } );
    $self->update_parcel_status( $order, $WAITING_SHIPPED );
    $guard->commit;

    return $order;
}

=head2 returned

=cut

sub returned {
    my ( $self, $order ) = @_;
    return unless $order;

    my $guard = $self->schema->txn_scope_guard;
    my $details = $order->order_details( { clothes_code => { '!=' => undef } } );
    while ( my $detail = $details->next ) {
        my $clothes = $detail->clothes;
        $clothes->update( { status_id => $RETURNED } );
        $detail->update( { status_id => $RETURNED } );
    }

    $order->update( { status_id => $RETURNED } );
    $self->update_parcel_status( $order, $RETURNED );
    $guard->commit;

    return $order;
}

=head2 partial_returned

=cut

sub partial_returned {
    my $self = shift;
}

=head2 admin_auth

    return unless $self->admin_auth;

=cut

sub admin_auth {
    my $self      = shift;
    my $user_info = $self->stash('user_info');
    return unless $user_info;

    if ( $user_info->staff != 1 ) {
        $self->error( 400, "Permission denied" );
        return;
    }

    return 1;
}

=head2 status2label($status, $active)

    %= status2label($order->status);
    # <span class="label label-default status-accept">승인</span>
    # <span class="label label-default status-accept active">$str</span>    # $active is true

=cut

sub status2label {
    my ( $self, $status, $active ) = @_;

    my ( $name, $id );
    if ( ref $status ) {
        $name = $status->name;
        $id   = $status->id;
    }
    else {
        $id   = $status;
        $name = $OpenCloset::Constants::Status::LABEL_MAP{$id};
    }

    my $html = Mojo::DOM::HTML->new;

    if ($active) {
        $html->parse(qq{<span class="label label-success active status-$id" title="$name" data-status="$id">$name</span>});
    }
    else {
        $html->parse(qq{<span class="label label-default status-$id" title="$name" data-status="$id">$name</span>});
    }

    my $tree = $html->tree;
    return Mojo::ByteStream->new( Mojo::DOM::HTML::_render($tree) );
}

=head2 update_parcel_status($order, $to)

    $self->update_parcel_status($order, $SHIPPED);

=cut

sub update_parcel_status {
    my ( $self, $order, $to ) = @_;
    return unless $order;
    return unless $to;

    my $parcel    = $order->order_parcel;
    my $from      = $parcel->status_id;
    my $user      = $order->user;
    my $user_info = $user->user_info;
    $parcel->update( { status_id => $to } );

    if ( $from == $WAITING_SHIPPED && $to == $SHIPPED ) {
        ## 발송대기 -> 배송중
        my $pos  = 0;
        my $mask = $parcel->sms_bitmask;
        my $sent = $mask & 2**$pos;
        unless ($sent) {
            my $msg = $self->render_to_string( 'sms/waiting_shipped2shipped', format => 'txt', order => $order );
            chomp $msg;
            $self->sms( $user_info->phone, $msg );
            $parcel->update( { sms_bitmask => $mask | 2**$pos } );
        }
    }
    elsif ( $from == $SHIPPED && $to == $DELIVERED ) {
        ## 배송중 -> 배송완료
        my $pos  = 1;
        my $mask = $parcel->sms_bitmask;
        my $sent = $mask & 2**$pos;
        unless ($sent) {
            my $msg = $self->render_to_string( 'sms/shipped2delivered', format => 'txt', order => $order );
            chomp $msg;
            $self->sms( $user_info->phone, $msg );
            $parcel->update( { sms_bitmask => $mask | 2**$pos } );
        }
    }

    return 1;
}

=head2 categories($order)

    % my @categories = categories($order)

=cut

sub categories {
    my ( $self, $order ) = @_;
    return unless $order;

    my @categories;
    my $status_id = $order->status_id;
    if ( "$CHOOSE_CLOTHES $CHOOSE_ADDRESS $PAYMENT $PAYMENT_DONE $WAITING_DEPOSIT" =~ m/\b$status_id\b/ ) {
        my $details = $order->order_details;
        while ( my $detail = $details->next ) {
            my $name = $detail->name;
            next unless $name =~ m/^[a-z]/;
            push @categories, $detail->name;
        }
    }
    else {
        my $details = $order->order_details( { clothes_code => { '!=' => undef } } );
        while ( my $detail = $details->next ) {
            push @categories, $detail->clothes->category;
        }
    }

    return @categories;
}

=head2 shirt_type($order)

    % my $type = shirt_type($order);
    # 하늘색

=cut

sub shirt_type {
    my ( $self, $order ) = @_;
    return unless $order;

    my $type      = '';
    my $status_id = $order->status_id;
    if ( "$CHOOSE_CLOTHES $CHOOSE_ADDRESS $PAYMENT $PAYMENT_DONE" =~ m/\b$status_id\b/ ) {
        my $detail = $order->order_details( { name => 'shirt' }, { rows => 1 } )->single;
        $type = $detail->desc || '' if $detail;
    }
    else {
        my $details = $order->order_details;
        my $detail = $details->search( { clothes_code => { -like => '0S%' } }, { rows => 1 } )->single;
        $type = $detail->desc || '' if $detail;
    }

    return $type;
}

=head2 blouse_type($order)

    % my $type = blouse_type($order);
    # 하늘색

=cut

sub blouse_type {
    my ( $self, $order ) = @_;
    return unless $order;

    my $type      = '';
    my $status_id = $order->status_id;
    if ( "$CHOOSE_CLOTHES $CHOOSE_ADDRESS $PAYMENT $PAYMENT_DONE" =~ m/\b$status_id\b/ ) {
        my $detail = $order->order_details( { name => 'blouse' }, { rows => 1 } )->single;
        $type = $detail->desc || '' if $detail;
    }
    else {
        my $details = $order->order_details;
        my $detail = $details->search( { clothes_code => { -like => '0B%' } }, { rows => 1 } )->single;
        $type = $detail->desc || '' if $detail;
    }

    return $type;
}

=head2 send_mail( $email )

=over

=item $email - RFC 5322 formatted String.

=back

=cut

sub send_mail {
    my ( $self, $email ) = @_;
    return unless $email;

    my $transport = Email::Sender::Transport::SMTP->new( { host => 'localhost' } );
    sendmail( $email, { transport => $transport } );
}

=head2 check_measurement

    my $failed = $self->check_measurement($user, $user_info);

=cut

sub check_measurement {
    my ( $self, $user, $user_info ) = @_;

    my $user_id = $user->id;
    my $gender = $user_info->gender || 'male'; # TODO: 원래 없으면 안됨

    my $input = {};
    map { $input->{$_} = $user_info->$_ } qw/height weight bust topbelly arm waist thigh leg hip knee/;

    my $v = $self->validation;
    $v->input($input);
    $v->required('height')->size( 3, 3 );
    $v->required('weight')->size( 2, 3 );
    $v->required('bust')->size( 2, 3 );
    $v->required('topbelly')->size( 2, 3 );
    $v->required('arm')->size( 2, 3 );

    if ( $gender eq 'male' ) {
        $v->required('waist')->size( 2, 3 );
        $v->required('thigh')->size( 2, 3 );
        $v->required('leg')->size( 2, 3 );
    }
    elsif ( $gender eq 'female' ) {
        $v->required('hip')->size( 2, 3 );
        $v->required('knee')->size( 2, 3 );
    }
    else {
        my $msg = "Wrong user gender: $gender($user_id)";
        $self->log->error($msg);
        return ["gender($msg)"];
    }

    return $v->failed if $v->has_error;
    return;
}

=head2 category_price($order, $category?)

    # 배송비미포함
    my $price = $self->category_price($order);     # 30000

    my $tie_price = $self->category_price($order, $TIE);     # 2000 or 0

=cut

sub category_price {
    my ( $self, $order, $category ) = @_;
    return unless $order;

    return $PRICE{$category} if $category && $category ne $TIE;

    my $price = 0;
    my %seen;
    my @categories = $self->categories($order);

    for my $c (@categories) {
        $price += $PRICE{$c};
        $seen{$c}++;
    }

    ## 자켓이나 팬츠가 없는데 타이가 있다면?
    my $tie_price = $PRICE{$TIE};
    if ( $seen{$TIE} && ( !$seen{$JACKET} || !$seen{$PANTS} ) ) {
        $tie_price = 2_000;
        $price += $tie_price;
    }

    return $tie_price if $category;
    return $price;
}

=head2 merchant_uid

    # merchant-1484777630841-Wfg
    # same as javascript: merchant-' + new Date().getTime() + "-<random_3_chars>"
    my $merchant_uid = $self->merchant_uid;

    # opencloset-share-3-1484777630841-D8d
    my $merchant_uid = $self->merchant_uid( "opencloset-share-%d-", $order->id );

=cut

sub merchant_uid {
    my ( $self, $prefix_fmt, @prefix_params ) = @_;

    my $prefix = $prefix_fmt ? sprintf( $prefix_fmt, @prefix_params ) : "merchant_";
    my ( $seconds, $microseconds ) = Time::HiRes::gettimeofday;
    my $random = String::Random->new->randregex(q{-\w\w\w});

    return $prefix . $seconds . $microseconds . $random;
}

=head2 formatted( $type, $string )

    %= formatted('phone', '01012345678')
    # 010-1234-5678

=cut

sub formatted {
    my ( $self, $type, $str ) = @_;
    return '' unless $type;
    return '' unless $str;

    my $formatted = $str;
    if ( $type eq 'phone' ) {
        my $len = length $formatted;
        my $head = substr( $formatted, 0, 3 );
        my @rest;
        if ( $len == 10 ) {
            push @rest, substr( $formatted, 3, 3 );
            push @rest, substr( $formatted, 6 );
        }
        elsif ( $len == 11 ) {
            push @rest, substr( $formatted, 3, 4 );
            push @rest, substr( $formatted, 7 );
        }
        else {
            return $formatted;
        }

        $formatted = join( '-', $head, @rest );
    }

    return $formatted;
}

=head2 date_calc( $wearon_date, $days )

Default C<$days> 는 3박 4일의 C<3>
발송(예정)일 또는 의류착용일과 대여기간을 기준으로 발송(예정)일, 대여일, 의류착용일, 반납일, 택배발송일을 계산합니다.

    # 발송(예정)일 = 주말 + 공휴일 + 0일    # AM 10:00 이전
    # 발송(예정)일 = 주말 + 공휴일 + 1일    # AM 10:00 이후
    # 도착(예정)일 = 발송(예정)일 + 공휴일 + 주말 + 2일
    # 의류착용일   = 도착(예정)일 + 1일
    # 대여일      = 의류착용일 - 1일
    # 반납일      = 대여일 + 대여기간(default 3일)
    # 택배일      = 반납일 - 1일

    my $shipping_date = $self->date_calc;    # 가장 가까운 발송(예정)일
    my $dates = $self->date_calc({ shipping => $shipping_date });
    # {
    #   shipping => $dt1, # 발송(예정)일
    #   arrival  => $dt2, # 도착(예정)일
    #   rental   => $dt3, # 대여일
    #   wearon   => $dt4, # 의류착용일
    #   target   => $dt5, # 반납일
    #   parcel   => $dt6, # 반납택배발송일
    # }

=cut

sub date_calc {
    my ( $self, $dates, $days ) = @_;
    my $tz = $self->config->{timezone};

    unless ($dates) {
        my $now      = DateTime->now( time_zone => $tz );
        my $hour     = $now->hour;
        my $year     = $now->year;
        my @holidays = $self->holidays( $year, $year + 1 ); # 연말을 고려함
        my %holidays;
        map { $holidays{$_}++ } @holidays;

        my $dt = DateTime->today( time_zone => $tz );
        $dt->add( days => 1 ) if $holidays{ $now->ymd } || $hour > 10;
        while (1) {
            $dt->add( days => 1 ) and next if $dt->day_of_week > 5;
            $dt->add( days => 1 ) and next if $holidays{ $dt->ymd };
            last;
        }

        return $dt;
    }

    my $shipping_date = $dates->{shipping};
    my $wearon_date   = $dates->{wearon};

    if ($shipping_date) {
        $days ||= $DEFAULT_RENTAL_PERIOD; # 기본 대여일은 3박 4일
        my $year = $shipping_date->year;
        my @holidays = $self->holidays( $year, $year + 1 ); # 연말을 고려함

        my ( $n,        $dt );
        my ( %holidays, %dates );
        map { $holidays{$_}++ } @holidays;

        $n  = $SHIPPING_BUFFER;
        $dt = $shipping_date->clone;
        while ($n) {
            $dt->add( days => 1 );
            next if $dt->day_of_week > 5;
            next if $holidays{ $dt->ymd };
            $n--;
        }

        $dates{arrival}  = $dt->clone;
        $dates{shipping} = $shipping_date->clone;
        $dates{wearon}   = $wearon_date ? $wearon_date->clone : $dates{arrival}->clone->add( days => 1 );
        $dates{rental}   = $dates{wearon}->clone->subtract( days => 1 );
        $dates{target}   = $dates{rental}->clone->add( days => $days );
        $dates{parcel}   = $dates{target}->clone->subtract( days => 1 );

        return \%dates;
    }
    elsif ($wearon_date) {
        my $year = $wearon_date->year;
        my @holidays = $self->holidays( $year, $year + 1 );

        my ( $n,        $dt );
        my ( %holidays, %dates );
        map { $holidays{$_}++ } @holidays;

        $n  = $SHIPPING_BUFFER + 1;
        $dt = $wearon_date->clone;
        while ($n) {
            $dt->subtract( days => 1 );
            next if $dt->day_of_week > 5;
            next if $holidays{ $dt->ymd };
            $n--;
        }

        $shipping_date = $dt;
        return $self->date_calc( { shipping => $shipping_date, wearon => $wearon_date }, $days );
    }

    return;
}

=head2 payment_deadline( $order )

    my $deadline = $self->payment_deadline($order);    # DateTime obj

=cut

sub payment_deadline {
    my ( $self, $order ) = @_;
    return unless $order;

    my $wearon_date = $self->timezone( $order->wearon_date );
    my $dates       = $self->date_calc( { wearon => $wearon_date } );
    my $deadline    = $dates->{shipping}->clone;
    $deadline->set_hour(10);

    return $deadline;
}

1;
