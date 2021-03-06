require 'net/http'

module Puppet::Module::Tool
  module Applications

    class Application
      include Utils::Interrogation

      def self.run(*args)
        new(*args).run
      end

      attr_accessor :options

      def initialize(options = {})
        @options = options
        Puppet::Module::Tool.prepare_settings(options)
      end

      def repository
        @repository ||= Repository.new(Puppet.settings[:puppet_module_repository])
      end

      def run
        raise NotImplementedError, "Should be implemented in child classes."
      end

      def discuss(response, success, failure)
        case response
        when Net::HTTPOK, Net::HTTPCreated
          say success
        else
          errors = PSON.parse(response.body)['error'] rescue "HTTP #{response.code}, #{response.body}"
          say "#{failure} (#{errors})"
        end
      end

      def metadata(require_modulefile = false)
        unless @metadata
          unless @path
            abort "Could not determine module path"
          end
          @metadata = Metadata.new
          contents = ContentsDescription.new(@path)
          contents.annotate(@metadata)
          checksums = Checksums.new(@path)
          checksums.annotate(@metadata)
          modulefile_path = File.join(@path, 'Modulefile')
          if File.file?(modulefile_path)
            Modulefile.evaluate(@metadata, modulefile_path)
          elsif require_modulefile
            abort "No Modulefile found."
          end
        end
        @metadata
      end

      def load_modulefile!
        @metadata = nil
        metadata(true)
      end

      # Use to extract and validate a module name and version from a
      #filename
      # Note: Must have @filename set to use this
      def parse_filename!
        @release_name = File.basename(@filename,'.tar.gz')
        parts         = @release_name.split('-')
        @username     = @release_name.split('-').first
        @module_name  = @release_name.split('-')[1..-2].join('-')
        @version      = @release_name.split('-').last
        @full_name    = [@username, @module_name].join('-')
        unless @username && @module_name
          abort "Username and Module name not provided"
        end
        begin
          Gem::Version.new(@version)
        rescue ArgumentError => e
          abort "Invalid version format: #{@version}"
        end
      end
    end

  end

end
