# coding: UTF-8

require 'yaml'
require 'json'
require 'nokogiri'
require 'rest_client'
require 'sinatra'
set :protection, except: :ip_spoofing

get '/' do
  phrase = 'В советской России OpenStack желает вам «с днем рождения»'
  english = AzureTranslator.translate(phrase, 'ru', 'en')
  parts = SovietInverter.new(english).uninvert.data
  "#{parts['do'].capitalize} #{parts['io']}"
end

get '/src' do
  content_type 'text/plain'
  IO.read(__FILE__)
end


class AzureToken
  BASE_URL = 'https://datamarket.accesscontrol.windows.net/v2/OAuth2-13/'
  TOKEN_FILE = 'token.yaml'

  def self.create
    token = self.load
    token = self.request_new if token.nil? || token.expired?
    token
  end
  
  def to_s
    @data['access_token']
  end

  def expired?
    Time::now() > @data['created'] + @data['expires_in'].to_i
  end
  
  private
  def initialize(data)
    @data = data
    @data['created'] ||= Time.now
  end

  def self.request_new
    response = RestClient.post(BASE_URL,
      client_id: ENV['AZURE_CLIENT_ID'],
      client_secret: ENV['AZURE_CLIENT_SECRET'],
      scope: 'http://api.microsofttranslator.com',
      grant_type: 'client_credentials'
    )
    token = AzureToken.new(JSON.parse(response))
    File.open(TOKEN_FILE, 'w') {|file| file.write(token.to_yaml)}
    token
  end
  
  def self.load
    YAML.load(IO.read(TOKEN_FILE)) if File.exist?(TOKEN_FILE)
  end
end

class AzureTranslator
  URL = 'http://api.microsofttranslator.com/v2/Http.svc/Translate'
  def self.translate(text, from, to)
    token = AzureToken.create
    response = RestClient.get(URL, {
      params: {text: text, from: from, to: to},
      'Authorization' => 'Bearer ' + token.to_s
    })
    Nokogiri::XML(response).at_css('string').text
  end
end

class SovietInverter
  attr_reader :data

  def initialize(string)
    @string = string.gsub(/"/, '')
  end

  def invert
    @data = /^In America[,]? (?<subject>\w+) (?<verb>\w+) (?<io>\w+) (?<do>.+)[\.]?$/i.match(@string)
    self
  end
  
  def uninvert
    @data = /^In Soviet Russia[,]? (?<io>\w+) (?<verb>\w+) (?<subject>\w+) (?<do>.+)[\.]?$/i.match(@string)
    self
  end
end
