# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FService::Result::Success do
  subject(:success) { described_class.new('Yay!') }

  it { expect(success).to be_a described_class }
  it { expect(success).to be_successful }
  it { expect(success).not_to be_failed }
  it { expect(success.value).to eq('Yay!') }
  it { expect(success.type).to eq(nil) }
  it { expect(success.error).to eq(nil) }
  it { expect(success.value!).to eq('Yay!') }

  context 'when defining a type' do
    subject(:success) { described_class.new('Yay!', :ok) }

    it { expect(success.type).to eq(:ok) }
  end

  describe '#on' do
    context 'when matching results' do
      subject(:success_match) do
        described_class.new('Yay!').on(
          success: ->(value) { return value + '!' },
          failure: ->(_error) { raise "This won't ever run" }
        )
      end

      it 'runs on the success path' do
        expect(success_match).to eq('Yay!!')
      end
    end

    context 'when chaining results' do
      subject(:chain) do
        described_class.new('Yay!')
                       .then { |value| described_class.new(value + ' It') }
                       .then { |value| described_class.new(value + ' works!', :ok) }
                       .and_then { |value, type| described_class.new(value + " Type: #{type}!") }
      end

      it { expect(chain).to be_successful }

      it 'chains successful results' do
        expect(chain.value).to eq('Yay! It works! Type: ok!')
      end
    end

    context 'when chaining results with a catch block' do
      subject(:chain) do
        described_class.new('Yay!')
                       .catch { FService::Result::Failure.new('Shoot! It failed!') }
                       .then { |value| described_class.new(value + ' It') }
                       .then { |value| described_class.new(value + ' works!', :ok) }
                       .then { |value, type| described_class.new(value + " Type: #{type}!") }
      end

      it { expect(chain).to be_successful }

      it 'chains successful results' do
        expect(chain.value).to eq('Yay! It works! Type: ok!')
      end
    end

    context 'when chaining results with a catch block using the `or` alias' do
      subject(:chain) do
        described_class.new('Yay!')
                       .or_else { FService::Result::Failure.new('Shoot! It failed!') }
                       .then { |value| described_class.new(value + ' It') }
                       .then { |value| described_class.new(value + ' works!', :ok) }
                       .then { |value, type| described_class.new(value + " Type: #{type}!") }
      end

      it { expect(chain).to be_successful }

      it 'chains successful results' do
        expect(chain.value).to eq('Yay! It works! Type: ok!')
      end
    end
  end

  describe '#on_success' do
    describe 'return' do
      subject(:on_success_callback) { success.on_success(unhundled: true) { 'some recovering' } }

      let(:success) { described_class.new([], :ok) }

      it 'returns itself' do
        expect(on_success_callback).to eq success
      end
    end

    describe 'callback matching' do
      context 'when no type is especified' do
        subject(:on_success_callback) { success.on_success { |array| array << 'It works!' } }

        let(:array) { [] }
        let(:success) { described_class.new(array, :error) }

        before { allow(FService).to receive(:deprecate!) }

        it 'handles the error' do
          expect { on_success_callback }.to change { array }.from([]).to(['It works!'])
        end

        it 'warns deprecation about passing no arguments' do
          on_success_callback

          expect(FService).to have_received(:deprecate!).with(
            name: "#{described_class}#on_success without target type",
            alternative: "#{described_class}#on_success(unhandled: true)",
            from: an_instance_of(String)
          )
        end
      end

      context 'when some type is especified' do
        subject(:on_success_callback) do
          success.on_success(:ok) { |value, type| value << type }
                 .on_success(:still_ok) { |value| value << 3 }
                 .on_success(unhandled: true) { |value| value << 'one more time' }
        end

        let(:array) { [] }
        let(:success) { described_class.new(array, type) }

        context 'and no type matches with success type' do
          let(:type) { :unknow_success }

          it 'freezes the result' do
            expect(on_success_callback).to be_frozen
          end

          it 'evaluates the block wich matches without specifying success' do
            on_success_callback

            expect(array).to eq ['one more time']
          end
        end

        context 'and some type matches with success type' do
          let(:type) { :ok }

          it 'freezes the result' do
            expect(on_success_callback).to be_frozen
          end

          it 'evaluates only the first given block on failure' do
            on_success_callback

            expect(array).to eq [:ok]
          end
        end
      end
    end
  end

  describe '#on_failure' do
    subject(:on_failure_callback) do
      success.on_failure(unhandled: true) { |value| value << 1 }
             .on_failure(:ok) { |value| value << 2 }
             .on_failure(unhandled: true) { raise "This won't ever run" }
             .on_failure(:ok, :not_ok) { raise 'This is a contradiction' }
    end

    let(:array) { [] }
    let(:success) { described_class.new(array, :ok) }

    it 'returns itself' do
      expect(on_failure_callback).to eq success
    end

    it 'keeps the result unfreeze' do
      expect(on_failure_callback).not_to be_frozen
    end

    it 'does not evaluate the given block on failure' do
      on_failure_callback

      expect(array).to eq []
    end
  end

  describe '#and_then' do
    subject(:success) { described_class.new('Pax', :ok) }

    it 'returns the given block result' do
      expect(success.and_then { |value| "Hello, #{value}!" }).to eq('Hello, Pax!')
    end
  end

  describe '#or_else' do
    subject(:success) { described_class.new('Pax', :ok) }

    it 'does not yields the block' do
      expect { |block| success.or_else(&block) }.not_to yield_control
    end

    it 'returns itself' do
      expect(success.or_else { 'an error happened' }).to eq(success)
    end
  end

  describe '#to_s' do
    it { expect(success.to_s).to eq 'Success("Yay!")' }
  end
end
