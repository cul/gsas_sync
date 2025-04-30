# Example Ruby Script Development Template

This is a quick setup template for ruby scripts.  It includes:

- A main.js file, which is an example entrypoint file for a ruby script.  If you want to, you can rename this to something more relevant to the script you're writing.
- A .ruby-version file to specify what version of Ruby you're using.
- A Gemfile for managing dependencies.
- Zeitwerk for auto-loading classes and modules in the `lib` directory.
- RSpec for testing.
- Automatic generation of a code coverage report when RSpec runs (via simplecov gem).
- Some example classes and tests (which you can delete in your local copy).

This project is meant to be downloaded as a zip file rather than cloned, since you'll most likely be using it as the basis for a new project (as opposed to wanting to push commits to the template code repository).

# Getting started

- Download this repository:
  - Option 1: Download as a zip file.
  - Option 2: Clone the repository and then delete the `.git` directory inside your closed copy so that you can initialize a new `.git` repository (with `git init`).
- Update the `.ruby-version` file based on the version of Ruby that you want to use.
- Run `bundle install`
  - Modern installations of ruby come with the `bundler` gem, so this should work as long as you're running `bundle install` in this project's top level directory.
- To try out the base project and make sure it works, run: `ruby ./main.rb`
  - It should print out `Hello!` and `Hello again!`
- To run rspec tests, run: `bundle exec rspec`
  - The tests should pass.

# Development notes

You can add new classes and modules in the `lib` directory and they'll be auto-loaded and available for use in your `main.js` script thanks to Zeitwerk.  In order for this to work, you'll need to name files according to Zeitwerk rules (https://github.com/fxn/zeitwerk).  Here's a quick summary

```
lib/animal.rb                        -> Animal
lib/animals/dog.rb                   -> Animals::Dog
lib/animals/dogs/beagle.rb           -> Animals::Dogs::Beagle
lib/animals/dogs/golden_retriever.rb -> Animals::Dogs::GoldenRetriever
```
