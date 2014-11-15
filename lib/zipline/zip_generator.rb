# this class acts as a streaming body for rails
# initialize it with an array of the files you want to zip
module Zipline
  class ZipGenerator
    # takes an array of triples [[size, download_url, filename], ... ]
    def initialize(files)
      @files = files
    end

    #this is supposed to be streamed!
    def to_s
      throw "stop!"
    end

    def each(&block)
      output = new_output(&block)
      OutputStream.open(output) do |zip|
        @files.each {|size, download_url, name| handle_file(zip, size, download_url, name) }
      end
    end

    def handle_file(zip, size, download_url, name)
      name = uniquify_name(name)
      write_file(zip, size, download_url, name)
    end

    def new_output(&block)
      FakeStream.new(&block)
    end

    def write_file(zip, size, download_url, name)
      zip.put_next_entry name, size

      if download_url.respond_to :call
        download_url = download_url.call()
      end

      c = Curl::Easy.new(download_url) do |curl|
        curl.on_body do |data|
          zip << data
          data.bytesize
        end
      end
      c.perform
    end

    def uniquify_name(name)
      @used_names ||= Set.new

      if @used_names.include?(name)

        #remove suffix e.g. ".foo"
        parts = name.split '.'
        name, extension =
          if parts.length == 1
            #no suffix, e.g. README
            parts << ''
          else
            extension = parts.pop
            [parts.join('.'), ".#{extension}"]
          end

        #trailing _#{number}
        pattern = /_(\d+)$/

        unless name.match pattern
          name = "#{name}_1"
        end

        while @used_names.include? name + extension
          #increment trailing number
          name = name.sub( pattern ) { |x| "_#{$1.to_i + 1}" }
        end

        #reattach suffix
        name += extension
      end

      @used_names << name
      name
    end
  end
end
