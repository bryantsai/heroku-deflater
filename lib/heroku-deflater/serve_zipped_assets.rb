require 'action_controller'
require 'active_support/core_ext/uri'
require 'action_dispatch/middleware/static'

# Adapted from https://gist.github.com/guyboltonking/2152663
#
# Taken from: https://github.com/mattolson/heroku_rails_deflate
#

module HerokuDeflater
  class ServeZippedAssets
    def initialize(app, root, assets_path, cache_control=nil)
      puts "initialize ServeZippedAssets(#{app}, #{root}, #{assets_path}, #{cache_control})"
      @app = app
      @assets_path = assets_path.chomp('/') + '/'
      @file_handler = ActionDispatch::FileHandler.new(root, cache_control)
    end

    def call(env)
      if env['REQUEST_METHOD'] == 'GET'
        puts "GET request ..."
        request = Rack::Request.new(env)
        encoding = Rack::Utils.select_best_encoding(%w(gzip identity), request.accept_encoding)

        puts "encoding=#{encoding}"

        if encoding == 'gzip'
          # See if gzipped version exists in assets directory
          compressed_path = env['PATH_INFO'] + '.gz'

          match = @file_handler.match?(compressed_path)

          puts "compressed_path=#{compressed_path} @assets_path=#{@assets_path} mm=#{compressed_path.start_with?(@assets_path)} match=#{match}"

          if compressed_path.start_with?(@assets_path) && match
            puts "serving gzipped version ..."

            # Get the FileHandler to serve up the gzipped file, then strip the .gz suffix
            env['PATH_INFO'] = match
            status, headers, body = @file_handler.call(env)
            env['PATH_INFO'].chomp!('.gz')

            # Set the Vary HTTP header.
            vary = headers['Vary'].to_s.split(',').map(&:strip)

            unless vary.include?('*') || vary.include?('Accept-Encoding')
              headers['Vary'] = vary.push('Accept-Encoding').join(',')
            end

            # Add encoding and type
            headers['Content-Encoding'] = 'gzip'
            headers['Content-Type'] = Rack::Mime.mime_type(File.extname(env['PATH_INFO']), 'text/plain')

            body.close if body.respond_to?(:close)
            puts "status=#{status}, headers=#{headers}"
            return [status, headers, body]
          end
        end
      end

      @app.call(env)
    rescue Exception => e
      puts "error happened: #{e}"
    end
  end
end
