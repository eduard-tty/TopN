#!/usr/bin/env perl
use strict;
use warnings;

use POE qw(Component::Server::TCP);
use Storable;

use TopN;

my ($hostname, $port, $expire) = @ARGV;
$hostname ||= 'localhost';
$port     ||= 20001;
$expire   ||= 3*24*60*60;

my $counts = TopN->new( $expire );

my %command_handlers = (
    count  => sub { $counts->add(shift); return; },
    expire => sub { $counts->expire(); return; },
    info   => sub {
        my $template = "Number of counts  : %s\nExpire queue size : %s\n\n";
        return sprintf($template, $counts->size(), $counts->expire_size() );
    },
    load   => sub {
        $counts = bless retrieve(shift), 'TopN';
        return;
    },
    quit   => sub { exit(0); },
    save   => sub {
        (my $name = localtime . '.topn') =~ s/\s+/-/g;
        store($counts, $name);
        return;
    },
    top    => sub { return join(', ',  $counts->top(shift) );  },
);

POE::Component::Server::TCP->new(
    Hostname => $hostname,
    Port     => $port,
    ClientInput => sub {
        my ($heap, $message) = @_[HEAP, ARG0];
        my ($command, @args) = split(/\s/, $message);
        my $response = '';
        if ( my $handler = $command_handlers{$command || ''} ) {
            $response = $handler->(@args);
        };
        if ( $response ) {
            $heap->{client}->put($response);
        }

        return;
    },
);

$poe_kernel->run();

exit(0);

1;

