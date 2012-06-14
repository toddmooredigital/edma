require 'spec_helper'

describe Edma do
  it 'should return correct version string' do
    Edma.version_string.should == "Edma version #{Edma::VERSION}"
  end

  it 'should return the correct id number' do
  	util = Edma::Utils.new
  	util.id.should == "edma"
  end

end