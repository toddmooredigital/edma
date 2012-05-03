module Edma
	AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID']
    AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY']
    AWS_BUCKET = "dtdigitaledms"
    S3ID = "s3-ap-southeast-1.amazonaws.com"
    EMAIL_CLIENTS = ["hotmail", "gmail", "notes8", "ol2010", "ol2007", "gmailnew", "ffhotmail", "ipad3", "iphone3", "ol2003", "ol2000", "ol2002", "yahooo"]
    LITMUS_TEST_URI = "https://soi.litmus.com/emails.xml"
    LITMUS_ACCOUNT_PASSWORD = ENV['LITMUS_PASSWORD']
end
