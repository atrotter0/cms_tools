require 'rest-client'
require 'json'
require 'csv'

load 'response_helper.rb'

FALLBACK_WIDGET_SLUGS = [
  "coupon", 
  "city-state-zip-search", 
  "self-storage-filtered", 
  "self-storage-search", 
  "multifamily-iui-cards-v2", 
  "multifamily-search-v2"
].freeze

class LocationPageData
  attr_accessor :client_name, :location_name, :location_urn, :pages, :last_publish_date

  def initialize(client_name, location_name, location_urn, last_publish_date)
    @client_name = client_name
    @location_name = location_name
    @location_urn = location_urn
    @pages = ""
    @last_publish_date = last_publish_date
  end

  def display
    puts "Client: #{client_name}"
    puts "Location: #{location_name}"
    puts "Urn: #{location_urn}"
    puts "Pages: #{pages}"
    puts "Last Publish Date: #{last_publish_date}"
  end

  def add_page(page)
    @pages += page + ', '
  end

  def remove_last_comma
    @pages = @pages.chop.chop
  end
end

def build_cms_list(file_name, cms_holder)
  file = File.open(file_name, "r")
  while !file.eof?
    line = file.readline.chomp
    cms_holder.push(line)
  end
  file.close
end

def gather_cms_info(cms_list, cms_data_holder)
  cms_list.each do |cms|
    cms_url = "https://#{cms}.herokuapp.com/g5_ops/config.json"
    puts "Gathering data for #{cms}"
    response = get_response(cms_url)
    data = get_data(response, cms_url) if response
    g5_internal = check_g5_internal(data) unless data.empty?
    get_page_info(data, cms_data_holder) if g5_internal == false
  end
end

def check_g5_internal(data)
  g5_internal = data["client"]["g5_internal"]
end

def get_page_info(data, cms_data_holder)
  client = data["client"]["name"]
  first_location = data["locations"].first
  if first_location.nil?
    puts "No locations for #{client}!"
    puts ""
  else
    data["locations"].each do |location|
      location_name = location["location"]
      location_urn = location["urn"]
      last_publish_date = Date.parse(location["last_successful_deploy"]) unless location["last_successful_deploy"].nil?
      location_data = LocationPageData.new(client, location_name, location_urn, last_publish_date)
      location["page_configs"].each do |page|
        page["garden_widget_slugs"].each do |widget_slug|
          if FALLBACK_WIDGET_SLUGS.include?(widget_slug)
            location_data.add_page(page["page"])
          end
        end
      end
      if location_data.pages != ""
        location_data.remove_last_comma
        cms_data_holder << location_data
        location_data.display
        puts "Added data to holder!"
        puts ""
      end
    end
  end
end

def export_to_csv(file_name, cms_data_holder)
  puts "Exporting CMS data..."
  csv_headers = ["Client:", "Location Name:", "Location Urn:", "Last Publish Date:", "Pages With Fallback Widgets:"]
  CSV.open(file_name, "wb") do |csv|
    csv << csv_headers
    cms_data_holder.each do |location|
      csv_row = [
        location.client_name, 
        location.location_name, 
        location.location_urn, 
        location.last_publish_date, 
        location.pages
      ]
      csv << csv_row
    end
  end
  puts "Data exported!"
end

# script start
cms_list = []
cms_data_holder = []
puts "Starting script..."
file = "cms-list-test.txt"
build_cms_list(file, cms_list)
gather_cms_info(cms_list, cms_data_holder)
puts "Location count: #{cms_data_holder.count}"
export_to_csv("cms_page_data.csv", cms_data_holder)
