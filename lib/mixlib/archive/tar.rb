require "rubygems/package"
require "zlib"

module Mixlib
  class Archive
    class Tar
      TAR_LONGLINK = "././@LongLink"

      attr_reader :options
      attr_reader :archive

      def initialize(archive, options = {})
        @archive = archive
        @options = options
      end

      def extract(destination)
        # (http://stackoverflow.com/a/31310593/506908)
        reader do |tar|
          dest = nil
          tar.each do |entry|
            if entry.full_name == TAR_LONGLINK
              dest = File.join(destination, entry.read.strip)
              next
            end
            dest ||= File.join(destination, entry.full_name)

            if entry.directory? || (entry.header.typeflag == "" && entry.full_name.end_with?("/"))
              File.delete(dest) if File.file?(dest)
              FileUtils.mkdir_p(dest, mode: entry.header.mode, verbose: false)
            elsif entry.file? || (entry.header.typeflag == "" && !entry.full_name.end_with?("/"))
              FileUtils.rm_rf(dest) if File.directory?(dest)
              File.open(dest, "wb") do |f|
                f.print(entry.read)
              end
              FileUtils.chmod(entry.header.mode, dest, verbose: false)
            elsif entry.header.typeflag == "2"
              # handle symlink
              File.symlink(entry.header.linkname, dest)
            else
              puts "unknown tar entry: #{entry.full_name} type: #{entry.header.typeflag}"
            end

            dest = nil
          end
        end
      end

      def reader(&block)
        raw = File.open(archive, "rb")
        file = case archive
               when /\.t?gz$/
                 Zlib::GzipReader.wrap(raw)
               else
                 raw
               end
        Gem::Package::TarReader.new(file, &block)
      ensure
        if file
          file.close unless file.closed?
          file = nil
        end
        if raw
          raw.close unless raw.closed?
          raw = nil
        end
      end

    end
  end
end