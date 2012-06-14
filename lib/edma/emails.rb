require "thor"
require "edma/conf"
require "edma/utils"

module Edma
  class Emails < Thor   
    VERSION = Edma::VERSION
    @@utils = Edma::Utils.new


    # Public: Main testing method to chain a few of the others together.
    #
    # file - name of the main email file (email.html)
    # file_to_compile - the name of the file to compile to (email_compiled.html)
    # images_folder - name of the images folder
    # skip_inline - skip processing inline
    # 
    #  Examples
    #
    #   edma run_test
    #   edma run_test -f email.html -c email_compiled.html -r images
    #
    desc "test_email", "upload the images to s3 and process a litmus test"
    method_option :file, :default => "email.html", :aliases => "-f", :desc => "name of the main email file"
    method_option :file_to_compile, :default => "email_compiled.html",
    :aliases => "-c", :desc => "the name of the file to compile to"
    method_option :images_folder, :default => "images", :aliases => "-r",
    :desc => "name of the images folder"
    method_option :skip_inline, :type => :boolean, :aliases => "-i"
    def test_email
      if options.skip_inline
        invoke :images_to_s3
        invoke :img_src_to_s3
        invoke :start_litmus_test
        cleanup()
      else
        invoke :to_inline
        invoke :images_to_s3
        invoke :img_src_to_s3
        invoke :start_litmus_test
        cleanup()
      end
    end


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
    method_option :file_to_compile, :default => "email_compiled.html", :aliases => "-f",
    :desc => "the name of the file to replace the src of"
    method_option :folder, :default => "images", :aliases => "-r",
    :desc => "the name of the folder to where the images are"
    method_option :write_file, 
    :aliases => "-w", :desc => "the name of the folder to write to"
    def img_src_to_s3
      require 'nokogiri'
      loc = "http://"+Edma::S3ID+"/"+Edma::AWS_BUCKET+"/"+@@utils.id
      file_ref = options.file_to_compile

      if File.exists? file_ref

        if !File.exists? options.folder
          STDOUT.puts "Error: folder #{file_ref} does not exist"
          exit
        end

        doc = Nokogiri::HTML(File.open(file_ref))
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
        else
          @@utils.compiled_markup = doc
        end
        puts "== Done"
        
      else
        STDOUT.puts "Error: No file #{file_ref}"
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
      
      AWS::S3::DEFAULT_HOST.replace Edma::S3ID
      service = AWS::S3::Base.establish_connection!(
        :access_key_id => Edma::AWS_ACCESS_KEY_ID,
        :secret_access_key => Edma::AWS_SECRET_ACCESS_KEY)
      bucket = AWS::S3::Bucket.find(Edma::AWS_BUCKET)
      
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
                AWS::S3::S3Object.store("#{@@utils.id}/"+remote_file, open("#{options.folder}/"+remote_file), Edma::AWS_BUCKET, :access => :public_read)
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


    # Public: Uploads compiled HTML markup to a Litmus App test.
    #
    # file - file to read and upload (defaults to varible in classs @compiled).
    #
    # Examples
    #
    #   edma start_litmus_test
    #   edma start_litmus_test -f email.html
    #   
    #
    desc "start_litmus_test", "uploads compiled HTML markup to a Litmus app test"
    method_option :file, :default => "_email.tmp.html", :aliases => "-f",
    :desc => "file to read and updload to litmus app"
    def start_litmus_test
      require 'net/http'
      require 'nokogiri'
      company = "soi"
      puts "== Starting Litmus test"
      
      if @@utils.compiled_markup
        doc = @@utils.compiled_markup
      else
        doc = Nokogiri::HTML(File.open(options.file))
      end       


      xml = generate_litmus_markup(doc)
      uri = URI(Edma::LITMUS_TEST_URI)
      req = Net::HTTP::Post.new(uri.path)
      
      req.basic_auth 'soi', Edma::LITMUS_ACCOUNT_PASSWORD
      req.content_type = 'application/xml'
      req.body = xml

      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(req)
      end

      case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        response = res.body
        xml = Nokogiri::XML(response)
        puts "== Test uploaded successfully to Litmus https://soi.litmus.com/tests/"+xml.xpath("//id").first.content
      else
        res.value
        puts "ERROR: inline service returned #{res.value}"
      end
    end
    
    no_tasks do

    def cleanup
      ENV['EDMA_TEMP_DOC'] = nil
    end

    def generate_litmus_markup(doc)
      array = @@utils.email_clients
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.test_set {
          xml.applications(:type => "array") {
            array.each do |client|
              xml.application {
                xml.code client
              }
            end
          }
          xml.save_defaults false
          xml.use_defaults false
          xml.email_source {
            xml.body {
              xml.cdata(doc)
            }
            xml.subject @@utils.id
          }
        }
      end
      builder.to_xml
    end

    end

  ##END of Class and Module
  end
end
