Paperclip::Attachment.default_options[:s3_host_name] = 's3-eu-west-1.amazonaws.com'

Paperclip.options[:content_type_mappings] = {
:json => "application/json"
}

