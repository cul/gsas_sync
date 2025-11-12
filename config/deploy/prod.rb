# frozen_string_literal: true

set :stage, :prod
server 'diglib-service-prod1.cul.columbia.edu', user: fetch(:remote_user), roles: %w[production_app]

# Grab latest tag version
ask :branch, proc { `git tag --sort=version:refname`.split("\n").last }
