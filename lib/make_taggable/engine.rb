# frozen_string_literal: true

module MakeTaggable
  ##
  # Mounts the gem's migrations into a host Rails application, so they can be installed with
  # `rails make_taggable_engine:install:migrations`.
  #
  class Engine < Rails::Engine
  end
end
