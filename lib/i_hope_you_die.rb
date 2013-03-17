# encoding: utf-8

require "savon"

module Savon
  class Builder
    def self.forced_output=(forced_output)
      @@forced_output = forced_output
    end

    def self.clear_forced_output
      @@forced_output = nil
    end

    def to_s
      if defined? @@forced_output and not @@forced_output.nil?
        @@forced_output
      else
        super
      end
    end
  end
end

class IHopeYouDie

  WSDL_PROD_AUTH = "https://ewus.nfz.gov.pl/ws-broker-server-ewus/services/Auth?wsdl"
  WSDL_PROD_BROK = "https://ewus.nfz.gov.pl/ws-broker-server-ewus/services/ServiceBroker?wsdl"
  WSDL_TEST_AUTH = "https://ewus.nfz.gov.pl/ws-broker-server-ewus-auth-test/services/Auth?wsdl"
  WSDL_TEST_BROK = "https://ewus.nfz.gov.pl/ws-broker-server-ewus-auth-test/services/ServiceBroker?wsdl"

  def initialize
    @prod = true
    @domain = '15' # '01'
    @login_type = ''
    @ident_string = ''

    @login = 'TEST1'
    @password = 'qwerty!@#'
  end

  attr_accessor :prod, :domain, :login_type, :ident_string, :login, :password

  def wsdl_auth
    if @prod
      WSDL_PROD_AUTH
    else
      WSDL_TEST_AUTH
    end
  end

  def wsdl_brok
    if @prod
      WSDL_PROD_BROK
    else
      WSDL_TEST_BROK
    end
  end

  def domain_string
    @domain.to_s || '01'
  end

  def login_type
    @login_type || 'SWD'
  end

  def ident_string
    @ident_string || '123456789'
  end

  def login
    @login || 'TEST'
  end

  def password
    @password || 'qwerty!@#'
  end

  def login_xml
    s = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:auth="http://xml.kamsoft.pl/ws/kaas/login_types">    <soapenv:Header/>    <soapenv:Body> 			 <auth:login> 				<auth:credentials>'
    unless domain_string.to_s == ''
      s += ' 					<auth:item> 						<auth:name>domain</auth:name> 						<auth:value><auth:stringValue>' + domain_string + '</auth:stringValue></auth:value> 					</auth:item>'
    end
    unless login_type.to_s == ''
      s += ' 					<auth:item> 						<auth:name>type</auth:name> 						<auth:value><auth:stringValue>' + login_type + '</auth:stringValue></auth:value> 					</auth:item>'
    end
    unless ident_string.to_s == ''
      s += ' 					<auth:item> 						<auth:name>idntSwd</auth:name> 						<auth:value><auth:stringValue>' + ident_string + '</auth:stringValue></auth:value> 					</auth:item>'
    end
    unless login.to_s == ''
      s += ' 					<auth:item> 						<auth:name>login</auth:name> 						<auth:value><auth:stringValue>' + login + '</auth:stringValue></auth:value> 					</auth:item>'
    end
    s += ' 				</auth:credentials> 		            	<auth:password>' + password + '</auth:password> 			</auth:login>    </soapenv:Body> </soapenv:Envelope>'
    return s
  end

  def brok_date
    '2008-09-12T09:37:36.406+01:00'
  end

  def session_id
    @session_id
  end

  def session_token
    @session_token
  end

  def cwu_xml(pesel)
    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:com="http://xml.kamsoft.pl/ws/common" xmlns:brok="http://xml.kamsoft.pl/ws/broker">    <soapenv:Header>       <com:session id="' + session_id + '" xmlns:ns1="http://xml.kamsoft.pl/ws/common"/>       <com:authToken id="' + session_token + '" xmlns:ns1="http://xml.kamsoft.pl/ws/common"/>    </soapenv:Header>    <soapenv:Body>       <brok:executeService>          <com:location>             <com:namespace>nfz.gov.pl/ws/broker/cwu</com:namespace>             <com:localname>checkCWU</com:localname>             <com:version>2.0</com:version>          </com:location>          <brok:date>' + brok_date + '</brok:date>          <brok:payload>             <brok:textload>                <ewus:status_cwu_pyt xmlns:ewus="https://ewus.nfz.gov.pl/ws/broker/ewus/status_cwu/v2">                   <ewus:numer_pesel>' + pesel + '</ewus:numer_pesel>                   <ewus:system_swiad nazwa="eWUŚ" wersja="2012.07.1.0"/>                </ewus:status_cwu_pyt>             </brok:textload>          </brok:payload>       </brok:executeService>    </soapenv:Body> </soapenv:Envelope>'
  end

  def auth!
    client_login = Savon::Client.new(wsdl: wsdl_auth)
    Savon::Builder.forced_output = login_xml
    response = client_login.call(:login)
    Savon::Builder.clear_forced_output

    login_doc = response.doc

    # get token and session id
    h = Hash.new
    login_doc.search('//soapenv:Envelope/soapenv:Header/*').each do |n|
      h[n.name] = n.attributes['id'].to_s
    end
    @session_token = h['authToken']
    @session_id = h['session']
  end

  def cwu_for_pesel(pesel)
    #puts "PESEL #{pesel}"

    xml = cwu_xml(pesel)

    puts "\n\n\n\n#{xml}\n\n\n"

    client = Savon::Client.new(wsdl: wsdl_brok)
    Savon::Builder.forced_output = xml
    response = client.call(:execute_service)
    Savon::Builder.clear_forced_output

    doc = response.doc
    return parse_cwu_response(doc)
  end

  def parse_cwu_response(doc)
    # fuck this shit.. regexp

    h = Hash.new

    keys = {
      time: 'ns3:date',
      cwu_status: 'ns2:status_cwu',
      pesel: 'ns2:numer_pesel',
      id_swiad: 'ns2:id_swiad',
      id_ow: 'ns2:id_ow',
      id_operatora: 'ns2:id_operatora',
      time_valid_to: 'ns2:data_waznosci_potwierdzenia',
      status_ubezp: 'ns2:status_ubezp',
      name: 'ns2:imie',
      surname: 'ns2:nazwisko'
    }

    s = doc.to_s
    keys.keys.each do |k|
      if s =~ /<#{keys[k]}>([^<]*)<\/#{keys[k]}>/
        h[k] = $1.to_s
      end
    end

    if s =~ /<ns2:status_cwu_odp([^>]+)>/
      t = $1

      if t =~ /id_operacji="([^"]+)"/
        h[:operation_id] = $1
      end

      if t =~ /data_czas_operacji="([^"]+)"/
        h[:operation_time] = $1
      end
    end
  end

  def check_pesels(pesels)
    pesels = [pesels] unless pesels.kind_of?(Array)
    return pesels.collect { |pesel| cwu_for_pesel(pesel) }
  end
end
