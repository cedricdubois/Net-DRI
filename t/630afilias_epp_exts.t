#!/usr/bin/perl

use strict;
use warnings;

use Net::DRI;
use Net::DRI::Data::Raw;

use Test::More tests => 29;

eval { no warnings; require Test::LongString; Test::LongString->import(max => 100); $Test::LongString::Context=50; };
if ( $@ ) { no strict 'refs'; *{'main::is_string'}=\&main::is; }

our $E1='<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd">';
our $E2='</epp>';
our $TRID='<trID><clTRID>ABC-12345</clTRID><svTRID>54322-XYZ</svTRID></trID>';

our ($R1,$R2);
sub mysend { my ($transport, $count, $msg) = @_; $R1 = $msg->as_string(); return 1; }
sub myrecv { return Net::DRI::Data::Raw->new_from_string($R2 ? $R2 : $E1.'<response>'.r().$TRID.'</response>'.$E2); }
sub r { my ($c,$m)=@_;  return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>'; }

my $dri=Net::DRI::TrapExceptions->new({cache_ttl => -1});
$dri->{trid_factory}=sub { return 'ABC-12345'; };
$dri->add_registry('INFO',{clid => 'ClientX'});
$dri->target('INFO')->add_current_profile('p1','epp',{f_send=>\&mysend,f_recv=>\&myrecv});

my ($rc,$ok,$cs,$st,$p);

####################################################################################################
## Restore a deleted domain
$R2 = $E1 . '<response>' . r(1001,'Command completed successfully; ' .
	'action pending') . $TRID . '</response>' . $E2;

$ok=eval {
	$rc = $dri->domain_renew('deleted-by-accident.info', {
		current_expiration => new DateTime(year => 2008, month => 12,
			day => 24),
		rgp => 1});
	1;
};
print(STDERR $@->as_string()) if ! $ok;
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'Domain successfully recovered');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><renew><domain:renew xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>deleted-by-accident.info</domain:name><domain:curExpDate>2008-12-24</domain:curExpDate></domain:renew></renew><extension><rgp:renew xmlns:rgp="urn:EPP:xml:ns:ext:rgp-1.0" xsi:schemaLocation="urn:EPP:xml:ns:ext:rgp-1.0 rgp-1.0.xsd"><rgp:restore/></rgp:renew></extension><clTRID>ABC-12345</clTRID></command></epp>', 'Recover Domain XML correct');

####################################################################################################
## OXRS
$R2=$E1."<response><result code='2005'><msg lang='en-US'>Parameter value syntax error</msg><value xmlns:oxrs='urn:afilias:params:xml:ns:oxrs-1.0'><oxrs:xcp>2005:Parameter value syntax error (ContactAuthInfoType:AUTHT range (6-16))</oxrs:xcp></value></result>".$TRID."</response>".$E2;

$rc=$dri->domain_check('toto.info');
is_deeply([$rc->get_extended_results()],[{from=>'oxrs',type=>'text',message=>'2005:Parameter value syntax error (ContactAuthInfoType:AUTHT range (6-16))'}],'oxrs error message parsing');



####################################################################################################
## Registrar Extension
$R2=$E1.'<response>'.r().'<resData><registrar:infData xmlns:registrar="urn:ietf:params:xml:ns:registrar-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:registrar-1.0 registrar-1.0.xsd">
  <registrar:id>ClientX</registrar:id>
  <registrar:roid>R3003-LRMS</registrar:roid>
  <registrar:user>ClientX</registrar:user>
  <registrar:ctID>ClientX-R</registrar:ctID>
  <registrar:contact type="admin">ClientX-Ra</registrar:contact>
  <registrar:contact type="billing">ClientX-Rb</registrar:contact>
  <registrar:contact type="tech">ClientX-Rt</registrar:contact>
  <registrar:crID>admin</registrar:crID>
  <registrar:crDate>2012-04-13T20:29:31.0Z</registrar:crDate>
  <registrar:status s="ok"/>
  <registrar:portfolio name="afilias">
    <registrar:balance>100</registrar:balance>
    <registrar:threshold>1.00</registrar:threshold>
  </registrar:portfolio>
  <registrar:category>A</registrar:category>
  </registrar:infData>
  </resData>'.$TRID.'</response>'.$E2;

# basic / plain text info
#$rc = $dri->registrar_info("ClientX");
$rc = $dri->registrar_info(); # uses current clid from add_registry

