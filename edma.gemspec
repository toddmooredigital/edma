$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require 'rake'
require 'edma/version'

Gem::Specification.new do |s|
 s.name        = "edma"
 s.version     = Edma::VERSION
 s.authors     = ["Todd Moore"]
 s.email       = ["todd.moore@dtdigital.com.au"]

 s.summary     = "Automation for various email tasks"
 s.description = "This gem helps with automating the production of various eDM tasks"
 s.homepage    = "http://github.com/dtdigital/edma.git"

 s.files = FileList['lib/**/*.rb', 'bin/*', '[A-Z]*', 'test/**/*'].to_a
 s.test_files  = Dir.glob("{spec,test}/**/*.rb")
 s.add_dependency('thor')
 s.add_dependency('sqlite3')
 s.add_dependency('aws-s3')
 s.add_dependency('nokogiri')
 s.add_dependency('httparty')
 s.executables << 'edma' 

end