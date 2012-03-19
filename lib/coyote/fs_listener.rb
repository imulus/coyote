require 'digest'

module Coyote
  autoload :Darwin,  'coyote/fs_listeners/darwin'
  autoload :Linux,   'coyote/fs_listeners/linux'
  autoload :Windows, 'coyote/fs_listeners/windows'
  autoload :Polling, 'coyote/fs_listeners/polling'

  class FSListener
    attr_reader :last_event, :sha1_checksums_hash

    def self.select_and_init
      if mac? && Darwin.usable?
        Darwin.new
      elsif linux? && Linux.usable?
        Linux.new
      elsif windows? && Windows.usable?
        Windows.new
      else
        print "Using polling (Please help us to support your system better than that.)\n".red
        Polling.new
      end
    end

    def initialize
      @sha1_checksums_hash = {}
      update_last_event
    end

    def update_last_event
      @last_event = Time.now
    end

    def modified_files(dirs, options = {})
      files = potentially_modified_files(dirs, options).select { |path| File.file?(path) && file_modified?(path) && file_content_modified?(path) }
      files.map! { |file| file.gsub("#{Dir.pwd}/", '') }
    end

  private

    def potentially_modified_files(dirs, options = {})
      match = options[:all] ? "**/*" : "*"
      Dir.glob(dirs.map { |dir| "#{dir}#{match}" })
    end

    def file_modified?(path)
      # Depending on the filesystem, mtime is probably only precise to the second, so round
      # both values down to the second for the comparison.
      File.mtime(path).to_i >= last_event.to_i
    rescue
      false
    end

    def file_content_modified?(path)
      sha1_checksum = Digest::SHA1.file(path).to_s
      if @sha1_checksums_hash[path] != sha1_checksum
        @sha1_checksums_hash[path] = sha1_checksum
        true
      else
        false
      end
    end

    def self.mac?
      Config::CONFIG['target_os'] =~ /darwin/i
    end

    def self.linux?
      Config::CONFIG['target_os'] =~ /linux/i
    end

    def self.windows?
      Config::CONFIG['target_os'] =~ /mswin|mingw/i
    end
  end
end