is($R1,$E1.'<command><info><registrar:info xmlns:registrar="urn:ietf:params:xml:ns:registrar-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:registrar-1.0 registrar-1.0.xsd"><registrar:id>ClientX</registrar:id></registrar:info></info><clTRID>ABC-12345</clTRID></command></epp>','registrar_info build_xml');
is($dri->get_info('id'),'ClientX','registrar_info({id => "ClientX"})');
is($dri->get_info('roid'),'R3003-LRMS','registrar_info({roid => "R3003-LRMS"})');
is($dri->get_info('user'),'ClientX','registrar_info({user => "ClientX"})');
is($dri->get_info('ctID'),'ClientX-R','registrar_info({ctID => "ClientX-R"})');
is($dri->get_info('crID'),'admin','registrar_info({crID => "admin"})');
is($dri->get_info('crDate'),'2012-04-13T20:29:31','registrar_info({crDate => "2012-04-13T20:29:31"})');
is($dri->get_info('category'),'A','registrar_info({category => "A"})');

# contacts
$cs = $dri->get_info('contact');
isa_ok($cs,'Net::DRI::Data::ContactSet','registrar_info get_info(contact)');
is ($cs->contact_admin()->id(),'ClientX-Ra','registrar_info({contact type=admin => "ClientX-Ra"})');
is ($cs->contact_billing()->id(),'ClientX-Rb','registrar_info({contact type=billing => "ClientX-Rb"})');
is ($cs->contact_tech()->id(),'ClientX-Rt','registrar_info({contact type=tech => "ClientX-Rt"})');

# status - either ok / lock
$st = $dri->get_info('status');
isa_ok($st,'Net::DRI::Protocol::EPP::Core::Status','registrar_info get_info(status)');
is_deeply([$st->list_status()],['ok'],'registrar_info({status s="ok"}');

# portfolio
$p = shift $dri->get_info('portfolio'); # first array element
is($p->{name},'afilias','registrar_info({portfolio name="afilias"})');
is($p->{'balance'},'100','registrar_info({balance => "100"})');
is($p->{'threshold'},'1.00','registrar_info({threshold => "1.00"})');

# plain balance/threshold
is($dri->get_info('balance'),'100','registrar_info({balance => "100"})');
is($dri->get_info('threshold'),'1.00','registrar_info({threshold => "1.00"})');


####################################################################################################
## IDN Extension

# Old method
$R2=$E1.'<response>'.r().'<resData><domain:chkData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:cd><domain:name avail="1">example3.info</domain:name></domain:cd></domain:chkData></resData>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_check('example3.info',{'language'=>'zh'});
is($R1,$E1.'<command><check><domain:check xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>example3.info</domain:name></domain:check></check><extension><idn:check xmlns:idn="urn:afilias:params:xml:ns:idn-1.0" xsi:schemaLocation="urn:afilias:params:xml:ns:idn-1.0 idn-1.0.xsd"><idn:script>zh</idn:script></idn:check></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_check idn old build');
is($rc->is_success(),1,'domain_check idn old is_success');

# New method (with IDN Object)
$R2=$E1.'<response>'.r().'<resData><domain:chkData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:cd><domain:name avail="1">example3.info</domain:name></domain:cd></domain:chkData></resData>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_check('example3.info',{'idn' => $dri->local_object('idn')->autodetect('','zh') });
is($R1,$E1.'<command><check><domain:check xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>example3.info</domain:name></domain:check></check><extension><idn:check xmlns:idn="urn:afilias:params:xml:ns:idn-1.0" xsi:schemaLocation="urn:afilias:params:xml:ns:idn-1.0 idn-1.0.xsd"><idn:script>zh</idn:script></idn:check></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_check idn new build');
is($rc->is_success(),1,'domain_check idn new is_success');

# New method (with IDN Object and extlang)
$R2=$E1.'<response>'.r().'<resData><domain:chkData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:cd><domain:name avail="1">example3.info</domain:name></domain:cd></domain:chkData></resData>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_check('example3.info',{'idn' => $dri->local_object('idn')->autodetect('','zh-tw') });
is($R1,$E1.'<command><check><domain:check xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>example3.info</domain:name></domain:check></check><extension><idn:check xmlns:idn="urn:afilias:params:xml:ns:idn-1.0" xsi:schemaLocation="urn:afilias:params:xml:ns:idn-1.0 idn-1.0.xsd"><idn:script>zh-tw</idn:script></idn:check></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_check idn new with extlang build');
is($rc->is_success(),1,'domain_check idn new with extlang is_success');


exit(0);
