class PmuFetcher

  # Returns the pathname of the file it downloaded to
  def download
    write_to_file(fetch_from_cognos)
  end

  private

  def fetch_from_cognos
    puts "Fetching data from Cognos..."
    uri = URI("https://reporting.northwestern.edu/sso/app/cgi-bin/cognosisapi.dll?b_action=cognosViewer&&CAMUsername=#{Settings.pmu.username}&CAMPassword=#{Settings.pmu.password}&CAMNamespace=ADS&ui.action=run&ui.object=%2fcontent%2ffolder%5b%40name%3d%27PMU%27%5d%2ffolder%5b%40name%3d%27WebServices%27%5d%2freport%5b%40name%3d%27PMU%20Organizational%20Data%27%5d&ui.name=PMU%20Organizational%20Data%27%5d&ui.name=PMU%20Organizational%20Data&run.outputFormat=XML&run.prompt=false")

    http = Net::HTTP.new uri.host, uri.port
    http.use_ssl = true
    # http.set_debug_output $stderr

    req = Net::HTTP::Get.new uri.request_uri

    response = http.request req

    puts "Got response #{response.code}."

    write_to_file(response.body, "pmu-raw")

    strip_html(response.body)
  end

  # The URL they've given us returns the XML we want wrapped in HTML. This strips it out
  # and gives us just the data we want.
  def strip_html(body)
    body.partition(/<textarea (.*?)>/)[2].partition(/<\/textarea>/)[0]
  end

  # Returns the path name
  def write_to_file(string, file_prefix = "pmu")
    path = File.expand_path("#{Rails.root}/tmp/#{file_prefix}-#{now_string}.xml", File.dirname(__FILE__))
    puts "Saving to file: #{path}"
    File.open path, "wb" do |f|
      f.write(string)
    end
    path
  end

  def now_string
    Time.zone.now.strftime("%Y-%m-%d.%H-%M")
  end

end
