module Http

  def update_request(url, form_data)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Patch.new(uri.request_uri)
    request.set_form_data(form_data)
    response = http.request(request)
    result = JSON.parse(response.body)
  end

end