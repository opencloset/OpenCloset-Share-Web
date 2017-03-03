package OpenCloset::Share::Web::Command::date;

use Mojo::Base 'Mojolicious::Command';

use DateTime::Format::Strptime;
use DateTime;

use OpenCloset::Constants qw/$DEFAULT_RENTAL_PERIOD $SHIPPING_BUFFER/;

has description => 'Date calculator';
has usage       => "Usage: APPLICATION date ymd(today)\n";

binmode STDOUT, ':utf8';

=encoding utf-8

=head1 NAME

OpenCloset::Share::Web::Command::date

=head1 SYNOPSIS

    $ MOJO_CONFIG=/path/to/share.conf ./script/share date    # default now
    $ MOJO_CONFIG=/path/to/share.conf ./script/share date 2017-02-14T10:00:00

=head1 METHODS

=head2 run

=cut

our %WEEK_MAP = ( 1 => '월', 2 => '화', 3 => '수', 4 => '목', 5 => '금', 6 => '토', 7 => '일' );

sub run {
    my ( $self, $str_date ) = @_;

    my $dt;
    my $tz = $self->app->config->{timezone};
    if ($str_date) {
        my $strp = DateTime::Format::Strptime->new(
            pattern   => '%FT%T',
            time_zone => $tz
        );
        $dt = $strp->parse_datetime($str_date);
    }
    else {
        $dt = DateTime->now( time_zone => $tz );
    }

    my $shipping_date = $self->shipping_date($dt);
    my $dates = $self->app->date_calc( { shipping => $shipping_date } );
    print $dt->ymd . ' (' . $WEEK_MAP{ $dt->day_of_week } . ') ' . $dt->hms . " 기준\n";
    printf "발송: %s(%s)\n", $dates->{shipping}->ymd, $WEEK_MAP{ $dates->{shipping}->day_of_week };
    printf "대여: %s(%s)\n", $dates->{rental}->ymd,   $WEEK_MAP{ $dates->{rental}->day_of_week };
    printf "착용: %s(%s)\n", $dates->{wearon}->ymd,   $WEEK_MAP{ $dates->{wearon}->day_of_week };
    printf "택배: %s(%s)\n", $dates->{parcel}->ymd,   $WEEK_MAP{ $dates->{parcel}->day_of_week };
    printf "반납: %s(%s)\n", $dates->{target}->ymd,   $WEEK_MAP{ $dates->{target}->day_of_week };
}

sub shipping_date {
    my ( $self, $today ) = @_;
    my $tz = $self->app->config->{timezone};

    $today = DateTime->now( time_zone => $tz ) unless $today;
    my $hour     = $today->hour;
    my $year     = $today->year;
    my @holidays = $self->app->holidays( $year, $year + 1 ); # 연말을 고려함
    my %holidays;
    map { $holidays{$_}++ } @holidays;

    my $dt = $today->clone->truncate( to => 'day' );
    if ( $holidays{ $today->ymd } || $hour > 10 ) {
        $dt->add( days => 1 );
        while (1) {
            $dt->add( days => 1 ) if $dt->day_of_week > 5;
            $dt->add( days => 1 ) if $holidays{ $dt->ymd };
            last;
        }
    }
    else {
        while (1) {
            $dt->add( days => 1 ) if $dt->day_of_week > 5;
            $dt->add( days => 1 ) if $holidays{ $dt->ymd };
            last;
        }
    }

    return $dt;
}

1;
