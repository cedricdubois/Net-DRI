## Domain Registry Interface, CNNIC CND (Chinese Domain Name) EPP Charge Extension
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

package Net::DRI::Protocol::EPP::Extensions::CNNIC::CDN;

use strict;
use warnings;

use Net::DRI::Util;
use Net::DRI::Exception;
use Data::Dumper;

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::CNNIC::CDN - CNNIC CND (Chinese Domain Name)

=head1 DESCRIPTION

Adds the EPP Extension for provisioning and management of Chinese Domain Names (CDNs), especially for variant CDNs.

Base on : http://tools.ietf.org/html/draft-kong-epp-cdn-mapping-00

The CDN is make up of a hash containing the following keys

=item ocnd [Punycode Domain Name]

=item scnd

=item tcnd [Punycode Domain Name]

=item vcnd [Punycode Domain Name]


=item restore [price for restore]

 # check and create
 
 $rc = $dri->domain_check('premium.tld');
 my $ch = $dri->get_info('charge');
 if ($ch->{create} < '1000000000.00') { 
   $rc=$dri->domain_create('premium.tld',{pure_create=>1,auth=>{pw=>'2fooBAR'},......,'charge' => $ch}); 
 }
 
 # info and transfer
 $rc = $dri->domain_info('premium.tld');
 my $ch = $dri->get_info('charge');
 $rc=$dri->domain_transfer_start('premium.tld',{...,'charge' => $ch}); 
 

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
           info => [ undef, \&parse],
           transfer_query => [ undef, \&parse ],
           create => [ \&create, \&parse ],
           delete => [ undef, \&parse ],
           update => [ \&update, \&parse ],
           transfer_request => [ \&transfer, \&parse ],
           renew => [ \&renew, \&parse ],
        );

 return { 'domain' => \%tmp };
}

sub setup
{
 my ($self,$po) = @_;
 $po->ns({'cdn' =>['urn:ietf:params:xml:ns:cdn-1.0','cdn-1.0.xsd']});
 $po->capabilities('domain_update','cnd',['add','rem']);

}
## FIXME use the one in Util.pm when its merged!
sub idn_get_ace_unicode
{
 my $domain = shift;
 eval { require Net::IDN::Encode; };
 return ($domain,$domain) if $@;
 my $idn = ($domain =~ m/^xn--/) ? Net::IDN::Encode::domain_to_unicode($domain):$domain;
 my $ace = ($domain !~ m/^[a-z0-9.-]/) ? Net::IDN::Encode::domain_to_ascii($domain):$domain; 
 return ($ace,$idn);
}
##

####################################################################################################
## Parsing

sub _parse_cdn
{
 my $start = shift;
 return unless $start;
 my ($key,$cdn,$ace,$idn,$vcdn,@vcdns);
 foreach my $el (Net::DRI::Util::xml_list_children($start)) 
 {
  my ($n,$c)=@$el;
  if ($n =~ m/^([OST]CDN)/)
  {
   $key = substr $n,0,4;
   ($ace,$idn) = idn_get_ace_unicode($c->textContent());
   $cdn->{lc($1)}->{ace} = $ace;
   $cdn->{lc($1)}->{idn} = $idn;
  } elsif ($n eq 'VCDNList')
  {
   foreach my $el2 (Net::DRI::Util::xml_list_children($c)) 
   {
    my ($n2,$c2)=@$el2;
    next if $n2 ne 'VCDN';
    ($ace,$idn) = idn_get_ace_unicode($c2->textContent());
    $vcdn = { ace=>$ace,idn=>$idn};
    push @vcdns,$vcdn;
   }
   @{$cdn->{vcdns}} = @vcdns;
  }
  
 }
 return $cdn;
}

sub parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();

 foreach my $ex (qw/infData creData upData delData renData trnData/)
 {
  next unless my $resdata=$mes->get_extension($mes->ns('cdn'),$ex);
  $rinfo->{domain}->{$oname}->{cdn} = _parse_cdn($resdata);
  return;
 }
 return;
}

####################################################################################################
## Build / Parse helprs

sub _build_cdn
{
 my $cdn = shift;
# print Dumper $cdn;

 return unless $cdn;
 my @n;
 my ($t,$p,$xmlkey);
 foreach my $key (qw/ocdn ocdn_punycode scdn scdn_punycode tcdn tcdn_punycode/)
 {
  next unless exists $cdn->{$key};
  ($t,$p) = split '_',$key;
  $xmlkey = uc($t) . ($p ? 'Punycode':'');
  push @n, ['cdn:'.$xmlkey,$cdn->{$key}];
 }
 if (exists $cdn->{vcdns})
 {
  my @v;
  foreach my $vcdn (@{$cdn->{vcdns}})
  {
   push @v, ['cdn:'.'VCDN',$vcdn->{'vcdn'}] if exists $vcdn->{'vcdn'};
   push @v, ['cdn:'.'VCDNPunycode',$vcdn->{'vcdn_punycode'}] if exists $vcdn->{'vcdn_punycode'};
  }
  push @n, ['cdn:VCDNList',@v];
 }
 print Dumper @n;
 return @n;
}

sub transform_build
{
 my ($epp,$domain,$rd,$cmd)=@_;
 my $mes=$epp->message();
 return unless Net::DRI::Util::has_key($rd,'cdn'); 
 my @n = _build_cdn($rd->{'cdn'});
 return unless @n;
 my $eid=$mes->command_extension_register('cdn',$cmd);
 $mes->command_extension($eid,\@n);
 print Dumper $eid;
 return;
}

sub create { transform_build(@_,'create'); }
sub transfer { transform_build(@_,'transfer'); }
sub renew { transform_build(@_,'renew'); }

sub update {
   my ($epp,$domain,$todo)=@_;
   return unless my $ch = $todo->set('charge');
   transform_build($epp,$domain,{'charge' => $ch},'restore'); 
}

1;