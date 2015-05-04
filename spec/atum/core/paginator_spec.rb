require 'spec_helper'

describe Atum::Core::Paginator do
  let(:request) { double(make_request: response) }
  let(:response) { double(body: anything) }
  let(:options) { {} }
  let(:paginator) { described_class.new(request, response, options) }

  describe '#enumerator' do
    subject(:enumerator) { paginator.enumerator }

    before do
      allow(request).to receive(:unenvelope).and_return({})
    end

    it { is_expected.to be_an(Enumerator) }

    context 'when there is no next page link' do
      before do
        allow(response).to receive(:paginated?).and_return(false)
      end

      it "doesn't fetch any more pages of data" do
        expect(request).to_not receive(:make_request)
        enumerator.to_a
      end
    end

    context 'when there is a next page link' do
      before do
        allow(response).to receive(:paginated?).and_return(true)
        allow(response).to receive(:links).and_return({
          'next' => '/things'
        })
      end

      it 'fetches another page of data' do
        allow(request).to receive(:make_request).and_return(
          double(
            headers: { 'Content-Type' => 'application/json' },
            body: '{}',
            status: 200
          )
        )
        expect(request).to receive(:make_request).once
        enumerator.take(20).to_a
      end
    end
  end
end
