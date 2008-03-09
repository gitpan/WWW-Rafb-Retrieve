#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 23;

my $ID = 'ddeC3l31';
my $PASTE_DUMP = {
          'desc' => 'Perl hashref',
          'content' => "{\r\n        true => sub { 1 },\r\n        false => sub { 0 },\r\n        time  => scalar localtime(),\r\n}",
          'name' => 'Zoffix',
          'lang'    => 'Perl',
};

BEGIN {
    use_ok('Carp');
    use_ok('URI');
    use_ok('LWP::UserAgent');
    use_ok('HTML::TokeParser::Simple');
    use_ok('Class::Data::Accessor');
    use_ok('HTML::Entities');
    use_ok( 'WWW::Rafb::Retrieve' );
}

diag( "Testing WWW::Rafb::Retrieve $WWW::Rafb::Retrieve::VERSION, Perl $], $^X" );

use WWW::Rafb::Retrieve;
my $paster = WWW::Rafb::Retrieve->new( timeout => 10 );
isa_ok($paster, 'WWW::Rafb::Retrieve');
can_ok($paster, qw(
    new
    retrieve
    error
    results
    html_content
    id
    uri
    timeout
    ua
    _parse
    _set_error
    _get_content
    response
    )
);

SKIP: {
    my $ret = $paster->retrieve($ID)
        or skip "Got error on ->retrieve($ID): " . $paster->error, 14;

    SKIP: {
        my $ret2 = $paster->retrieve("http://rafb.net/p/$ID.html")
            or skip
                "Got error on ->retrieve('http://rafb.net/p/$ID.html'): "
                        . $paster->error, 1;
        is_deeply(
            $ret,
            $ret2,
            'calls with ID and URI must return the same'
        );
    }

    is_deeply(
        $ret,
        $PASTE_DUMP,
        q|dump from Dumper must match ->retrieve()'s response|,
    );

    for ( qw(lang content name desc) ) {
        ok( exists $ret->{$_}, "$_ key must exist in the return" );
    }

    is_deeply(
        $ret,
        $paster->results,
        '->results() must now return whatever ->retrieve() returned',
    );

    is(
        $paster->id,
        $ID,
        'paste ID must match the return from ->id()',
    );

    isa_ok( $paster->uri, 'URI::http', '->uri() method' );

    is(
        $paster->uri,
        "http://rafb.net/p/$ID.html",
        'uri() must contain a URI to the paste',
    );
    isa_ok( $paster->response, 'HTTP::Response', '->response() method' );

    like( $paster->html_content,
     qr|<html>.*?<head>.*?</head>.*?</html>|s,
        '->html_content() method'
    );
    is(
        $paster->timeout,
        10,
        '->timeout() method',
    );
    isa_ok( $paster->ua, 'LWP::UserAgent', '->ua() method' );
} # SKIP{}





