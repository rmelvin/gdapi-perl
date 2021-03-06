package WWW::GoDaddy::REST::Schema;

use Moose;
use WWW::GoDaddy::REST::Util qw( abs_url build_complex_query_url );

extends 'WWW::GoDaddy::REST::Resource';

sub resource_field_names {
    my $self       = shift;
    my %res_fields = %{ $self->f('resourceFields') };
    return keys %res_fields;
}

sub resource_field {
    my $self       = shift;
    my $name       = shift;
    my $res_fields = $self->f('resourceFields');
    if ( !exists $res_fields->{$name} ) {
        return undef;
    }
    return $res_fields->{$name};
}

sub resource_field_type {
    my $self = shift;
    my $name = shift;
    my $opts = shift || {};

    my $type                     = $self->resource_field($name)->{'type'} || 'string';
    my $want_array               = wantarray;
    my $auto_upconvert_reference = $opts->{auto_upconvert_reference};
    my $qualify_schema_types     = $opts->{qualify_schema_types};

    if ( $want_array or $auto_upconvert_reference or $qualify_schema_types ) {
        my ( $a_type, $b_type ) = split( /[\[\]]/, $type );

        my $compound_type = $b_type ? 1 : 0;

        if ($auto_upconvert_reference) {

            # some schemas don't properly use the 'reference' type to indicate
            # the complex relationship.  Convention seems to favor two sorts
            # of field names that link to complex types:
            #   mySchemaId
            #   my_schema_id
            if ( !$compound_type && $name =~ /^(.*)(_id|Id)$/ ) {
                my $possible_schema = $self->client->schema($1);
                if ($possible_schema) {
                    $compound_type = 1;
                    $a_type        = 'reference';
                    $b_type        = $possible_schema->id;
                }
            }
        }

        if ($qualify_schema_types) {
            if ($compound_type) {
                my $possible_schema = $self->client->schema($b_type);
                if ($possible_schema) {
                    $b_type = $possible_schema->link('self');
                }
            }
            else {
                my $possible_schema = $self->client->schema($a_type);
                if ($possible_schema) {
                    $a_type = $possible_schema->link('self');
                }
            }
        }

        if ($want_array) {
            if ($compound_type) {
                return ( $a_type, $b_type );
            }
            else {
                return ( undef, $a_type );
            }
        }
        else {
            if ($compound_type) {
                $type = sprintf( '%s[%s]', $a_type, $b_type );
            }
            else {
                $type = $a_type;
            }
        }
    }
    return $type;
}

sub query {
    my $self = shift;

    if ( @_ == 1 && !ref( $_[0] ) ) {
        return $self->query_by_id(@_);
    }
    else {
        return $self->query_complex(@_);
    }

}

sub query_complex {
    my $self = shift;

    my $id = delete $_[0]->{'id'};
    my $url;
    if ( defined $id ) {
        $url = build_complex_query_url( $self->query_url($id), @_ );
    }
    else {
        $url = build_complex_query_url( $self->query_url, @_ );
    }

    my $resource = $self->client->http_request_as_resource( 'GET', $url );

    return wantarray ? $resource->items() : $resource;
}

sub query_by_id {
    my $self = shift;
    my $id   = shift;

    my $client = $self->client;
    my $url    = $self->query_url($id);

    return $client->http_request_as_resource( 'GET', $url );
}

sub create {
    my $self = shift;

    my $client = $self->client;
    my $url    = $self->query_url;

    return $client->http_request_as_resource( 'POST', $url, @_ );
}

sub is_queryable {
    my $self = shift;
    if ( $self->id eq 'schema' ) {
        return 1;
    }
    if ( $self->link('collection') ) {
        return 1;
    }
}

sub query_url {
    my $self = shift;
    my ($id) = @_;

    my $base_url = $self->id eq 'schema' ? $self->link('schemas') : $self->link('collection');
    if ( !defined $base_url ) {
        die( "Unable to build a query url: schema '" . $self->id . "' has no 'collection' link" );
    }
    if ( defined $id ) {
        return abs_url( $base_url, $id );
    }
    return $base_url;
}

our %REGISTRY;

sub registry_add {
    my $class   = shift;
    my %schemas = @_;
    while ( my ( $key, $object ) = each(%schemas) ) {
        $REGISTRY{$key} = $object;
    }
}

sub registry_lookup {
    my $class     = shift;
    my @possibles = @_;
    foreach my $find (@possibles) {
        next unless defined $find;
        if ( exists $REGISTRY{$find} and defined $REGISTRY{$find} ) {
            return $REGISTRY{$find};
        }
        while ( my ( $key, $schema ) = each %REGISTRY ) {
            if ( lc($find) eq lc($key) ) {
                return $schema;
            }
        }
    }
    return;

}

sub registry_list {
    my $class = shift;
    my %seen;
    return grep { not $seen{ $_->id }++ } values %REGISTRY;
}

1;

=head1 NAME

WWW::GoDaddy::REST::Schema - schema specific resource class

=head1 SYNOPSIS

  $schema  = $client->schema('the_name');
  $scehama = $resource->schema(); 

=head1 DESCRIPTION

This is used to represent a 'schema' which is a very common resource in the
Go Daddy(r) API specification.

It is a sub class of L<WWW::GoDaddy::REST::Resource>.

=head1 METHODS

TODO: You'll have to read code to understand the methods listed here for
now.  See L<WWW::GoDaddy::REST::Resource> for at least some of this.

=head1 AUTHOR

David Bartle, C<< <davidb@mediatemple.net> >>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2014 Go Daddy Operating Company, LLC

Permission is hereby granted, free of charge, to any person obtaining a 
copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the 
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.

=cut
