require 'uri'
require 'cgi'
require 'open-uri'
require 'fileutils'

require 'rabbit/element'

module Rabbit
  module Parser
    module Ext
      module Image
        ALLOWED_IMG_URL_SCHEME = ['http', 'file', '']

        module_function
        def make_image(canvas, uri_str, prop={})
          uri = URI.parse(uri_str)
          scheme = uri.scheme
          unless ALLOWED_IMG_URL_SCHEME.include?(scheme.to_s.downcase)
            return nil
          end
          begin
            Element::Image.new(Private.image_filename(canvas, uri), prop)
          rescue Error
            canvas.logger.warn($!.message)
            nil
          end
        end

        def make_image_from_file(canvas, source)
          src_file = Tempfile.new("rabbit-image-source")
          src_file.open
          src_file.print(source)
          src_file.close
          image_file = prop = nil
          begin
            image_file, prop = yield(src_file.path)
          rescue ImageLoadError
            canvas.logger.warn($!.message)
          end
          return nil if image_file.nil?
          image = make_image(canvas, %Q[file://#{image_file.path}], prop)
          return nil if image.nil?
          image["_src"] = image_file # for protecting from GC
          image
        end

        module Private
          module_function
          def image_filename(canvas, uri)
            case uri.scheme
            when /file/i
              GLib.filename_from_utf8(uri.path)
            when /http|ftp/i
              other_uri_filename(canvas, uri)
            else
              related_path_filename(canvas, uri)
            end
          end

          def tmp_filename(canvas, key)
            dir = canvas.tmp_dir_name
            FileUtils.mkdir_p(dir)
            File.join(dir, CGI.escape(key))
          end

          def related_path_filename(canvas, uri)
            image_uri = canvas.full_path(GLib.filename_from_utf8(uri.to_s))
            filename = nil

            begin
              raise URI::InvalidURIError if URI.parse(image_uri).scheme.nil?
              filename = tmp_filename(canvas, image_uri)
              setup_image_file(canvas, image_uri, filename)
            rescue URI::InvalidURIError
              filename = image_uri
            end

            filename
          end

          def other_uri_filename(canvas, uri)
            filename = tmp_filename(canvas, uri.to_s)
            setup_image_file(canvas, uri, filename)
            filename
          end

          def setup_image_file(canvas, uri, filename)
            begin
              open(uri, "rb") do |in_file|
                File.open(filename, "wb") do |out|
                  out.print(in_file.read)
                end
              end
            rescue SocketError, OpenURI::HTTPError
              canvas.logger.warn("#{$!.message}: #{uri}")
            end
          end
        end
      end
    end
  end
end
