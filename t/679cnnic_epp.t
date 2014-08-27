#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Net::DRI;
use Net::DRI::Data::Raw;
use DateTime::Duration;
use Data::Dumper;


use Test::More tests => 86;
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
#is($cdn->{vcdns}->[0]->{vcdn_punycode},'xn--fsq470a.xn--fiqz9s','domain_info get_info (cdn) vcdn_punycode');

# Info with native idn
SKIP: {
  skip 'TODO!!!!!!!!!!!!!!! Skipping info with native idn',1;
$R2=$E1.'<response>'.r().'<resData><domain:infData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0"><domain:name></domain:name><domain:roid>58812678-domain</domain:roid><domain:status s="ok" /><domain:registrant>123</domain:registrant><domain:contact type="admin">123</domain:contact><domain:contact type="tech">123</domain:contact><domain:ns><domain:hostObj>ns1.example.cn</domain:hostObj></domain:ns><domain:clID>ClientX</domain:clID><domain:crID>ClientY</domain:crID><domain:crDate>2011-04-03T22:00:00.0Z</domain:crDate><domain:exDate>2012-04-03T22:00:00.0Z</domain:exDate><domain:authInfo><domain:pw>2fooBAR</domain:pw></domain:authInfo></domain:infData></resData><extension> **** </extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_info('实例.中国');
};

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
  #cdn=>{vcdns=>[{vcdn=>'実例.中國'}]},
  });
#実例.中国
$command = $E1.'<command><create><domain:create xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>xn--fsq270a.xn--fiqs8s</domain:name><domain:period unit="y">2</domain:period><domain:authInfo><domain:pw>2fooBAR</domain:pw></domain:authInfo></domain:create></create><extension><cdn:create xmlns:cdn="urn:ietf:params:xml:ns:cdn-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:cdn-1.0 cdn-1.0.xsd"><cdn:VCDNList><cdn:VCDN>実例.中國</cdn:VCDN></cdn:VCDNList></cdn:create></extension><clTRID>ABC-12345</clTRID></command>'.$E2;
#utf8::encode($command);
is_string($R1,$command,'domain_create build');
is($rc->is_success(),1,'domain_create is is_success');
is($dri->get_info('action'),'create','domain_create get_info (action)');
#exit;



## Delete
$R2=$E1.'<response>'.r().'<extension><cdn:delData xmlns:cdn="urn:ietf:params:xml:ns:cdn-1.0"><cdn:SCDN>实例.中国</cdn:SCDN><cdn:TCDN>實例.中國</cdn:TCDN><cdn:VCDNList><cdn:VCDN>実例.中國</cdn:VCDN></cdn:VCDNList></cdn:delData></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_delete('xn--fsq270a.xn--fiqs8s');
is($rc->is_success(),1,'domain_delete is is_success');
$cdn = $dri->get_info('cdn');
is_deeply($cdn->{scdn},{ace=>'xn--fsq270a.xn--fiqs8s',idn=>'实例.中国'},'domain_delete get_info (cdn) scdn');
is_deeply($cdn->{tcdn},{ace=>'xn--fsqz41a.xn--fiqz9s',idn=>'實例.中國'},'domain_delete get_info (cdn) tcdn');
is_deeply($cdn->{vcdns}->[0],{ace=>'xn--fsq470a.xn--fiqz9s',idn=>'実例.中國'},'domain_delete get_info (cdn) vcdns');
exit;


