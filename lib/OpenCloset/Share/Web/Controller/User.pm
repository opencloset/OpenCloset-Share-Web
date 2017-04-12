package OpenCloset::Share::Web::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Digest::MD5 qw/md5_hex/;
use Email::Simple ();
use Encode qw/encode_utf8/;
use Mojo::URL;
use String::Random ();

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 auth

    under /

=cut

sub auth {
    my $self = shift;

    my $user_id = $self->session('access_token');
    unless ($user_id) {
        my $login = Mojo::URL->new( $self->config->{opencloset}{login} );
        $login->query( return => $self->req->url->to_abs );
        $self->redirect_to($login);
        return;
    }

    my $user = $self->schema->resultset('User')->find( { id => $user_id } );
    my $user_info = $user->user_info;
    $self->stash( user => $user, user_info => $user_info );
    return 1;
}

=head2 logout

    # logout
    GET /logout

=cut

sub logout {
    my $self = shift;

    delete $self->session->{access_token};
    $self->redirect_to('welcome');
}

=head2 add

    GET /signup

=cut

sub add {
    my $self = shift;
}

=head2 reset

    GET /reset

=cut

sub reset {
    my $self = shift;
}

=head2 reset_password

    POST /reset

=cut

sub reset_password {
    my $self = shift;

    my $v = $self->validation;
    $v->required('email')->email;

    return $self->error( 400, "유효하지 않은 email 입니다." ) if $v->has_error;

    my $email = $v->param('email');
    my $user = $self->schema->resultset('User')->find( { email => $email } );
    return $self->error( 404, "사용자를 찾을 수 없습니다: $email" ) unless $user;

    my $digest = md5_hex(time);
    $user->update( { password => $digest } );

    my $body = $self->render_to_string( 'email/reset_password', format => 'txt', email => $email, password => $digest );
    chomp $body;

    my $msg = Email::Simple->create(
        header => [
            From    => $self->config->{notify}{from},
            To      => $email,
            Subject => '[열린옷장] 비밀번호 변경안내',
        ],
        body => $body
    );

    $self->send_mail( encode_utf8( $msg->as_string ) );
    $self->log->info( "reset password url: " . $self->url_for('/login')->query(email => $email, password => $digest)->to_abs );

    $self->flash( done => 1 );
    $self->redirect_to('/reset');
}

=head2 authentication

    GET /authentication?email=xxxx&password=xxxx

=cut

sub authentication {
    my $self = shift;

    my $v = $self->validation;
    $v->required('email')->email;
    $v->required('password');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        $self->log->debug( 'Parameter validation failed: ' . join( ', ', @$failed ) );
        return $self->error( 400, '잘못된 요청입니다' );
    }

    my $email    = $v->param('email');
    my $password = $v->param('password');

    my $user = $self->schema->resultset('User')->find( { email => $email } );
    return $self->error( 404, "User not found: $email" ) unless $user;
    return $self->error( 400, 'Wrong password' )         unless $user->check_password($password);

    $self->session( access_token => $user->id );
    $self->redirect_to("/settings");
}

=head2 settings

    GET /settings

=cut

sub settings { }

=head2 update_settings

    POST /settings

=cut

sub update_settings {
    my $self = shift;

    my $v = $self->validation;
    $v->required('password');
    $v->required('re-password');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $password = $v->param('password');
    my $retype   = $v->param('re-password');
    return $self->error( 400, "비밀번호가 일치하지 않습니다." ) if $password ne $retype;

    my $user = $self->stash('user');
    my $expires = time + ( 86400 * 365 );
    $user->update( { password => $password, expires => $expires } );
    $self->redirect_to('index');
}

=head2 create

    POST /users

=cut

