## Domain Registry Interface, CNNIC Contact EPP Extension
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

package Net::DRI::Protocol::EPP::Extensions::CNNIC::Contact;

use strict;
use warnings;

use Net::DRI::Util;
use Net::DRI::Exception;
use Data::Dumper;

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::CNNIC::Contact - CNNIC Contact Extensions

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
 my %tmp=(
           create   => [ \&create, \&parse],
           update   => [ \&update, \&parse],
           info   => [ undef, \&parse],
        );
 return { 'contact' => \%tmp };
}

sub setup
{
 my ($self,$po) = @_;
 $po->ns({'cnnic-contact' =>['urn:ietf:params:xml:ns:cnnic-contact-1.0','cnnic-contact-1.0.xsd']});
}

####################################################################################################
## Parsing

sub parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless my $data=$mes->get_extension($mes->ns('cnnic-contact'),'infData');
 foreach my $el (Net::DRI::Util::xml_list_children($data)) 
 {
  my ($n,$c)=@$el;
  $rinfo->{$otype}->{$oname}->{type} = $c->getAttribute('type') if $n eq 'contact' && $c->hasAttribute('type');
  $rinfo->{$otype}->{$oname}->{id} = $c->textContent() if $n eq 'contact';
 }
 return;
}

####################################################################################################
## Building

sub create
{
 my ($epp,$c)=@_;
 my $mes=$epp->message();
 return unless $c->type();
 Net::DRI::Exception::usererr_invalid_parameters('contact type should be one of YYZZ,ZZJGDMZ,SFZ,JGZ,HZ,QT') unless $c->type() =~ m/^(?:YYZZ|ZZJGDMZ|SFZ|JGZ|HZ|QT)$/;
 Net::DRI::Exception::usererr_invalid_parameters('contact id should be a string between 1 and 20 characters') unless Net::DRI::Util::xml_is_token($c->type(),1,20);
 my @n;
 push @n,['cnnic-contact:contact',{'type'=>ic($c->type())}, $c->id()];
 my $eid=$mes->command_extension_register('cnnic-registry','create');
 $mes->command_extension($eid,\@n);
 return;
}

sub update {
 my ($epp,$domain,$todo)=@_;
 my $mes=$epp->message();
 my (@n,$ace,$idn);


 return unless @n;
 my $eid=$mes->command_extension_register('cdn','update');
 $mes->command_extension($eid,\@n);
 return;
}

1;