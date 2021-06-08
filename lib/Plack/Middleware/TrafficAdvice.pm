package Plack::Middleware::TrafficAdvice;

use v5.8.5;

use strict;
use warnings;

use parent 'Plack::Middleware';

use Plack::Util::Accessor qw/ data file /;

use Cwd;
use File::Temp qw/ tempfile /;
use HTTP::Date;
use HTTP::Status qw/ :constants /;
use JSON::MaybeXS;

sub prepare_app {
    my ($self) = @_;

    if (my $data = $self->data) {

        if ($self->file) {
            die "Cannot specify both data and file";
        }

        my ($fh, $filename) = tempfile('traffic-advice-XXXXXXXX', SUFFIX => '.json', UNLINK => 0, TMPDIR => 1);
        $self->file( $filename );

        if (ref($data)) {
            my $encoder = JSON::MaybeXS->new( { utf8 => 1 } );
            print {$fh} $encoder->encode($data)
                or die "Unable to write data";
        }
        else {
            print {$fh} $data
                or die "Unable to write data";
        }

        close $fh;


    }
    elsif (my $file = $self->file) {

        unless (-r $file) {
            die "Cannot read file: '$file'";
        }

    }
    else {
        die "Either data or file must be configured";
    }

}

sub call {
    my ( $self, $env ) = @_;

    unless ( $env->{REQUEST_URI} eq '/.well-known/traffic-advice' ) {
        return $self->app->($env);
    }

    unless ( $env->{REQUEST_METHOD} eq 'GET' ) {
        return $self->error( HTTP_METHOD_NOT_ALLOWED, "Not Allowed" );
    }

    my $file = $self->file;

    # Some of this is based on Plack::App::File.

    open my $fh, "<:raw", $file
        or return $self->error( HTTP_INTERNAL_SERVER_ERROR, "Internal Error" );

    my @stat = stat $file;

    Plack::Util::set_io_path($fh, Cwd::realpath($file));

    [
        HTTP_OK,
        [
         'Content-Type'   => 'application/trafficadvice+json',
         'Content-Length' => $stat[7],
         'Last-Modified'  => HTTP::Date::time2str( $stat[9] )
        ],
        $fh,
    ];

}

sub error {
    my ($self, $code, $message) = @_;
    return [ $code, [ 'Content-Type' => 'text/plain', 'Content-Length' => length($message) ], [ $message ] ];
}

1;