sub create {
    my $self = shift;

    my $v = $self->validation;
    $v->required('name');
    $v->required('email')->email;
    $v->required('password');
    $v->required('re-password');
    $v->required('gender')->in(qw/male female/);
    $v->required('birth')->like(qr/^\d{4}$/);
    $v->required('address1');
    $v->required('address2');
    $v->required('address3');
    $v->required('address4');
    $v->required('phone')->like(qr/^01\d\-?\d{3,4}\-?\d{4}$/);
    $v->required('verification-code')->like(qr/^\d{6}$/);

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my $error  = '입력값이 유효하지 않습니다: ' . join( ', ', @$failed );
        my $input  = $v->input;
        $self->flash( input => $input, error => $error );
        return $self->redirect_to('/signup');
    }

    my $name     = $v->param('name');
    my $email    = $v->param('email');
    my $password = $v->param('password');
    my $retype   = $v->param('re-password');
    my $gender   = $v->param('gender');
    my $birth    = $v->param('birth');
    my $address1 = $v->param('address1');
    my $address2 = $v->param('address2');
    my $address3 = $v->param('address3');
    my $address4 = $v->param('address4');
    my $phone    = $v->param('phone') =~ s/\-//gr;
    my $code     = $v->param('verification-code');

    my $user = $self->schema->resultset('User')->find( { email => $email } );
    if ($user) {
        my $error = "이미 사용중인 email 입니다: $email";
        my $input = $v->input;
        $self->flash( input => $input, error => $error );
        return $self->redirect_to('/signup');
    }

    if ( $password ne $retype ) {
        my $error = "비밀번호를 다르게 입력하셨습니다.";
        my $input = $v->input;
        $self->flash( input => $input, error => $error );
        return $self->redirect_to('/signup');
    }

    my $verify = $self->session('verify');
    unless ($verify) {
        my $error = "휴대폰 본인확인이 되지 않았습니다.";
        my $input = $v->input;
        delete $input->{phone};
        delete $input->{'verification-code'};
        $self->flash( input => $input, error => $error );
        return $self->redirect_to('/signup');
    }

    if ( $phone ne $verify->{phone} || $code ne $verify->{code} ) {
        my $error = "유효하지 않은 인증번호입니다.";
        my $input = $v->input;
        delete $input->{phone};
        delete $input->{'verification-code'};
        $self->flash( input => $input, error => $error );
        return $self->redirect_to('/signup');
    }

    my $guard = $self->schema->txn_scope_guard;
    my $now   = DateTime->now;
    $user = $self->schema->resultset('User')->create(
        {
            name     => $name,
            email    => $email,
            password => $password,
            expires  => $now->epoch + ( 86400 * 30 * 12 ), # 1년 유효?
        }
    );

    $user->create_related(
        'user_info',
        {
            address1 => $address1,
            address2 => $address2,
            address3 => $address3,
            address4 => $address4,
            birth    => $birth,
            gender   => $gender,
            phone    => $phone,
        }
    );
    $guard->commit;

    $self->session( access_token => $user->id );
    $self->redirect_to('index');
}

=head2 verify

    POST /verify

=cut

sub verify {
    my $self = shift;

    my $v = $self->validation;
    $v->required('phone')->like(qr/^01\d\-?\d{3,4}\-?\d{4}$/);

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter validation failed: ' . join( ', ', @$failed ) );
    }

    my $phone = $v->param('phone') =~ s/\-//gr;
    my $user_info = $self->schema->resultset('UserInfo')->find( { phone => $phone } );
    return $self->error( 400, "중복된 휴대폰번호 입니다: $phone" ) if $user_info;

    my $code = String::Random->new->randregex('\d\d\d\d\d\d');
    $self->log->info("[$phone] 열린옷장 인증번호: $code");
    my $sms = $self->sms( $phone, "열린옷장 인증번호: $code" );
    return $self->error( 500, "Failed to send a SMS to $phone" ) unless $sms;

    $self->session( verify => { phone => $phone, code => $code } );
    $self->render( text => 'Sent a verification code successfully' );
}

1;
