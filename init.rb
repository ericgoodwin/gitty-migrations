require 'git'
require 'migration_settings'
require 'gitty_migration'
#require 'gitty_migrator'
#ActiveRecord::Migrator.send(:extend, GittyMigrator)
ActiveRecord::Migration.send(:include, GittyMigration)
