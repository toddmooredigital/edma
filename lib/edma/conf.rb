module Edma
	VERSION = "1.0.0"

	#Amazon Configuration
	AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID']
    AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY']
    AWS_BUCKET = "dtdigitaledms"
    S3ID = "s3-ap-southeast-1.amazonaws.com"

    #Litmus Configuration
    LITMUS_TEST_URI = "https://soi.litmus.com/emails.xml"
    LITMUS_ACCOUNT_PASSWORD = ENV['LITMUS_PASSWORD']

    #Block for maybe configuring the fileserver packaging
    FILESERVER = "OgilvyInteractive"
end
