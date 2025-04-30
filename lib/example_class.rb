# frozen_string_literal: true

class ExampleClass
  def example_instance_method
    SomeNamespace::AnotherExampleClass.example_class_method
  end

  def self.example_class_method
    puts 'Hello again!'
  end
end
