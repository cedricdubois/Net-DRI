#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Net::DRI;
use Net::DRI::Data::Raw;
use DateTime::Duration;
use Data::Dumper;


use Test::More tests => 33;
eval { no warnings; require Test::LongString; Test::LongString->import(max => 100); $Test::LongString::Context=50; };
if ( $@ ) { no strict 'refs'; *{'main::is_string'}=\&main::is; }

our $E1='<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd">';
our $E2='</epp>';
our $TRID='<trID><clTRID>ABC-12345</clTRID><svTRID>54322-XYZ</svTRID></trID>';

our ($R1,$R2);
sub mysend { my ($transport,$count,$msg)=@_; $R1=$msg->as_string(); return 1; }
sub myrecv { return Net::DRI::Data::Raw->new_from_string($R2? $R2 : $E1.'<response>'.r().$TRID.'</response>'.$E2); }
sub r      { my ($c,$m)=@_; return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>'; }

my $dri=Net::DRI::TrapExceptions->new({cache_ttl => 10});
$dri->{trid_factory}=sub { return 'ABC-12345'; };
$dri->add_registry('NGTLD',{provider=>'cnnic'});
$dri->target('cnnic')->add_current_profile('p1','epp',{f_send=>\&mysend,f_recv=>\&myrecv});

my $rc;
my $s;
my $d;
my ($dh,$command,$cdn,@c,$toc,$cs,$c1,$c2);

################################################################################
### Contact Operations


################################################################################
### CDN (Chinese Domain Name) Extension
### EPP Query Commands ###

# Info with punycode
$R2=$E1.'<response>'.r().'<resData><domain:infData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name><domain:roid>58812678-domain</domain:roid><domain:status s="ok" /><domain:registrant>123</domain:registrant><domain:contact type="admin">123</domain:contact><domain:contact type="tech">123</domain:contact><domain:ns><domain:hostObj>ns1.example.cn</domain:hostObj></domain:ns><domain:clID>ClientX</domain:clID><domain:crID>ClientY</domain:crID><domain:crDate>2011-04-03T22:00:00.0Z</domain:crDate><domain:exDate>2012-04-03T22:00:00.0Z</domain:exDate><domain:authInfo><domain:pw>2fooBAR</domain:pw></domain:authInfo></domain:infData></resData><extension><cdn:infData xmlns:cdn="urn:ietf:params:xml:ns:cdn-1.0"><cdn:OCDNPunycode>xn--fsq270a.xn--fiqs8s</cdn:OCDNPunycode><cdn:SCDN>实例.中国</cdn:SCDN><cdn:SCDNPunycode>xn--fsq270a.xn--fiqs8s</cdn:SCDNPunycode><cdn:TCDN>實例.中國</cdn:TCDN><cdn:TCDNPunycode>xn--fsqz41a.xn--fiqz9s</cdn:TCDNPunycode><cdn:VCDNList><cdn:VCDN>実例.中國</cdn:VCDN><cdn:VCDNPunycode>xn--fsq470a.xn--fiqz9s</cdn:VCDNPunycode></cdn:VCDNList></cdn:infData></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_info('xn--fsq270a.xn--fiqs8s');
is_string($R1,$E1.'<command><info><domain:info xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name hosts="all">xn--fsq270a.xn--fiqs8s</domain:name></domain:info></info><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_info build');
is($rc->is_success(),1,'domain_info is is_success');
is($dri->get_info('action'),'info','domain_info get_info (action)');
is($dri->get_info('name'),'xn--fsq270a.xn--fiqs8s','domain_info get_info (name)');
$cdn = $dri->get_info('cdn');
is_deeply($cdn->{ocdn},{ace=>'xn--fsq270a.xn--fiqs8s',idn=>'实例.中国'},'domain_info get_info (cdn) ocdn');
is_deeply($cdn->{scdn},{ace=>'xn--fsq270a.xn--fiqs8s',idn=>'实例.中国'},'domain_info get_info (cdn) scdn');
is_deeply($cdn->{tcdn},{ace=>'xn--fsqz41a.xn--fiqz9s',idn=>'實例.中國'},'domain_info get_info (cdn) tcdn');
is_deeply($cdn->{vcdns}->[0],{ace=>'xn--fsq470a.xn--fiqz9s',idn=>'実例.中國'},'domain_info get_info (cdn) vcdns');

# Transfer query
$R2=$E1.'<response>'.r().'<resData><domain:trnData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name><domain:roid>58812678-domain</domain:roid><domain:trStatus>pending</domain:trStatus><domain:reID>ClientX</domain:reID><domain:reDate>2000-06-06T22:00:00.0Z</domain:reDate><domain:acID>ClientY</domain:acID><domain:acDate>2000-06-11T22:00:00.0Z</domain:acDate><domain:exDate>2002-09-08T22:00:00.0Z</domain:exDate></domain:trnData></resData><extension><cdn:trnData xmlns:cdn="urn:ietf:params:xml:ns:cdn-1.0"><cdn:SCDN>实例.中国</cdn:SCDN><cdn:TCDN>實例.中國</cdn:TCDN><cdn:VCDNList><cdn:VCDN>実例.中國</cdn:VCDN></cdn:VCDNList></cdn:trnData></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_transfer_query('xn--fsq270a.xn--fiqs8s');
is($dri->get_info('action'),'transfer','domain_transfer_query get_transfer (action)');
is($dri->get_info('name'),'xn--fsq270a.xn--fiqs8s','domain_transfer_query get_info (name)');
is($dri->get_info('trStatus'),'pending','domain_transfer_query get_info (trStatus)');
$cdn = $dri->get_info('cdn');
is_deeply($cdn->{scdn},{ace=>'xn--fsq270a.xn--fiqs8s',idn=>'实例.中国'},'domain_transfer_query get_info (cdn) scdn');
is_deeply($cdn->{tcdn},{ace=>'xn--fsqz41a.xn--fiqz9s',idn=>'實例.中國'},'domain_transfer_query get_info (cdn) tcdn');
is_deeply($cdn->{vcdns}->[0],{ace=>'xn--fsq470a.xn--fiqz9s',idn=>'実例.中國'},'domain_transfer_query get_info (cdn) vcdns');

################################################################################
### EPP Transform Commands ###

## Create
$R2=$E1.'<response>'.r().'<resData><domain:creData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name><domain:crDate>1999-04-03T22:00:00.0Z</domain:crDate><domain:exDate>2001-04-03T22:00:00.0Z</domain:exDate></domain:creData></resData>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_create('xn--fsq270a.xn--fiqs8s',{
  pure_create=>1,
  duration=>DateTime::Duration->new(years=>2),
  auth=>{pw=>'2fooBAR'},
  cdn=>{vcdns=>[{idn=>'実例.中國'}]},
  });
