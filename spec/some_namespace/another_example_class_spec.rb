# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SomeNamespace::AnotherExampleClass do
  describe '.example_class_method' do
    it 'prints the expected text to stdout' do
      expect { described_class.example_class_method }.to output("Hello!\n").to_stdout
    end
  end
end
