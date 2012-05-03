class EDMA < Thor
  
  VERSION = "1.0.0"
  @@id = File.basename(Dir.getwd)
  @@AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID']
  @@AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY']
  @@AWS_BUCKET = "dtdigitaledms"
  @@S3ID = "s3-ap-southeast-1.amazonaws.com"

  # Public: Takes a file and adds target blanks to that file.
  #
  # file - file name, defaults to email.html 
  #
  # Examples
  #
  #   edma add_blanks
  #   edma add_blanks -f example.html
  #   
  #
  desc "add_blanks", "add target blanks to a tags"
  method_option :file,:default => "email.html", :aliases => "-f",
  :desc => "the name of the HTML file to add target blanks to"
  def add_blanks
    require 'nokogiri'    
    if File.exists? options.file
      doc = Nokogiri::HTML(File.open(options.file))
      puts "== Adding target='_blank' to anchor tags"
      doc.xpath("//a").each do |anchor|
        target = anchor['target']
        if target == nil
          anchor['target'] = "_blank"
        end
      end
      system %Q{rm #{options.file}}
      file = File.new(options.file, "w")
      file.write(doc)
      file.close
    else
      STDOUT.puts "Error: \"#{options.file}\" does not exist"
      exit
    end
  end

  # Public: Converts a HTML template to inline styles using a 3P sevice
  #
  # file - filename to convert
  # compiled_file - save converted markup to (default => email_compiled.html)
  #
  # Examples
  #
  #   edma to_inline
  #   edma to_inline -f email.html -c compiled.html   
  #   
  #
  desc "to_inline", "convert a HTML template to inline styles"
  method_option :file,:default => "email.html", :aliases => "-f",
  :desc => "the name of the HTML file to convert to inline styles"
  method_option :compiled_file,:default => "email_compiled.html", :aliases => "-c",
  :desc => "the name of the file to returned the inline styles to"
  def to_inline
    require 'net/http'
    require 'cgi'
    if File.exist?(options.file)
      email = File.open(options.file, "rb")
      email_content = email.read
      puts "== Converting email to inline styles"
      #uses the http://inlinestyler.torchboxapps.com web service
      uri = URI('http://inlinestyler.torchboxapps.com/styler/convert/')
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data('source' => email_content, 'returnraw' => true)

      res = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end

      case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        html = CGI.unescapeHTML(res.body)
        if File.exist?(options.compiled_file)
          system %Q{rm #{options.compiled_file}}
        end
        
        file = File.new(options.compiled_file, "w")
        file.write(html)
        file.close
        puts "== Done"
      else
        res.value
        puts "ERROR: inline service returned #{res.value}"
      end
    else
      puts "ERROR: missing an email template named '#{options.file}'"
    end
  end

  # Public: Replace all the img tags in HTML markup to S3 source.
  #
  # file - The name of the file to replace the src of 
  # folder - Name of the images folder (default => images).
  # write_file - the name of the file to write to
  #
  # Examples
  #
  #   edma img_src_to_s3 
  #   edma img_src_to_s3 -f example.html  
  #
  desc "img_src_to_s3", "Replace all the img tags in HTML markup to s3 source"
  method_option :file, :default => "email.html", :aliases => "-f",
  :desc => "the name of the file to replace the src of"
  method_option :folder, :default => "images", :aliases => "-r",
  :desc => "the name of the folder to where the images are"
  method_option :write_file, 
  :aliases => "-w", :desc => "the name of the folder to write to"
  def img_src_to_s3
    require 'nokogiri'
    loc = "http://"+@@S3ID+"/"+@@AWS_BUCKET+"/"+@@id

    if File.exists? options.file

      if !File.exists? options.folder
        STDOUT.puts "Error: folder #{options.folder} does not exist"
        exit
      end

      doc = Nokogiri::HTML(File.open(options.file))
      puts "== Replacing img src to S3"
      doc.xpath("//img").each do |img|
        src = img['src']
        src = src.gsub!(/(^#{options.folder})/, loc)
        img['src'] = src
      end

      if options.write_file
        file = File.new(options.write_file, "w")
        file.write(doc)
        file.close
        puts "== Done"
      else
        @compiled_markup = doc
        puts "== Done"
      end
    else
      STDOUT.puts "Error: No file #{options.file}"
      exit
    end
  end

  # Public: Uploads images to an Amazone S3 Instance.
  #
  # folder - Name of the images folder (default => images).
  #
  # Examples
  #
  #   edma images_to_s3   
  #   edma images_to_s3 -r images
  #
  desc "images_to_s3", "uploads images to an Amazon s3 instance"
  method_option :folder, :default => "images", :aliases => "-r",
  :desc => "the name of the folder to upload to the S3 bucket"
  def images_to_s3
    require 'aws/s3'
    require 'digest/md5'
    require 'mime/types'
    puts "== Uploading assets to S3/Cloudfront"
    

    AWS::S3::DEFAULT_HOST.replace @@S3ID
    service = AWS::S3::Base.establish_connection!(
      :access_key_id => @@AWS_ACCESS_KEY_ID,
      :secret_access_key => @@AWS_SECRET_ACCESS_KEY)
    bucket = AWS::S3::Bucket.find(@@AWS_BUCKET)
    
    STDOUT.sync = true
    if Dir.exists? options.folder
      Dir.glob("#{options.folder}/**/*").each do |file|
          if File.file?(file)
            remote_file = file.gsub("#{options.folder}/", "")            
            begin
              obj = bucket.objects.find_first(remote_file)
            rescue
              obj = nil
            end

            if !obj || (obj.etag != Digest::MD5.hexdigest(File.read(file)))
              AWS::S3::S3Object.store("#{@@id}/"+remote_file, open("#{options.folder}/"+remote_file), @@AWS_BUCKET, :access => :public_read)
              puts "*UPLOADED: "+remote_file
            else
              print "."
            end
          end
      end
      STDOUT.sync = false # Done with progress output.
      puts "== Done"
    else
      STDOUT.puts "Error: folder does not exist"
      exit
    end
  end

end

EDMA.start
