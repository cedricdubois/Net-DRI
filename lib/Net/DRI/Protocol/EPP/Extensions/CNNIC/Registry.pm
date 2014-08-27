## Domain Registry Interface, CNNIC Registry EPP Extension
##
## Copyright (c) 2014 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
##           (c) 2014 Michael Holloway <michael@thedarkwinter.com>. All rights reserved.
##
## This file is part of Net::DRI
##
## Net::DRI is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## See the LICENSE file that comes with this distribution for more details.
####################################################################################################

package Net::DRI::Protocol::EPP::Extensions::CNNIC::Registry;

use strict;
use warnings;

use Net::DRI::Util;
use Net::DRI::Exception;
use Data::Dumper;

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::CNNIC::Registry - CNNIC Registry Extensions

=head1 DESCRIPTION

Adds the EPP Registry extension

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt>

=head1 AUTHOR

Michael Holloway, E<lt>michael@thedarkwinter.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2014 Patrick Mevzek <netdri@dotandco.com>.
(c) 2014 Michael Holloway <michael@thedarkwinter.com>.
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

####################################################################################################

sub register_commands
{
 my ($class,$version)=@_;
 my %contact=(
           create   => [ \&contact_create, \&parse],
           info   => [ undef, \&parse],
        );
 my %host=(
           create   => [ \&host_create, \&parse],
           info   => [ undef, \&parse],
        );

 return { 'contact' => \%contact, 'host' => \%host };
}

sub setup
{
 my ($self,$po) = @_;
 $po->ns({'cnnic-registry' =>['urn:ietf:params:xml:ns:cnnic-registry-1.0','cnnic-registry-1.0.xsd']});
}

####################################################################################################
## Parsing
sub parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless my $data=$mes->get_extension($mes->ns('cnnic-registry'),'infData');
 foreach my $el (Net::DRI::Util::xml_list_children($data)) 
 {
  my ($n,$c)=@$el;
  $rinfo->{$otype}->{$oname}->{$n} = $c->textContent() if $n eq 'registry';
 }
 return;
}

####################################################################################################
## Building

sub contact_create
{
 my ($epp,$c)=@_;
 my $mes=$epp->message();
 my @n;
 push @n,['cnnic-registry:registry',$c->registry()];
 my $eid=$mes->command_extension_register('cnnic-registry','create');
 $mes->command_extension($eid,\@n);
 return;
}

# Fixme can I use one create for both?
sub host_create
{
 my ($epp,$h)=@_;
 my $mes=$epp->message();
 my @n;
 push @n,['cnnic-registry:registry',$h->registry()];
 my $eid=$mes->command_extension_register('cnnic-registry','create');
 $mes->command_extension($eid,\@n);
 return;
}
1;