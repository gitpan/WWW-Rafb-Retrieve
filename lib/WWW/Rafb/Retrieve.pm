package WWW::Rafb::Retrieve;

use warnings;
use strict;

our $VERSION = '0.001';

use Carp;
use URI;
use LWP::UserAgent;
use HTML::TokeParser::Simple;
use HTML::Entities;
use base 'Class::Data::Accessor';
__PACKAGE__->mk_classaccessors qw(
    ua
    timeout
    html_content
    uri
    id
    error
    results
    response
);

sub new {
    my $class = shift;
    croak "Must have even number of arguments to new()"
        if @_ & 1;

    my %args = @_;
    $args{ +lc } = delete $args{ $_ } for keys %args;

    $args{timeout} ||= 30;
    $args{ua} ||= LWP::UserAgent->new(
        timeout => $args{timeout},
        agent   => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.8.1.12)'
                    .' Gecko/20080207 Ubuntu/7.10 (gutsy) Firefox/2.0.0.12',
    );

    my $self = bless {}, $class;
    $self->timeout( $args{timeout} );
    $self->ua( $args{ua} );

    return $self;
}

sub retrieve {
    my ( $self, $in ) = @_;
    croak "Missing paste URI or ID (or it's undefined)"
        unless defined $in;

    my ( $id )
    = $in =~ m{ (?:http://)? (?:www\.)? rafb.net/p/ (\S+?) \.html}ix;

    $id = $in
        unless defined $id;

    $self->id( $id );

    $self->$_(undef)
        for qw(error  results  html_content  uri  response);

    my $uri = $self->uri( URI->new("http://rafb.net/p/$id.html") );

    my $response = $self->response( $self->ua->get( $uri ) );

    if ( $response->is_success ) {
        return $self->_parse( $self->html_content($response->content) );
    }
    else {
        return $self->_set_error(
            'Failed to retrieve the paste: ' . $response->status_line
        );
    }
}

sub _parse {
    my ( $self, $content ) = @_;
    return $self->_set_error( 'Nothing to parse (empty document retrieved)' )
        unless defined $content and length $content;

    my $parser = HTML::TokeParser::Simple->new( \$content );

    my %data;
    my %nav = (
        level       => 0,
        small       => 0,
        b           => 0,
        get_desc    => 0,
    );
    while ( my $t = $parser->get_token ) {
        if ( $t->is_start_tag('small') ) {
            if ( ++$nav{small} == 2 ) {
                $nav{get_desc} = 1;
            }
            $nav{level} = 1;
        }
        elsif ( $t->is_start_tag('b') ) {
            $nav{b}++;
            $nav{level} = 2;
        }
        elsif ( $nav{b} == 1 and $t->is_text ) {
            $data{lang} = $t->as_is;
            @nav{ qw(b level)} = (2, 3);
        }
        elsif ( $nav{b} == 3 and $t->is_text ) {
            $data{name} = $t->as_is;
            @nav{ qw(b level) } = (4, 4);
        }
        elsif ( $nav{get_desc} and $t->is_text ) {
            $data{desc} = substr $t->as_is, 13; # remove 'Description: ' text
            $nav{success} = 1;
            last;
        }
    }
    
    unless ( $nav{success} ) {
        return $self->_set_error(
            "Failed to parse paste.. \$nav{level} == $nav{level}"
        );
    }

    for ( values %data ) {
        decode_entities( $_ );
        s/\240/ /g; # replace any &nbsp; chars
    }

    $data{content} = $self->_get_content
        or return;

    return $self->results( \%data );
}

sub _get_content {
    my $self = shift;
    my $content_uri
    = URI->new( sprintf 'http://rafb.net/p/%s.txt', $self->id );

    my $content_response = $self->ua->get( $content_uri );
    if ( $content_response->is_success ) {
        return $content_response->content;
    }
    else {
        return $self->_set_error(
            'Failed to retrieve paste: ' . $content_response->status_line
        );
    }
}

sub _set_error {
    my ( $self, $error ) = @_;
    $self->error( $error );
    return;
}

1;
__END__

=head1 NAME

WWW::Rafb::Retrieve - retrieve pastes from http://rafb.net/paste/

=head1 SYNOPSIS

    use strict;
    use warnings;

    use WWW::Rafb::Retrieve;

    my $paster = WWW::Rafb::Retrieve->new;

    my $results_ref = $paster->retrieve('http://rafb.net/p/uldKMl73.html')
        or die $paster->error;

    printf "Paste %s was posted by %s\nDescription: %s\n%s\n",
                $paster->uri, @$results_ref{ qw( name  desc  content ) };

=head1 DESCRIPTION

Retrieve pastes from L<http://rafb.net/paste/> via Perl

=head1 CONSTRUCTOR

=head2 new

    my $paster = WWW::Rafb::Retrieve->new;

    my $paster = WWW::Rafb::Retrieve->new(
        timeout => 10,
    );

    my $paster = WWW::Rafb::Retrieve->new(
        ua => LWP::UserAgent->new(
            timeout => 10,
            agent   => 'PasterUA',
        ),
    );

Constructs and returns a brand new yummy juicy WWW::Rafb::Retrieve
object. Takes two arguments, both are I<optional>. Possible arguments are
as follows:

=head3 timeout

    ->new( timeout => 10 );

B<Optional>. Specifies the C<timeout> argument of L<LWP::UserAgent>'s
constructor, which is used for retrieving. B<Defaults to:> C<30> seconds.

=head3 ua

    ->new( ua => LWP::UserAgent->new( agent => 'Foos!' ) );

B<Optional>. If the C<timeout> argument is not enough for your needs
of mutilating the L<LWP::UserAgent> object used for retrieving, feel free
to specify the C<ua> argument which takes an L<LWP::UserAgent> object
as a value. B<Note:> the C<timeout> argument to the constructor will
not do anything if you specify the C<ua> argument as well. B<Defaults to:>
plain boring default L<LWP::UserAgent> object with C<timeout> argument
set to whatever C<WWW::Rafb::Retrieve>'s C<timeout> argument is
set to as well as C<agent> argument is set to mimic Firefox.

=head1 METHODS

=head2 retrieve

    my $result_ref = $paster->retrieve('http://rafb.net/p/uldKMl73.html')
        or die $paster->error;

    my $result_ref = $paster->retrieve('uldKMl73')
        or die $paster->error;

Instructs the object to retrieve a specified paste. Takes one mandatory
argument which can be either a full URI to the paste you want to retrieve
or just the paste's ID. If an error occurs returns either C<undef>
or an empty list depending on the context and the reason for the error
will be available via C<error()> method. Upon success returns a hashref
with the following keys/values:

    $VAR1 = {
        'lang' => 'Plain Text',
        'desc' => 'No description',
        'content' => 'blah blah teh paste',
        'name' => 'Anonymous Poster'
    };

=head3 content

    { 'content' => 'blah blah teh paste', }

The C<content> key will contain the textual content of the paste.

=head3 lang

    { 'lang' => 'Plain Text' }

The C<lang> key will contain the (computer) language of the paste.

=head3 desc

    { 'desc' => 'No description' }

The C<desc> key will contain the description of the paste.

=head3 name

    { 'name' => 'Anonymous Poster' }

The C<name> key will contain the name of the creature that posted the paste.

=head2 error

    my $result_ref = $paster->retrieve('uldKMl73')
        or die $paster->error;

If an error occurs during the call to C<retrieve()> it will return
either C<undef> or an empty list depending on the context and the reason
for the error will be available via C<error()> method. Takes no arguments,
returns a human parasable error message explaining why C<retrieve()> failed.

=head2 id

    my $paste_id = $paster->id;

Must be called after a successfull call to C<retrieve()>. Takes no arguments,
returns a paste ID of the last retrieved paste irrelevant of whether
an ID or a URI was given to C<retrieve()>

=head2 uri

    my $paste_uri = $paster->uri;

Must be called after a successfull call to C<retrieve()>. Takes no arguments,
returns a L<URI> object with the URI pointing to the last retrieved paste
irrelevant of whether an ID or a URI was given to C<retrieve()>

=head2 results

    my $results_ref = $paster->results;

Must be called after a successfull call to C<retrieve()>. Takes no arguments,
returns the same hashref which the last C<retrieve()> returned. See
C<retrieve()> method for more information.

=head2 response

    my $response_obj = $paster->response;

Must be called after a call to C<retrieve()>. Takes no arguments,
returns an L<HTTP::Response> object which was obtained while trying to
retrieve your paste. You can use it in case you want to thoroughly
investigate why the C<retrieve()> might have failed.

=head2 html_content

    my $paste_html = $paster->html_content;

Must be called after a successfull call to C<retrieve()>. Takes no arguments,
returns an unparsed HTML content of the paste you've specified to
C<retrieve()>

=head2 timeout

    my $ua_timeout = $paster->timeout;

Takes no arguments, returns the value you've specified in the C<timeout>
argument to C<new()> method (or its default if you didn't). See C<new()>
method above for more information.

=head2 ua

    my $old_LWP_UA_obj = $paster->ua;

    $paster->ua( LWP::UserAgent->new( timeout => 10, agent => 'foos' );

Returns a currently used L<LWP::UserAgent> object used for retrieving
pastes. Takes one optional argument which must be an L<LWP::UserAgent>
object, and the object you specify will be used in any subsequent calls
to C<retrieve()>.

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-rafb-retrieve at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Rafb-Retrieve>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Rafb::Retrieve

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Rafb-Retrieve>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Rafb-Retrieve>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Rafb-Retrieve>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Rafb-Retrieve>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