$command = $E1.'<command><create><domain:create xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name><domain:period unit="y">2</domain:period><domain:authInfo><domain:pw>2fooBAR</domain:pw></domain:authInfo></domain:create></create><extension><cdn:create xmlns:cdn="urn:ietf:params:xml:ns:cdn-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:cdn-1.0 cdn-1.0.xsd"><cdn:VCDNList><cdn:VCDN>実例.中國</cdn:VCDN></cdn:VCDNList></cdn:create></extension><clTRID>ABC-12345</clTRID></command>'.$E2;
is_string($R1,$command,'domain_create build');
is($rc->is_success(),1,'domain_create is is_success');
is($dri->get_info('action'),'create','domain_create get_info (action)');


## Delete
$R2=$E1.'<response>'.r().'<extension><cdn:delData xmlns:cdn="urn:ietf:params:xml:ns:cdn-1.0"><cdn:SCDN>实例.中国</cdn:SCDN><cdn:TCDN>實例.中國</cdn:TCDN><cdn:VCDNList><cdn:VCDN>実例.中國</cdn:VCDN></cdn:VCDNList></cdn:delData></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_delete('xn--fsq270a.xn--fiqs8s');
is($rc->is_success(),1,'domain_delete is is_success');
$cdn = $dri->get_info('cdn');
is_deeply($cdn->{scdn},{ace=>'xn--fsq270a.xn--fiqs8s',idn=>'实例.中国'},'domain_delete get_info (cdn) scdn');
is_deeply($cdn->{tcdn},{ace=>'xn--fsqz41a.xn--fiqz9s',idn=>'實例.中國'},'domain_delete get_info (cdn) tcdn');
is_deeply($cdn->{vcdns}->[0],{ace=>'xn--fsq470a.xn--fiqz9s',idn=>'実例.中國'},'domain_delete get_info (cdn) vcdns');


