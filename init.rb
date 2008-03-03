require 'git'
require 'smart_migration'
ActiveRecord::Migration.send(:include, SmartMigration)