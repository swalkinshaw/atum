require 'spec_helper'

describe 'The Generated Client' do
  let(:name) { 'Fruity' }
  let(:schema_file) do
    File.expand_path('../fixtures/fruity_schema.json', File.dirname(__FILE__))
  end
  let(:url) { 'http://USER:PASSWORD@api.fruity.com/fruits' }
  let(:tmp_folder) do
    File.expand_path(File.join('..', '..', 'tmp'), File.dirname(__FILE__))
  end
  let(:options) { { path: File.join(tmp_folder, 'client') } }
  let(:generator_service) do
    Atum::Generation::GeneratorService.new(name, schema_file, url, options)
  end
  let(:pre_generation_setup) { -> { generator_service.generate_files } }

  around(:each) do |example|
    pre_generation_setup.call
    load File.join(options[:path], 'fruity.rb')
    Fruity.connect(url, 'USER', 'PASSWORD')
    example.run
    Fruity.send(:remove_const, 'VERSION')
    Fruity.send(:remove_const, 'SCHEMA')
    FileUtils.rm_rf(options[:path])
  end

  it 'can make get requests' do
    stub = WebMock.stub_request(:get, "#{url}/lemon")
    Fruity.lemon.list
    expect(stub).to have_been_requested
  end

  it 'can make get requests with url params' do
    lemon_id = 'MYLEMONID'
    stub = WebMock.stub_request(:get, "#{url}/lemon/#{lemon_id}")
    Fruity.lemon.info(lemon_id)
    expect(stub).to have_been_requested
  end

  it 'can make requests with custom headers' do
    headers = { 'Accept' => 'application/json', 'Api-Version' => '2014-09-01',
                'Content-Type' => 'application/json' }
    stub = WebMock.stub_request(:get, "#{url}/lemon").with do |request|
      expect(request.headers).to include(headers)
    end
    Fruity.lemon.list(headers: headers)
    expect(stub).to have_been_requested
  end

  it 'passes through query params' do
    query = { 'size' => 'large' }
    stub = WebMock.stub_request(:get, "#{url}/lemon?size=large")
    Fruity.lemon.list(query: query)
    expect(stub).to have_been_requested
  end

  it 'can use href params and pass query params' do
    lemon_id = 'MYLEMONID'
    query = { 'size' => 'large' }
    stub = WebMock.stub_request(:get, "#{url}/lemon/#{lemon_id}?size=large")
    Fruity.lemon.info(lemon_id, query: query)
    expect(stub).to have_been_requested
  end

  it 'just returns non-json responses' do
    body = 'MYBODY'
    WebMock.stub_request(:get, "#{url}/lemon")
      .to_return(body: body, headers: { 'Content-Type' => 'application/text' })
    expect(Fruity.lemon.list).to eq(body)
  end

  it 'unenvelopes json api responses' do
    lemon_body = { 'lemon_uuid' => 'MYLEMONID' }
    lemon_id = 'MYLEMONID'
    WebMock.stub_request(:get, "#{url}/lemon/#{lemon_id}")
      .to_return(body: { 'lemons' => lemon_body }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    expect(Fruity.lemon.info(lemon_id)).to eq(lemon_body)
  end

  it 'can send raw POST bodies' do
    body = 'MYBODY'
    WebMock.stub_request(:post, "#{url}/lemon")
      .with(body: body)
    expect(Fruity.lemon.create(body: body))
  end

  it 'sends JSON when POST-ing a hash' do
    body = { size: 'large', is_ripe: true, date_picked: Time.now }
    WebMock.stub_request(:post, "#{url}/lemon")
      .with(body: body.to_json)
    expect(Fruity.lemon.create(body: body))
  end

  context "when a version file doesn't exist" do
    it "doesn't define VERSION" do
      expect(Fruity::VERSION).to eq('')
    end
  end

  context 'when a version file exists' do
    let(:version) { '1.2.3' }
    let(:pre_generation_setup) do
      lambda do
        generator_service.generate_files
        file = File.expand_path(File.join(options[:path], 'fruity', 'version.rb'))
        File.open(file, 'w') do |f|
          f.write "module #{name}\n"
          f.write "  VERSION = '#{version}'\n"
          f.write 'end'
        end
      end
    end

    it 'includes a version file for the client when one exists' do
      expect(Fruity::VERSION).to eq(version)
    end
  end

  context 'when using a :test http_adapter' do
    before do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get("#{url}/lemon") { |_| [200, {}, 5] }
      end
      Fruity.connect(url, 'USER', 'PASSWORD',
                     http_adapter: [:test, stubs])
    end

    it 'uses the defined stubs' do
      expect(Fruity.lemon.list).to eq(5)
    end
  end
end
