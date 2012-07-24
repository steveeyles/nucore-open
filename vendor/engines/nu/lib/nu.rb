module Nu
  class Engine < Rails::Engine
    config.autoload_paths << File.join(File.dirname(__FILE__), "../lib")

    config.to_prepare do
      Journal.send :include, Nu::JournalExtension
      JournalRow.send :include, Nu::JournalRowExtension
      User.send :include, Nu::UserExtension
      UsersController.send :include, Nu::UsersControllerExtension
    end
  end
end