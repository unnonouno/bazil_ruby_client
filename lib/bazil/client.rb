require 'forwardable'

require 'rubygems'
require 'json'
require 'net/http'
require 'net/https'
require 'bazil/application'
require 'bazil/rest'
require 'bazil/error'

module Bazil
  class Client
    extend Forwardable

    private

    CA_FILE_KEY = 'ca_file'

    VERSION_KEY = 'version'
    AVAILABLE_VERSIONS = {SSLv2: "SSLv2", SSLv3: "SSLv3", TLSv1: "TLSv1"}
    DEFAULT_VERSION = :TLSv1

    SKIP_VERIFY_KEY = 'skip_verify'
    DEFAULT_SKIP_VERIFY = false

    public

    def initialize(host, port, options=nil)
      @http_cli = REST.new(host, port)
      return if options.nil?

      if options.class == String then
        options = {CA_FILE_KEY => options}
      end
      options[VERSION_KEY] ||= DEFAULT_VERSION
      options[SKIP_VERIFY_KEY] ||= DEFAULT_SKIP_VERIFY

      unless options[CA_FILE_KEY].class == String && options[CA_FILE_KEY][0] == '/' then
        raise "ca_file option must be absolute path"
      end
      unless File::exists? options[CA_FILE_KEY] then
        raise "ca_file '#{options[CA_FILE_KEY]}' doesn't exists"
      end

      unless AVAILABLE_VERSIONS.has_key? options[VERSION_KEY] then
        raise "Unknwon SSL version: '#{options[VERSION_KEY]}'"
      end

      unless options[SKIP_VERIFY_KEY].class == TrueClass || options[SKIP_VERIFY_KEY].class == FalseClass then
        raise "skip_verify option must be boolean value"
      end

      @http_cli.use_ssl = true
      @http_cli.ca_file = options[CA_FILE_KEY]
      @http_cli.ssl_version = AVAILABLE_VERSIONS[options[VERSION_KEY]]
      @http_cli.verify_mode = options[SKIP_VERIFY_KEY] ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
    end

    def_delegators :@http_cli, :read_timeout, :read_timeout=, :set_api_keys

    def status
      res = @http_cli.get(gen_uri('status'))
      raise_error("Failed to get status of the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def config
      res = @http_cli.get(gen_uri('config'))
      raise_error("Failed to get config of the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def update_config(config)
      data = config.to_json
      res = @http_cli.put(gen_uri('config'), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise_error("Failed to update config of the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def errors
      res = @http_cli.get(gen_uri('errors'))
      raise_error("Failed to get information of errors from the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def clear_errors
      res = @http_cli.delete(gen_uri('errors'))
      raise_error("Failed to clear error information of the server", res) unless res.code =~ /2[0-9][0-9]/
      true
    end

    def application_names
      res = @http_cli.get(gen_uri('apps'))
      raise_error("Failed to get names of applications", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)['application_names']
    end

    def create_application(name, config = {})
      config = config.dup
      config['application_name'] = name
      data = config.to_json
      res, body = @http_cli.post(gen_uri('apps'), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise_error("Failed to create application: #{name}", res) unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      Application.new(self, name)
    end

    def delete_application(name)
      res, body = @http_cli.delete(gen_uri("apps/#{name}"))
      raise_error("Failed to delete application: #{name}", res) unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      true # TODO: return better information
    end

    def delete_all_applications
      res, body = @http_cli.delete("/#{api_version}")
      raise_error("Failed to delete applications: #{res.body}", res) unless res.code =~ /2[0-9][0-9]/
      true
    end

    def application(name)
      Application.new(self, name)
    end

    def http_client
      @http_cli
    end

    # TODO: make this changable
    def api_version
      'v1'
    end

    private

    def gen_uri(path)
      "/#{api_version}/#{path}"
    end

    def raise_error(message, res)
      raise APIError.new(message, res.code, JSON.parse(res.body))
    end
  end # class Client
end # module Bazil
