require "nucore/engine_config"

module Nucore

  class Engine < Rails::Engine

    include Nucore::EngineConfig

  end

end
