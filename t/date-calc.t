#!/usr/bin/env perl
use strict;
use warnings;

# Disable IPv6, epoll and kqueue
BEGIN { $ENV{MOJO_NO_IPV6} = $ENV{MOJO_POLL} = 1 }

use Mojolicious;
use Mojolicious::Lite;
use DateTime::Format::Strptime;

my $mojolicious_version = Mojolicious->VERSION;

app->log->level('error');

plugin 'OpenCloset::Plugin::Helpers';
plugin 'OpenCloset::Share::Web::Plugin::Helpers';

our $DEFAULT_DAYS = 3;

get '/wearon/:date' => sub {
    my $self = shift;
    my $date = $self->param('date');
    my $days = $self->param('days') || $DEFAULT_DAYS;
    my $strp = DateTime::Format::Strptime->new(
        pattern => '%F',
        locale => 'ko_KR',
        time_zone => 'Asia/Seoul'
    );
    my $dt = $strp->parse_datetime($date);
    my $dates = $self->date_calc({ wearon => $dt }, $days);
    my %map; # stringify DateTime
    map { $map{$_} = $dates->{$_}->ymd } keys %$dates;
    $self->render(json => \%map);
};

get '/shipping/:date' => sub {
    my $self = shift;
    my $date = $self->param('date');
    my $days = $self->param('days') || $DEFAULT_DAYS;
    my $strp = DateTime::Format::Strptime->new(
        pattern => '%F',
        locale => 'ko_KR',
        time_zone => 'Asia/Seoul'
    );
    my $dt = $strp->parse_datetime($date);
    my $dates = $self->date_calc({ shipping => $dt }, $days);
    my %map; # stringify DateTime
    map { $map{$_} = $dates->{$_}->ymd } keys %$dates;
    $self->render(json => \%map);
};

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new;

# 3박 4일
$t->get_ok('/wearon/2020-09-30')
    ->status_is(200)
    ->json_is('/shipping' => '2020-09-25')
    ->json_is('/wearon' => '2020-09-30')
    ->json_is('/rental' => '2020-09-29')
    ->json_is('/arrival' => '2020-09-29')
    ->json_is('/target' => '2020-10-02')
    ->json_is('/parcel' => '2020-10-02');

$t->get_ok('/shipping/2020-09-30')
    ->status_is(200)
    ->json_is('/shipping' => '2020-09-30')
    ->json_is('/wearon' => '2020-10-07')
    ->json_is('/rental' => '2020-10-06')
    ->json_is('/arrival' => '2020-10-06')
    ->json_is('/target' => '2020-10-09')
    ->json_is('/parcel' => '2020-10-09');

# 5박 6일
$t->get_ok('/wearon/2020-09-30?days=5')
    ->status_is(200)
    ->json_is('/shipping' => '2020-09-25')
    ->json_is('/wearon' => '2020-09-30')
    ->json_is('/rental' => '2020-09-29')
    ->json_is('/arrival' => '2020-09-29')
    ->json_is('/target' => '2020-10-04')
    ->json_is('/parcel' => '2020-10-04');

$t->get_ok('/shipping/2020-09-30?days=5')
    ->status_is(200)
    ->json_is('/shipping' => '2020-09-30')
    ->json_is('/wearon' => '2020-10-07')
    ->json_is('/rental' => '2020-10-06')
    ->json_is('/arrival' => '2020-10-06')
    ->json_is('/target' => '2020-10-11')
    ->json_is('/parcel' => '2020-10-11');

done_testing();