## Renew
$R2=$E1.'<response>'.r().'<resData><domain:renData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>exdomain.kiwi</domain:name><domain:exDate>2005-04-03T22:00:00.0Z</domain:exDate></domain:renData></resData><extension><fee:renData xmlns:fee="urn:ietf:params:xml:ns:fee-0.5" xsi:schemaLocation="urn:ietf:params:xml:ns:fee-0.5 fee-0.5.xsd"><fee:currency>USD</fee:currency><fee:fee>5.00</fee:fee></fee:renData></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_renew('exdomain.kiwi',{duration => DateTime::Duration->new(years=>5), current_expiration => DateTime->new(year=>2000,month=>4,day=>3),fee=>{currency=>'USD',fee=>'5.00'}});
is_string($R1,$E1.'<command><renew><domain:renew xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>exdomain.kiwi</domain:name><domain:curExpDate>2000-04-03</domain:curExpDate><domain:period unit="y">5</domain:period></domain:renew></renew><extension><fee:renew xmlns:fee="urn:ietf:params:xml:ns:fee-0.5" xsi:schemaLocation="urn:ietf:params:xml:ns:fee-0.5 fee-0.5.xsd"><fee:currency>USD</fee:currency><fee:fee>5.00</fee:fee></fee:renew></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'Fee extension: domain_renew build');
is($rc->is_success(),1,'domain_renew is is_success');
$d=$rc->get_data('fee');
is($d->{currency},'USD','Fee extension: domain_renew parse currency');
is($d->{fee},5.00,'Fee extension: domain_renew parse fee');

## Transfer
$R2=$E1.'<response>'.r().'<resData><domain:trnData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>exdomain.kiwi</domain:name><domain:trStatus>pending</domain:trStatus><domain:reID>ClientX</domain:reID><domain:reDate>2000-06-08T22:00:00.0Z</domain:reDate><domain:acID>ClientY</domain:acID><domain:acDate>2000-06-13T22:00:00.0Z</domain:acDate><domain:exDate>2002-09-08T22:00:00.0Z</domain:exDate></domain:trnData></resData><extension><fee:trnData xmlns:fee="urn:ietf:params:xml:ns:fee-0.5" xsi:schemaLocation="urn:ietf:params:xml:ns:fee-0.5 fee-0.5.xsd"><fee:currency>USD</fee:currency><fee:fee>5.00</fee:fee></fee:trnData></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_transfer_start('exdomain.kiwi',{auth => {pw=>'2fooBAR',roid=>"JD1234-REP"},duration=>DateTime::Duration->new(years=>1),fee=>{currency=>'USD',fee=>'5.00'}});
is_string($R1,$E1.'<command><transfer op="request"><domain:transfer xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>exdomain.kiwi</domain:name><domain:period unit="y">1</domain:period><domain:authInfo><domain:pw roid="JD1234-REP">2fooBAR</domain:pw></domain:authInfo></domain:transfer></transfer><extension><fee:transfer xmlns:fee="urn:ietf:params:xml:ns:fee-0.5" xsi:schemaLocation="urn:ietf:params:xml:ns:fee-0.5 fee-0.5.xsd"><fee:currency>USD</fee:currency><fee:fee>5.00</fee:fee></fee:transfer></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'Fee extension: domain_transfer build');
is($rc->is_success(),1,'domain_transfer is is_success');
$d=$rc->get_data('fee');
is($d->{currency},'USD','Fee extension: domain_transfer parse currency');
is($d->{fee},5.00,'Fee extension: domain_transfer parse fee');

## Update
$R2=$E1.'<response>'.r().'<extension><fee:updData xmlns:fee="urn:ietf:params:xml:ns:fee-0.5" xsi:schemaLocation="urn:ietf:params:xml:ns:fee-0.5 fee-0.5.xsd"><fee:currency>USD</fee:currency><fee:fee>5.00</fee:fee></fee:updData></extension>'.$TRID.'</response>'.$E2;
$toc=Net::DRI::Data::Changes->new();
$toc->set('registrant',$dri->local_object('contact')->srid('sh8013'));
$toc->set('fee',{currency=>'USD',fee=>'5.00'});
$rc=$dri->domain_update('exdomain.kiwi',$toc);
is_string($R1,$E1.'<command><update><domain:update xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>exdomain.kiwi</domain:name><domain:chg><domain:registrant>sh8013</domain:registrant></domain:chg></domain:update></update><extension><fee:update xmlns:fee="urn:ietf:params:xml:ns:fee-0.5" xsi:schemaLocation="urn:ietf:params:xml:ns:fee-0.5 fee-0.5.xsd"><fee:currency>USD</fee:currency><fee:fee>5.00</fee:fee></fee:update></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'Fee extension: domain_update build');
is($rc->is_success(),1,'domain_update is is_success');
$d=$rc->get_data('fee');
is($d->{currency},'USD','Fee extension: domain_transfer parse currency');
is($d->{fee},5.00,'Fee extension: domain_transfer parse fee');
### END: EPP Transform Commands ###
####################################################################################################

## Claims check
my $lp = {type=>'claims'};
$R2=$E1.'<response>'.r().'<extension><launch:chkData xmlns:launch="urn:ietf:params:xml:ns:launch-1.0"><launch:phase>claims</launch:phase><launch:cd><launch:name exists="1">exdomain.kiwi</launch:name><launch:claimKey validatorID="sample">2013041500/2/6/9/rJ1NrDO92vDsAzf7EQzgjX4R0000000001</launch:claimKey></launch:cd></launch:chkData></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_check('exdomain.kiwi',{lp => $lp});
is ($R1,$E1.'<command><check><domain:check xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>exdomain.kiwi</domain:name></domain:check></check><extension><launch:check xmlns:launch="urn:ietf:params:xml:ns:launch-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:launch-1.0 launch-1.0.xsd" type="claims"><launch:phase>claims</launch:phase></launch:check></extension><clTRID>ABC-12345</clTRID></command></epp>','domain_check build_xml');
my $lpres = $dri->get_info('lp');
is($lpres->{'exist'},1,'domain_check get_info(exist)');
is($lpres->{'phase'},'claims','domain_check get_info(phase) ');
is($lpres->{'claim_key'},'2013041500/2/6/9/rJ1NrDO92vDsAzf7EQzgjX4R0000000001','domain_check get_info(claim_key) ');
is($lpres->{'validator_id'},'sample','domain_check get_info(validator_id) ');


exit 0;
