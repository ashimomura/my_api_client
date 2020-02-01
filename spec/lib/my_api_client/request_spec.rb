# frozen_string_literal: true

RSpec.describe MyApiClient::Request do
  class self::MockClass
    include MyApiClient::Request
    include MyApiClient::Config
    include MyApiClient::Exceptions
    include MyApiClient::ErrorHandling

    if ActiveSupport::VERSION::STRING >= '5.2.0'
      class_attribute :logger, instance_writer: false, default: ::Logger.new(STDOUT)
      class_attribute :error_handlers, default: []
    else
      class_attribute :logger
      class_attribute :error_handlers
      self.logger = ::Logger.new(STDOUT)
      self.error_handlers = []
    end

    endpoint 'https://example.com/v1'
    http_open_timeout 2.seconds
    http_read_timeout 3.seconds

    private

    def bad_request(_params, _logger)
      puts 'The method is called'
    end
  end

  let(:instance) { self.class::MockClass.new }

  described_class::HTTP_METHODS.each do |http_method|
    describe "##{http_method}" do
      subject(:execute) do
        instance.public_send(http_method, pathname, headers: headers, query: query, body: body)
      end

      before { allow(instance).to receive(:_request).and_return(response) }

      let(:pathname) { 'path/to/resource' }
      let(:headers) { { 'Content-Type': 'application/json;charset=UTF-8' } }
      let(:query) { { key: 'value' } }
      let(:body) { nil }
      let(:response) { instance_double(Sawyer::Response, data: resource) }
      let(:resource) { instance_double(Sawyer::Resource) }

      it 'calls #_request method and then processes the response' do
        execute
        expect(instance)
          .to have_received(:_request)
          .with(http_method, pathname, headers, query, body, instance_of(::Logger))
          .ordered
        expect(response)
          .to have_received(:data)
          .with(no_args)
          .ordered
      end

      it { is_expected.to eq resource }
    end
  end

  describe '#_request' do
    subject(:request!) do
      instance._request(http_method, '/path/to/resource', headers, query, body, logger)
    end

    before do
      allow(MyApiClient::Params::Request).to receive(:new).and_call_original
      allow(MyApiClient::Params::Params).to receive(:new).and_call_original
      allow(MyApiClient::Logger).to receive(:new).and_return(request_logger)
      allow(Sawyer::Agent).to receive(:new).and_return(agent)
      allow(Faraday).to receive(:new).and_call_original
      allow(instance).to receive(:_error_handling).and_call_original
      stub_request(http_method, 'https://example.com/v1/path/to/resource')
        .with(query: query)
        .to_return(body: response_body, headers: headers)
    end

    let(:headers) { { 'Content-Type': 'application/json;charset=UTF-8' } }
    let(:request_logger) { instance_double(MyApiClient::Logger, info: nil, warn: nil, error: nil) }
    let(:agent) { instance_double(Sawyer::Agent, call: response) }
    let(:response) do
      instance_double(Sawyer::Response, status: 200, data: resource, timing: 0.1, headers: nil)
    end
    let(:resource) { instance_double(Sawyer::Resource) }
    let(:logger) { instance_double(::Logger) }
    let(:response_body) { { message: 'OK' }.to_json }

    shared_examples 'to initialize an instance of each class' do
      it 'builds a request parameter instance with arguments' do
        request!
        expect(MyApiClient::Params::Request)
          .to have_received(:new).with(http_method, '/v1/path/to/resource', headers, query, body)
      end

      it 'builds a request logger instance with arguments' do
        request!
        expect(MyApiClient::Logger)
          .to have_received(:new)
          .with(logger, instance_of(Faraday::Connection), http_method, '/v1/path/to/resource')
      end

      it 'builds a Sawyer::Agent instance with the configuration parameter' do
        request!
        expect(Sawyer::Agent)
          .to have_received(:new)
          .with('https://example.com', faraday: instance_of(Faraday::Connection))
      end

      it 'builds a Faraday instance with configuration parameters' do
        request!
        expect(Faraday)
          .to have_received(:new)
          .with(nil, request: { timeout: 3.seconds, open_timeout: 2.seconds })
      end

      it 'builds the Params instance with request and response parameters' do
        request!
        expect(MyApiClient::Params::Params)
          .to have_received(:new)
          .with(instance_of(MyApiClient::Params::Request), response)
      end

      it 'initializes in order of faraday, sawyer, logger' do
        request!
        expect(Faraday).to have_received(:new).ordered
        expect(Sawyer::Agent).to have_received(:new).ordered
        expect(MyApiClient::Logger).to have_received(:new).ordered
      end
    end

    shared_examples 'to execute an HTTP request' do
      it 'requests to the API by Sawyer::Agent#call' do
        request!
        expect(agent)
          .to have_received(:call)
          .with(http_method, '/v1/path/to/resource', body, headers: headers, query: query)
      end

      it 'verifies the API response with `#error_handling` definition' do
        request!
        expect(instance).to have_received(:_error_handling).with(response)
      end

      it 'returns the API response' do
        expect(request!).to eq response
      end
    end

    shared_examples 'to handle errors' do
      context 'when #error_handling returns Proc' do
        before { allow(instance).to receive(:_error_handling).and_return(proc) }

        let(:proc) { ->(_params, _request_logger) { puts 'The procedure is called' } }

        it 'calls received procedure' do
          expect { request! }.to output("The procedure is called\n").to_stdout
        end
      end

      context 'when detects some network error' do
        before { allow(agent).to receive(:call).and_raise(Net::OpenTimeout) }

        it 'raises MyApiClient::NetworkError' do
          expect { request! }.to raise_error(MyApiClient::NetworkError)
        end
      end

      context 'when raises a error which inherit MyApiClient::Error' do
        before { allow(instance).to receive(:_error_handling).and_return(proc) }

        let(:proc) { ->(params, _request_logger) { raise MyApiClient::Error, params } }

        it 'escalates the error' do
          expect { request! }.to raise_error(MyApiClient::Error)
        end
      end
    end

    context 'when requesting with GET method' do
      let(:http_method) { :get }
      let(:query) { { key: 'value' } }
      let(:body) { nil }

      it_behaves_like 'to initialize an instance of each class'
      it_behaves_like 'to execute an HTTP request'
      it_behaves_like 'to handle errors'
    end

    context 'when requesting with POST method' do
      let(:http_method) { :post }
      let(:query) { nil }
      let(:body) { { name: 'name', birthday: Date.new(1999, 1, 1) } }

      it_behaves_like 'to initialize an instance of each class'
      it_behaves_like 'to execute an HTTP request'
      it_behaves_like 'to handle errors'
    end

    context 'when requesting with PATCH method' do
      let(:http_method) { :patch }
      let(:query) { nil }
      let(:body) { { name: 'name', birthday: Date.new(1999, 1, 1) } }

      it_behaves_like 'to initialize an instance of each class'
      it_behaves_like 'to execute an HTTP request'
      it_behaves_like 'to handle errors'
    end

    context 'when requesting with DELETE method' do
      let(:http_method) { :delete }
      let(:query) { nil }
      let(:body) { nil }

      it_behaves_like 'to initialize an instance of each class'
      it_behaves_like 'to execute an HTTP request'
      it_behaves_like 'to handle errors'
    end
  end

  describe '#schema_and_hostname' do
    context 'with domain name and path' do
      before { self.class::MockClass.endpoint('https://example.com/path/to/resource') }

      it 'extracts schema and hostname from endpoint' do
        expect(instance.schema_and_hostname).to eq 'https://example.com'
      end
    end

    context 'when given endpoint: "localhost:3000"' do
      before { self.class::MockClass.endpoint('http://localhost:3000/path/to/resource') }

      it 'extracts schema and hostname from endpoint' do
        expect(instance.schema_and_hostname).to eq 'http://localhost:3000'
      end
    end
  end

  describe '#common_path' do
    context 'with domain name and path' do
      before { self.class::MockClass.endpoint('https://example.com/path/to/resource') }

      it 'extracts pathname from endpoint' do
        expect(instance.common_path).to eq '/path/to/resource'
      end
    end

    context 'when given endpoint: "localhost:3000"' do
      before { self.class::MockClass.endpoint('http://localhost:3000/path/to/resource') }

      it 'extracts pathname from endpoint' do
        expect(instance.common_path).to eq '/path/to/resource'
      end
    end
  end
end
