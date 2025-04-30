# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ExampleClass do
  let(:instance) { described_class.new }

  describe '#example_instance_method' do
    it 'prints the expected text to stdout' do
      expect(SomeNamespace::AnotherExampleClass).to receive(:example_class_method).and_call_original
      expect { instance.example_instance_method }.to output("Hello!\n").to_stdout
    end
  end

  describe '.example_class_method' do
    it 'prints the expected text to stdout' do
      expect { described_class.example_class_method }.to output("Hello again!\n").to_stdout
    end
  end
end