## Renew
$R2=$E1.'<response>'.r().'<resData><domain:renData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name><domain:exDate>2005-04-03T22:00:00.0Z</domain:exDate></domain:renData></resData><extension><cdn:renData xmlns:cdn="urn:ietf:params:xml:ns:cdn-1.0"><cdn:SCDN>实例.中国</cdn:SCDN><cdn:TCDN>實例.中國</cdn:TCDN><cdn:VCDNList><cdn:VCDN>実例.中國</cdn:VCDN></cdn:VCDNList></cdn:renData></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_renew('xn--fsq270a.xn--fiqs8s',{duration => DateTime::Duration->new(years=>5), current_expiration => DateTime->new(year=>2000,month=>4,day=>3)});
is_string($R1,$E1.'<command><renew><domain:renew xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name><domain:curExpDate>2000-04-03</domain:curExpDate><domain:period unit="y">5</domain:period></domain:renew></renew><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_renew build');
is($rc->is_success(),1,'domain_renew is is_success');
$cdn = $dri->get_info('cdn');
is_deeply($cdn->{scdn},{ace=>'xn--fsq270a.xn--fiqs8s',idn=>'实例.中国'},'domain_renew get_info (cdn) scdn');
is_deeply($cdn->{tcdn},{ace=>'xn--fsqz41a.xn--fiqz9s',idn=>'實例.中國'},'domain_renew get_info (cdn) tcdn');
is_deeply($cdn->{vcdns}->[0],{ace=>'xn--fsq470a.xn--fiqz9s',idn=>'実例.中國'},'domain_renew get_info (cdn) vcdns');

## Transfer
$R2=$E1.'<response>'.r().'<resData><domain:trnData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name><domain:trStatus>pending</domain:trStatus><domain:reID>ClientX</domain:reID><domain:reDate>2000-06-08T22:00:00.0Z</domain:reDate><domain:acID>ClientY</domain:acID><domain:acDate>2000-06-13T22:00:00.0Z</domain:acDate><domain:exDate>2002-09-08T22:00:00.0Z</domain:exDate></domain:trnData></resData><extension><cdn:trnData xmlns:cdn="urn:ietf:params:xml:ns:cdn-1.0"><cdn:SCDN>实例.中国</cdn:SCDN><cdn:TCDN>實例.中國</cdn:TCDN><cdn:VCDNList><cdn:VCDN>実例.中國</cdn:VCDN></cdn:VCDNList></cdn:trnData></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_transfer_start('xn--fsq270a.xn--fiqs8s',{auth => {pw=>'2fooBAR',roid=>"JD1234-REP"},duration=>DateTime::Duration->new(years=>1),fee=>{currency=>'USD',fee=>'5.00'}});
is_string($R1,$E1.'<command><transfer op="request"><domain:transfer xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name><domain:period unit="y">1</domain:period><domain:authInfo><domain:pw roid="JD1234-REP">2fooBAR</domain:pw></domain:authInfo></domain:transfer></transfer><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_transfer build');
is($rc->is_success(),1,'domain_transfer is is_success');
is_deeply($cdn->{scdn},{ace=>'xn--fsq270a.xn--fiqs8s',idn=>'实例.中国'},'domain_transfer get_info (cdn) scdn');
is_deeply($cdn->{tcdn},{ace=>'xn--fsqz41a.xn--fiqz9s',idn=>'實例.中國'},'domain_transfer get_info (cdn) tcdn');
is_deeply($cdn->{vcdns}->[0],{ace=>'xn--fsq470a.xn--fiqz9s',idn=>'実例.中國'},'domain_transfer get_info (cdn) vcdns');

## Update
$R2=$E1.'<response>'.r().$TRID.'</response>'.$E2;
$toc=Net::DRI::Data::Changes->new();
my $adddelcdn = { vcdns=>[ {idn=>'実例.中國'} ] };
my $chgcdn = { tcdn=> {ace=>'xn--fsqz41a.xn--fiqz9s'} };
$toc->set('cdn',$chgcdn);
$toc->add('cdn',$adddelcdn);
$toc->del('cdn',$adddelcdn);

$rc=$dri->domain_update('xn--fsq270a.xn--fiqs8s',$toc);
is_string($R1,$E1.'<command><update><domain:update xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name></domain:update></update><extension><cdn:update xmlns:cdn="urn:ietf:params:xml:ns:cdn-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:cdn-1.0 cdn-1.0.xsd"><cdn:add><cdn:VCDN>実例.中國</cdn:VCDN></cdn:add><cdn:rem><cdn:VCDN>実例.中國</cdn:VCDN></cdn:rem><cdn:chg><cdn:TCDN>實例.中國</cdn:TCDN></cdn:chg></cdn:update></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_update build');
is($rc->is_success(),1,'domain_update is is_success');

exit;

####################################################################################################

exit 0;