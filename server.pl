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

my $server;
my $counts = TopN->new( $expire );

my %command_handlers = (
    count  => sub { $counts->add(shift); return; },
    top    => sub { return join(', ',  $counts->top(shift) );  },
    quit   => sub { exit(0); },
    save   => sub {
        (my $name = localtime . '.topn') =~ s/\s+/-/g;
        save_topn($counts, $name); 
        return;
    },
    load   => sub { load_topn(shift); return; },
    info   => sub {
        my $template = "Number of counts  : %s\nExpire queue size : %s\n\n";
        my $info = sprintf($template, $counts->size(), $counts->expire_size() );
        return $info;
    },
);

sub save_topn  {
    my ($counts, $name) = @_;
    store($counts, $name);
    return;
}

sub load_topn  {
    my ($name) = @_;
    $counts = bless retrieve($name), 'TopN';
    return;
}

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

